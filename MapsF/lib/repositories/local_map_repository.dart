import '../core/database/local_database.dart';
import '../models/local_map.dart';

class LocalMapRepository {
  const LocalMapRepository(this._database);

  final LocalDatabase _database;

  Future<List<LocalMap>> listMaps() async {
    final rows = await _database.getLocalMaps();
    return rows.map(LocalMap.fromDatabaseRow).toList();
  }

  Future<LocalMap?> findMap(String id) async {
    final row = await _database.getLocalMap(id);
    return row == null ? null : LocalMap.fromDatabaseRow(row);
  }

  Future<void> save(LocalMap map) {
    return _database.upsertLocalMap(map);
  }
}
