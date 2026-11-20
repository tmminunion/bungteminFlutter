import 'package:flutter/material.dart';

import '../../models/myars_models.dart';
import '../../services/myars_service.dart';
import 'myars_tiket_detail_screen.dart';
import 'myars_widgets.dart';
import '../../core/net/btapi_auth.dart';

/// Detail Absensi Event (`/aplikasi/absensi/absensidetail/:id`).
/// Menyalin logika `AbsensidetailPage` (`bungteminAPP`):
/// - Muat cache lokal (`getLocalAbsensi`) lalu refresh `GET /absensi/rakernit2025/api/:id`.
/// - Persentase & progress bar `percentasi()` / `percentasi2()`.
/// - Daftar peserta hadir + navigasi ke `TiketdetailPage`.
class MyArsAbsensiDetailScreen extends StatefulWidget {
  const MyArsAbsensiDetailScreen({
    super.key,
    required this.eventSlug,
    this.initialEvent,
    this.service,
  });

  final String eventSlug;
  final MyArsEvent? initialEvent;
  final MyArsService? service;

  @override
  State<MyArsAbsensiDetailScreen> createState() =>
      _MyArsAbsensiDetailScreenState();
}

class _MyArsAbsensiDetailScreenState extends State<MyArsAbsensiDetailScreen> {
  late final MyArsService _service;
  MyArsEventDetail? _detail;
  bool _loading = true;

  MyArsEvent? get _event => _detail?.event ?? widget.initialEvent;
  List<MyArsTicket> get _pesertaList => _detail?.data ?? const [];
  int get _targetPeserta => _event?.jumlahPeserta ?? _detail?.peserta ?? 0;

  String get _percentasiText {
    if (_targetPeserta <= 0) return '0.00';
    return ((_pesertaList.length / _targetPeserta) * 100).toStringAsFixed(2);
  }

  double get _percentasiProgress {
    if (_targetPeserta <= 0) return 0.0;
    final val =
        double.tryParse((_pesertaList.length / _targetPeserta).toStringAsFixed(2)) ??
            0.0;
    return val.clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MyArsService();
    _loadAbsensi();
  }

  Future<void> _loadAbsensi() async {
    final local = await _service.loadLocalEventDetail(widget.eventSlug);
    if (!mounted) return;
    if (local != null && local.event != null) {
      setState(() {
        _detail = local;
        _loading = false;
      });
    }

    try {
      final fetched = await _service.getAbsensiById(widget.eventSlug);
      if (!mounted) return;
      if (fetched.status == 'success') {
        setState(() {
          _detail = fetched;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _openParticipantTicket(MyArsTicket item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MyArsTiketDetailScreen(
          noreg: item.noreg,
          ticketId: item.id.toString(),
          initialTicket: item,
          service: _service,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ev = _event;
    final list = _pesertaList;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: RefreshIndicator(
        onRefresh: _loadAbsensi,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: MyArsHeroHeader(
                titleChip: 'DETAIL ABSENSI',
                countLabel: '${list.length} Hadir',
                bottomChild: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NAMA KEGIATAN',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.9,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        ev?.namaAcara.isNotEmpty == true
                            ? ev!.namaAcara
                            : 'Memuat Nama Acara...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          _HeroMeta(
                            icon: Icons.calendar_today_rounded,
                            label: MyArsTicket.formatDate(
                              ev?.tanggalAcara,
                              slashNumeric: true,
                            ),
                          ),
                          _HeroMeta(
                            icon: Icons.location_on_outlined,
                            label: ev?.tempat.isNotEmpty == true
                                ? ev!.tempat
                                : 'Aula Utama',
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Text(
                            'Tingkat Kehadiran',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '$_percentasiText%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: _percentasiProgress,
                          minHeight: 7,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF38BDF8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Daftar Peserta Hadir',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${list.length} / $_targetPeserta Orang',
                          style: const TextStyle(
                            color: Color(0xFF0284C7),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_loading && list.isEmpty)
                      const MyArsLoadingCard(
                        title: 'Memuat Peserta Hadir',
                        message: 'Mengambil data presensi kegiatan...',
                      )
                    else if (list.isEmpty)
                      const MyArsEmptyCard(
                        icon: Icons.people_outline_rounded,
                        title: 'Belum Ada Peserta Check-In',
                        message:
                            'Daftar peserta yang melakukan scan QR akan tampil otomatis di sini.',
                      )
                    else
                      for (var i = 0; i < list.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        _PesertaCard(
                          index: i + 1,
                          item: list[i],
                          onOpenTicket: () => _openParticipantTicket(list[i]),
                        ),
                      ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              _FooterStatPill(label: 'HADIR', value: '${list.length}'),
              const SizedBox(width: 10),
              _FooterStatPill(label: 'TARGET', value: '$_targetPeserta'),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF0284C7)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '$_percentasiText%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
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

class _HeroMeta extends StatelessWidget {
  const _HeroMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PesertaCard extends StatelessWidget {
  const _PesertaCard({
    required this.index,
    required this.item,
    required this.onOpenTicket,
  });

  final int index;
  final MyArsTicket item;
  final VoidCallback onOpenTicket;

  @override
  Widget build(BuildContext context) {
    final deptLine = [
      if (item.divisi.isNotEmpty) item.divisi,
      if (item.plant.isNotEmpty) item.plant,
    ].join(' • ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x070F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 50,
                  height: 50,
                  color: const Color(0xFFF1F5F9),
                  child: item.avatarUrl.isNotEmpty
                      ? Image.network(
                          item.avatarUrl,
        headers: BtapiAuth.imageHeaders(item.avatarUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Image.asset(
                            'assets/img/default-avatar.png',
                            fit: BoxFit.cover,
                          ),
                        )
                      : Image.asset(
                          'assets/img/default-avatar.png',
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.nama.isNotEmpty ? item.nama : '-',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '#$index',
                            style: const TextStyle(
                              color: Color(0xFF1D4ED8),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.noreg,
                      style: const TextStyle(
                        color: Color(0xFF0284C7),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (deptLine.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        deptLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        '${MyArsTicket.formatDate(item.tanggal, slashNumeric: true)} • ${item.jamMasuk}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onOpenTicket,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1D4ED8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text(
                  'Lihat Tiket',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FooterStatPill extends StatelessWidget {
  const _FooterStatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
