import 'package:flutter/material.dart';

import '../models/log_entry.dart';
import '../models/vehicle.dart';
import '../services/database_service.dart';
import '../utils/calculations.dart';
import '../utils/formatters.dart';
import '../utils/log_type_ui.dart';
import 'log_form_screen.dart';

class LogDetailScreen extends StatefulWidget {
  final Vehicle vehicle;
  final LogEntry log;

  const LogDetailScreen({
    super.key,
    required this.vehicle,
    required this.log,
  });

  @override
  State<LogDetailScreen> createState() => _LogDetailScreenState();
}

class _LogDetailScreenState extends State<LogDetailScreen> {
  final _db = DatabaseService.instance;

  late LogEntry _log;
  List<LogEntry> _allLogs = const [];

  @override
  void initState() {
    super.initState();
    _log = widget.log;
    _load();
  }

  Future<void> _load() async {
    final logs = await _db.getLogsForVehicle(widget.vehicle.id);
    final fresh = await _db.getLog(_log.id);
    if (!mounted) return;
    setState(() {
      _allLogs = logs;
      if (fresh != null) _log = fresh;
    });
  }

  Future<void> _edit() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LogFormScreen(
          vehicle: widget.vehicle,
          existing: _log,
        ),
      ),
    );
    await _load();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: const Text(
          'This log entry will be removed permanently. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _db.deleteLog(_log.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final efficiency = efficiencyForEntry(_log, _allLogs);
    final pricePerUnit =
        _log.liters != null && _log.liters! > 0 ? _log.cost / _log.liters! : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log details'),
        actions: [
          IconButton(
            onPressed: _edit,
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit entry',
          ),
          IconButton(
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete entry',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: _log.type.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _log.type.icon,
                    size: 28,
                    color: _log.type.color,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _log.type.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        formatLongDate(_log.date),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatMoney(_log.cost),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _DetailCard(
            title: 'Entry details',
            children: [
              _DetailRow(
                label: 'Vehicle',
                value: '${widget.vehicle.name} (${widget.vehicle.type})',
              ),
              if (_log.odometer != null)
                _DetailRow(
                  label: 'Odometer',
                  value: formatDistance(_log.odometer!),
                ),
              if (_log.liters != null)
                _DetailRow(
                  label: widget.vehicle.isElectric
                      ? 'Electricity used'
                      : 'Liters filled',
                  value:
                      '${formatDecimal(_log.liters!)} ${widget.vehicle.fuelUnit}',
                ),
              if (pricePerUnit != null)
                _DetailRow(
                  label: 'Price per ${widget.vehicle.fuelUnit}',
                  value: formatMoney(pricePerUnit),
                ),
              if (_log.type == LogType.fuel &&
                  efficiency == null) ...[
                const _DetailRow(
                  label: 'Fuel efficiency',
                  value: 'Needs another fuel log',
                ),
              ],
              if (efficiency != null) ...[
                _DetailRow(
                  label: 'Distance since last fill-up',
                  value: formatDistance(efficiency.distanceKm),
                ),
                _DetailRow(
                  label: 'Fuel efficiency',
                  value: formatEfficiency(
                    efficiency.efficiency,
                    widget.vehicle.efficiencyUnit,
                  ),
                  highlight: true,
                ),
              ],
            ],
          ),
          if (_log.notes != null) ...[
            const SizedBox(height: 16),
            _DetailCard(
              title: 'Notes',
              children: [
                Text(
                  _log.notes!,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ],
            ),
          ],
          if (_log.type == LogType.fuel && efficiency == null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Add another fuel entry with a higher odometer reading to compute km/L.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _DetailRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                color: highlight ? theme.colorScheme.primary : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
