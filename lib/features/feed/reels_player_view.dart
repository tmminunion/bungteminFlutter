import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../core/cached_image.dart';
import '../../core/session_store.dart';
import '../../services/bungtemin_api.dart';
import '../../core/net/btapi_auth.dart';

class ReelsPlayerView extends StatefulWidget {
  const ReelsPlayerView({
    super.key,
    required this.reels,
    required this.api,
    required this.session,
    required this.onRefresh,
    required this.onRequireLogin,
    required this.onReelDeleted,
  });

  final List<Map<String, dynamic>> reels;
  final BungteminApi api;
  final UserSession? session;
  final Future<void> Function() onRefresh;
  final void Function(String reason, VoidCallback afterLogin) onRequireLogin;
  final void Function(String id) onReelDeleted;

  @override
  State<ReelsPlayerView> createState() => _ReelsPlayerViewState();
}

class _ReelsPlayerViewState extends State<ReelsPlayerView> {
  final PageController _pageController = PageController();
  int _activeIndex = 0;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _precacheAround(0);
  }

  void _precacheAround(int index) {
    if (kIsWeb || widget.reels.isEmpty) return;
    for (final targetIdx in [index, index + 1]) {
      if (targetIdx < 0 || targetIdx >= widget.reels.length) continue;
      final r = widget.reels[targetIdx];
      final type = (r['mediaType'] ?? 'video').toString().toLowerCase();
      if (type == 'image') continue;
      final url = (r['mediaUrl'] ?? r['video_url'] ?? r['url'] ?? '').toString().trim();
      if (url.startsWith('http://') || url.startsWith('https://')) {
        unawaited(BungteminReelCache.precache(url));
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reels.isEmpty) {
      return ColoredBox(
        color: const Color(0xFF070D1B),
        child: RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: ListView(
            padding: const EdgeInsets.all(28),
            children: const [
              SizedBox(height: 90),
              Icon(
                Icons.movie_creation_outlined,
                size: 56,
                color: Color(0xFF38BDF8),
              ),
              SizedBox(height: 14),
              Text(
                'Belum Ada Reels Aktif',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Tap tombol + di bawah untuk mengunggah video singkat ke komunitas Bungtemin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ColoredBox(
      color: const Color(0xFF070D1B),
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.reels.length,
        onPageChanged: (index) {
          setState(() => _activeIndex = index);
          _precacheAround(index);
        },
        itemBuilder: (context, index) {
          final reel = widget.reels[index];
          final id = (reel['id'] ?? reel['\$id'] ?? index).toString();
          return _ReelPageItem(
            key: ValueKey('reel_$id'),
            reel: reel,
            isActive: index == _activeIndex,
            isMuted: _isMuted,
            api: widget.api,
            session: widget.session,
            onToggleMute: () => setState(() => _isMuted = !_isMuted),
            onRequireLogin: widget.onRequireLogin,
            onDeleted: () => widget.onReelDeleted(id),
          );
        },
      ),
    );
  }
}

class _ReelPageItem extends StatefulWidget {
  const _ReelPageItem({
    super.key,
    required this.reel,
    required this.isActive,
    required this.isMuted,
    required this.api,
    required this.session,
    required this.onToggleMute,
    required this.onRequireLogin,
    required this.onDeleted,
  });

  final Map<String, dynamic> reel;
  final bool isActive;
  final bool isMuted;
  final BungteminApi api;
  final UserSession? session;
  final VoidCallback onToggleMute;
  final void Function(String reason, VoidCallback afterLogin) onRequireLogin;
  final VoidCallback onDeleted;

  @override
  State<_ReelPageItem> createState() => _ReelPageItemState();
}

class _ReelPageItemState extends State<_ReelPageItem> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;
  bool _showPlayPauseBadge = false;
  bool _viewCounted = false;
  Timer? _badgeTimer;

  late List<String> _likes;
  late int _views;
  bool _saved = false;

  String get _docId =>
      (widget.reel['id'] ?? widget.reel['\$id'] ?? '').toString().trim();

  String get _mediaType =>
      (widget.reel['mediaType'] ?? 'video').toString().toLowerCase() == 'image'
          ? 'image'
          : 'video';

  String get _mediaUrl =>
      (widget.reel['mediaUrl'] ??
              widget.reel['video_url'] ??
              widget.reel['url'] ??
              '')
          .toString()
          .trim();

  String get _thumbUrl {
    final direct = (widget.reel['thumb_url'] ?? '').toString().trim();
    if (direct.startsWith('http://') || direct.startsWith('https://')) {
      return direct;
    }
    final tid = (widget.reel['thumb_id'] ?? '').toString().trim();
    if (tid.startsWith('http://') || tid.startsWith('https://')) {
      return tid;
    }
    if (tid.isNotEmpty) {
      return 'https://bungtemin.net/btapi/Media/stream/reels/${Uri.encodeComponent(tid)}';
    }
    return '';
  }

  Future<void> _loadSaved() async {
    if (_docId.isEmpty) return;
    final ids = await SessionStore().loadSavedReelIds();
    if (!mounted) return;
    setState(() => _saved = ids.contains(_docId));
  }

  Future<void> _toggleSaved() async {
    final id = _docId;
    if (id.isEmpty) return;
    final store = SessionStore();
    final ids = await store.loadSavedReelIds();
    final nowSaved = !ids.contains(id);
    if (nowSaved) {
      ids.add(id);
    } else {
      ids.remove(id);
    }
    await store.saveSavedReelIds(ids);
    if (!mounted) return;
    setState(() => _saved = nowSaved);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1400),
          content: Text(
            nowSaved ? 'Reels disimpan ke Tersimpan' : 'Dihapus dari Tersimpan',
          ),
        ),
      );
  }

  @override
  void initState() {
    super.initState();
    final rawLikes = widget.reel['likes'];
    _likes = rawLikes is List
        ? rawLikes.map((e) => e.toString()).toList()
        : <String>[];
    _views = int.tryParse((widget.reel['views'] ?? 0).toString()) ?? 0;
    _loadSaved();

    if (_mediaType == 'video' && _mediaUrl.isNotEmpty) {
      _initVideo();
    } else if (_mediaType == 'image' && widget.isActive) {
      _trackViewOnce();
    }
  }

  Future<void> _initVideo() async {
    final uri = Uri.tryParse(_mediaUrl);
    if (uri == null) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    final cached = await BungteminReelCache.getCachedFile(_mediaUrl);
    final controller = cached != null
        ? VideoPlayerController.file(cached.file)
        : VideoPlayerController.networkUrl(uri);
    if (cached == null) {
      unawaited(BungteminReelCache.precache(_mediaUrl));
    }
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(widget.isMuted ? 0.0 : 1.0);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _initialized = true);
      if (widget.isActive) {
        await controller.play();
        _trackViewOnce();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  @override
  void didUpdateWidget(covariant _ReelPageItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controller = _controller;
    if (controller == null || !_initialized) return;

    if (widget.isMuted != oldWidget.isMuted) {
      controller.setVolume(widget.isMuted ? 0.0 : 1.0);
    }

    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        controller.play();
        _trackViewOnce();
      } else {
        controller.pause();
      }
    }
  }

  Future<void> _trackViewOnce() async {
    if (_viewCounted || _docId.isEmpty) return;
    _viewCounted = true;
    final updated = await widget.api.incrementReelView(_docId);
    if (updated != null && mounted) {
      setState(() => _views = updated);
    }
  }

  void _togglePlayPause() {
    final controller = _controller;
    if (controller == null || !_initialized) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    _badgeTimer?.cancel();
    setState(() => _showPlayPauseBadge = true);
    _badgeTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _showPlayPauseBadge = false);
    });
  }

  Future<void> _handleLike() async {
    final session = widget.session;
    if (session == null) {
      widget.onRequireLogin(
        'Masuk terlebih dahulu untuk menyukai Reels ini.',
        _handleLike,
      );
      return;
    }
    if (_docId.isEmpty) return;

    final userNoreg = SessionStore.formatNoreg8(session.noreg);
    final alreadyLiked = _likes.contains(userNoreg);
    setState(() {
      if (alreadyLiked) {
        _likes.remove(userNoreg);
      } else {
        _likes.add(userNoreg);
      }
    });

    final serverLikes = await widget.api.toggleReelLike(
      id: _docId,
      noreg: userNoreg,
    );
    if (serverLikes != null && mounted) {
      setState(() => _likes = serverLikes);
    }
  }

  Future<void> _handleDelete() async {
    if (_docId.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Reels'),
        content: const Text('Yakin ingin menghapus video Reels ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final deleted = await widget.api.deleteReel(_docId);
    if (deleted && mounted) {
      widget.onDeleted();
    }
  }

  @override
  void dispose() {
    _badgeTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nama = (widget.reel['nama'] ?? 'Anggota').toString().trim();
    final text = (widget.reel['text'] ?? '').toString().trim();
    final ownerNoreg = SessionStore.formatNoreg8(
      (widget.reel['noreg'] ?? '').toString(),
    );
    final currentNoreg = widget.session != null
        ? SessionStore.formatNoreg8(widget.session!.noreg)
        : '';
    final isOwner = currentNoreg.isNotEmpty && currentNoreg == ownerNoreg;
    final canDelete = isOwner || (widget.session?.isModeratorOrPuk ?? false);
    final isLiked = currentNoreg.isNotEmpty && _likes.contains(currentNoreg);
    final avatarUrl = (widget.reel['avatar'] ?? '').toString().trim().isNotEmpty
        ? widget.reel['avatar'].toString().trim()
        : (ownerNoreg.isNotEmpty
            ? 'https://bungtemin.net/btapi/Calendar/hravatar/$ownerNoreg'
            : '');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _mediaType == 'video' ? _togglePlayPause : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          if (_mediaType == 'image' && _mediaUrl.isNotEmpty)
            Image.network(
              _mediaUrl,
        headers: BtapiAuth.imageHeaders(_mediaUrl),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 48,
                ),
              ),
            )
          else if (_initialized && _controller != null)
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: _controller!.value.size.width > 0
                    ? _controller!.value.size.width
                    : 720,
                height: _controller!.value.size.height > 0
                    ? _controller!.value.size.height
                    : 1280,
                child: VideoPlayer(_controller!),
              ),
            )
          else ...[
            if (_thumbUrl.isNotEmpty)
              Image.network(
                _thumbUrl,
        headers: BtapiAuth.imageHeaders(_thumbUrl),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            Center(
              child: _hasError
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.videocam_off_rounded,
                          color: Colors.white70,
                          size: 46,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Video gagal dimuat',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: () {
                            setState(() => _hasError = false);
                            _initVideo();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                          ),
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    )
                  : const CircularProgressIndicator(
                      color: Color(0xFF38BDF8),
                    ),
            ),
          ],

          // Progress bar tipis di atas (sesuai reels.page.scss)
          if (_mediaType == 'video' && _initialized && _controller != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: _controller!,
                builder: (_, val, __) {
                  final totalMs = val.duration.inMilliseconds;
                  final posMs = val.position.inMilliseconds;
                  final progress =
                      totalMs > 0 ? (posMs / totalMs).clamp(0.0, 1.0) : 0.0;
                  return LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF38BDF8),
                    ),
                  );
                },
              ),
            ),

          // Indikator Play/Pause saat tap layar
          if (_showPlayPauseBadge && _controller != null)
            Center(
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.52),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _controller!.value.isPlaying
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),

          // Overlay gradient bawah + info user + side actions
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 40, 14, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Color(0xE6070D1B),
                    Color(0x73070D1B),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '@${nama.isEmpty ? 'Anggota' : nama}',
                          style: const TextStyle(
                            color: Color(0xFF7DD3FC),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (text.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            text,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFF1F5F9),
                              fontSize: 13.5,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_mediaType == 'video') ...[
                        _GlassActionPill(
                          icon: widget.isMuted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          label: widget.isMuted ? 'Bisukan' : 'Suara',
                          onTap: widget.onToggleMute,
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (canDelete) ...[
                        _GlassActionPill(
                          icon: Icons.delete_outline_rounded,
                          iconColor: const Color(0xFFF87171),
                          label: 'Hapus',
                          onTap: _handleDelete,
                        ),
                        const SizedBox(height: 12),
                      ],
                      _GlassActionPill(
                        icon: isLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        iconColor:
                            isLiked ? const Color(0xFFFB7185) : Colors.white,
                        label: '${_likes.length}',
                        onTap: _handleLike,
                      ),
                      const SizedBox(height: 12),
                      _GlassActionPill(
                        icon: Icons.visibility_outlined,
                        label: '$_views',
                      ),
                      const SizedBox(height: 12),
                      _GlassActionPill(
                        icon: _saved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        iconColor:
                            _saved ? const Color(0xFF38BDF8) : Colors.white,
                        label: _saved ? 'Tersimpan' : 'Simpan',
                        onTap: _toggleSaved,
                      ),
                      const SizedBox(height: 12),
                      _GlassActionPill(
                        icon: Icons.share_rounded,
                        label: 'Bagikan',
                        onTap: () {
                          final caption = text.isNotEmpty ? '"$text"\n\n' : '';
                          final msg = 'Reels dari *$nama* di Bungtemin:\n$caption$_mediaUrl';
                          launchUrl(
                            Uri.parse('https://wa.me/?text=${Uri.encodeComponent(msg)}'),
                            mode: LaunchMode.externalApplication,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: 44,
                        height: 44,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF38BDF8), Color(0xFF6366F1)],
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: avatarUrl.isNotEmpty
                              ? Image.network(
                                  avatarUrl,
        headers: BtapiAuth.imageHeaders(avatarUrl),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const ColoredBox(
                                    color: Color(0xFF1E293B),
                                    child: Icon(
                                      Icons.person_rounded,
                                      color: Colors.white70,
                                    ),
                                  ),
                                )
                              : const ColoredBox(
                                  color: Color(0xFF1E293B),
                                  child: Icon(
                                    Icons.person_rounded,
                                    color: Colors.white70,
                                  ),
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
    );
  }
}

class _GlassActionPill extends StatelessWidget {
  const _GlassActionPill({
    required this.icon,
    required this.label,
    this.iconColor = Colors.white,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const textShadow = [
      Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 1)),
    ];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 28, shadows: textShadow),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                shadows: textShadow,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
