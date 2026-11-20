import 'dart:convert';

import '../core/net/cached_http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/work_calendar.dart';

/// Memuat kalender kerja TMMIN melalui proxy BTAPI (`https://bungtemin.net/btapi/Calendar`)
/// yang menggabungkan data HRPortal MyTMMIN + override Admin Panel (`/adminpanel/kalender`).
/// Mengecek `cache_key` di `/btapi/Calendar/version` agar perubahan dari Admin Panel
/// langsung terdeteksi dan otomatis menyegarkan cache lokal Flutter.
class WorkCalendarService {
  static const Duration _timeout = Duration(seconds: 15);
  static const Duration _versionTimeout = Duration(seconds: 5);
  static const Duration cacheTtl = Duration(days: 30); // Cache 1 bulanan
  static const String _cachePrefix = 'work_calendar_v2_';
  static const String _btapiCalendarUrl = 'https://bungtemin.net/btapi/Calendar';
  static const String _btapiVersionUrl =
      'https://bungtemin.net/btapi/Calendar/version';

  /// Rentang tahun yang bisa dipilih: 3 tahun ke belakang s/d 3 tahun ke depan.
  static List<int> availableYears() {
    final now = DateTime.now().year;
    return [for (var y = now - 3; y <= now + 3; y++) y];
  }

  Future<WorkYear> load(int year, {bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_cachePrefix$year';
    final cachedEntry = _readCacheEntry(prefs.getString(key), year);

    // Cek cepat cache_key terbaru dari server (misal: update1 -> upadat16)
    final remoteKey = await _fetchRemoteCacheKey();
    final cacheKeyChanged = remoteKey != null &&
        remoteKey.isNotEmpty &&
        cachedEntry != null &&
        cachedEntry.cacheKey != remoteKey;

    if (!forceRefresh && cachedEntry != null && !cacheKeyChanged) {
      // Jika data berasal dari fallback generator atau usia cache > 30 hari,
      // segarkan di latar belakang dari BTAPI proxy tanpa memblokir UI.
      if (cachedEntry.yearData.isFallback || cachedEntry.isExpired) {
        _refreshInBackground(prefs, key, year);
      }
      return cachedEntry.yearData;
    }

    final remote = await _fetchFromBtapiProxy(
      year,
      forceRefresh: forceRefresh || cacheKeyChanged,
    );
    if (remote != null) {
      await _saveCache(
        prefs,
        key,
        remote.rows,
        isFallback: false,
        cacheKey: remote.cacheKey.isNotEmpty
            ? remote.cacheKey
            : (remoteKey ?? 'update1'),
      );
      return WorkYear.fromRows(year, remote.rows, isFallback: false);
    }

    // Jika jaringan sedang offline tetapi ada cache lama, gunakan cache lama dulu
    if (cachedEntry != null) {
      return cachedEntry.yearData;
    }

    final generated = WorkYear.fallbackRows(year);
    await _saveCache(
      prefs,
      key,
      generated,
      isFallback: true,
      cacheKey: '',
    );
    return WorkYear.fromRows(year, generated, isFallback: true);
  }

  Future<String?> _fetchRemoteCacheKey() async {
    try {
      final uri = Uri.parse(_btapiVersionUrl).replace(
        queryParameters: {'_t': '${DateTime.now().millisecondsSinceEpoch}'},
      );
      final res = await http.get(uri).timeout(_versionTimeout);
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      final key = (decoded['cache_key'] ?? '').toString().trim();
      return key.isEmpty ? null : key;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCache(
    SharedPreferences prefs,
    String key,
    List<Map<String, dynamic>> rows, {
    required bool isFallback,
    required String cacheKey,
  }) async {
    await prefs.setString(
      key,
      jsonEncode({
        'isFallback': isFallback,
        'cacheKey': cacheKey,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
        'rows': rows,
      }),
    );
  }

  Future<void> _refreshInBackground(
    SharedPreferences prefs,
    String key,
    int year,
  ) async {
    final remote = await _fetchFromBtapiProxy(year);
    if (remote != null) {
      await _saveCache(
        prefs,
        key,
        remote.rows,
        isFallback: false,
        cacheKey: remote.cacheKey,
      );
    }
  }

  _CachedCalendarEntry? _readCacheEntry(String? raw, int year) {
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final rows = (decoded['rows'] as List?)
          ?.whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (rows == null || rows.isEmpty) return null;
      final isFallback = decoded['isFallback'] == true;
      final cacheKey = (decoded['cacheKey'] ?? '').toString().trim();
      final cachedAtMs =
          int.tryParse((decoded['cachedAt'] ?? '0').toString()) ?? 0;
      final ageMs = DateTime.now().millisecondsSinceEpoch - cachedAtMs;
      final isExpired = cachedAtMs <= 0 || ageMs > cacheTtl.inMilliseconds;
      final parsed = WorkYear.fromRows(
        year,
        rows,
        isFallback: isFallback,
      );
      if (parsed.months.isEmpty) return null;
      return _CachedCalendarEntry(
        yearData: parsed,
        isExpired: isExpired,
        cacheKey: cacheKey,
      );
    } catch (_) {
      return null;
    }
  }

  Future<_RemoteCalendarResult?> _fetchFromBtapiProxy(
    int year, {
    bool forceRefresh = false,
  }) async {
    try {
      final params = <String, String>{
        'WorkingMonth': '$year-01',
        'MonthPeriod': '12',
        'OrderDate': 'asc',
        'NationalHolidayFlag': '0',
        if (forceRefresh) 'refresh': '1',
      };
      final uri = Uri.parse(_btapiCalendarUrl).replace(queryParameters: params);
      final res = await http.get(uri).timeout(_timeout);
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map || decoded['data'] is! List) return null;
      final rows = (decoded['data'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (rows.isEmpty) return null;
      final cacheKey = (decoded['cache_key'] ?? '').toString().trim();
      return _RemoteCalendarResult(rows: rows, cacheKey: cacheKey);
    } catch (_) {
      return null;
    }
  }
}

class _RemoteCalendarResult {
  const _RemoteCalendarResult({
    required this.rows,
    required this.cacheKey,
  });

  final List<Map<String, dynamic>> rows;
  final String cacheKey;
}

class _CachedCalendarEntry {
  const _CachedCalendarEntry({
    required this.yearData,
    required this.isExpired,
    required this.cacheKey,
  });

  final WorkYear yearData;
  final bool isExpired;
  final String cacheKey;
}
