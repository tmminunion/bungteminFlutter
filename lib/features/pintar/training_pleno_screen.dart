import 'package:flutter/material.dart';

import '../../core/session_store.dart';
import '../../models/training_item.dart';
import '../../services/bungtemin_api.dart';
import 'training_ticket_screen.dart';

class TrainingPlenoScreen extends StatefulWidget {
  const TrainingPlenoScreen({
    super.key,
    this.session,
    this.initialEvents,
  });

  final UserSession? session;
  final List<TrainingEventItem>? initialEvents;

  @override
  State<TrainingPlenoScreen> createState() => _TrainingPlenoScreenState();
}

class _TrainingPlenoScreenState extends State<TrainingPlenoScreen> {
  final BungteminApi _api = BungteminApi();
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  List<TrainingEventItem> _trainings = const [];
  List<TrainingEventItem> _filteredTrainings = const [];

  int _page = 1;
  int _lastPage = 1;
  bool _loading = false;

  Map<String, bool> _registeredMap = {};
  final Map<String, bool> _loadingMap = {};

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _initScreen();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 120 &&
        !_loading &&
        _page < _lastPage) {
      _page++;
      _loadData(reset: false);
    }
  }

  Future<void> _initScreen() async {
    await _loadRegisteredMap();
    if (widget.initialEvents != null) {
      if (!mounted) return;
      setState(() {
        _trainings = widget.initialEvents!;
        _filteredTrainings = widget.initialEvents!;
      });
      return;
    }
    await _loadData(reset: true);
  }

  Future<void> _loadRegisteredMap() async {
    final cachedRaw = await SessionStore().loadTrainingTicketsCache();
    final tickets = TrainingTicketItem.decodeList(cachedRaw);
    final map = <String, bool>{};
    for (final t in tickets) {
      if (t.eventSlug.trim().isNotEmpty) {
        map[t.eventSlug.trim()] = true;
      }
    }
    if (!mounted) return;
    setState(() {
      _registeredMap = map;
    });
  }

  Future<void> _loadData({bool reset = false}) async {
    if (_loading && !reset) return;
    if (reset) {
      _page = 1;
    }
    setState(() => _loading = true);
    try {
      final resp = await _api.fetchTrainings(page: _page);
      if (!mounted) return;
      setState(() {
        _trainings = reset ? resp.data : [..._trainings, ...resp.data];
        _lastPage = resp.lastPage;
        _loading = false;
      });
      _applyFilter();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredTrainings = List<TrainingEventItem>.from(_trainings);
      } else {
        _filteredTrainings = _trainings
            .where(
              (t) =>
                  t.namaAcara.toLowerCase().contains(q) ||
                  t.tempat.toLowerCase().contains(q),
            )
            .toList();
      }
    });
  }

  void _showToast(String message, {Color bg = const Color(0xFF2563EB)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: bg,
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Future<void> _register(TrainingEventItem item) async {
    final key = item.eventSlug;
    if (_registeredMap[key] == true) {
      _showToast(
        'Anda sudah terdaftar pada agenda ini.',
        bg: const Color(0xFFD97706),
      );
      return;
    }

    final s = widget.session ?? await SessionStore().load();
    if (s == null) {
      _showToast(
        'Silakan login terlebih dahulu untuk mendaftar training.',
        bg: const Color(0xFFD97706),
      );
      return;
    }

    setState(() => _loadingMap[key] = true);
    try {
      await _api.registerTraining(session: s, trainingSlug: key);
      if (!mounted) return;
      setState(() {
        _registeredMap[key] = true;
        _loadingMap[key] = false;
      });
      _showToast(
        'Berhasil mendaftar! Tiket sudah masuk ke menu Tiket Saya.',
        bg: const Color(0xFF059669),
      );
    } on BungteminApiException catch (e) {
      if (!mounted) return;
      setState(() => _loadingMap[key] = false);
      _showToast(e.message, bg: const Color(0xFFDC2626));
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMap[key] = false);
      _showToast(
        'Terjadi kesalahan koneksi server.',
        bg: const Color(0xFFDC2626),
      );
    }
  }

  Future<void> _openTickets() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TrainingTicketScreen(session: widget.session),
      ),
    );
    await _loadRegisteredMap();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadRegisteredMap();
          await _loadData(reset: true);
        },
        child: CustomScrollView(
          controller: _scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
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
                        if (_loading && _filteredTrainings.isEmpty)
                          _buildLoadingBox()
                        else if (!_loading && _filteredTrainings.isEmpty)
                          _buildEmptyCard()
                        else
                          for (var i = 0;
                              i < _filteredTrainings.length;
                              i++) ...[
                            if (i > 0) const SizedBox(height: 14),
                            _PlenoEventCard(
                              item: _filteredTrainings[i],
                              isRegistered:
                                  _registeredMap[_filteredTrainings[i].eventSlug] ==
                                      true,
                              isLoading:
                                  _loadingMap[_filteredTrainings[i].eventSlug] ==
                                      true,
                              onRegister: () =>
                                  _register(_filteredTrainings[i]),
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
                          'Training',
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
              Material(
                color: Colors.white.withValues(alpha: 0.12),
                shape: StadiumBorder(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
                ),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: _openTickets,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.confirmation_number_outlined,
                          size: 16,
                          color: Colors.white,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Tiket Saya',
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
                    Icons.school_rounded,
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
                      'PENDIDIKAN & KADERISASI',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: Color(0xFF7DD3FC),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Training Pleno',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Daftar agenda pelatihan aktif & registrasi e-tiket',
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
                hintText: 'Cari nama acara atau lokasi...',
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

  Widget _buildLoadingBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text(
            'Memuat daftar training pleno...',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
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
            Icons.calendar_today_outlined,
            size: 36,
            color: Color(0xFF94A3B8),
          ),
          SizedBox(height: 8),
          Text(
            'Belum Ada Agenda Training',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Tarik ke bawah untuk memperbarui daftar kegiatan terbaru.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _PlenoEventCard extends StatelessWidget {
  const _PlenoEventCard({
    required this.item,
    required this.isRegistered,
    required this.isLoading,
    required this.onRegister,
  });

  final TrainingEventItem item;
  final bool isRegistered;
  final bool isLoading;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 26,
            offset: Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 142,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  item.thumbnailAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/hd/backdrop.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x1A0F172A),
                        Color(0x990F172A),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF0284C7)],
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Pleno',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                if (isRegistered)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xEB10B981),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Terdaftar',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.namaAcara,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: Color(0xFF0284C7),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        item.formattedTanggal,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Color(0xFF0284C7),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        item.tempat.isNotEmpty
                            ? item.tempat
                            : 'Lokasi belum tersedia',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: isRegistered
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 17,
                                color: Color(0xFF047857),
                              ),
                              SizedBox(width: 7),
                              Text(
                                'Sudah Terdaftar',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ],
                          ),
                        )
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1D4ED8), Color(0xFF0284C7)],
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x401D4ED8),
                                blurRadius: 18,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: isLoading ? null : onRegister,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            icon: isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.rocket_launch_outlined,
                                    size: 17,
                                  ),
                            label: const Text(
                              'Daftar Sekarang',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
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
  }
}
