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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sysdsafe/backup_service.dart';
import 'package:sysdsafe/database.dart';
import 'package:sysdsafe/state.dart';
import 'package:sysdsafe/ui/backups.dart';

class MockBackupService extends BackupService {
  @override
  Future<List<BackupStatusItem>> loadBackups() async {
    return [
      BackupStatusItem(
        id: 1,
        serviceName: 'nginx.service',
        originalContent: '[Service]\nExecStart=/usr/sbin/nginx\n',
        timestamp: '2026-10-06T12:00:00.000',
        isOverrideActive: true,
        dropInContent: '[Service]\nNoNewPrivileges=yes\n',
      ),
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('BackupRecord & BackupStatusItem Models', () {
    test('BackupRecord.fromMap properly constructs model', () {
      final record = BackupRecord.fromMap({
        '_id': 42,
        'service_name': 'test.service',
        'original_content': '[Service]\nExecStart=/bin/true\n',
        'timestamp': '2026-10-06T12:00:00.000Z',
      });

      expect(record.id, 42);
      expect(record.serviceName, 'test.service');
      expect(record.originalContent, '[Service]\nExecStart=/bin/true\n');
      expect(record.timestamp, '2026-10-06T12:00:00.000Z');
    });

    test('BackupStatusItem formattedDate outputs human-readable string', () {
      final item = BackupStatusItem(
        id: 1,
        serviceName: 'sshd.service',
        originalContent: 'content',
        timestamp: '2026-10-06T14:30:45.000',
        isOverrideActive: true,
        dropInContent: '[Service]\nNoNewPrivileges=yes',
      );

      expect(item.formattedDate, '2026-10-06 14:30:45');
      expect(item.isOverrideActive, isTrue);
      expect(item.dropInContent, contains('NoNewPrivileges=yes'));
    });

    test('BackupStatusItem tolerates unparseable timestamps gracefully', () {
      final item = BackupStatusItem(
        id: 2,
        serviceName: 'cups.service',
        originalContent: 'cups_orig',
        timestamp: 'invalid-date-format',
        isOverrideActive: false,
      );

      expect(item.formattedDate, 'invalid-date-format');
      expect(item.isOverrideActive, isFalse);
    });
  });

  group('DatabaseHelper Backup Management', () {
    test('backupServiceState, getAllBackups, and deleteBackup operate correctly', () async {
      final dbHelper = DatabaseHelper.instance;

      // Ensure test records are stored
      await dbHelper.backupServiceState('auditd.service', '[Service]\nExecStart=/sbin/auditd\n');
      await dbHelper.backupServiceState('nginx.service', '[Service]\nExecStart=/usr/sbin/nginx\n');

      final backups = await dbHelper.getAllBackups();
      expect(backups.any((b) => b.serviceName == 'auditd.service'), isTrue);
      expect(backups.any((b) => b.serviceName == 'nginx.service'), isTrue);

      final singleBackup = await dbHelper.getServiceBackup('auditd.service');
      expect(singleBackup, contains('/sbin/auditd'));

      // Delete by service name
      await dbHelper.deleteBackupForService('auditd.service');
      final afterDelete = await dbHelper.getServiceBackup('auditd.service');
      expect(afterDelete, isNull);
    });
  });

  group('BackupService Logic & Restoration', () {
    test('restoreService rejects unsafe service names', () async {
      final service = BackupService();
      final result = await service.restoreService('../etc/cron.daily/malicious');

      expect(result.success, isFalse);
      expect(result.message, contains('Invalid service name'));
    });

    test('restoreService handles mock runner success', () async {
      final service = BackupService(
        commandRunner: (executable, arguments) async {
          return ProcessResult(1234, 0, 'reverted', '');
        },
      );

      final result = await service.restoreService('nginx.service');
      expect(result.success, isTrue);
      expect(result.message, contains('restored to its original state'));
    });

    test('restoreService handles mock runner failure', () async {
      final service = BackupService(
        commandRunner: (executable, arguments) async {
          return ProcessResult(1234, 1, '', 'Permission denied');
        },
      );

      final result = await service.restoreService('nginx.service');
      expect(result.success, isFalse);
      expect(result.message, contains('Restore failed: Permission denied'));
    });
  });

  group('BackupsScreen Widget Tests', () {
    testWidgets('renders screen controls, header, search bar, and mock backup card', (tester) async {
      final mockService = MockBackupService();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (context) => AppState(),
            child: Scaffold(
              body: BackupsScreen(backupService: mockService),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Changes & Backups'), findsOneWidget);
      expect(find.text('Total Backups'), findsOneWidget);
      expect(find.text('Active Changes'), findsOneWidget);
      expect(find.text('Restored / Original'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsOneWidget);
      expect(find.text('nginx.service'), findsOneWidget);
      expect(find.text('Change Active'), findsOneWidget);
    });
  });
}
