import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_cache_store.dart';

/// HTTP client "local-first" berbasis SQLite.
///
/// Alur untuk request yang boleh di-cache (GET + beberapa POST read-only):
/// 1. Belum ada cache  -> ambil dari jaringan seperti biasa, simpan bila 2xx.
/// 2. Ada cache & sedang offline -> langsung kembalikan cache (tanpa muter).
/// 3. Ada cache & online -> balapan: jaringan diberi waktu [softTimeout].
///    Kalau jaringan lambat/gagal/5xx, kembalikan cache; request jaringan
///    tetap berjalan di belakang dan memperbarui cache untuk pembukaan berikutnya.
class OfflineFirstClient extends http.BaseClient {
  OfflineFirstClient({
    http.Client? inner,
    this.softTimeout = const Duration(milliseconds: 2500),
    this.backgroundTimeout = const Duration(seconds: 30),
    ApiCacheStore? store,
  })  : _inner = inner ?? http.Client(),
        _store = store ?? ApiCacheStore.instance;

  final http.Client _inner;
  final ApiCacheStore _store;
  final Duration softTimeout;
  final Duration backgroundTimeout;

  /// Setelah satu request gagal karena jaringan, anggap offline selama ini.
  static const Duration offlineGrace = Duration(seconds: 20);
  static DateTime? _offlineUntil;

  /// `true` saat aplikasi sedang menampilkan data dari cache karena offline.
  static final ValueNotifier<bool> offline = ValueNotifier<bool>(false);

  /// Setelah aksi tulis (POST upload/like/komentar), GET berikutnya menunggu
  /// jaringan penuh supaya user langsung melihat hasil perubahannya.
  static const Duration freshAfterMutation = Duration(seconds: 15);
  static DateTime? _lastMutationAt;

  static bool get _recentlyMutated {
    final at = _lastMutationAt;
    return at != null && DateTime.now().difference(at) < freshAfterMutation;
  }

  static bool get isLikelyOffline {
    final until = _offlineUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  static void _markOffline() {
    _offlineUntil = DateTime.now().add(offlineGrace);
    offline.value = true;
  }

  static void _markOnline() {
    _offlineUntil = null;
    offline.value = false;
  }

  // ---------------------------------------------------------------------------
  // Kebijakan cache
  // ---------------------------------------------------------------------------

  /// Endpoint GET yang TIDAK boleh di-cache (status realtime / auth / kontrol).
  static final List<RegExp> _getDenyList = [
    RegExp(r'/auth/msapp_status', caseSensitive: false),
    RegExp(r'/AppControl/', caseSensitive: false),
    RegExp(r'login|otp|logout', caseSensitive: false),
    RegExp(r'scan_absen|kirimAbsen|checkin', caseSensitive: false),
  ];

  /// Endpoint POST yang sebenarnya hanya MEMBACA data -> aman di-cache.
  static final List<RegExp> _postAllowList = [
    RegExp(r'/btapi/User/pin_status', caseSensitive: false),
    RegExp(r'/btapi/training/getAllByNoreg', caseSensitive: false),
  ];

  static bool _isCacheable(http.BaseRequest req) {
    if (req is! http.Request) return false; // multipart/streamed: tidak di-cache
    final url = req.url.toString();
    switch (req.method.toUpperCase()) {
      case 'GET':
        return !_getDenyList.any((r) => r.hasMatch(url));
      case 'POST':
        return _postAllowList.any((r) => r.hasMatch(url));
      default:
        return false;
    }
  }

  /// Buang query cache-buster (`_t=1700000000000`) supaya kunci stabil.
  static Uri _normalizeUrl(Uri url) {
    if (url.queryParameters.isEmpty) return url;
    final digits = RegExp(r'^\d{10,}$');
    final params = Map<String, String>.from(url.queryParameters)
      ..removeWhere(
        (k, v) => (k == '_t' || k == 't' || k == '_') && digits.hasMatch(v),
      );
    if (params.isEmpty) return Uri.parse(url.toString().split('?').first);
    return url.replace(queryParameters: params);
  }

  static String _cacheKey(http.Request req) {
    final auth = req.headers.entries
        .where((e) => e.key.toLowerCase() == 'authorization')
        .map((e) => e.value)
        .join();
    final body = req.method.toUpperCase() == 'GET' ? '' : req.body;
    final scope = (auth.isEmpty && body.isEmpty) ? '' : '#${_hash('$auth|$body')}';
    return '${req.method.toUpperCase()} ${_normalizeUrl(req.url)}$scope';
  }

  /// FNV-1a 32-bit ganda (cukup untuk membedakan token/body, tanpa paket crypto).
  static String _hash(String input) {
    var h1 = 0x811c9dc5;
    var h2 = 0x01000193 ^ input.length;
    for (final c in utf8.encode(input)) {
      h1 = ((h1 ^ c) * 0x01000193) & 0xffffffff;
      h2 = ((h2 ^ c) * 0x000193eb) & 0xffffffff;
    }
    return '${h1.toRadixString(16)}${h2.toRadixString(16)}';
  }

  // ---------------------------------------------------------------------------
  // Eksekusi
  // ---------------------------------------------------------------------------

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!_isCacheable(request)) {
      return _sendTracked(request);
    }
    final req = request as http.Request;
    final key = _cacheKey(req);
    final cached = await _store.read(key);

    // 1) Belum pernah tersimpan: perilaku normal (error tetap dilempar).
    if (cached == null) {
      final res = await _fetchAndStore(req, key);
      return _toStreamed(res, request);
    }

    // 2) Diketahui offline: langsung tampilkan data lokal, cek ulang diam-diam.
    if (isLikelyOffline) {
      _fetchAndStore(req, key).ignore();
      return _fromCache(cached, request);
    }

    // 3) Online: beri jaringan kesempatan singkat, selebihnya pakai cache.
    final network = _fetchAndStore(req, key);
    try {
      final wait = _recentlyMutated ? backgroundTimeout : softTimeout;
      final res = await network.timeout(wait);
      if (res.statusCode >= 500) return _fromCache(cached, request);
      return _toStreamed(res, request);
    } on TimeoutException {
      network.ignore(); // tetap jalan di belakang & memperbarui cache
      return _fromCache(cached, request);
    } catch (_) {
      return _fromCache(cached, request);
    }
  }

  /// Reset status global (dipakai unit test).
  @visibleForTesting
  static void resetState() {
    _offlineUntil = null;
    _lastMutationAt = null;
    offline.value = false;
  }

  /// Request non-cache tetap dipantau supaya status offline akurat.
  Future<http.StreamedResponse> _sendTracked(http.BaseRequest request) async {
    try {
      final res = await _inner.send(request);
      _markOnline();
      if (request.method.toUpperCase() != 'GET') {
        _lastMutationAt = DateTime.now();
      }
      return res;
    } catch (_) {
      _markOffline();
      rethrow;
    }
  }

  Future<http.Response> _fetchAndStore(http.Request original, String key) async {
    try {
      final streamed =
          await _inner.send(_clone(original)).timeout(backgroundTimeout);
      final res =
          await http.Response.fromStream(streamed).timeout(backgroundTimeout);
      _markOnline();
      if (res.statusCode >= 200 &&
          res.statusCode < 300 &&
          res.bodyBytes.isNotEmpty) {
        await _store.write(
          key,
          original.url.toString(),
          ApiCacheEntry(
            statusCode: res.statusCode,
            headers: res.headers,
            body: res.bodyBytes,
            updatedAt: DateTime.now(),
          ),
        );
      }
      return res;
    } catch (_) {
      _markOffline();
      rethrow;
    }
  }

  static http.Request _clone(http.Request r) {
    return http.Request(r.method, r.url)
      ..headers.addAll(r.headers)
      ..bodyBytes = r.bodyBytes
      ..followRedirects = r.followRedirects
      ..maxRedirects = r.maxRedirects
      ..persistentConnection = r.persistentConnection;
  }

  static http.StreamedResponse _toStreamed(
    http.Response res,
    http.BaseRequest request,
  ) {
    return http.StreamedResponse(
      Stream.value(res.bodyBytes),
      res.statusCode,
      contentLength: res.bodyBytes.length,
      request: request,
      headers: res.headers,
      reasonPhrase: res.reasonPhrase,
    );
  }

  static http.StreamedResponse _fromCache(
    ApiCacheEntry entry,
    http.BaseRequest request,
  ) {
    return http.StreamedResponse(
      Stream.value(entry.body),
      entry.statusCode,
      contentLength: entry.body.length,
      request: request,
      headers: {
        ...entry.headers,
        'x-bt-cache': 'HIT',
        'x-bt-cache-age': entry.age.inSeconds.toString(),
      },
    );
  }

  @override
  void close() => _inner.close();
}
