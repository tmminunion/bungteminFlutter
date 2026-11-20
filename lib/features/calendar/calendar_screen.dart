import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/work_calendar.dart';
import '../../services/work_calendar_service.dart';

/// Kalender kerja TMMIN, konsep dari bungteminAPP (`/kalender`):
/// hero aurora, pemilih tahun -3..+3, mode per bulan / 12 bulan,
/// statistik hari kerja, legenda, detail tanggal & daftar hari besar.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const _holidayRed = Color(0xFFDC2626);
  static const _holidayBg = Color(0xFFFEF2F2);

  final _service = WorkCalendarService();
  final _years = WorkCalendarService.availableYears();

  late int _year = DateTime.now().year;
  WorkYear? _data;
  bool _loading = true;
  bool _allMonths = false;
  int _monthIdx = DateTime.now().month - 1;
  WorkDay? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() => _loading = _data == null || force);
    final result = await _service.load(_year, forceRefresh: force);
    if (!mounted) return;
    setState(() {
      _data = result;
      _loading = false;
      if (_monthIdx >= result.months.length) _monthIdx = 0;
      _pickDefaultDay();
    });
  }

  WorkMonth? get _month {
    final d = _data;
    if (d == null || d.months.isEmpty) return null;
    return d.months[_monthIdx.clamp(0, d.months.length - 1)];
  }

  void _pickDefaultDay() {
    final m = _month;
    if (m == null) {
      _selected = null;
      return;
    }
    WorkDay? pick;
    for (final d in m.days) {
      if (d.isToday) {
        pick = d;
        break;
      }
    }
    if (pick == null) {
      for (final d in m.days) {
        if (d.hasEvent) {
          pick = d;
          break;
        }
      }
    }
    _selected = pick ?? m.days.first;
  }

  void _selectYear(int y) {
    if (y == _year && _data != null) return;
    setState(() => _year = y);
    _load();
  }

  void _moveMonth(int delta) {
    final d = _data;
    if (d == null || d.months.isEmpty) return;
    setState(() {
      _monthIdx = (_monthIdx + delta) % d.months.length;
      if (_monthIdx < 0) _monthIdx += d.months.length;
      _pickDefaultDay();
    });
  }

  Future<void> _refresh() async {
    await _load(force: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Kalender $_year diperbarui')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator(
        onRefresh: () => _load(force: true),
        edgeOffset: 80,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _hero(data),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: Transform.translate(
                offset: const Offset(0, -34),
                child: _body(data),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- hero
  Widget _hero(WorkYear? data) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(18, top + 14, 18, 52),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, AppColors.blueAccent, AppColors.sky],
          stops: [0, 0.58, 1],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _pill(
                icon: Icons.arrow_back_rounded,
                label: 'Beranda',
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const Spacer(),
              _pill(
                icon: _allMonths
                    ? Icons.calendar_month_rounded
                    : Icons.view_agenda_rounded,
                label: _allMonths ? 'Per Bulan' : '12 Bulan',
                onTap: () => setState(() => _allMonths = !_allMonths),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _refresh,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.auroraCyan.withValues(alpha: 0.2),
                    border: Border.all(
                      color: AppColors.auroraCyan.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 19,
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
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                child: Image.asset(
                  'assets/icon/10.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.event_note_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (data?.isFallback ?? false)
                          ? 'KALENDER KERJA & HARI BESAR NASIONAL'
                          : 'KALENDER KERJA BUNGTEMIN',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: Color(0xFF7DD3FC),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Kalender Kerja $_year',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Rentang ${_years.first} – ${_years.last}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AppColors.navy.withValues(alpha: 0.36),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: Row(
              children: [
                for (final y in _years)
                  Expanded(child: _yearChip(y)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _yearChip(int y) {
    final active = y == _year;
    final current = y == DateTime.now().year;
    return GestureDetector(
      onTap: () => _selectYear(y),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$y',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: active
                    ? AppColors.navy
                    : Colors.white.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: current
                    ? (active ? AppColors.primaryBlue : AppColors.auroraCyan)
                    : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- body
  Widget _body(WorkYear? data) {
    if (_loading && data == null) {
      return _card(
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (data == null || data.months.isEmpty) {
      return _card(
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Text('Data kalender belum tersedia. Tarik layar untuk memuat ulang.'),
        ),
      );
    }
    return _allMonths ? _allView(data) : _singleView(data);
  }

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _singleView(WorkYear data) {
    final m = _month!;
    final sel = _selected;
    return Column(
      children: [
        _card(
          child: Column(
            children: [
              Row(
                children: [
                  _arrow(Icons.chevron_left_rounded, () => _moveMonth(-1)),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${m.name} $_year',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          data.isFallback
                              ? 'Mode Auto-Kalender (Estimasi Otomatis)'
                              : 'Jadwal Kalender Kerja Bungtemin',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _arrow(Icons.chevron_right_rounded, () => _moveMonth(1)),
                ],
              ),
              const SizedBox(height: 12),
              _monthPills(data),
              const SizedBox(height: 12),
              Row(
                children: [
                  _stat('${m.workDays}', 'Hari Kerja', AppColors.primaryBlue),
                  const SizedBox(width: 8),
                  _stat('${m.offDays}', 'Libur/Off', _holidayRed),
                  const SizedBox(width: 8),
                  _stat('${m.holidays.length}', 'Hari Besar', AppColors.amber),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MonthGrid(
                month: m,
                selected: sel,
                onTap: (d) => setState(() => _selected = d),
              ),
              const SizedBox(height: 12),
              _legend(),
              if (sel != null) ...[
                const SizedBox(height: 14),
                _selectedBanner(m, sel),
              ],
            ],
          ),
        ),
        if (m.holidays.isNotEmpty) ...[
          const SizedBox(height: 16),
          _card(child: _holidayList(m, title: 'Hari Besar & Libur ${m.name} $_year')),
        ],
      ],
    );
  }

  Widget _allView(WorkYear data) {
    return Column(
      children: [
        for (final m in data.months) ...[
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${m.name} $_year',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                            ),
                          ),
                          Text(
                            '${m.workDays} hari kerja • ${m.offDays} hari libur',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (m.holidays.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _holidayBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${m.holidays.length} Hari Besar',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _holidayRed,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                _MonthGrid(month: m, compact: true),
                if (m.holidays.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _holidayList(m),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _arrow(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Icon(icon, color: AppColors.navySoft),
      ),
    );
  }

  Widget _monthPills(WorkYear data) {
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 6.0;
        final w = (c.maxWidth - gap * 5) / 6;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < data.months.length; i++)
              GestureDetector(
                onTap: () => setState(() {
                  _monthIdx = i;
                  _pickDefaultDay();
                }),
                child: Container(
                  width: w,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: i == _monthIdx
                        ? const LinearGradient(
                            colors: [AppColors.primaryBlue, AppColors.sky],
                          )
                        : null,
                    color: i == _monthIdx ? null : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: i == _monthIdx
                          ? Colors.transparent
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    data.months[i].shortName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: i == _monthIdx
                          ? Colors.white
                          : const Color(0xFF475569),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _stat(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend() {
    Widget item(Color bg, Color border, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: border),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              text,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
          ],
        );
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        item(Colors.white, const Color(0xFFCBD5E1), 'Hari Kerja'),
        item(_holidayBg, _holidayRed, 'Libur / Off'),
        item(AppColors.amber, AppColors.amber, 'Libur Nasional'),
        item(AppColors.primaryBlue, AppColors.primaryBlue, 'Hari Ini'),
      ],
    );
  }

  Widget _selectedBanner(WorkMonth m, WorkDay d) {
    final off = d.isHoliday;
    final color = off ? _holidayRed : AppColors.primaryBlue;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  d.num.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                Text(
                  m.shortName,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.note.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  d.description.isNotEmpty
                      ? d.description
                      : (off ? 'Libur Kerja / Akhir Pekan' : 'Hari Kerja Normal'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _holidayList(WorkMonth m, {String? title}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  size: 18, color: AppColors.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        for (final h in m.holidays)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _holidayBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${h.num}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _holidayRed,
                          height: 1,
                        ),
                      ),
                      Text(
                        m.shortName,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: _holidayRed,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        h.note.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: AppColors.muted,
                        ),
                      ),
                      Text(
                        h.description,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
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

/// Grid tanggal satu bulan (minggu mulai Senin).
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    this.selected,
    this.onTap,
    this.compact = false,
  });

  final WorkMonth month;
  final WorkDay? selected;
  final ValueChanged<WorkDay>? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[
      for (var i = 0; i < month.blanks; i++) const SizedBox.shrink(),
      for (final d in month.days) _cell(d),
    ];

    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < kDayNames.length; i++)
              Expanded(
                child: Center(
                  child: Text(
                    kDayNames[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: i >= 5
                          ? const Color(0xFFDC2626)
                          : AppColors.muted,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 7,
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: compact ? 3 : 5,
          crossAxisSpacing: compact ? 3 : 5,
          children: cells,
        ),
      ],
    );
  }

  Widget _cell(WorkDay d) {
    final isSel = selected != null && selected!.date == d.date;
    final today = d.isToday;
    final nationalHoliday = d.hasEvent && d.isHoliday;

    Color bg = Colors.white;
    Color fg = AppColors.navy;
    Color border = const Color(0xFFE2E8F0);
    if (d.isHoliday) {
      bg = const Color(0xFFFEF2F2);
      fg = const Color(0xFFDC2626);
      border = const Color(0xFFFECACA);
    }
    if (nationalHoliday) {
      bg = const Color(0xFFFEF3C7);
      border = AppColors.amber;
    }
    if (today) {
      bg = AppColors.primaryBlue;
      fg = Colors.white;
      border = AppColors.primaryBlue;
    }
    if (isSel && !today) {
      border = AppColors.primaryBlue;
    }

    final cell = Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(compact ? 8 : 12),
        border: Border.all(color: border, width: isSel ? 2 : 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            '${d.num}',
            style: TextStyle(
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
          if (d.hasEvent)
            Positioned(
              bottom: compact ? 3 : 5,
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: today ? Colors.white : AppColors.amber,
                ),
              ),
            ),
        ],
      ),
    );

    if (onTap == null) return cell;
    return GestureDetector(onTap: () => onTap!(d), child: cell);
  }
}
