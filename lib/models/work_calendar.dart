/// Model kalender kerja TMMIN (dipindahkan dari bungteminAPP `kalender.page.ts`).
///
/// Sumber data: HRPortal TMMIN (`WORKING_DATE` = `dd-MM-yyyy`, `DATE_COLOR`
/// '2' = libur/off, '1' = hari kerja). Bila tahun belum dirilis, dibuat
/// otomatis dari akhir pekan + daftar hari libur nasional ([fallbackRows]).
library;

const List<String> kDayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

const List<String> kShortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

const List<String> kFullMonths = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

class WorkDay {
  const WorkDay({
    required this.date,
    required this.isHoliday,
    required this.description,
    required this.note,
  });

  final DateTime date;
  final bool isHoliday;
  final String description;
  final String note;

  int get num => date.day;
  bool get hasEvent => description.isNotEmpty;

  bool get isToday {
    final now = DateTime.now();
    return now.year == date.year &&
        now.month == date.month &&
        now.day == date.day;
  }
}

class WorkMonth {
  const WorkMonth({
    required this.index,
    required this.days,
    required this.blanks,
  });

  /// 0 = Januari ... 11 = Desember
  final int index;
  final List<WorkDay> days;

  /// Jumlah sel kosong sebelum tanggal 1 (minggu dimulai Senin).
  final int blanks;

  String get name => kFullMonths[index];
  String get shortName => kShortMonths[index];
  int get workDays => days.where((d) => !d.isHoliday).length;
  int get offDays => days.where((d) => d.isHoliday).length;
  List<WorkDay> get holidays =>
      days.where((d) => d.isHoliday && d.hasEvent).toList();
}

class WorkYear {
  const WorkYear({
    required this.year,
    required this.months,
    required this.isFallback,
  });

  final int year;
  final List<WorkMonth> months;
  final bool isFallback;

  /// Bangun dari baris mentah HRPortal.
  factory WorkYear.fromRows(
    int year,
    List<Map<String, dynamic>> rows, {
    required bool isFallback,
  }) {
    final byMonth = <int, List<WorkDay>>{};
    for (final row in rows) {
      final parts = (row['WORKING_DATE'] ?? '').toString().split('-');
      if (parts.length != 3) continue;
      final d = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final y = int.tryParse(parts[2]);
      if (d == null || m == null || y == null || y != year) continue;
      if (m < 1 || m > 12) continue;

      final off = (row['DATE_COLOR'] ?? '').toString() == '2';
      final desc = (row['DESCRIPTION'] ?? '').toString().trim();
      final note = (row['NOTE'] ?? '').toString().trim();
      byMonth.putIfAbsent(m, () => []).add(
            WorkDay(
              date: DateTime(y, m, d),
              isHoliday: off,
              description: desc,
              note: note.isNotEmpty
                  ? note
                  : (off ? 'Libur Akhir Pekan / Off' : 'Hari Kerja Efektif'),
            ),
          );
    }

    final months = <WorkMonth>[];
    for (var m = 1; m <= 12; m++) {
      final days = byMonth[m];
      if (days == null || days.isEmpty) continue;
      days.sort((a, b) => a.date.compareTo(b.date));
      months.add(
        WorkMonth(
          index: m - 1,
          days: days,
          blanks: DateTime(year, m, 1).weekday - 1,
        ),
      );
    }
    return WorkYear(year: year, months: months, isFallback: isFallback);
  }

  /// Generator otomatis untuk tahun yang belum dirilis HRPortal.
  static List<Map<String, dynamic>> fallbackRows(int year) {
    final holidays = nationalHolidays(year);
    final rows = <Map<String, dynamic>>[];
    for (var m = 1; m <= 12; m++) {
      final daysInMonth = DateTime(year, m + 1, 0).day;
      for (var d = 1; d <= daysInMonth; d++) {
        final key = '${_p2(d)}-${_p2(m)}-$year';
        final wd = DateTime(year, m, d).weekday;
        final weekend = wd == DateTime.saturday || wd == DateTime.sunday;
        final desc = holidays[key] ?? '';
        final off = weekend || desc.isNotEmpty;
        rows.add({
          'WORKING_DATE': key,
          'DATE_COLOR': off ? '2' : '1',
          'NOTE': desc.isNotEmpty ? 'LIBUR NASIONAL' : '',
          'DESCRIPTION': desc,
        });
      }
    }
    return rows;
  }

  static String _p2(int n) => n < 10 ? '0$n' : '$n';

  /// Libur nasional tetap + estimasi hari raya (key `dd-MM-yyyy`).
  static Map<String, String> nationalHolidays(int year) {
    final fixed = <String, String>{
      '01-01-$year': 'Tahun Baru Masehi',
      '01-05-$year': 'Hari Buruh Internasional',
      '01-06-$year': 'Hari Lahir Pancasila',
      '17-08-$year': 'Hari Kemerdekaan Republik Indonesia',
      '25-12-$year': 'Hari Raya Natal',
    };
    return {...fixed, ...?_movable[year]};
  }

  static const Map<int, Map<String, String>> _movable = {
    2024: {
      '08-02-2024': "Isra Mi'raj Nabi Muhammad SAW",
      '10-02-2024': 'Tahun Baru Imlek',
      '11-03-2024': 'Hari Suci Nyepi',
      '29-03-2024': 'Wafat Yesus Kristus',
      '31-03-2024': 'Hari Paskah',
      '10-04-2024': 'Hari Raya Idul Fitri 1445 H',
      '11-04-2024': 'Hari Raya Idul Fitri 1445 H',
      '09-05-2024': 'Kenaikan Yesus Kristus',
      '23-05-2024': 'Hari Raya Waisak',
      '17-06-2024': 'Hari Raya Idul Adha 1445 H',
      '07-07-2024': 'Tahun Baru Islam 1446 H',
      '16-09-2024': 'Maulid Nabi Muhammad SAW',
    },
    2025: {
      '27-01-2025': "Isra Mi'raj Nabi Muhammad SAW",
      '29-01-2025': 'Tahun Baru Imlek',
      '29-03-2025': 'Hari Suci Nyepi',
      '31-03-2025': 'Hari Raya Idul Fitri 1446 H',
      '01-04-2025': 'Hari Raya Idul Fitri 1446 H',
      '18-04-2025': 'Wafat Yesus Kristus',
      '12-05-2025': 'Hari Raya Waisak',
      '29-05-2025': 'Kenaikan Yesus Kristus',
      '06-06-2025': 'Hari Raya Idul Adha 1446 H',
      '27-06-2025': 'Tahun Baru Islam 1447 H',
      '05-09-2025': 'Maulid Nabi Muhammad SAW',
    },
    2026: {
      '16-01-2026': "Isra Mi'raj Nabi Muhammad SAW",
      '17-02-2026': 'Tahun Baru Imlek',
      '19-03-2026': 'Hari Suci Nyepi',
      '20-03-2026': 'Hari Raya Idul Fitri 1447 H',
      '21-03-2026': 'Hari Raya Idul Fitri 1447 H',
      '03-04-2026': 'Wafat Yesus Kristus',
      '14-05-2026': 'Kenaikan Yesus Kristus',
      '27-05-2026': 'Hari Raya Idul Adha 1447 H',
      '31-05-2026': 'Hari Raya Waisak',
      '16-06-2026': 'Tahun Baru Islam 1448 H',
      '25-08-2026': 'Maulid Nabi Muhammad SAW',
    },
    2027: {
      '05-01-2027': "Isra Mi'raj Nabi Muhammad SAW",
      '06-02-2027': 'Tahun Baru Imlek',
      '09-03-2027': 'Hari Raya Idul Fitri 1448 H',
      '10-03-2027': 'Hari Raya Idul Fitri 1448 H',
      '26-03-2027': 'Wafat Yesus Kristus',
      '07-04-2027': 'Hari Suci Nyepi',
      '06-05-2027': 'Kenaikan Yesus Kristus',
      '16-05-2027': 'Hari Raya Idul Adha 1448 H',
      '20-05-2027': 'Hari Raya Waisak',
      '06-06-2027': 'Tahun Baru Islam 1449 H',
      '14-08-2027': 'Maulid Nabi Muhammad SAW',
    },
    2028: {
      '26-01-2028': 'Tahun Baru Imlek',
      '26-02-2028': 'Hari Raya Idul Fitri 1449 H',
      '27-02-2028': 'Hari Raya Idul Fitri 1449 H',
      '26-03-2028': 'Hari Suci Nyepi',
      '14-04-2028': 'Wafat Yesus Kristus',
      '05-05-2028': 'Hari Raya Idul Adha 1449 H',
      '09-05-2028': 'Hari Raya Waisak',
      '25-05-2028': 'Kenaikan Yesus Kristus & Tahun Baru Islam 1450 H',
      '03-08-2028': 'Maulid Nabi Muhammad SAW',
      '14-12-2028': "Isra Mi'raj Nabi Muhammad SAW",
    },
    2029: {
      '13-02-2029': 'Tahun Baru Imlek',
      '14-02-2029': 'Hari Raya Idul Fitri 1450 H',
      '15-02-2029': 'Hari Raya Idul Fitri 1450 H',
      '15-03-2029': 'Hari Suci Nyepi',
      '30-03-2029': 'Wafat Yesus Kristus',
      '24-04-2029': 'Hari Raya Idul Adha 1450 H',
      '10-05-2029': 'Kenaikan Yesus Kristus',
      '14-05-2029': 'Tahun Baru Islam 1451 H',
      '27-05-2029': 'Hari Raya Waisak',
      '22-07-2029': 'Maulid Nabi Muhammad SAW',
      '03-12-2029': "Isra Mi'raj Nabi Muhammad SAW",
    },
  };
}
