import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/myars_models.dart';
import '../../services/myars_service.dart';
import 'myars_widgets.dart';
import '../../core/net/btapi_auth.dart';

/// E-Pass Kehadiran (`/aplikasi/absensi/tiketdetail/:noreg/:id`).
/// Menyalin logika `TiketdetailPage` (`bungteminAPP`):
/// 1. Strategi 1: Cek cache lokal terlebih dahulu.
/// 2. Strategi 2: Fetch `GET /btapi/MyEvent/tiketbyid/:id` dan sinkronkan QR `{n, r, c}`.
class MyArsTiketDetailScreen extends StatefulWidget {
  const MyArsTiketDetailScreen({
    super.key,
    required this.noreg,
    required this.ticketId,
    this.initialTicket,
    this.service,
  });

  final String noreg;
  final String ticketId;
  final MyArsTicket? initialTicket;
  final MyArsService? service;

  @override
  State<MyArsTiketDetailScreen> createState() => _MyArsTiketDetailScreenState();
}

class _MyArsTiketDetailScreenState extends State<MyArsTiketDetailScreen> {
  late final MyArsService _service;
  MyArsTicket? _participant;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MyArsService();
    if (widget.initialTicket != null) {
      _participant = widget.initialTicket;
      _loading = false;
    }
    _loadTicket();
  }

  Future<void> _loadTicket() async {
    // Strategi 1: Cache lokal dulu
    final local = await _service.loadLocalTicket(
      id: widget.ticketId,
      noreg: widget.noreg,
    );
    if (!mounted) return;
    if (local != null) {
      setState(() {
        _participant = local;
        _loading = false;
      });
      return;
    }

    // Strategi 2: Fetch API tiketbyid
    try {
      final fetched = await _service.getTiketById(
        widget.ticketId,
        noreg: widget.noreg,
      );
      if (!mounted) return;
      setState(() {
        if (fetched != null) {
          _participant = fetched;
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _participant;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          const MyArsHeroHeader(
            titleChip: 'E-PASS KEHADIRAN',
            countLabel: 'QR VERIFIKASI',
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
              child: p != null
                  ? _BoardingPassCard(participant: p)
                  : _loading
                      ? const MyArsLoadingCard(
                          title: 'Memuat Tiket...',
                          message:
                              'Sedang mengambil data peserta & kode QR verifikasi...',
                        )
                      : const MyArsEmptyCard(
                          icon: Icons.qr_code_2_rounded,
                          title: 'Data Tiket Tidak Ditemukan',
                          message:
                              'Tiket kehadiran tidak tersedia atau belum tersinkronisasi.',
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardingPassCard extends StatelessWidget {
  const _BoardingPassCard({required this.participant});

  final MyArsTicket participant;

  @override
  Widget build(BuildContext context) {
    final qrData = participant.qrCodePayload;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/img/appicon.png',
                    width: 24,
                    height: 24,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.verified_user_rounded,
                      size: 22,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'bungtemin.net',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'ABSENSI RESMI',
                    style: TextStyle(
                      color: Color(0xFF1D4ED8),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  participant.acara.isNotEmpty ? participant.acara : '-',
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 68,
                        height: 82,
                        color: const Color(0xFFF1F5F9),
                        child: participant.avatarUrl.isNotEmpty
                            ? Image.network(
                                participant.avatarUrl,
        headers: BtapiAuth.imageHeaders(participant.avatarUrl),
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
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'NAMA PESERTA',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            participant.nama.isNotEmpty
                                ? participant.nama
                                : '-',
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'NOREG',
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      participant.noreg.isNotEmpty
                                          ? participant.noreg
                                          : '-',
                                      style: const TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'DIVISI',
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Tooltip(
                                      message: participant.divisi,
                                      child: Text(
                                        MyArsTicket.formatDivisi(
                                          participant.divisi,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF0F172A),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _PerforationDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TANGGAL',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        MyArsTicket.formatDate(participant.tanggal),
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'CHECK IN',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        participant.jamMasuk.isNotEmpty
                            ? participant.jamMasuk
                            : '-',
                        style: const TextStyle(
                          color: Color(0xFF0284C7),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'STATUS',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      MyArsStatusChip(status: participant.status),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 164,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF0F172A),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Scan QR untuk verifikasi kehadiran',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PerforationDivider extends StatelessWidget {
  const _PerforationDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: LayoutBuilder(
              builder: (_, constraints) {
                const dashWidth = 6.0;
                const dashSpace = 5.0;
                final count =
                    (constraints.maxWidth / (dashWidth + dashSpace)).floor();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    count,
                    (_) => const SizedBox(
                      width: dashWidth,
                      height: 1.5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: -12,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: -12,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
