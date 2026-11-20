import 'dart:convert';

import 'package:bungtemin_flutter/core/net/api_cache_store.dart';
import 'package:bungtemin_flutter/core/net/offline_first_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _MemoryStore implements ApiCacheStore {
  final Map<String, ApiCacheEntry> data = {};

  @override
  Future<ApiCacheEntry?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String url, ApiCacheEntry entry) async {
    data[key] = entry;
  }

  @override
  Future<void> remove(String key) async {
    data.remove(key);
  }

  @override
  Future<void> clear() async => data.clear();
}

void main() {
  final url = Uri.parse('https://bungtemin.net/btapi/Media/stories');

  setUp(OfflineFirstClient.resetState);

  test('menyimpan respons sukses lalu memakai cache saat jaringan putus',
      () async {
    final store = _MemoryStore();
    var online = true;
    final client = OfflineFirstClient(
      store: store,
      inner: MockClient((req) async {
        if (!online) throw http.ClientException('Failed host lookup');
        return http.Response(jsonEncode({'data': ['a']}), 200);
      }),
    );

    final first = await client.get(url);
    expect(first.statusCode, 200);
    expect(store.data, hasLength(1));

    online = false;
    final second = await client.get(url);
    expect(second.statusCode, 200);
    expect(jsonDecode(second.body)['data'], ['a']);
    expect(second.headers['x-bt-cache'], 'HIT');
    expect(OfflineFirstClient.offline.value, isTrue);
  });

  test('tanpa cache, error jaringan tetap dilempar', () async {
    final client = OfflineFirstClient(
      store: _MemoryStore(),
      inner: MockClient((req) async => throw http.ClientException('offline')),
    );
    await expectLater(
      client.get(url),
      throwsA(isA<http.ClientException>()),
    );
  });

  test('jaringan lambat -> cache dikembalikan setelah soft timeout', () async {
    final store = _MemoryStore();
    var slow = false;
    final client = OfflineFirstClient(
      store: store,
      softTimeout: const Duration(milliseconds: 50),
      inner: MockClient((req) async {
        if (slow) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          return http.Response('"baru"', 200);
        }
        return http.Response('"lama"', 200);
      }),
    );

    await client.get(url);
    slow = true;
    final res = await client.get(url);
    expect(res.body, '"lama"');

    // Request di belakang tetap memperbarui cache untuk pembukaan berikutnya.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(utf8.decode(store.data.values.single.body), '"baru"');
  });

  test('POST mutasi tidak pernah di-cache, cache-buster diabaikan', () async {
    final store = _MemoryStore();
    final client = OfflineFirstClient(
      store: store,
      inner: MockClient((req) async => http.Response('{"ok":true}', 200)),
    );

    await client.post(
      Uri.parse('https://bungtemin.net/btapi/Media/toggle_like'),
      body: {'id': '1'},
    );
    expect(store.data, isEmpty);

    await client.get(Uri.parse('https://bungtemin.net/btapi/Promo?_t=1700000000000'));
    await client.get(Uri.parse('https://bungtemin.net/btapi/Promo?_t=1700000009999'));
    expect(store.data, hasLength(1));
  });

  test('cache dibedakan per token Authorization', () async {
    final store = _MemoryStore();
    final client = OfflineFirstClient(
      store: store,
      inner: MockClient((req) async => http.Response('{}', 200)),
    );
    final me = Uri.parse('https://bungtemin.net/Idcard/api/me');
    await client.get(me, headers: {'Authorization': 'Bearer a.b.c'});
    await client.get(me, headers: {'Authorization': 'Bearer x.y.z'});
    expect(store.data, hasLength(2));
  });
}
