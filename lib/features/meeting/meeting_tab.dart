import 'package:flutter/material.dart';

import '../../core/session_store.dart';
import '../../core/theme.dart';
import '../../models/meeting_item.dart';
import '../../services/bungtemin_api.dart';
import 'meeting_room_screen.dart';

class MeetingTab extends StatefulWidget {
  const MeetingTab({
    super.key,
    required this.session,
    this.initialSegment = 0,
    this.lockSegment = false,
    this.onBackHome,
    this.initialData,
  });

  final UserSession session;
  final int initialSegment;

  /// true: jangan pindah otomatis ke tab lain saat tab awal kosong (dibuka dari Hub).
  final bool lockSegment;
  final VoidCallback? onBackHome;
  final MeetingDashboardData? initialData;

  @override
  State<MeetingTab> createState() => _MeetingTabState();
}

class _MeetingTabState extends State<MeetingTab> {
  final _api = BungteminApi();
  final _searchCtrl = TextEditingController();

  // 0: Meeting PUK, 1: Meeting KP, 2: Meeting Pleno, 3: Meeting Anggota
  // (urutan sama dengan router organisasi di web).
  late int _activeSegment;
  bool _segmentTouched = false;
  String _statusFilter = 'all';
  String _query = '';
  bool _loading = true;
  String? _error;
  List<MeetingItem> _items = const [];
  String _roleLabel = '';
  int _pctHadir = 0;

  static const _segments = [
    ('PUK', 'Meeting PUK', Icons.account_balance_outlined),
    ('KP', 'Meeting KP', Icons.groups_2_outlined),
    ('Pleno', 'Meeting Pleno', Icons.work_outline_rounded),
    ('Anggota', 'Meeting Anggota', Icons.people_outline_rounded),
  ];

  static const _statusFilters = [
    ('all', 'Semua'),
    ('planning', 'Planning'),
    ('ongoing', 'Berlangsung'),
    ('review_kp', 'Review KP'),
    ('review_puk', 'Review PUK'),
    ('completed', 'Selesai'),
  ];

  @override
  void initState() {
    super.initState();
    _activeSegment = widget.initialSegment;
    if (widget.initialData != null) {
      _items = widget.initialData!.meetings;
      _roleLabel = widget.initialData!.roleLabel;
      _pctHadir = widget.initialData!.pctHadir;
      _loading = false;
      _autoSelectSegment();
    } else {
      _load();
    }
  }

  @override
  void didUpdateWidget(covariant MeetingTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSegment != widget.initialSegment) {
      setState(() => _activeSegment = widget.initialSegment);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.fetchMeetings(
        noreg: widget.session.noreg,
        token: widget.session.token,
      );
      if (!mounted) return;
      setState(() {
        _items = data.meetings;
        _roleLabel = data.roleLabel;
        _pctHadir = data.pctHadir;
        _autoSelectSegment();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  List<MeetingItem> _bySegment(int seg) =>
      _items.where((m) => m.segment == seg).toList();

  /// Jika pengguna belum memilih tab sendiri, buka tab pertama yang ada isinya.
  void _autoSelectSegment() {
    if (_segmentTouched || widget.lockSegment || widget.initialSegment != 0) {
      return;
    }
    if (_items.isEmpty || _bySegment(_activeSegment).isNotEmpty) return;
    for (var i = 0; i < _segments.length; i++) {
      if (_bySegment(i).isNotEmpty) {
        _activeSegment = i;
        return;
      }
    }
  }

  static (String, Color) _kategoriChip(MeetingItem m) => switch (m.segment) {
        0 => ('Rapat PUK', AppColors.indigo),
        1 => ('Rapat KP', AppColors.sky),
        2 => ('KP ↔ Pleno', AppColors.primaryBlue),
        _ => ('Pleno ↔ Member', AppColors.emerald),
      };

  static String _pihakLabel(MeetingItem m) => switch (m.segment) {
        0 || 1 =>
          m.pimpinanRapat.isNotEmpty ? 'Pimpinan: ${m.pimpinanRapat}' : '',
        2 => 'KP: ${m.kpNama}',
        _ => 'Pleno: ${m.plenoNama}',
      };

  List<MeetingItem> get _filtered {
    final source = _bySegment(_activeSegment);
    final q = _query.trim().toLowerCase();

    return source.where((m) {
      final st = m.status.toLowerCase();
      final matchesStatus = switch (_statusFilter) {
        'all' => true,
        'completed' => st == 'finish' || st == 'completed',
        _ => st == _statusFilter,
      };
      if (!matchesStatus) return false;
      if (q.isEmpty) return true;
      return m.judul.toLowerCase().contains(q) ||
          m.kodeMeeting.toLowerCase().contains(q) ||
          m.tempat.toLowerCase().contains(q) ||
          m.kpNama.toLowerCase().contains(q) ||
          m.plenoNama.toLowerCase().contains(q);
    }).toList();
  }

  static String _statusLabel(String raw) {
    return switch (raw.toLowerCase()) {
      'planning' => 'Planning',
      'scheduled' => 'Terjadwal',
      'ongoing' => 'Berlangsung',
      'review_kp' => 'Review KP',
      'review_puk' => 'Review PUK',
      'completed' => 'Selesai',
      'finish' => 'Finish',
      'cancelled' => 'Dibatalkan',
      _ => raw.isNotEmpty ? raw.toUpperCase() : 'PLANNING',
    };
  }

  static Color _statusColor(String raw) {
    return switch (raw.toLowerCase()) {
      'finish' || 'completed' => AppColors.emerald,
      'ongoing' => AppColors.sky,
      'review_kp' || 'review_puk' => AppColors.amber,
      'cancelled' => AppColors.rose,
      _ => AppColors.indigo,
    };
  }

  @override
  Widget build(BuildContext context) {
    final visible = _filtered;

    return Container(
      color: AppColors.surface,
      child: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Aurora Hero Header (identik gaya NewsTab)
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  18,
                  MediaQuery.of(context).padding.top + 12,
                  18,
                  22,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.navy,
                      AppColors.navyMid,
                      AppColors.navyDeep,
                    ],
                  ),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (widget.onBackHome != null)
                          _HeaderPillButton(
                            icon: Icons.arrow_back_rounded,
                            label: 'Beranda',
                            onTap: widget.onBackHome!,
                          )
                        else
                          const SizedBox.shrink(),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_pctHadir > 0) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.emerald
                                      .withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: AppColors.emerald
                                        .withValues(alpha: 0.45),
                                  ),
                                ),
                                child: Text(
                                  '$_pctHadir% Hadir',
                                  style: const TextStyle(
                                    color: Color(0xFFA7F3D0),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            _HeaderIconButton(
                              icon: Icons.refresh_rounded,
                              onTap: _load,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Image.asset('assets/icon/23.png'),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _roleLabel.isNotEmpty
                                    ? _roleLabel.toUpperCase()
                                    : 'HUB MANAGEMENT MEETING',
                                style: const TextStyle(
                                  color: Color(0xFF7DD3FC),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _segments[_activeSegment.clamp(0, _segments.length - 1)].$2,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.session.nama} · Noreg ${SessionStore.formatNoreg8(widget.session.noreg)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
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
            ),

            // Search Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.navy.withValues(alpha: 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: _activeSegment == 0
                          ? 'Cari agenda meeting pleno...'
                          : 'Cari agenda meeting anggota...',
                      hintStyle: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13.5,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.muted,
                      ),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Status Chips
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Row(
                  children: _statusFilters.map((entry) {
                    final key = entry.$1;
                    final label = entry.$2;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: _statusFilter == key,
                        onSelected: (_) => setState(() => _statusFilter = key),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            if (_loading && _items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
              )
            else if (_error != null && _items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Muat Ulang'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (visible.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _segments[_activeSegment].$3,
                          size: 48,
                          color: AppColors.muted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Belum Ada ${_segments[_activeSegment].$2}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Ubah filter status atau tarik ke bawah untuk memuat ulang agenda.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                sliver: SliverList.separated(
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, idx) {
                    final m = visible[idx];
                    final statusColor = _statusColor(m.status);
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _openRoom(m),
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.navy.withValues(alpha: 0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      _statusLabel(m.status),
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _kategoriChip(m)
                                          .$2
                                          .withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      _kategoriChip(m).$1,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: _kategoriChip(m).$2,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Flexible(
                                    child: Text(
                                      m.kodeMeeting,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.muted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 9),
                              Text(
                                m.judul,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.navy,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${m.tanggal} • ${m.jamMulai} WIB • ${m.tempat}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.muted,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.people_alt_outlined,
                                    size: 16,
                                    color: AppColors.muted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${m.totalHadir}/${m.totalPeserta} hadir',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.navySoft,
                                    ),
                                  ),
                                  const Spacer(),
                                  Flexible(
                                    child: Text(
                                      _pihakLabel(m),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.blueAccent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openRoom(MeetingItem m) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MeetingRoomScreen(session: widget.session, meeting: m),
      ),
    );
    if (mounted) _load();
  }
}

class _HeaderPillButton extends StatelessWidget {
  const _HeaderPillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 17),
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

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

