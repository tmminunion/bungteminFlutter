import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bungtemin_flutter/features/proker/proker_screen.dart';
import 'package:bungtemin_flutter/models/proker_item.dart';

void main() {
  group('BidangProker model', () {
    test('provides 7 standard PUK bidang and filters by bidang/program', () {
      expect(BidangProker.defaults.length, 7);
      expect(BidangProker.defaults.first.formattedBadge, 'Bidang 01');

      final byName = BidangProker.filter(BidangProker.defaults, 'hipp');
      expect(byName.length, 1);
      expect(byName.first.bidang, 'HIPP');

      final byProgram = BidangProker.filter(BidangProker.defaults, 'PKB');
      expect(byProgram.length, 1);
      expect(byProgram.first.bidang, 'Pendidikan');
    });
  });

  testWidgets('ProkerScreen renders 7 bidang, filters search & opens detail sheet',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProkerScreen(),
      ),
    );

    expect(find.text('Program Kerja'), findsOneWidget);
    expect(find.text('7 Bidang'), findsOneWidget);
    expect(find.text('Bidang Kesekertariatan'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'HIPP');
    await tester.pumpAndSettle();

    expect(find.text('Bidang HIPP'), findsOneWidget);
    expect(find.text('Bidang Kesekertariatan'), findsNothing);

    await tester.tap(find.text('Bidang HIPP'));
    await tester.pumpAndSettle();

    expect(find.text('Fokus Program Kerja'), findsOneWidget);
    expect(
      find.textContaining('LKS Bipartit'),
      findsOneWidget,
    );
  });
}
