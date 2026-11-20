import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_info.dart';
import '../../core/session_store.dart';
import '../../core/theme.dart';
import '../../models/bungtemin_menu.dart';
import '../../services/bungtemin_api.dart';
import '../../services/fcm_service.dart';
import '../about/contact_screen.dart';
import '../about/feedback_screen.dart';
import '../auth/login_screen.dart';
import '../calendar/calendar_screen.dart';
import '../chat/chat_inbox_screen.dart';
import '../inbox/broadcast_inbox_screen.dart';
import '../feed/tabfeed_screen.dart';
import '../home/home_tab.dart';
import '../kta/kta_tab.dart';
import '../lapor/lapor_screen.dart';
import '../meeting/meeting_hub_screen.dart';
import '../meeting/meeting_room_screen.dart';
import '../meeting/meeting_tab.dart';
import '../myars/myars_absensi_detail_screen.dart';
import '../myars/myars_event_scanner_screen.dart';
import '../myars/myars_events_screens.dart';
import '../myars/myars_tiket_detail_screen.dart';
import '../myars/myars_tiket_list_screen.dart';
import '../news/news_tab.dart';
import '../pintar/pintar_buku_screen.dart';
import '../pintar/training_listbulan_screen.dart';
import '../pintar/training_pleno_screen.dart';
import '../pintar/training_screen.dart';
import '../pintar/training_ticket_screen.dart';
import '../profil/profil_screen.dart';
import '../proker/proker_screen.dart';
import '../kodawari/kodawari_screen.dart';
import '../bucat/bucat_screen.dart';
import '../quiz/quiz_screen.dart';
import '../pretest/pretest_screen.dart';
import '../keuangan/keuangan_screen.dart';
import '../nfc/nfc_emoney_screen.dart';
import '../bubabe/bubabe_screen.dart';
import '../scanner/scanner_screen.dart';
import '../struktur/struktur_screen.dart';
import '../tonton/tonton_screen.dart';
import '../../core/net/btapi_auth.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({
    super.key,
    required this.session,
    required this.onAuthenticated,
    required this.onLogout,
    required this.onOpenTutorial,
  });

  final UserSession? session;
  final ValueChanged<UserSession> onAuthenticated;
  final VoidCallback onLogout;
  final VoidCallback onOpenTutorial;

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  StreamSubscription<PushPayload>? _pushTapSub;
  UserSession? _session;
  String _checkedPinNoreg = '';

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _pushTapSub = FcmService.instance.onNotificationTap.listen(_handlePushTap);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = FcmService.instance.consumePendingLaunchPayload();
      if (pending != null && mounted) {
        _handlePushTap(pending);
      }
      _checkTtlSecurityPrompt();
    });
  }

  @override
  void didUpdateWidget(covariant MainShellScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.session != oldWidget.session) {
      _session = widget.session;
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkTtlSecurityPrompt());
    }
  }

  @override
  void dispose() {
    _pushTapSub?.cancel();
    super.dispose();
  }

  Future<void> _checkTtlSecurityPrompt() async {
    final s = _session;
    if (!mounted || s == null || !s.isValid || s.token.trim().isEmpty) return;
    if (_checkedPinNoreg == s.noreg) return;
    _checkedPinNoreg = s.noreg;

    final hasPin = await BungteminApi().fetchPinStatus(token: s.token);
    if (!mounted || hasPin != false) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.security_rounded, color: Color(0xFFD97706)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ganti Password Tanggal Lahir',
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: const Text(
          'Akun Anda masih menggunakan tanggal lahir (TTL) untuk login. Demi keamanan, segera buat PIN atau kata sandi pribadi.',
          style: TextStyle(fontSize: 13.5, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Nanti'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ProfilScreen(session: s, initialSegment: 3),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Buat PIN Sekarang',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _openAccountSettings() {
    _requireLogin(
      'Masuk untuk mengatur PIN, No. WhatsApp & profil akun Anda.',
      () {
        final s = _session;
        if (s == null) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ProfilScreen(session: s, initialSegment: 3),
          ),
        );
      },
    );
  }

  void _openAppSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pengaturan Aplikasi',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Kelola cache data, panduan, dan sinkronisasi notifikasi',
                style: TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE0F2FE),
                  child: Icon(Icons.cleaning_services_rounded, color: Color(0xFF0284C7)),
                ),
                title: const Text('Bersihkan Cache Lokal', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Muat ulang berita, menu & data KTA terbaru', style: TextStyle(fontSize: 12)),
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  for (final k in [
                    'bt_menu_cache',
                    'bt_kta_cache',
                    'bt_struktur_cache',
                    'bt_internal_news_cache',
                    'bt_external_news_cache',
                    'bt_banners_cache',
                  ]) {
                    await prefs.remove(k);
                  }
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cache lokal berhasil dibersihkan.'),
                      backgroundColor: AppColors.emerald,
                    ),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFECFDF5),
                  child: Icon(Icons.notifications_active_rounded, color: AppColors.emerald),
                ),
                title: const Text('Sinkronkan Notifikasi', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Perbarui topik pengumuman & agenda', style: TextStyle(fontSize: 12)),
                onTap: () async {
                  try {
                    await FcmService.instance.init();
                  } catch (_) {}
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sinkronisasi notifikasi selesai.'),
                      backgroundColor: AppColors.emerald,
                    ),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEEF2FF),
                  child: Icon(Icons.school_rounded, color: Color(0xFF4F46E5)),
                ),
                title: const Text('Panduan Penggunaan', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Putar ulang tutorial pengenalan aplikasi', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  widget.onOpenTutorial();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAbout() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset('assets/img/appicon.png', width: 38, height: 38),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tentang Bungtemin',
                    style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'PUK SP LEM SPSI PT TMMIN',
                    style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: const Text(
          'Bungtemin adalah aplikasi portal resmi anggota PUK SP LEM SPSI PT Toyota Motor Manufacturing Indonesia yang dikelola oleh Badan Organisasi Timedia.\n\nLayanan mencakup berita organisasi, KTA Digital 3D, presensi acara & rapat, program kerja, kalender kerja, serta aspirasi anggota.',
          style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _openContact();
            },
            child: const Text('Hubungi Kami'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primaryBlue),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _handlePushTap(PushPayload payload) {
    if (!mounted) return;
    final target = payload.resolveTargetRoute();
    if (target.startsWith('http://') || target.startsWith('https://')) {
      final uri = Uri.tryParse(target);
      if (uri != null) {
        launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    if (target == '/home') return;

    final fakeItem = BungteminMenuItem(
      label: payload.title.isNotEmpty ? payload.title : 'Notifikasi',
      route: target,
      iconAsset: 'assets/icon/1.png',
      requiresLogin: BungteminMenuItem.requiresLoginFor(
        target,
        label: payload.title,
      ),
    );
    _handleMenuTap(fakeItem);
  }

  void _requireLogin(String reason, VoidCallback afterLogin) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => LoginScreen(
          showBackButton: true,
          reasonMessage: reason,
          onAuthenticated: (newSession) {
            setState(() => _session = newSession);
            widget.onAuthenticated(newSession);
            Navigator.of(ctx).pop();
            afterLogin();
          },
        ),
      ),
    );
  }

  void _withLogin(String reason, void Function(UserSession session) action) {
    final s = _session;
    if (s == null) {
      _requireLogin(reason, () {
        final authed = _session;
        if (authed != null && mounted) {
          action(authed);
        }
      });
      return;
    }
    action(s);
  }

  void _openNews({int segment = 0}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => Scaffold(
          body: NewsTab(
            initialSegment: segment,
            onBackHome: () => Navigator.of(ctx).pop(),
          ),
        ),
      ),
    );
  }

  void _openProfil() {
    _withLogin(
      'Masuk terlebih dahulu untuk membuka Profil Anggota Anda.',
      (s) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProfilScreen(session: s),
        ),
      ),
    );
  }

  void _openKta() {
    _withLogin(
      'Masuk terlebih dahulu untuk membuka KTA Digital 3D Anda.',
      (s) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(
              backgroundColor: const Color(0xFF0B1325),
              title: const Text(
                'KTA Digital FSP LEM SPSI',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5),
              ),
            ),
            body: KtaTab(session: s),
          ),
        ),
      ),
    );
  }

  Future<void> _openMeetingById(String meetingId) async {
    _withLogin(
      'Masuk terlebih dahulu untuk membuka Room, Undangan & Tiket Meeting.',
      (s) async {
        try {
          final data = await BungteminApi().fetchMeetings(
            noreg: s.noreg,
            token: s.token,
          );
          if (!mounted) return;
          final found = data.meetings.where((m) => m.id == meetingId).toList();
          if (found.isNotEmpty) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MeetingRoomScreen(
                  session: s,
                  meeting: found.first,
                ),
              ),
            );
            return;
          }
        } catch (_) {}
        if (mounted) _openMeeting();
      },
    );
  }

  void _openMeeting({int segment = 0}) {
    _withLogin(
      'Masuk terlebih dahulu untuk mengakses Jadwal & Tiket Meeting.',
      (s) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (ctx) => Scaffold(
            body: segment == 0
                ? MeetingHubScreen(
                    session: s,
                    onBackHome: () => Navigator.of(ctx).pop(),
                  )
                : MeetingTab(
                    session: s,
                    initialSegment: segment,
                    onBackHome: () => Navigator.of(ctx).pop(),
                  ),
          ),
        ),
      ),
    );
  }

  void _openTraining() {
    _withLogin(
      'Masuk terlebih dahulu untuk mengakses Pusat Training & Pintar.',
      (s) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TrainingScreen(session: s),
        ),
      ),
    );
  }

  void _openTrainingPleno() {
    _withLogin(
      'Masuk terlebih dahulu untuk mengakses Jadwal Training Pleno.',
      (s) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TrainingPlenoScreen(session: s),
        ),
      ),
    );
  }

  void _openTrainingTicket() {
    _withLogin(
      'Masuk terlebih dahulu untuk melihat Tiket Training Anda.',
      (s) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TrainingTicketScreen(
            session: s,
            onOpenPleno: () {
              Navigator.of(context).pop();
              _openTrainingPleno();
            },
          ),
        ),
      ),
    );
  }

  void _openTrainingListBulan() {
    _withLogin(
      'Masuk terlebih dahulu untuk melihat Agenda Training Bulanan.',
      (s) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TrainingListBulanScreen(session: s),
        ),
      ),
    );
  }

  void _openPintarBuku() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PintarBukuScreen(),
      ),
    );
  }

  void _openBukuReader({String? paramId}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BukuReaderScreen(paramId: paramId),
      ),
    );
  }

  void _openTabFeed() {
    _withLogin(
      'Masuk terlebih dahulu untuk membuka Cerita Komunitas.',
      (s) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TabFeedScreen(
            session: s,
            onRequireLogin: _requireLogin,
          ),
        ),
      ),
    );
  }

  void _openChat({String? roomId, String? titleHint}) {
    _withLogin(
      'Masuk terlebih dahulu untuk membuka Chat Anggota & B.A.I.M AI.',
      (s) {
        final rid = (roomId ?? '').trim();
        if (rid.startsWith('dm_')) {
          final parts = rid.split('_');
          final selfDigits = s.noreg.replaceAll(RegExp(r'\D+'), '');
          final self8 = selfDigits.isNotEmpty ? selfDigits.padLeft(8, '0') : '';
          final peer = parts.length == 3
              ? (parts[1] == self8 ? parts[2] : parts[1])
              : '';
          final cleanTitle = (titleHint ?? '')
              .replaceFirst(RegExp(r'^Pesan dari\s+', caseSensitive: false), '')
              .trim();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ChatRoomScreen(
                session: s,
                roomId: rid,
                kind: 'dm',
                title: cleanTitle.isNotEmpty ? cleanTitle : 'Chat Anggota',
                peerNoreg: peer,
              ),
            ),
          );
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ChatInboxScreen(session: s),
          ),
        );
      },
    );
  }

  void _openInbox() {
    _withLogin(
      'Masuk terlebih dahulu untuk membuka Kotak Masuk Broadcast.',
      (_) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const BroadcastInboxScreen(),
        ),
      ),
    );
  }

  void _openContact() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ContactScreen(),
      ),
    );
  }

  void _openFeedback() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const FeedbackScreen(),
      ),
    );
  }

  void _openCalendar() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CalendarScreen(),
      ),
    );
  }

  void _openScanner() {
    _withLogin(
      'Masuk terlebih dahulu untuk menggunakan pemindai QR (BTScan).',
      (s) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ScannerScreen(
            session: s,
            onRequireLogin: _requireLogin,
          ),
        ),
      ),
    );
  }

  void _openStruktur() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const StrukturScreen(),
      ),
    );
  }

  void _openProker() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ProkerScreen(),
      ),
    );
  }

  void _openTonton() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const TontonScreen(),
      ),
    );
  }

  void _openLapor({String? initialCategoryKey}) {
    _withLogin(
      'Masuk terlebih dahulu untuk mengakses layanan Hallo PUK.',
      (s) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LaporScreen(
            session: s,
            initialCategoryKey: initialCategoryKey,
          ),
        ),
      ),
    );
  }

  void _openMyArs() {
    _withLogin(
      'Masuk terlebih dahulu untuk melihat tiket & riwayat absensi MyArs.',
      (s) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MyArsTiketListScreen(session: s),
        ),
      ),
    );
  }

  void _openAplikasiHub() {
    _withLogin(
      'Masuk terlebih dahulu untuk membuka Portal BTapp.',
      (s) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AplikasiHubScreen(session: s),
        ),
      ),
    );
  }

  void _openMyEventList() {
    _withLogin(
      'Masuk terlebih dahulu untuk mengelola Event MyArs.',
      (s) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MyArsEventsScreen(session: s),
        ),
      ),
    );
  }

  void _openPublicEvents() {
    _withLogin(
      'Masuk terlebih dahulu untuk memantau Public Event.',
      (s) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MyArsPublicEventsScreen(session: s),
        ),
      ),
    );
  }

  void _openCreateEvent() {
    _withLogin(
      'Masuk terlebih dahulu untuk membuat Event baru.',
      (s) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MyArsCreateEventScreen(session: s),
        ),
      ),
    );
  }

  void _openAbsensiDetail(String slug) {
    _withLogin(
      'Masuk terlebih dahulu untuk melihat detail absensi event.',
      (_) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MyArsAbsensiDetailScreen(eventSlug: slug),
        ),
      ),
    );
  }

  void _openTiketDetail(String noreg, String ticketId) {
    _withLogin(
      'Masuk terlebih dahulu untuk membuka detail tiket absensi.',
      (_) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MyArsTiketDetailScreen(
            noreg: noreg,
            ticketId: ticketId,
          ),
        ),
      ),
    );
  }

  void _openEventScanner(String slug) {
    _withLogin(
      'Masuk terlebih dahulu untuk membuka scanner absensi event.',
      (s) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MyArsEventScannerScreen(
            eventSlug: slug,
            session: s,
          ),
        ),
      ),
    );
  }

  void _openQuiz() {
    _withLogin(
      'Masuk terlebih dahulu untuk mengikuti Quiz Bungtemin.',
      (s) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => QuizLobbyScreen(session: s),
        ),
      ),
    );
  }

  void _openPretest() {
    _withLogin(
      'Masuk terlebih dahulu untuk mengikuti Pretest & Posttest.',
      (s) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PretestLobbyScreen(session: s),
        ),
      ),
    );
  }

  void _handleMenuTap(BungteminMenuItem item) {
    if (item.isMaintenance) {
      final msg = item.maintenanceMessage.trim().isNotEmpty
          ? item.maintenanceMessage.trim()
          : 'Menu ${item.label} sedang dalam pemeliharaan sistem. Silakan coba beberapa saat lagi.';
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.build_circle_rounded, color: Color(0xFFD97706)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${item.label} (Maintenance)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Text(msg, style: const TextStyle(fontSize: 13.5, height: 1.45)),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      );
      return;
    }
    final requiresAuth = item.requiresLogin ||
        BungteminMenuItem.requiresLoginFor(item.route, label: item.label);
    if (requiresAuth && _session == null) {
      _requireLogin(
        'Fitur ${item.label} membutuhkan akun anggota. Silakan masuk terlebih dahulu.',
        () => _executeMenuRoute(item),
      );
      return;
    }
    _executeMenuRoute(item);
  }

  void _executeMenuRoute(BungteminMenuItem item) {
    final rawRoute = item.route.trim();
    final route = rawRoute.toLowerCase();
    final rawParts =
        rawRoute.split('/').where((s) => s.trim().isNotEmpty).toList();
    if (route.startsWith('/news')) {
      _openNews(segment: 0);
      return;
    }
    if (route.startsWith('/inbox')) {
      void openInbox() {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const BroadcastInboxScreen(),
          ),
        );
      }
      if (_session == null) {
        _requireLogin('Silakan login untuk membuka Kotak Masuk.', openInbox);
      } else {
        openInbox();
      }
      return;
    }
    if (route.startsWith('/tabfeed') || route.startsWith('/feed')) {
      _openTabFeed();
      return;
    }
    if (route.startsWith('/chat') || item.label.trim().toLowerCase() == 'chat') {
      final rid = rawParts.length > 1 ? rawParts[1].trim() : null;
      _openChat(roomId: rid, titleHint: item.label);
      return;
    }
    if (route.startsWith('/meeting')) {
      if (rawParts.length > 1 && rawParts[1].trim().isNotEmpty) {
        _openMeetingById(rawParts[1].trim());
      } else {
        _openMeeting();
      }
      return;
    }
    if (route.startsWith('/training-pleno')) {
      _openTrainingPleno();
      return;
    }
    if (route.startsWith('/training-ticket')) {
      _openTrainingTicket();
      return;
    }
    if (route.startsWith('/training/listbulan')) {
      _openTrainingListBulan();
      return;
    }
    if (route.startsWith('/training')) {
      _openTraining();
      return;
    }
    if (route.startsWith('/pintar')) {
      _openPintarBuku();
      return;
    }
    if (route.startsWith('/buku')) {
      final parts = route.split('/').where((s) => s.isNotEmpty).toList();
      final paramId = parts.length > 1 ? parts[1] : null;
      _openBukuReader(paramId: paramId);
      return;
    }
    if (route.startsWith('/profil')) {
      _openProfil();
      return;
    }
    if (route.startsWith('/idcard') || route.startsWith('/kta')) {
      _openKta();
      return;
    }
    if (route.startsWith('/kalender')) {
      _openCalendar();
      return;
    }
    if (route.startsWith('/bubabe') || item.label.trim().toLowerCase() == 'bubabe') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => BubabeScreen(session: _session)),
      );
      return;
    }
    if (route.startsWith('/struktur')) {
      _openStruktur();
      return;
    }
    if (route.startsWith('/proker')) {
      _openProker();
      return;
    }
    if (route.startsWith('/scanner')) {
      _openScanner();
      return;
    }
    if (route.startsWith('/tonton')) {
      _openTonton();
      return;
    }
    if (route.startsWith('/lapor') || route.startsWith('/hallopuk')) {
      String? initialCat;
      if (route.contains('formlapor')) {
        initialCat = 'lapor';
      } else if (route.contains('formusul')) {
        initialCat = 'usul';
      } else if (route.contains('formnanya')) {
        initialCat = 'nanya';
      }
      _openLapor(initialCategoryKey: initialCat);
      return;
    }
    if (route.startsWith('/saran') || route.startsWith('/feedback') || item.label.trim().toLowerCase() == 'saran app') {
      _openFeedback();
      return;
    }
    if (route.startsWith('/contact') || route.startsWith('/hubungi')) {
      _openContact();
      return;
    }
    if (route.startsWith('/tutorial')) {
      widget.onOpenTutorial();
      return;
    }
    if (route.startsWith('/aplikasi/todo') ||
        item.label.toLowerCase() == 'kodawari') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const KodawariScreen()),
      );
      return;
    }
    if (route.startsWith('/aplikasi/absensi/tiketdetail')) {
      final noreg = rawParts.length > 3 ? rawParts[3] : '';
      final id = rawParts.length > 4 ? rawParts[4] : '';
      if (id.isNotEmpty) {
        _openTiketDetail(noreg, id);
      } else {
        _openMyArs();
      }
      return;
    }
    if (route.startsWith('/aplikasi/absensi/absensidetail')) {
      final slug = rawParts.length > 3 ? rawParts[3] : '';
      if (slug.isNotEmpty) {
        _openAbsensiDetail(slug);
      } else {
        _openMyEventList();
      }
      return;
    }
    if (route.startsWith('/aplikasi/absensi/tiketlist') ||
        item.label.toLowerCase() == 'myars') {
      _openMyArs();
      return;
    }
    if (route.startsWith('/aplikasi/absensilist')) {
      _openPublicEvents();
      return;
    }
    if (route.startsWith('/aplikasi/absensinew')) {
      _openCreateEvent();
      return;
    }
    if (route.startsWith('/aplikasi/absensi')) {
      _openMyEventList();
      return;
    }
    if (route.startsWith('/myscanner')) {
      final slug = rawParts.length > 1 ? rawParts[1] : '';
      if (slug.isNotEmpty) {
        _openEventScanner(slug);
      } else {
        _openMyEventList();
      }
      return;
    }
    if (route == '/aplikasi' || route == '/aplikasi/') {
      _openAplikasiHub();
      return;
    }
    if (route.startsWith('/aplikasi/note') || item.label.toLowerCase() == 'bucat') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const BucatScreen()),
      );
      return;
    }
    if (route.startsWith('/quiz') || item.label.toLowerCase() == 'quiz') {
      _openQuiz();
      return;
    }
    if (route.startsWith('/pretest') || item.label.toLowerCase() == 'pretest') {
      _openPretest();
      return;
    }
    if (route == '/nfc-emoney' || route.startsWith('/nfc')) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const NfcEmoneyScreen()),
      );
      return;
    }
    if (route.startsWith('/keuangan') || item.label.toLowerCase() == 'keuangan') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const KeuanganScreen()),
      );
      return;
    }

    _showFeaturePreviewSheet(item);
  }

  void _showFeaturePreviewSheet(BungteminMenuItem item) {
    final desc = _featureDescription(item.label);
    final isAuthenticated = _session != null;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
          22,
          14,
          22,
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
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Image.asset(
                    item.iconAsset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.apps_rounded,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: (item.requiresLogin
                                  ? AppColors.emerald
                                  : AppColors.primaryBlue)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          item.requiresLogin
                              ? (isAuthenticated
                                  ? 'Terverifikasi: ${_session!.nama}'
                                  : 'Butuh Login Anggota')
                              : 'Akses Terbuka',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: item.requiresLogin
                                ? const Color(0xFF047857)
                                : AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              desc,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.55,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Mengerti',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _featureDescription(String label) {
    switch (label.toLowerCase()) {
      case 'pintar':
        return 'Ruang e-Training, materi organisasi, dan peningkatan kompetensi anggota PUK SP LEM SPSI PT. TMMIN. Modul ini terproteksi akun anggota.';
      case 'cerita':
        return 'Linimasa cerita dan momen kebersamaan anggota Bungtemin di berbagai plant TMMIN.';
      case 'chat':
        return 'Chat inbox antar anggota, grup semua anggota, serta asisten AI B.A.I.M.';
      case 'tonton':
        return 'Kanal video edukasi, liputan kegiatan serikat, dan dokumentasi resmi Timedia.';
      case 'hallo puk':
        return 'Layanan aspirasi, tanya pengurus, usulan, serta pelaporan anggota ke PUK SP LEM SPSI.';
      case 'btapp':
        return 'Pusat utilitas & aplikasi internal penunjang aktivitas kerja dan organisasi.';
      case 'struktur':
        return 'Susunan kepengurusan PUK SP LEM SPSI PT. TMMIN dan koordinator pleno per area.';
      case 'btscan':
        return 'Pemindai QR cepat untuk presensi kegiatan, tiket meeting, dan verifikasi ID digital.';
      case 'kalender':
        return 'Kalender kerja TMMIN, jadwal libur nasional, dan agenda penting organisasi.';
      case 'proker':
        return 'Transparansi program kerja dan realisasi kegiatan PUK SP LEM SPSI PT. TMMIN.';
      case 'keuangan':
        return 'Informasi laporan dan transparansi keuangan organisasi serikat pekerja.';
      case 'myars':
        return 'Tiket absensi dan riwayat kehadiran pribadi Anda pada kegiatan organisasi.';
      case 'quiz':
      case 'pretest':
        return 'Latihan interaktif dan uji pemahaman materi edukasi serikat pekerja.';
      case 'bucat':
      case 'kodawari':
        return 'Catatan praktis dan daftar tugas harian untuk mendukung produktivitas kerja.';
      default:
        return 'Modul layanan resmi Bungtemin. Fitur native Flutter untuk modul ini sedang disiapkan agar sinkron penuh dengan portal Bungtemin.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _BungteminDrawer(
        session: session,
        onOpenHome: () => Navigator.of(context).pop(),
        onOpenNews: () {
          Navigator.of(context).pop();
          _openNews();
        },
        onOpenKta: () {
          Navigator.of(context).pop();
          _openKta();
        },
        onOpenScanner: () {
          Navigator.of(context).pop();
          _openScanner();
        },
        onOpenChat: () {
          Navigator.of(context).pop();
          _openChat();
        },
        onOpenInbox: () {
          Navigator.of(context).pop();
          _openInbox();
        },
        onOpenProfil: () {
          Navigator.of(context).pop();
          _openProfil();
        },
        onOpenAccountSettings: () {
          Navigator.of(context).pop();
          _openAccountSettings();
        },
        onOpenAppSettings: () {
          Navigator.of(context).pop();
          _openAppSettings();
        },
        onOpenAbout: () {
          Navigator.of(context).pop();
          _openAbout();
        },
        onOpenContact: () {
          Navigator.of(context).pop();
          _openContact();
        },
        onLoginTap: () {
          Navigator.of(context).pop();
          _requireLogin(
            'Masuk untuk mengakses KTA Digital, Meeting, Pintar & Profil.',
            () {},
          );
        },
        onLogoutTap: () {
          Navigator.of(context).pop();
          widget.onLogout();
        },
      ),
      body: HomeTab(
        session: session,
        onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
        onNavigateTab: (idx) {
          if (idx == 1) _openNews();
          if (idx == 2) _openKta();
          if (idx == 3) _openMeeting();
          if (idx == 4) _openProfil();
        },
        onOpenNews: (seg) => _openNews(segment: seg),
        onRequireLogin: _requireLogin,
        onMenuTap: _handleMenuTap,
      ),
    );
  }
}

class _BungteminDrawer extends StatelessWidget {
  const _BungteminDrawer({
    required this.session,
    required this.onOpenHome,
    required this.onOpenNews,
    required this.onOpenKta,
    required this.onOpenScanner,
    required this.onOpenChat,
    required this.onOpenInbox,
    required this.onOpenProfil,
    required this.onOpenAccountSettings,
    required this.onOpenAppSettings,
    required this.onOpenAbout,
    required this.onOpenContact,
    required this.onLoginTap,
    required this.onLogoutTap,
  });

  final UserSession? session;
  final VoidCallback onOpenHome;
  final VoidCallback onOpenNews;
  final VoidCallback onOpenKta;
  final VoidCallback onOpenScanner;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenInbox;
  final VoidCallback onOpenProfil;
  final VoidCallback onOpenAccountSettings;
  final VoidCallback onOpenAppSettings;
  final VoidCallback onOpenAbout;
  final VoidCallback onOpenContact;
  final VoidCallback onLoginTap;
  final VoidCallback onLogoutTap;

  @override
  Widget build(BuildContext context) {
    final loggedIn = session != null;

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          InkWell(
            onTap: loggedIn ? onOpenProfil : onLoginTap,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 20,
                20,
                20,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.navy, AppColors.navyMid],
                ),
              ),
              child: Row(
                children: [
                  if (loggedIn)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 52,
                        height: 52,
                        color: Colors.white24,
                        child: Image.network(
                          session!.avatarUrl,
        headers: BtapiAuth.imageHeaders(session!.avatarUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Image.asset(
                            'assets/img/default-avatar.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 52,
                      height: 52,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Image.asset('assets/img/appicon.png'),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loggedIn ? session!.nama : 'Selamat Datang',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          loggedIn
                              ? 'Noreg ${session!.noreg} • ${session!.job}'
                              : 'Masuk untuk akses KTA & Layanan',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (loggedIn)
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white70,
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              children: [
                _DrawerTile(
                  iconAsset: 'assets/icon/1.png',
                  title: 'Beranda',
                  subtitle: 'Dashboard & semua layanan',
                  selected: true,
                  onTap: onOpenHome,
                ),
                _DrawerTile(
                  iconAsset: 'assets/icon/1.png',
                  iconData: Icons.newspaper_rounded,
                  title: 'Berita & Agenda',
                  subtitle: 'Kabar resmi organisasi',
                  selected: false,
                  onTap: onOpenNews,
                ),
                _DrawerTile(
                  iconAsset: 'assets/icon/19.png',
                  title: 'KTA Digital',
                  subtitle: loggedIn ? 'Kartu anggota & QR' : 'Butuh login anggota',
                  selected: false,
                  locked: !loggedIn,
                  onTap: onOpenKta,
                ),
                _DrawerTile(
                  iconAsset: 'assets/icon/9.png',
                  title: 'Smart Scanner QR',
                  subtitle: loggedIn ? 'Presensi acara & rapat' : 'Butuh login anggota',
                  selected: false,
                  locked: !loggedIn,
                  onTap: onOpenScanner,
                ),
                _DrawerTile(
                  iconAsset: 'assets/icon/22.png',
                  iconData: Icons.chat_rounded,
                  title: 'Chat & B.A.I.M AI',
                  subtitle: loggedIn ? 'Inbox anggota & asisten AI' : 'Butuh login anggota',
                  selected: false,
                  locked: !loggedIn,
                  onTap: onOpenChat,
                ),
                _DrawerTile(
                  iconAsset: 'assets/icon/1.png',
                  iconData: Icons.mark_email_unread_rounded,
                  title: 'Kotak Masuk Broadcast',
                  subtitle: loggedIn
                      ? 'Pengumuman, PDF, konfirmasi & form'
                      : 'Butuh login anggota',
                  selected: false,
                  locked: !loggedIn,
                  onTap: onOpenInbox,
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 14, 12, 4),
                  child: Text(
                    'PENGATURAN',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                _DrawerTile(
                  iconData: Icons.manage_accounts_rounded,
                  title: 'Pengaturan Akun',
                  subtitle: loggedIn ? 'Ubah PIN, No. WA & profil' : 'Butuh login anggota',
                  selected: false,
                  locked: !loggedIn,
                  onTap: onOpenAccountSettings,
                ),
                _DrawerTile(
                  iconData: Icons.tune_rounded,
                  title: 'Pengaturan Aplikasi',
                  subtitle: 'Cache, notifikasi & panduan',
                  selected: false,
                  onTap: onOpenAppSettings,
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 14, 12, 4),
                  child: Text(
                    'INFORMASI',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                _DrawerTile(
                  iconData: Icons.info_outline_rounded,
                  title: 'Tentang Aplikasi',
                  subtitle: 'Profil platform & pengelola',
                  selected: false,
                  onTap: onOpenAbout,
                ),
                _DrawerTile(
                  iconData: Icons.support_agent_rounded,
                  title: 'Hubungi Kami',
                  subtitle: 'Kontak sekretariat & redaksi',
                  selected: false,
                  onTap: onOpenContact,
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            child: SizedBox(
              width: double.infinity,
              child: loggedIn
                  ? OutlinedButton.icon(
                      onPressed: onLogoutTap,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Keluar Sesi (Logout)'),
                    )
                  : FilledButton.icon(
                      onPressed: onLoginTap,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Masuk Akun Anggota'),
                    ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              MediaQuery.of(context).padding.bottom + 12,
            ),
            child: Text(
              'Versi Aplikasi ${AppInfo.displayVersion}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    this.iconAsset,
    this.iconData,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.locked = false,
  });

  final String? iconAsset;
  final IconData? iconData;
  final String title;
  final String subtitle;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: selected,
      selectedTileColor: AppColors.primaryBlue.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: Container(
        width: 38,
        height: 38,
        padding: EdgeInsets.all(iconData != null ? 0 : 5),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(11),
        ),
        child: iconData != null
            ? Icon(iconData, size: 20, color: AppColors.navy)
            : Image.asset(iconAsset ?? 'assets/icon/1.png', fit: BoxFit.contain),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13.5,
          color: AppColors.navy,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
      ),
      trailing: locked
          ? const Icon(Icons.lock_outline_rounded, size: 17, color: AppColors.muted)
          : null,
      onTap: onTap,
    );
  }
}
