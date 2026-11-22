import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_info.dart';
import 'core/net/offline_first_client.dart';
import 'core/session_store.dart';
import 'core/theme.dart';
import 'features/shell/main_shell.dart';
import 'features/shell/service_block_screen.dart';
import 'features/tutorial/tutorial_screen.dart';
import 'services/app_control_service.dart';
import 'services/deep_link_service.dart';
import 'services/fcm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppInfo.init();
  // Android 15+ Edge-to-Edge: gambar konten di belakang status & navigation bar,
  // inset ditangani lewat MediaQuery padding / SafeArea di tiap layar.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  PaintingBinding.instance.imageCache.maximumSize = 500;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 150 << 20;
  runApp(const BungteminFlutterApp());
}

class BungteminFlutterApp extends StatefulWidget {
  const BungteminFlutterApp({super.key});

  @override
  State<BungteminFlutterApp> createState() => _BungteminFlutterAppState();
}

class _BungteminFlutterAppState extends State<BungteminFlutterApp>
    with WidgetsBindingObserver {
  final _store = SessionStore();
  final _appControl = AppControlService();
  UserSession? _session;
  bool _didTutorial = false;
  bool _ready = false;
  bool _checkingControl = false;
  AppControlStatus _controlStatus = AppControlStatus.online;
  Timer? _controlTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
    _controlTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _refreshControlStatus(),
    );
  }

  @override
  void dispose() {
    _controlTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshControlStatus();
    }
  }

  Future<void> _bootstrap() async {
    // Local-first: tampilkan app segera dari data lokal, jangan menunggu jaringan.
    // Status AppControl (maintenance/shutdown) dicek di belakang layar.
    final results = await Future.wait([
      _store.hasSeenTutorial(),
      _store.load(),
    ]);
    if (!mounted) return;
    final loadedSession = results[1] as UserSession?;
    setState(() {
      _didTutorial = results[0] as bool;
      _session = loadedSession;
      _ready = true;
    });
    unawaited(_refreshControlStatus());
    unawaited(FcmService.instance.init(initialNoreg: loadedSession?.noreg));
    unawaited(DeepLinkService.instance.init());
  }

  Future<void> _refreshControlStatus() async {
    if (_checkingControl) return;
    setState(() => _checkingControl = true);
    final latest = await _appControl.fetchStatus();
    if (!mounted) return;
    setState(() {
      _controlStatus = latest;
      _checkingControl = false;
    });
  }

  Future<void> _completeTutorial() async {
    await _store.setTutorialSeen(true);
    if (!mounted) return;
    setState(() => _didTutorial = true);
  }

  Future<void> _handleLogout() async {
    final prevNoreg = _session?.noreg;
    await _store.clear();
    if (!mounted) return;
    setState(() => _session = null);
    unawaited(FcmService.instance.clearUser(prevNoreg));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bungtemin',
      debugShowCheckedModeBanner: false,
      theme: buildBungteminTheme(),
      builder: (context, child) => _OfflineBanner(child: child),
      home: !_ready
          ? const Scaffold(
              backgroundColor: AppColors.navy,
              body: Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              ),
            )
          : _controlStatus.isBlocked
              ? ServiceBlockScreen(
                  status: _controlStatus,
                  checking: _checkingControl,
                  onRetry: _refreshControlStatus,
                )
              : !_didTutorial
                  ? TutorialScreen(onComplete: _completeTutorial)
                  : MainShellScreen(
                      session: _session,
                      onAuthenticated: (s) {
                        setState(() => _session = s);
                        unawaited(FcmService.instance.syncUser(s.noreg));
                      },
                      onLogout: _handleLogout,
                      onOpenTutorial: () =>
                          setState(() => _didTutorial = false),
                    ),
    );
  }
}

/// Strip kecil di bawah layar saat aplikasi menampilkan data dari cache lokal.
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final content = child ?? const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: OfflineFirstClient.offline,
      builder: (context, isOffline, _) {
        // Struktur tree selalu sama agar state Navigator tidak ter-reset.
        return Column(
          children: [
            // Saat offline, banner yang menangani inset bawah.
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: isOffline,
                child: content,
              ),
            ),
            if (isOffline) const Material(
              color: Color(0xFF7C2D12),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off, size: 14, color: Colors.white),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Offline — menampilkan data tersimpan',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
