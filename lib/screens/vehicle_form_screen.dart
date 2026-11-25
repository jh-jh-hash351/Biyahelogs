import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../models/vehicle.dart';
import '../services/database_service.dart';

class VehicleFormScreen extends StatefulWidget {
  final int userId;
  final Vehicle? existing;

  const VehicleFormScreen({
    super.key,
    required this.userId,
    this.existing,
  });

  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _plateController = TextEditingController();
  final _db = DatabaseService.instance;

  late String _type;
  late String _engine;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController.text = existing?.name ?? '';
    _plateController.text = existing?.plateNumber ?? '';
    _type = existing?.type ?? vehicleTypes.first;
    _engine = existing?.engine ?? engineTypes.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final name = _nameController.text.trim();
    final plate = _plateController.text.trim();
    final plateNumber = plate.isEmpty ? null : plate.toUpperCase();
    try {
      Vehicle result;
      final existing = widget.existing;
      if (existing == null) {
        result = await _db.createVehicle(
          userId: widget.userId,
          name: name,
          type: _type,
          engine: _engine,
          plateNumber: plateNumber,
        );
      } else {
        result = Vehicle(
          id: existing.id,
          userId: existing.userId,
          name: name,
          type: _type,
          engine: _engine,
          plateNumber: plateNumber,
          createdAt: existing.createdAt,
        );
        await _db.updateVehicle(result);
      }
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save the vehicle. $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit vehicle' : 'Add vehicle'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                            Icons.info_outline,
                            size: 20,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'BiyaheLog supports any vehicle you maintain — motorcycle, tricycle, car, van, truck, jeepney, and more.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Vehicle nickname',
                        hintText: 'e.g. Delivery van, Lolo\'s tricycle',
                        prefixIcon: Icon(Icons.drive_eta),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Give your vehicle a name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _type,
                      decoration: const InputDecoration(
                        labelText: 'Vehicle type',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: vehicleTypes
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _type = value);
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _engine,
                      decoration: const InputDecoration(
                        labelText: 'Fuel / power source',
                        prefixIcon: Icon(Icons.bolt_outlined),
                      ),
                      items: engineTypes
                          .map(
                            (engine) => DropdownMenuItem(
                              value: engine,
                              child: Text(engine),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _engine = value);
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _plateController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Plate number (optional)',
                        prefixIcon: Icon(Icons.pin_outlined),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? LoadingAnimationWidget.beat(
                                color: Theme.of(context).colorScheme.onPrimary,
                                size: 20,
                              )
                            : const Icon(Icons.check),
                        label: Text(
                          _saving
                              ? 'Saving...'
                              : (_isEditing ? 'Save changes' : 'Add vehicle'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    if (_isEditing) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Changing the fuel source updates the unit used for efficiency (L or kWh).',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
