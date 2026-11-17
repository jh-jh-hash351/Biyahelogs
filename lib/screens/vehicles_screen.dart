import 'package:flutter/material.dart';

import '../models/user.dart';
import '../models/vehicle.dart';
import '../services/database_service.dart';
import '../utils/formatters.dart';
import '../widgets/empty_state.dart';
import 'vehicle_form_screen.dart';

class VehiclesScreen extends StatelessWidget {
  final User user;
  final List<Vehicle> vehicles;
  final int activeVehicleId;
  final Future<void> Function(Vehicle vehicle) onSetActive;
  final Future<void> Function() onVehiclesChanged;
  final Future<void> Function(Vehicle vehicle) onVehicleCreated;

  const VehiclesScreen({
    super.key,
    required this.user,
    required this.vehicles,
    required this.activeVehicleId,
    required this.onSetActive,
    required this.onVehiclesChanged,
    required this.onVehicleCreated,
  });

  Future<void> _addVehicle(BuildContext context) async {
    final created = await Navigator.of(context).push<Vehicle>(
      MaterialPageRoute(
        builder: (_) => VehicleFormScreen(userId: user.id),
      ),
    );
    if (created != null) await onVehicleCreated(created);
  }

  Future<void> _editVehicle(BuildContext context, Vehicle vehicle) async {
    final updated = await Navigator.of(context).push<Vehicle>(
      MaterialPageRoute(
        builder: (_) => VehicleFormScreen(
          userId: user.id,
          existing: vehicle,
        ),
      ),
    );
    if (updated != null) await onVehiclesChanged();
  }

  Future<void> _deleteVehicle(BuildContext context, Vehicle vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${vehicle.name}?'),
        content: const Text(
          'All fuel, maintenance, and expense logs for this vehicle will also be deleted. This cannot be undone.',
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
    try {
      await DatabaseService.instance.deleteVehicle(vehicle.id);
      await onVehiclesChanged();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${vehicle.name} was deleted.')),
      );
    } on LastVehicleException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keep at least one vehicle in your garage.'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete the vehicle. $error')),
      );
    }
  }

  Future<void> _setActive(BuildContext context, Vehicle vehicle) async {
    if (vehicle.id == activeVehicleId) return;
    await onSetActive(vehicle);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${vehicle.name} is now active.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('My garage')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addVehicle(context),
        icon: const Icon(Icons.add),
        label: const Text('Add vehicle'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.swap_horiz,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Each vehicle keeps its own log history, fuel efficiency, and monthly totals. Tap a vehicle to make it active.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (vehicles.isEmpty)
            EmptyState(
              icon: Icons.garage_outlined,
              title: 'Your garage is empty',
              message: 'Add a vehicle to start logging your biyahe.',
              actionLabel: 'Add vehicle',
              onAction: () => _addVehicle(context),
            )
          else
            ...vehicles.map((vehicle) {
              final isActive = vehicle.id == activeVehicleId;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _setActive(context, vehicle),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                          width: isActive ? 1.6 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              vehicleIcon(vehicle.type),
                              color: isActive
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      vehicle.name,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (isActive)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme
                                              .colorScheme.primaryContainer,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          'Active',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            color: theme.colorScheme
                                                .onPrimaryContainer,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${vehicle.type} · ${vehicle.engine}'
                                  '${vehicle.plateNumber == null ? '' : ' · ${vehicle.plateNumber}'}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color:
                                        theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (value) {
                              if (value == 'active') {
                                _setActive(context, vehicle);
                              } else if (value == 'edit') {
                                _editVehicle(context, vehicle);
                              } else if (value == 'delete') {
                                _deleteVehicle(context, vehicle);
                              }
                            },
                            itemBuilder: (menuContext) => [
                              if (!isActive)
                                const PopupMenuItem<String>(
                                  value: 'active',
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle_outline),
                                      SizedBox(width: 10),
                                      Text('Set as active'),
                                    ],
                                  ),
                                ),
                              const PopupMenuItem<String>(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined),
                                    SizedBox(width: 10),
                                    Text('Edit details'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem<String>(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline),
                                    SizedBox(width: 10),
                                    Text('Delete vehicle'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          if (vehicles.length == 1) ...[
            const SizedBox(height: 4),
            Text(
              'Add more vehicles to shuffle between your motorcycle, car, or delivery ride.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
