import 'package:flutter_test/flutter_test.dart';

import 'package:bungtemin_flutter/models/work_calendar.dart';

void main() {
  group('WorkYear fallback generator', () {
    final year = WorkYear.fromRows(
      2027,
      WorkYear.fallbackRows(2027),
      isFallback: true,
    );

    test('membuat 12 bulan dengan jumlah hari benar', () {
      expect(year.months.length, 12);
      expect(year.months[1].days.length, 28); // Februari 2027
      expect(year.months[0].days.length, 31);
    });

    test('minggu dimulai Senin (1 Jan 2027 = Jumat -> 4 sel kosong)', () {
      expect(year.months[0].blanks, 4);
    });

    test('hitung hari libur Januari 2027 (10 akhir pekan + 2 libur nasional)', () {
      final jan = year.months[0];
      expect(jan.offDays, 12);
      expect(jan.workDays, 19);
      expect(jan.holidays.length, 2);
      expect(jan.days.first.isHoliday, isTrue);
      expect(jan.days.first.description, 'Tahun Baru Masehi');
    });
  });

  group('WorkYear.fromRows (format HRPortal)', () {
    test('membaca WORKING_DATE dd-MM-yyyy dan DATE_COLOR', () {
      final year = WorkYear.fromRows(
        2026,
        [
          {
            'WORKING_DATE': '17-08-2026',
            'DATE_COLOR': '2',
            'NOTE': 'LIBUR NASIONAL',
            'DESCRIPTION': 'Hari Kemerdekaan Republik Indonesia',
          },
          {
            'WORKING_DATE': '18-08-2026',
            'DATE_COLOR': '1',
            'NOTE': '',
            'DESCRIPTION': '',
          },
          {'WORKING_DATE': '01-01-2025', 'DATE_COLOR': '1'},
        ],
        isFallback: false,
      );
      expect(year.months.length, 1);
      final agu = year.months.first;
      expect(agu.name, 'Agustus');
      expect(agu.days.length, 2);
      expect(agu.days.first.isHoliday, isTrue);
      expect(agu.days.last.note, 'Hari Kerja Efektif');
      expect(agu.blanks, 5); // 1 Agustus 2026 = Sabtu
    });
  });
}
