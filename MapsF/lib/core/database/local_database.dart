import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../models/local_map.dart';

class LocalDatabase {
  LocalDatabase();

  static const _databaseName = 'geocampo_local.db';
  static const _databaseVersion = 2;

  Database? _database;

  Future<Database> get database async {
    final current = _database;
    if (current != null) return current;

    final dbPath = p.join(await getDatabasesPath(), _databaseName);
    return _database = await openDatabase(
      dbPath,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _addColumnIfMissing(db, 'local_maps', 'package_version', 'TEXT');
          await _addColumnIfMissing(
            db,
            'local_maps',
            'package_size_bytes',
            'INTEGER',
          );
          await _addColumnIfMissing(
            db,
            'local_maps',
            'offline_saved_at',
            'TEXT',
          );
          await _addColumnIfMissing(
            db,
            'local_maps',
            'last_opened_at',
            'TEXT',
          );
        }
      },
    );
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
CREATE TABLE local_maps (
  id TEXT PRIMARY KEY,
  remote_map_id TEXT,
  project_id TEXT,
  name TEXT NOT NULL,
  source_type TEXT NOT NULL,
  package_path TEXT NOT NULL,
  mbtiles_path TEXT NOT NULL,
  preview_path TEXT,
  metadata_path TEXT NOT NULL,
  bounds_json TEXT NOT NULL,
  footprint_json TEXT,
  center_lat REAL,
  center_lng REAL,
  min_zoom INTEGER,
  max_zoom INTEGER,
  default_zoom INTEGER,
  package_version TEXT,
  package_size_bytes INTEGER,
  package_checksum_sha256 TEXT,
  offline_saved_at TEXT,
  last_opened_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
''');
    await db.execute('''
CREATE TABLE field_observations (
  id TEXT PRIMARY KEY,
  local_map_id TEXT,
  payload_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
''');
    await db.execute('''
CREATE TABLE packages (
  id TEXT PRIMARY KEY,
  local_map_id TEXT,
  path TEXT NOT NULL,
  checksum_sha256 TEXT,
  created_at TEXT NOT NULL
);
''');
  }

  static Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String type,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }

  Future<List<Map<String, Object?>>> getLocalMaps() async {
    final db = await database;
    return db.query('local_maps', orderBy: 'updated_at DESC');
  }

  Future<Map<String, Object?>?> getLocalMap(String id) async {
    final db = await database;
    final rows = await db.query(
      'local_maps',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> upsertLocalMap(LocalMap map) async {
    final db = await database;
    await db.insert(
      'local_maps',
      map.toDatabaseRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> getFieldObservations() async {
    final db = await database;
    return db.query('field_observations', orderBy: 'created_at DESC');
  }

  Future<List<Map<String, Object?>>> getPackages() async {
    final db = await database;
    return db.query('packages', orderBy: 'created_at DESC');
  }
}
