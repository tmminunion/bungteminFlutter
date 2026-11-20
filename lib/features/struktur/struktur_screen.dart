import 'dart:ui';
import 'package:flutter/material.dart';

import '../../core/session_store.dart';
import '../../core/theme.dart';
import '../../models/struktur_item.dart';
import '../../services/bungtemin_api.dart';
import '../../core/net/btapi_auth.dart';

class StrukturScreen extends StatefulWidget {
  const StrukturScreen({
    super.key,
    this.initialGroups,
  });

  final List<StrukturPeriodGroup>? initialGroups;

  @override
  State<StrukturScreen> createState() => _StrukturScreenState();
}

class _StrukturScreenState extends State<StrukturScreen> {
  final _api = BungteminApi();
  final _searchCtrl = TextEditingController();

  List<StrukturPeriodGroup> _groups = const [];
  int _selectedPeriodIndex = 0;
  String _searchQuery = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialGroups != null && widget.initialGroups!.isNotEmpty) {
      _groups = widget.initialGroups!;
      _loading = false;
    } else {
      _loadCachedAndFresh();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCachedAndFresh() async {
    final cached = await SessionStore().loadStrukturCache();
    if (cached != null) {
      final parsed = BungteminApi.parseStrukturJson(cached);
      if (parsed.isNotEmpty && mounted) {
        setState(() {
          _groups = parsed;
          _loading = false;
        });
      }
    }

    final fresh = await _api.fetchStruktur();
    if (!mounted) return;
    setState(() {
      if (fresh.isNotEmpty) {
        _groups = fresh;
        if (_selectedPeriodIndex >= _groups.length) {
          _selectedPeriodIndex = 0;
        }
      }
      _loading = false;
    });
  }

  StrukturPeriodGroup? get _activeGroup {
    if (_groups.isEmpty) return null;
    final idx = _selectedPeriodIndex.clamp(0, _groups.length - 1);
    return _groups[idx];
  }

  List<StrukturMember> get _filteredAnggota {
    final grp = _activeGroup;
    if (grp == null) return const [];
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return grp.anggota;
    return grp.anggota
        .where(
          (p) =>
              p.nama.toLowerCase().contains(q) ||
              p.job.toLowerCase().contains(q) ||
              p.cleanedJob.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final activeGroup = _activeGroup;
    final filtered = _filteredAnggota;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator(
        onRefresh: _loadCachedAndFresh,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _StrukturHeroHeader(
                    eyebrow: activeGroup != null
                        ? activeGroup.cleanedTag
                        : 'STRUKTUR ORGANISASI',
                    periode: activeGroup?.periode,
                    totalPengurus: activeGroup?.anggota.length ?? 0,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -44),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 36),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          children: [
                            if (_groups.isNotEmpty) ...[
                              _StrukturControlCard(
                                groups: _groups,
                                selectedIndex: _selectedPeriodIndex,
                                searchCtrl: _searchCtrl,
                                searchQuery: _searchQuery,
                                onSelectPeriod: (idx) =>
                                    setState(() => _selectedPeriodIndex = idx),
                                onSearchChanged: (v) =>
                                    setState(() => _searchQuery = v),
                                onClearSearch: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              ),
                              const SizedBox(height: 18),
                            ],
                            if (_loading && _groups.isEmpty)
                              const _StrukturStateBox(
                                isLoading: true,
                                title: 'Memuat Struktur',
                                subtitle:
                                    'Memuat data struktur kepengurusan...',
                              )
                            else if (activeGroup == null)
                              const _StrukturStateBox(
                                isLoading: false,
                                title: 'Data Belum Tersedia',
                                subtitle:
                                    'Tarik ke bawah untuk memuat ulang struktur kepengurusan.',
                              )
                            else if (filtered.isEmpty)
                              _StrukturStateBox(
                                isLoading: false,
                                title: 'Data Tidak Ditemukan',
                                subtitle:
                                    'Tidak ada pengurus dengan kata kunci "$_searchQuery"',
                              )
                            else
                              Column(
                                children: [
                                  for (var i = 0; i < filtered.length; i++) ...[
                                    if (i > 0) const SizedBox(height: 12),
                                    _StrukturMemberCard(
                                      member: filtered[i],
                                      displayNo: filtered[i].no > 0
                                          ? filtered[i].no
                                          : (i + 1),
                                    ),
                                  ],
                                ],
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

class _StrukturHeroHeader extends StatelessWidget {
  const _StrukturHeroHeader({
    required this.eyebrow,
    required this.periode,
    required this.totalPengurus,
    required this.onBack,
  });

  final String eyebrow;
  final String? periode;
  final int totalPengurus;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.58, 1.0],
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E3A8A),
            Color(0xFF0284C7),
          ],
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(34),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.22),
            blurRadius: 36,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -40,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 42, sigmaY: 42),
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -40,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 42, sigmaY: 42),
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6366F1).withValues(alpha: 0.28),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(18, topPad + 16, 18, 68),
            child: Column(
              children: [
                // Top Navigation Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onBack,
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
                              color: Colors.white.withValues(alpha: 0.24),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_back_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Kembali',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (totalPengurus > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF38BDF8).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0xFF7DD3FC)
                                .withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.groups_rounded,
                              size: 16,
                              color: Color(0xFF38BDF8),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$totalPengurus Pengurus',
                              style: const TextStyle(
                                color: Color(0xFFE0F2FE),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                // Hero Title & Period Summary
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.navy.withValues(alpha: 0.25),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/icon/5.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.account_tree_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            eyebrow.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                              color: Color(0xFF7DD3FC),
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Struktur Kepengurusan',
                            style: TextStyle(
                              fontSize: 20.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (periode != null && periode!.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              'Masa Bakti $periode',
                              style: TextStyle(
                                fontSize: 12.8,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFE2E8F0)
                                    .withValues(alpha: 0.85),
                              ),
                            ),
                          ],
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

class _StrukturControlCard extends StatelessWidget {
  const _StrukturControlCard({
    required this.groups,
    required this.selectedIndex,
    required this.searchCtrl,
    required this.searchQuery,
    required this.onSelectPeriod,
    required this.onSearchChanged,
    required this.onClearSearch,
  });

  final List<StrukturPeriodGroup> groups;
  final int selectedIndex;
  final TextEditingController searchCtrl;
  final String searchQuery;
  final ValueChanged<int> onSelectPeriod;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.12),
            blurRadius: 36,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          if (groups.length > 1) ...[
            Row(
              children: [
                for (var i = 0; i < groups.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _PeriodTabButton(
                      label: i == 0 ? 'Periode Aktif' : 'Demisioner',
                      periode: groups[i].periode,
                      icon: i == 0
                          ? Icons.verified_user_outlined
                          : Icons.history_rounded,
                      active: selectedIndex == i,
                      onTap: () => onSelectPeriod(i),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
          ],
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  size: 19,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: searchCtrl,
                    onChanged: onSearchChanged,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: 'Cari nama pengurus atau jabatan...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ),
                if (searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: onClearSearch,
                    child: const Icon(
                      Icons.cancel_rounded,
                      size: 19,
                      color: Color(0xFF94A3B8),
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

class _PeriodTabButton extends StatelessWidget {
  const _PeriodTabButton({
    required this.label,
    required this.periode,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String periode;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: active
                ? const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF0284C7)],
                  )
                : null,
            color: active ? null : const Color(0xFFF8FAFC),
            border: Border.all(
              color: active ? Colors.transparent : const Color(0xFFE2E8F0),
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: active ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: active
                            ? Colors.white.withValues(alpha: 0.85)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      periode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: active ? Colors.white : const Color(0xFF334155),
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
}

class _StrukturMemberCard extends StatelessWidget {
  const _StrukturMemberCard({
    required this.member,
    required this.displayNo,
  });

  final StrukturMember member;
  final int displayNo;

  @override
  Widget build(BuildContext context) {
    final isTop = member.isTop;
    final isHigh = member.isHigh;
    final orderText = '#${displayNo.toString().padLeft(2, '0')}';
    final avatarSize = isTop ? 80.0 : 72.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: isTop
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
              )
            : isHigh
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Color(0xFFF0F9FF)],
                  )
                : null,
        color: (isTop || isHigh) ? null : Colors.white,
        border: Border.all(
          color: isTop
              ? const Color(0xFF3B82F6)
              : isHigh
                  ? const Color(0xFFBAE6FD)
                  : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: isTop
                ? const Color(0xFF1E3A8A).withValues(alpha: 0.25)
                : AppColors.navy.withValues(alpha: 0.05),
            blurRadius: isTop ? 28 : 16,
            offset: Offset(0, isTop ? 12 : 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Order Number Pill (Top-Right)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isTop
                    ? Colors.white.withValues(alpha: 0.14)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isTop
                      ? Colors.white.withValues(alpha: 0.24)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Text(
                orderText,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                  color:
                      isTop ? const Color(0xFFFDE68A) : const Color(0xFF94A3B8),
                ),
              ),
            ),
          ),
          Row(
            children: [
              // Portrait Photo Squircle
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: avatarSize,
                    height: avatarSize,
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isTop
                            ? const [Color(0xFFFBBF24), Color(0xFFF59E0B)]
                            : isHigh
                                ? const [Color(0xFF38BDF8), Color(0xFF2563EB)]
                                : const [Color(0xFFCBD5E1), Color(0xFF94A3B8)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.navy.withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(17.5),
                      child: Container(
                        color: const Color(0xFFE2E8F0),
                        child: member.image.isNotEmpty
                            ? Image.network(
                                member.image,
        headers: BtapiAuth.imageHeaders(member.image),
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                                errorBuilder: (_, __, ___) => Image.asset(
                                  'assets/img/default-avatar.png',
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Image.asset(
                                'assets/img/default-avatar.png',
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                  ),
                  if (isTop || isHigh)
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isTop
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF2563EB),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  const Color(0xFF2563EB).withValues(alpha: 0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Icon(
                          isTop
                              ? Icons.star_rounded
                              : Icons.workspace_premium_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              // Member Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: isTop
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFFFEF3C7),
                                    Color(0xFFFDE68A),
                                  ],
                                )
                              : isHigh
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFFDBEAFE),
                                        Color(0xFFBAE6FD),
                                      ],
                                    )
                                  : null,
                          color: (isTop || isHigh)
                              ? null
                              : const Color(0xFFEFF6FF),
                        ),
                        child: Text(
                          member.cleanedJob.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: isTop
                                ? const Color(0xFFB45309)
                                : isHigh
                                    ? const Color(0xFF0369A1)
                                    : const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        member.nama,
                        style: TextStyle(
                          fontSize: isTop ? 17 : 15.5,
                          fontWeight: FontWeight.w800,
                          color: isTop ? Colors.white : AppColors.navy,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: isTop
                                ? const Color(0xFF38BDF8)
                                : const Color(0xFF0284C7),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'SP LEM SPSI · PT. TMMIN',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: isTop
                                    ? const Color(0xFFCBD5E1)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StrukturStateBox extends StatelessWidget {
  const _StrukturStateBox({
    required this.isLoading,
    required this.title,
    required this.subtitle,
  });

  final bool isLoading;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        children: [
          if (isLoading)
            const CircularProgressIndicator()
          else
            const Icon(
              Icons.search_off_rounded,
              size: 40,
              color: Color(0xFF94A3B8),
            ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.8,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
