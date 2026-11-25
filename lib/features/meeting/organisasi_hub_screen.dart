import 'package:flutter/material.dart';

import '../../core/screen_security.dart';
import '../../core/session_store.dart';
import '../../core/theme.dart';
import '../../models/meeting_meta.dart';
import '../../services/bungtemin_api.dart';
import 'organisasi_manage_screen.dart';

/// Halaman Pengaturan Organisasi (PUK, KP, Pleno, Anggota) mengikuti role web organisasi.
class OrganisasiHubScreen extends StatefulWidget {
  const OrganisasiHubScreen({
    super.key,
    required this.session,
    this.api,
  });

  final UserSession session;
  final BungteminApi? api;

  @override
  State<OrganisasiHubScreen> createState() => _OrganisasiHubScreenState();
}

class _OrganisasiHubScreenState extends State<OrganisasiHubScreen> {
  late final BungteminApi _api = widget.api ?? BungteminApi();
  bool _loading = true;
  String? _error;
  MeetingMeta? _meta;

  @override
  void initState() {
    super.initState();
    ScreenSecurity.enable();
    _load();
  }

  @override
  void dispose() {
    ScreenSecurity.disable();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final meta = await _api.fetchMeetingMeta(
        noreg: widget.session.noreg,
        token: widget.session.token,
      );
      if (!mounted) return;
      setState(() => _meta = meta);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openSection(String label, OrgSectionMode mode) async {
    final meta = _meta;
    if (meta == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => OrganisasiManageScreen(
          session: widget.session,
          meta: meta,
          mode: mode,
          titleOverride: label,
        ),
      ),
    );
    if (mounted) {
      ScreenSecurity.enable();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = _meta;
    final admin = meta?.canManageAll ?? false;

    final struktur = <(String, String, IconData, OrgSectionMode)>[
      if (admin) ...[
        (
          'PUK',
          'Kelola pengurus inti & bidang PUK',
          Icons.business_center_outlined,
          OrgSectionMode.puk,
        ),
        (
          'KP (Koordinator Pleno)',
          'Atur Koordinator Pleno & wilayah kerja',
          Icons.apartment_rounded,
          OrgSectionMode.kp,
        ),
        (
          'PLENO',
          'Kelola anggota Pleno per KP',
          Icons.groups_rounded,
          OrgSectionMode.pleno,
        ),
        (
          'Anggota (Member Basis)',
          'Kelola data anggota, Pleno pembina & No. WA',
          Icons.people_alt_rounded,
          OrgSectionMode.member,
        ),
      ] else if (meta?.isKp ?? false) ...[
        (
          'Pleno KP Saya',
          'Kelola Pleno di bawah KP Anda',
          Icons.groups_rounded,
          OrgSectionMode.pleno,
        ),
        (
          'Anggota KP Saya',
          'Kelola anggota & No. WA di KP Anda',
          Icons.people_alt_rounded,
          OrgSectionMode.member,
        ),
      ] else if (meta?.isPleno ?? false)
        (
          'Member Binaan Saya',
          'Kelola data anggota binaan & No. WA',
          Icons.people_alt_rounded,
          OrgSectionMode.member,
        ),
    ];

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: const Text(
          'Pengaturan Organisasi',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (meta != null && meta.roleLabel.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_rounded, color: AppColors.primaryBlue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hak Akses Organisasi Anda',
                            style: TextStyle(fontSize: 11, color: AppColors.muted),
                          ),
                          Text(
                            meta.roleLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppColors.navy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (_loading && meta == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Text(_error!, style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 10),
                    FilledButton(onPressed: _load, child: const Text('Coba Lagi')),
                  ],
                ),
              )
            else if (struktur.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 36, color: AppColors.muted),
                    SizedBox(height: 10),
                    Text(
                      'Khusus Pengurus Organisasi',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.navy,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Menu pengaturan PUK, KP, Pleno, dan Anggota hanya tersedia untuk akun dengan role PUK, KP, atau Pleno sesuai hak akses web organisasi.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                    ),
                  ],
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < struktur.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(struktur[i].$3, color: AppColors.primaryBlue),
                        ),
                        title: Text(
                          struktur[i].$1,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                            fontSize: 14.5,
                          ),
                        ),
                        subtitle: Text(
                          struktur[i].$2,
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                        onTap: () => _openSection(struktur[i].$1, struktur[i].$4),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
