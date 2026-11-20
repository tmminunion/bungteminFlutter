import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/session_store.dart';
import '../../models/training_item.dart';

class PintarBukuScreen extends StatefulWidget {
  const PintarBukuScreen({super.key});

  @override
  State<PintarBukuScreen> createState() => _PintarBukuScreenState();
}

class _PintarBukuScreenState extends State<PintarBukuScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final List<BukuPintarItem> _appPages = BukuPintarItem.defaults;
  List<BukuPintarItem> _filteredBooks = BukuPintarItem.defaults;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredBooks = List<BukuPintarItem>.from(_appPages);
      } else {
        _filteredBooks = _appPages
            .where(
              (b) =>
                  b.title.toLowerCase().contains(q) ||
                  b.sub.toLowerCase().contains(q) ||
                  b.desc.toLowerCase().contains(q),
            )
            .toList();
      }
    });
  }

  Future<void> _openBook(BukuPintarItem book) async {
    await SessionStore().saveReadBukuId(book.url);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BukuReaderScreen(initialBookUrl: book.url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: CustomScrollView(
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
                      _buildSearchCard(),
                      const SizedBox(height: 16),
                      if (_filteredBooks.isEmpty)
                        _buildEmptyCard()
                      else
                        Material(
                          color: Colors.white,
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              for (var i = 0; i < _filteredBooks.length; i++) ...[
                                if (i > 0)
                                  const Divider(
                                    height: 1,
                                    indent: 66,
                                    color: Color(0xFFF1F5F9),
                                  ),
                                _BookListTile(
                                  book: _filteredBooks[i],
                                  onTap: () => _openBook(_filteredBooks[i]),
                                ),
                              ],
                            ],
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
                      Icons.local_library_outlined,
                      size: 15,
                      color: Color(0xFFE0F2FE),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_appPages.length} Dokumen',
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
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
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
                    Icons.menu_book_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PUSTAKA DIGITAL ANGGOTA',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: Color(0xFF7DD3FC),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Buku Pintar SPSI',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Kumpulan undang-undang & referensi ketenagakerjaan offline',
                      style: TextStyle(
                        fontSize: 12.5,
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
    );
  }

  Widget _buildSearchCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 26,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => _applyFilter(),
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
              decoration: const InputDecoration(
                hintText: 'Cari nomor UU atau topik...',
                hintStyle: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          if (_searchCtrl.text.isNotEmpty)
            IconButton(
              onPressed: () {
                _searchCtrl.clear();
                _applyFilter();
              },
              icon: const Icon(
                Icons.cancel_rounded,
                size: 19,
                color: Color(0xFF94A3B8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.description_outlined,
            size: 38,
            color: Color(0xFF94A3B8),
          ),
          SizedBox(height: 8),
          Text(
            'Dokumen Tidak Ditemukan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Coba kata kunci lain seperti Ketenagakerjaan atau Serikat Pekerja.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _BookListTile extends StatelessWidget {
  const _BookListTile({required this.book, required this.onTap});

  final BukuPintarItem book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.description_outlined,
                size: 22,
                color: Color(0xFF1D4ED8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }
}

class BukuReaderScreen extends StatefulWidget {
  const BukuReaderScreen({
    super.key,
    this.initialBookUrl,
    this.paramId,
  });

  final String? initialBookUrl;
  final String? paramId;

  @override
  State<BukuReaderScreen> createState() => _BukuReaderScreenState();
}

class _BukuReaderScreenState extends State<BukuReaderScreen> {
  static const double _zoomStep = 0.25;
  static const double _defaultZoom = 1.0;

  String _src = 'assets/doc/1.pdf';
  double _pdfZoom = _defaultZoom;
  List<String> _pages = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initReader();
  }

  Future<void> _initReader() async {
    var resolvedSrc = widget.initialBookUrl ?? await SessionStore().loadReadBukuId();
    if (widget.paramId == '1' || widget.paramId == '2') {
      resolvedSrc = 'assets/doc/${widget.paramId}.pdf';
      await SessionStore().saveReadBukuId(resolvedSrc);
    }

    final jsonPath =
        resolvedSrc.contains('2.pdf') ? 'assets/doc/2.json' : 'assets/doc/1.json';
    List<String> loadedPages = const [];
    try {
      final raw = await rootBundle.loadString(jsonPath);
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['pages'] is List) {
        loadedPages =
            (decoded['pages'] as List).map((e) => e.toString()).toList();
      }
    } catch (_) {}

    if (loadedPages.isEmpty) {
      loadedPages = [
        resolvedSrc.contains('2.pdf')
            ? 'UNDANG-UNDANG REPUBLIK INDONESIA NOMOR 21 TAHUN 2000 TENTANG SERIKAT PEKERJA / SERIKAT BURUH'
            : 'UNDANG-UNDANG REPUBLIK INDONESIA NOMOR 13 TAHUN 2003 TENTANG KETENAGAKERJAAN',
      ];
    }

    if (!mounted) return;
    setState(() {
      _src = resolvedSrc;
      _pages = loadedPages;
      _loading = false;
    });
  }

  String get _docTitle {
    if (_src.contains('2.pdf')) {
      return 'UU No. 21 Tahun 2000 — Serikat Pekerja';
    }
    return 'UU No. 13 Tahun 2003 — Ketenagakerjaan';
  }

  void _zoomIn() {
    if (_pdfZoom < 2.5) {
      setState(() {
        _pdfZoom = double.parse((_pdfZoom + _zoomStep).toStringAsFixed(2));
      });
    }
  }

  void _zoomOut() {
    if (_pdfZoom > _defaultZoom) {
      setState(() {
        _pdfZoom = double.parse((_pdfZoom - _zoomStep).toStringAsFixed(2));
      });
    }
  }

  void _resetZoom() {
    setState(() {
      _pdfZoom = _defaultZoom;
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final zoomPct = (_pdfZoom * 100).round();

    return Scaffold(
      backgroundColor: const Color(0xFF1E293B),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(14, topPad + 12, 14, 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xF50F172A), Color(0xF01E3A8A)],
                  ),
                  border: Border(
                    bottom: BorderSide(color: Color(0x24FFFFFF)),
                  ),
                ),
                child: Row(
                  children: [
                    Material(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: StadiumBorder(
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: InkWell(
                        customBorder: const StadiumBorder(),
                        onTap: () => Navigator.of(context).maybePop(),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 8,
                          ),
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
                                'Pintar',
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
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.description_outlined,
                              size: 16,
                              color: Color(0xFF7DD3FC),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _docTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFE2E8F0),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(10, 12, 10, 90),
                        itemCount: _pages.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, idx) {
                          return Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x59000000),
                                  blurRadius: 24,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _docTitle,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0284C7),
                                      ),
                                    ),
                                    Text(
                                      'Hal. ${idx + 1} / ${_pages.length}',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                SelectableText(
                                  _pages[idx],
                                  style: TextStyle(
                                    fontSize: 13.0 * _pdfZoom,
                                    height: 1.55,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xDC0F172A),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 26,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _HudCircleBtn(
                      icon: Icons.remove_rounded,
                      enabled: _pdfZoom > 1.0,
                      onTap: _zoomOut,
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 48,
                      child: Text(
                        '$zoomPct%',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _HudCircleBtn(
                      icon: Icons.add_rounded,
                      enabled: _pdfZoom < 2.5,
                      onTap: _zoomIn,
                    ),
                    const SizedBox(width: 6),
                    _HudCircleBtn(
                      icon: Icons.refresh_rounded,
                      enabled: true,
                      isReset: true,
                      onTap: _resetZoom,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HudCircleBtn extends StatelessWidget {
  const _HudCircleBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.isReset = false,
  });

  final IconData icon;
  final bool enabled;
  final bool isReset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.38,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isReset
                ? const Color(0xFF38BDF8).withValues(alpha: 0.24)
                : Colors.white.withValues(alpha: 0.14),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isReset ? const Color(0xFF7DD3FC) : Colors.white,
          ),
        ),
      ),
    );
  }
}
