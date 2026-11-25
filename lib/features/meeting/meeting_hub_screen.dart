import 'package:flutter/material.dart';

import '../../core/session_store.dart';
import '../../core/theme.dart';
import '../../models/meeting_item.dart';
import '../../models/meeting_meta.dart';
import '../../services/bungtemin_api.dart';
import 'meeting_create_screen.dart';
import 'meeting_tab.dart';

/// Hub Management Meeting: empat grup (PUK, KP, Pleno, Anggota) + Struktur Organisasi,
/// mengikuti sidebar web organisasi dan hak akses per role.
class MeetingHubScreen extends StatefulWidget {
  const MeetingHubScreen({
    super.key,
    required this.session,
    this.onBackHome,
    this.api,
  });

  final UserSession session;
  final VoidCallback? onBackHome;
  final BungteminApi? api;

  @override
  State<MeetingHubScreen> createState() => _MeetingHubScreenState();
}

class _MeetingHubScreenState extends State<MeetingHubScreen> {
  late final BungteminApi _api = widget.api ?? BungteminApi();

  bool _loading = true;
  String? _error;
  MeetingMeta? _meta;
  List<MeetingItem> _items = const [];
  String _roleLabel = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final s = widget.session;
    try {
      final results = await Future.wait<Object?>([
        _api.fetchMeetingMeta(noreg: s.noreg, token: s.token),
        _api
            .fetchMeetings(noreg: s.noreg, token: s.token)
            .then<Object?>((v) => v)
            .catchError((_) => null),
      ]);
      if (!mounted) return;
      final meta = results[0] as MeetingMeta;
      final dash = results[1] as MeetingDashboardData?;
      setState(() {
        _meta = meta;
        _items = dash?.meetings ?? const [];
        _roleLabel = meta.roleLabel.isNotEmpty
            ? meta.roleLabel
            : (dash?.roleLabel ?? '');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _count(int segment) => _items.where((m) => m.segment == segment).length;

  Future<void> _openList(MeetingKind kind) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (ctx) => Scaffold(
          body: MeetingTab(
            session: widget.session,
            initialSegment: kind.segment,
            lockSegment: true,
            onBackHome: () => Navigator.of(ctx).pop(),
          ),
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _openCreate(MeetingKind kind) async {
    final meta = _meta;
    if (meta == null) return;
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => MeetingCreateScreen(
          session: widget.session,
          kind: kind,
          meta: meta,
          api: _api,
        ),
      ),
    );
    if (created == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final meta = _meta;
    final admin = meta?.canManageAll ?? false;
    final canPleno = meta?.canSeePleno ?? false;
    final canCreate = meta?.canCreate ?? false;
    final kinds = MeetingKind.all;

    final groups = <Widget>[
      if (admin) ...[
        _GroupCard(
          kind: kinds[0],
          count: _count(0),
          showCreate: canCreate,
          onList: () => _openList(kinds[0]),
          onCreate: () => _openCreate(kinds[0]),
        ),
        _GroupCard(
          kind: kinds[1],
          count: _count(1),
          showCreate: canCreate,
          onList: () => _openList(kinds[1]),
          onCreate: () => _openCreate(kinds[1]),
        ),
      ],
      if (canPleno)
        _GroupCard(
          kind: kinds[2],
          count: _count(2),
          showCreate: canCreate,
          onList: () => _openList(kinds[2]),
          onCreate: () => _openCreate(kinds[2]),
        ),
      _GroupCard(
        kind: kinds[3],
        count: _count(3),
        showCreate: canCreate && canPleno,
        onList: () => _openList(kinds[3]),
        onCreate: () => _openCreate(kinds[3]),
      ),
    ];

    return Container(
      color: AppColors.surface,
      child: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _hero(context)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_loading && meta == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (_error != null)
                    _ErrorBanner(message: _error!, onRetry: _load),
                  if (meta != null || _error != null) ...[
                    for (final g in groups) ...[g, const SizedBox(height: 14)],
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        18,
        MediaQuery.of(context).padding.top + 12,
        18,
        24,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, AppColors.navyMid, AppColors.navyDeep],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (widget.onBackHome != null)
                InkWell(
                  onTap: widget.onBackHome,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
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
                        Icon(Icons.arrow_back_rounded,
                            size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'Beranda',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                tooltip: 'Muat ulang',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                ),
                child: Image.asset('assets/icon/23.png'),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _roleLabel.isNotEmpty
                          ? _roleLabel.toUpperCase()
                          : 'HUB MANAGEMENT MEETING',
                      style: const TextStyle(
                        color: Color(0xFF7DD3FC),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Management Meeting',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.session.nama} · Noreg ${SessionStore.formatNoreg8(widget.session.noreg)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 12,
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
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.rose.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.rose.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFBE123C)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF9F1239)),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.kind,
    required this.count,
    required this.showCreate,
    required this.onList,
    required this.onCreate,
  });

  final MeetingKind kind;
  final int count;
  final bool showCreate;
  final VoidCallback onList;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: kind.color,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(kind.icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kind.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    Text(
                      kind.kategori,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: kind.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count meeting',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: kind.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onList,
                  icon: const Icon(Icons.list_alt_rounded, size: 18),
                  label: const Text('Daftar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kind.color,
                    side: BorderSide(color: kind.color.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (showCreate) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onCreate,
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                    label: const Text('Buat'),
                    style: FilledButton.styleFrom(
                      backgroundColor: kind.color,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
