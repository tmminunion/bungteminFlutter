import 'package:flutter/material.dart';

import '../../core/session_store.dart';
import '../../models/training_item.dart';
import '../../services/bungtemin_api.dart';
import 'pintar_buku_screen.dart';
import 'training_listbulan_screen.dart';
import 'training_pleno_screen.dart';
import 'training_ticket_screen.dart';

class _TrainingMenuLeaf {
  _TrainingMenuLeaf({
    required this.text,
    required this.key,
    this.badge = 0,
    this.route,
  });

  final String text;
  final String key;
  int badge;
  final String? route;
}

class _TrainingMenuSubGroup {
  _TrainingMenuSubGroup({
    required this.title,
    required this.key,
    this.badge = 0,
    this.open = true,
    required this.items,
  });

  final String title;
  final String key;
  int badge;
  bool open;
  final List<_TrainingMenuLeaf> items;
}

class _TrainingMenuGroup {
  _TrainingMenuGroup({
    required this.title,
    required this.key,
    this.badge = 0,
    this.open = true,
    required this.children,
  });

  final String title;
  final String key;
  int badge;
  bool open;
  final List<_TrainingMenuSubGroup> children;
}

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({
    super.key,
    this.session,
    this.initialTrainings,
    this.initialTickets,
  });

  final UserSession? session;
  final List<TrainingEventItem>? initialTrainings;
  final List<TrainingTicketItem>? initialTickets;

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  final BungteminApi _api = BungteminApi();
  late List<_TrainingMenuGroup> _menuData;

  int _totalBelum = 0;
  int _totalTiket = 0;

  @override
  void initState() {
    super.initState();
    _loadMenu();
    _initTrainingData();
  }

  void _loadMenu() {
    _menuData = [
      _TrainingMenuGroup(
        title: '1. Jadwal Belajar',
        key: 'jadwal',
        badge: 0,
        open: true,
        children: [
          _TrainingMenuSubGroup(
            title: '1.1 Agenda Bulan Ini',
            key: 'agenda',
            badge: 0,
            open: true,
            items: [
              _TrainingMenuLeaf(text: 'Anggota', key: 'anggota', badge: 0),
              _TrainingMenuLeaf(
                text: 'Pleno',
                key: 'pleno',
                badge: 0,
                route: '/training-pleno',
              ),
              _TrainingMenuLeaf(
                text: 'Tiket Saya',
                key: 'tiket',
                badge: 0,
                route: '/training-ticket',
              ),
              _TrainingMenuLeaf(
                text: 'Koordinator Pleno',
                key: 'koordinator',
                badge: 0,
              ),
              _TrainingMenuLeaf(
                text: 'Rakorpuk Lengkap-Sus',
                key: 'rakorpuk',
                badge: 0,
              ),
            ],
          ),
        ],
      ),
      _TrainingMenuGroup(
        title: '2. Training Need Analysis',
        key: 'tna',
        badge: 0,
        open: false,
        children: [],
      ),
    ];
  }

  Future<void> _initTrainingData() async {
    if (widget.initialTrainings != null || widget.initialTickets != null) {
      final trainings = widget.initialTrainings ?? const [];
      final tickets = widget.initialTickets ?? const [];
      _computeAndApplyBadges(trainings, tickets);
      return;
    }
    await _loadTickets();
    await _loadBadgeFromTraining();
  }

  Future<List<TrainingTicketItem>> _loadTickets() async {
    final s = widget.session ?? await SessionStore().load();
    final noreg = s?.noreg ?? '';
    final tickets = await _api.fetchTrainingTickets(noreg: noreg);
    if (mounted) {
      setState(() {
        _totalTiket = tickets.length;
      });
    }
    return tickets;
  }

  Future<void> _loadBadgeFromTraining() async {
    try {
      final resp = await _api.fetchTrainings(page: 1);
      final cachedRaw = await SessionStore().loadTrainingTicketsCache();
      final tickets = TrainingTicketItem.decodeList(cachedRaw);
      _computeAndApplyBadges(resp.data, tickets);
    } catch (_) {}
  }

  void _computeAndApplyBadges(
    List<TrainingEventItem> trainings,
    List<TrainingTicketItem> tickets,
  ) {
    final trainingIds = trainings.map((t) => t.eventSlug).toList();
    final registeredIds =
        tickets.map((t) => t.eventSlug).where((s) => s.isNotEmpty).toSet();
    final belumIds =
        trainingIds.where((id) => !registeredIds.contains(id)).toList();

    if (!mounted) return;
    setState(() {
      _totalBelum = belumIds.length;
      _totalTiket = tickets.length;
      _applyBadge({
        'pleno': _totalBelum,
        'tiket': _totalTiket,
      });
    });
  }

  void _applyBadge(Map<String, int> badgeData) {
    for (final m in _menuData) {
      if (badgeData.containsKey(m.key)) {
        m.badge = badgeData[m.key]!;
      }
      for (final c in m.children) {
        if (badgeData.containsKey(c.key)) {
          c.badge = badgeData[c.key]!;
        }
        for (final i in c.items) {
          if (badgeData.containsKey(i.key)) {
            i.badge = badgeData[i.key]!;
          }
        }
      }
    }
  }

  Future<void> _openPleno() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TrainingPlenoScreen(session: widget.session),
      ),
    );
    await _loadBadgeFromTraining();
  }

  Future<void> _openTickets() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TrainingTicketScreen(
          session: widget.session,
          onOpenPleno: () {
            Navigator.of(context).pop();
            _openPleno();
          },
        ),
      ),
    );
    await _loadBadgeFromTraining();
  }

  Future<void> _openListBulan() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TrainingListBulanScreen(session: widget.session),
      ),
    );
    await _loadBadgeFromTraining();
  }

  Future<void> _openBukuPintar() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PintarBukuScreen(),
      ),
    );
  }

  Future<void> _openLeafItem(_TrainingMenuLeaf item) async {
    if (item.route == '/training-pleno') {
      await _openPleno();
      return;
    }
    if (item.route == '/training-ticket') {
      await _openTickets();
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1800),
        content: Text(
          'Modul "${item.text}" sedang disiapkan untuk rilis berikutnya.',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadTickets();
          await _loadBadgeFromTraining();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeroHeader(context, topPad),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < _menuData.length; i++) ...[
                          if (i > 0) const SizedBox(height: 12),
                          _buildMenuGroup(i, _menuData[i]),
                        ],
                        const SizedBox(height: 12),
                        _buildQuickResourcesCard(),
                      ],
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

  Widget _buildHeroHeader(BuildContext context, double topPad) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18, topPad + 18, 18, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.58, 1.0],
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E3A8A),
            Color(0xFF0284C7),
          ],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
        boxShadow: [
          BoxShadow(
            color: Color(0x380F172A),
            blurRadius: 36,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Material(
                color: Colors.white.withValues(alpha: 0.12),
                shape: StadiumBorder(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
                ),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => Navigator.of(context).maybePop(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_back_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Beranda',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Material(
                color: Colors.white.withValues(alpha: 0.12),
                shape: StadiumBorder(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
                ),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: _openTickets,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.confirmation_number_outlined,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Tiket ($_totalTiket)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.26),
                  ),
                ),
                child: Image.asset(
                  'assets/icon/4.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BIDANG PENDIDIKAN • PUK SPSI',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: Color(0xFF7DD3FC),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Pusat Training',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Jadwal pelatihan, registrasi peserta, & e-tiket kehadiran',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xE0E2E8F0),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _openPleno,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.20),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_totalBelum',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'Training Tersedia',
                          style: TextStyle(
                            color: Color(0xE6E2E8F0),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _openTickets,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.20),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_totalTiket',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'Tiket Terdaftar',
                          style: TextStyle(
                            color: Color(0xE6E2E8F0),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuGroup(int index, _TrainingMenuGroup group) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 26,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Material(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() => group.open = !group.open),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1D4ED8), Color(0xFF0284C7)],
                            ),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            '0${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          group.title,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (group.badge > 0) ...[
                          _buildCountBadge(
                            group.badge,
                            color: const Color(0xFFEF4444),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Icon(
                          group.open
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.chevron_right_rounded,
                          color: const Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (group.open)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              child: group.children.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_outlined,
                            size: 18,
                            color: Color(0xFF64748B),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Evaluasi kompetensi & TNA akan segera hadir.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        for (final sub in group.children)
                          _buildSubGroup(sub),
                      ],
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubGroup(_TrainingMenuSubGroup sub) {
    return Column(
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => sub.open = !sub.open),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    sub.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334155),
                    ),
                  ),
                  Row(
                    children: [
                      if (sub.badge > 0) ...[
                        _buildCountBadge(
                          sub.badge,
                          color: const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Icon(
                        sub.open
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.chevron_right_rounded,
                        color: const Color(0xFF64748B),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (sub.open) ...[
          const SizedBox(height: 8),
          for (var i = 0; i < sub.items.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _buildLeafItem(sub.items[i]),
          ],
        ],
      ],
    );
  }

  Widget _buildLeafItem(_TrainingMenuLeaf item) {
    Color iconBg = const Color(0xFFEFF6FF);
    Color iconColor = const Color(0xFF2563EB);
    IconData iconData = Icons.school_outlined;

    if (item.key == 'pleno') {
      iconBg = const Color(0xFFDBEAFE);
      iconColor = const Color(0xFF1D4ED8);
      iconData = Icons.calendar_today_outlined;
    } else if (item.key == 'tiket') {
      iconBg = const Color(0xFFDCFCE7);
      iconColor = const Color(0xFF15803D);
      iconData = Icons.confirmation_number_outlined;
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openLeafItem(item),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(iconData, size: 18, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.text,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (item.badge > 0) ...[
                _buildCountBadge(
                  item.badge,
                  color: const Color(0xFF2563EB),
                ),
                const SizedBox(width: 8),
              ],
              const Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickResourcesCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _openBukuPintar,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.menu_book_rounded, size: 17),
              label: const Text(
                'Buku Pintar UU',
                style: TextStyle(fontSize: 12.2, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _openListBulan,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.calendar_month_rounded, size: 17),
              label: const Text(
                'Rekap Bulanan',
                style: TextStyle(fontSize: 12.2, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountBadge(int count, {required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
