import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/session_store.dart';
import '../../core/theme.dart';
import '../../models/kta_member.dart';
import '../../services/bungtemin_api.dart';
import '../../core/net/btapi_auth.dart';


class KtaDigitalScreen extends StatefulWidget {
  const KtaDigitalScreen({
    super.key,
    required this.session,
    this.initialMember,
    this.onAddressUpdated,
  });

  final UserSession session;
  final KtaMember? initialMember;
  final VoidCallback? onAddressUpdated;

  @override
  State<KtaDigitalScreen> createState() => _KtaDigitalScreenState();
}

class _KtaDigitalScreenState extends State<KtaDigitalScreen> {
  final _ktaKey = GlobalKey<_KtaTabState>();
  final _api = BungteminApi();

  Future<void> _openEditDomisiliDialog() async {
    final currentAlamat =
        _ktaKey.currentState?._member?.alamat ?? widget.initialMember?.alamat ?? '';
    final ctrl = TextEditingController(
      text: currentAlamat.trim() == '-' ? '' : currentAlamat.trim(),
    );
    var saving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setModalState) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: const Row(
              children: [
                Icon(Icons.edit_location_alt_rounded, color: AppColors.primaryBlue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ubah Alamat Domisili',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: TextField(
              controller: ctrl,
              minLines: 2,
              maxLines: 4,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Alamat Domisili',
                hintText: 'Masukkan alamat domisili lengkap...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final alamat = ctrl.text.trim();
                        if (alamat.length < 5) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Alamat domisili minimal 5 karakter.'),
                              backgroundColor: AppColors.amber,
                            ),
                          );
                          return;
                        }
                        setModalState(() => saving = true);
                        try {
                          final msg = await _api.updateAddress(
                            alamat: alamat,
                            token: widget.session.token,
                          );
                          if (!mounted) return;
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          await _ktaKey.currentState?._loadKta();
                          widget.onAddressUpdated?.call();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(msg),
                              backgroundColor: AppColors.emerald,
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          setModalState(() => saving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.toString()),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Simpan'),
              ),
            ],
          ),
        ),
      );
    } finally {
      ctrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1325),
        title: const Text(
          'KTA Digital FSP LEM SPSI',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5),
        ),
        actions: [
          IconButton(
            onPressed: _openEditDomisiliDialog,
            icon: const Icon(Icons.edit_rounded, size: 20),
            tooltip: 'Ubah Alamat Domisili',
          ),
        ],
      ),
      body: KtaTab(
        key: _ktaKey,
        session: widget.session,
        initialMember: widget.initialMember,
      ),
    );
  }
}

class KtaTab extends StatefulWidget {
  const KtaTab({
    super.key,
    required this.session,
    this.initialMember,
  });

  final UserSession session;
  final KtaMember? initialMember;

  @override
  State<KtaTab> createState() => _KtaTabState();
}

class _KtaTabState extends State<KtaTab> with SingleTickerProviderStateMixin {
  final _api = BungteminApi();
  late final AnimationController _flipCtrl;
  KtaMember? _member;
  bool _loading = true;
  String? _error;
  bool _isFlipped = false;
  bool _isStackMode = false;
  bool _showBirth = false;

  static const double _cardWidth = 332;
  static const double _cardHeight = 516;

  @override
  void initState() {
    super.initState();
    _flipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 580),
    );
    if (widget.initialMember != null) {
      _member = widget.initialMember;
      _loading = false;
    } else {
      _loadKta();
    }
  }

  @override
  void didUpdateWidget(covariant KtaTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.noreg != widget.session.noreg &&
        widget.initialMember == null) {
      _loadKta();
    }
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadKta() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.fetchKta(
        noreg: widget.session.noreg,
        token: widget.session.token,
      );
      if (!mounted) return;
      setState(() => _member = res);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _toggleFlip() {
    setState(() => _isFlipped = !_isFlipped);
    if (_isFlipped) {
      _flipCtrl.forward();
    } else {
      _flipCtrl.reverse();
    }
  }

  void _toggleViewMode() {
    setState(() => _isStackMode = !_isStackMode);
  }

  void _openQrModal(KtaMember member) {
    showDialog<void>(
      context: context,
      barrierColor: AppColors.navy.withValues(alpha: 0.85),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.sky,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'QR PRESENSI & PROFIL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close_rounded, color: AppColors.muted),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),

              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.sky, width: 2),
                ),
                child: QrImageView(
                  data: member.qrProfil,
                  size: 210,
                  backgroundColor: Colors.white,
                ),
              ),

              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Tutup',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
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
    if (_loading) {
      return const _KtaStageBackdrop(
        child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }
    if (_error != null || _member == null) {
      return _KtaStageBackdrop(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 46,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 10),
                Text(
                  _error ?? 'Data KTA tidak tersedia.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _loadKta,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final member = _member!;

    return _KtaStageBackdrop(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_isStackMode) ...[
                GestureDetector(
                  onTap: _toggleFlip,
                  child: AnimatedBuilder(
                    animation: _flipCtrl,
                    builder: (context, _) {
                      final angle = _flipCtrl.value * math.pi;
                      final showBack = angle > (math.pi / 2);
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0009)
                          ..rotateY(angle),
                        child: showBack
                            ? Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()..rotateY(math.pi),
                                child: _buildBackCard(member),
                              )
                            : _buildFrontCard(member),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _toggleFlip,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.sync_rounded,
                          color: AppColors.auroraCyan,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Ketuk kartu untuk membalik (${_isFlipped ? 'Tampak Belakang' : 'Tampak Depan'})',
                          style: const TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                const Text(
                  'TAMPAK DEPAN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 8),
                _buildFrontCard(member),
                const SizedBox(height: 22),
                const Text(
                  'TAMPAK BELAKANG',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 8),
                _buildBackCard(member),
              ],
              const SizedBox(height: 16),
              // Action Controls Row matching bungteminAPP
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _cardWidth),
                child: Row(
                  children: [
                    if (!_isStackMode) ...[
                      Expanded(
                        child: _KtaActionButton(
                          icon: Icons.sync_rounded,
                          label: _isFlipped ? 'Depan' : 'Balik',
                          gradient: const [
                            AppColors.sky,
                            Color(0xFF0369A1),
                          ],
                          foreground: Colors.white,
                          onTap: _toggleFlip,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: _KtaActionButton(
                        icon: _isStackMode
                            ? Icons.view_in_ar_rounded
                            : Icons.layers_outlined,
                        label: _isStackMode ? 'Mode 3D' : '2 Sisi',
                        background: Colors.white.withValues(alpha: 0.92),
                        foreground: AppColors.navy,
                        onTap: _toggleViewMode,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _KtaActionButton(
                        icon: Icons.qr_code_2_rounded,
                        label: 'QR Besar',
                        gradient: const [AppColors.gold, AppColors.amber],
                        foreground: AppColors.navy,
                        onTap: () => _openQrModal(member),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Frame dasar KTA resmi hasil MUNAS: background `assets/card/bg.png` (300% centered)
  /// dan header resmi `assets/card/card-header.png`.
  Widget _buildMunasCardFrame({required Widget body}) {
    return Container(
      width: _cardWidth,
      height: _cardHeight,
      decoration: BoxDecoration(
        color: const Color(0xFFE9EAEC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xB8DEE0E3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background resmi hasil MUNAS: background-size: 300%, center
            Positioned.fill(
              child: OverflowBox(
                maxWidth: _cardWidth * 3.0,
                maxHeight: _cardWidth * 2.2,
                child: Image.asset(
                  'assets/card/bg.png',
                  width: _cardWidth * 3.0,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 14, 15, 13),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 245),
                    child: Image.asset(
                      'assets/card/card-header.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  Expanded(child: body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrontCard(KtaMember m) {
    return _buildMunasCardFrame(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(height: 4),
          // Avatar 92x92 bulat border putih 3px
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.network(
                m.avatarUrl,
        headers: BtapiAuth.imageHeaders(m.avatarUrl),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Image.asset(
                  'assets/card/character.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          // Member Info Center
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    m.nama.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: AppColors.navy,
                      height: 1.18,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    m.job.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navySoft,
                        ),
                        children: [
                          const TextSpan(text: 'ID : '),
                          TextSpan(
                            text: m.ktaNumber,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'SP LEM SPSI PT. TMMIN',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${m.lokasi.toUpperCase()} • ${m.plant}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom Blue Bar + QR Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E3A8A).withValues(alpha: 0.30),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'KEANGGOTAAN',
                        style: TextStyle(
                          color: Color(0xFFBFDBFE),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        m.aktif ? 'AKTIF' : 'NONAKTIF',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Berlaku s.d : ${m.berlaku}',
                        style: const TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _openQrModal(m),
                  child: Container(
                    width: 50,
                    height: 50,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: m.qrProfil,
                      size: 42,
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackCard(KtaMember m) {
    return _buildMunasCardFrame(
      body: Column(
        children: [
          const SizedBox(height: 6),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.navy.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BackInfoRow(label: 'Nama Lengkap', value: m.nama),
                  const _DashedDivider(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TEMPAT / TANGGAL LAHIR',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: () => setState(() => _showBirth = !_showBirth),
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '${m.tempatLahir}, ',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: _showBirth
                                    ? AppColors.sky.withValues(alpha: 0.12)
                                    : AppColors.navy.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: ImageFiltered(
                                imageFilter: ImageFilter.blur(
                                  sigmaX: (m.tglLahir == '-' || !_showBirth)
                                      ? 4.5
                                      : 0,
                                  sigmaY: (m.tglLahir == '-' || !_showBirth)
                                      ? 4.5
                                      : 0,
                                ),
                                child: Text(
                                  m.tglLahir == '-' ? '•• •••••• ••••' : m.tglLahir,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.navy,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const _DashedDivider(),
                  _BackInfoRow(label: 'Agama', value: m.agama.toUpperCase()),
                  const _DashedDivider(),
                  _BackInfoRow(
                    label: 'Alamat Domisili',
                    value: m.alamat,
                    maxLines: 3,
                  ),
                  const _DashedDivider(),
                  _BackInfoRow(
                    label: 'Departemen / Divisi',
                    value: '${m.dept} (${m.divisi})',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Column(
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: Color(0xFF334155),
                    ),
                    children: [
                      const TextSpan(text: 'Nomor Anggota: '),
                      TextSpan(
                        text: m.ktaNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 1),
                const Text(
                  'Di-generate oleh bungtemin.net',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
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

class _KtaStageBackdrop extends StatelessWidget {
  const _KtaStageBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.navyDeep,
                AppColors.navy,
                Color(0xFF131C33),
              ],
            ),
          ),
        ),
        Positioned(
          top: -60,
          left: -50,
          child: _GlowSpot(
            size: 220,
            color: AppColors.auroraCyan.withValues(alpha: 0.16),
          ),
        ),
        Positioned(
          top: 40,
          right: -60,
          child: _GlowSpot(
            size: 230,
            color: AppColors.auroraIndigo.withValues(alpha: 0.18),
          ),
        ),
        Positioned(
          bottom: -50,
          left: 60,
          child: _GlowSpot(
            size: 220,
            color: AppColors.gold.withValues(alpha: 0.12),
          ),
        ),
        child,
      ],
    );
  }
}

class _GlowSpot extends StatelessWidget {
  const _GlowSpot({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _KtaActionButton extends StatelessWidget {
  const _KtaActionButton({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.onTap,
    this.gradient,
    this.background,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final VoidCallback onTap;
  final List<Color>? gradient;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            color: gradient == null ? background : null,
            gradient: gradient != null
                ? LinearGradient(colors: gradient!)
                : null,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: foreground),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: foreground,
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

class _BackInfoRow extends StatelessWidget {
  const _BackInfoRow({
    required this.label,
    required this.value,
    this.maxLines = 2,
  });

  final String label;
  final String value;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 1.5),
        Text(
          value,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        const dashWidth = 4.0;
        const dashSpace = 3.0;
        final count =
            (constraints.maxWidth / (dashWidth + dashSpace)).floor().clamp(1, 100);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => const SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Color(0xFFCBD5E1)),
              ),
            ),
          ),
        );
      },
    );
  }
}
