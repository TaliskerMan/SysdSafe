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

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sysdsafe/main.dart';
import 'package:sysdsafe/man_parser.dart';

/// Representation of a systemd hardening directive and its description/snippet.
class DirectiveExplanation {
  /// Constructor for [DirectiveExplanation].
  DirectiveExplanation({
    required this.directive,
    required this.explanation,
    required this.snippet,
  });

  /// Name of the Systemd hardening directive.
  final String directive;

  /// Explanation of the security benefits of the directive.
  final String explanation;

  /// Standard configuration snippet to enforce the directive.
  final String snippet;
}

/// Represents a stored backup entry for a systemd service before modifications were made.
/// (CP-ChangeComments: Data model representing service configuration snapshots for rollback)
class BackupRecord {
  /// Constructor for [BackupRecord].
  BackupRecord({
    required this.id,
    required this.serviceName,
    required this.originalContent,
    required this.timestamp,
  });

  /// Primary key ID in the SQLite backups table.
  final int id;

  /// Systemd service unit name (e.g., 'cups.service').
  final String serviceName;

  /// Original service definition content captured prior to modifications.
  final String originalContent;

  /// Timestamp string (ISO-8601) when the backup was captured.
  final String timestamp;

  /// Creates a [BackupRecord] instance from an SQLite map row.
  factory BackupRecord.fromMap(Map<String, dynamic> map) {
    return BackupRecord(
      id: map['_id'] as int? ?? 0,
      serviceName: map['service_name'] as String? ?? '',
      originalContent: map['original_content'] as String? ?? '',
      timestamp: map['timestamp'] as String? ?? '',
    );
  }
}

/// Helper class to initialize and perform database operations on Systemd hardening directives.
class DatabaseHelper {
  DatabaseHelper._init();

  /// Singleton instance of the [DatabaseHelper].
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  /// Retrieve the SQLite [Database] instance, initializing it if necessary.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('sysdsafe.db');
    return _database!;
  }

  /// Initialize the SQLite database connection at the specified file path.
  Future<Database> _initDB(String filePath) async {
    sysdsafeFfiInit();

    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      sqfliteFfiInit();
      databaseFactory = createDatabaseFactoryFfi(ffiInit: sysdsafeFfiInit);
      return databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: _createDB,
          onOpen: _onOpenDB,
        ),
      );
    }
    final dbPath = await getApplicationSupportDirectory();
    final path = join(dbPath.path, filePath);

    databaseFactory = createDatabaseFactoryFfi(ffiInit: sysdsafeFfiInit);
    return databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: _createDB,
        onOpen: _onOpenDB,
      ),
    );
  }

  /// Ensures all required tables exist even on existing database files from earlier versions.
  /// (CP-ChangeComments: Prevents "no such table: backups" on databases created prior to backup feature)
  Future _onOpenDB(Database db) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';

    await db.execute('''
CREATE TABLE IF NOT EXISTS directives (
  _id $idType,
  directive $textType,
  explanation $textType,
  snippet $textType
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS backups (
  _id $idType,
  service_name $textType,
  original_content $textType,
  timestamp $textType
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS app_settings (
  key $textType PRIMARY KEY,
  value $textType
)
''');
  }

  /// Create database tables schema during database creation.
  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';

    await db.execute('''
CREATE TABLE directives (
  _id $idType,
  directive $textType,
  explanation $textType,
  snippet $textType
)
''');

    // ShadowAgent Rule: Implement a reversible safety net for users
    // We add a backups table to store the pre-fix state of service files so they
    // can be recovered if the user gets locked out.
    await db.execute('''
CREATE TABLE backups (
  _id $idType,
  service_name $textType,
  original_content $textType,
  timestamp $textType
)
''');

    // Table for storing persistent user preferences (e.g. desktop theme mode, font size)
    await db.execute('''
CREATE TABLE IF NOT EXISTS app_settings (
  key $textType PRIMARY KEY,
  value $textType
)
''');
  }

  /// Check if the database has already been successfully seeded with directives.
  Future<bool> isDatabaseInitialized() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM directives',
    );
    final count = result.first['count'] as int? ?? 0;
    return count > 0;
  }

  /// Seed the database by parsing manual pages or falling back to defaults.
  Future<void> seedDatabase({void Function(double)? onProgress}) async {
    final db = await instance.database;

    final parser = ManParserService();
    final parsedDirectives = await parser.parseAll(onProgress: onProgress);

    // Default fallback if parsing fails (no pandoc, etc.)
    if (parsedDirectives.isEmpty) {
      await db.insert('directives', {
        'directive': 'PrivateNetwork',
        'explanation':
            'Sets up a new network namespace for the executed processes and only configures the loopback network device "lo".',
        'snippet': 'PrivateNetwork=yes',
      });
      return;
    }

    // Insert all parsed in a batch for efficiency
    final batch = db.batch();
    for (final pd in parsedDirectives) {
      batch.insert('directives', {
        'directive': pd.directive,
        'explanation': pd.explanationMarkdown,
        'snippet': pd.snippet,
      });
    }
    await batch.commit(noResult: true);
  }

  /// Wipe and re-seed the directives database.
  Future<void> syncDatabase() async {
    final db = await instance.database;
    await db.execute('DELETE FROM directives');
    await seedDatabase();
  }

  /// Find and return the [DirectiveExplanation] for the specified directive name.
  Future<DirectiveExplanation?> getExplanation(String directivePart) async {
    final db = await instance.database;
    final maps = await db.query(
      'directives',
      where: 'directive LIKE ?',
      whereArgs: ['%$directivePart%'],
    );

    if (maps.isNotEmpty) {
      return DirectiveExplanation(
        directive: maps.first['directive']! as String,
        explanation: maps.first['explanation']! as String,
        snippet: maps.first['snippet']! as String,
      );
    } else {
      return DirectiveExplanation(
        directive: directivePart,
        explanation:
            'No specific explanation found in database. This directive restricts system access.',
        snippet: '$directivePart=...',
      );
    }
  }

  // ShadowAgent Rule: "First, do no harm".
  // This method ensures we preserve the most recent state before auto-fixing.
  // We overwrite older backups of the same service to keep only the latest pre-autofix state.
  /// Backup the original pre-fix state of a Systemd service file.
  Future<void> backupServiceState(String serviceName, String content) async {
    final db = await instance.database;
    final timestamp = DateTime.now().toIso8601String();

    // Check if backup already exists
    final maps = await db.query(
      'backups',
      where: 'service_name = ?',
      whereArgs: [serviceName],
    );

    if (maps.isNotEmpty) {
      // Update existing backup to ensure only the most recent state is kept
      await db.update(
        'backups',
        {'original_content': content, 'timestamp': timestamp},
        where: 'service_name = ?',
        whereArgs: [serviceName],
      );
    } else {
      // Insert new backup
      await db.insert('backups', {
        'service_name': serviceName,
        'original_content': content,
        'timestamp': timestamp,
      });
    }
  }

  // Retrieve the backup if needed for UI inspection or restoration.
  /// Retrieve the backed up original content of a Systemd service file.
  Future<String?> getServiceBackup(String serviceName) async {
    final db = await instance.database;
    final maps = await db.query(
      'backups',
      where: 'service_name = ?',
      whereArgs: [serviceName],
    );

    if (maps.isNotEmpty) {
      return maps.first['original_content']! as String;
    }
    return null;
  }

  /// Retrieves all service backups stored in the SQLite database ordered by ID descending.
  /// (CP-ChangeComments: Enables the Backups & Restore UI to list all captured states)
  Future<List<BackupRecord>> getAllBackups() async {
    final db = await instance.database;
    final maps = await db.query(
      'backups',
      orderBy: '_id DESC',
    );
    return maps.map((map) => BackupRecord.fromMap(map)).toList();
  }

  /// Deletes a specific service backup entry from SQLite by its unique ID.
  /// (CP-ChangeComments: Allows removing individual stale backup entries)
  Future<void> deleteBackup(int id) async {
    final db = await instance.database;
    await db.delete(
      'backups',
      where: '_id = ?',
      whereArgs: [id],
    );
  }

  /// Deletes any existing backup record for the specified service name.
  /// (CP-ChangeComments: Cleans up service backup after full reversion if needed)
  Future<void> deleteBackupForService(String serviceName) async {
    final db = await instance.database;
    await db.delete(
      'backups',
      where: 'service_name = ?',
      whereArgs: [serviceName],
    );
  }

  /// Saves a key-value setting into the persistent `app_settings` table.
  Future<void> saveSetting(String key, String value) async {
    final db = await instance.database;
    await db.execute('''
CREATE TABLE IF NOT EXISTS app_settings (
  key TEXT PRIMARY KEY,
  value TEXT
)
''');
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieves a key-value setting from the `app_settings` table, or null if unset.
  Future<String?> getSetting(String key) async {
    final db = await instance.database;
    await db.execute('''
CREATE TABLE IF NOT EXISTS app_settings (
  key TEXT PRIMARY KEY,
  value TEXT
)
''');
    final maps = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isNotEmpty) {
      return maps.first['value'] as String?;
    }
    return null;
  }
}
