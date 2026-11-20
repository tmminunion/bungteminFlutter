import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/session_store.dart';
import '../../models/myars_models.dart';
import '../../services/myars_service.dart';
import 'myars_widgets.dart';

/// Scanner Panitia Event (`/myscanner/:id`).
/// Menyalin logika `MyscannerPage` (`bungteminAPP`):
/// - Menampilkan QR Code event (`absensi:<event_slug>`) untuk absen mandiri peserta.
/// - Memindai QR peserta (`untukabsen:`, `profil:`, `userid:`, `dt:`, atau noreg polos).
/// - Mengirim ke endpoint `nudb.bungtemin.net` dan ping WebSocket `PresenceService.setAbsensi()`.
class MyArsEventScannerScreen extends StatefulWidget {
  const MyArsEventScannerScreen({
    super.key,
    required this.eventSlug,
    required this.session,
    this.initialEvent,
    this.service,
  });

  final String eventSlug;
  final UserSession? session;
  final MyArsEvent? initialEvent;
  final MyArsService? service;

  @override
  State<MyArsEventScannerScreen> createState() =>
      _MyArsEventScannerScreenState();
}

class _MyArsEventScannerScreenState extends State<MyArsEventScannerScreen> {
  late final MyArsService _service;
  MyArsEvent? _eventDetail;
  bool _loading = false;
  bool _processing = false;

  String get _qrCodeStr => _eventDetail != null
      ? 'absensi:${widget.eventSlug}'
      : 'Event tidak ditemukan';

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MyArsService();
    _eventDetail = widget.initialEvent;
    _loadEventData();
  }

  Future<void> _loadEventData() async {
    if (_eventDetail == null) {
      setState(() => _loading = true);
    }
    final cached = await _service.findCachedEventBySlug(widget.eventSlug);
    if (!mounted) return;
    if (cached != null) {
      setState(() {
        _eventDetail = cached;
        _loading = false;
      });
      return;
    }

    try {
      final detail = await _service.getAbsensiById(widget.eventSlug);
      if (!mounted) return;
      setState(() {
        if (detail.event != null) {
          _eventDetail = detail.event;
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _startCameraScan() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => const _EventScannerOverlayPage(),
      ),
    );
    if (scanned != null && scanned.trim().isNotEmpty) {
      await _processScan(scanned);
    }
  }

  Future<void> _openManualInput() async {
    final ctrl = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Input Kode QR Peserta',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Contoh: profil:..., untukabsen:..., dt:..., 00123456',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
    if (raw != null && raw.trim().isNotEmpty) {
      await _processScan(raw);
    }
  }

  Future<void> _processScan(String raw) async {
    if (_processing) return;
    setState(() => _processing = true);

    MyArsScanActionResult result;
    try {
      result = await _service.processEventScannerQr(
        rawQr: raw,
        eventSlug: widget.eventSlug,
        session: widget.session,
      );
    } catch (_) {
      result = const MyArsScanActionResult(
        success: false,
        header: 'Error',
        message: 'Tidak bisa koneksi ke server',
      );
    }

    if (!mounted) return;
    setState(() => _processing = false);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          result.header,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: result.success
                ? const Color(0xFF15803D)
                : const Color(0xFFB91C1C),
          ),
        ),
        content: Text(result.message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ev = _eventDetail;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          Column(
            children: [
              MyArsHeroHeader(
                titleChip: 'PANITIA & PETUGAS',
                countLabel: ev != null ? 'Event #${ev.id}' : 'Scanner',
                title: 'Scanner Event',
                subtitle: 'Check-in peserta dan tampilkan QR absensi acara',
                iconAsset: 'assets/icon/9.png',
                icon: Icons.qr_code_scanner_rounded,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                  child: _loading && ev == null
                      ? const MyArsLoadingCard(
                          title: 'Memuat Detail Acara...',
                          message: 'Menyiapkan QR Code absensi event...',
                        )
                      : ev == null
                          ? const MyArsEmptyCard(
                              icon: Icons.event_busy_rounded,
                              title: 'Event Tidak Ditemukan',
                              message:
                                  'Pastikan daftar Acara Saya sudah dimuat terlebih dahulu.',
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(26),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x0D0F172A),
                                        blurRadius: 18,
                                        offset: Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDCFCE7),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: const Text(
                                              'QR Code Acara',
                                              style: TextStyle(
                                                color: Color(0xFF15803D),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            MyArsTicket.formatDate(
                                              ev.tanggalAcara,
                                            ),
                                            style: const TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        ev.namaAcara,
                                        style: const TextStyle(
                                          color: Color(0xFF0F172A),
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.location_on_outlined,
                                            size: 15,
                                            color: Color(0xFF64748B),
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              ev.tempat.isNotEmpty
                                                  ? ev.tempat
                                                  : 'Lokasi acara',
                                              style: const TextStyle(
                                                color: Color(0xFF64748B),
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 18),
                                      Center(
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius:
                                                BorderRadius.circular(22),
                                            border: Border.all(
                                              color: const Color(0xFFE2E8F0),
                                            ),
                                          ),
                                          child: QrImageView(
                                            data: _qrCodeStr,
                                            size: 196,
                                            version: QrVersions.auto,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      const Center(
                                        child: Text(
                                          'Scan QR ini dari aplikasi peserta untuk absen mandiri',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: _startCameraScan,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E3A8A),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 15,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.qr_code_scanner_rounded,
                                  ),
                                  label: const Text(
                                    'Mulai Scan Kehadiran',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: _openManualInput,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 13,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  icon: const Icon(Icons.keyboard_rounded),
                                  label: const Text(
                                    'Input Manual Noreg / Kode QR',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                ),
              ),
            ],
          ),
          if (_processing)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 14),
                        Text(
                          'Mengirim...',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EventScannerOverlayPage extends StatefulWidget {
  const _EventScannerOverlayPage();

  @override
  State<_EventScannerOverlayPage> createState() =>
      _EventScannerOverlayPageState();
}

class _EventScannerOverlayPageState extends State<_EventScannerOverlayPage> {
  final _ctrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim() ?? '';
      if (raw.isNotEmpty) {
        _handled = true;
        Navigator.of(context).pop(raw);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _ctrl,
            onDetect: _onDetect,
            errorBuilder: (_, __) => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Kamera tidak tersedia. Gunakan Input Manual kode QR.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          Positioned(
            top: topPad + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Scan Kehadiran Peserta',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    _ctrl.toggleTorch();
                    setState(() => _torchOn = !_torchOn);
                  },
                  icon: Icon(
                    _torchOn
                        ? Icons.flash_on_rounded
                        : Icons.flash_off_rounded,
                    color: Colors.white,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  label: const Text(
                    'Batal',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFF38BDF8),
                  width: 3,
                ),
              ),
            ),
          ),
          const Positioned(
            bottom: 42,
            left: 24,
            right: 24,
            child: Text(
              'Arahkan kamera ke QR Code peserta atau tiket event',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
