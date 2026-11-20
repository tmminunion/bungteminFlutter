import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/session_store.dart';
import '../../core/theme.dart';
import '../../models/meeting_item.dart';
import '../../services/bungtemin_api.dart';
import '../../services/fcm_service.dart';
import '../feed/tabfeed_screen.dart';
import '../../core/net/btapi_auth.dart';
import '../inbox/broadcast_inbox_screen.dart';

const String _chatBaseUrl = 'https://bungtemin.net/btapi/Chat';

String _norm8(String noreg) {
  final digits = noreg.replaceAll(RegExp(r'\D+'), '');
  if (digits.isEmpty) return '';
  return digits.padLeft(8, '0');
}

String _dmRoomId(String a, String b) {
  final pair = [_norm8(a), _norm8(b)]..sort();
  return 'dm_${pair[0]}_${pair[1]}';
}

String _formatTime(String raw) {
  if (raw.length >= 16) {
    return raw.substring(11, 16);
  }
  return '';
}

class ChatRoomSummary {
  const ChatRoomSummary({
    required this.roomId,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.peerNoreg,
    required this.lastAt,
    required this.pinned,
    this.isOnline = false,
    this.statusText = '',
  });

  final String roomId;
  final String kind;
  final String title;
  final String subtitle;
  final String peerNoreg;
  final String lastAt;
  final bool pinned;
  final bool isOnline;
  final String statusText;

  factory ChatRoomSummary.fromJson(Map<String, dynamic> json) {
    return ChatRoomSummary(
      roomId: (json['room_id'] ?? '').toString(),
      kind: (json['kind'] ?? 'dm').toString(),
      title: (json['title'] ?? 'Chat').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      peerNoreg: (json['peer_noreg'] ?? '').toString(),
      lastAt: (json['last_at'] ?? '').toString(),
      pinned: json['pinned'] == true,
      isOnline: json['is_online'] == true,
      statusText: (json['status_text'] ?? '').toString(),
    );
  }
}

class ChatMessageItem {
  const ChatMessageItem({
    required this.id,
    required this.roomId,
    required this.senderNoreg,
    required this.senderNama,
    required this.receiverNoreg,
    required this.message,
    required this.isAi,
    required this.createdAt,
  });

  final int id;
  final String roomId;
  final String senderNoreg;
  final String senderNama;
  final String receiverNoreg;
  final String message;
  final bool isAi;
  final String createdAt;

  factory ChatMessageItem.fromJson(Map<String, dynamic> json) {
    return ChatMessageItem(
      id: int.tryParse((json['id'] ?? '0').toString()) ?? 0,
      roomId: (json['room_id'] ?? '').toString(),
      senderNoreg: (json['sender_noreg'] ?? '').toString(),
      senderNama: (json['sender_nama'] ?? '').toString(),
      receiverNoreg: (json['receiver_noreg'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      isAi: json['is_ai'] == true || json['is_ai'] == 1,
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

class ChatMemberItem {
  const ChatMemberItem({
    required this.noreg,
    required this.nama,
    required this.divisi,
    required this.job,
    this.isOnline = false,
    this.statusText = '',
  });

  final String noreg;
  final String nama;
  final String divisi;
  final String job;
  final bool isOnline;
  final String statusText;

  factory ChatMemberItem.fromJson(Map<String, dynamic> json) {
    return ChatMemberItem(
      noreg: (json['noreg'] ?? '').toString(),
      nama: (json['nama'] ?? '').toString(),
      divisi: (json['divisi'] ?? '').toString(),
      job: (json['job'] ?? '').toString(),
      isOnline: json['is_online'] == true,
      statusText: (json['status_text'] ?? '').toString(),
    );
  }
}

class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key, required this.session});

  final UserSession session;

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  final _searchController = TextEditingController();
  final _api = BungteminApi();

  List<ChatRoomSummary> _rooms = [];
  List<StoryItem> _stories = [];
  List<ChatMemberItem> _onlineMembers = [];

  bool _loadingInbox = true;
  bool _loadingStories = true;
  bool _loadingOnline = true;
  String? _inboxError;
  String _query = '';
  StreamSubscription<PushPayload>? _fcmSub;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _fcmSub = FcmService.instance.onForegroundMessage.listen((payload) {
      if (payload.type.toLowerCase() == 'chat' && mounted) {
        _loadInbox();
      }
    });
  }

  @override
  void dispose() {
    _fcmSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadInbox(),
      _loadStories(),
      _loadOnlineMembers(),
    ]);
  }

  Future<void> _loadInbox() async {
    setState(() {
      _loadingInbox = _rooms.isEmpty;
      _inboxError = null;
    });
    try {
      final noreg = _norm8(widget.session.noreg);
      final res = await http
          .get(Uri.parse('$_chatBaseUrl/inbox?noreg=$noreg'), headers: BtapiAuth.headers())
          .timeout(const Duration(seconds: 12));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        final list = (body['data'] as List<dynamic>? ?? [])
            .map((e) => ChatRoomSummary.fromJson(e as Map<String, dynamic>))
            .toList();
        if (!mounted) return;
        setState(() {
          _rooms = list;
          _loadingInbox = false;
        });
      } else {
        throw Exception(body['message'] ?? 'Gagal memuat inbox');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _inboxError = e.toString().replaceFirst('Exception: ', '');
        _loadingInbox = false;
      });
    }
  }

  Future<void> _loadStories() async {
    setState(() => _loadingStories = _stories.isEmpty);
    try {
      final list = await _api.fetchStories();
      if (!mounted) return;
      setState(() {
        _stories = list;
        _loadingStories = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingStories = false);
    }
  }

  Future<void> _loadOnlineMembers() async {
    setState(() => _loadingOnline = _onlineMembers.isEmpty);
    try {
      final noreg = _norm8(widget.session.noreg);
      final res = await http
          .get(Uri.parse('$_chatBaseUrl/online?noreg=$noreg'), headers: BtapiAuth.headers())
          .timeout(const Duration(seconds: 10));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        final list = (body['data'] as List<dynamic>? ?? [])
            .map((e) => ChatMemberItem.fromJson(e as Map<String, dynamic>))
            .toList();
        if (!mounted) return;
        setState(() {
          _onlineMembers = list;
          _loadingOnline = false;
        });
      } else if (mounted) {
        setState(() => _loadingOnline = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingOnline = false);
    }
  }

  Future<void> _openRoom(ChatRoomSummary room) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatRoomScreen(
          session: widget.session,
          roomId: room.roomId,
          kind: room.kind,
          title: room.title,
          peerNoreg: room.peerNoreg,
        ),
      ),
    );
    if (mounted) {
      _loadInbox();
      _loadOnlineMembers();
    }
  }

  Future<void> _openDmWithMember(ChatMemberItem member) async {
    final roomId = _dmRoomId(widget.session.noreg, member.noreg);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatRoomScreen(
          session: widget.session,
          roomId: roomId,
          kind: 'dm',
          title: member.nama,
          peerNoreg: member.noreg,
        ),
      ),
    );
    if (mounted) {
      _loadInbox();
      _loadOnlineMembers();
    }
  }

  Future<void> _openNewChatPicker() async {
    final picked = await showModalBottomSheet<ChatMemberItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _MemberPickerSheet(selfNoreg: widget.session.noreg),
    );
    if (picked == null || !mounted) return;
    await _openDmWithMember(picked);
  }

  void _openStoryFeed() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TabFeedScreen(
          session: widget.session,
          onRequireLogin: (_, after) => after(),
        ),
      ),
    );
  }

  void _showStoryPreview(StoryItem story) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0F172A),
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.emerald,
                    child: Text(
                      story.nama.isNotEmpty ? story.nama[0].toUpperCase() : 'A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          story.nama,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        if (story.createdAt.isNotEmpty)
                          Text(
                            story.createdAt,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                ],
              ),
            ),
            if (story.mediaUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: Image.network(
                    story.mediaUrl,
        headers: BtapiAuth.imageHeaders(story.mediaUrl),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Icon(
                        Icons.broken_image_rounded,
                        color: Colors.white38,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
            if (story.caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Text(
                  story.caption,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredRooms = _rooms.where((r) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return r.title.toLowerCase().contains(q) ||
          r.subtitle.toLowerCase().contains(q) ||
          r.peerNoreg.toLowerCase().contains(q);
    }).toList();

    final onlineCount = _onlineMembers.where((m) => m.isOnline).length;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chat Bungtemin',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              Text(
                'DM Anggota, Status & B.A.I.M AI',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          centerTitle: false,
          actions: [
            IconButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const BroadcastInboxScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.mark_email_unread_rounded),
              tooltip: 'Kotak Masuk Broadcast',
            ),
            IconButton(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Segarkan',
            ),
          ],
          bottom: TabBar(
            indicatorColor: AppColors.emerald,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: const Color(0xFF94A3B8),
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
            tabs: [
              const Tab(text: 'Chat'),
              Tab(text: 'Status (${_stories.length})'),
              Tab(text: onlineCount > 0 ? 'Online ($onlineCount)' : 'Online'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openNewChatPicker,
          backgroundColor: AppColors.emerald,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.chat_rounded),
          label: const Text(
            'Chat Baru',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: CHAT INBOX
            Column(
              children: [
                Container(
                  color: AppColors.navy,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v.trim()),
                    style: const TextStyle(fontSize: 14, color: AppColors.navy),
                    decoration: InputDecoration(
                      hintText: 'Cari obrolan atau anggota...',
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
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _loadingInbox
                      ? const Center(child: CircularProgressIndicator())
                      : _inboxError != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.wifi_off_rounded,
                                      size: 42,
                                      color: AppColors.muted,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      _inboxError!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: AppColors.muted),
                                    ),
                                    const SizedBox(height: 14),
                                    FilledButton(
                                      onPressed: _loadInbox,
                                      child: const Text('Coba Lagi'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadInbox,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(12, 10, 12, 88),
                                itemCount: filteredRooms.length,
                                separatorBuilder: (_, __) => const Divider(
                                  height: 1,
                                  indent: 72,
                                  color: Color(0xFFE2E8F0),
                                ),
                                itemBuilder: (_, idx) {
                                  final room = filteredRooms[idx];
                                  return _RoomTile(
                                    room: room,
                                    onTap: () => _openRoom(room),
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),

            // TAB 2: STATUS / CERITA ANGGOTA
            RefreshIndicator(
              onRefresh: _loadStories,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 88),
                children: [
                  Card(
                    child: ListTile(
                      onTap: _openStoryFeed,
                      leading: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.navy.withValues(alpha: 0.1),
                            child: const Icon(
                              Icons.person_rounded,
                              color: AppColors.navy,
                            ),
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: AppColors.emerald,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.add_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      title: const Text(
                        'Status Saya & Cerita Anggota',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          color: AppColors.navy,
                        ),
                      ),
                      subtitle: const Text(
                        'Ketuk untuk buat status baru atau buka galeri Cerita',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 14, 4, 8),
                    child: Text(
                      'PEMBARUAN STATUS TERBARU',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  if (_loadingStories)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_stories.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(28),
                      child: Center(
                        child: Text(
                          'Belum ada status cerita terbaru.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    )
                  else
                    ..._stories.map((st) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          onTap: () => _showStoryPreview(st),
                          leading: Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.emerald,
                                width: 2.2,
                              ),
                            ),
                            child: ClipOval(
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: st.mediaUrl.isNotEmpty
                                    ? Image.network(
                                        st.mediaUrl,
        headers: BtapiAuth.imageHeaders(st.mediaUrl),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Center(
                                          child: Text(
                                            st.nama.isNotEmpty
                                                ? st.nama[0].toUpperCase()
                                                : 'A',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          st.nama.isNotEmpty
                                              ? st.nama[0].toUpperCase()
                                              : 'A',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          title: Text(
                            st.nama,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppColors.navy,
                            ),
                          ),
                          subtitle: Text(
                            st.caption.isNotEmpty ? st.caption : st.createdAt,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                          trailing: Text(
                            _formatTime(st.createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),

            // TAB 3: USER ONLINE & AKTIF TERBARU
            RefreshIndicator(
              onRefresh: _loadOnlineMembers,
              child: _loadingOnline
                  ? const Center(child: CircularProgressIndicator())
                  : _onlineMembers.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.all(32),
                          children: const [
                            SizedBox(height: 60),
                            Icon(
                              Icons.people_outline_rounded,
                              size: 48,
                              color: AppColors.muted,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Belum ada anggota lain yang aktif di Chat.\nGunakan tombol Chat Baru untuk memulai obrolan.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 88),
                          itemCount: _onlineMembers.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            indent: 72,
                            color: Color(0xFFE2E8F0),
                          ),
                          itemBuilder: (_, idx) {
                            final m = _onlineMembers[idx];
                            return ListTile(
                              onTap: () => _openDmWithMember(m),
                              leading: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  CircleAvatar(
                                    radius: 23,
                                    backgroundColor: const Color(0xFFE0F2FE),
                                    child: Text(
                                      m.nama.isNotEmpty
                                          ? m.nama[0].toUpperCase()
                                          : 'A',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primaryBlue,
                                      ),
                                    ),
                                  ),
                                  if (m.isOnline)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 13,
                                        height: 13,
                                        decoration: BoxDecoration(
                                          color: AppColors.emerald,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              title: Text(
                                m.nama,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: AppColors.navy,
                                ),
                              ),
                              subtitle: Text(
                                '${m.statusText.isNotEmpty ? m.statusText : 'Noreg ${m.noreg}'}${m.divisi.isNotEmpty ? ' • ${m.divisi}' : ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: m.isOnline
                                      ? const Color(0xFF047857)
                                      : AppColors.muted,
                                  fontWeight: m.isOnline
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 19,
                                color: AppColors.primaryBlue,
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

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.room, required this.onTap});

  final ChatRoomSummary room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isBaim = room.kind == 'baim';
    final isGroup = room.kind == 'group';

    Color avatarBg = const Color(0xFFE0F2FE);
    Color iconColor = AppColors.primaryBlue;
    IconData iconData = Icons.person_rounded;

    if (isBaim) {
      avatarBg = const Color(0xFFEDE9FE);
      iconColor = const Color(0xFF6D28D9);
      iconData = Icons.auto_awesome_rounded;
    } else if (isGroup) {
      avatarBg = const Color(0xFFD1FAE5);
      iconColor = const Color(0xFF047857);
      iconData = Icons.groups_rounded;
    }

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: avatarBg,
            child: Icon(iconData, color: iconColor, size: 24),
          ),
          if (!isBaim && !isGroup && room.isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: AppColors.emerald,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              room.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
                color: AppColors.navy,
              ),
            ),
          ),
          if (isBaim || isGroup) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isBaim
                    ? const Color(0xFF6D28D9).withValues(alpha: 0.12)
                    : AppColors.emerald.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                isBaim ? 'AI' : 'GRUP',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isBaim ? const Color(0xFF6D28D9) : const Color(0xFF047857),
                ),
              ),
            ),
          ],
          if (room.lastAt.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(
              _formatTime(room.lastAt),
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(
          room.subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
      ),
    );
  }
}

class _MemberPickerSheet extends StatefulWidget {
  const _MemberPickerSheet({required this.selfNoreg});

  final String selfNoreg;

  @override
  State<_MemberPickerSheet> createState() => _MemberPickerSheetState();
}

class _MemberPickerSheetState extends State<_MemberPickerSheet> {
  final _ctrl = TextEditingController();
  List<ChatMemberItem> _members = [];
  bool _loading = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(val));
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final self8 = _norm8(widget.selfNoreg);
      final uri = Uri.parse(
        '$_chatBaseUrl/members?noreg=$self8&q=${Uri.encodeQueryComponent(q.trim())}',
      );
      final res = await http.get(uri, headers: BtapiAuth.headers()).timeout(const Duration(seconds: 10));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        final list = (body['data'] as List<dynamic>? ?? [])
            .map((e) => ChatMemberItem.fromJson(e as Map<String, dynamic>))
            .toList();
        if (!mounted) return;
        setState(() {
          _members = list;
          _loading = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _loading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.78,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Row(
              children: [
                Icon(Icons.person_search_rounded, color: AppColors.navy),
                SizedBox(width: 10),
                Text(
                  'Pilih Anggota untuk Chat',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _ctrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Cari nama, noreg, atau divisi...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _members.isEmpty
                    ? const Center(
                        child: Text(
                          'Anggota tidak ditemukan.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _members.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, idx) {
                          final m = _members[idx];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFE0F2FE),
                              child: Text(
                                m.nama.isNotEmpty ? m.nama[0].toUpperCase() : 'A',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                            ),
                            title: Text(
                              m.nama,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.navy,
                              ),
                            ),
                            subtitle: Text(
                              'Noreg ${m.noreg}${m.divisi.isNotEmpty ? ' • ${m.divisi}' : ''}${m.isOnline ? ' • Online' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: m.isOnline
                                    ? const Color(0xFF047857)
                                    : AppColors.muted,
                                fontWeight: m.isOnline
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                            trailing: m.isOnline
                                ? Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: AppColors.emerald,
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                : null,
                            onTap: () => Navigator.of(context).pop(m),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({
    super.key,
    required this.session,
    required this.roomId,
    required this.kind,
    required this.title,
    this.peerNoreg = '',
  });

  final UserSession session;
  final String roomId;
  final String kind;
  final String title;
  final String peerNoreg;

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<ChatMessageItem> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _peerIsOnline = false;
  String _peerStatusText = '';
  StreamSubscription<PushPayload>? _fcmSub;

  bool get _isBaim => widget.kind == 'baim';

  @override
  void initState() {
    super.initState();
    _fetchMessages(initial: true);
    if (!_isBaim) {
      _fcmSub = FcmService.instance.onForegroundMessage.listen((payload) {
        if (payload.type.toLowerCase() == 'chat' &&
            (payload.pageId.isEmpty || payload.pageId == widget.roomId) &&
            mounted) {
          _fetchMessages(initial: false);
        }
      });
    }
  }

  @override
  void dispose() {
    _fcmSub?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _fetchMessages({required bool initial}) async {
    try {
      final afterId = (!initial && _messages.isNotEmpty) ? _messages.last.id : 0;
      final self8 = _norm8(widget.session.noreg);
      final uri = Uri.parse(
        '$_chatBaseUrl/messages?room_id=${Uri.encodeQueryComponent(widget.roomId)}&noreg=$self8&after_id=$afterId',
      );
      final res = await http.get(uri, headers: BtapiAuth.headers()).timeout(const Duration(seconds: 10));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        final incoming = (body['data'] as List<dynamic>? ?? [])
            .map((e) => ChatMessageItem.fromJson(e as Map<String, dynamic>))
            .toList();
        final pp = body['peer_presence'];
        if (!mounted) return;
        setState(() {
          if (pp is Map) {
            _peerIsOnline = pp['is_online'] == true;
            _peerStatusText = (pp['status_text'] ?? '').toString();
          }
          if (initial) {
            _messages = incoming;
          } else if (incoming.isNotEmpty) {
            final existingIds = _messages.map((m) => m.id).toSet();
            for (final m in incoming) {
              if (!existingIds.contains(m.id)) {
                _messages.add(m);
              }
            }
          }
          _loading = false;
        });
        if (initial || incoming.isNotEmpty) {
          _scrollToBottom();
        }
      } else if (initial && mounted) {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (initial && mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _sendMessage([String? preset]) async {
    final text = (preset ?? _msgCtrl.text).trim();
    if (text.isEmpty || _sending) return;
    if (preset == null) _msgCtrl.clear();

    setState(() => _sending = true);
    final self8 = _norm8(widget.session.noreg);

    try {
      if (_isBaim) {
        final res = await http
            .post(
              Uri.parse('$_chatBaseUrl/ask_baim'),
              headers: {'Content-Type': 'application/json', ...BtapiAuth.headers()},
              body: jsonEncode({
                'noreg': self8,
                'nama': widget.session.nama,
                'message': text,
              }),
            )
            .timeout(const Duration(seconds: 20));
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (res.statusCode == 200 && body['success'] == true) {
          final u = ChatMessageItem.fromJson(
            body['user_message'] as Map<String, dynamic>,
          );
          final ai = ChatMessageItem.fromJson(
            body['ai_message'] as Map<String, dynamic>,
          );
          if (!mounted) return;
          setState(() {
            _messages.addAll([u, ai]);
            _sending = false;
          });
          _scrollToBottom();
          return;
        }
      } else {
        final res = await http
            .post(
              Uri.parse('$_chatBaseUrl/send'),
              headers: {'Content-Type': 'application/json', ...BtapiAuth.headers()},
              body: jsonEncode({
                'room_id': widget.roomId,
                'sender_noreg': self8,
                'sender_nama': widget.session.nama,
                'receiver_noreg': widget.kind == 'dm' ? widget.peerNoreg : '',
                'message': text,
              }),
            )
            .timeout(const Duration(seconds: 12));
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (res.statusCode == 200 && body['success'] == true) {
          final sent = ChatMessageItem.fromJson(
            body['data'] as Map<String, dynamic>,
          );
          if (!mounted) return;
          setState(() {
            if (!_messages.any((m) => m.id == sent.id)) {
              _messages.add(sent);
            }
            _sending = false;
          });
          _scrollToBottom();
          return;
        }
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gagal mengirim pesan. Periksa koneksi Anda.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final self8 = _norm8(widget.session.noreg);
    final subtitle = _isBaim
        ? 'Bungtemin Artificial Intelligence Machine'
        : _peerStatusText.isNotEmpty
            ? _peerStatusText
            : 'Noreg ${widget.peerNoreg}';

    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD),
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        centerTitle: false,
        titleSpacing: 0,
        actions: [
          IconButton(
            onPressed: () => _fetchMessages(initial: false),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Muat pesan terbaru',
          ),
        ],
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _isBaim
                  ? const Color(0xFF6D28D9)
                  : widget.kind == 'group'
                      ? AppColors.emerald
                      : AppColors.primaryBlue,
              child: Icon(
                _isBaim
                    ? Icons.auto_awesome_rounded
                    : widget.kind == 'group'
                        ? Icons.groups_rounded
                        : Icons.person_rounded,
                size: 19,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Row(
                    children: [
                      if (!_isBaim && _peerIsOnline) ...[
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: const BoxDecoration(
                            color: AppColors.emerald,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: _peerIsOnline
                                ? const Color(0xFF6EE7B7)
                                : const Color(0xFFCBD5E1),
                            fontWeight: _peerIsOnline
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
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
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _EmptyChatHint(
                        isBaim: _isBaim,
                        onQuickPrompt: _isBaim ? _sendMessage : null,
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                        itemCount: _messages.length,
                        itemBuilder: (_, idx) {
                          final m = _messages[idx];
                          final isMine = !m.isAi && _norm8(m.senderNoreg) == self8;
                          return _ChatBubble(
                            message: m,
                            isMine: isMine,
                            showSenderName: !isMine && (widget.kind == 'group' || m.isAi),
                          );
                        },
                      ),
          ),
          if (_sending && _isBaim)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                'B.A.I.M sedang mengetik...',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          Container(
            color: const Color(0xFFF1F5F9),
            padding: EdgeInsets.fromLTRB(
              10,
              8,
              10,
              MediaQuery.of(context).padding.bottom + 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: _isBaim
                          ? 'Tanya B.A.I.M apa saja...'
                          : 'Ketik pesan...',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 23,
                  backgroundColor:
                      _isBaim ? const Color(0xFF6D28D9) : AppColors.emerald,
                  child: IconButton(
                    onPressed: _sending ? null : () => _sendMessage(),
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
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

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.isMine,
    required this.showSenderName,
  });

  final ChatMessageItem message;
  final bool isMine;
  final bool showSenderName;

  @override
  Widget build(BuildContext context) {
    final bg = isMine
        ? const Color(0xFFDCF8C6)
        : message.isAi
            ? const Color(0xFFF5F3FF)
            : Colors.white;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMine ? 14 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 14),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showSenderName)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  message.senderNama,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: message.isAi
                        ? const Color(0xFF6D28D9)
                        : AppColors.primaryBlue,
                  ),
                ),
              ),
            Text(
              message.message,
              style: const TextStyle(
                fontSize: 14,
                height: 1.38,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 3),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                _formatTime(message.createdAt),
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChatHint extends StatelessWidget {
  const _EmptyChatHint({required this.isBaim, this.onQuickPrompt});

  final bool isBaim;
  final ValueChanged<String>? onQuickPrompt;

  @override
  Widget build(BuildContext context) {
    if (!isBaim) {
      return const Center(
        child: Text(
          'Belum ada pesan. Mulai obrolan sekarang!',
          style: TextStyle(color: Color(0xFF475569), fontSize: 13.5),
        ),
      );
    }

    const prompts = [
      'Apa itu KTA Digital?',
      'Bagaimana cek Tiket Meeting?',
      'Di mana Buku Pintar & UU?',
      'Kontak Sekretariat PUK',
    ];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 30,
              backgroundColor: Color(0xFFEDE9FE),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 30,
                color: Color(0xFF6D28D9),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Halo! Saya B.A.I.M',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Bungtemin Artificial Intelligence Machine.\nPilih topik di bawah atau ketik pertanyaan Anda:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: prompts
                  .map(
                    (p) => ActionChip(
                      label: Text(
                        p,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      backgroundColor: Colors.white,
                      onPressed: () => onQuickPrompt?.call(p),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
