import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/screen_security.dart';
import '../../core/session_store.dart';
import '../../core/theme.dart';
import '../../models/meeting_meta.dart';

const String _orgBaseUrl = 'https://bungtemin.net/btapi/Organisasi';

enum OrgSectionMode { puk, kp, pleno, member }

class OrganisasiManageScreen extends StatefulWidget {
  const OrganisasiManageScreen({
    super.key,
    required this.session,
    required this.meta,
    required this.mode,
    this.titleOverride,
    this.filterKpNo,
    this.filterPlenoId,
  });

  final UserSession session;
  final MeetingMeta meta;
  final OrgSectionMode mode;
  final String? titleOverride;
  final int? filterKpNo;
  final int? filterPlenoId;

  @override
  State<OrganisasiManageScreen> createState() => _OrganisasiManageScreenState();
}

class _OrganisasiManageScreenState extends State<OrganisasiManageScreen> {
  static const _plants = ['HO', 'STR #1', 'STR #2', 'KRW #1', 'KRW #2', 'KRW #3'];
  static const _shifts = ['Non-Shift', 'Red', 'White', 'Shift A', 'Shift B'];

  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;
  String _query = '';

  int? _selectedKpNo;
  int? _selectedPlenoId;

  @override
  void initState() {
    super.initState();
    ScreenSecurity.enable();
    _selectedKpNo = widget.filterKpNo ??
        ((widget.meta.isKp && !widget.meta.canManageAll)
            ? widget.meta.kpNo
            : null);
    _selectedPlenoId = widget.filterPlenoId;
    _load();
  }

  @override
  void dispose() {
    ScreenSecurity.disable();
    _searchCtrl.dispose();
    super.dispose();
  }

  String _maskPhone(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    if (s.length <= 4) return 'xxxx';
    return '${s.substring(0, s.length - 4)}xxxx';
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (widget.session.token.trim().isNotEmpty)
          'Authorization': 'Bearer ${widget.session.token.trim()}',
      };

  String get _screenTitle {
    if (widget.titleOverride != null && widget.titleOverride!.isNotEmpty) {
      return widget.titleOverride!;
    }
    return switch (widget.mode) {
      OrgSectionMode.puk => 'Pengaturan PUK',
      OrgSectionMode.kp => 'Koordinator Pleno (KP)',
      OrgSectionMode.pleno => 'Daftar Pleno',
      OrgSectionMode.member => 'Anggota (Member Basis)',
    };
  }

  bool get _canCreateOrEdit {
    return switch (widget.mode) {
      OrgSectionMode.puk => widget.meta.canManageAll,
      OrgSectionMode.kp => widget.meta.canManageAll,
      OrgSectionMode.pleno => widget.meta.canManageAll || widget.meta.isKp,
      OrgSectionMode.member =>
        widget.meta.canManageAll || widget.meta.isKp || widget.meta.isPleno,
    };
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isError ? AppColors.rose : AppColors.emerald,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final path = switch (widget.mode) {
        OrgSectionMode.puk => 'puk_list',
        OrgSectionMode.kp => 'kp_list',
        OrgSectionMode.pleno =>
          'pleno_list${(_selectedKpNo ?? 0) > 0 ? '?kp_no=$_selectedKpNo' : ''}',
        OrgSectionMode.member => () {
            final params = <String>[];
            if ((_selectedPlenoId ?? 0) > 0) {
              params.add('pleno_id=$_selectedPlenoId');
            } else if ((_selectedKpNo ?? 0) > 0) {
              params.add('kp_no=$_selectedKpNo');
            }
            if (_query.isNotEmpty) {
              params.add('q=${Uri.encodeQueryComponent(_query)}');
            }
            return 'member_list${params.isEmpty ? '' : '?${params.join('&')}'}';
          }(),
      };

      final res = await http
          .get(Uri.parse('$_orgBaseUrl/$path'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        final raw = body['data'] as List<dynamic>? ?? const [];
        if (!mounted) return;
        setState(() {
          _items = raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _loading = false;
        });
      } else {
        throw Exception(body['message'] ?? 'Gagal memuat data (${res.statusCode})');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _post(String endpoint, Map<String, dynamic> payload) async {
    final res = await http
        .post(
          Uri.parse('$_orgBaseUrl/$endpoint'),
          headers: _headers,
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300 && body['success'] == true) {
      _snack((body['message'] ?? 'Berhasil disimpan').toString());
      await _load();
      return;
    }
    throw Exception(body['message'] ?? 'Gagal menyimpan (${res.statusCode})');
  }

  Future<void> _editPhoneQuick(Map<String, dynamic> item) async {
    final ctrl = TextEditingController(text: (item['no_hp'] ?? '').toString());
    final nama = (item['nama'] ?? '').toString();
    final noreg = (item['noreg'] ?? '').toString();

    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Edit Nomor Telp / WA',
          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$nama ($noreg)',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.phone,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Nomor WhatsApp / HP',
                hintText: '08xxxxxxxxxx',
                prefixIcon: const Icon(Icons.phone_android_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: AppColors.emerald),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (saved == null) return;

    try {
      await _post('update_phone', {
        'noreg': noreg,
        'no_hp': saved,
        if (widget.mode == OrgSectionMode.member) 'member_id': item['id'],
      });
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> item) async {
    final nama = (item['nama'] ?? '').toString();
    final label = switch (widget.mode) {
      OrgSectionMode.puk => 'Lepas $nama dari Pengurus PUK (kembali ke Member)?',
      OrgSectionMode.kp => 'Lepas $nama dari Koordinator KP (kembali ke Member)?',
      OrgSectionMode.pleno => 'Lepas $nama dari Pleno (kembali ke Member)?',
      OrgSectionMode.member => 'Hapus anggota $nama dari daftar binaan?',
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Konfirmasi Hapus',
          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
        ),
        content: Text(label, style: const TextStyle(fontSize: 13.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final endpoint = switch (widget.mode) {
      OrgSectionMode.puk => 'puk_delete',
      OrgSectionMode.kp => 'kp_delete',
      OrgSectionMode.pleno => 'pleno_delete',
      OrgSectionMode.member => 'member_delete',
    };
    try {
      await _post(endpoint, {'id': item['id']});
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final noregCtrl = TextEditingController(
      text: (existing?['noreg'] ?? '').toString(),
    );
    final namaCtrl = TextEditingController(
      text: (existing?['nama'] ?? '').toString(),
    );
    final phoneCtrl = TextEditingController(
      text: (existing?['no_hp'] ?? '').toString(),
    );
    final deptCtrl = TextEditingController(
      text: (existing?['dept'] ?? '').toString(),
    );
    final divisiCtrl = TextEditingController(
      text: (existing?['divisi'] ?? '').toString(),
    );
    final seksiCtrl = TextEditingController(
      text: (existing?['seksi'] ?? '').toString(),
    );
    final kpNoCtrl = TextEditingController(
      text: (existing?['kp_no'] ?? '').toString() == '0'
          ? ''
          : (existing?['kp_no'] ?? '').toString(),
    );

    var plant = (existing?['plant'] ?? '').toString();
    if (!_plants.contains(plant)) plant = 'KRW #1';

    var shift = (existing?['shift'] ?? '').toString();
    if (!_shifts.contains(shift)) shift = 'Non-Shift';

    var komisi = (existing?['komisi'] ?? 'A').toString();
    if (!const ['A', 'B', 'C', 'D', 'E', 'Ketua', 'Sekretaris', 'Bendahara']
        .contains(komisi)) {
      komisi = 'A';
    }

    int? kpChoice = int.tryParse((existing?['kp_no'] ?? '').toString());
    if (kpChoice == null || kpChoice <= 0) {
      kpChoice = _selectedKpNo ?? (widget.meta.kpNo > 0 ? widget.meta.kpNo : null);
    }

    int? plenoChoice = int.tryParse((existing?['pleno_id'] ?? '').toString());
    if (plenoChoice == null || plenoChoice <= 0) {
      plenoChoice = _selectedPlenoId;
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        var submitting = false;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> pickCandidate() async {
              final picked = await showModalBottomSheet<Map<String, dynamic>>(
                context: ctx,
                isScrollControlled: true,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (_) => _CandidateSearchSheet(headers: _headers),
              );
              if (picked == null) return;
              setModalState(() {
                noregCtrl.text = (picked['noreg'] ?? '').toString();
                namaCtrl.text = (picked['nama'] ?? '').toString();
                phoneCtrl.text = (picked['no_hp'] ?? '').toString();
                deptCtrl.text = (picked['dept'] ?? '').toString();
                divisiCtrl.text = (picked['divisi'] ?? '').toString();
                final p = (picked['plant'] ?? '').toString();
                if (_plants.contains(p)) plant = p;
              });
            }

            final filteredPlenos = widget.meta.plenoList.where((p) {
              if (!widget.meta.canManageAll && widget.meta.isKp && widget.meta.kpNo > 0) {
                return p.kp == widget.meta.kpNo;
              }
              if ((kpChoice ?? 0) > 0) return p.kp == kpChoice;
              return true;
            }).toList();

            return Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                14,
                18,
                MediaQuery.of(ctx).viewInsets.bottom + 22,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${isEdit ? 'Edit' : 'Tambah'} $_screenTitle',
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                        if (!isEdit)
                          TextButton.icon(
                            onPressed: pickCandidate,
                            icon: const Icon(Icons.person_search_rounded, size: 18),
                            label: const Text('Cari Anggota'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: noregCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Noreg',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'No. Telp / WA',
                              hintText: '08xxxxxxxxxx',
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: namaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nama Lengkap',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (widget.mode == OrgSectionMode.puk) ...[
                      DropdownButtonFormField<String>(
                        initialValue: komisi,
                        decoration: const InputDecoration(
                          labelText: 'Komisi / Bidang',
                          isDense: true,
                        ),
                        items: [
                          for (final k in const [
                            'A', 'B', 'C', 'D', 'E',
                            'Ketua', 'Sekretaris', 'Bendahara',
                          ])
                            DropdownMenuItem(value: k, child: Text(k)),
                        ],
                        onChanged: (v) => setModalState(() => komisi = v ?? komisi),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (widget.mode == OrgSectionMode.kp) ...[
                      TextField(
                        controller: kpNoCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Nomor KP (kosongkan = otomatis)',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (widget.mode == OrgSectionMode.pleno &&
                        widget.meta.canManageAll) ...[
                      DropdownButtonFormField<int>(
                        initialValue: widget.meta.kpList.any((k) => k.kp == kpChoice)
                            ? kpChoice
                            : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'KP Penanggung Jawab',
                          isDense: true,
                        ),
                        items: [
                          for (final k in widget.meta.kpList)
                            DropdownMenuItem(
                              value: k.kp,
                              child: Text(
                                'KP ${k.kp} · ${k.nama}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => setModalState(() => kpChoice = v),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (widget.mode == OrgSectionMode.member &&
                        !widget.meta.isPleno) ...[
                      DropdownButtonFormField<int>(
                        initialValue: filteredPlenos.any((p) => p.id == plenoChoice)
                            ? plenoChoice
                            : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Pleno Penanggung Jawab',
                          isDense: true,
                        ),
                        items: [
                          for (final p in filteredPlenos)
                            DropdownMenuItem(
                              value: p.id,
                              child: Text(
                                'KP ${p.kp} · ${p.nama}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => setModalState(() => plenoChoice = v),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: plant,
                            decoration: const InputDecoration(
                              labelText: 'Plant',
                              isDense: true,
                            ),
                            items: [
                              for (final p in _plants)
                                DropdownMenuItem(value: p, child: Text(p)),
                            ],
                            onChanged: (v) => setModalState(() => plant = v ?? plant),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: widget.mode == OrgSectionMode.member
                              ? DropdownButtonFormField<String>(
                                  initialValue: shift,
                                  decoration: const InputDecoration(
                                    labelText: 'Shift',
                                    isDense: true,
                                  ),
                                  items: [
                                    for (final sh in _shifts)
                                      DropdownMenuItem(value: sh, child: Text(sh)),
                                  ],
                                  onChanged: (v) =>
                                      setModalState(() => shift = v ?? shift),
                                )
                              : TextField(
                                  controller: deptCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Dept',
                                    isDense: true,
                                  ),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (widget.mode == OrgSectionMode.member)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: seksiCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Seksi',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: divisiCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Divisi',
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      TextField(
                        controller: divisiCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Divisi',
                          isDense: true,
                        ),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: submitting
                            ? null
                            : () async {
                                setModalState(() => submitting = true);
                                try {
                                  final endpoint = switch (widget.mode) {
                                    OrgSectionMode.puk => 'puk_save',
                                    OrgSectionMode.kp => 'kp_save',
                                    OrgSectionMode.pleno => 'pleno_save',
                                    OrgSectionMode.member => 'member_save',
                                  };
                                  final payload = <String, dynamic>{
                                    if (isEdit) 'id': existing['id'],
                                    'noreg': noregCtrl.text.trim(),
                                    'nama': namaCtrl.text.trim(),
                                    'no_hp': phoneCtrl.text.trim(),
                                    'plant': plant,
                                    'dept': deptCtrl.text.trim(),
                                    'divisi': divisiCtrl.text.trim(),
                                    if (widget.mode == OrgSectionMode.puk)
                                      'komisi': komisi,
                                    if (widget.mode == OrgSectionMode.kp)
                                      'kp_no': kpNoCtrl.text.trim(),
                                    if (widget.mode == OrgSectionMode.pleno &&
                                        kpChoice != null)
                                      'kp_no': kpChoice,
                                    if (widget.mode == OrgSectionMode.member) ...{
                                      'seksi': seksiCtrl.text.trim(),
                                      'shift': shift,
                                      if (plenoChoice != null)
                                        'pleno_id': plenoChoice,
                                    },
                                  };
                                  await _post(endpoint, payload);
                                  if (ctx.mounted) Navigator.of(ctx).pop(true);
                                } catch (e) {
                                  setModalState(() => submitting = false);
                                  _snack(
                                    e.toString().replaceFirst('Exception: ', ''),
                                    isError: true,
                                  );
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.navy,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          submitting ? 'Menyimpan...' : 'Simpan Data',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    noregCtrl.dispose();
    namaCtrl.dispose();
    phoneCtrl.dispose();
    deptCtrl.dispose();
    divisiCtrl.dispose();
    seksiCtrl.dispose();
    kpNoCtrl.dispose();

    if (saved == true && mounted) {
      // _post already reloaded list
    }
  }

  void _openChildren(Map<String, dynamic> item) {
    if (widget.mode == OrgSectionMode.kp) {
      final kpNo = int.tryParse('${item['kp_no']}') ?? 0;
      if (kpNo <= 0) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => OrganisasiManageScreen(
            session: widget.session,
            meta: widget.meta,
            mode: OrgSectionMode.pleno,
            titleOverride: 'Pleno KP $kpNo · ${item['nama']}',
            filterKpNo: kpNo,
          ),
        ),
      );
    } else if (widget.mode == OrgSectionMode.pleno) {
      final plenoId = int.tryParse('${item['id']}') ?? 0;
      if (plenoId <= 0) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => OrganisasiManageScreen(
            session: widget.session,
            meta: widget.meta,
            mode: OrgSectionMode.member,
            titleOverride: 'Anggota · ${item['nama']}',
            filterPlenoId: plenoId,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _items.where((it) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return (it['nama'] ?? '').toString().toLowerCase().contains(q) ||
          (it['noreg'] ?? '').toString().toLowerCase().contains(q) ||
          (it['no_hp'] ?? '').toString().toLowerCase().contains(q) ||
          (it['plant'] ?? '').toString().toLowerCase().contains(q) ||
          (it['divisi'] ?? '').toString().toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _screenTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              '${filtered.length} terdaftar',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: _canCreateOrEdit
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text(
                'Tambah',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      body: Column(
        children: [
          Container(
            color: AppColors.navy,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.trim()),
              style: const TextStyle(fontSize: 14, color: AppColors.navy),
              decoration: InputDecoration(
                hintText: 'Cari nama, noreg, plant, atau no. HP...',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.muted),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 42,
                                color: AppColors.rose,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.muted),
                              ),
                              const SizedBox(height: 14),
                              FilledButton(
                                onPressed: _load,
                                child: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'Belum ada data di kategori ini.',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 88),
                              itemCount: filtered.length,
                              itemBuilder: (_, idx) => _buildCard(filtered[idx]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final nama = (item['nama'] ?? '-').toString();
    final noreg = (item['noreg'] ?? '').toString();
    final phone = (item['no_hp'] ?? '').toString();
    final plant = (item['plant'] ?? '').toString();
    final divisi = (item['divisi'] ?? '').toString();

    String badgeText = '';
    if (widget.mode == OrgSectionMode.kp) {
      badgeText = 'KP ${item['kp_no'] ?? '-'}';
    } else if (widget.mode == OrgSectionMode.pleno) {
      badgeText = 'KP ${item['kp_no'] ?? '-'}';
    } else if (widget.mode == OrgSectionMode.puk) {
      badgeText = 'Komisi ${item['komisi'] ?? '-'}';
    } else if (widget.mode == OrgSectionMode.member) {
      badgeText = (item['shift'] ?? 'Non-Shift').toString();
    }

    final subParts = <String>[
      'Noreg $noreg',
      if (plant.isNotEmpty) plant,
      if (divisi.isNotEmpty) divisi,
    ];

    final canDrillDown = widget.mode == OrgSectionMode.kp ||
        widget.mode == OrgSectionMode.pleno;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: canDrillDown ? () => _openChildren(item) : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 21,
                    backgroundColor: const Color(0xFFE0F2FE),
                    child: Text(
                      nama.isNotEmpty ? nama[0].toUpperCase() : 'A',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                nama,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: AppColors.navy,
                                ),
                              ),
                            ),
                            if (badgeText.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  badgeText,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subParts.join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        InkWell(
                          onTap: () => _editPhoneQuick(item),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: phone.isNotEmpty
                                  ? AppColors.emerald.withValues(alpha: 0.1)
                                  : AppColors.amber.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.phone_rounded,
                                  size: 14,
                                  color: phone.isNotEmpty
                                      ? const Color(0xFF047857)
                                      : const Color(0xFFB45309),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  phone.isNotEmpty
                                      ? _maskPhone(phone)
                                      : 'Isi No. WA',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: phone.isNotEmpty
                                        ? const Color(0xFF047857)
                                        : const Color(0xFFB45309),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.edit_rounded,
                                  size: 13,
                                  color: AppColors.muted,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (widget.mode == OrgSectionMode.kp)
                          Text(
                            '${item['total_pleno'] ?? 0} Pleno · ${item['total_member'] ?? 0} Anggota',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.muted,
                            ),
                          )
                        else if (widget.mode == OrgSectionMode.pleno)
                          Text(
                            '${item['total_member'] ?? 0} Anggota',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_canCreateOrEdit) ...[
                    const SizedBox(width: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 19,
                            color: AppColors.primaryBlue,
                          ),
                          tooltip: 'Edit',
                          onPressed: () => _openEditor(existing: item),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 19,
                            color: AppColors.rose,
                          ),
                          tooltip: 'Hapus',
                          onPressed: () => _confirmDelete(item),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CandidateSearchSheet extends StatefulWidget {
  const _CandidateSearchSheet({required this.headers});

  final Map<String, String> headers;

  @override
  State<_CandidateSearchSheet> createState() => _CandidateSearchSheetState();
}

class _CandidateSearchSheetState extends State<_CandidateSearchSheet> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _results = const [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(val));
  }

  Future<void> _search(String q) async {
    final clean = q.trim();
    if (clean.length < 2) {
      setState(() => _results = const []);
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await http
          .get(
            Uri.parse(
              '$_orgBaseUrl/search_candidates?q=${Uri.encodeQueryComponent(clean)}',
            ),
            headers: widget.headers,
          )
          .timeout(const Duration(seconds: 10));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        final list = (body['data'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (!mounted) return;
        setState(() {
          _results = list;
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.72,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 14, 18, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Cari Anggota dari Database Pemandatan',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: 'Ketik minimal 2 huruf nama atau noreg...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? const Center(
                        child: Text(
                          'Ketik nama atau noreg untuk mencari.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, idx) {
                          final r = _results[idx];
                          return ListTile(
                            title: Text(
                              '${r['nama'] ?? ''}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              'Noreg ${r['noreg'] ?? ''} • ${r['plant'] ?? '-'} • ${r['job'] ?? 'Member'}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            onTap: () => Navigator.of(context).pop(r),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
