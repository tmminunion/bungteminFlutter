import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/cached_image.dart';
import '../../core/session_store.dart';
import '../../core/theme.dart';
import '../../models/meeting_item.dart';
import '../../services/bungtemin_api.dart';

class IgFeedView extends StatefulWidget {
  const IgFeedView({
    super.key,
    required this.stories,
    required this.api,
    required this.session,
    required this.onRefresh,
    required this.onCreateTap,
    required this.onRequireLogin,
    required this.onStoryDeleted,
  });

  final List<StoryItem> stories;
  final BungteminApi api;
  final UserSession? session;
  final Future<void> Function() onRefresh;
  final VoidCallback onCreateTap;
  final void Function(String reason, VoidCallback afterLogin) onRequireLogin;
  final ValueChanged<String> onStoryDeleted;

  @override
  State<IgFeedView> createState() => _IgFeedViewState();
}

class _IgFeedViewState extends State<IgFeedView> {
  final Map<String, List<String>> _likesOverride = <String, List<String>>{};
  final Map<String, int> _commentCountOverride = <String, int>{};
  final Set<String> _savedIds = <String>{};
  String? _heartOverlayId;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final ids = await SessionStore().loadSavedStoryIds();
    if (!mounted) return;
    setState(() {
      _savedIds
        ..clear()
        ..addAll(ids);
    });
  }

  Future<void> _toggleSaved(String id) async {
    setState(() {
      if (!_savedIds.add(id)) _savedIds.remove(id);
    });
    await SessionStore().saveSavedStoryIds(_savedIds);
  }

  List<String> _likesFor(StoryItem s) => _likesOverride[s.id] ?? s.likes;

  int _commentsCountFor(StoryItem s) =>
      _commentCountOverride[s.id] ?? s.commentsCount;

  Future<void> _toggleLike(StoryItem s, {bool forceLike = false}) async {
    final session = widget.session;
    if (session == null) {
      widget.onRequireLogin(
        'Masuk terlebih dahulu untuk menyukai postingan ini.',
        () => _toggleLike(s, forceLike: forceLike),
      );
      return;
    }

    final userNoreg = SessionStore.formatNoreg8(session.noreg);
    final current = List<String>.from(_likesFor(s));
    final alreadyLiked = current.contains(userNoreg);

    if (forceLike) {
      setState(() => _heartOverlayId = s.id);
      Future.delayed(const Duration(milliseconds: 650), () {
        if (mounted && _heartOverlayId == s.id) {
          setState(() => _heartOverlayId = null);
        }
      });
      if (alreadyLiked) return;
    }

    setState(() {
      if (alreadyLiked) {
        current.remove(userNoreg);
      } else {
        current.add(userNoreg);
      }
      _likesOverride[s.id] = current;
    });

    final serverLikes = await widget.api.toggleStoryLike(
      id: s.id,
      noreg: userNoreg,
    );
    if (serverLikes != null && mounted) {
      setState(() => _likesOverride[s.id] = serverLikes);
    }
  }

  Future<void> _shareToWhatsApp(StoryItem s) async {
    final caption = s.caption.isNotEmpty ? '"${s.caption}"\n\n' : '';
    final text =
        'Postingan dari *${s.nama}* di Linimasa Bungtemin:\n$caption${s.mediaUrl}';
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _deleteStory(StoryItem s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Postingan'),
        content: const Text('Yakin ingin menghapus foto cerita ini?'),
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

    final deleted = await widget.api.deleteStory(s.id);
    if (deleted && mounted) {
      widget.onStoryDeleted(s.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Postingan berhasil dihapus')),
      );
    }
  }

  Future<void> _openCommentsSheet(StoryItem s) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StoryCommentsSheet(
        story: s,
        api: widget.api,
        session: widget.session,
        onRequireLogin: widget.onRequireLogin,
        onCountChanged: (count) {
          if (mounted) {
            setState(() => _commentCountOverride[s.id] = count);
          }
        },
      ),
    );
  }

  void _openStoryPreview(StoryItem item) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF070D1B),
        insetPadding: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
                child: Row(
                  children: [
                    _StoryAvatar(noreg: item.noreg, size: 34),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.nama.isNotEmpty ? item.nama : 'Anggota TMMIN',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                          if (item.createdAt.isNotEmpty)
                            Text(
                              item.createdAt,
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),
              if (item.mediaUrl.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 440),
                  child: BungteminCachedImage(
                    imageUrl: item.mediaUrl,
                    fit: BoxFit.contain,
                    memCacheWidth: 1080,
                    errorWidget: const SizedBox(
                      height: 220,
                      child: Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white54,
                          size: 42,
                        ),
                      ),
                    ),
                  ),
                ),
              if (item.caption.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    item.caption,
                    style: const TextStyle(
                      color: Color(0xFFE2E8F0),
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentNoreg = widget.session != null
        ? SessionStore.formatNoreg8(widget.session!.noreg)
        : '';

    if (widget.stories.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(
          padding: const EdgeInsets.all(28),
          children: [
            const SizedBox(height: 80),
            const Icon(Icons.photo_camera_outlined, size: 54, color: AppColors.muted),
            const SizedBox(height: 12),
            const Text(
              'Belum Ada Postingan Linimasa',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Bagikan foto kegiatan pertama Anda ke komunitas Bungtemin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            Center(
              child: FilledButton.icon(
                onPressed: widget.onCreateTap,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Buat Postingan'),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: widget.stories.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _IgStoriesBar(
              stories: widget.stories,
              onCreateTap: widget.onCreateTap,
              onStoryTap: _openStoryPreview,
            );
          }

          final s = widget.stories[index - 1];
          final likes = _likesFor(s);
          final isLiked = currentNoreg.isNotEmpty && likes.contains(currentNoreg);
          final commentsCount = _commentsCountFor(s);
          final isSaved = _savedIds.contains(s.id);
          final showHeart = _heartOverlayId == s.id;
          final displayName = s.nama.isNotEmpty ? s.nama : 'Anggota TMMIN';
          final ownerNoreg = SessionStore.formatNoreg8(s.noreg);
          final isOwner = currentNoreg.isNotEmpty && currentNoreg == ownerNoreg;
          final canDelete = isOwner || (widget.session?.isModeratorOrPuk ?? false);

          return Container(
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                  child: Row(
                    children: [
                      _StoryAvatar(noreg: s.noreg, size: 36, hasRing: true),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: AppColors.navy,
                              ),
                            ),
                            if (s.createdAt.isNotEmpty)
                              Text(
                                s.createdAt,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_horiz_rounded,
                          color: AppColors.navySoft,
                        ),
                        onSelected: (val) {
                          if (val == 'share') _shareToWhatsApp(s);
                          if (val == 'delete') _deleteStory(s);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'share',
                            child: Text('Bagikan ke WhatsApp'),
                          ),
                          if (canDelete)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                'Hapus Postingan',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (s.mediaUrl.isNotEmpty)
                  GestureDetector(
                    onDoubleTap: () => _toggleLike(s, forceLike: true),
                    onTap: () => _openStoryPreview(s),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            color: const Color(0xFFF1F5F9),
                            child: BungteminCachedImage(
                              imageUrl: s.mediaUrl,
                              fit: BoxFit.cover,
                              memCacheWidth: 1080,
                              placeholder: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              errorWidget: const ColoredBox(
                                color: AppColors.navySoft,
                                child: Center(
                                  child: Icon(
                                    Icons.image_not_supported_outlined,
                                    color: Colors.white54,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (showHeart)
                            const Center(
                              child: Icon(
                                Icons.favorite_rounded,
                                color: Colors.white,
                                size: 84,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 2),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => _toggleLike(s),
                        icon: Icon(
                          isLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: isLiked
                              ? const Color(0xFFE11D48)
                              : AppColors.navy,
                          size: 25,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _openCommentsSheet(s),
                        icon: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: AppColors.navy,
                          size: 22,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _shareToWhatsApp(s),
                        icon: const Icon(
                          Icons.send_rounded,
                          color: AppColors.navy,
                          size: 21,
                        ),
                        tooltip: 'Bagikan ke WhatsApp',
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => _toggleSaved(s.id),
                        icon: Icon(
                          isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: AppColors.navy,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (likes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '${likes.length} suka',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                      if (s.caption.isNotEmpty)
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '$displayName ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navy,
                                ),
                              ),
                              TextSpan(
                                text: s.caption,
                                style: const TextStyle(
                                  color: AppColors.navySoft,
                                ),
                              ),
                            ],
                          ),
                          style: const TextStyle(fontSize: 13.5, height: 1.4),
                        ),
                      if (commentsCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: GestureDetector(
                            onTap: () => _openCommentsSheet(s),
                            child: Text(
                              'Lihat semua $commentsCount komentar',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StoryCommentsSheet extends StatefulWidget {
  const _StoryCommentsSheet({
    required this.story,
    required this.api,
    required this.session,
    required this.onRequireLogin,
    required this.onCountChanged,
  });

  final StoryItem story;
  final BungteminApi api;
  final UserSession? session;
  final void Function(String reason, VoidCallback afterLogin) onRequireLogin;
  final ValueChanged<int> onCountChanged;

  @override
  State<_StoryCommentsSheet> createState() => _StoryCommentsSheetState();
}

class _StoryCommentsSheetState extends State<_StoryCommentsSheet> {
  final _ctrl = TextEditingController();
  bool _loading = true;
  bool _sending = false;
  List<Map<String, dynamic>> _comments = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await widget.api.fetchStoryComments(widget.story.id);
    if (!mounted) return;
    setState(() {
      _comments = list;
      _loading = false;
    });
    widget.onCountChanged(list.length);
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;

    final session = widget.session;
    if (session == null) {
      Navigator.pop(context);
      widget.onRequireLogin(
        'Masuk terlebih dahulu untuk menulis komentar.',
        () {},
      );
      return;
    }

    setState(() => _sending = true);
    final added = await widget.api.addStoryComment(
      id: widget.story.id,
      noreg: session.noreg,
      nama: session.nama,
      comment: text,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (added != null) {
      _ctrl.clear();
      setState(() => _comments = [..._comments, added]);
      widget.onCountChanged(_comments.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Komentar',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? const Center(
                        child: Text(
                          'Belum ada komentar. Jadilah yang pertama!',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(14),
                        itemCount: _comments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, idx) {
                          final c = _comments[idx];
                          final nama = (c['nama'] ?? 'Anggota').toString();
                          final noreg = (c['noreg'] ?? '').toString();
                          final comment = (c['comment'] ?? '').toString();
                          final time = (c['created_at'] ?? '').toString();
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _StoryAvatar(noreg: noreg, size: 34),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: '$nama ',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.navy,
                                            ),
                                          ),
                                          TextSpan(
                                            text: comment,
                                            style: const TextStyle(
                                              color: AppColors.navySoft,
                                            ),
                                          ),
                                        ],
                                      ),
                                      style: const TextStyle(fontSize: 13.5),
                                    ),
                                    if (time.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 3),
                                        child: Text(
                                          time,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.muted,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(
              14,
              8,
              10,
              MediaQuery.of(context).padding.bottom + 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: const InputDecoration(
                      hintText: 'Tulis komentar...',
                      border: InputBorder.none,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                IconButton(
                  onPressed: _sending ? null : _submit,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: AppColors.primaryBlue,
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

class _IgStoriesBar extends StatelessWidget {
  const _IgStoriesBar({
    required this.stories,
    required this.onCreateTap,
    required this.onStoryTap,
  });

  final List<StoryItem> stories;
  final VoidCallback onCreateTap;
  final ValueChanged<StoryItem> onStoryTap;

  @override
  Widget build(BuildContext context) {
    final previewItems = stories.take(12).toList();
    return Container(
      height: 108,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: previewItems.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, idx) {
          if (idx == 0) {
            return GestureDetector(
              onTap: onCreateTap,
              child: SizedBox(
                width: 66,
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFEFF6FF),
                        border: Border.all(
                          color: AppColors.primaryBlue.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: AppColors.primaryBlue,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Cerita Anda',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: AppColors.navySoft),
                    ),
                  ],
                ),
              ),
            );
          }

          final item = previewItems[idx - 1];
          return GestureDetector(
            onTap: () => onStoryTap(item),
            child: SizedBox(
              width: 66,
              child: Column(
                children: [
                  _StoryAvatar(noreg: item.noreg, size: 60, hasRing: true),
                  const SizedBox(height: 5),
                  Text(
                    item.nama.isNotEmpty ? item.nama : 'Anggota',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppColors.navy),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StoryAvatar extends StatelessWidget {
  const _StoryAvatar({
    required this.noreg,
    required this.size,
    this.hasRing = false,
  });

  final String noreg;
  final double size;
  final bool hasRing;

  @override
  Widget build(BuildContext context) {
    final cleanNoreg = SessionStore.formatNoreg8(noreg);
    final url = cleanNoreg.isNotEmpty && cleanNoreg != '00000000'
        ? 'https://bungtemin.net/btapi/Calendar/hravatar/$cleanNoreg'
        : '';

    final inner = ClipOval(
      child: url.isNotEmpty
          ? BungteminCachedImage(
              imageUrl: url,
              width: size - (hasRing ? 6 : 0),
              height: size - (hasRing ? 6 : 0),
              fit: BoxFit.cover,
              memCacheWidth: 160,
              placeholder: _fallback(),
              errorWidget: _fallback(),
            )
          : _fallback(),
    );

    if (!hasRing) return inner;

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2.2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFFF59E0B),
            Color(0xFFEC4899),
            Color(0xFF6366F1),
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(1.5),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: inner,
      ),
    );
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      color: const Color(0xFFE2E8F0),
      child: Icon(
        Icons.person_rounded,
        size: size * 0.55,
        color: AppColors.navySoft,
      ),
    );
  }
}
