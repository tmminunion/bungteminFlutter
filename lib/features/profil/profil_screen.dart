import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/bungtemin_crypto.dart';
import '../../core/session_store.dart';
import '../../core/theme.dart';
import '../../models/kta_member.dart';
import '../../services/bungtemin_api.dart';
import '../kta/kta_tab.dart';
import '../../core/net/btapi_auth.dart';

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({
    super.key,
    required this.session,
    this.initialMember,
    this.initialSegment = 0,
  });

  final UserSession session;
  final KtaMember? initialMember;
  final int initialSegment;

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  final _api = BungteminApi();
  int _activeSegment = 0;
  KtaMember? _member;
  bool _loading = true;
  bool? _hasPin;
  String _waNumber = '';

  @override
  void initState() {
    super.initState();
    _activeSegment = widget.initialSegment;
    _loadPinStatus();
    if (widget.initialMember != null) {
      _member = widget.initialMember;
      _loading = false;
    } else {
      _loadCachedAndFreshKta();
    }
  }

  Future<void> _loadPinStatus() async {
    final info = await _api.fetchSecurityProfile(token: widget.session.token);
    if (!mounted) return;
    setState(() {
      if (info.hasPin != null) _hasPin = info.hasPin;
      if (info.waNumber.isNotEmpty) _waNumber = info.waNumber;
    });
  }

  Future<void> _loadCachedAndFreshKta() async {
    final cached = await SessionStore().loadKtaCache();
    if (cached != null) {
      try {
        final decoded = jsonDecode(cached);
        if (decoded is Map<String, dynamic> && mounted) {
          setState(() {
            _member = KtaMember.fromJson(decoded);
            _loading = false;
          });
        }
      } catch (_) {}
    }

    try {
      final fresh = await _api.fetchKta(
        noreg: widget.session.noreg,
        token: widget.session.token,
      );
      if (!mounted) return;
      setState(() {
        _member = fresh;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _selectTab(int index) {
    setState(() => _activeSegment = index);
  }

  void _openKtaScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF0B1325),
            title: const Text(
              'KTA Digital FSP LEM SPSI',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5),
            ),
          ),
          body: KtaTab(
            session: widget.session,
            initialMember: _member,
          ),
        ),
      ),
    );
  }

  Future<void> _openChangePinDialog() async {
    final pinCtrl = TextEditingController();
    var obscure = true;
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Row(
            children: [
              Icon(Icons.key_rounded, color: AppColors.primaryBlue),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Atur / Ganti PIN Login',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Masukkan PIN atau Kata Sandi pribadi baru (minimal 6 karakter, tidak boleh sama dengan tanggal lahir):',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: pinCtrl,
                obscureText: obscure,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'PIN / Sandi Baru (min. 6 karakter)',
                  suffixIcon: IconButton(
                    onPressed: () => setModalState(() => obscure = !obscure),
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
            ],
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
                      final pin = pinCtrl.text.trim();
                      if (pin.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('PIN minimal 6 karakter.'),
                            backgroundColor: AppColors.amber,
                          ),
                        );
                        return;
                      }
                      setModalState(() => saving = true);
                      try {
                        final msg = await _api.setMemberPin(
                          newPin: pin,
                          token: widget.session.token,
                        );
                        if (!mounted) return;
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(msg),
                            backgroundColor: AppColors.emerald,
                          ),
                        );
                      } catch (e) {
                        setModalState(() => saving = false);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.toString()),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Simpan PIN',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = _member;
    final noreg = m?.noreg ?? SessionStore.formatNoreg8(widget.session.noreg);
    final nama = (m != null && m.nama.isNotEmpty && m.nama != '-')
        ? m.nama
        : widget.session.nama;
    final job = (m != null && m.job.isNotEmpty) ? m.job : widget.session.job;
    final avatarUrl = m?.avatarUrl ?? widget.session.avatarUrl;
    final ktaNum = (m != null && m.ktaNumber.isNotEmpty && m.ktaNumber != '-')
        ? m.ktaNumber
        : null;
    final qrData = (m != null &&
            m.qrProfil.isNotEmpty &&
            m.qrProfil != 'profil:$noreg')
        ? m.qrProfil
        : 'profil:${BungteminCrypto.encrypt(noreg)}';

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator(
        onRefresh: _loadCachedAndFreshKta,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _ProfilHeroHeader(
                    nama: nama,
                    noreg: noreg,
                    ktaNumber: ktaNum,
                    avatarUrl: avatarUrl,
                    onBack: () => Navigator.of(context).pop(),
                    onOpenKta: _openKtaScreen,
                  ),
                  Transform.translate(
                    offset: const Offset(0, -24),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Column(
                          children: [
                            _ProfilSegmentBar(
                              activeSegment: _activeSegment,
                              onSelectTab: _selectTab,
                              onOpenIdCard: _openKtaScreen,
                            ),
                            const SizedBox(height: 14),
                            if (_loading && m == null)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 48),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child: switch (_activeSegment) {
                                  1 => _UnitKerjaSlide(
                                      key: const ValueKey('unit_kerja'),
                                      lokasi: m?.lokasi ?? 'PT. TMMIN',
                                      plant: m?.plant ?? '-',
                                      dept: (m != null &&
                                              m.dept.isNotEmpty &&
                                              m.dept != '-')
                                          ? m.dept
                                          : job,
                                      divisi: (m != null &&
                                              m.divisi.isNotEmpty &&
                                              m.divisi != '-')
                                          ? m.divisi
                                          : 'PT. Toyota Motor Manufacturing Indonesia',
                                      aktif: m?.aktif ?? true,
                                      tanggalStart: m?.tanggalStart ?? '-',
                                      berlaku: m?.berlaku ?? '-',
                                    ),
                                  2 => _QrProfilSlide(
                                      key: const ValueKey('qr_profil'),
                                      nama: nama,
                                      noreg: noreg,
                                      qrData: qrData,
                                    ),
                                  3 => _KeamananSlide(
                                      key: const ValueKey('keamanan_pin'),
                                      hasPin: _hasPin,
                                      waNumber: _waNumber,
                                      alamat: m?.alamat ?? '',
                                      token: widget.session.token,
                                      api: _api,
                                      onPinSaved: () {
                                        if (mounted) {
                                          setState(() => _hasPin = true);
                                        }
                                      },
                                      onPhoneSaved: (newWa) {
                                        if (mounted) {
                                          setState(() => _waNumber = newWa);
                                        }
                                      },
                                      onAddressSaved: () {
                                        if (mounted) {
                                          _load();
                                        }
                                      },
                                    ),
                                  _ => _BiodataSlide(
                                      key: const ValueKey('biodata'),
                                      nama: nama,
                                      noreg: noreg,
                                      ktaNumber: ktaNum,
                                      job: job,
                                      tempatLahir: m?.tempatLahir ?? '-',
                                      tglLahir: m?.tglLahir ?? '-',
                                      agama: m?.agama ?? '-',
                                      onChangePin: _openChangePinDialog,
                                      onOpenKta: _openKtaScreen,
                                    ),
                                },
                              ),
                            SizedBox(
                              height: MediaQuery.of(context).padding.bottom + 24,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfilHeroHeader extends StatelessWidget {
  const _ProfilHeroHeader({
    required this.nama,
    required this.noreg,
    required this.ktaNumber,
    required this.avatarUrl,
    required this.onBack,
    required this.onOpenKta,
  });

  final String nama;
  final String noreg;
  final String? ktaNumber;
  final String avatarUrl;
  final VoidCallback onBack;
  final VoidCallback onOpenKta;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.52, 1.0],
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E1B4B),
            Color(0xFF1D4ED8),
          ],
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(36),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.35),
            blurRadius: 36,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -40,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.32),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFA855F7).withValues(alpha: 0.28),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(18, topPad + 16, 18, 46),
            child: Column(
              children: [
                // Top Navigation Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _HeroNavPill(
                      icon: Icons.arrow_back_rounded,
                      label: 'Beranda',
                      onTap: onBack,
                    ),
                    _HeroNavPill(
                      icon: Icons.badge_outlined,
                      label: 'KTA Digital',
                      isKtaStyle: true,
                      onTap: onOpenKta,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // Squircle Avatar with Verified Badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 112,
                      height: 112,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF38BDF8),
                            Color(0xFF818CF8),
                            Color(0xFFC084FC),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF020617).withValues(alpha: 0.45),
                            blurRadius: 32,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Container(
                          color: const Color(0xFF1E293B),
                          child: Image.network(
                            avatarUrl,
        headers: BtapiAuth.imageHeaders(avatarUrl),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Image.asset(
                              'assets/img/default-avatar.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                          ),
                          border: Border.all(
                            color: const Color(0xFF0F172A),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  const Color(0xFF10B981).withValues(alpha: 0.45),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  nama,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.fingerprint_rounded,
                            size: 15,
                            color: Color(0xFFE2E8F0),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'NOREG: $noreg',
                            style: const TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (ktaNumber != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color:
                                const Color(0xFF34D399).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_user_outlined,
                              size: 15,
                              color: Color(0xFFA7F3D0),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'KTA: $ktaNumber',
                              style: const TextStyle(
                                color: Color(0xFFA7F3D0),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
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
    );
  }
}

class _HeroNavPill extends StatelessWidget {
  const _HeroNavPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isKtaStyle = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isKtaStyle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: isKtaStyle
                ? LinearGradient(
                    colors: [
                      const Color(0xFF38BDF8).withValues(alpha: 0.28),
                      const Color(0xFF6366F1).withValues(alpha: 0.32),
                    ],
                  )
                : null,
            color: isKtaStyle ? null : Colors.white.withValues(alpha: 0.12),
            border: Border.all(
              color: isKtaStyle
                  ? const Color(0xFF7DD3FC).withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isKtaStyle ? const Color(0xFFE0F2FE) : Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isKtaStyle ? const Color(0xFFE0F2FE) : Colors.white,
                  fontSize: 12.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfilSegmentBar extends StatelessWidget {
  const _ProfilSegmentBar({
    required this.activeSegment,
    required this.onSelectTab,
    required this.onOpenIdCard,
  });

  final int activeSegment;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onOpenIdCard;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.10),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              icon: Icons.person_outline_rounded,
              label: 'Biodata',
              active: activeSegment == 0,
              onTap: () => onSelectTab(0),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _SegmentButton(
              icon: Icons.business_outlined,
              label: 'Unit Kerja',
              active: activeSegment == 1,
              onTap: () => onSelectTab(1),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _SegmentButton(
              icon: Icons.qr_code_rounded,
              label: 'QR Profil',
              active: activeSegment == 2,
              onTap: () => onSelectTab(2),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _SegmentButton(
              icon: Icons.credit_card_rounded,
              label: 'ID Card',
              active: false,
              onTap: onOpenIdCard,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _SegmentButton(
              icon: Icons.lock_outline_rounded,
              label: 'Keamanan',
              active: activeSegment == 3,
              onTap: () => onSelectTab(3),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: active
                ? const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                  )
                : null,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.32),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 19,
                color: active ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BiodataSlide extends StatelessWidget {
  const _BiodataSlide({
    super.key,
    required this.nama,
    required this.noreg,
    required this.ktaNumber,
    required this.job,
    required this.tempatLahir,
    required this.tglLahir,
    required this.agama,
    required this.onChangePin,
    required this.onOpenKta,
  });

  final String nama;
  final String noreg;
  final String? ktaNumber;
  final String job;
  final String tempatLahir;
  final String tglLahir;
  final String agama;
  final VoidCallback onChangePin;
  final VoidCallback onOpenKta;

  @override
  Widget build(BuildContext context) {
    final hasTtl = (tempatLahir.isNotEmpty && tempatLahir != '-') ||
        (tglLahir.isNotEmpty && tglLahir != '-');
    final ttlStr =
        '${tempatLahir.isNotEmpty ? tempatLahir : '-'}${tglLahir.isNotEmpty && tglLahir != '-' ? ', $tglLahir' : ''}';

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          _ProfilInfoCard(
            icon: Icons.account_circle_outlined,
            iconBg: const Color(0xFFEFF6FF),
            iconColor: const Color(0xFF2563EB),
            title: 'Informasi Pribadi',
            subtitle: 'Data identitas anggota terdaftar',
            items: [
              _InfoItemData(label: 'Nama Lengkap', value: nama),
              _InfoItemData(
                label: 'Nomor Registrasi (Noreg)',
                value: noreg,
                isMono: true,
              ),
              if (ktaNumber != null)
                _InfoItemData(
                  label: 'Nomor KTA SPSI',
                  value: ktaNumber!,
                  isMono: true,
                  isHighlight: true,
                ),
              _InfoItemData(label: 'Jabatan / Job', value: job),
              if (hasTtl)
                _InfoItemData(label: 'Tempat, Tanggal Lahir', value: ttlStr),
              if (agama.isNotEmpty && agama != '-')
                _InfoItemData(label: 'Agama', value: agama),
            ],
          ),
          const SizedBox(height: 12),
          // Atur / Ganti PIN Login Pribadi Banner
          _ActionPromoBanner(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.key_rounded,
                color: Color(0xFF60A5FA),
                size: 22,
              ),
            ),
            title: 'Atur / Ganti PIN Login Pribadi',
            subtitle:
                'Kunci akun Anda dengan PIN pribadi (nonaktifkan login tanggal lahir)',
            onTap: onChangePin,
          ),
          const SizedBox(height: 12),
          // Lihat KTA Banner
          _ActionPromoBanner(
            leading: Image.asset(
              'assets/icon/19.png',
              width: 46,
              height: 46,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.badge_rounded,
                color: AppColors.auroraCyan,
                size: 36,
              ),
            ),
            title: 'Lihat Kartu Tanda Anggota (KTA)',
            subtitle: 'Tampilkan desain KTA Digital resmi SP LEM SPSI',
            onTap: onOpenKta,
          ),
        ],
      ),
    );
  }
}

class _UnitKerjaSlide extends StatelessWidget {
  const _UnitKerjaSlide({
    super.key,
    required this.lokasi,
    required this.plant,
    required this.dept,
    required this.divisi,
    required this.aktif,
    required this.tanggalStart,
    required this.berlaku,
  });

  final String lokasi;
  final String plant;
  final String dept;
  final String divisi;
  final bool aktif;
  final String tanggalStart;
  final String berlaku;

  @override
  Widget build(BuildContext context) {
    final lokasiLabel =
        (plant.isNotEmpty && plant != '-' && plant != lokasi)
            ? '$lokasi • $plant'
            : lokasi;
    final hasMasaBerlaku =
        (tanggalStart != '-' && tanggalStart.isNotEmpty) ||
        (berlaku != '-' && berlaku.isNotEmpty);

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: _ProfilInfoCard(
        icon: Icons.location_on_outlined,
        iconBg: const Color(0xFFF5F3FF),
        iconColor: const Color(0xFF7C3AED),
        title: 'Penempatan & Unit Kerja',
        subtitle: 'Data plant, divisi, dan masa berlaku KTA',
        items: [
          _InfoItemData(label: 'Lokasi / Plant', value: lokasiLabel),
          _InfoItemData(label: 'Departemen', value: dept),
          _InfoItemData(label: 'Divisi', value: divisi),
          _InfoItemData(
            label: 'Status Keanggotaan',
            value: aktif ? 'Aktif Terdaftar' : 'Nonaktif',
            isStatusOk: aktif,
          ),
          if (hasMasaBerlaku)
            _InfoItemData(
              label: 'Masa Berlaku KTA',
              value: '$tanggalStart s/d $berlaku',
            ),
        ],
      ),
    );
  }
}

class _QrProfilSlide extends StatelessWidget {
  const _QrProfilSlide({
    super.key,
    required this.nama,
    required this.noreg,
    required this.qrData,
  });

  final String nama;
  final String noreg;
  final String qrData;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.07),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 15,
                    color: Color(0xFF2563EB),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'QR Identitas Terenkripsi (AES-256)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFCBD5E1),
                  width: 1.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.navy.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: QrImageView(
                data: qrData,
                size: 210,
                backgroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoItemData {
  const _InfoItemData({
    required this.label,
    required this.value,
    this.isMono = false,
    this.isHighlight = false,
    this.isStatusOk = false,
  });

  final String label;
  final String value;
  final bool isMono;
  final bool isHighlight;
  final bool isStatusOk;
}

class _ProfilInfoCard extends StatelessWidget {
  const _ProfilInfoCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final List<_InfoItemData> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.07),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    items[i].label.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (items[i].isStatusOk)
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          items[i].value,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      items[i].value,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        fontFamily: items[i].isMono ? 'monospace' : null,
                        color: items[i].isHighlight
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF1E293B),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionPromoBanner extends StatelessWidget {
  const _ActionPromoBanner({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF38BDF8),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeamananSlide extends StatefulWidget {
  const _KeamananSlide({
    super.key,
    required this.hasPin,
    required this.waNumber,
    required this.alamat,
    required this.token,
    required this.api,
    required this.onPinSaved,
    required this.onPhoneSaved,
    required this.onAddressSaved,
  });

  final bool? hasPin;
  final String waNumber;
  final String alamat;
  final String token;
  final BungteminApi api;
  final VoidCallback onPinSaved;
  final ValueChanged<String> onPhoneSaved;
  final VoidCallback onAddressSaved;

  @override
  State<_KeamananSlide> createState() => _KeamananSlideState();
}

class _KeamananSlideState extends State<_KeamananSlide> {
  final _pinCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  bool _savingPhone = false;
  bool _savingAddress = false;

  @override
  void initState() {
    super.initState();
    _phoneCtrl.text = widget.waNumber;
    _addressCtrl.text = widget.alamat;
  }

  @override
  void didUpdateWidget(covariant _KeamananSlide oldWidget) {
    super.didUpdateWidget(covariant _KeamananSlide oldWidget);
    if (widget.waNumber != oldWidget.waNumber && _phoneCtrl.text.trim().isEmpty) {
      _phoneCtrl.text = widget.waNumber;
    }
    if (widget.alamat != oldWidget.alamat && _addressCtrl.text.trim().isEmpty) {
      _addressCtrl.text = widget.alamat;
    }
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    _confirmCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitAddress() async {
    final alamat = _addressCtrl.text.trim();
    if (alamat.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alamat domisili minimal 5 karakter.'),
          backgroundColor: AppColors.amber,
        ),
      );
      return;
    }
    setState(() => _savingAddress = true);
    try {
      final msg = await widget.api.updateAddress(
        alamat: alamat,
        token: widget.token,
      );
      if (!mounted) return;
      widget.onAddressSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.emerald,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _savingAddress = false);
      }
    }
  }

  Future<void> _submitPhone() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nomor telepon / WhatsApp minimal 9 digit.'),
          backgroundColor: AppColors.amber,
        ),
      );
      return;
    }
    setState(() => _savingPhone = true);
    try {
      final msg = await widget.api.updatePhoneNumber(
        phone: phone,
        token: widget.token,
      );
      if (!mounted) return;
      widget.onPhoneSaved(phone);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.emerald,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _savingPhone = false);
      }
    }
  }

  Future<void> _submit() async {
    final pin = _pinCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    if (pin.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN / Kata Sandi minimal 6 karakter.'),
          backgroundColor: AppColors.amber,
        ),
      );
      return;
    }
    if (pin != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konfirmasi PIN / Kata Sandi tidak cocok.'),
          backgroundColor: AppColors.amber,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final msg = await widget.api.setMemberPin(
        newPin: pin,
        token: widget.token,
      );
      if (!mounted) return;
      _pinCtrl.clear();
      _confirmCtrl.clear();
      widget.onPinSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.emerald,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = widget.hasPin == true;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (isLocked ? AppColors.emerald : AppColors.amber)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isLocked ? Icons.verified_user_rounded : Icons.warning_amber_rounded,
                  color: isLocked ? AppColors.emerald : const Color(0xFFD97706),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLocked
                          ? 'PIN Pribadi Aktif'
                          : 'Masih Pakai Password TTL',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isLocked
                          ? 'Login tanggal lahir sudah dinonaktifkan.'
                          : 'Segera ganti tanggal lahir dengan PIN/Kata Sandi pribadi.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _pinCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'PIN / Kata Sandi Baru',
              hintText: 'Minimal 6 karakter (jangan tanggal lahir)',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmCtrl,
            obscureText: _obscure,
            decoration: const InputDecoration(
              labelText: 'Konfirmasi PIN / Kata Sandi',
              prefixIcon: Icon(Icons.lock_reset_rounded),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_rounded, size: 18),
            label: Text(
              isLocked ? 'Perbarui PIN / Kata Sandi' : 'Aktifkan PIN Pribadi',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const Divider(height: 30, color: Color(0xFFE2E8F0)),
          const Text(
            'Nomor Telepon / WhatsApp',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Dipakai untuk menerima OTP login, tiket acara, dan notifikasi WA.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'No. WhatsApp / Telepon',
              hintText: 'Contoh: 081234567890',
              prefixIcon: Icon(Icons.phone_android_rounded),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _savingPhone ? null : _submitPhone,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.emerald,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: _savingPhone
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: const Text(
              'Simpan No. Telepon / WA',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 22),
          const Divider(height: 1),
          const SizedBox(height: 18),
          const Text(
            'Alamat Domisili',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Alamat yang tersimpan akan tampil pada Kartu Tanda Anggota (KTA) Anda.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressCtrl,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Alamat Domisili',
              hintText: 'Masukkan alamat lengkap tempat tinggal',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _savingAddress ? null : _submitAddress,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: _savingAddress
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_rounded, size: 18),
            label: const Text(
              'Simpan Alamat Domisili',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
