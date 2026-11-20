import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/cached_image.dart';
import '../../core/session_store.dart';
import '../../core/theme.dart';
import '../../models/meeting_item.dart';
import '../../models/meeting_room.dart';
import '../../services/bungtemin_api.dart';

/// Room meeting — disamakan dengan room di web/Ionic.
///
/// 4 tab: Kehadiran, Foto, Resume, Voice Member.
/// Kamera (scan kehadiran & ambil foto) hanya tampil untuk **owner**
/// (`can_manage`): Meeting Anggota → Pleno, Meeting Pleno → KP, dst.
class MeetingRoomScreen extends StatefulWidget {
  const MeetingRoomScreen({
    super.key,
    required this.session,
    required this.meeting,
  });

  final UserSession session;
  final MeetingItem meeting;

  @override
  State<MeetingRoomScreen> createState() => _MeetingRoomScreenState();
}

class _MeetingRoomScreenState extends State<MeetingRoomScreen> {
  final _api = BungteminApi();
  final _picker = ImagePicker();

  final _searchCtrl = TextEditingController();
  final _topikCtrl = TextEditingController();
  final _pembicaraCtrl = TextEditingController();
  final _isiCtrl = TextEditingController();
  final _keputusanCtrl = TextEditingController();
  final _kesimpulanCtrl = TextEditingController();
  final _tindakCtrl = TextEditingController();

  MeetingRoomData? _room;
  bool _loading = true;
  bool _busy = false;
  bool _showQr = false;
  bool _resumeLoaded = false;
  String? _error;
  String _search = '';
  int _tab = 0; // 0 Kehadiran, 1 Foto, 2 Resume, 3 Voice Member

  static const _statusOptions = [
    ('planning', 'Planning'),
    ('ongoing', 'Berlangsung'),
    ('review_kp', 'Review KP'),
    ('review_puk', 'Review PUK'),
    ('completed', 'Selesai'),
    ('cancelled', 'Dibatalkan'),
  ];

  String get _mid => widget.meeting.id.toString();
  String get _noreg => widget.session.noreg;
  String get _token => widget.session.token;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _topikCtrl.dispose();
    _pembicaraCtrl.dispose();
    _isiCtrl.dispose();
    _keputusanCtrl.dispose();
    _kesimpulanCtrl.dispose();
    _tindakCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool spinner = true}) async {
    if (spinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final r = await _api.fetchMeetingRoom(
        meetingId: _mid,
        noreg: _noreg,
        token: _token,
      );
      if (!mounted) return;
      setState(() {
        _room = r;
        _loading = false;
        _error = null;
        if (!_resumeLoaded) {
          _kesimpulanCtrl.text = r.kesimpulan;
          _tindakCtrl.text = r.tindakLanjut;
          _resumeLoaded = true;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: error ? AppColors.rose : null,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<bool> _run(Future<void> Function() action, {String? ok}) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      await action();
      if (ok != null) _toast(ok);
      return true;
    } catch (e) {
      _toast(e.toString(), error: true);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _toast('Tidak bisa membuka tautan.', error: true);
  }

  // ---------------------------------------------------------------- Kehadiran

  Future<void> _scanCamera() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _MeetingScanPage()),
    );
    if (code == null || code.trim().isEmpty) return;
    await _checkin(code.trim(), fromCamera: true);
  }

  Future<void> _manualCheckin() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Check-In Manual / Token'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Noreg atau Kode Tiket (MTG-...)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Check-In'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (code == null || code.isEmpty) return;
    await _checkin(code);
  }

  Future<void> _checkin(String code, {bool fromCamera = false}) async {
    String? result;
    final ok = await _run(() async {
      result = await _api.scanMeetingTicket(
        meetingId: _mid,
        code: code,
        noreg: _noreg,
        token: _token,
      );
      await _load(spinner: false);
    });
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ok ? 'Check-In Berhasil' : 'Gagal Check-In'),
        content: Text(
          ok
              ? (result ?? 'Kehadiran tercatat.')
              : 'Kode QR / Tiket / Noreg tidak valid atau Anda bukan pengelola meeting ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(fromCamera ? 'Selesai' : 'OK'),
          ),
          if (fromCamera)
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _scanCamera();
              },
              child: const Text('Scan Lagi'),
            ),
        ],
      ),
    );
  }

  Future<void> _setStatus(MeetingPeserta p, String status) async {
    await _run(() async {
      await _api.updateMeetingPeserta(
        meetingId: _mid,
        pesertaId: p.id,
        status: status,
        noreg: _noreg,
        token: _token,
      );
      await _load(spinner: false);
    });
  }

  Future<void> _sendWa() async {
    final yes = await _confirm(
      'Kirim Tiket via WA',
      'Antrekan undangan & link QR Tiket via WhatsApp untuk seluruh peserta meeting ini?',
      'Kirim WA',
    );
    if (yes != true) return;
    String? msg;
    await _run(() async {
      msg = await _api.sendMeetingWaTickets(
        meetingId: _mid,
        noreg: _noreg,
        token: _token,
      );
    }, ok: 'Tiket WA diantrekan.');
    if (msg != null) _toast(msg!);
  }

  Future<bool?> _confirm(String title, String message, String okLabel) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(okLabel),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ Foto / Resume

  Future<void> _pickAndUpload(String field, ImageSource source) async {
    XFile? file;
    try {
      file = await _picker.pickImage(
        source: source,
        maxWidth: 2200,
        imageQuality: 85,
      );
    } catch (_) {
      _toast('Tidak bisa membuka kamera/galeri. Periksa izin aplikasi.',
          error: true);
      return;
    }
    if (file == null) return;
    final path = file.path;
    await _run(() async {
      await _api.uploadMeetingDokumen(
        meetingId: _mid,
        field: field,
        filePath: path,
        noreg: _noreg,
        token: _token,
      );
      await _load(spinner: false);
    }, ok: field == 'foto_dokumentasi'
        ? 'Foto dokumentasi diunggah.'
        : 'File resume diunggah.');
  }

  int get _liveResumeWords {
    final text = '${_kesimpulanCtrl.text} ${_tindakCtrl.text}'.trim();
    final local =
        text.isEmpty ? 0 : text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return math.max(local, _room?.progress.resumeWordCount ?? 0);
  }

  Future<void> _saveKesimpulan() async {
    await _run(() async {
      await _api.updateMeetingKesimpulan(
        meetingId: _mid,
        kesimpulan: _kesimpulanCtrl.text.trim(),
        tindakLanjut: _tindakCtrl.text.trim(),
        noreg: _noreg,
        token: _token,
      );
      await _load(spinner: false);
    }, ok: 'Kesimpulan rapat disimpan.');
  }

  // -------------------------------------------------------------- Voice Member

  Future<void> _addVoice() async {
    if (_topikCtrl.text.trim().isEmpty) {
      _toast('Topik / aspirasi wajib diisi.', error: true);
      return;
    }
    final ok = await _run(() async {
      await _api.saveMeetingNotulen(
        meetingId: _mid,
        topik: _topikCtrl.text.trim(),
        pembicara: _pembicaraCtrl.text.trim(),
        isiDiskusi: _isiCtrl.text.trim(),
        keputusan: _keputusanCtrl.text.trim(),
        noreg: _noreg,
        token: _token,
      );
      await _load(spinner: false);
    }, ok: 'Voice member ditambahkan.');
    if (ok) {
      _topikCtrl.clear();
      _pembicaraCtrl.clear();
      _isiCtrl.clear();
      _keputusanCtrl.clear();
    }
  }

  Future<void> _removeVoice(MeetingNotulen n) async {
    final yes = await _confirm('Hapus Poin', 'Hapus "${n.topik}"?', 'Hapus');
    if (yes != true) return;
    await _run(() async {
      await _api.deleteMeetingNotulen(
        meetingId: _mid,
        notulenId: n.id,
        noreg: _noreg,
        token: _token,
      );
      await _load(spinner: false);
    }, ok: 'Poin dihapus.');
  }

  // -------------------------------------------------------------------- Status

  Future<void> _changeStatus(String status) async {
    await _run(() async {
      await _api.changeMeetingStatus(
        meetingId: _mid,
        status: status,
        noreg: _noreg,
        token: _token,
      );
      await _load(spinner: false);
    }, ok: 'Status meeting diperbarui.');
  }

  Future<void> _submitReview() async {
    final r = _room;
    if (r == null) return;
    if (!r.progress.isReadyForReview) {
      final miss = r.progress.missing.isEmpty
          ? 'Semua 4 tab wajib terisi terlebih dahulu.'
          : r.progress.missing.map((e) => '• $e').join('\n');
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Checklist Belum Lengkap'),
          content: Text('Lengkapi terlebih dahulu:\n$miss'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    final isMember = r.kategori.toLowerCase().contains('member');
    final yes = await _confirm(
      isMember ? 'Kirim Laporan untuk Review?' : 'Kirim ke PUK untuk Review?',
      isMember
          ? 'Seluruh 4 tab sudah lengkap. Kirim laporan Meeting Anggota ini ke KP / PUK untuk direview?'
          : 'Seluruh 4 tab sudah lengkap. Kirim laporan meeting ini ke PUK untuk review & proses insentif?',
      'Kirim Review',
    );
    if (yes != true) return;
    await _run(() async {
      await _api.submitMeetingReview(
        meetingId: _mid,
        noreg: _noreg,
        token: _token,
      );
      await _load(spinner: false);
    }, ok: 'Laporan dikirim untuk review.');
  }

  // --------------------------------------------------------------------- Build

  static String _statusLabel(String raw) {
    for (final o in _statusOptions) {
      if (o.$1 == raw) return o.$2;
    }
    return raw.isEmpty ? 'Planning' : raw.toUpperCase();
  }

  static Color _pesertaColor(String st) => switch (st) {
        'hadir' => AppColors.emerald,
        'izin' || 'sakit' => AppColors.amber,
        'alfa' => AppColors.rose,
        _ => AppColors.muted,
      };

  String get _ownerLabel => switch (widget.meeting.segment) {
        3 => 'Pleno',
        2 => 'KP',
        _ => 'PUK',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => _load(spinner: false),
            child: _buildBody(),
          ),
          if (_busy)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(minHeight: 3),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final r = _room;
    if (_loading && r == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _hero(null),
          const SizedBox(height: 80),
          const Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (r == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _hero(null),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 44, color: AppColors.rose),
                const SizedBox(height: 10),
                Text(
                  _error ?? 'Gagal memuat ruang meeting.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 14),
                FilledButton(onPressed: _load, child: const Text('Coba Lagi')),
              ],
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _hero(r)),
        SliverToBoxAdapter(child: _progressCard(r)),
        SliverToBoxAdapter(child: _tabBar(r)),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            16,
            4,
            16,
            MediaQuery.of(context).padding.bottom + 32,
          ),
          sliver: SliverToBoxAdapter(
            child: switch (_tab) {
              1 => _fotoTab(r),
              2 => _resumeTab(r),
              3 => _voiceTab(r),
              _ => _kehadiranTab(r),
            },
          ),
        ),
      ],
    );
  }

  Widget _hero(MeetingRoomData? r) {
    final m = widget.meeting;
    final judul = r?.judul ?? m.judul;
    final kategori = r?.kategori ?? m.kategori;
    final tanggal = r?.tanggal ?? m.tanggal;
    final jam = r?.jamMulai ?? m.jamMulai;
    final tempat = r?.tempat ?? m.tempat;
    final pimpinan = r?.pimpinanRapat ?? m.pimpinanRapat;
    final status = r?.status ?? m.status;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 8,
        16,
        20,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, Color(0xFF1E3A8A), Color(0xFF0369A1)],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              const Expanded(
                child: Text(
                  'ROOM MEETING',
                  style: TextStyle(
                    color: Color(0xFF93C5FD),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _load(spinner: false),
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip(kategori, Colors.white),
              if (r != null && r.canManage)
                _chip('Anda owner (${_ownerLabel})', const Color(0xFF86EFAC)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            judul,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          _heroLine(Icons.calendar_today_rounded, '$tanggal • $jam WIB'),
          _heroLine(Icons.location_on_outlined, tempat),
          if (pimpinan.isNotEmpty)
            _heroLine(Icons.record_voice_over_outlined, 'Pimpinan: $pimpinan'),
          if (r != null && r.notulis.isNotEmpty)
            _heroLine(Icons.edit_note_rounded, 'Notulis: ${r.notulis}'),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Status:',
                style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5),
              ),
              const SizedBox(width: 8),
              if (r != null && r.canChangeStatus)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _statusOptions.any((o) => o.$1 == status)
                          ? status
                          : null,
                      isDense: true,
                      hint: Text(_statusLabel(status)),
                      items: [
                        for (final o in _statusOptions)
                          DropdownMenuItem(
                            value: o.$1,
                            child: Text(
                              o.$2,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null && v != status) _changeStatus(v);
                      },
                    ),
                  ),
                )
              else
                _chip(_statusLabel(status), Colors.white),
            ],
          ),
          if (r != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (r.resumeUrl.isNotEmpty)
                  _heroButton(Icons.newspaper_outlined, 'Resume',
                      () => _openUrl(r.resumeUrl)),
                if (r.dokumenUrl.isNotEmpty)
                  _heroButton(Icons.print_outlined, 'Blangko PDF',
                      () => _openUrl(r.dokumenUrl)),
                if (r.undanganUrl.isNotEmpty)
                  _heroButton(Icons.mail_outline_rounded, 'Undangan',
                      () => _openUrl(r.undanganUrl)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _heroLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: const Color(0xFFBFDBFE)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _progressCard(MeetingRoomData r) {
    final p = r.progress;
    final st = r.status;
    final reviewOrDone =
        const ['review_puk', 'review_kp', 'finish', 'completed', 'approved']
            .contains(st);
    Widget pill(String label, bool ok) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: (ok ? AppColors.emerald : AppColors.muted)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${ok ? '✓' : '○'} $label',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: ok ? AppColors.emerald : AppColors.muted,
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Checklist Kelengkapan Meeting',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                Text(
                  '${p.completedTabs}/4 Tab (${p.percent}%)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (p.percent.clamp(0, 100)) / 100,
                minHeight: 7,
                backgroundColor: const Color(0xFFE2E8F0),
                color: p.isReadyForReview
                    ? AppColors.emerald
                    : AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                pill('Kehadiran', p.absensiOk),
                pill('Foto', p.galeriOk),
                pill('Resume', p.resumeOk),
                pill('Voice Member', p.voiceOk),
              ],
            ),
            if (p.missing.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Belum lengkap: ${p.missing.join(' • ')}',
                style: const TextStyle(fontSize: 12, color: AppColors.rose),
              ),
            ],
            if (r.canChangeStatus) ...[
              const SizedBox(height: 10),
              if (!reviewOrDone)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: p.isReadyForReview && !_busy ? _submitReview : null,
                    icon: Icon(
                      p.isReadyForReview
                          ? Icons.send_rounded
                          : Icons.lock_outline_rounded,
                      size: 18,
                    ),
                    label: const Text('Kirim ke KP / PUK untuk Review'),
                  ),
                )
              else
                _chip(
                  '${_statusLabel(st)} ${p.incentiveUnlocked ? '(Selesai)' : '(Dalam Review)'}',
                  AppColors.emerald,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tabBar(MeetingRoomData r) {
    final p = r.progress;
    final items = [
      ('Kehadiran', '${r.totalHadir}/${r.totalPeserta}', p.absensiOk),
      ('Foto', r.fotoUrl.isNotEmpty ? '1 foto' : 'belum', p.galeriOk),
      (
        'Resume',
        r.resumeFileUrl.isNotEmpty ? 'file ada' : '$_liveResumeWords kata',
        p.resumeOk
      ),
      ('Voice Member', '${r.notulens.length} poin', p.voiceOk),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _tab = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                    decoration: BoxDecoration(
                      color:
                          _tab == i ? AppColors.primaryBlue : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${items[i].$3 ? '✓ ' : ''}${items[i].$1}',
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _tab == i
                                  ? Colors.white
                                  : AppColors.navySoft,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            items[i].$2,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: _tab == i
                                  ? Colors.white70
                                  : AppColors.muted,
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
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String hint, {
    int lines = 1,
    bool readOnly = false,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        readOnly: readOnly,
        minLines: lines,
        maxLines: lines == 1 ? 1 : lines + 3,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ Tab: 0

  Widget _kehadiranTab(MeetingRoomData r) {
    final q = _search.trim().toLowerCase();
    final list = r.pesertas.where((p) {
      if (q.isEmpty) return true;
      return p.nama.toLowerCase().contains(q) ||
          p.noreg.toLowerCase().contains(q) ||
          p.jabatan.toLowerCase().contains(q);
    }).toList();

    Widget box(String n, String label, Color c) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  n,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: c,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            box('${r.totalHadir}', 'Hadir', AppColors.emerald),
            box('${r.totalPending}', 'Pending', AppColors.muted),
            box('${r.totalIzinSakit}', 'Izin/Sakit', AppColors.amber),
            box('${r.totalPeserta}', 'Terundang', AppColors.primaryBlue),
          ],
        ),
        const SizedBox(height: 12),
        // Kamera & kontrol kehadiran HANYA untuk owner (can_manage).
        if (r.canManage)
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _scanCamera,
                    icon: const Icon(Icons.photo_camera_outlined, size: 20),
                    label: const Text('Scan Kehadiran (Kamera)'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.emerald,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _manualCheckin,
                      icon: const Icon(Icons.keyboard_alt_outlined, size: 18),
                      label: const Text('Input Noreg/Token'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _showQr = !_showQr),
                      icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                      label: const Text('QR Self Check-in'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _sendWa,
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Kirim Tiket WA'),
                    ),
                  ],
                ),
                if (_showQr) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      color: Colors.white,
                      child: QrImageView(data: r.qrData, size: 190),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Center(
                    child: Text(
                      'Anggota yang memakai aplikasi dapat scan QR ini dari menu Scanner untuk self check-in.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                    ),
                  ),
                ],
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Scan kamera & ubah kehadiran hanya tersedia untuk owner meeting ($_ownerLabel).',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
        _field(
          _searchCtrl,
          'Cari nama / noreg / jabatan...',
          onChanged: (v) => setState(() => _search = v),
        ),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Belum ada peserta.',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          ),
        for (final p in list)
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.nama,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${p.noreg} • ${p.jabatan.isEmpty ? 'Peserta' : p.jabatan}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                          if (p.waktuAbsen.isNotEmpty)
                            Text(
                              'Absen: ${p.waktuAbsen}${p.metodeAbsen.isEmpty ? '' : ' (${p.metodeAbsen})'}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _chip(p.statusKehadiran.toUpperCase(),
                        _pesertaColor(p.statusKehadiran)),
                  ],
                ),
                if (r.canManage) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final s in const ['hadir', 'izin', 'alfa'])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              s[0].toUpperCase() + s.substring(1),
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: p.statusKehadiran == s,
                            onSelected: _busy ? null : (_) => _setStatus(p, s),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  // ------------------------------------------------------------------ Tab: 1

  Widget _fotoTab(MeetingRoomData r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Galeri Foto Dokumentasi',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  _chip(
                    r.fotoUrl.isNotEmpty ? 'Foto Tersedia' : 'Belum Ada Foto',
                    r.fotoUrl.isNotEmpty ? AppColors.emerald : AppColors.muted,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Foto dokumentasi rapat (JPG/PNG/WEBP, maks. 15 MB).',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              if (r.canChangeStatus) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Kamera hanya untuk owner.
                    if (r.canManage)
                      FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _pickAndUpload(
                                  'foto_dokumentasi',
                                  ImageSource.camera,
                                ),
                        icon: const Icon(Icons.photo_camera_outlined, size: 18),
                        label: const Text('Ambil Foto (Kamera)'),
                      ),
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _pickAndUpload(
                                'foto_dokumentasi',
                                ImageSource.gallery,
                              ),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Pilih dari Galeri'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        _card(
          child: r.fotoUrl.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.image_outlined,
                            size: 44, color: AppColors.muted),
                        SizedBox(height: 8),
                        Text(
                          'Belum ada foto dokumentasi untuk meeting ini.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    GestureDetector(
                      onTap: () => _openUrl(r.fotoUrl),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: BungteminCachedImage(
                          imageUrl: r.fotoUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: 1080,
                          errorWidget: const SizedBox(
                            height: 160,
                            child: Center(
                              child: Icon(Icons.broken_image_outlined,
                                  color: AppColors.muted, size: 40),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => _openUrl(r.fotoUrl),
                      icon: const Icon(Icons.open_in_full_rounded, size: 16),
                      label: const Text('Buka Ukuran Penuh'),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ Tab: 2

  Widget _resumeTab(MeetingRoomData r) {
    final minWords = r.progress.minResumeWords;
    final words = _liveResumeWords;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Resume / Kesimpulan Digital',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  _chip(
                    '$words / $minWords kata',
                    words >= minWords ? AppColors.emerald : AppColors.amber,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Jika tidak mengunggah file scan, ketik kesimpulan minimal $minWords kata.',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 10),
              _field(
                _kesimpulanCtrl,
                'Kesimpulan rapat...',
                lines: 3,
                readOnly: !r.canChangeStatus,
                onChanged: (_) => setState(() {}),
              ),
              _field(
                _tindakCtrl,
                'Usulan / catatan penutup ke KP-PUK...',
                lines: 2,
                readOnly: !r.canChangeStatus,
                onChanged: (_) => setState(() {}),
              ),
              if (r.canChangeStatus)
                FilledButton(
                  onPressed: _busy ? null : _saveKesimpulan,
                  child: const Text('Simpan Kesimpulan'),
                ),
            ],
          ),
        ),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'File Resume Meeting',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  _chip(
                    r.resumeFileUrl.isNotEmpty ? 'Sudah Ada' : 'Belum Diunggah',
                    r.resumeFileUrl.isNotEmpty
                        ? AppColors.emerald
                        : AppColors.muted,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Unggah foto/scan resume rapat (JPG/PNG/WEBP, maks. 15 MB).',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (r.canChangeStatus && r.canManage)
                    FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () =>
                              _pickAndUpload('resume_file', ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('Foto Resume (Kamera)'),
                    ),
                  if (r.canChangeStatus)
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () =>
                              _pickAndUpload('resume_file', ImageSource.gallery),
                      icon: const Icon(Icons.upload_file_rounded, size: 18),
                      label: const Text('Pilih dari Galeri'),
                    ),
                  if (r.resumeFileUrl.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => _openUrl(r.resumeFileUrl),
                      icon: const Icon(Icons.description_outlined, size: 18),
                      label: const Text('Lihat Resume Terunggah'),
                    ),
                  if (r.resumeUrl.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => _openUrl(r.resumeUrl),
                      icon: const Icon(Icons.newspaper_outlined, size: 18),
                      label: const Text('Buka Resume Fisik'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ Tab: 3

  Widget _voiceTab(MeetingRoomData r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (r.canChangeStatus)
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tambah Voice Member & Rekomendasi',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 10),
                _field(_topikCtrl, 'Topik / aspirasi anggota *'),
                _field(_pembicaraCtrl, 'Nama pemberi masukan / member'),
                _field(_isiCtrl, 'Isi voice member / aspirasi', lines: 2),
                _field(
                  _keputusanCtrl,
                  'Rekomendasi / tindak lanjut ke KP-PUK (opsional)',
                  lines: 2,
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _addVoice,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.emerald,
                    ),
                    child: const Text('Simpan Voice & Rekomendasi'),
                  ),
                ),
              ],
            ),
          ),
        if (r.notulens.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Belum ada voice member / rekomendasi.',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          ),
        for (var i = 0; i < r.notulens.length; i++)
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _chip(
                      r.notulens[i].keputusan.isNotEmpty
                          ? 'Rekomendasi'
                          : 'Voice Member',
                      r.notulens[i].keputusan.isNotEmpty
                          ? AppColors.primaryBlue
                          : AppColors.indigo,
                    ),
                    const Spacer(),
                    if (r.canChangeStatus)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: _busy ? null : () => _removeVoice(r.notulens[i]),
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: AppColors.rose),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '#${i + 1} ${r.notulens[i].topik}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                if (r.notulens[i].pembicara.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Pembicara: ${r.notulens[i].pembicara}',
                      style:
                          const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ),
                if (r.notulens[i].isiDiskusi.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(r.notulens[i].isiDiskusi),
                  ),
                if (r.notulens[i].keputusan.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Rekomendasi / Respon: ${r.notulens[i].keputusan}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.navySoft,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Halaman scan kamera untuk kehadiran (QR Tiket, QR KTA, atau barcode noreg).
class _MeetingScanPage extends StatefulWidget {
  const _MeetingScanPage();

  @override
  State<_MeetingScanPage> createState() => _MeetingScanPageState();
}

class _MeetingScanPageState extends State<_MeetingScanPage> {
  final _ctrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final b in capture.barcodes) {
      final v = b.rawValue?.trim();
      if (v != null && v.isNotEmpty) {
        _handled = true;
        Navigator.of(context).pop(v);
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
            errorBuilder: (_, error) => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Kamera tidak dapat dibuka. Periksa izin kamera aplikasi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            right: 8,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
                const Expanded(
                  child: Text(
                    'Scan Kehadiran Meeting',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _ctrl.toggleTorch(),
                  icon: const Icon(Icons.flashlight_on_outlined,
                      color: Colors.white),
                ),
              ],
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).padding.bottom + 32,
            child: const Text(
              'Arahkan kamera ke QR Tiket WA/App, QR KTA, atau Barcode Noreg',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
