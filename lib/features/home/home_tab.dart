import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/app_info.dart';
import '../../core/cached_image.dart';
import '../../core/session_store.dart';
import '../../core/theme.dart';
import '../../models/bungtemin_menu.dart';
import '../../models/meeting_item.dart';
import '../../models/news_item.dart';
import '../../services/bungtemin_api.dart';
import '../../services/inbox_service.dart';
import '../inbox/broadcast_inbox_screen.dart';
import '../news/news_detail_screen.dart';
import 'promo_modal_dialog.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({
    super.key,
    required this.session,
    required this.onOpenDrawer,
    required this.onNavigateTab,
    required this.onOpenNews,
    required this.onRequireLogin,
    required this.onMenuTap,
  });

  final UserSession? session;
  final VoidCallback onOpenDrawer;
  final ValueChanged<int> onNavigateTab;
  final ValueChanged<int> onOpenNews;
  final void Function(String reason, VoidCallback afterLogin) onRequireLogin;
  final ValueChanged<BungteminMenuItem> onMenuTap;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _api = BungteminApi();
  final _inboxService = InboxService();
  final _bannerCtrl = PageController();
  Timer? _bannerTimer;

  int _bannerPage = 0;
  int _unreadInboxCount = 0;
  bool _loadingNews = true;
  bool _notificationsRead = false;
  bool _promoChecked = false;
  List<String> _banners = [
    for (var i = 1; i <= 6; i++)
      'https://bungtemin.net/assets/img/ads/$i.jpg?v=new',
  ];
  List<BungteminMenuItem> _menus = BungteminMenuItem.defaults;
  List<NewsItem> _internalNews = const [];
  List<NewsItem> _externalNews = const [];
  List<StoryItem> _stories = const [];

  @override
  void initState() {
    super.initState();
    _loadCachedHomeData();
    _loadAll();
    _loadUnreadInboxCount();
    _startBannerAutoPlay();
    _checkAndShowPromoModal();
  }

  @override
  void didUpdateWidget(covariant HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session?.noreg != widget.session?.noreg) {
      _loadUnreadInboxCount();
    }
  }

  Future<void> _loadUnreadInboxCount() async {
    if (widget.session == null) {
      if (mounted && _unreadInboxCount != 0) {
        setState(() => _unreadInboxCount = 0);
      }
      return;
    }
    try {
      final res = await _inboxService.fetchList();
      if (!mounted) return;
      setState(() => _unreadInboxCount = res.unreadCount);
    } catch (_) {
      // Abaikan error jaringan agar tidak mengganggu home
    }
  }

  Future<void> _openInboxWithRefresh() async {
    if (widget.session == null) {
      widget.onRequireLogin(
        'Masuk terlebih dahulu untuk membuka Kotak Masuk Broadcast.',
        () => _openInboxWithRefresh(),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const BroadcastInboxScreen(),
      ),
    );
    if (mounted) {
      _loadUnreadInboxCount();
    }
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerCtrl.dispose();
    super.dispose();
  }

  void _startBannerAutoPlay() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_bannerCtrl.hasClients || _banners.isEmpty) return;
      final next = (_bannerPage + 1) % _banners.length;
      _bannerCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _checkAndShowPromoModal() async {
    if (_promoChecked) return;
    _promoChecked = true;

    void handleRoute(String route) {
      final r = route.toLowerCase();
      if (r.startsWith('/news')) {
        widget.onOpenNews(0);
        return;
      }
      if (r.startsWith('/tabfeed') || r.startsWith('/feed')) {
        widget.onNavigateTab(2);
        return;
      }
      final matched = _menus.where((m) => m.route.toLowerCase() == r);
      if (matched.isNotEmpty) {
        widget.onMenuTap(matched.first);
      } else {
        widget.onOpenNews(0);
      }
    }

    final promoCfg = await _api.fetchPromoAndUpdateConfig();
    if (!mounted) return;

    // 1. Cek notifikasi update aplikasi Play Store jika versi berbeda/lebih lama
    if (promoCfg != null && promoCfg['app_update'] is Map) {
      final upd = Map<String, dynamic>.from(promoCfg['app_update'] as Map);
      final enabled = upd['enabled'] == true;
      final latestVer = (upd['latest_version'] ?? '').toString().trim();
      final latestBuild =
          int.tryParse((upd['latest_build'] ?? '0').toString()) ?? 0;
      if (enabled &&
          latestVer.isNotEmpty &&
          AppInfo.isOlderThan(latestVer, latestBuild)) {
        await PromoModalHelper.showUpdateDialog(context, updateInfo: upd);
        if (!mounted) return;
      }
    }

    if (await PromoModalHelper.isHiddenToday()) return;

    // 2. Tampilkan Multi Promo dari /btapi/Promo (atau fallback NUDB PromoModal)
    final promos = <Map<String, dynamic>>[];
    if (promoCfg != null && promoCfg['promos'] is List) {
      for (final p in (promoCfg['promos'] as List)) {
        if (p is Map) {
          promos.add(Map<String, dynamic>.from(p));
        }
      }
    }
    if (promos.isEmpty) {
      final nudbPromo = await _api.fetchPromoModal();
      if (nudbPromo != null) {
        promos.add(nudbPromo);
      }
    }
    if (promos.isEmpty || !mounted) return;

    await PromoModalHelper.showMulti(
      context,
      promos: promos,
      onInternalRoute: handleRoute,
    );
  }

  Future<void> _loadCachedHomeData() async {
    final results = await Future.wait([
      SessionStore().loadMenuCache(),
      _api.loadCachedHeroBanners(),
      _api.loadCachedInternalNews(),
      _api.loadCachedExternalNews(),
    ]);
    if (!mounted) return;
    final cachedMenu = results[0] as String?;
    final cachedBanners = results[1] as List<String>;
    final cachedInternal = results[2] as List<NewsItem>;
    final cachedExternal = results[3] as List<NewsItem>;
    setState(() {
      if (cachedMenu != null) {
        final parsed = BungteminApi.parseMenuJson(cachedMenu);
        if (parsed.isNotEmpty) _menus = parsed;
      }
      if (cachedBanners.isNotEmpty) _banners = cachedBanners;
      if (cachedInternal.isNotEmpty) _internalNews = cachedInternal;
      if (cachedExternal.isNotEmpty) _externalNews = cachedExternal;
      if (cachedInternal.isNotEmpty || cachedExternal.isNotEmpty) {
        _loadingNews = false;
      }
    });
  }

  Future<void> _loadAll() async {
    unawaited(_loadUnreadInboxCount());
    if (_internalNews.isEmpty && _externalNews.isEmpty) {
      setState(() => _loadingNews = true);
    }
    try {
      final results = await Future.wait([
        _api.fetchHeroBanners(),
        _api.fetchMenus(),
        _api.fetchInternalNews(limit: 8),
        _api.fetchExternalNews(limit: 10),
        _api.fetchStories(),
      ]);
      if (!mounted) return;
      setState(() {
        _banners = results[0] as List<String>;
        _menus = results[1] as List<BungteminMenuItem>;
        final internal = results[2] as List<NewsItem>;
        final external = results[3] as List<NewsItem>;
        if (internal.isNotEmpty) _internalNews = internal;
        if (external.isNotEmpty) _externalNews = external;
        _stories = results[4] as List<StoryItem>;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingNews = false);
      }
    }
  }

  List<BungteminMenuItem> get _activeMenus =>
      _menus.where((m) => !m.isOff).toList();

  List<BungteminMenuItem> get _mainMenus {
    final active = _activeMenus;
    final hasExplicitMain = active.any((m) => m.group == 'main');
    if (hasExplicitMain) {
      final mains = active.where((m) => m.group == 'main').toList();
      if (mains.length <= 11) return mains;
      return mains.sublist(0, 11);
    }
    return active.length > 11 ? active.sublist(0, 11) : active;
  }

  List<BungteminMenuItem> get _extraMenus {
    final active = _activeMenus;
    final mains = _mainMenus;
    final mainRoutes = mains.map((m) => m.route.trim().toLowerCase()).toSet();
    final base = active
        .where((m) => !mainRoutes.contains(m.route.trim().toLowerCase()))
        .toList();

    // Jika data masih dari NewMenu lama (tidak punya key/group dari /btapi/Menu/list),
    // tetap gabungkan item baru dari BungteminMenuItem.defaults.
    final isControlled = active.any((m) => m.group == 'main');
    if (!isControlled) {
      final existingRoutes = _menus.map((m) => m.route.trim().toLowerCase()).toSet();
      final existingLabels = _menus.map((m) => m.label.trim().toLowerCase()).toSet();
      for (final def in BungteminMenuItem.defaults) {
        final r = def.route.trim().toLowerCase();
        final l = def.label.trim().toLowerCase();
        if (!existingRoutes.contains(r) && !existingLabels.contains(l)) {
          base.add(def);
          existingRoutes.add(r);
          existingLabels.add(l);
        }
      }
      if (!existingRoutes.any((r) => r.contains('nfc'))) {
        base.add(
          const BungteminMenuItem(
            label: 'Cek E-Money',
            iconAsset: 'assets/icon/5.png',
            route: '/nfc-emoney',
            requiresLogin: false,
          ),
        );
      }
    }
    return base;
  }

  bool get _hasNotificationDot =>
      !_notificationsRead &&
      (widget.session == null ||
          _internalNews.isNotEmpty ||
          _externalNews.isNotEmpty);

  void _handleBannerTap(int idx) {
    final url = idx >= 0 && idx < _banners.length ? _banners[idx] : '';
    final match = RegExp(r'/(\d+)\.(?:jpg|jpeg|png|webp)', caseSensitive: false)
        .firstMatch(url);
    final slot = int.tryParse(match?.group(1) ?? '') ?? (idx + 1);

    switch (slot) {
      case 1:
        widget.onMenuTap(
          const BungteminMenuItem(
            label: 'Struktur',
            iconAsset: 'assets/icon/7.png',
            route: '/struktur',
            requiresLogin: false,
          ),
        );
      case 2:
        _openMoreSheet();
      case 3:
        widget.onOpenNews(0);
      case 4:
        widget.onMenuTap(
          const BungteminMenuItem(
            label: 'Pintar',
            iconAsset: 'assets/icon/4.png',
            route: '/training',
            requiresLogin: true,
          ),
        );
      case 5:
        if (widget.session != null) {
          widget.onNavigateTab(2);
        } else {
          widget.onRequireLogin(
            'Masuk ke akun anggota untuk membuka KTA Digital & Agenda.',
            () => widget.onNavigateTab(2),
          );
        }
      case 6:
      default:
        widget.onMenuTap(
          const BungteminMenuItem(
            label: 'BTScan',
            iconAsset: 'assets/icon/9.png',
            route: '/scanner',
            requiresLogin: true,
          ),
        );
    }
  }

  void _openMoreSheet() {
    var query = '';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final normalized = query.trim().toLowerCase();
          final source = normalized.isEmpty ? _extraMenus : _menus;
          final items = normalized.isEmpty
              ? source
              : source
                  .where((m) => m.label.toLowerCase().contains(normalized))
                  .toList();

          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFDFCFB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              image: DecorationImage(
                image: AssetImage('assets/card/bg.png'),
                fit: BoxFit.cover,
                alignment: Alignment.center,
                opacity: 0.9,
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(ctx).viewInsets.bottom +
                  MediaQuery.of(ctx).padding.bottom +
                  24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Eksplorasi Layanan',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Pilih fitur dan menu tambahan Bungtemin',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surface,
                      ),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  onChanged: (val) => setSheetState(() => query = val),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Cari menu (misal: KTA, Pintar, Quiz, Bucat)...',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: AppColors.muted,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.88),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppColors.primaryBlue,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'Menu tidak ditemukan.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.85,
                    ),
                    itemBuilder: (_, idx) {
                      final item = items[idx];
                      return _MenuGridTile(
                        item: item,
                        isLoggedIn: widget.session != null,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          widget.onMenuTap(item);
                        },
                      );
                    },
                  ),
              ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showNotificationsSheet() {
    if (!_notificationsRead) {
      setState(() => _notificationsRead = true);
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          MediaQuery.of(ctx).padding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Notifikasi Bungtemin',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.12),
                child: const Icon(
                  Icons.newspaper_rounded,
                  color: AppColors.primaryBlue,
                ),
              ),
              title: const Text(
                'Berita Internal & Eksternal Terkini',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
              subtitle: Text(
                '${_internalNews.length} kabar internal & ${_externalNews.length} berita eksternal siap dibaca.',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                widget.onOpenNews(0);
              },
            ),
            if (widget.session == null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.amber.withValues(alpha: 0.14),
                  child: const Icon(
                    Icons.lock_open_rounded,
                    color: AppColors.amber,
                  ),
                ),
                title: const Text(
                  'Masuk Akun Anggota',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                subtitle: const Text(
                  'Login untuk mengakses KTA Digital 3D, Meeting, Pintar & Profil.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  widget.onRequireLogin(
                    'Masuk ke akun anggota untuk membuka KTA, Meeting, Pintar & Profil.',
                    () {},
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    const bannerHeight = 290.0;
    const overlapOffset = 98.0;

    return Container(
      color: AppColors.surface,
      child: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            // HERO BANNER + FLOATING TOP BAR + OVERLAPPING GLASS MENU CARD
            Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. Hero Top Section
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(32),
                  ),
                  child: Container(
                    height: bannerHeight,
                    color: AppColors.navy,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        PageView.builder(
                          controller: _bannerCtrl,
                          itemCount: _banners.length,
                          onPageChanged: (idx) =>
                              setState(() => _bannerPage = idx),
                          itemBuilder: (_, idx) {
                            final bannerFallback = Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.navy,
                                    AppColors.navyMid,
                                    AppColors.blueAccent,
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset(
                                      'assets/img/appicon.png',
                                      width: 56,
                                      height: 56,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'PUK SP LEM SPSI PT. TMMIN',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _handleBannerTap(idx),
                              child: BungteminCachedImage(
                                imageUrl: _banners[idx],
                                fit: BoxFit.cover,
                                memCacheWidth: 1080,
                                placeholder: bannerFallback,
                                errorWidget: bannerFallback,
                              ),
                            );
                          },
                        ),
                        // Top-to-bottom scrim fading into surface
                        IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: const [0.0, 0.3, 0.55, 1.0],
                                colors: [
                                  AppColors.navy.withValues(alpha: 0.48),
                                  Colors.transparent,
                                  Colors.transparent,
                                  AppColors.surface.withValues(alpha: 0.94),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Banner dots
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: overlapOffset + 14,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(_banners.length, (i) {
                              final active = i == _bannerPage;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                width: active ? 18 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: active
                                      ? AppColors.auroraCyan
                                      : Colors.white.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Floating Top App Bar
                Positioned(
                  top: topPad + 10,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _TopGlassButton(
                        icon: Icons.menu_rounded,
                        tooltip: 'Menu Samping',
                        onTap: widget.onOpenDrawer,
                      ),
                      Row(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              _TopGlassButton(
                                icon: Icons.mail_outline_rounded,
                                tooltip: 'Kotak Masuk Broadcast',
                                onTap: _openInboxWithRefresh,
                              ),
                              if (_unreadInboxCount > 0)
                                Positioned(
                                  top: -3,
                                  right: -3,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1.5,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 18,
                                      minHeight: 18,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.rose,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.rose
                                              .withValues(alpha: 0.65),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      _unreadInboxCount > 99
                                          ? '99+'
                                          : '$_unreadInboxCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              _TopGlassButton(
                                icon: Icons.notifications_none_rounded,
                                tooltip: 'Notifikasi',
                                onTap: _showNotificationsSheet,
                              ),
                              if (_hasNotificationDot)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: AppColors.rose,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.rose
                                              .withValues(alpha: 0.8),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 3. Overlapping Glass Main Card
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    bannerHeight - overlapOffset,
                    16,
                    0,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDFCFB),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white,
                        width: 1.5,
                      ),
                      image: const DecorationImage(
                        image: AssetImage('assets/card/bg.png'),
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        opacity: 0.92,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.navy.withValues(alpha: 0.14),
                          blurRadius: 34,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28.5),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -18,
                            bottom: -18,
                            child: IgnorePointer(
                              child: Opacity(
                                opacity: 0.045,
                                child: Image.asset(
                                  'assets/card/logospsi.png',
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                            child: Column(
                              children: [
                                // Member Strip OR Guest Strip
                                _IdentityStrip(
                                  session: widget.session,
                                  onOpenProfil: () => widget.onNavigateTab(4),
                                  onOpenKta: () => widget.onNavigateTab(2),
                                  onOpenLogin: () => widget.onRequireLogin(
                                    'Masuk ke akun anggota Bungtemin untuk akses KTA & Training.',
                                    () {},
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // 4x3 Menu Grid (11 menus + Lainnya)
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: EdgeInsets.zero,
                                  itemCount: _mainMenus.length + 1,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 6,
                                    childAspectRatio: 0.86,
                                  ),
                                  itemBuilder: (_, idx) {
                                    if (idx == _mainMenus.length) {
                                      return _MoreMenuTile(
                                        onTap: _openMoreSheet,
                                      );
                                    }
                                    final item = _mainMenus[idx];
                                    return _MenuGridTile(
                                      item: item,
                                      isLoggedIn: widget.session != null,
                                      onTap: () => widget.onMenuTap(item),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // BERITA INTERNAL SECTION
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SectionHeader(
                icon: Icons.newspaper_rounded,
                iconBg: AppColors.primaryBlue,
                title: 'Berita Internal',
                subtitle: 'Kabar dan agenda resmi',
                onSeeAll: () => widget.onOpenNews(0),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 226,
              child: _loadingNews && _internalNews.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _internalNews.isEmpty
                      ? const _EmptyNewsBanner(
                          text: 'Belum ada berita internal saat ini.',
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _internalNews.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 14),
                          itemBuilder: (context, idx) {
                            final item = _internalNews[idx];
                            return _InternalNewsCard(
                              item: item,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => NewsDetailScreen(item: item),
                                ),
                              ),
                            );
                          },
                        ),
            ),

            const SizedBox(height: 24),

            // TRENDING EKSTERNAL SECTION
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SectionHeader(
                icon: Icons.local_fire_department_rounded,
                iconBg: AppColors.indigo,
                title: 'Trending Eksternal',
                subtitle: 'Sorotan berita & informasi terkini',
                onSeeAll: () => widget.onOpenNews(1),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 196,
              child: _loadingNews && _externalNews.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _externalNews.isEmpty
                      ? const _EmptyNewsBanner(
                          text: 'Memuat berita eksternal terkini...',
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _externalNews.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, idx) {
                            final item = _externalNews[idx];
                            return _ExternalMiniCard(
                              item: item,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => NewsDetailScreen(item: item),
                                ),
                              ),
                            );
                          },
                        ),
            ),

            // STORIES KOMUNITAS (jika ada)
            if (_stories.isNotEmpty) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SectionHeader(
                  icon: Icons.auto_stories_rounded,
                  iconBg: AppColors.emerald,
                  title: 'Cerita Komunitas',
                  subtitle: 'Momen terbaru anggota TMMIN',
                  onSeeAll: () => widget.onMenuTap(
                    const BungteminMenuItem(
                      label: 'Cerita',
                      iconAsset: 'assets/icon/2.png',
                      route: '/tabfeed/feed',
                      requiresLogin: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 152,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _stories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, idx) {
                    final s = _stories[idx];
                    return Container(
                      width: 116,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: AppColors.navySoft,
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.45),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (s.mediaUrl.isNotEmpty)
                            BungteminCachedImage(
                              imageUrl: s.mediaUrl,
                              fit: BoxFit.cover,
                              memCacheWidth: 360,
                              errorWidget: const Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: Colors.white38,
                                ),
                              ),
                            ),
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black87],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 8,
                            right: 8,
                            bottom: 8,
                            child: Text(
                              s.nama.isNotEmpty ? s.nama : 'Anggota',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopGlassButton extends StatelessWidget {
  const _TopGlassButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.navy.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
            ),
            child: Icon(icon, color: Colors.white, size: 21),
          ),
        ),
      ),
    );
  }
}

class _IdentityStrip extends StatelessWidget {
  const _IdentityStrip({
    required this.session,
    required this.onOpenProfil,
    required this.onOpenKta,
    required this.onOpenLogin,
  });

  final UserSession? session;
  final VoidCallback onOpenProfil;
  final VoidCallback onOpenKta;
  final VoidCallback onOpenLogin;

  @override
  Widget build(BuildContext context) {
    final loggedIn = session != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xE8F8FAFC), Color(0xE8EFF6FF)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: loggedIn ? onOpenProfil : onOpenLogin,
              borderRadius: BorderRadius.circular(14),
              child: Row(
                children: [
                  if (loggedIn)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          border: Border.all(
                            color: AppColors.primaryBlue,
                            width: 1.8,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: BungteminCachedImage(
                          imageUrl: session!.avatarUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: 160,
                          errorWidget: Image.asset(
                            'assets/img/default-avatar.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 42,
                      height: 42,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFDBEAFE)),
                      ),
                      child: Image.asset(
                        'assets/img/appicon.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loggedIn
                              ? 'ANGGOTA AKTIF'
                              : 'SELAMAT DATANG DI BUNGTEMIN',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryBlue,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          loggedIn
                              ? session!.nama
                              : 'Masuk untuk akses KTA & Training',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: loggedIn ? onOpenKta : onOpenLogin,
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryBlue, AppColors.indigo],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (loggedIn) ...[
                      const Icon(
                        Icons.badge_outlined,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'KTA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ] else ...[
                      const Text(
                        'Masuk',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuGridTile extends StatelessWidget {
  const _MenuGridTile({
    required this.item,
    required this.isLoggedIn,
    required this.onTap,
  });

  final BungteminMenuItem item;
  final bool isLoggedIn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final showLock = item.requiresLogin && !isLoggedIn;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 56,
                height: 56,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.88),
                      const Color(0xDCF8FAFC),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navy.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Opacity(
                  opacity: item.isMaintenance ? 0.52 : 1.0,
                  child: Image.asset(
                    item.iconAsset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.apps_rounded,
                      color: AppColors.primaryBlue,
                      size: 28,
                    ),
                  ),
                ),
              ),
              if (item.isMaintenance)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 1.3),
                    ),
                    child: const Text(
                      'MAINT',
                      style: TextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                )
              else if (showLock)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3.5),
                    decoration: BoxDecoration(
                      color: AppColors.navy,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.4),
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      size: 9.5,
                      color: AppColors.gold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.navySoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreMenuTile extends StatelessWidget {
  const _MoreMenuTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xE8EFF6FF), Color(0xDDE0E7FF)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Icon(
              Icons.grid_view_rounded,
              color: AppColors.primaryBlue,
              size: 26,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Lainnya',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.navySoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onSeeAll,
  });

  final IconData icon;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconBg.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconBg, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: onSeeAll,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Semua',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBlue,
                  ),
                ),
                SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppColors.primaryBlue,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InternalNewsCard extends StatelessWidget {
  const _InternalNewsCard({required this.item, required this.onTap});

  final NewsItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 122,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (item.imageUrl.isNotEmpty)
                      BungteminCachedImage(
                        imageUrl: item.imageUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 640,
                        placeholder: const _CardImagePlaceholder(
                          colors: [AppColors.navy, AppColors.primaryBlue],
                        ),
                        errorWidget: const _CardImagePlaceholder(
                          colors: [AppColors.navy, AppColors.primaryBlue],
                        ),
                      )
                    else
                      const _CardImagePlaceholder(
                        colors: [AppColors.navy, AppColors.primaryBlue],
                      ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'SPSI Update',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                          height: 1.3,
                        ),
                      ),
                      const Row(
                        children: [
                          Text(
                            'Baca Selengkapnya',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: AppColors.primaryBlue,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExternalMiniCard extends StatelessWidget {
  const _ExternalMiniCard({required this.item, required this.onTap});

  final NewsItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 168,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 102,
                width: double.infinity,
                child: item.imageUrl.isNotEmpty
                    ? BungteminCachedImage(
                        imageUrl: item.imageUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 480,
                        placeholder: const _CardImagePlaceholder(
                          colors: [AppColors.navyMid, AppColors.indigo],
                        ),
                        errorWidget: const _CardImagePlaceholder(
                          colors: [AppColors.navyMid, AppColors.indigo],
                        ),
                      )
                    : const _CardImagePlaceholder(
                        colors: [AppColors.navyMid, AppColors.indigo],
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    item.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardImagePlaceholder extends StatelessWidget {
  const _CardImagePlaceholder({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Image.asset('assets/icon/1.png', width: 42, height: 42),
      ),
    );
  }
}

class _EmptyNewsBanner extends StatelessWidget {
  const _EmptyNewsBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
