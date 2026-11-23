import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_info.dart';
import '../core/net/offline_first_client.dart';
import '../models/news_item.dart';

/// Tracker analitik layar ringan untuk Bungtemin APK.
/// Mengirim data 100% anonim (path layar, device, hash perangkat acak — tanpa noreg/nama/HP)
/// ke https://bungtemin.net/btapi/Analytics/track secara fire-and-forget agar tidak
/// menghambat UI maupun menyebabkan error saat offline.
class AppAnalyticsService {
  AppAnalyticsService._();

  static final AppAnalyticsService instance = AppAnalyticsService._();

  static const String _endpoint = 'https://bungtemin.net/btapi/Analytics/track';
  static const String _visitorPrefKey = 'bt_anon_visitor_id_v1';
  static const Duration _dedupeWindow = Duration(seconds: 4);

  String? _cachedVisitorId;
  String? _lastPath;
  DateTime? _lastSentAt;

  Future<String> _getOrCreateVisitorId() async {
    if (_cachedVisitorId != null && _cachedVisitorId!.isNotEmpty) {
      return _cachedVisitorId!;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(_visitorPrefKey);
      if (existing != null && RegExp(r'^[a-f0-9]{16}$').hasMatch(existing)) {
        _cachedVisitorId = existing;
        return existing;
      }
      final rng = Random.secure();
      final seedBytes = List<int>.generate(24, (_) => rng.nextInt(256));
      final digest = sha256.convert(seedBytes).toString().substring(0, 16);
      await prefs.setString(_visitorPrefKey, digest);
      _cachedVisitorId = digest;
      return digest;
    } catch (_) {
      return '';
    }
  }

  String _normalizePath(String raw) {
    var p = raw.trim();
    if (p.isEmpty) return '/app/home';
    if (!p.startsWith('/')) p = '/$p';
    if (!p.startsWith('/app/')) {
      p = p == '/app' ? '/app/home' : '/app$p';
    }
    p = p.replaceAll(RegExp(r'/{2,}'), '/');
    if (p.length > 220) p = p.substring(0, 220);
    return p;
  }

  String _deviceLabel() {
    if (kIsWeb) return 'Desktop';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'iOS App';
      case TargetPlatform.android:
        return 'Android App';
      default:
        return 'Mobile';
    }
  }

  String _userAgent() {
    final ver = AppInfo.isLoaded
        ? '${AppInfo.version}+${AppInfo.buildNumber}'
        : 'unknown';
    final os = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
        ? 'iOS'
        : 'Android';
    return 'BungteminAPK/$ver ($os)';
  }

  /// Catat kunjungan layar/fitur secara non-blocking (fire-and-forget).
  void trackScreen(String rawPath) {
    final path = _normalizePath(rawPath);
    final now = DateTime.now();
    if (_lastPath == path &&
        _lastSentAt != null &&
        now.difference(_lastSentAt!) < _dedupeWindow) {
      return;
    }
    _lastPath = path;
    _lastSentAt = now;

    if (OfflineFirstClient.offline.value) return;
    unawaited(_send(path));
  }

  /// Catat pembacaan detail artikel berita di dalam APK.
  void trackNews(NewsItem item) {
    String slug = '';
    final link = item.linkUrl.trim();
    if (link.isNotEmpty) {
      final uri = Uri.tryParse(link);
      if (uri != null && uri.path.isNotEmpty) {
        final segs = uri.pathSegments.where((s) => s.trim().isNotEmpty).toList();
        if (segs.isNotEmpty) {
          slug = segs.last.trim();
        }
      }
    }
    if (slug.isEmpty) {
      slug = item.id.trim().isNotEmpty ? 'id-${item.id.trim()}' : 'detail';
    }
    trackScreen('/app/news/$slug');
  }

  Future<void> _send(String path) async {
    try {
      final visitorId = await _getOrCreateVisitorId();
      final payload = <String, dynamic>{
        'url': path,
        'source': 'apk_bungtemin',
        'device': _deviceLabel(),
        if (visitorId.isNotEmpty) 'visitor_id': visitorId,
      };
      await http
          .post(
            Uri.parse(_endpoint),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'User-Agent': _userAgent(),
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      // Abaikan error jaringan agar tidak mengganggu pengalaman pengguna.
    }
  }
}

/// NavigatorObserver opsional untuk otomatis mencatat route bernama (named routes).
class AppAnalyticsObserver extends NavigatorObserver {
  void _trackRoute(Route<dynamic>? route) {
    if (route is! PageRoute) return;
    final name = route.settings.name?.trim() ?? '';
    if (name.isEmpty || name == '/') return;
    AppAnalyticsService.instance.trackScreen(name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _trackRoute(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _trackRoute(newRoute);
  }
}

/// Wrapper ringan untuk memicu tracking 1x saat StatelessWidget screen dibuka.
class ScreenViewTracker extends StatefulWidget {
  const ScreenViewTracker({
    super.key,
    required this.onTrack,
    required this.child,
  });

  final VoidCallback onTrack;
  final Widget child;

  @override
  State<ScreenViewTracker> createState() => _ScreenViewTrackerState();
}

class _ScreenViewTrackerState extends State<ScreenViewTracker> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onTrack();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
