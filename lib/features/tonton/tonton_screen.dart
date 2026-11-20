import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../core/cached_image.dart';
import '../../core/theme.dart';
import '../../models/tonton_video.dart';
import '../../services/bungtemin_api.dart';

/// Tonton Bungtemin — Gaya UI YouTube Modern:
/// - Top bar YouTube style (icon merah play + wordmark Tonton, toggle search, refresh)
/// - Horizontal category chips (Semua, SPSI, Sarasehan, Mars, TMMIN, Tersimpan)
/// - Kartu video 16:9 full-bleed thumbnail + avatar channel + bookmark & share
/// - Halaman Watch Theater gelap (`TontonPlayerScreen`) dengan player 16:9 sticky,
///   action pills, deskripsi lipat, dan daftar Video Berikutnya (Up Next).
class TontonScreen extends StatefulWidget {
  const TontonScreen({
    super.key,
    this.initialVideos,
  });

  final List<TontonVideo>? initialVideos;

  @override
  State<TontonScreen> createState() => _TontonScreenState();
}

class _TontonScreenState extends State<TontonScreen> {
  static const _kCacheKey = 'bt_tonton_videos_v1';
  static const _kSavedKey = 'bt_tonton_saved_ids';
  static const Color _ytRed = Color(0xFFFF0033);

  final _api = BungteminApi();
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  bool _showSearch = false;
  String _selectedChip = 'Semua';
  String _query = '';
  List<TontonVideo> _videos = const [];
  Set<String> _savedIds = <String>{};

  static const _baseChips = [
    'Semua',
    'SPSI',
    'Sarasehan',
    'Mars',
    'TMMIN',
    'Tersimpan',
  ];

  @override
  void initState() {
    super.initState();
    _loadSaved();
    if (widget.initialVideos != null) {
      _videos = widget.initialVideos!;
      _loading = false;
    } else {
      _loadVideos();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kSavedKey) ?? const [];
    if (!mounted) return;
    setState(() => _savedIds = list.toSet());
  }

  Future<void> _toggleSave(TontonVideo video) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = Set<String>.from(_savedIds);
    final added = !updated.contains(video.videoId);
    if (added) {
      updated.add(video.videoId);
    } else {
      updated.remove(video.videoId);
    }
    await prefs.setStringList(_kSavedKey, updated.toList());
    if (!mounted) return;
    setState(() => _savedIds = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? 'Disimpan ke daftar Tonton Tersimpan'
              : 'Dihapus dari daftar Tersimpan',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _loadVideos({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCacheKey);
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            final cached = decoded
                .whereType<Map<String, dynamic>>()
                .map(TontonVideo.fromJson)
                .where((v) => v.videoId.isNotEmpty)
                .toList();
            if (cached.isNotEmpty && mounted) {
              setState(() {
                _videos = cached;
                _loading = false;
              });
            }
          }
        } catch (_) {}
      }
    }

    if (_videos.isEmpty || forceRefresh) {
      setState(() => _loading = true);
    }

    final fresh = await _api.fetchTontonVideos();
    if (!mounted) return;
    if (fresh.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kCacheKey,
        jsonEncode(
          fresh
              .map((v) => {
                    'id': v.id,
                    'playlist_id': v.videoId,
                    'title': v.title,
                    'content': v.description,
                    'category': v.category,
                    'channelTitle': v.channelTitle,
                  })
              .toList(),
        ),
      );
      setState(() {
        _videos = fresh;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  List<TontonVideo> get _filtered {
    final q = _query.trim().toLowerCase();
    return _videos.where((v) {
      final matchesSearch = q.isEmpty ||
          v.title.toLowerCase().contains(q) ||
          v.category.toLowerCase().contains(q) ||
          v.description.toLowerCase().contains(q);
      final matchesChip = switch (_selectedChip) {
        'Semua' => true,
        'Tersimpan' => _savedIds.contains(v.videoId),
        _ => v.title.toLowerCase().contains(_selectedChip.toLowerCase()) ||
            v.category.toLowerCase() == _selectedChip.toLowerCase(),
      };
      return matchesSearch && matchesChip;
    }).toList();
  }

  Future<void> _openPlayer(TontonVideo video) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TontonPlayerScreen(
          initialVideo: video,
          playlist: _videos,
          savedIds: _savedIds,
          onToggleSave: _toggleSave,
        ),
      ),
    );
    _loadSaved();
  }

  void _shareVideo(TontonVideo video) {
    Clipboard.setData(ClipboardData(text: video.youtubeUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tautan video YouTube disalin!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    const darkBg = Color(0xFF0B0F19);
    const darkSurface = Color(0xFF161D2F);
    const darkChip = Color(0xFF1E293B);
    const darkMuted = Color(0xFF94A3B8);

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: darkBg,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: _showSearch
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  hintText: 'Telusuri video Bungtemin...',
                  hintStyle: const TextStyle(color: darkMuted),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Colors.white70,
                          ),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                ),
              )
            : Row(
                children: [
                  Container(
                    width: 30,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _ytRed,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Tonton',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: darkSurface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: const Text(
                      'SPSI TV',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.auroraCyan,
                      ),
                    ),
                  ),
                ],
              ),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchCtrl.clear();
                  _query = '';
                }
              });
            },
            tooltip: _showSearch ? 'Tutup Pencarian' : 'Cari Video',
            icon: Icon(
              _showSearch ? Icons.close_rounded : Icons.search_rounded,
            ),
          ),
          IconButton(
            onPressed: () => _loadVideos(forceRefresh: true),
            tooltip: 'Muat Ulang',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          // YouTube-style Category Chips Strip (Dark Mode)
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              itemCount: _baseChips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, idx) {
                final chip = _baseChips[idx];
                final active = chip == _selectedChip;
                return GestureDetector(
                  onTap: () => setState(() => _selectedChip = chip),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: active ? Colors.white : darkChip,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: active
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (chip == 'Tersimpan') ...[
                          Icon(
                            Icons.bookmark_rounded,
                            size: 14,
                            color: active ? darkBg : Colors.white70,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          chip,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: active ? darkBg : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),

          // Feed Content
          Expanded(
            child: RefreshIndicator(
              color: AppColors.auroraCyan,
              backgroundColor: darkSurface,
              onRefresh: () => _loadVideos(forceRefresh: true),
              child: _loading && list.isEmpty
                  ? ListView.builder(
                      padding: const EdgeInsets.only(top: 8),
                      itemCount: 3,
                      itemBuilder: (_, __) => const _VideoSkeletonCard(),
                    )
                  : list.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 90),
                            const Icon(
                              Icons.ondemand_video_rounded,
                              size: 56,
                              color: darkMuted,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _selectedChip == 'Tersimpan'
                                  ? 'Belum Ada Video Tersimpan'
                                  : 'Video Tidak Ditemukan',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                'Pilih kategori "Semua" atau tarik ke bawah untuk memuat ulang galeri video.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: darkMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 28),
                          itemCount: list.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          itemBuilder: (_, idx) {
                            final video = list[idx];
                            final isSaved = _savedIds.contains(video.videoId);
                            return _YouTubeFeedCard(
                              video: video,
                              isFeatured: idx == 0 && _selectedChip == 'Semua',
                              isSaved: isSaved,
                              onTap: () => _openPlayer(video),
                              onToggleSave: () => _toggleSave(video),
                              onShare: () => _shareVideo(video),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _YouTubeFeedCard extends StatelessWidget {
  const _YouTubeFeedCard({
    required this.video,
    required this.isFeatured,
    required this.isSaved,
    required this.onTap,
    required this.onToggleSave,
    required this.onShare,
  });

  final TontonVideo video;
  final bool isFeatured;
  final bool isSaved;
  final VoidCallback onTap;
  final VoidCallback onToggleSave;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 16:9 Full-Bleed Thumbnail
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (video.thumbnailHq.isNotEmpty)
                  BungteminCachedImage(
                    imageUrl: video.thumbnailHq,
                    fit: BoxFit.cover,
                    memCacheWidth: 720,
                    placeholder: const _VideoThumbPlaceholder(),
                    errorWidget: const _VideoThumbPlaceholder(),
                  )
                else
                  const _VideoThumbPlaceholder(),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.35),
                      ],
                    ),
                  ),
                ),
                // Center Glass Play Button
                Center(
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.62),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
                // Top-left featured badge
                if (isFeatured)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF0033),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'TERBARU',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                // Bottom-right YouTube / category badge
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.play_circle_filled_rounded,
                          color: Color(0xFFFF0033),
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          video.category,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // YouTube Metadata Row (Avatar + Title/Channel + Actions)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 6, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1E293B),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/img/appicon.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${video.channelTitle} • ${video.category} • SPSI Stream',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onToggleSave,
                  visualDensity: VisualDensity.compact,
                  tooltip: isSaved ? 'Tersimpan' : 'Simpan Video',
                  icon: Icon(
                    isSaved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: isSaved ? AppColors.auroraCyan : const Color(0xFF94A3B8),
                    size: 20,
                  ),
                ),
                IconButton(
                  onPressed: onShare,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Bagikan Tautan',
                  icon: const Icon(
                    Icons.share_outlined,
                    color: Color(0xFF94A3B8),
                    size: 19,
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

class _VideoThumbPlaceholder extends StatelessWidget {
  const _VideoThumbPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, AppColors.navyMid],
        ),
      ),
      child: Center(
        child: Image.asset('assets/icon/13.png', width: 54, height: 54),
      ),
    );
  }
}

class _VideoSkeletonCard extends StatelessWidget {
  const _VideoSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(color: const Color(0xFF161D2F)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 16, 16),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 19,
                backgroundColor: Color(0xFF1E293B),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 11,
                      width: 160,
                      decoration: BoxDecoration(
                        color: const Color(0xFF161D2F),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Halaman Theater Watch ala YouTube Modern (Sticky 16:9 Player + Action Chips + Up Next)
class TontonPlayerScreen extends StatefulWidget {
  const TontonPlayerScreen({
    super.key,
    required this.initialVideo,
    required this.playlist,
    required this.savedIds,
    required this.onToggleSave,
  });

  final TontonVideo initialVideo;
  final List<TontonVideo> playlist;
  final Set<String> savedIds;
  final Future<void> Function(TontonVideo) onToggleSave;

  @override
  State<TontonPlayerScreen> createState() => _TontonPlayerScreenState();
}

class _TontonPlayerScreenState extends State<TontonPlayerScreen> {
  final _api = BungteminApi();
  late YoutubePlayerController _ytCtrl;
  late TontonVideo _active;
  late Set<String> _savedIds;
  bool _descExpanded = false;

  @override
  void initState() {
    super.initState();
    _active = widget.initialVideo;
    _savedIds = Set<String>.from(widget.savedIds);
    _ytCtrl = YoutubePlayerController.fromVideoId(
      videoId: _active.videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        enableCaption: true,
      ),
    );
    _enrichMetadata(_active);
  }

  @override
  void dispose() {
    _ytCtrl.close();
    super.dispose();
  }

  Future<void> _enrichMetadata(TontonVideo video) async {
    final meta = await _api.fetchYoutubeNoembed(video.videoId);
    if (!mounted || meta.isEmpty || _active.videoId != video.videoId) return;
    setState(() {
      _active = _active.copyWith(
        title: (meta['title']?.isNotEmpty ?? false) ? meta['title'] : null,
        channelTitle:
            (meta['author']?.isNotEmpty ?? false) ? meta['author'] : null,
      );
    });
  }

  void _switchVideo(TontonVideo next) {
    if (next.videoId == _active.videoId) return;
    setState(() {
      _active = next;
      _descExpanded = false;
    });
    _ytCtrl.loadVideoById(videoId: next.videoId);
    _enrichMetadata(next);
  }

  Future<void> _handleSave() async {
    await widget.onToggleSave(_active);
    if (!mounted) return;
    setState(() {
      if (_savedIds.contains(_active.videoId)) {
        _savedIds.remove(_active.videoId);
      } else {
        _savedIds.add(_active.videoId);
      }
    });
  }

  void _share() {
    Clipboard.setData(ClipboardData(text: _active.youtubeUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tautan video YouTube disalin.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openInYoutube() async {
    final uri = Uri.tryParse(_active.youtubeUrl);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaved = _savedIds.contains(_active.videoId);
    final upNext = widget.playlist
        .where((v) => v.videoId != _active.videoId)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Sticky Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 12, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    tooltip: 'Kembali ke Tonton',
                  ),
                  const Expanded(
                    child: Text(
                      'Tonton Bungtemin',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF0033).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFFFF0033).withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.sensors_rounded,
                          color: Color(0xFFFF4D6D),
                          size: 13,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Now Playing',
                          style: TextStyle(
                            color: Color(0xFFFFB3C1),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Sticky 16:9 YouTube Player
            YoutubePlayer(
              controller: _ytCtrl,
              aspectRatio: 16 / 9,
            ),

            // Scrollable Details & Up Next
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  14,
                  14,
                  14,
                  MediaQuery.of(context).padding.bottom + 24,
                ),
                children: [
                  Text(
                    _active.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_active.category} • Bungtemin Official Stream',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Channel Row
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF1E293B),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/img/appicon.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _active.channelTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Icon(
                                  Icons.verified_rounded,
                                  color: AppColors.auroraCyan,
                                  size: 15,
                                ),
                              ],
                            ),
                            const Text(
                              'PUK SP LEM SPSI PT. TMMIN',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Horizontal YouTube Action Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _TheaterActionPill(
                          icon: isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          label: isSaved ? 'Tersimpan' : 'Simpan',
                          highlighted: isSaved,
                          onTap: _handleSave,
                        ),
                        const SizedBox(width: 8),
                        _TheaterActionPill(
                          icon: Icons.share_outlined,
                          label: 'Bagikan',
                          onTap: _share,
                        ),
                        const SizedBox(width: 8),
                        _TheaterActionPill(
                          icon: Icons.open_in_new_rounded,
                          label: 'Buka YouTube',
                          onTap: _openInYoutube,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Collapsible Description Card
                  GestureDetector(
                    onTap: () => setState(() => _descExpanded = !_descExpanded),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161D2F),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Deskripsi Video',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                _descExpanded ? 'Ringkas' : 'Selengkapnya',
                                style: const TextStyle(
                                  color: AppColors.auroraCyan,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _active.description.isNotEmpty
                                ? _active.description
                                : 'Putar video dokumentasi dan edukasi resmi PUK SP LEM SPSI PT. TMMIN langsung di sini atau buka melalui YouTube.',
                            maxLines: _descExpanded ? null : 2,
                            overflow: _descExpanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 12.5,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (upNext.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Video Berikutnya',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final next in upNext)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => _switchVideo(next),
                          borderRadius: BorderRadius.circular(14),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 136,
                                  height: 76,
                                  child: BungteminCachedImage(
                                    imageUrl: next.thumbnailHq,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 320,
                                    placeholder:
                                        const _VideoThumbPlaceholder(),
                                    errorWidget:
                                        const _VideoThumbPlaceholder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      next.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${next.channelTitle} • ${next.category}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
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

class _TheaterActionPill extends StatelessWidget {
  const _TheaterActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: highlighted
              ? AppColors.primaryBlue.withValues(alpha: 0.25)
              : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: highlighted
                ? AppColors.auroraCyan.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: highlighted ? AppColors.auroraCyan : Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: highlighted ? AppColors.auroraCyan : Colors.white,
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
