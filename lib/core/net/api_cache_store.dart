import 'dart:typed_data';

import 'api_cache_store_stub.dart'
    if (dart.library.io) 'api_cache_store_sqlite.dart' as impl;

/// Satu baris respons API yang tersimpan di SQLite lokal.
class ApiCacheEntry {
  const ApiCacheEntry({
    required this.statusCode,
    required this.headers,
    required this.body,
    required this.updatedAt,
  });

  final int statusCode;
  final Map<String, String> headers;
  final Uint8List body;
  final DateTime updatedAt;

  Duration get age => DateTime.now().difference(updatedAt);
}

/// Penyimpanan cache respons API (SQLite di Android/iOS, no-op di Web/test).
abstract class ApiCacheStore {
  static final ApiCacheStore instance = impl.createApiCacheStore();

  Future<ApiCacheEntry?> read(String key);

  Future<void> write(String key, String url, ApiCacheEntry entry);

  Future<void> remove(String key);

  /// Hapus seluruh cache (dipanggil saat logout agar data user lain tidak bocor).
  Future<void> clear();
}
