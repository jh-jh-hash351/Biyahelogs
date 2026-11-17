import '../models/log_entry.dart';

class MonthTotal {
  final int year;
  final int month;
  final double total;

  const MonthTotal(this.year, this.month, this.total);

  DateTime get date => DateTime(year, month);
}

class EfficiencyPoint {
  final LogEntry entry;
  final LogEntry previousEntry;
  final double distanceKm;
  final double efficiency;

  const EfficiencyPoint({
    required this.entry,
    required this.previousEntry,
    required this.distanceKm,
    required this.efficiency,
  });
}

List<LogEntry> sortedFuelEntries(List<LogEntry> logs) {
  final fuel = logs
      .where((log) => log.type == LogType.fuel && log.odometer != null)
      .toList();
  fuel.sort((a, b) {
    final byOdometer = a.odometer!.compareTo(b.odometer!);
    if (byOdometer != 0) return byOdometer;
    return a.date.compareTo(b.date);
  });
  return fuel;
}

List<EfficiencyPoint> efficiencyPoints(List<LogEntry> logs) {
  final fuel = sortedFuelEntries(logs);
  final points = <EfficiencyPoint>[];
  for (var i = 1; i < fuel.length; i++) {
    final previous = fuel[i - 1];
    final current = fuel[i];
    final liters = current.liters;
    final distance = current.odometer! - previous.odometer!;
    if (liters == null || liters <= 0 || distance <= 0) continue;
    points.add(
      EfficiencyPoint(
        entry: current,
        previousEntry: previous,
        distanceKm: distance,
        efficiency: distance / liters,
      ),
    );
  }
  return points;
}

EfficiencyPoint? efficiencyForEntry(LogEntry entry, List<LogEntry> logs) {
  if (entry.type != LogType.fuel) return null;
  for (final point in efficiencyPoints(logs)) {
    if (point.entry.id == entry.id) return point;
  }
  return null;
}

double? averageEfficiency(List<LogEntry> logs) {
  final points = efficiencyPoints(logs);
  if (points.isEmpty) return null;
  var distance = 0.0;
  var fuel = 0.0;
  for (final point in points) {
    distance += point.distanceKm;
    fuel += point.entry.liters!;
  }
  if (fuel <= 0) return null;
  return distance / fuel;
}

double? latestOdometer(List<LogEntry> logs) {
  double? latest;
  for (final log in logs) {
    final value = log.odometer;
    if (value == null) continue;
    if (latest == null || value > latest) latest = value;
  }
  return latest;
}

List<MonthTotal> monthlyTotals(List<LogEntry> logs) {
  final totals = <int, double>{};
  for (final log in logs) {
    final key = log.date.year * 100 + log.date.month;
    totals[key] = (totals[key] ?? 0) + log.cost;
  }
  final result = totals.entries
      .map((entry) => MonthTotal(entry.key ~/ 100, entry.key % 100, entry.value))
      .toList();
  result.sort((a, b) => b.date.compareTo(a.date));
  return result;
}

double spendingInMonth(List<LogEntry> logs, DateTime month) {
  return logs
      .where((log) => log.date.year == month.year && log.date.month == month.month)
      .fold(0.0, (sum, log) => sum + log.cost);
}

Map<LogType, double> spendingByType(List<LogEntry> logs, DateTime month) {
  final totals = {for (final type in LogType.values) type: 0.0};
  for (final log in logs) {
    if (log.date.year != month.year || log.date.month != month.month) continue;
    totals[log.type] = (totals[log.type] ?? 0) + log.cost;
  }
  return totals;
}

LogEntry? latestLogOfType(List<LogEntry> logs, LogType type) {
  LogEntry? latest;
  for (final log in logs) {
    if (log.type != type) continue;
    if (latest == null || log.date.isAfter(latest.date)) latest = log;
  }
  return latest;
}
