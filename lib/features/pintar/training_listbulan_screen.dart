import 'package:flutter/material.dart';

import '../../core/session_store.dart';
import '../../models/training_item.dart';
import '../../services/bungtemin_api.dart';
import 'training_pleno_screen.dart';

class TrainingListBulanScreen extends StatefulWidget {
  const TrainingListBulanScreen({
    super.key,
    this.session,
    this.initialEvents,
  });

  final UserSession? session;
  final List<TrainingEventItem>? initialEvents;

  @override
  State<TrainingListBulanScreen> createState() =>
      _TrainingListBulanScreenState();
}

class _TrainingListBulanScreenState extends State<TrainingListBulanScreen> {
  static const List<String> _months = [
    'Semua',
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  final BungteminApi _api = BungteminApi();
  List<TrainingEventItem> _events = const [];
  List<TrainingEventItem> _filteredEvents = const [];
  bool _isLoading = false;
  String _selectedMonth = 'Semua';

  @override
  void initState() {
    super.initState();
    if (widget.initialEvents != null) {
      _events = widget.initialEvents!;
      _filteredEvents = widget.initialEvents!;
    } else {
      _loadEvents();
    }
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      final resp = await _api.fetchTrainings(page: 1);
      if (!mounted) return;
      setState(() {
        _events = resp.data;
        _isLoading = false;
      });
      _applyFilter();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _selectMonth(String m) {
    setState(() {
      _selectedMonth = m;
    });
    _applyFilter();
  }

  void _applyFilter() {
    if (_selectedMonth == 'Semua') {
      setState(() {
        _filteredEvents = List<TrainingEventItem>.from(_events);
      });
      return;
    }
    final targetMonth = _months.indexOf(_selectedMonth);
    setState(() {
      _filteredEvents =
          _events.where((e) => e.monthNumber == targetMonth).toList();
    });
  }

  void _openPleno() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TrainingPlenoScreen(session: widget.session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: RefreshIndicator(
        onRefresh: _loadEvents,
        child: CustomScrollView(
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
                        if (_isLoading && _filteredEvents.isEmpty)
                          _buildLoadingBox()
                        else if (!_isLoading && _filteredEvents.isEmpty)
                          _buildEmptyCard()
                        else
                          for (var i = 0; i < _filteredEvents.length; i++) ...[
                            if (i > 0) const SizedBox(height: 12),
                            _MonthEventCard(
                              item: _filteredEvents[i],
                              onTap: _openPleno,
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
                  onTap: _openPleno,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.rocket_launch_outlined,
                          size: 15,
                          color: Colors.white,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Daftar Pleno',
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
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.26),
                  ),
                ),
                child: Image.asset(
                  'assets/icon/10.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.calendar_month_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REKAP AGENDA TRAINING',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: Color(0xFF7DD3FC),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Jadwal Per Bulan',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Filter agenda pelatihan & pendidikan berdasarkan bulan',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xE0E2E8F0),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < _months.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(_months[i]),
                    selected: _selectedMonth == _months[i],
                    onSelected: (_) => _selectMonth(_months[i]),
                    selectedColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _selectedMonth == _months[i]
                          ? const Color(0xFF0F172A)
                          : Colors.white,
                    ),
                    shape: const StadiumBorder(),
                  ),
                ],
              ],
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
            'Memuat agenda training...',
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
      child: Column(
        children: [
          const Icon(
            Icons.event_busy_outlined,
            size: 36,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 8),
          Text(
            'Belum Ada Agenda di $_selectedMonth',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pilih bulan lain atau "Semua" untuk melihat seluruh jadwal tersedia.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _MonthEventCard extends StatelessWidget {
  const _MonthEventCard({
    required this.item,
    required this.onTap,
  });

  final TrainingEventItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Agenda Training',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                  Text(
                    item.formattedTanggal,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.namaAcara,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: Color(0xFF0284C7),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            item.tempat.isNotEmpty
                                ? item.tempat
                                : 'Lokasi menyusul',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.2,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
