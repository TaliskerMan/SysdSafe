// Copyright (C) 2026 Chuck Talk <cwtalk1@gmail.com>
// This file is part of SysdSafe.
//
// SysdSafe is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, version 3.
//
// SysdSafe is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY. See the GNU AGPL v3 for details.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sysdsafe/database.dart';
import 'package:sysdsafe/hardening.dart';
import 'package:sysdsafe/logging.dart';

/// Represents a combined backup and active status snapshot for a Systemd service.
/// (CP-ChangeComments: Encapsulates both DB backup history and real-time filesystem state)
class BackupStatusItem {
  /// Constructor for [BackupStatusItem].
  BackupStatusItem({
    required this.id,
    required this.serviceName,
    required this.originalContent,
    required this.timestamp,
    required this.isOverrideActive,
    this.dropInContent,
    this.backupFilePath,
  });

  /// SQLite database ID or -1 if discovered from file system.
  final int id;

  /// Systemd service unit name.
  final String serviceName;

  /// Content of the service configuration prior to SysdSafe modifications.
  final String originalContent;

  /// ISO-8601 formatted timestamp of the backup.
  final String timestamp;

  /// Whether SysdSafe's override drop-in file is currently active on disk.
  final bool isOverrideActive;

  /// Content of the active drop-in configuration file, if currently active.
  final String? dropInContent;

  /// File path to the plain-text backup file, if present.
  final String? backupFilePath;

  /// Human-readable date and time formatted string.
  String get formattedDate {
    try {
      final parsed = DateTime.parse(timestamp);
      return '${parsed.year.toString().padLeft(4, '0')}-'
          '${parsed.month.toString().padLeft(2, '0')}-'
          '${parsed.day.toString().padLeft(2, '0')} '
          '${parsed.hour.toString().padLeft(2, '0')}:'
          '${parsed.minute.toString().padLeft(2, '0')}:'
          '${parsed.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return timestamp;
    }
  }
}

/// Result of an attempted service restoration to original state.
/// (CP-ChangeComments: Structured outcome for restoration reporting in the UI)
class RestoreResult {
  /// Constructor for [RestoreResult].
  RestoreResult({
    required this.success,
    required this.message,
    required this.isHealthy,
  });

  /// Whether the restoration command completed successfully.
  final bool success;

  /// Explanatory message or error detail.
  final String message;

  /// Whether the service returned to an active/healthy state.
  final bool isHealthy;
}

/// Service managing systemd service backups and state restoration.
/// (CP-ChangeComments: Centralized service providing safe rollback to known original states)
class BackupService {
  /// Constructor for [BackupService], allowing an optional command runner for testing.
  BackupService({
    Future<ProcessResult> Function(String, List<String>)? commandRunner,
  }) : _commandRunner = commandRunner ?? Process.run;

  final Future<ProcessResult> Function(String, List<String>) _commandRunner;

  /// Default path to the privileged SysdSafe PolicyKit helper.
  static const String kSysdSafeHelper = '/usr/lib/sysdsafe/sysdsafe-helper';

  /// Standard path for systemd system drop-in directory.
  static const String kSystemdSystemDir = '/etc/systemd/system';

  /// Discovers and loads all backup records, cross-referencing SQLite, plain text
  /// files at `~/sysdsafe_backups/`, and real-time `/etc/systemd/system` overrides.
  Future<List<BackupStatusItem>> loadBackups() async {
    final dbBackups = await DatabaseHelper.instance.getAllBackups();
    final items = <String, BackupStatusItem>{};

    // 1. Process SQLite backups
    for (final b in dbBackups) {
      final serviceName = b.serviceName;
      final dropInFile = File('$kSystemdSystemDir/$serviceName.d/sysdsafe-tier1.conf');
      final hasDropIn = await dropInFile.exists();
      String? dropInContent;
      if (hasDropIn) {
        try {
          dropInContent = await dropInFile.readAsString();
        } catch (_) {}
      }

      final homeDir = Platform.environment['HOME'] ?? '/root';
      final backupFilePath = '$homeDir/sysdsafe_backups/$serviceName.backup';
      final hasBackupFile = await File(backupFilePath).exists();

      items[serviceName] = BackupStatusItem(
        id: b.id,
        serviceName: serviceName,
        originalContent: b.originalContent,
        timestamp: b.timestamp,
        isOverrideActive: hasDropIn,
        dropInContent: dropInContent,
        backupFilePath: hasBackupFile ? backupFilePath : null,
      );
    }

    // 2. Discover any external disk backups in ~/sysdsafe_backups not in DB
    try {
      final homeDir = Platform.environment['HOME'] ?? '/root';
      final backupDir = Directory('$homeDir/sysdsafe_backups');
      if (await backupDir.exists()) {
        final entries = backupDir.listSync();
        for (final entry in entries) {
          if (entry is File && entry.path.endsWith('.backup')) {
            final fileName = p.basename(entry.path);
            final serviceName = fileName.substring(0, fileName.length - '.backup'.length);

            if (!items.containsKey(serviceName) && Hardening.isSafeServiceName(serviceName)) {
              final content = await entry.readAsString();
              final stat = await entry.stat();
              final ts = stat.modified.toIso8601String();

              // Auto-sync into SQLite to maintain database consistency
              await DatabaseHelper.instance.backupServiceState(serviceName, content);

              final dropInFile = File('$kSystemdSystemDir/$serviceName.d/sysdsafe-tier1.conf');
              final hasDropIn = await dropInFile.exists();
              String? dropInContent;
              if (hasDropIn) {
                try {
                  dropInContent = await dropInFile.readAsString();
                } catch (_) {}
              }

              items[serviceName] = BackupStatusItem(
                id: -1,
                serviceName: serviceName,
                originalContent: content,
                timestamp: ts,
                isOverrideActive: hasDropIn,
                dropInContent: dropInContent,
                backupFilePath: entry.path,
              );
            }
          }
        }
      }
    } catch (e) {
      LogService.error('Error scanning backup directory: $e');
    }

    // 3. Discover any active sysdsafe-tier1.conf drop-ins on the system
    try {
      final sysDir = Directory(kSystemdSystemDir);
      if (await sysDir.exists()) {
        final entries = sysDir.listSync();
        for (final entry in entries) {
          if (entry is Directory && entry.path.endsWith('.d')) {
            final dropIn = File(p.join(entry.path, 'sysdsafe-tier1.conf'));
            if (await dropIn.exists()) {
              final dirName = p.basename(entry.path);
              final serviceName = dirName.substring(0, dirName.length - 2);

              if (!items.containsKey(serviceName) && Hardening.isSafeServiceName(serviceName)) {
                String? dropInContent;
                try {
                  dropInContent = await dropIn.readAsString();
                } catch (_) {}

                items[serviceName] = BackupStatusItem(
                  id: -1,
                  serviceName: serviceName,
                  originalContent: '# Active drop-in found without prior backup snapshot.',
                  timestamp: DateTime.now().toIso8601String(),
                  isOverrideActive: true,
                  dropInContent: dropInContent,
                );
              }
            }
          }
        }
      }
    } catch (e) {
      LogService.error('Error scanning systemd drop-in directories: $e');
    }

    final resultList = items.values.toList();
    // Sort: Active modifications first, then newest timestamp first
    resultList.sort((a, b) {
      if (a.isOverrideActive != b.isOverrideActive) {
        return a.isOverrideActive ? -1 : 1;
      }
      return b.timestamp.compareTo(a.timestamp);
    });

    return resultList;
  }

  /// Restores a service to its original state by removing SysdSafe's drop-in override,
  /// executing daemon-reload, and try-restarting the unit.
  /// (CP-ChangeComments: Executes privileged revert operation and validates post-restoration health)
  Future<RestoreResult> restoreService(String serviceName) async {
    if (!Hardening.isSafeServiceName(serviceName)) {
      return RestoreResult(
        success: false,
        message: 'Invalid service name format.',
        isHealthy: false,
      );
    }

    final filePath = '$kSystemdSystemDir/$serviceName.d/sysdsafe-tier1.conf';
    final isRoot = Platform.isLinux &&
        Process.runSync('id', ['-u']).stdout.toString().trim() == '0';

    try {
      ProcessResult result;
      if (File(kSysdSafeHelper).existsSync()) {
        if (isRoot) {
          result = await _commandRunner(kSysdSafeHelper, ['revert', filePath, serviceName]);
        } else {
          result = await _commandRunner('pkexec', [kSysdSafeHelper, 'revert', filePath, serviceName]);
        }
      } else {
        const fallbackScript =
            r'rm -f -- "$1" && systemctl daemon-reload && systemctl try-restart -- "$2"';
        if (isRoot) {
          result = await _commandRunner('sh', [
            '-c',
            fallbackScript,
            '--',
            filePath,
            serviceName,
          ]);
        } else {
          result = await _commandRunner('pkexec', [
            'sh',
            '-c',
            fallbackScript,
            '--',
            filePath,
            serviceName,
          ]);
        }
      }

      if (result.exitCode == 0) {
        LogService.info('Successfully reverted SysdSafe changes for $serviceName');

        // Check if service is active after reload
        var isHealthy = true;
        try {
          final healthCheck = await _commandRunner('systemctl', ['is-active', '--', serviceName]);
          isHealthy = healthCheck.stdout.toString().trim() == 'active';
        } catch (_) {}

        return RestoreResult(
          success: true,
          message: 'Service "$serviceName" restored to its original state.',
          isHealthy: isHealthy,
        );
      } else {
        LogService.error('Revert failed for $serviceName: ${result.stderr}');
        return RestoreResult(
          success: false,
          message: 'Restore failed: ${result.stderr}',
          isHealthy: false,
        );
      }
    } catch (e) {
      LogService.error('Restore execution error for $serviceName: $e');
      return RestoreResult(
        success: false,
        message: 'Error executing restore: $e',
        isHealthy: false,
      );
    }
  }

  /// Deletes a backup record from SQLite and optionally cleans up the disk backup file.
  /// (CP-ChangeComments: Removes stale backup records when explicitly requested)
  Future<void> deleteBackup(BackupStatusItem item) async {
    if (item.id > 0) {
      await DatabaseHelper.instance.deleteBackup(item.id);
    } else {
      await DatabaseHelper.instance.deleteBackupForService(item.serviceName);
    }
    if (item.backupFilePath != null) {
      try {
        final f = File(item.backupFilePath!);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (e) {
        LogService.error('Error deleting backup file: $e');
      }
    }
  }
}
