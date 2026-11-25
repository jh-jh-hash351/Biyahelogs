import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../models/log_entry.dart';
import '../models/user.dart';
import '../models/vehicle.dart';
import '../services/database_service.dart';
import '../utils/calculations.dart';
import '../utils/formatters.dart';
import '../widgets/empty_state.dart';
import '../widgets/log_tile.dart';
import '../widgets/summary_tile.dart';
import 'log_detail_screen.dart';
import 'log_form_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final User user;
  final Vehicle vehicle;
  final List<Vehicle> vehicles;
  final Future<void> Function(Vehicle vehicle) onSwitchVehicle;
  final VoidCallback onOpenRecentLogs;
  final VoidCallback onOpenGarage;
  final Future<void> Function() onLogout;

  const HomeScreen({
    super.key,
    required this.user,
    required this.vehicle,
    required this.vehicles,
    required this.onSwitchVehicle,
    required this.onOpenRecentLogs,
    required this.onOpenGarage,
    required this.onLogout,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseService.instance;

  List<LogEntry> _logs = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vehicle.id != widget.vehicle.id) {
      _load();
    }
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
        _error = 'Could not load your logs. $error';
        _loading = false;
      });
    }
  }

  Future<void> _openAdd({LogType? initialType}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LogFormScreen(
          vehicle: widget.vehicle,
          initialType: initialType,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _openDetail(LogEntry log) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LogDetailScreen(vehicle: widget.vehicle, log: log),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _showVehiclePicker() async {
    final selection = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    Text(
                      'Switch vehicle',
                      style: Theme.of(sheetContext)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ...widget.vehicles.map(
                      (vehicle) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(sheetContext)
                              .colorScheme
                              .primaryContainer,
                          child: Icon(vehicleIcon(vehicle.type)),
                        ),
                        title: Text(vehicle.name),
                        subtitle: Text('${vehicle.type} · ${vehicle.engine}'),
                        trailing: vehicle.id == widget.vehicle.id
                            ? Icon(
                                Icons.check_circle,
                                color: Theme.of(sheetContext)
                                    .colorScheme
                                    .primary,
                              )
                            : null,
                        onTap: () =>
                            Navigator.of(sheetContext).pop(vehicle),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.garage_outlined),
                title: const Text('Manage vehicles'),
                onTap: () => Navigator.of(sheetContext).pop('manage'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (!mounted) return;
    if (selection is Vehicle && selection.id != widget.vehicle.id) {
      await widget.onSwitchVehicle(selection);
    } else if (selection == 'manage') {
      widget.onOpenGarage();
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'Your account, vehicles, and logs stay saved on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final monthSpend = spendingInMonth(_logs, now);
    final average = averageEfficiency(_logs);
    final odometer = latestOdometer(_logs);
    final lastOilChange = latestLogOfType(_logs, LogType.oilChange);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.route, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text(
              'BiyaheLog',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Account',
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (value) {
              if (value == 'garage') widget.onOpenGarage();
              if (value == 'settings') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              }
              if (value == 'logout') _confirmLogout();
            },
            itemBuilder: (menuContext) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.user.username,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Local account',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'garage',
                child: Row(
                  children: [
                    Icon(Icons.garage_outlined),
                    SizedBox(width: 10),
                    Text('My garage'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined),
                    SizedBox(width: 10),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 10),
                    Text('Log out'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAdd(),
        icon: const Icon(Icons.add),
        label: const Text('Add log'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(
          theme,
          monthSpend: monthSpend,
          average: average,
          odometer: odometer,
          lastOilChange: lastOilChange,
        ),
      ),
    );
  }

  Widget _buildBody(
    ThemeData theme, {
    required double monthSpend,
    required double? average,
    required double? odometer,
    required LogEntry? lastOilChange,
  }) {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 220),
          Center(
            child: LoadingAnimationWidget.beat(
              color: theme.colorScheme.primary,
              size: 44,
            ),
          ),
        ],
      );
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(Icons.error_outline, size: 44, color: theme.colorScheme.error),
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
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        _VehicleCard(
          vehicle: widget.vehicle,
          vehicleCount: widget.vehicles.length,
          onTap: _showVehiclePicker,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SummaryTile(
                icon: Icons.payments_outlined,
                color: theme.colorScheme.primary,
                label: 'This month',
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
            const SizedBox(width: 10),
            Expanded(
              child: SummaryTile(
                icon: Icons.route_outlined,
                color: const Color(0xFF2563EB),
                label: 'Odometer',
                value: odometer == null ? '—' : formatDistance(odometer),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _MaintenanceCard(
          vehicle: widget.vehicle,
          lastOilChange: lastOilChange,
          latestOdometer: odometer,
          onLogOilChange: () => _openAdd(initialType: LogType.oilChange),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Text(
              'Recent logs',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (_logs.isNotEmpty)
              TextButton(
                onPressed: widget.onOpenRecentLogs,
                child: const Text('View all'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_logs.isEmpty)
          EmptyState(
            icon: Icons.receipt_long,
            title: 'No biyahe logged yet',
            message:
                'Track fuel, oil changes, repairs, and other expenses for ${widget.vehicle.name}.',
            actionLabel: 'Add your first log',
            onAction: () => _openAdd(),
          )
        else ...[
          // Preview of recent logs
          ..._logs.take(4).map(
            (log) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: LogTile(
                log: log,
                fuelUnit: widget.vehicle.fuelUnit,
                onTap: () => _openDetail(log),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: widget.onOpenRecentLogs,
              icon: const Icon(Icons.receipt_long_outlined),
              label: Text(
                'Recent logs (${_logs.length} ${_logs.length == 1 ? "entry" : "entries"})',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final int vehicleCount;
  final VoidCallback onTap;

  const _VehicleCard({
    required this.vehicle,
    required this.vehicleCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: colorScheme.primary,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  vehicleIcon(vehicle.type),
                  color: colorScheme.onPrimary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${vehicle.type}  ·  ${vehicle.engine}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                    if (vehicle.plateNumber != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          vehicle.plateNumber!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onPrimary,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Icon(
                    vehicleCount > 1
                        ? Icons.unfold_more
                        : Icons.edit_outlined,
                    color: colorScheme.onPrimary,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    vehicleCount > 1 ? 'Switch' : 'Vehicle',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimary.withValues(alpha: 0.8),
                    ),
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

class _MaintenanceCard extends StatelessWidget {
  final Vehicle vehicle;
  final LogEntry? lastOilChange;
  final double? latestOdometer;
  final VoidCallback onLogOilChange;

  const _MaintenanceCard({
    required this.vehicle,
    required this.lastOilChange,
    required this.latestOdometer,
    required this.onLogOilChange,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final oil = lastOilChange;
    double? kmSince;
    int? daysSince;
    if (oil != null) {
      daysSince = DateTime.now().difference(oil.date).inDays;
      if (oil.odometer != null &&
          latestOdometer != null &&
          latestOdometer! >= oil.odometer!) {
        kmSince = latestOdometer! - oil.odometer!;
      }
    }
    final due = (kmSince != null && kmSince >= 5000) ||
        (daysSince != null && daysSince >= 180);
    final statusColor = oil == null
        ? colorScheme.outline
        : (due ? colorScheme.error : const Color(0xFF15803D));
    final sinceText = kmSince != null
        ? '${formatWhole(kmSince)} km since the last oil change.'
        : daysSince != null
            ? '$daysSince days since the last oil change.'
            : 'Add odometer readings to track distance since the last change.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.oil_barrel, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Oil change',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Maintenance reminder',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  oil == null ? 'No data' : (due ? 'Due' : 'On track'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (oil == null)
            Text(
              'No oil change logged yet. Add one to start your upkeep history.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            Text(
              'Last changed ${formatDate(oil.date)}'
              '${oil.odometer == null ? '' : ' at ${formatDistance(oil.odometer!)}'}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              sinceText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (due) ...[
              const SizedBox(height: 4),
              Text(
                'Consider scheduling an oil change soon.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onLogOilChange,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Log oil change'),
            ),
          ),
        ],
      ),
    );
  }
}
