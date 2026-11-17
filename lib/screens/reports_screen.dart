import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/log_entry.dart';
import '../models/vehicle.dart';
import '../services/database_service.dart';
import '../utils/calculations.dart';
import '../utils/formatters.dart';
import '../utils/log_type_ui.dart';
import '../widgets/summary_tile.dart';

class ReportsScreen extends StatefulWidget {
  final Vehicle vehicle;

  const ReportsScreen({super.key, required this.vehicle});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _db = DatabaseService.instance;

  List<LogEntry> _logs = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final logs = await _db.getLogsForVehicle(widget.vehicle.id);
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load the report. $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final totalSpent = _logs.fold<double>(0, (sum, log) => sum + log.cost);
    final monthSpend = spendingInMonth(_logs, now);
    final average = averageEfficiency(_logs);
    final odometer = latestOdometer(_logs);
    final byType = spendingByType(_logs, now);
    final maxTypeSpend = byType.values.fold<double>(0, math.max);
    final efficiency = efficiencyPoints(_logs).reversed.take(5).toList();
    final months = List<DateTime>.generate(
      6,
      (index) => DateTime(now.year, now.month - 5 + index),
    );
    final monthlyValues = months
        .map((month) => spendingInMonth(_logs, month))
        .toList();
    final lastOilChange = latestLogOfType(_logs, LogType.oilChange);
    final lastRepair = latestLogOfType(_logs, LogType.repair);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spending report'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(
          theme,
          totalSpent: totalSpent,
          monthSpend: monthSpend,
          average: average,
          odometer: odometer,
          byType: byType,
          maxTypeSpend: maxTypeSpend,
          efficiency: efficiency,
          months: months,
          monthlyValues: monthlyValues,
          lastOilChange: lastOilChange,
          lastRepair: lastRepair,
        ),
      ),
    );
  }

  Widget _buildBody(
    ThemeData theme, {
    required double totalSpent,
    required double monthSpend,
    required double? average,
    required double? odometer,
    required Map<LogType, double> byType,
    required double maxTypeSpend,
    required List<EfficiencyPoint> efficiency,
    required List<DateTime> months,
    required List<double> monthlyValues,
    required LogEntry? lastOilChange,
    required LogEntry? lastRepair,
  }) {
    final colorScheme = theme.colorScheme;
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 220),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(Icons.error_outline, size: 44, color: colorScheme.error),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Center(
            child: FilledButton(
              onPressed: _load,
              child: const Text('Try again'),
            ),
          ),
        ],
      );
    }
    final now = DateTime.now();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  vehicleIcon(widget.vehicle.type),
                  color: colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.vehicle.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${widget.vehicle.type} · ${widget.vehicle.engine}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Total spent',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimary.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatMoney(totalSpent),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SummaryTile(
                icon: Icons.payments_outlined,
                color: colorScheme.primary,
                label: formatMonthYear(now),
                value: formatMoney(monthSpend),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SummaryTile(
                icon: Icons.speed,
                color: const Color(0xFFEA8C00),
                label: 'Avg ${widget.vehicle.efficiencyUnit}',
                value: average == null ? '—' : formatDecimal(average),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SummaryTile(
                icon: Icons.route_outlined,
                color: const Color(0xFF2563EB),
                label: 'Odometer',
                value: odometer == null ? '—' : formatDistance(odometer),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SummaryTile(
                icon: Icons.receipt_long,
                color: const Color(0xFF7C3AED),
                label: 'Log entries',
                value: '${_logs.length}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ReportCard(
          title: 'Monthly spending',
          subtitle: 'Last 6 months',
          child: _MonthlyBars(months: months, values: monthlyValues),
        ),
        const SizedBox(height: 16),
        _ReportCard(
          title: 'This month by type',
          subtitle: formatMonthYear(now),
          child: maxTypeSpend == 0
              ? Text(
                  'No expenses recorded this month yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              : Column(
                  children: LogType.values
                      .where((type) => (byType[type] ?? 0) > 0)
                      .map(
                        (type) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _BreakdownRow(
                            type: type,
                            amount: byType[type] ?? 0,
                            maxAmount: maxTypeSpend,
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 16),
        _ReportCard(
          title: 'Fuel efficiency',
          subtitle: average == null
              ? 'Needs at least two fuel logs'
              : 'Average ${formatEfficiency(average, widget.vehicle.efficiencyUnit)}',
          child: efficiency.isEmpty
              ? Text(
                  'Log two or more fuel fill-ups with odometer readings to compute ${widget.vehicle.efficiencyUnit}.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              : Column(
                  children: efficiency
                      .map(
                        (point) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEA8C00)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.local_gas_station,
                                  size: 18,
                                  color: Color(0xFFEA8C00),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      formatDate(point.entry.date),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${formatDistance(point.distanceKm)} on ${formatDecimal(point.entry.liters!)} ${widget.vehicle.fuelUnit}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                        color:
                                            colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                formatEfficiency(
                                  point.efficiency,
                                  widget.vehicle.efficiencyUnit,
                                ),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 16),
        _ReportCard(
          title: 'Upkeep history',
          subtitle: 'Latest maintenance records',
          child: Column(
            children: [
              _UpkeepRow(
                icon: LogType.oilChange.icon,
                color: LogType.oilChange.color,
                label: 'Last oil change',
                log: lastOilChange,
              ),
              const SizedBox(height: 10),
              _UpkeepRow(
                icon: LogType.repair.icon,
                color: LogType.repair.color,
                label: 'Last repair',
                log: lastRepair,
              ),
            ],
          ),
        ),
        if (_logs.isEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Add log entries from the Home tab to see spending and efficiency trends here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ReportCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _MonthlyBars extends StatelessWidget {
  final List<DateTime> months;
  final List<double> values;

  const _MonthlyBars({required this.months, required this.values});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final maxValue = values.fold<double>(0, math.max);
    return SizedBox(
      height: 170,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(months.length, (index) {
          final total = values[index];
          final factor = maxValue <= 0 ? 0.0 : total / maxValue;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (total > 0)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formatCompactMoney(total),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Container(
                    height: total > 0 ? 12 + 92 * factor : 6,
                    decoration: BoxDecoration(
                      color: total > 0
                          ? colorScheme.primary
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatMonth(months[index]),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final LogType type;
  final double amount;
  final double maxAmount;

  const _BreakdownRow({
    required this.type,
    required this.amount,
    required this.maxAmount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final factor = maxAmount <= 0 ? 0.0 : amount / maxAmount;
    return Column(
      children: [
        Row(
          children: [
            Icon(type.icon, size: 18, color: type.color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                type.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              formatMoney(amount),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: factor,
            minHeight: 8,
            color: type.color,
            backgroundColor: type.color.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }
}

class _UpkeepRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final LogEntry? log;

  const _UpkeepRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.log,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = log;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                entry == null
                    ? 'Not logged yet'
                    : '${formatDate(entry.date)}'
                        '${entry.odometer == null ? '' : ' · ${formatDistance(entry.odometer!)}'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (entry != null)
          Text(
            formatMoney(entry.cost),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}
