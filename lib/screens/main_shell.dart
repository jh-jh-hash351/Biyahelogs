import 'package:flutter/material.dart';

import '../models/user.dart';
import '../models/vehicle.dart';
import '../services/database_service.dart';
import 'home_screen.dart';
import 'reports_screen.dart';
import 'vehicle_form_screen.dart';
import 'vehicles_screen.dart';

class MainShell extends StatefulWidget {
  final User user;
  final Future<void> Function() onLogout;

  const MainShell({
    super.key,
    required this.user,
    required this.onLogout,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _db = DatabaseService.instance;

  List<Vehicle> _vehicles = const [];
  Vehicle? _active;
  int _index = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles({int? preferId}) async {
    try {
      final vehicles = await _db.getVehicles(widget.user.id);
      if (vehicles.isEmpty) {
        if (!mounted) return;
        setState(() {
          _vehicles = vehicles;
          _active = null;
          _loading = false;
          _error = null;
        });
        return;
      }
      final savedId = preferId ??
          _active?.id ??
          await _db.getActiveVehicleId(widget.user.id);
      final active = vehicles.firstWhere(
        (vehicle) => vehicle.id == savedId,
        orElse: () => vehicles.first,
      );
      await _db.setActiveVehicleId(widget.user.id, active.id);
      if (!mounted) return;
      setState(() {
        _vehicles = vehicles;
        _active = active;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your vehicles. $error';
        _loading = false;
      });
    }
  }

  Future<void> _switchVehicle(Vehicle vehicle) async {
    await _db.setActiveVehicleId(widget.user.id, vehicle.id);
    if (!mounted) return;
    setState(() => _active = vehicle);
  }

  Future<void> _addFirstVehicle() async {
    final created = await Navigator.of(context).push<Vehicle>(
      MaterialPageRoute(
        builder: (_) => VehicleFormScreen(userId: widget.user.id),
      ),
    );
    if (created != null) await _loadVehicles(preferId: created.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              const Text('Loading your garage...'),
            ],
          ),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('BiyaheLog')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    size: 44, color: theme.colorScheme.error),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loadVehicles,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final active = _active;
    if (active == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('BiyaheLog'),
          actions: [
            IconButton(
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout),
              tooltip: 'Log out',
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.garage_outlined,
                    size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Add your first vehicle',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'BiyaheLog works with any vehicle — motorcycle, tricycle, car, van, truck, and more.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _addFirstVehicle,
                  icon: const Icon(Icons.add),
                  label: const Text('Add vehicle'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final pages = <Widget>[
      HomeScreen(
        key: ValueKey('home-${active.id}'),
        user: widget.user,
        vehicle: active,
        vehicles: _vehicles,
        onSwitchVehicle: _switchVehicle,
        onOpenGarage: () => setState(() => _index = 2),
        onLogout: widget.onLogout,
      ),
      ReportsScreen(
        key: ValueKey('reports-${active.id}'),
        vehicle: active,
      ),
      VehiclesScreen(
        user: widget.user,
        vehicles: _vehicles,
        activeVehicleId: active.id,
        onSetActive: _switchVehicle,
        onVehiclesChanged: _loadVehicles,
        onVehicleCreated: (vehicle) => _loadVehicles(preferId: vehicle.id),
      ),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.garage_outlined),
            selectedIcon: Icon(Icons.garage),
            label: 'Garage',
          ),
        ],
      ),
    );
  }
}
