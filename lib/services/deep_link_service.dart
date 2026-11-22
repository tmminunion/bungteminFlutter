import 'dart:async';

import 'package:app_links/app_links.dart';

/// Menangani Android App Links (https://bungtemin.net/btapp/...) dan
/// custom scheme (btapp://...) agar tautan dari WhatsApp langsung membuka
/// layar tujuan di Bungtemin App tanpa melalui browser.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  final _controller = StreamController<Uri>.broadcast();
  StreamSubscription<Uri>? _sub;
  Uri? _pendingLaunchUri;
  bool _initialized = false;

  Stream<Uri> get onUri => _controller.stream;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null && _isSupportedUri(initial)) {
        _pendingLaunchUri = initial;
      }
    } catch (_) {}

    _sub = _appLinks.uriLinkStream.listen(
      (uri) {
        if (_isSupportedUri(uri)) {
          _controller.add(uri);
        }
      },
      onError: (_) {},
    );
  }

  Uri? consumePendingUri() {
    final u = _pendingLaunchUri;
    _pendingLaunchUri = null;
    return u;
  }

  static bool _isSupportedUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'btapp') return true;
    if ((scheme == 'https' || scheme == 'http') &&
        uri.host.toLowerCase() == 'bungtemin.net' &&
        uri.path.toLowerCase().startsWith('/btapp')) {
      return true;
    }
    return false;
  }

  /// Konversi URI https://bungtemin.net/btapp/<section>/<id> atau btapp://<section>/<id>
  /// menjadi route internal BungteminMenuItem yang dikenali MainShellScreen.
  static String resolveInternalRoute(Uri uri) {
    final segments = <String>[];
    if (uri.scheme.toLowerCase() == 'btapp') {
      if (uri.host.isNotEmpty) segments.add(uri.host);
      segments.addAll(uri.pathSegments.where((s) => s.isNotEmpty));
    } else {
      final raw = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (raw.isNotEmpty && raw.first.toLowerCase() == 'btapp') {
        segments.addAll(raw.skip(1));
      } else {
        segments.addAll(raw);
      }
    }

    if (segments.isEmpty) return '/home';
    final head = segments.first.toLowerCase();
    final rest = segments.length > 1 ? segments.sublist(1).join('/') : '';

    switch (head) {
      case 'home':
      case 'beranda':
        return '/home';
      case 'inbox':
      case 'pengumuman':
        return '/inbox';
      case 'feed':
      case 'tabfeed':
      case 'berita':
        return '/tabfeed';
      case 'meeting':
      case 'rapat':
        return rest.isNotEmpty ? '/meeting/$rest' : '/meeting';
      case 'tiket':
      case 'absensi':
      case 'myars':
        return '/aplikasi/absensi/tiketlist';
      case 'kta':
        return '/kta';
      case 'chat':
        return '/chat';
      case 'lapor':
      case 'feedback':
        return '/lapor';
      case 'kalender':
      case 'calendar':
        return '/calendar';
      case 'keuangan':
      case 'finance':
        return '/keuangan';
      case 'profil':
        return '/profil';
      default:
        return '/${segments.join('/')}';
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _controller.close();
  }
}
