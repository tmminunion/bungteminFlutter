import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/proker_item.dart';

/// Halaman Program Kerja (Proker) — migrasi dari `bungteminAPP/src/app/proker/`.
class ProkerScreen extends StatefulWidget {
  const ProkerScreen({
    super.key,
    this.initialBidang,
  });

  final List<BidangProker>? initialBidang;

  @override
  State<ProkerScreen> createState() => _ProkerScreenState();
}

class _ProkerScreenState extends State<ProkerScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  List<BidangProker> get _allBidang =>
      widget.initialBidang ?? BidangProker.defaults;

  List<BidangProker> get _filtered => BidangProker.filter(_allBidang, _query);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() => _query = '');
  }

  void _openDetail(BidangProker item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProkerDetailSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                _ProkerHeroHeader(
                  totalBidang: _allBidang.length,
                  onBack: () => Navigator.of(context).pop(),
                ),
                Transform.translate(
                  offset: const Offset(0, -34),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: _SearchGlassCard(
                          controller: _searchCtrl,
                          query: _query,
                          onChanged: (val) => setState(() => _query = val),
                          onClear: _clearSearch,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (filtered.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: _EmptyProkerCard(onReset: _clearSearch),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                MediaQuery.of(context).padding.bottom + 28,
              ),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 880),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isTwoCol = constraints.maxWidth >= 660;
                        const gap = 14.0;
                        final cardWidth = isTwoCol
                            ? (constraints.maxWidth - gap) / 2
                            : constraints.maxWidth;

                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final item in filtered)
                              SizedBox(
                                width: cardWidth,
                                child: _BidangProkerCard(
                                  item: item,
                                  onTap: () => _openDetail(item),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProkerHeroHeader extends StatelessWidget {
  const _ProkerHeroHeader({
    required this.totalBidang,
    required this.onBack,
  });

  final int totalBidang;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E3A8A),
            Color(0xFF0284C7),
          ],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x330F172A),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        child: Stack(
          children: [
            Positioned(
              top: -55,
              right: -35,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.22),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: -35,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF10B981).withValues(alpha: 0.16),
                ),
              ),
            ),
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _DotGridPainter()),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(18, topPad + 14, 18, 56),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Material(
                        color: Colors.white.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(999),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: onBack,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22),
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
                                  'Beranda',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0xFF7DD3FC).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.layers_outlined,
                              size: 14,
                              color: Color(0xFFE0F2FE),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$totalBidang Bidang',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFE0F2FE),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
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
                          'assets/icon/6.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.assignment_turned_in_rounded,
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
                              'PUK SP LEM SPSI • TMMIN',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: Color(0xFF7DD3FC),
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Program Kerja',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Pilar kerja & layanan prioritas setiap bidang organisasi',
                              style: TextStyle(
                                fontSize: 12.2,
                                color: Color(0xE0E2E8F0),
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
      ),
    );
  }
}

class _SearchGlassCard extends StatelessWidget {
  const _SearchGlassCard({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            color: AppColors.primaryBlue,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
              decoration: const InputDecoration(
                hintText: 'Cari bidang atau fokus program...',
                hintStyle: TextStyle(
                  fontSize: 13.5,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
          if (query.isNotEmpty)
            IconButton(
              onPressed: onClear,
              tooltip: 'Bersihkan pencarian',
              icon: const Icon(
                Icons.cancel_rounded,
                size: 19,
                color: AppColors.muted,
              ),
            ),
        ],
      ),
    );
  }
}

class _BidangProkerCard extends StatelessWidget {
  const _BidangProkerCard({
    required this.item,
    required this.onTap,
  });

  final BidangProker item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D0F172A),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(21)),
                child: SizedBox(
                  height: 138,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _BidangBannerImage(item: item),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x140F172A),
                              Color(0xB80F172A),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: item.accent,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            item.formattedBadge,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Divisi Kerja PUK',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.muted,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Bidang ${item.bidang}',
                                style: const TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.navy,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: item.accent.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: item.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.tagline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.6,
                        height: 1.45,
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.only(top: 10),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFFF1F5F9)),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.done_all_rounded,
                                  size: 15,
                                  color: item.accent,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    '${item.programList.length} Program Prioritas',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Lihat Detail',
                            style: TextStyle(
                              fontSize: 11.8,
                              fontWeight: FontWeight.w800,
                              color: item.accent,
                            ),
                          ),
                        ],
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

class _BidangBannerImage extends StatelessWidget {
  const _BidangBannerImage({required this.item});

  final BidangProker item;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      item.imageAsset,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.navy,
                item.accent,
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -12,
                bottom: -14,
                child: Icon(
                  item.icon,
                  size: 104,
                  color: Colors.white.withValues(alpha: 0.16),
                ),
              ),
              Center(
                child: Icon(
                  item.icon,
                  size: 42,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyProkerCard extends StatelessWidget {
  const _EmptyProkerCard({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 28,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Bidang Tidak Ditemukan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Coba gunakan kata kunci lain seperti Pendidikan, HIPP, atau Advokasi.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.8,
              color: AppColors.muted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('Tampilkan Semua Bidang'),
          ),
        ],
      ),
    );
  }
}

class _ProkerDetailSheet extends StatelessWidget {
  const _ProkerDetailSheet({required this.item});

  final BidangProker item;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.48,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: EdgeInsets.fromLTRB(18, 0, 18, bottomPad + 24),
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        height: 170,
                        width: double.infinity,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _BidangBannerImage(item: item),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0x260F172A),
                                    Color(0xD90F172A),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: IconButton.filled(
                                onPressed: () => Navigator.of(context).pop(),
                                style: IconButton.styleFrom(
                                  backgroundColor:
                                      Colors.black.withValues(alpha: 0.45),
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.close_rounded, size: 20),
                              ),
                            ),
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: 14,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: item.accent,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      item.formattedBadge,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Bidang ${item.bidang}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: item.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: item.accent.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        item.tagline,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Fokus Program Kerja',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (var i = 0; i < item.programList.length; i++) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: item.accent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.programList[i],
                                style: const TextStyle(
                                  fontSize: 13.2,
                                  height: 1.48,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;

    const spacing = 20.0;
    for (double y = 10; y < size.height; y += spacing) {
      for (double x = 10; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
