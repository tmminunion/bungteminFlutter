import 'package:flutter/material.dart';

import '../../core/session_store.dart';
import '../../core/theme.dart';
import '../../models/meeting_meta.dart';
import '../../services/bungtemin_api.dart';

/// Segmen meeting (urutan sama dengan Hub & web organisasi).
class MeetingKind {
  const MeetingKind({
    required this.segment,
    required this.title,
    required this.kategori,
    required this.mode,
    required this.icon,
    required this.color,
  });

  final int segment;
  final String title;
  final String kategori;

  /// `pleno` atau `member` (parameter `mode` di API).
  final String mode;
  final IconData icon;
  final Color color;

  static const List<MeetingKind> all = [
    MeetingKind(
      segment: 0,
      title: 'Meeting PUK',
      kategori: 'Rapat PUK',
      mode: 'pleno',
      icon: Icons.account_balance_outlined,
      color: AppColors.indigo,
    ),
    MeetingKind(
      segment: 1,
      title: 'Meeting KP',
      kategori: 'Rapat KP',
      mode: 'pleno',
      icon: Icons.groups_2_outlined,
      color: AppColors.sky,
    ),
    MeetingKind(
      segment: 2,
      title: 'Meeting Pleno',
      kategori: 'Rapat Pleno',
      mode: 'pleno',
      icon: Icons.work_outline_rounded,
      color: AppColors.primaryBlue,
    ),
    MeetingKind(
      segment: 3,
      title: 'Meeting Anggota',
      kategori: 'Rapat Member',
      mode: 'member',
      icon: Icons.people_outline_rounded,
      color: AppColors.emerald,
    ),
  ];
}

class MeetingCreateScreen extends StatefulWidget {
  const MeetingCreateScreen({
    super.key,
    required this.session,
    required this.kind,
    required this.meta,
    this.api,
  });

  final UserSession session;
  final MeetingKind kind;
  final MeetingMeta meta;
  final BungteminApi? api;

  @override
  State<MeetingCreateScreen> createState() => _MeetingCreateScreenState();
}

class _MeetingCreateScreenState extends State<MeetingCreateScreen> {
  static const _plants = ['HO', 'STR #1', 'STR #2', 'KRW #1', 'KRW #2', 'KRW #3'];

  late final BungteminApi _api = widget.api ?? BungteminApi();
  final _tempatCtrl = TextEditingController();
  final _agendaCtrl = TextEditingController();

  late DateTime _tanggal;
  TimeOfDay _jamMulai = const TimeOfDay(hour: 9, minute: 0);
  late String _plant;
  int? _kpNo;
  int? _plenoId;
  bool _saving = false;

  MeetingMeta get _meta => widget.meta;
  MeetingKind get _kind => widget.kind;

  bool get _isAnggota => _kind.segment == 3;
  bool get _isPleno => _kind.segment == 2;

  /// Admin/PUK memilih KP sendiri untuk meeting Pleno & Anggota.
  bool get _needsKpPicker =>
      _meta.canManageAll && (_isPleno || _isAnggota);

  /// Meeting Anggota oleh admin/KP memilih Pleno binaan (Pleno otomatis pakai miliknya).
  bool get _needsPlenoPicker => _isAnggota && !_meta.isPleno;

  int get _effectiveKp => _meta.canManageAll ? (_kpNo ?? 0) : _meta.kpNo;

  List<MetaPerson> get _plenoOptions {
    final kp = _effectiveKp;
    if (kp <= 0) return _meta.canManageAll ? _meta.plenoList : const [];
    return _meta.plenoList.where((p) => p.kp == kp).toList();
  }

  @override
  void initState() {
    super.initState();
    _tanggal = DateTime.tryParse(_meta.defaultTanggal) ??
        DateTime.now().add(const Duration(days: 3));
    _plant = _plants.contains(_meta.defaultPlant) ? _meta.defaultPlant : 'KRW #1';
    _tempatCtrl.text =
        _isAnggota ? 'Sekretariat / Ruang Rapat' : 'Ruang Rapat PUK';
  }

  @override
  void dispose() {
    _tempatCtrl.dispose();
    _agendaCtrl.dispose();
    super.dispose();
  }

  static String _two(int n) => n < 10 ? '0$n' : '$n';
  static String _fmtTime(TimeOfDay t) => '${_two(t.hour)}:${_two(t.minute)}';
  static String _fmtDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

  static const _bulan = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  static String _fmtDateId(DateTime d) =>
      '${d.day} ${_bulan[d.month - 1]} ${d.year}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _tanggal = picked);
  }

  Future<void> _pickStart() async {
    final t = await showTimePicker(context: context, initialTime: _jamMulai);
    if (t != null) setState(() => _jamMulai = t);
  }

  String? _validate() {
    if (_needsKpPicker && (_kpNo == null || _kpNo == 0)) {
      return 'Pilih KP terlebih dahulu.';
    }
    if (_isAnggota && _needsPlenoPicker && _plenoId == null) {
      return 'Pilih Pleno binaan untuk Meeting Anggota.';
    }
    if (_tempatCtrl.text.trim().isEmpty) {
      return 'Isi tempat rapat terlebih dahulu.';
    }
    if (_isAnggota && _meta.memberCount < _meta.minMember && !_needsPlenoPicker) {
      return 'Member terdaftar baru ${_meta.memberCount} orang (minimal ${_meta.minMember}).';
    }
    return null;
  }

  Future<void> _submit() async {
    final err = _validate();
    if (err != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(err)));
      return;
    }

    final payload = <String, dynamic>{
      'mode': _kind.mode,
      'kategori': _kind.kategori,
      'judul': '',
      'tanggal': _fmtDate(_tanggal),
      'jam_mulai': _fmtTime(_jamMulai),
      'tempat': _tempatCtrl.text.trim(),
      'plant': _plant,
      'tipe_meeting': 'offline',
      'link_online': '',
      'agenda': _agendaCtrl.text.trim(),
      if (_meta.canManageAll && _kpNo != null && _kpNo != 0) 'kp_no': _kpNo,
      if (_plenoId != null && _needsPlenoPicker) 'pleno_id': _plenoId,
    };

    setState(() => _saving = true);
    try {
      final msg = await _api.createMeeting(
        noreg: widget.session.noreg,
        token: widget.session.token,
        payload: payload,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _kind.color;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          'Buat ${_kind.title}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _banner(color),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_needsKpPicker) ...[
                    DropdownButtonFormField<int>(
                      initialValue: _kpNo,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'KP Penyelenggara'),
                      items: [
                        for (final kp in _meta.kpList)
                          DropdownMenuItem(
                            value: kp.kp,
                            child: Text(
                              'KP ${kp.kp} · ${kp.nama}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() {
                        _kpNo = v;
                        _plenoId = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_needsPlenoPicker) ...[
                    DropdownButtonFormField<int>(
                      initialValue: _plenoOptions.any((p) => p.id == _plenoId)
                          ? _plenoId
                          : null,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Pleno Binaan',
                        helperText: _plenoOptions.isEmpty
                            ? 'Pilih KP dahulu atau belum ada Pleno'
                            : null,
                      ),
                      items: [
                        for (final p in _plenoOptions)
                          DropdownMenuItem(
                            value: p.id,
                            child: Text(p.nama, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) => setState(() => _plenoId = v),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: _pickerTile(
                          icon: Icons.event_rounded,
                          label: 'Tanggal',
                          value: _fmtDateId(_tanggal),
                          onTap: _pickDate,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _pickerTile(
                          icon: Icons.schedule_rounded,
                          label: 'Jam Mulai',
                          value: _fmtTime(_jamMulai),
                          onTap: _pickStart,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: _plant,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Plant'),
                          items: [
                            for (final p in _plants)
                              DropdownMenuItem(value: p, child: Text(p)),
                          ],
                          onChanged: (v) => setState(() => _plant = v ?? _plant),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _tempatCtrl,
                          decoration: const InputDecoration(labelText: 'Tempat'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _agendaCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Agenda Singkat (opsional)',
                      hintText: _kind.kategori,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(
                  _saving ? 'Menyimpan...' : 'Buat Meeting',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Judul dibuat otomatis dan tiket QR dikirim via WhatsApp.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _banner(Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_kind.icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _kind.kategori,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isAnggota
                      ? 'Member terdaftar: ${_meta.memberCount} (minimal ${_meta.minMember})'
                      : (_meta.roleLabel.isNotEmpty
                          ? _meta.roleLabel
                          : 'Judul otomatis dari sistem'),
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pickerTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: AppColors.primaryBlue),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
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
