import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'api_cache_store.dart';

ApiCacheStore createApiCacheStore() => _SqliteApiCacheStore();

class _SqliteApiCacheStore implements ApiCacheStore {
  static const _dbName = 'bt_api_cache.db';
  static const _table = 'api_cache';

  /// Entri yang tidak tersentuh lebih dari ini akan dibersihkan saat app dibuka.
  static const _maxAge = Duration(days: 45);

  Future<Database?>? _dbFuture;
  bool _disabled = false;

  /// Cache memori kecil supaya pembacaan berulang dalam satu sesi tidak ke disk.
  final Map<String, ApiCacheEntry> _memory = {};

  Future<Database?> _db() {
    if (_disabled) return Future.value(null);
    return _dbFuture ??= _open();
  }

  Future<Database?> _open() async {
    try {
      final dir = await getDatabasesPath();
      final db = await openDatabase(
        p.join(dir, _dbName),
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE $_table (
              cache_key TEXT PRIMARY KEY,
              url TEXT NOT NULL,
              status INTEGER NOT NULL,
              headers TEXT NOT NULL,
              body BLOB NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
        },
      );
      final cutoff =
          DateTime.now().subtract(_maxAge).millisecondsSinceEpoch;
      unawaited(
        db
            .delete(_table, where: 'updated_at < ?', whereArgs: [cutoff])
            .catchError((_) => 0),
      );
      return db;
    } catch (_) {
      // Plugin tidak tersedia (mis. unit test) -> nonaktifkan cache diam-diam.
      _disabled = true;
      return null;
    }
  }

  @override
  Future<ApiCacheEntry?> read(String key) async {
    final mem = _memory[key];
    if (mem != null) return mem;
    try {
      final db = await _db();
      if (db == null) return null;
      final rows = await db.query(
        _table,
        columns: ['status', 'headers', 'body', 'updated_at'],
        where: 'cache_key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final row = rows.first;
      final rawHeaders = jsonDecode(row['headers'] as String? ?? '{}');
      final entry = ApiCacheEntry(
        statusCode: row['status'] as int? ?? 200,
        headers: rawHeaders is Map
            ? rawHeaders.map((k, v) => MapEntry(k.toString(), v.toString()))
            : const {},
        body: row['body'] is Uint8List
            ? row['body'] as Uint8List
            : Uint8List.fromList((row['body'] as List).cast<int>()),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row['updated_at'] as int? ?? 0,
        ),
      );
      _memory[key] = entry;
      return entry;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String url, ApiCacheEntry entry) async {
    _memory[key] = entry;
    try {
      final db = await _db();
      if (db == null) return;
      await db.insert(
        _table,
        {
          'cache_key': key,
          'url': url,
          'status': entry.statusCode,
          'headers': jsonEncode(entry.headers),
          'body': entry.body,
          'updated_at': entry.updatedAt.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  @override
  Future<void> remove(String key) async {
    _memory.remove(key);
    try {
      final db = await _db();
      await db?.delete(_table, where: 'cache_key = ?', whereArgs: [key]);
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    _memory.clear();
    try {
      final db = await _db();
      await db?.delete(_table);
    } catch (_) {}
  }
}
