class BungteminMenuItem {
  const BungteminMenuItem({
    required this.label,
    required this.iconAsset,
    required this.route,
    required this.requiresLogin,
    this.group = 'extra',
    this.mode = 'online',
    this.maintenanceMessage = '',
  });

  final String label;
  final String iconAsset;
  final String route;
  final bool requiresLogin;
  final String group;
  final String mode;
  final String maintenanceMessage;

  bool get isMaintenance => mode.toLowerCase() == 'maintenance';
  bool get isOff => mode.toLowerCase() == 'off' || mode.toLowerCase() == 'shutdown';

  factory BungteminMenuItem.fromJson(Map<String, dynamic> json) {
    final rawLink = json['route'] ?? json['routerLink'];
    var resolvedRoute = '/home';
    if (rawLink is String) {
      resolvedRoute = rawLink;
    } else if (rawLink is Map) {
      resolvedRoute = (rawLink['loggedIn'] ?? rawLink['loggedOut'] ?? '/home')
          .toString();
    }
    final label = (json['label'] ?? 'Menu').toString();
    if (label.trim().toLowerCase() == 'bubabe') {
      resolvedRoute = '/bubabe';
    }
    return BungteminMenuItem(
      label: label,
      iconAsset: (json['icon'] ?? 'assets/icon/1.png').toString(),
      route: resolvedRoute,
      requiresLogin:
          json['requiresLogin'] == true ||
          requiresLoginFor(resolvedRoute, label: label),
      group: (json['group'] ?? 'extra').toString(),
      mode: (json['mode'] ?? 'online').toString(),
      maintenanceMessage: (json['maintenance_message'] ?? '').toString(),
    );
  }

  /// Menentukan apakah suatu rute atau label menu wajib login anggota.
  /// Dipakai untuk menyelaraskan `NewMenu` remote, cache lokal, drawer, dan push route.
  static bool requiresLoginFor(String route, {String label = ''}) {
    final r = route.trim().toLowerCase();
    final l = label.trim().toLowerCase();

    if (r.startsWith('/aplikasi/note') || l == 'bucat') return false;
    if (r.startsWith('/aplikasi/todo') || l == 'kodawari') return false;

    if (r.startsWith('/profil') ||
        r.startsWith('/idcard') ||
        r.startsWith('/kta') ||
        r.startsWith('/training') ||
        r.startsWith('/scanner') ||
        r.startsWith('/meeting') ||
        r.startsWith('/organisasi') ||
        r.startsWith('/aplikasi') ||
        r.startsWith('/myscanner') ||
        r.startsWith('/lapor') ||
        r.startsWith('/hallopuk') ||
        r.startsWith('/tabfeed') ||
        r.startsWith('/feed') ||
        r.startsWith('/quiz') ||
        r.startsWith('/pretest') ||
        r.startsWith('/chat')) {
      return true;
    }

    return const {
      'pintar',
      'profil',
      'btscan',
      'meeting',
      'organisasi',
      'btapp',
      'hallo puk',
      'cerita',
      'myars',
      'quiz',
      'pretest',
      'chat',
    }.contains(l);
  }

  /// Menu bawaan sesuai respons resmi `nudb.bungtemin.net/data/NewMenu`.
  static const List<BungteminMenuItem> defaults = [
    BungteminMenuItem(
      label: 'Berita',
      iconAsset: 'assets/icon/1.png',
      route: '/news',
      requiresLogin: false,
      group: 'main',
    ),
    BungteminMenuItem(
      label: 'Cerita',
      iconAsset: 'assets/icon/2.png',
      route: '/tabfeed/feed',
      requiresLogin: true,
      group: 'main',
    ),
    BungteminMenuItem(
      label: 'Tonton',
      iconAsset: 'assets/icon/13.png',
      route: '/tonton',
      requiresLogin: false,
      group: 'main',
    ),
    BungteminMenuItem(
      label: 'Pintar',
      iconAsset: 'assets/icon/4.png',
      route: '/training',
      requiresLogin: true,
      group: 'main',
    ),
    BungteminMenuItem(
      label: 'Hallo PUK',
      iconAsset: 'assets/icon/3.png',
      route: '/lapor',
      requiresLogin: true,
      group: 'main',
    ),
    BungteminMenuItem(
      label: 'Meeting',
      iconAsset: 'assets/icon/23.png',
      route: '/meeting',
      requiresLogin: true,
      group: 'main',
    ),
    BungteminMenuItem(
      label: 'Organisasi',
      iconAsset: 'assets/icon/7.png',
      route: '/organisasi',
      requiresLogin: true,
      group: 'main',
    ),
    BungteminMenuItem(
      label: 'BTapp',
      iconAsset: 'assets/icon/12.png',
      route: '/aplikasi',
      requiresLogin: true,
      group: 'main',
    ),
    BungteminMenuItem(
      label: 'Struktur',
      iconAsset: 'assets/icon/7.png',
      route: '/struktur',
      requiresLogin: false,
      group: 'main',
    ),
    BungteminMenuItem(
      label: 'Profil',
      iconAsset: 'assets/icon/8.png',
      route: '/profil',
      requiresLogin: true,
      group: 'main',
    ),
    BungteminMenuItem(
      label: 'BTScan',
      iconAsset: 'assets/icon/9.png',
      route: '/scanner',
      requiresLogin: true,
      group: 'main',
    ),
    BungteminMenuItem(
      label: 'Kalender',
      iconAsset: 'assets/icon/10.png',
      route: '/kalender',
      requiresLogin: false,
    ),
    BungteminMenuItem(
      label: 'Proker',
      iconAsset: 'assets/icon/6.png',
      route: '/proker',
      requiresLogin: false,
    ),
    BungteminMenuItem(
      label: 'Keuangan',
      iconAsset: 'assets/icon/5.png',
      route: '/keuangan',
      requiresLogin: false,
    ),
    BungteminMenuItem(
      label: 'MyArs',
      iconAsset: 'assets/icon/15.png',
      route: '/aplikasi/absensi/tiketlist',
      requiresLogin: true,
    ),
    BungteminMenuItem(
      label: 'Bubabe',
      iconAsset: 'assets/icon/16.png',
      route: '/bubabe',
      requiresLogin: false,
    ),
    BungteminMenuItem(
      label: 'Quiz',
      iconAsset: 'assets/icon/14.png',
      route: '/quiz/lobby',
      requiresLogin: true,
    ),
    BungteminMenuItem(
      label: 'Pretest',
      iconAsset: 'assets/icon/17.png',
      route: '/pretest/lobby',
      requiresLogin: true,
    ),
    BungteminMenuItem(
      label: 'Bucat',
      iconAsset: 'assets/icon/18.png',
      route: '/aplikasi/note',
      requiresLogin: false,
    ),
    BungteminMenuItem(
      label: 'Kodawari',
      iconAsset: 'assets/icon/20.png',
      route: '/aplikasi/todo',
      requiresLogin: false,
    ),
    BungteminMenuItem(
      label: 'Buku Pintar',
      iconAsset: 'assets/icon/25.png',
      route: '/pintar',
      requiresLogin: false,
    ),
    BungteminMenuItem(
      label: 'Chat',
      iconAsset: 'assets/icon/22.png',
      route: '/chat',
      requiresLogin: true,
    ),
    BungteminMenuItem(
      label: 'Saran App',
      iconAsset: 'assets/icon/24.png',
      route: '/saran',
      requiresLogin: false,
    ),
  ];
}
