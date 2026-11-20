import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'ig_feed_view.dart';
import 'my_feed_profile_view.dart';
import 'reels_player_view.dart';

import '../../core/session_store.dart';
import '../../core/theme.dart';
import '../../models/meeting_item.dart';
import '../../services/bungtemin_api.dart';
import '../../services/fcm_service.dart';

class TabFeedScreen extends StatefulWidget {
  const TabFeedScreen({
    super.key,
    required this.session,
    required this.onRequireLogin,
  });

  final UserSession? session;
  final void Function(String reason, VoidCallback afterLogin) onRequireLogin;

  @override
  State<TabFeedScreen> createState() => _TabFeedScreenState();
}

class _TabFeedScreenState extends State<TabFeedScreen> {
  final _api = BungteminApi();
  int _tabIndex = 0; // 0: Linimasa, 1: Reels, 2: Notif, 3: Profil
  bool _loading = true;
  List<StoryItem> _stories = const [];
  List<Map<String, dynamic>> _reels = const [];

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.fetchStories(),
        _api.fetchReels(),
      ]);
      if (!mounted) return;
      setState(() {
        _stories = results[0] as List<StoryItem>;
        _reels = results[1] as List<Map<String, dynamic>>;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectBottomTab(int idx) {
    if ((idx == 2 || idx == 3) && widget.session == null) {
      widget.onRequireLogin(
        idx == 2
            ? 'Masuk terlebih dahulu untuk melihat notifikasi Cerita Anda.'
            : 'Masuk terlebih dahulu untuk membuka Profil Cerita Anda.',
        () {
          if (mounted) setState(() => _tabIndex = idx);
        },
      );
      return;
    }
    setState(() => _tabIndex = idx);
  }

  void _handleCreatePost() {
    if (widget.session == null) {
      widget.onRequireLogin(
        'Masuk terlebih dahulu untuk membuat postingan Foto atau Reels.',
        _showCreatePostSheet,
      );
      return;
    }
    _showCreatePostSheet();
  }

  Future<void> _showCreatePostSheet() async {
    final session = widget.session;
    if (session == null) return;

    final initialType = _tabIndex == 1 ? 'reels' : 'feed';
    final postedType = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreatePostSheet(
        api: _api,
        session: session,
        initialType: initialType,
      ),
    );

    if (postedType != null && mounted) {
      setState(() {
        _tabIndex = postedType == 'reels' ? 1 : 0;
      });
      await _loadFeed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_tabIndex) {
      0 => 'Linimasa Cerita',
      1 => 'Reels Komunitas',
      2 => 'Notifikasi Cerita',
      _ => 'Profil Cerita Saya',
    };

    return Scaffold(
      backgroundColor: _tabIndex == 1 ? const Color(0xFF070D1B) : AppColors.surface,
      appBar: AppBar(
        backgroundColor: _tabIndex == 1 ? const Color(0xFF070D1B) : AppColors.navy,
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        actions: [
          IconButton(
            onPressed: _loadFeed,
            tooltip: 'Muat Ulang',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _AuroraFeedBottomBar(
        currentIndex: _tabIndex,
        onSelect: _selectBottomTab,
        onCreateTap: _handleCreatePost,
      ),
    );
  }

  Widget _buildBody() {
    if (_tabIndex == 0) {
      if (_loading) {
        return const Center(child: CircularProgressIndicator());
      }
      return IgFeedView(
        stories: _stories,
        api: _api,
        session: widget.session,
        onRefresh: _loadFeed,
        onCreateTap: _handleCreatePost,
        onRequireLogin: widget.onRequireLogin,
        onStoryDeleted: (id) {
          setState(() {
            _stories = _stories.where((s) => s.id != id).toList();
          });
        },
      );
    }

    if (_tabIndex == 1) {
      if (_loading) {
        return const ColoredBox(
          color: Color(0xFF070D1B),
          child: Center(
            child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
          ),
        );
      }
      return ReelsPlayerView(
        reels: _reels,
        api: _api,
        session: widget.session,
        onRefresh: _loadFeed,
        onRequireLogin: widget.onRequireLogin,
        onReelDeleted: (id) {
          setState(() {
            _reels = _reels
                .where((r) => (r['id'] ?? r['\$id'] ?? '').toString() != id)
                .toList();
          });
        },
      );
    }

    if (_tabIndex == 2) {
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: FcmService.instance.loadHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none_rounded,
                        size: 48, color: AppColors.primaryBlue),
                    SizedBox(height: 10),
                    Text(
                      'Notifikasi Cerita',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Belum ada notifikasi push yang masuk.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 4),
                child: Row(
                  children: [
                    Text(
                      'Riwayat Notifikasi (${items.length})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        await FcmService.instance.clearHistory();
                        if (mounted) setState(() {});
                      },
                      child: const Text('Bersihkan'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, idx) {
                    final n = items[idx];
                    final title = (n['title'] ?? 'Notifikasi').toString();
                    final body = (n['body'] ?? '').toString();
                    final timeRaw = (n['receivedAt'] ?? '').toString();
                    final time = timeRaw.length >= 16
                        ? timeRaw.substring(0, 16).replaceFirst('T', ' ')
                        : timeRaw;
                    return Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.primaryBlue.withValues(alpha: 0.12),
                          child: const Icon(
                            Icons.notifications_active_rounded,
                            color: AppColors.primaryBlue,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: AppColors.navy,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (body.isNotEmpty) Text(body),
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
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    }

    return MyFeedProfileView(
      session: widget.session,
      stories: _stories,
      reels: _reels,
      onCreateTap: _handleCreatePost,
      onOpenReels: () => _selectBottomTab(1),
    );
  }
}

class _CreatePostSheet extends StatefulWidget {
  const _CreatePostSheet({
    required this.api,
    required this.session,
    required this.initialType,
  });

  final BungteminApi api;
  final UserSession session;
  final String initialType;

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final _picker = ImagePicker();
  final _captionCtrl = TextEditingController();
  late String _postType; // 'feed' | 'reels'
  Uint8List? _mediaBytes;
  String _mediaName = '';
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _postType = widget.initialType;
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(ImageSource source) async {
    setState(() => _error = null);
    try {
      XFile? picked;
      if (_postType == 'feed') {
        picked = await _picker.pickImage(
          source: source,
          maxWidth: 1440,
          imageQuality: 82,
        );
      } else {
        picked = await _picker.pickVideo(
          source: source,
          maxDuration: const Duration(minutes: 2),
        );
      }
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final maxBytes =
          _postType == 'feed' ? 35 * 1024 * 1024 : 50 * 1024 * 1024;
      if (bytes.length > maxBytes) {
        setState(() {
          _error = _postType == 'feed'
              ? 'Ukuran foto maksimal 35 MB.'
              : 'Ukuran video Reels maksimal 50 MB.';
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _mediaBytes = bytes;
        final rawName = picked!.name.trim();
        final ext = rawName.contains('.') ? rawName.split('.').last.toLowerCase() : '';
        if (_postType == 'feed') {
          const validImg = {'jpg', 'jpeg', 'png', 'webp', 'gif'};
          _mediaName = validImg.contains(ext) ? rawName : 'story.jpg';
        } else {
          const validVid = {'mp4', 'mov', 'webm', 'm4v'};
          _mediaName = validVid.contains(ext) ? rawName : 'reel.mp4';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Gagal memilih media: $e');
    }
  }

  Future<void> _submit() async {
    if (_mediaBytes == null) {
      setState(() {
        _error = _postType == 'feed'
            ? 'Pilih foto terlebih dahulu.'
            : 'Pilih video Reels terlebih dahulu.';
      });
      return;
    }
    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      if (_postType == 'feed') {
        await widget.api.uploadStory(
          bytes: _mediaBytes!,
          filename: _mediaName,
          noreg: widget.session.noreg,
          nama: widget.session.nama,
          pesan: _captionCtrl.text,
        );
      } else {
        await widget.api.uploadReel(
          bytes: _mediaBytes!,
          filename: _mediaName,
          noreg: widget.session.noreg,
          nama: widget.session.nama,
          text: _captionCtrl.text,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _postType == 'feed'
                ? 'Foto cerita berhasil diposting!'
                : 'Video Reels berhasil diposting!',
          ),
        ),
      );
      Navigator.of(context).pop(_postType);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizeMb = _mediaBytes == null
        ? ''
        : ' (${(_mediaBytes!.length / (1024 * 1024)).toStringAsFixed(1)} MB)';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Posting Cerita / Reels',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'feed',
                  icon: Icon(Icons.photo_library_outlined, size: 17),
                  label: Text('Foto Cerita'),
                ),
                ButtonSegment(
                  value: 'reels',
                  icon: Icon(Icons.movie_creation_outlined, size: 17),
                  label: Text('Video Reels'),
                ),
              ],
              selected: {_postType},
              onSelectionChanged: _uploading
                  ? null
                  : (s) => setState(() {
                        _postType = s.first;
                        _mediaBytes = null;
                        _mediaName = '';
                        _error = null;
                      }),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _uploading
                        ? null
                        : () => _pickMedia(ImageSource.gallery),
                    icon: Icon(
                      _postType == 'feed'
                          ? Icons.photo_outlined
                          : Icons.video_library_outlined,
                      size: 18,
                    ),
                    label: Text(
                      _postType == 'feed' ? 'Pilih Foto' : 'Pilih Video',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _uploading
                        ? null
                        : () => _pickMedia(ImageSource.camera),
                    icon: Icon(
                      _postType == 'feed'
                          ? Icons.camera_alt_outlined
                          : Icons.videocam_outlined,
                      size: 18,
                    ),
                    label: Text(
                      _postType == 'feed' ? 'Kamera' : 'Rekam',
                    ),
                  ),
                ),
              ],
            ),
            if (_mediaBytes != null) ...[
              const SizedBox(height: 12),
              if (_postType == 'feed')
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.memory(
                    _mediaBytes!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.navy.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.video_file_rounded,
                          color: AppColors.indigo),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$_mediaName$sizeMb',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _captionCtrl,
              maxLines: 3,
              enabled: !_uploading,
              decoration: const InputDecoration(
                labelText: 'Keterangan / Caption',
                hintText: 'Tulis cerita atau keterangan...',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _uploading ? null : _submit,
              icon: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_rounded),
              label: Text(
                _uploading ? 'Mengunggah...' : 'Posting Sekarang',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.navy,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuroraFeedBottomBar extends StatelessWidget {
  const _AuroraFeedBottomBar({
    required this.currentIndex,
    required this.onSelect,
    required this.onCreateTap,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      height: 64 + bottomPad,
      padding: EdgeInsets.only(bottom: bottomPad),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.20),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Row(
        children: [
          _FeedTabBtn(
            icon: Icons.public_rounded,
            label: 'Linimasa',
            selected: currentIndex == 0,
            onTap: () => onSelect(0),
          ),
          _FeedTabBtn(
            icon: Icons.movie_creation_outlined,
            label: 'Reels',
            selected: currentIndex == 1,
            onTap: () => onSelect(1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: InkWell(
              onTap: onCreateTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primaryBlue, AppColors.auroraCyan],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.auroraCyan.withValues(alpha: 0.40),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),
          _FeedTabBtn(
            icon: Icons.notifications_none_rounded,
            label: 'Notif',
            selected: currentIndex == 2,
            onTap: () => onSelect(2),
          ),
          _FeedTabBtn(
            icon: Icons.person_outline_rounded,
            label: 'Profil',
            selected: currentIndex == 3,
            onTap: () => onSelect(3),
          ),
        ],
      ),
    );
  }
}

class _FeedTabBtn extends StatelessWidget {
  const _FeedTabBtn({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.auroraCyan : const Color(0xFF94A3B8);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
