import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';

import '../../core/theme.dart';

class _EmoneyReadResult {
  const _EmoneyReadResult({
    required this.bankName,
    required this.cardNumber,
    required this.balance,
    required this.uidHex,
    required this.accentColor,
    required this.isUidOnly,
  });

  final String bankName;
  final String cardNumber;
  final int? balance;
  final String uidHex;
  final Color accentColor;
  final bool isUidOnly;
}

class NfcEmoneyScreen extends StatefulWidget {
  const NfcEmoneyScreen({super.key});

  @override
  State<NfcEmoneyScreen> createState() => _NfcEmoneyScreenState();
}

class _NfcEmoneyScreenState extends State<NfcEmoneyScreen>
    with SingleTickerProviderStateMixin {
  bool _checkingNfc = true;
  bool _nfcAvailable = false;
  bool _scanning = false;
  String? _errorMsg;
  _EmoneyReadResult? _result;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _initNfc();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    NfcManager.instance.stopSession().catchError((_) {});
    super.dispose();
  }

  Future<void> _initNfc() async {
    try {
      final available = await NfcManager.instance.isAvailable();
      if (!mounted) return;
      setState(() {
        _nfcAvailable = available;
        _checkingNfc = false;
      });
      if (available) {
        _startScan();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _nfcAvailable = false;
        _checkingNfc = false;
        _errorMsg = 'Gagal memeriksa NFC: $e';
      });
    }
  }

  Future<void> _startScan() async {
    if (_scanning) return;
    setState(() {
      _scanning = true;
      _errorMsg = null;
    });

    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            final res = await _readTag(tag);
            if (!mounted) return;
            setState(() {
              _result = res;
              _errorMsg = null;
            });
          } catch (e) {
            if (!mounted) return;
            setState(() {
              _errorMsg = 'Kartu terdeteksi, tapi gagal dibaca. Tempelkan lebih stabil.\n($e)';
            });
          }
        },
        onError: (error) async {
          if (!mounted) return;
          setState(() {
            _scanning = false;
            _errorMsg = error.message;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _errorMsg = 'Tidak dapat memulai sesi NFC: $e';
      });
    }
  }

  Future<_EmoneyReadResult> _readTag(NfcTag tag) async {
    final isoDep = IsoDep.from(tag);
    final nfcA = NfcA.from(tag);
    final uidBytes = isoDep?.identifier ?? nfcA?.identifier ?? Uint8List(0);
    final uidHex = _toHex(uidBytes, sep: ':');

    if (isoDep != null) {
      // 1. Mandiri e-Money
      final mandiri = await _tryMandiri(isoDep, uidHex);
      if (mandiri != null) return mandiri;

      // 2. BCA Flazz Gen 2
      final flazz = await _tryFlazzGen2(isoDep, uidHex);
      if (flazz != null) return flazz;

      // 3. BNI TapCash
      final tapcash = await _tryBniTapCash(isoDep, uidHex);
      if (tapcash != null) return tapcash;

      // 4. BRI Brizzi
      final brizzi = await _tryBriBrizzi(isoDep, uidHex);
      if (brizzi != null) return brizzi;
    }

    return _EmoneyReadResult(
      bankName: 'Kartu NFC / RFID (13.56 MHz)',
      cardNumber: uidHex.isNotEmpty ? uidHex : '-',
      balance: null,
      uidHex: uidHex,
      accentColor: AppColors.primaryBlue,
      isUidOnly: true,
    );
  }

  Future<_EmoneyReadResult?> _tryMandiri(IsoDep iso, String uidHex) async {
    try {
      // Select Mandiri e-Money AID: 00000000000001
      final sel = await iso.transceive(
        data: Uint8List.fromList([
          0x00, 0xA4, 0x04, 0x00, 0x08,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01,
        ]),
      );
      if (!_isSwOk(sel)) return null;

      // Get balance & card info
      final balResp = await iso.transceive(
        data: Uint8List.fromList([0x00, 0xB5, 0x00, 0x00, 0x0A]),
      );
      int? balance;
      if (_isSwOk(balResp) && balResp.length >= 6) {
        balance = (balResp[0] & 0xFF) |
            ((balResp[1] & 0xFF) << 8) |
            ((balResp[2] & 0xFF) << 16) |
            ((balResp[3] & 0xFF) << 24);
      }

      String cardNo = uidHex;
      final infoResp = await iso.transceive(
        data: Uint8List.fromList([0x00, 0xB3, 0x00, 0x00, 0x3F]),
      );
      if (_isSwOk(infoResp) && infoResp.length >= 16) {
        final rawHex = _toHex(infoResp.sublist(0, 8));
        if (RegExp(r'^\d{16}$').hasMatch(rawHex)) {
          cardNo = _formatCardNo(rawHex);
        }
      }

      if (balance == null) return null;
      return _EmoneyReadResult(
        bankName: 'Mandiri e-Money',
        cardNumber: cardNo,
        balance: balance,
        uidHex: uidHex,
        accentColor: const Color(0xFF003D79),
        isUidOnly: false,
      );
    } catch (_) {
      return null;
    }
  }

  Future<_EmoneyReadResult?> _tryFlazzGen2(IsoDep iso, String uidHex) async {
    try {
      // Select BCA Flazz Gen 2 AID: A0000000180F0000018001
      final sel = await iso.transceive(
        data: Uint8List.fromList([
          0x00, 0xA4, 0x04, 0x00, 0x0B,
          0xA0, 0x00, 0x00, 0x00, 0x18, 0x0F, 0x00, 0x00, 0x01, 0x80, 0x01,
        ]),
      );
      if (!_isSwOk(sel)) return null;

      final balResp = await iso.transceive(
        data: Uint8List.fromList([0x80, 0x5C, 0x00, 0x02, 0x04]),
      );
      if (!_isSwOk(balResp) || balResp.length < 6) return null;

      final balance = ((balResp[0] & 0xFF) << 24) |
          ((balResp[1] & 0xFF) << 16) |
          ((balResp[2] & 0xFF) << 8) |
          (balResp[3] & 0xFF);

      return _EmoneyReadResult(
        bankName: 'BCA Flazz (Gen 2)',
        cardNumber: uidHex,
        balance: balance,
        uidHex: uidHex,
        accentColor: const Color(0xFF005EB8),
        isUidOnly: false,
      );
    } catch (_) {
      return null;
    }
  }

  Future<_EmoneyReadResult?> _tryBniTapCash(IsoDep iso, String uidHex) async {
    try {
      final sel = await iso.transceive(
        data: Uint8List.fromList([
          0x00, 0xA4, 0x04, 0x00, 0x08,
          0xA0, 0x00, 0x42, 0x4E, 0x49, 0x10, 0x00, 0x01,
        ]),
      );
      if (!_isSwOk(sel)) return null;

      final balResp = await iso.transceive(
        data: Uint8List.fromList([0x90, 0x32, 0x03, 0x00, 0x00]),
      );
      if (balResp.length < 5) return null;
      final sw1 = balResp[balResp.length - 2];
      final sw2 = balResp[balResp.length - 1];
      if (!((sw1 == 0x90 && sw2 == 0x00) || (sw1 == 0x91 && sw2 == 0x00))) {
        return null;
      }

      // Purse balance (24-bit big-endian at offset 2..4 when available)
      final balance = balResp.length >= 7
          ? (((balResp[2] & 0xFF) << 16) |
              ((balResp[3] & 0xFF) << 8) |
              (balResp[4] & 0xFF))
          : 0;

      return _EmoneyReadResult(
        bankName: 'BNI TapCash',
        cardNumber: uidHex,
        balance: balance,
        uidHex: uidHex,
        accentColor: const Color(0xFFF15A24),
        isUidOnly: false,
      );
    } catch (_) {
      return null;
    }
  }

  Future<_EmoneyReadResult?> _tryBriBrizzi(IsoDep iso, String uidHex) async {
    try {
      final sel = await iso.transceive(
        data: Uint8List.fromList([
          0x00, 0xA4, 0x04, 0x00, 0x07,
          0xA0, 0x00, 0x00, 0x01, 0x41, 0x00, 0x01,
        ]),
      );
      if (!_isSwOk(sel)) return null;

      final balResp = await iso.transceive(
        data: Uint8List.fromList([
          0x90, 0xBD, 0x00, 0x00, 0x07,
          0x01, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00,
        ]),
      );
      int? balance;
      if (balResp.length >= 6) {
        balance = (balResp[0] & 0xFF) |
            ((balResp[1] & 0xFF) << 8) |
            ((balResp[2] & 0xFF) << 16) |
            ((balResp[3] & 0xFF) << 24);
      }

      return _EmoneyReadResult(
        bankName: 'BRI Brizzi',
        cardNumber: uidHex,
        balance: balance,
        uidHex: uidHex,
        accentColor: const Color(0xFF00529C),
        isUidOnly: balance == null,
      );
    } catch (_) {
      return null;
    }
  }

  bool _isSwOk(Uint8List resp) {
    if (resp.length < 2) return false;
    final sw1 = resp[resp.length - 2];
    final sw2 = resp[resp.length - 1];
    return sw1 == 0x90 && sw2 == 0x00;
  }

  String _toHex(Uint8List bytes, {String sep = ''}) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(sep);
  }

  String _formatCardNo(String raw) {
    final buf = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(raw[i]);
    }
    return buf.toString();
  }

  String _formatRupiah(int amount) {
    final s = amount.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final revIdx = s.length - i;
      if (i > 0 && revIdx % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp $buf';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Cek Saldo E-Money (NFC)'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildScannerBanner(),
          const SizedBox(height: 16),
          if (_errorMsg != null) _buildErrorCard(_errorMsg!),
          if (_result != null) _buildResultCard(_result!),
          const SizedBox(height: 16),
          _buildSupportedCardsInfo(),
        ],
      ),
    );
  }

  Widget _buildScannerBanner() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, Color(0xFF1E1B4B)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) {
              final scale = _nfcAvailable && _scanning
                  ? 1.0 + (_pulseCtrl.value * 0.08)
                  : 1.0;
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.auroraCyan.withValues(alpha: 0.14),
                    border: Border.all(
                      color: AppColors.auroraCyan.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    _nfcAvailable ? Icons.nfc_rounded : Icons.portable_wifi_off_rounded,
                    size: 40,
                    color: _nfcAvailable ? AppColors.auroraCyan : Colors.amberAccent,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          Text(
            _checkingNfc
                ? 'Memeriksa Sensor NFC...'
                : _nfcAvailable
                    ? 'Tempelkan Kartu ke Belakang HP'
                    : 'NFC Tidak Aktif / Tidak Tersedia',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _nfcAvailable
                ? 'Tahan kartu E-Money atau ID Card 13.56 MHz selama 1–2 detik hingga terbaca.'
                : 'Aktifkan NFC di Pengaturan HP Anda lalu tekan tombol cek ulang.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          if (!_checkingNfc && !_nfcAvailable) ...[
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _initNfc,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.auroraCyan,
                foregroundColor: AppColors.navy,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                'Cek Ulang NFC',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorCard(String msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(_EmoneyReadResult res) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [res.accentColor, AppColors.navy],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: res.accentColor.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  res.bankName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(Icons.contactless_rounded, color: Colors.white70, size: 26),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            res.balance != null ? 'Sisa Saldo' : 'UID Kartu (Non-Emoney)',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            res.balance != null ? _formatRupiah(res.balance!) : res.uidHex,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nomor / UID Kartu',
                      style: TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      res.cardNumber,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
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

  Widget _buildSupportedCardsInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kartu yang Didukung',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '• Mandiri e-Money (ISO-DEP)\n'
            '• BCA Flazz Gen 2 (berlogo NFC)\n'
            '• BNI TapCash & BRI Brizzi\n'
            '• ID Card / Kartu RFID 13.56 MHz (tampil UID)',
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.muted,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
