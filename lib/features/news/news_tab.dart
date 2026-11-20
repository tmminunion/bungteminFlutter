import 'package:flutter/material.dart';

import '../../core/cached_image.dart';
import '../../core/theme.dart';
import '../../models/news_item.dart';
import '../../services/bungtemin_api.dart';
import '../about/contact_screen.dart';
import 'news_detail_screen.dart';

class NewsTab extends StatefulWidget {
  const NewsTab({
    super.key,
    this.initialSegment = 0,
    this.onBackHome,
  });

  final int initialSegment;
  final VoidCallback? onBackHome;

  @override
  State<NewsTab> createState() => _NewsTabState();
}

class _NewsTabState extends State<NewsTab> {
  final _api = BungteminApi();
  final _searchCtrl = TextEditingController();

  late int _activeSegment;
  bool _loading = true;
  String _query = '';
  List<NewsItem> _internal = const [];
  List<NewsItem> _external = const [];

  @override
  void initState() {
    super.initState();
    _activeSegment = widget.initialSegment;
    _loadCachedThenRefresh();
  }

  @override
  void didUpdateWidget(covariant NewsTab oldWidget) {
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

  Future<void> _loadCachedThenRefresh() async {
    final cached = await Future.wait([
      _api.loadCachedInternalNews(),
      _api.loadCachedExternalNews(),
    ]);
    if (!mounted) return;
    if (cached[0].isNotEmpty || cached[1].isNotEmpty) {
      setState(() {
        if (cached[0].isNotEmpty) _internal = cached[0];
        if (cached[1].isNotEmpty) _external = cached[1];
        _loading = false;
      });
    }
    await _loadNews();
  }

  Future<void> _loadNews() async {
    if (_internal.isEmpty && _external.isEmpty) {
      setState(() => _loading = true);
    }
    try {
      final results = await Future.wait([
        _api.fetchInternalNews(limit: 12),
        _api.fetchExternalNews(limit: 12),
      ]);
      if (!mounted) return;
      setState(() {
        if (results[0].isNotEmpty) _internal = results[0];
        if (results[1].isNotEmpty) _external = results[1];
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  List<NewsItem> get _filtered {
    final source = _activeSegment == 0 ? _internal : _external;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return source;
    return source.where((item) {
      return item.title.toLowerCase().contains(q) ||
          item.excerpt.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return Container(
      color: AppColors.surface,
      child: RefreshIndicator(
        onRefresh: _loadNews,
        child: CustomScrollView(
          slivers: [
            // Aurora Hero Header
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
                            _HeaderPillButton(
                              icon: Icons.support_agent_rounded,
                              label: 'Hubungi Kami',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const ContactScreen(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _HeaderIconButton(
                              icon: Icons.refresh_rounded,
                              onTap: _loadNews,
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
                          child: Image.asset('assets/icon/1.png'),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'KABAR & AGENDA RESMI',
                                style: TextStyle(
                                  color: Color(0xFF7DD3FC),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Berita Terkini',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Informasi resmi PUK SP LEM SPSI TMMIN & ketenagakerjaan',
                                style: TextStyle(
                                  color: Color(0xFFCBD5E1),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // Segment Switcher
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SegmentButton(
                              label: 'Internal (${_internal.length})',
                              active: _activeSegment == 0,
                              onTap: () => setState(() => _activeSegment = 0),
                            ),
                          ),
                          Expanded(
                            child: _SegmentButton(
                              label: 'Eksternal (${_external.length})',
                              active: _activeSegment == 1,
                              onTap: () => setState(() => _activeSegment = 1),
                            ),
                          ),
                        ],
                      ),
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
                      hintText: 'Cari judul atau topik berita...',
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

            if (_loading && items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
              )
            else if (items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.newspaper_rounded,
                          size: 48,
                          color: AppColors.muted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _activeSegment == 0
                              ? 'Belum Ada Berita Internal'
                              : 'Belum Ada Berita Eksternal',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tarik ke bawah untuk memuat ulang kabar terbaru.',
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
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                sliver: SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _NewsListCard(
                      item: item,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => NewsDetailScreen(item: item),
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

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: active ? AppColors.navy : Colors.white.withValues(alpha: 0.8),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _NewsListCard extends StatelessWidget {
  const _NewsListCard({required this.item, required this.onTap});

  final NewsItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final badgeColor =
        item.isInternal ? AppColors.primaryBlue : AppColors.indigo;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 156,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (item.imageUrl.isNotEmpty)
                      BungteminCachedImage(
                        imageUrl: item.imageUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 720,
                        placeholder: _NewsThumbFallback(
                          isInternal: item.isInternal,
                        ),
                        errorWidget: _NewsThumbFallback(
                          isInternal: item.isInternal,
                        ),
                      )
                    else
                      _NewsThumbFallback(isInternal: item.isInternal),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          item.isInternal ? 'Resmi' : 'Eksternal',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 13,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          item.displayDate,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                        height: 1.3,
                      ),
                    ),
                    if (item.excerpt.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.excerpt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.muted,
                          height: 1.45,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'Baca Selengkapnya',
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 15,
                          color: badgeColor,
                        ),
                      ],
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

class _NewsThumbFallback extends StatelessWidget {
  const _NewsThumbFallback({required this.isInternal});

  final bool isInternal;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isInternal
              ? const [Color(0xFF1E3A8A), Color(0xFF2563EB)]
              : const [Color(0xFF312E81), Color(0xFF6366F1)],
        ),
      ),
      child: Center(
        child: Image.asset('assets/icon/1.png', width: 52, height: 52),
      ),
    );
  }
}
