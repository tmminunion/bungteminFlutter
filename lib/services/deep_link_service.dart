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
      // Beranda & Kotak Masuk
      case 'home':
      case 'beranda':
        return '/home';
      case 'inbox':
      case 'pengumuman':
      case 'notifikasi':
        return '/inbox';

      // Menu Utama (Main)
      case 'berita':
      case 'news':
        return '/news';
      case 'cerita':
      case 'feed':
      case 'tabfeed':
        return '/tabfeed/feed';
      case 'tonton':
      case 'video':
        return '/tonton';
      case 'pintar':
      case 'training':
        return rest.isNotEmpty ? '/training/$rest' : '/training';
      case 'training-pleno':
        return '/training-pleno';
      case 'training-ticket':
        return '/training-ticket';
      case 'lapor':
      case 'hallopuk':
      case 'hallo-puk':
      case 'hallo_puk':
        return rest.isNotEmpty ? '/lapor/$rest' : '/lapor';
      case 'meeting':
      case 'rapat':
        return rest.isNotEmpty ? '/meeting/$rest' : '/meeting';
      case 'organisasi':
      case 'org':
        return '/organisasi';
      case 'btapp':
      case 'aplikasi':
        return rest.isNotEmpty ? '/aplikasi/$rest' : '/aplikasi';
      case 'struktur':
        return '/struktur';
      case 'profil':
      case 'profile':
        return '/profil';
      case 'kta':
      case 'idcard':
        return '/kta';
      case 'btscan':
      case 'scanner':
      case 'scan':
        return '/scanner';
      case 'myscanner':
        return rest.isNotEmpty ? '/myscanner/$rest' : '/aplikasi/absensi';
      case 'kalender':
      case 'calendar':
        return '/kalender';

      // Menu Tambahan (Extra)
      case 'proker':
        return '/proker';
      case 'keuangan':
      case 'finance':
        return '/keuangan';
      case 'myars':
      case 'tiket':
      case 'tiketlist':
        return '/aplikasi/absensi/tiketlist';
      case 'tiketdetail':
        return rest.isNotEmpty
            ? '/aplikasi/absensi/tiketdetail/$rest'
            : '/aplikasi/absensi/tiketlist';
      case 'absensi':
      case 'event':
      case 'events':
        return rest.isNotEmpty
            ? '/aplikasi/absensi/absensidetail/$rest'
            : '/aplikasi/absensilist';
      case 'bubabe':
        return '/bubabe';
      case 'quiz':
        return '/quiz/lobby';
      case 'pretest':
        return '/pretest/lobby';
      case 'bucat':
      case 'note':
      case 'catatan':
        return '/aplikasi/note';
      case 'kodawari':
      case 'todo':
        return '/aplikasi/todo';
      case 'buku':
      case 'buku-pintar':
      case 'buku_pintar':
      case 'bukupintar':
        return rest.isNotEmpty ? '/buku/$rest' : '/pintar';
      case 'chat':
        return rest.isNotEmpty ? '/chat/$rest' : '/chat';
      case 'saran':
      case 'feedback':
      case 'saran-app':
      case 'saran_app':
        return '/saran';
      case 'nfc':
      case 'emoney':
      case 'cek-emoney':
      case 'cek_emoney':
      case 'nfc-emoney':
        return '/nfc-emoney';
      case 'contact':
      case 'hubungi':
        return '/contact';
      case 'tutorial':
        return '/tutorial';

      default:
        return '/${segments.join('/')}';
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _controller.close();
  }
}
