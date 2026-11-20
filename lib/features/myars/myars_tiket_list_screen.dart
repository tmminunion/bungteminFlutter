import 'package:flutter/material.dart';

import '../../core/session_store.dart';
import '../../models/myars_models.dart';
import '../../services/myars_service.dart';
import 'myars_events_screens.dart';
import 'myars_tiket_detail_screen.dart';
import 'myars_widgets.dart';

/// MyArs — Riwayat Tiket Absensi Saya (`/aplikasi/absensi/tiketlist`).
/// Menyalin logika `TiketlistPage` (`bungteminAPP`) secara identik:
/// - Offline-first cache per noreg
/// - Fetch `GET /btapi/MyEvent/tiket/:noreg?page=:page`
/// - Pull-to-refresh & infinite scroll pagination (`currentPage < totalPage`)
/// - Pencarian real-time (`Acara`, `Kode`, `kategori`, `komisi`)
class MyArsTiketListScreen extends StatefulWidget {
  const MyArsTiketListScreen({
    super.key,
    required this.session,
    this.service,
    this.initialTickets,
  });

  final UserSession? session;
  final MyArsService? service;
  final List<MyArsTicket>? initialTickets;

  @override
  State<MyArsTiketListScreen> createState() => _MyArsTiketListScreenState();
}

class _MyArsTiketListScreenState extends State<MyArsTiketListScreen> {
  late final MyArsService _service;
  final ScrollController _scrollCtrl = ScrollController();

  List<MyArsTicket> _dataevent = [];
  int _currentPage = 1;
  int _totalPage = 1;
  bool _isLoading = false;
  bool _isLoadingMore = false;

  String get _noreg => MyArsService.resolveActiveNoreg(widget.session);

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MyArsService();
    _scrollCtrl.addListener(_onScroll);
    if (widget.initialTickets != null) {
      _dataevent = List<MyArsTicket>.from(widget.initialTickets!);
    } else {
      _loadData();
    }
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients || _isLoadingMore || _isLoading) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 100 && _currentPage < _totalPage) {
      _loadMore();
    }
  }

  Future<void> _doRefresh() async {
    _currentPage = 1;
    await _loadData(fromRefresh: true);
  }

  Future<void> _loadData({
    bool fromRefresh = false,
    bool appending = false,
  }) async {
    if (_currentPage == 1 && !fromRefresh && _dataevent.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      // STEP 1: Offline-first local cache pada page 1
      if (_currentPage == 1 && !appending) {
        final localData = await _service.loadLocalTiketByNoreg(_noreg);
        if (!mounted) return;
        if (localData.isNotEmpty) {
          setState(() {
            _dataevent = localData;
            _isLoading = false;
          });
        }
      }

      // STEP 2: Sinkronisasi API
      final res = await _service.getTiketByUser(_noreg, page: _currentPage);
      if (!mounted) return;
      if (res.success) {
        final updated = _currentPage == 1
            ? res.items
            : <MyArsTicket>[..._dataevent, ...res.items];
        setState(() {
          _dataevent = updated;
          _totalPage = res.lastPage > 0 ? res.lastPage : 1;
          _isLoading = false;
          _isLoadingMore = false;
        });
        await _service.saveLocalTiketList(_noreg, updated);
      } else {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_currentPage >= _totalPage || _isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });
    await _loadData(appending: true);
  }

  void _openDetail(MyArsTicket item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MyArsTiketDetailScreen(
          noreg: _noreg,
          ticketId: item.id.toString(),
          initialTicket: item,
          service: _service,
        ),
      ),
    );
  }

  void _openHub() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AplikasiHubScreen(
          session: widget.session,
          service: _service,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _dataevent;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: RefreshIndicator(
        onRefresh: _doRefresh,
        child: CustomScrollView(
          controller: _scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: MyArsHeroHeader(
                titleChip: 'TIKET ABSENSI',
                countLabel: '${filtered.length} Tiket',
                title: 'Riwayat Tiket Saya',
                subtitle: 'Noreg aktif: $_noreg',
                icon: Icons.confirmation_number_outlined,
                extraAction: Material(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    onTap: _openHub,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.apps_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Acara',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isLoading)
                      const MyArsLoadingCard(
                        title: 'Memuat Riwayat Tiket',
                        message:
                            'Sedang menyinkronkan tiket kehadiran Anda...',
                      )
                    else if (filtered.isEmpty)
                      MyArsEmptyCard(
                        icon: Icons.confirmation_number_outlined,
                        title: 'Belum Ada Riwayat Tiket',
                        message:
                            'Tiket absensi Anda akan muncul setelah mengikuti acara resmi Bungtemin.',
                      )
                    else ...[
                      for (var i = 0; i < filtered.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        _TicketCard(
                          item: filtered[i],
                          onTap: () => _openDetail(filtered[i]),
                        ),
                      ],
                      if (_isLoadingMore)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                          ),
                        )
                      else if (_currentPage < _totalPage)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: OutlinedButton.icon(
                            onPressed: _loadMore,
                            icon: const Icon(Icons.expand_more_rounded),
                            label: const Text('Muat tiket lainnya'),
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

class _TicketCard extends StatelessWidget {
  const _TicketCard({
    required this.item,
    required this.onTap,
  });

  final MyArsTicket item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(15),
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
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1E3A8A), Color(0xFF0284C7)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'KOMISI',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          item.komisi.isNotEmpty ? item.komisi : '-',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.acara.isNotEmpty ? item.acara : '-',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            _MetaIconText(
                              icon: Icons.calendar_today_rounded,
                              label: MyArsTicket.formatDate(item.tanggal),
                            ),
                            _MetaIconText(
                              icon: Icons.access_time_rounded,
                              label: item.jamMasuk.isNotEmpty
                                  ? item.jamMasuk
                                  : '-',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      MyArsStatusChip(status: item.status),
                      const SizedBox(height: 8),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF94A3B8),
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '#${item.kategori.isNotEmpty ? item.kategori : 'Acara'}',
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.qr_code_2_rounded,
                        size: 15,
                        color: Color(0xFF0284C7),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Lihat E-Pass',
                        style: TextStyle(
                          color: Color(0xFF0284C7),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaIconText extends StatelessWidget {
  const _MetaIconText({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
