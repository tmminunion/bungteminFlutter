import 'package:flutter/material.dart';

import '../../core/cached_image.dart';
import '../../core/session_store.dart';
import '../../core/theme.dart';
import '../../models/meeting_item.dart';

/// Tab "Profil" pada Cerita (Feed) dengan layout ala TikTok:
/// Avatar tengah, handle @noreg, statistik 3 kolom, tombol aksi,
/// tab ikon (Galeri, Reels, Tersimpan), dan grid 3 kolom rasio 3:4.
class MyFeedProfileView extends StatefulWidget {
  const MyFeedProfileView({
    super.key,
    required this.session,
    required this.stories,
    required this.reels,
    required this.onCreateTap,
    required this.onOpenReels,
  });

  final UserSession? session;
  final List<StoryItem> stories;
  final List<Map<String, dynamic>> reels;
  final VoidCallback onCreateTap;
  final VoidCallback onOpenReels;

  @override
  State<MyFeedProfileView> createState() => _MyFeedProfileViewState();
}

class _SavedEntry {
  const _SavedEntry({
    required this.id,
    required this.isReel,
    required this.nama,
    required this.caption,
    required this.imageUrl,
    required this.isVideo,
    this.likesCount = 0,
    this.canUnsave = false,
  });

  final String id;
  final bool isReel;
  final String nama;
  final String caption;
  final String imageUrl;
  final bool isVideo;
  final int likesCount;
  final bool canUnsave;
}

String _reelId(Map<String, dynamic> r) =>
    (r['id'] ?? r['\$id'] ?? '').toString().trim();

String _reelMediaUrl(Map<String, dynamic> r) =>
    (r['mediaUrl'] ?? r['video_url'] ?? r['url'] ?? '').toString().trim();

String _reelThumbUrl(Map<String, dynamic> r) {
  final direct = (r['thumb_url'] ?? '').toString().trim();
  if (direct.startsWith('http://') || direct.startsWith('https://')) {
    return direct;
  }
  final tid = (r['thumb_id'] ?? '').toString().trim();
  if (tid.startsWith('http://') || tid.startsWith('https://')) return tid;
  if (tid.isNotEmpty) {
    return 'https://bungtemin.net/btapi/Media/stream/reels/${Uri.encodeComponent(tid)}';
  }
  return '';
}

int _reelLikesCount(Map<String, dynamic> r) {
  final raw = r['likes'];
  if (raw is List) return raw.length;
  if (raw is num) return raw.toInt();
  return 0;
}

class _MyFeedProfileViewState extends State<MyFeedProfileView> {
  int _activeTab = 0; // 0: Postingan, 1: Reels, 2: Tersimpan
  Set<String> _savedStoryIds = <String>{};
  Set<String> _savedReelIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final store = SessionStore();
    final stories = await store.loadSavedStoryIds();
    final reels = await store.loadSavedReelIds();
    if (!mounted) return;
    setState(() {
      _savedStoryIds = stories;
      _savedReelIds = reels;
    });
  }

  bool _isMine(String itemNoreg, String itemNama) {
    final s = widget.session;
    if (s == null) return false;
    final myNoreg = SessionStore.formatNoreg8(s.noreg);
    final rawNoreg = SessionStore.formatNoreg8(itemNoreg);
    if (myNoreg.isNotEmpty && rawNoreg.isNotEmpty) {
      return myNoreg == rawNoreg;
    }
    final myNama = s.nama.trim().toLowerCase();
    return myNama.isNotEmpty && itemNama.trim().toLowerCase() == myNama;
  }

  List<_SavedEntry> _buildMyStories() {
    final out = <_SavedEntry>[];
    for (final s in widget.stories) {
      if (!_isMine(s.noreg, s.nama)) continue;
      final isVideo = s.mediaType == 'video';
      out.add(
        _SavedEntry(
          id: s.id,
          isReel: false,
          nama: s.nama,
          caption: s.caption,
          imageUrl: isVideo ? '' : s.mediaUrl,
          isVideo: isVideo,
          likesCount: s.likes.length,
        ),
      );
    }
    return out;
  }

  List<_SavedEntry> _buildMyReels() {
    final out = <_SavedEntry>[];
    for (final r in widget.reels) {
      final id = _reelId(r);
      if (id.isEmpty) continue;
      final ownerNoreg = (r['noreg'] ?? '').toString();
      final ownerNama = (r['nama'] ?? '').toString();
      if (!_isMine(ownerNoreg, ownerNama)) continue;
      final isVideo =
          (r['mediaType'] ?? 'video').toString().toLowerCase() != 'image';
      out.add(
        _SavedEntry(
          id: id,
          isReel: true,
          nama: ownerNama.isNotEmpty ? ownerNama : 'Anggota',
          caption: (r['text'] ?? '').toString(),
          imageUrl: isVideo ? _reelThumbUrl(r) : _reelMediaUrl(r),
          isVideo: isVideo,
          likesCount: _reelLikesCount(r),
        ),
      );
    }
    return out;
  }

  List<_SavedEntry> _buildSaved() {
    final out = <_SavedEntry>[];

    for (final s in widget.stories) {
      if (!_savedStoryIds.contains(s.id)) continue;
      final isVideo = s.mediaType == 'video';
      out.add(
        _SavedEntry(
          id: s.id,
          isReel: false,
          nama: s.nama,
          caption: s.caption,
          imageUrl: isVideo ? '' : s.mediaUrl,
          isVideo: isVideo,
          likesCount: s.likes.length,
          canUnsave: true,
        ),
      );
    }

    for (final r in widget.reels) {
      final id = _reelId(r);
      if (id.isEmpty || !_savedReelIds.contains(id)) continue;
      final isVideo =
          (r['mediaType'] ?? 'video').toString().toLowerCase() != 'image';
      out.add(
        _SavedEntry(
          id: id,
          isReel: true,
          nama: (r['nama'] ?? 'Anggota').toString(),
          caption: (r['text'] ?? '').toString(),
          imageUrl: isVideo ? _reelThumbUrl(r) : _reelMediaUrl(r),
          isVideo: isVideo,
          likesCount: _reelLikesCount(r),
          canUnsave: true,
        ),
      );
    }

    return out;
  }

  Future<void> _unsave(_SavedEntry e) async {
    final store = SessionStore();
    if (e.isReel) {
      final next = <String>{..._savedReelIds}..remove(e.id);
      setState(() => _savedReelIds = next);
      await store.saveSavedReelIds(next);
    } else {
      final next = <String>{..._savedStoryIds}..remove(e.id);
      setState(() => _savedStoryIds = next);
      await store.saveSavedStoryIds(next);
    }
  }

  void _openEntry(_SavedEntry e) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF070D1B),
        insetPadding: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      Icon(
                        e.isReel
                            ? Icons.movie_outlined
                            : Icons.photo_library_outlined,
                        color: const Color(0xFF38BDF8),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.nama.isNotEmpty ? e.nama : 'Anggota TMMIN',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                if (e.imageUrl.isEmpty)
                  const SizedBox(
                    height: 180,
                    child: Center(
                      child: Icon(
                        Icons.play_circle_outline_rounded,
                        color: Colors.white54,
                        size: 52,
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 420),
                    child: BungteminCachedImage(
                      imageUrl: e.imageUrl,
                      fit: BoxFit.contain,
                      memCacheWidth: 1080,
                      errorWidget: const SizedBox(
                        height: 200,
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
                if (e.caption.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(
                      e.caption,
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      if (e.isReel && e.isVideo)
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            widget.onOpenReels();
                          },
                          icon: const Icon(
                            Icons.play_circle_outline_rounded,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Putar di Reels',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (e.canUnsave)
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _unsave(e);
                          },
                          icon: const Icon(
                            Icons.bookmark_remove_outlined,
                            color: Color(0xFF38BDF8),
                          ),
                          label: const Text(
                            'Hapus dari Tersimpan',
                            style: TextStyle(
                              color: Color(0xFF38BDF8),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final nama = (s != null && s.nama.trim().isNotEmpty)
        ? s.nama.trim()
        : 'Anggota Bungtemin';
    final noreg = s != null && s.noreg.trim().isNotEmpty
        ? SessionStore.formatNoreg8(s.noreg)
        : '-';
    final divisi = s?.divisi.trim() ?? '';

    final myStories = _buildMyStories();
    final myReels = _buildMyReels();
    final saved = _buildSaved();

    final totalPosts = myStories.length + myReels.length;
    final totalLikes = myStories.fold<int>(0, (sum, e) => sum + e.likesCount) +
        myReels.fold<int>(0, (sum, e) => sum + e.likesCount);

    const fallbackAvatar = Image(
      image: AssetImage('assets/img/default-avatar.png'),
      fit: BoxFit.cover,
    );

    final activeItems = switch (_activeTab) {
      1 => myReels,
      2 => saved,
      _ => myStories,
    };

    return Container(
      color: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header Profil ala TikTok
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              children: [
                GestureDetector(
                  onTap: widget.onCreateTap,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF2563EB),
                              Color(0xFFEC4899),
                              Color(0xFFF59E0B),
                            ],
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: ClipOval(
                            child: (s?.avatarUrl ?? '').isEmpty
                                ? fallbackAvatar
                                : BungteminCachedImage(
                                    imageUrl: s!.avatarUrl,
                                    width: 86,
                                    height: 86,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 240,
                                    placeholder: fallbackAvatar,
                                    errorWidget: fallbackAvatar,
                                  ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFF25F4EE),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            size: 17,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  nama,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  divisi.isNotEmpty ? '@$noreg • $divisi' : '@$noreg',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 16),

                // Statistik 3 Kolom ala TikTok
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StatColumn(value: '$totalPosts', label: 'Postingan'),
                    Container(
                      width: 1,
                      height: 24,
                      color: const Color(0xFFE2E8F0),
                    ),
                    _StatColumn(value: '${myReels.length}', label: 'Reels'),
                    Container(
                      width: 1,
                      height: 24,
                      color: const Color(0xFFE2E8F0),
                    ),
                    _StatColumn(value: '$totalLikes', label: 'Suka'),
                  ],
                ),
                const SizedBox(height: 16),

                // Tombol Aksi ala TikTok
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: widget.onCreateTap,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.add_box_outlined, size: 18),
                      label: const Text(
                        'Buat Postingan',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: widget.onOpenReels,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.navy,
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 19),
                      label: const Text(
                        'Tonton Reels',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tab Ikon ala TikTok
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFE2E8F0)),
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              children: [
                _TikTokTabItem(
                  icon: Icons.grid_on_rounded,
                  label: 'Foto (${myStories.length})',
                  active: _activeTab == 0,
                  onTap: () => setState(() => _activeTab = 0),
                ),
                _TikTokTabItem(
                  icon: Icons.video_collection_outlined,
                  label: 'Reels (${myReels.length})',
                  active: _activeTab == 1,
                  onTap: () => setState(() => _activeTab = 1),
                ),
                _TikTokTabItem(
                  icon: Icons.bookmark_border_rounded,
                  label: 'Tersimpan (${saved.length})',
                  active: _activeTab == 2,
                  onTap: () {
                    setState(() => _activeTab = 2);
                    _loadSaved();
                  },
                ),
              ],
            ),
          ),

          // Grid 3 Kolom Rasio 3:4 ala TikTok
          if (activeItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 46),
              child: Column(
                children: [
                  Icon(
                    _activeTab == 1
                        ? Icons.videocam_outlined
                        : _activeTab == 2
                            ? Icons.bookmark_border_rounded
                            : Icons.photo_library_outlined,
                    size: 46,
                    color: const Color(0xFF94A3B8),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _activeTab == 1
                        ? 'Belum ada video Reels'
                        : _activeTab == 2
                            ? 'Belum ada postingan tersimpan'
                            : 'Belum ada postingan foto',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _activeTab == 2
                        ? 'Ketuk ikon bookmark pada Cerita atau Reels untuk menyimpannya di sini.'
                        : 'Bagikan momen Anda agar tampil di grid profil.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                  ),
                ],
              ),
            )
          else
            GridView.builder(
              padding: EdgeInsets.only(
                top: 2,
                bottom: MediaQuery.of(context).padding.bottom + 24,
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeItems.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
                childAspectRatio: 0.75,
              ),
              itemBuilder: (_, i) {
                final e = activeItems[i];
                final placeholder = Container(
                  color: const Color(0xFF0F172A),
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_outline_rounded,
                      color: Colors.white60,
                      size: 32,
                    ),
                  ),
                );
                return GestureDetector(
                  onTap: () => _openEntry(e),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (e.imageUrl.isEmpty)
                        placeholder
                      else
                        BungteminCachedImage(
                          imageUrl: e.imageUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: 360,
                          placeholder: Container(color: const Color(0xFFE2E8F0)),
                          errorWidget: placeholder,
                        ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 36,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.55),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (e.isReel)
                        const Positioned(
                          top: 6,
                          right: 6,
                          child: Icon(
                            Icons.play_arrow_rounded,
                            size: 18,
                            color: Colors.white,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 4),
                            ],
                          ),
                        ),
                      Positioned(
                        left: 6,
                        bottom: 5,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.favorite_border_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${e.likesCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                shadows: [
                                  Shadow(color: Colors.black54, blurRadius: 4),
                                ],
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
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _TikTokTabItem extends StatelessWidget {
  const _TikTokTabItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.navy : const Color(0xFF94A3B8);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? AppColors.navy : Colors.transparent,
                width: 2.2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
