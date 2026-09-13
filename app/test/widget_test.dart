import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gizilacak/theme/apple.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id'));

  testWidgets('status chip renders Indonesian label', (tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: Center(child: StatusChip('Draf', tone: ChipTone.warn)),
      ),
    );
    expect(find.text('Draf'), findsOneWidget);
  });

  testWidgets('grouped section draws a hairline between rows only', (tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoPageScaffold(
          child: GlSection(
            header: 'Produksi',
            children: [
              GlRow(title: 'Draf', value: '2'),
              GlRow(title: 'Siap kirim', value: '1'),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Produksi'), findsOneWidget);
    expect(find.byType(GlHairline), findsOneWidget);
  });

  group('consumptionWindow never says "aman"', () {
    final cookedNow = DateTime(2026, 9, 12, 10);

    test('reports the window as still open', () {
      final result = consumptionWindow(
        cookedNow.add(const Duration(hours: 4)),
        now: cookedNow,
      );
      expect(result.text, 'Masih dalam batas waktu konsumsi');
      expect(result.tone, ChipTone.good);
    });

    test('warns as the limit approaches', () {
      final result = consumptionWindow(
        cookedNow.add(const Duration(minutes: 30)),
        now: cookedNow,
      );
      expect(result.text, 'Mendekati batas waktu');
      expect(result.tone, ChipTone.warn);
    });

    test('states the limit has passed', () {
      final result = consumptionWindow(
        cookedNow.subtract(const Duration(minutes: 1)),
        now: cookedNow,
      );
      expect(result.text, 'Melewati batas waktu konsumsi');
      expect(result.tone, ChipTone.bad);
    });

    test('falls back to unverified when nothing was recorded', () {
      final result = consumptionWindow(null, now: cookedNow);
      expect(result.text, 'Data belum dapat diverifikasi');
      expect(result.tone, ChipTone.neutral);
    });
  });

  group('day grouping', () {
    final now = DateTime(2026, 9, 12, 8);

    test('names today and yesterday', () {
      expect(dayLabel(DateTime(2026, 9, 12, 19), now: now), 'Hari ini');
      expect(dayLabel(DateTime(2026, 9, 11), now: now), 'Kemarin');
    });

    test('spells out older days', () {
      expect(dayLabel(DateTime(2026, 9, 8), now: now), contains('September'));
      expect(dayLabel(DateTime(2025, 4, 2), now: now), '2 April 2025');
    });

    test('buckets rows in the order the API returned them', () {
      final groups = groupByDay(
        [
          {'code': 'A', 'production_date': '2026-09-12'},
          {'code': 'B', 'production_date': '2026-09-12'},
          {'code': 'C', 'production_date': '2026-09-11'},
          {'code': 'D'},
        ],
        'production_date',
      );
      expect(groups.map((g) => g.label).toList(), [
        dayLabel(DateTime(2026, 9, 12)),
        dayLabel(DateTime(2026, 9, 11)),
        'Tanpa tanggal',
      ]);
      expect(groups.first.rows.map((r) => r['code']).toList(), ['A', 'B']);
    });
  });
}
