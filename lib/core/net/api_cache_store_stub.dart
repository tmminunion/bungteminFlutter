import 'api_cache_store.dart';

/// Fallback untuk platform tanpa `dart:io` (Flutter Web preview): tanpa cache.
ApiCacheStore createApiCacheStore() => _NoopApiCacheStore();

class _NoopApiCacheStore implements ApiCacheStore {
  @override
  Future<ApiCacheEntry?> read(String key) async => null;

  @override
  Future<void> write(String key, String url, ApiCacheEntry entry) async {}

  @override
  Future<void> remove(String key) async {}

  @override
  Future<void> clear() async {}
}
