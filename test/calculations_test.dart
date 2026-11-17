import 'package:flutter_test/flutter_test.dart';

import 'package:biyahe_log/models/log_entry.dart';
import 'package:biyahe_log/utils/calculations.dart';

LogEntry log({
  int id = 0,
  LogType type = LogType.fuel,
  DateTime? date,
  double? odometer,
  double cost = 500,
  double? liters,
}) {
  return LogEntry(
    id: id,
    userId: 1,
    vehicleId: 1,
    type: type,
    date: date ?? DateTime(2026, 1, 1),
    odometer: odometer,
    cost: cost,
    liters: liters,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('fuel efficiency', () {
    test('computes km/L between two fuel fill-ups', () {
      final logs = [
        log(id: 1, odometer: 1000, liters: 25),
        log(id: 2, odometer: 1300, liters: 10),
      ];

      final points = efficiencyPoints(logs);

      expect(points, hasLength(1));
      expect(points.single.distanceKm, 300);
      expect(points.single.efficiency, 30);
      expect(averageEfficiency(logs), 30);
    });

    test('averages across multiple fill-ups using total distance and fuel', () {
      final logs = [
        log(id: 1, odometer: 1000),
        log(id: 2, odometer: 1300, liters: 10),
        log(id: 3, odometer: 1800, liters: 20),
      ];

      expect(efficiencyPoints(logs), hasLength(2));
      expect(averageEfficiency(logs), closeTo(800 / 30, 0.0001));
    });

    test('ignores non-fuel logs and invalid odometer pairs', () {
      final logs = [
        log(id: 1, odometer: 1000, liters: 20),
        log(
          id: 2,
          type: LogType.oilChange,
          odometer: 1200,
          date: DateTime(2026, 1, 2),
        ),
        log(id: 3, odometer: 1000, liters: 10, date: DateTime(2026, 1, 3)),
      ];

      expect(efficiencyPoints(logs), isEmpty);
      expect(averageEfficiency(logs), isNull);
    });

    test('returns the efficiency point for a specific entry', () {
      final first = log(id: 1, odometer: 1000);
      final second = log(id: 2, odometer: 1500, liters: 25);
      final logs = [first, second];

      final point = efficiencyForEntry(second, logs);

      expect(point, isNotNull);
      expect(point!.previousEntry.id, 1);
      expect(point.efficiency, 20);
      expect(efficiencyForEntry(first, logs), isNull);
    });
  });

  group('odometer and maintenance', () {
    test('latest odometer is the highest reading', () {
      final logs = [
        log(id: 1, odometer: 1500),
        log(id: 2, odometer: 9000),
        log(id: 3, odometer: 3000),
      ];

      expect(latestOdometer(logs), 9000);
    });

    test('latest log of a type is picked by date', () {
      final logs = [
        log(
          id: 1,
          type: LogType.oilChange,
          date: DateTime(2025, 12, 1),
        ),
        log(
          id: 2,
          type: LogType.oilChange,
          date: DateTime(2026, 2, 1),
        ),
        log(id: 3, type: LogType.repair, date: DateTime(2026, 3, 1)),
      ];

      expect(latestLogOfType(logs, LogType.oilChange)!.id, 2);
      expect(latestLogOfType(logs, LogType.repair)!.id, 3);
      expect(latestLogOfType(logs, LogType.other), isNull);
    });
  });

  group('spending', () {
    final logs = [
      log(id: 1, date: DateTime(2026, 9, 3), cost: 1000),
      log(id: 2, date: DateTime(2026, 9, 18), cost: 500.5),
      log(
        id: 3,
        type: LogType.repair,
        date: DateTime(2026, 10, 2),
        cost: 2500,
      ),
      log(
        id: 4,
        type: LogType.oilChange,
        date: DateTime(2026, 8, 10),
        cost: 800,
      ),
    ];

    test('groups totals by month, newest first', () {
      final totals = monthlyTotals(logs);

      expect(totals, hasLength(3));
      expect(totals.first.month, 10);
      expect(totals.first.total, 2500);
      expect(totals[1].month, 9);
      expect(totals[1].total, 1500.5);
    });

    test('computes spend for a single month', () {
      expect(spendingInMonth(logs, DateTime(2026, 9)), 1500.5);
      expect(spendingInMonth(logs, DateTime(2026, 1)), 0);
    });

    test('breaks a month down by entry type', () {
      final byType = spendingByType(logs, DateTime(2026, 9));

      expect(byType[LogType.fuel], 1500.5);
      expect(byType[LogType.repair], 0);
      expect(byType[LogType.oilChange], 0);
    });
  });
}
