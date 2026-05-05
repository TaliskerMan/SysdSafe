import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'man_parser.dart';

class DirectiveExplanation {
  final String directive;
  final String explanation;
  final String snippet;

  DirectiveExplanation({
    required this.directive,
    required this.explanation,
    required this.snippet,
  });
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('sysdsafe.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationSupportDirectory();
    final path = join(dbPath.path, filePath);

    return await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(version: 1, onCreate: _createDB),
    );
  }

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
  }

  Future<bool> isDatabaseInitialized() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM directives',
    );
    final count = result.first['count'] as int? ?? 0;
    return count > 0;
  }

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
    Batch batch = db.batch();
    for (var pd in parsedDirectives) {
      batch.insert('directives', {
        'directive': pd.directive,
        'explanation': pd.explanationMarkdown,
        'snippet': pd.snippet,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> syncDatabase() async {
    final db = await instance.database;
    await db.execute('DELETE FROM directives');
    await seedDatabase();
  }

  Future<DirectiveExplanation?> getExplanation(String directivePart) async {
    final db = await instance.database;
    final maps = await db.query(
      'directives',
      where: 'directive LIKE ?',
      whereArgs: ['%$directivePart%'],
    );

    if (maps.isNotEmpty) {
      return DirectiveExplanation(
        directive: maps.first['directive'] as String,
        explanation: maps.first['explanation'] as String,
        snippet: maps.first['snippet'] as String,
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
  Future<String?> getServiceBackup(String serviceName) async {
    final db = await instance.database;
    final maps = await db.query(
      'backups',
      where: 'service_name = ?',
      whereArgs: [serviceName],
    );

    if (maps.isNotEmpty) {
      return maps.first['original_content'] as String;
    }
    return null;
  }
}
