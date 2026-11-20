import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/bungtemin_crypto.dart';
import '../../core/session_store.dart';
import '../../core/theme.dart';
import '../../services/bungtemin_api.dart';
import '../../services/myars_service.dart';

enum BtScanKind {
  meetingTicket,
  meetingSelfCheckin,
  eventAbsensi,
  eventTiket,
  ticketDt,
  profil,
  epassJson,
  url,
  plainText,
}

class BtScanAction {
  const BtScanAction({
    required this.kind,
    required this.payload,
    this.meetingId = '',
  });

  final BtScanKind kind;
  final String payload;
  final String meetingId;
}

/// Normalisasi & klasifikasi isi QR yang dipindai BTScan agar mendukung semua
/// format QR absensi Bungtemin (`absensi:`, URL `/gambar/qrcode/absensi:`,
/// `/absensi/camera/:slug`, `untukabsen:`, `dt:`, `MTG-...`, `meeting:`,
/// `profil:`/`userid:`, serta E-Pass JSON `{n,r,c}`).
BtScanAction parseBtScanQr(String rawInput) {
  final raw = rawInput.trim();
  if (raw.isEmpty) {
    return const BtScanAction(kind: BtScanKind.plainText, payload: '');
  }

  final decoded = raw.contains('%') ? _safeUriDecode(raw) : raw;

  final mtgMatch =
      RegExp(r'MTG-(\d+)-[A-Za-z0-9]+', caseSensitive: false).firstMatch(raw);
  final delimIdx = decoded.indexOf(':');
  final prefix =
      delimIdx != -1 ? decoded.substring(0, delimIdx).toLowerCase() : '';
  final payload =
      delimIdx != -1 ? decoded.substring(delimIdx + 1).trim() : decoded;

  if (prefix == 'ticket' || prefix == 'tkt' || mtgMatch != null) {
    return BtScanAction(
      kind: BtScanKind.meetingTicket,
      payload: raw,
      meetingId: mtgMatch?.group(1) ?? '',
    );
  }

  // Deteksi QR absensi event baik langsung (`absensi:<slug>`) maupun dibungkus URL
  final absensiEmbedded = RegExp(
    r'(?:^|[/?=&#])absensi:([A-Za-z0-9_\-]+)',
    caseSensitive: false,
  ).firstMatch(decoded);
  if (absensiEmbedded != null) {
    return BtScanAction(
      kind: BtScanKind.eventAbsensi,
      payload: absensiEmbedded.group(1)!.trim(),
    );
  }

  final uri = Uri.tryParse(decoded);
  if (uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.contains('bungtemin')) {
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    // /absensi/camera/<slug> atau /absensi/rakernit2025/lihat/<slug>
    if (segs.length >= 3 &&
        segs[0].toLowerCase() == 'absensi' &&
        (segs[1].toLowerCase() == 'camera' ||
            segs[2].toLowerCase() == 'lihat')) {
      final slugCandidate = segs.last.trim();
      if (slugCandidate.isNotEmpty &&
          slugCandidate.toLowerCase() != 'kirimabsen') {
        return BtScanAction(
          kind: BtScanKind.eventAbsensi,
          payload: slugCandidate,
        );
      }
    }
    if (decoded.toLowerCase().contains('profil:') ||
        decoded.toLowerCase().contains('userid:')) {
      final idx = decoded.toLowerCase().contains('profil:')
          ? decoded.toLowerCase().indexOf('profil:')
          : decoded.toLowerCase().indexOf('userid:');
      return BtScanAction(
        kind: BtScanKind.profil,
        payload: decoded.substring(idx),
      );
    }
  }

  // JSON E-Pass Tiket `{"n":...,"r":"00415024","c":"Absensi..."}`
  if (raw.startsWith('{')) {
    try {
      final map = jsonDecode(raw);
      if (map is Map && map['r'] != null) {
        return BtScanAction(
          kind: BtScanKind.epassJson,
          payload: map['r'].toString().trim(),
        );
      }
    } catch (_) {}
  }

  switch (prefix) {
    case 'http':
    case 'https':
      return BtScanAction(kind: BtScanKind.url, payload: raw);
    case 'dt':
      return BtScanAction(kind: BtScanKind.ticketDt, payload: payload);
    case 'untukabsen':
      return BtScanAction(kind: BtScanKind.eventTiket, payload: payload);
    case 'absensi':
      return BtScanAction(kind: BtScanKind.eventAbsensi, payload: payload);
    case 'meeting':
      return BtScanAction(
        kind: BtScanKind.meetingSelfCheckin,
        payload: payload,
      );
    case 'profil':
    case 'userid':
      return BtScanAction(kind: BtScanKind.profil, payload: raw);
    default:
      return BtScanAction(kind: BtScanKind.plainText, payload: raw);
  }
}

String _safeUriDecode(String value) {
  try {
    return Uri.decodeComponent(value);
  } catch (_) {
    return value;
  }
}

/// BTScan Digital — clone dari `bungteminAPP/src/app/scanner/`:
/// 1. Kartu QR Identitas Terenkripsi AES-256 URL-Safe (`profil:...` / `profil:guest`).
/// 2. Live Camera Scanner dengan `MobileScanner` (torch, switch camera, kotak pemindai).
/// 3. Routing hasil scan (`ticket:`/`tkt:`/`MTG-`, `meeting:`, `absensi:`, `dt:`, `http/https`, `profil:`/`userid:`).
/// 4. Hasil Pemindaian QR sheet dengan dekripsi Noreg & Salin Hasil Scan.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({
    super.key,
    required this.session,
    required this.onRequireLogin,
  });

  final UserSession? session;
  final void Function(String reason, VoidCallback afterLogin) onRequireLogin;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  static const _kLastScanKey = 'bt_last_scan';

  final _api = BungteminApi();
  String _lastScan = '';
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _loadLastScan();
  }

  Future<void> _loadLastScan() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kLastScanKey) ?? '';
    if (!mounted) return;
    setState(() => _lastScan = saved);
  }

  Future<void> _saveLastScan(String raw) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastScanKey, raw);
    if (mounted) setState(() => _lastScan = raw);
  }

  String get _memberQrData {
    final s = widget.session;
    if (s == null || s.noreg.trim().isEmpty) {
      return 'profil:guest';
    }
    final encrypted = BungteminCrypto.encrypt(s.noreg);
    return 'profil:${encrypted.isNotEmpty ? encrypted : s.noreg}';
  }

  Future<void> _openCameraScanner() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => const _CameraScannerPage(),
      ),
    );
    if (scanned != null && scanned.trim().isNotEmpty) {
      await _handleScannedCode(scanned.trim());
    }
  }

  Future<void> _handleScannedCode(String raw) async {
    await _saveLastScan(raw);
    if (!mounted) return;

    final action = parseBtScanQr(raw);
    switch (action.kind) {
      case BtScanKind.meetingTicket:
        await _processMeetingTicket(action.payload, action.meetingId);
        break;
      case BtScanKind.url:
        _showResultSheet(raw, launchableUrl: raw);
        break;
      case BtScanKind.ticketDt:
        await _processTicketDt(action.payload);
        break;
      case BtScanKind.eventTiket:
        await _processEventTiket(action.payload);
        break;
      case BtScanKind.eventAbsensi:
        await _processAbsensi(action.payload);
        break;
      case BtScanKind.meetingSelfCheckin:
        await _processMeetingSelfCheckin(action.payload);
        break;
      case BtScanKind.profil:
        _showResultSheet(
          raw,
          decryptedNoreg: BungteminCrypto.decrypt(action.payload),
        );
        break;
      case BtScanKind.epassJson:
        _showResultSheet(
          raw,
          decryptedNoreg: action.payload,
        );
        break;
      case BtScanKind.plainText:
        _showResultSheet(raw);
        break;
    }
  }

  Future<void> _processEventTiket(String kode) async {
    final s = widget.session;
    if (s == null) {
      widget.onRequireLogin(
        'Masuk terlebih dahulu untuk memproses tiket absensi event.',
        () => _processEventTiket(kode),
      );
      return;
    }
    setState(() => _processing = true);
    try {
      final result = await MyArsService().addFromTiket(kode, session: s);
      if (!mounted) return;
      await _showStatusDialog(
        result.header,
        result.message,
        success: result.success,
      );
    } catch (e) {
      if (!mounted) return;
      await _showStatusDialog('Gagal Absensi Tiket', e.toString());
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _processMeetingTicket(String rawCode, String meetingId) async {
    final s = widget.session;
    if (s == null) {
      widget.onRequireLogin(
        'Masuk terlebih dahulu untuk verifikasi tiket meeting.',
        () => _processMeetingTicket(rawCode, meetingId),
      );
      return;
    }
    if (meetingId.isEmpty) {
      _showResultSheet(rawCode);
      return;
    }

    setState(() => _processing = true);
    try {
      final msg = await _api.scanMeetingTicket(
        meetingId: meetingId,
        code: rawCode,
        noreg: s.noreg,
        token: s.token,
      );
      if (!mounted) return;
      await _showStatusDialog('Check-In Tiket Berhasil', msg, success: true);
    } catch (e) {
      if (!mounted) return;
      await _showStatusDialog('Gagal Check-In Tiket', e.toString());
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _processMeetingSelfCheckin(String meetingRef) async {
    final s = widget.session;
    if (s == null) {
      widget.onRequireLogin(
        'Masuk terlebih dahulu untuk absensi meeting.',
        () => _processMeetingSelfCheckin(meetingRef),
      );
      return;
    }
    setState(() => _processing = true);
    try {
      final msg = await _api.selfCheckinMeeting(
        meetingRef: meetingRef,
        noreg: s.noreg,
        token: s.token,
      );
      if (!mounted) return;
      await _showStatusDialog('Check-In Berhasil', msg, success: true);
    } catch (e) {
      if (!mounted) return;
      await _showStatusDialog('Gagal Check-In', e.toString());
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _processAbsensi(String eventId) async {
    final s = widget.session;
    if (s == null) {
      widget.onRequireLogin(
        'Masuk terlebih dahulu untuk mencatat absensi event.',
        () => _processAbsensi(eventId),
      );
      return;
    }
    setState(() => _processing = true);
    try {
      final msg = await _api.submitNuAbsensi(eventId: eventId, session: s);
      if (!mounted) return;
      await _showStatusDialog('Absensi Berhasil', msg, success: true);
    } catch (e) {
      if (!mounted) return;
      await _showStatusDialog('Gagal Absensi', e.toString());
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _processTicketDt(String barcode) async {
    final s = widget.session;
    if (s == null) {
      widget.onRequireLogin(
        'Masuk terlebih dahulu untuk mengirim tiket absensi.',
        () => _processTicketDt(barcode),
      );
      return;
    }
    setState(() => _processing = true);
    try {
      final msg = await _api.submitNuTicketDt(barcode: barcode, session: s);
      if (!mounted) return;
      await _showStatusDialog('Tiket Berhasil', msg, success: true);
    } catch (e) {
      if (!mounted) return;
      await _showStatusDialog('Gagal Kirim Tiket', e.toString());
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _showStatusDialog(
    String title,
    String message, {
    bool success = false,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              color: success ? AppColors.emerald : Colors.redAccent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(height: 1.45)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showResultSheet(
    String raw, {
    String? decryptedNoreg,
    String? launchableUrl,
  }) {
    final resolvedDecrypted = (decryptedNoreg != null && decryptedNoreg.isNotEmpty)
        ? decryptedNoreg
        : ((raw.toLowerCase().startsWith('profil:') ||
                raw.toLowerCase().startsWith('userid:'))
            ? BungteminCrypto.decrypt(raw)
            : '');

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(ctx).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mini Aurora Header inside sheet
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.navy, AppColors.navyMid],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.emerald.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 13,
                                  color: AppColors.emerald,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Scan Berhasil',
                                  style: TextStyle(
                                    color: AppColors.emerald,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Hasil Pemindaian QR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (resolvedDecrypted.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            size: 16,
                            color: Color(0xFF047857),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'NOREG Terdekripsi (AES-256)',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        resolvedDecrypted,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.navy,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 16,
                          color: AppColors.primaryBlue,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Konten QR Terdeteksi',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      raw,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    QrImageView(
                      data: raw,
                      size: 170,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'QR-ID Digital Code',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (launchableUrl != null) ...[
                FilledButton.icon(
                  onPressed: () async {
                    final uri = Uri.tryParse(launchableUrl);
                    if (uri != null) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text(
                    'Buka Tautan di Browser',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: raw));
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Teks berhasil disalin!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.copy_rounded),
                label: const Text(
                  'Salin Hasil Scan',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              // Aurora Hero Header
              Container(
                padding: EdgeInsets.fromLTRB(18, topPad + 12, 18, 48),
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
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(32),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _ScannerPillBtn(
                          icon: Icons.arrow_back_rounded,
                          label: 'Beranda',
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        _ScannerPillBtn(
                          icon: Icons.qr_code_scanner_rounded,
                          label: 'Pindai QR',
                          accent: true,
                          onTap: _openCameraScanner,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Image.asset('assets/icon/9.png'),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'VERIFIKASI & ABSENSI QR',
                                style: TextStyle(
                                  color: Color(0xFF7DD3FC),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'BTScan Digital',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Tunjukkan QR identitas Anda atau pindai QR acara / anggota',
                                style: TextStyle(
                                  color: Color(0xFFCBD5E1),
                                  fontSize: 12,
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

              // Main Card Container overlapping hero
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                child: Transform.translate(
                  offset: const Offset(0, -28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Member Encrypted QR Card
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.navy.withValues(alpha: 0.10),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryBlue
                                        .withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'QR Identitas Terenkripsi',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primaryBlue,
                                    ),
                                  ),
                                ),
                                const Text(
                                  'AES-256 URL-Safe',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFDBEAFE),
                                  width: 1.5,
                                ),
                              ),
                              child: QrImageView(
                                data: _memberQrData,
                                size: 210,
                                backgroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Primary Scan CTA
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _openCameraScanner,
                          borderRadius: BorderRadius.circular(18),
                          child: Ink(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.primaryBlue,
                                  AppColors.indigo,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryBlue
                                      .withValues(alpha: 0.30),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.qr_code_2_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Mulai Scan QR Code',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_lastScan.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () => _showResultSheet(_lastScan),
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryBlue
                                        .withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.receipt_long_rounded,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Hasil Scan Terakhir',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _lastScan,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.navy,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.muted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_processing)
            Container(
              color: AppColors.navy.withValues(alpha: 0.55),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.auroraCyan),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScannerPillBtn extends StatelessWidget {
  const _ScannerPillBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: accent
              ? AppColors.auroraCyan.withValues(alpha: 0.24)
              : Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: accent
                ? AppColors.auroraCyan.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraScannerPage extends StatefulWidget {
  const _CameraScannerPage();

  @override
  State<_CameraScannerPage> createState() => _CameraScannerPageState();
}

class _CameraScannerPageState extends State<_CameraScannerPage> {
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
      final val = barcode.rawValue?.trim();
      if (val != null && val.isNotEmpty) {
        _handled = true;
        Navigator.of(context).pop(val);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _ctrl,
            onDetect: _onDetect,
            errorBuilder: (_, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.videocam_off_rounded,
                      color: Colors.white70,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Kamera belum dapat dibuka (${error.errorCode.name}).\nPastikan izin kamera diaktifkan.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Kembali'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Viewfinder Frame
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.auroraCyan, width: 3),
              ),
            ),
          ),

          // Top Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Arahkan Kamera ke QR Code',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Batalkan',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Controls (Flash & Switch Camera)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 28,
            left: 24,
            right: 24,
            child: Column(
              children: [
                const Text(
                  'Posisikan QR di dalam kotak pemindai dengan cahaya cukup',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filled(
                      onPressed: () {
                        _ctrl.toggleTorch();
                        setState(() => _torchOn = !_torchOn);
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.6),
                      ),
                      icon: Icon(
                        _torchOn
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        color: _torchOn ? AppColors.gold : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 20),
                    IconButton.filled(
                      onPressed: _ctrl.switchCamera,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.6),
                      ),
                      icon: const Icon(
                        Icons.cameraswitch_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
