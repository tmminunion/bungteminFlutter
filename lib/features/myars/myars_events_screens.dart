import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/session_store.dart';
import '../../models/myars_models.dart';
import '../../services/myars_service.dart';
import '../pintar/training_ticket_screen.dart';
import 'myars_absensi_detail_screen.dart';
import 'myars_event_scanner_screen.dart';
import 'myars_tiket_list_screen.dart';
import 'myars_widgets.dart';

/// Portal BTapp / Bungtemin Hub (`/aplikasi` = `AplikasiPage`).
class AplikasiHubScreen extends StatelessWidget {
  const AplikasiHubScreen({
    super.key,
    required this.session,
    this.service,
  });

  final UserSession? session;
  final MyArsService? service;

  @override
  Widget build(BuildContext context) {
    final svc = service ?? MyArsService();
    final items = <_HubModuleItem>[
      _HubModuleItem(
        title: 'My Qrcode Event',
        description: 'Semua Tiket & QR Code acara.',
        iconAsset: 'assets/icon/qr.png',
        accent: const Color(0xFF7C3AED),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TrainingTicketScreen(session: session),
          ),
        ),
      ),
      _HubModuleItem(
        title: 'Public Event',
        description: 'Monitoring kehadiran realtime.',
        iconAsset: 'assets/icon/21.png',
        accent: const Color(0xFF059669),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MyArsPublicEventsScreen(
              session: session,
              service: svc,
            ),
          ),
        ),
      ),
      _HubModuleItem(
        title: 'MyEvent',
        description: 'Kelola pamflet & QR Code acara.',
        iconAsset: 'assets/icon/22.png',
        accent: const Color(0xFF6366F1),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MyArsEventsScreen(
              session: session,
              service: svc,
            ),
          ),
        ),
      ),
      _HubModuleItem(
        title: 'MyAbsensi Tiket',
        description: 'Daftar tiket & riwayat kehadiran acara.',
        iconAsset: 'assets/icon/15.png',
        accent: const Color(0xFF0284C7),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MyArsTiketListScreen(
              session: session,
              service: svc,
            ),
          ),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          const MyArsHeroHeader(
            titleChip: 'PORTAL BTAPP',
            countLabel: '4 Modul',
            title: 'Bungtemin Hub',
            subtitle: 'Pusat manajemen absensi, QR Code & tiket kegiatan',
            icon: Icons.apps_rounded,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Produktivitas',
                        style: TextStyle(
                          color: Color(0xFF0369A1),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Absensi Online',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${items.length} Modul',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _HubCard(item: items[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HubModuleItem {
  const _HubModuleItem({
    required this.title,
    required this.description,
    required this.iconAsset,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String description;
  final String iconAsset;
  final Color accent;
  final VoidCallback onTap;
}

class _HubCard extends StatelessWidget {
  const _HubCard({required this.item});

  final _HubModuleItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x080F172A),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: item.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Image.asset(
                  item.iconAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.qr_code_rounded,
                    color: item.accent,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.description,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// MyEvent — Kelola Acara Saya (`/aplikasi/absensi` = `AbsensiPage`).
class MyArsEventsScreen extends StatefulWidget {
  const MyArsEventsScreen({
    super.key,
    required this.session,
    this.service,
  });

  final UserSession? session;
  final MyArsService? service;

  @override
  State<MyArsEventsScreen> createState() => _MyArsEventsScreenState();
}

class _MyArsEventsScreenState extends State<MyArsEventsScreen> {
  late final MyArsService _service;
  final ScrollController _scrollCtrl = ScrollController();

  List<MyArsEvent> _dataevent = [];
  int _currentPage = 1;
  int _lastPage = 1;
  bool _loading = true;
  bool _loadingMore = false;

  String get _noreg => MyArsService.resolveActiveNoreg(widget.session);

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MyArsService();
    _scrollCtrl.addListener(_onScroll);
    _loadLocalData();
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients || _loadingMore || _loading) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 100 && _currentPage < _lastPage) {
      _loadMore();
    }
  }

  Future<void> _loadLocalData() async {
    final local = await _service.loadLocalMyEvents(_noreg);
    if (!mounted) return;
    if (local.isNotEmpty) {
      setState(() {
        _dataevent = local;
        _loading = false;
      });
    }
    await _getAllData();
  }

  Future<void> _getAllData({bool appending = false}) async {
    try {
      final res = await _service.getMyEventNoreg(_noreg, page: _currentPage);
      if (!mounted) return;
      final updated = _currentPage == 1 && !appending
          ? res.items
          : <MyArsEvent>[..._dataevent, ...res.items];
      setState(() {
        _dataevent = updated;
        _lastPage = res.lastPage > 0 ? res.lastPage : 1;
        _loading = false;
        _loadingMore = false;
      });
      await _service.saveLocalMyEvents(_noreg, updated);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _refresh() async {
    _currentPage = 1;
    await _getAllData();
  }

  Future<void> _loadMore() async {
    if (_currentPage >= _lastPage || _loadingMore) return;
    setState(() {
      _loadingMore = true;
      _currentPage++;
    });
    await _getAllData(appending: true);
  }

  Future<void> _copyLink(MyArsEvent item) async {
    await Clipboard.setData(ClipboardData(text: item.cameraWebUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Teks berhasil disalin!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openExternalLink(MyArsEvent item) async {
    final uri = Uri.tryParse(item.cameraWebUrl);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MyArsCreateEventScreen(
              session: widget.session,
              service: _service,
            ),
          ),
        ),
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: MyArsHeroHeader(
                titleChip: 'ACARA SAYA',
                countLabel: '${_dataevent.length} Acara',
                title: 'Kelola Acara Saya',
                subtitle:
                    'Pantau kehadiran, buka scanner QR & bagikan tautan acara',
                icon: Icons.qr_code_2_rounded,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 88),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_loading && _dataevent.isEmpty)
                      const MyArsLoadingCard(
                        title: 'Memuat Acara Saya',
                        message: 'Mengambil daftar acara yang Anda kelola...',
                      )
                    else if (_dataevent.isEmpty)
                      const MyArsEmptyCard(
                        icon: Icons.collections_bookmark_outlined,
                        title: 'Belum Ada Acara Tersimpan',
                        message:
                            'Tekan tombol + di kanan bawah untuk membuat acara absensi baru.',
                      )
                    else ...[
                      for (var i = 0; i < _dataevent.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        _MyEventCard(
                          index: i + 1,
                          item: _dataevent[i],
                          onViewAbsensi: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => MyArsAbsensiDetailScreen(
                                eventSlug: _dataevent[i].eventSlug,
                                initialEvent: _dataevent[i],
                                service: _service,
                              ),
                            ),
                          ),
                          onOpenScanner: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => MyArsEventScannerScreen(
                                eventSlug: _dataevent[i].eventSlug,
                                session: widget.session,
                                initialEvent: _dataevent[i],
                                service: _service,
                              ),
                            ),
                          ),
                          onOpenWebCam: () => _openExternalLink(_dataevent[i]),
                          onCopyLink: () => _copyLink(_dataevent[i]),
                        ),
                      ],
                      if (_loadingMore)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_currentPage < _lastPage)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: OutlinedButton(
                            onPressed: _loadMore,
                            child: const Text('Muat acara lainnya'),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyEventCard extends StatelessWidget {
  const _MyEventCard({
    required this.index,
    required this.item,
    required this.onViewAbsensi,
    required this.onOpenScanner,
    required this.onOpenWebCam,
    required this.onCopyLink,
  });

  final int index;
  final MyArsEvent item;
  final VoidCallback onViewAbsensi;
  final VoidCallback onOpenScanner;
  final VoidCallback onOpenWebCam;
  final VoidCallback onCopyLink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  '$index',
                  style: const TextStyle(
                    color: Color(0xFF1D4ED8),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.namaAcara,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _SmallMeta(
                          icon: Icons.location_on_outlined,
                          text: item.tempat.isNotEmpty
                              ? item.tempat
                              : 'Lokasi acara',
                        ),
                        _SmallMeta(
                          icon: Icons.calendar_today_rounded,
                          text: MyArsTicket.formatDate(item.tanggalAcara),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 3.1,
            children: [
              _GridActionButton(
                icon: Icons.newspaper_rounded,
                label: 'Lihat Absensi',
                bg: const Color(0xFFEFF6FF),
                fg: const Color(0xFF1D4ED8),
                onTap: onViewAbsensi,
              ),
              _GridActionButton(
                icon: Icons.qr_code_scanner_rounded,
                label: 'Scanner In-App',
                bg: const Color(0xFFECFEFF),
                fg: const Color(0xFF0F766E),
                onTap: onOpenScanner,
              ),
              _GridActionButton(
                icon: Icons.open_in_new_rounded,
                label: 'Kamera Web',
                bg: const Color(0xFFF8FAFC),
                fg: const Color(0xFF334155),
                onTap: onOpenWebCam,
              ),
              _GridActionButton(
                icon: Icons.copy_rounded,
                label: 'Salin Tautan',
                bg: const Color(0xFFF8FAFC),
                fg: const Color(0xFF334155),
                onTap: onCopyLink,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GridActionButton extends StatelessWidget {
  const _GridActionButton({
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
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

/// Public Event — Daftar Acara Publik (`/aplikasi/absensilist` = `AbsensilistPage`).
class MyArsPublicEventsScreen extends StatefulWidget {
  const MyArsPublicEventsScreen({
    super.key,
    required this.session,
    this.service,
  });

  final UserSession? session;
  final MyArsService? service;

  @override
  State<MyArsPublicEventsScreen> createState() =>
      _MyArsPublicEventsScreenState();
}

class _MyArsPublicEventsScreenState extends State<MyArsPublicEventsScreen> {
  late final MyArsService _service;
  final ScrollController _scrollCtrl = ScrollController();

  List<MyArsEvent> _dataevent = [];
  int _currentPage = 1;
  int _lastPage = 1;
  bool _loading = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MyArsService();
    _scrollCtrl.addListener(_onScroll);
    _loadLocalData();
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients || _loadingMore || _loading) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 100 && _currentPage < _lastPage) {
      _loadMore();
    }
  }

  Future<void> _loadLocalData() async {
    final local = await _service.loadLocalPublicEvents();
    if (!mounted) return;
    if (local.isNotEmpty) {
      setState(() {
        _dataevent = local;
        _loading = false;
      });
    }
    await _getAllData();
  }

  Future<void> _getAllData({bool appending = false}) async {
    try {
      final res = await _service.getMyEventAll(page: _currentPage);
      if (!mounted) return;
      final updated = _currentPage == 1 && !appending
          ? res.items
          : <MyArsEvent>[..._dataevent, ...res.items];
      setState(() {
        _dataevent = updated;
        _lastPage = res.lastPage > 0 ? res.lastPage : 1;
        _loading = false;
        _loadingMore = false;
      });
      await _service.saveLocalPublicEvents(updated);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _refresh() async {
    _currentPage = 1;
    await _getAllData();
  }

  Future<void> _loadMore() async {
    if (_currentPage >= _lastPage || _loadingMore) return;
    setState(() {
      _loadingMore = true;
      _currentPage++;
    });
    await _getAllData(appending: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MyArsCreateEventScreen(
              session: widget.session,
              service: _service,
            ),
          ),
        ),
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: MyArsHeroHeader(
                titleChip: 'ACARA PUBLIK',
                countLabel: '${_dataevent.length} Acara',
                title: 'Daftar Acara Publik',
                subtitle: 'Monitoring kehadiran & daftar hadir kegiatan aktif',
                icon: Icons.calendar_month_rounded,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 88),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_loading && _dataevent.isEmpty)
                      const MyArsLoadingCard(
                        title: 'Memuat Acara Publik',
                        message: 'Mengambil daftar kegiatan aktif...',
                      )
                    else if (_dataevent.isEmpty)
                      const MyArsEmptyCard(
                        icon: Icons.calendar_today_outlined,
                        title: 'Belum Ada Acara Publik',
                        message:
                            'Buat acara baru atau tarik ke bawah untuk menyegarkan daftar.',
                      )
                    else ...[
                      for (var i = 0; i < _dataevent.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: Text(
                                      '${i + 1}',
                                      style: const TextStyle(
                                        color: Color(0xFF15803D),
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _dataevent[i].namaAcara,
                                          style: const TextStyle(
                                            color: Color(0xFF0F172A),
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 4,
                                          children: [
                                            _SmallMeta(
                                              icon: Icons.location_on_outlined,
                                              text: _dataevent[i]
                                                      .tempat
                                                      .isNotEmpty
                                                  ? _dataevent[i].tempat
                                                  : 'Lokasi belum ditentukan',
                                            ),
                                            _SmallMeta(
                                              icon: Icons.calendar_today_rounded,
                                              text: MyArsTicket.formatDate(
                                                _dataevent[i].tanggalAcara,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              FilledButton.icon(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => MyArsAbsensiDetailScreen(
                                      eventSlug: _dataevent[i].eventSlug,
                                      initialEvent: _dataevent[i],
                                      service: _service,
                                    ),
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFEFF6FF),
                                  foregroundColor: const Color(0xFF1D4ED8),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 11,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.newspaper_rounded,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Lihat Daftar Absensi',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_loadingMore)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_currentPage < _lastPage)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: OutlinedButton(
                            onPressed: _loadMore,
                            child: const Text('Muat acara lainnya'),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Buat Acara Baru (`/aplikasi/absensinew` = `AbsensinewPage`).
class MyArsCreateEventScreen extends StatefulWidget {
  const MyArsCreateEventScreen({
    super.key,
    required this.session,
    this.service,
  });

  final UserSession? session;
  final MyArsService? service;

  @override
  State<MyArsCreateEventScreen> createState() => _MyArsCreateEventScreenState();
}

class _MyArsCreateEventScreenState extends State<MyArsCreateEventScreen> {
  late final MyArsService _service;
  final TextEditingController _acaraCtrl = TextEditingController();
  final TextEditingController _jumlahCtrl = TextEditingController();
  bool _submitting = false;

  bool get _canSubmit =>
      !_submitting &&
      _acaraCtrl.text.trim().isNotEmpty &&
      (int.tryParse(_jumlahCtrl.text.trim()) ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MyArsService();
  }

  @override
  void dispose() {
    _acaraCtrl.dispose();
    _jumlahCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final acara = _acaraCtrl.text.trim();
    final jumlah = int.tryParse(_jumlahCtrl.text.trim()) ?? 0;
    if (acara.isEmpty || jumlah <= 0) return;

    setState(() => _submitting = true);
    try {
      final res = await _service.makeEvent(
        acara: acara,
        jumlah: jumlah,
        session: widget.session,
      );
      if (!mounted) return;
      setState(() => _submitting = false);

      if (res.success) {
        _acaraCtrl.clear();
        _jumlahCtrl.clear();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => MyArsPublicEventsScreen(
              session: widget.session,
              service: _service,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message)),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terjadi kesalahan saat menghubungi server'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          const MyArsHeroHeader(
            titleChip: 'ACARA BARU',
            countLabel: 'Form Event',
            title: 'Buat Acara Absensi',
            subtitle:
                'Siapkan kuota peserta & kode event baru dalam hitungan detik',
            iconAsset: 'assets/icon/5.png',
            icon: Icons.auto_awesome_rounded,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A0F172A),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Nama Acara / Kegiatan',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _acaraCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.auto_awesome_outlined),
                        hintText: 'Contoh: Rapat Koordinasi Unit',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Target Jumlah Peserta',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _jumlahCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.people_outline_rounded),
                        hintText: 'Contoh: 50',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: _canSubmit ? _submit : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add_circle_outline_rounded),
                      label: Text(
                        _submitting
                            ? 'Mengirim data...'
                            : 'Buat Acara Sekarang',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
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

class _SmallMeta extends StatelessWidget {
  const _SmallMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13.5, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
