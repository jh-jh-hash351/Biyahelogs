import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/log_entry.dart';
import '../models/vehicle.dart';
import '../services/database_service.dart';
import '../utils/formatters.dart';
import '../utils/log_type_ui.dart';

class LogFormScreen extends StatefulWidget {
  final Vehicle vehicle;
  final LogEntry? existing;
  final LogType? initialType;

  const LogFormScreen({
    super.key,
    required this.vehicle,
    this.existing,
    this.initialType,
  });

  @override
  State<LogFormScreen> createState() => _LogFormScreenState();
}

class _LogFormScreenState extends State<LogFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _odometerController = TextEditingController();
  final _costController = TextEditingController();
  final _litersController = TextEditingController();
  final _notesController = TextEditingController();
  final _dateController = TextEditingController();
  final _db = DatabaseService.instance;

  late LogType _type;
  late DateTime _date;
  bool _saving = false;

  String get _fuelUnit => widget.vehicle.fuelUnit;

  bool get _isEditing => widget.existing != null;

  bool get _odometerRequired => _type != LogType.other;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _type = existing?.type ?? widget.initialType ?? LogType.fuel;
    _date = existing?.date ?? DateUtils.dateOnly(DateTime.now());
    _dateController.text = formatDate(_date);
    _odometerController.text = inputNumber(existing?.odometer);
    _costController.text = existing == null
        ? ''
        : (existing.cost == existing.cost.roundToDouble()
            ? existing.cost.toStringAsFixed(0)
            : existing.cost.toString());
    _litersController.text = inputNumber(existing?.liters);
    _notesController.text = existing?.notes ?? '';
  }

  @override
  void dispose() {
    _odometerController.dispose();
    _costController.dispose();
    _litersController.dispose();
    _notesController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      _date = DateUtils.dateOnly(picked);
      _dateController.text = formatDate(_date);
    });
  }

  double? _parseNumber(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final existing = widget.existing;
    final log = LogEntry(
      id: existing?.id ?? 0,
      userId: widget.vehicle.userId,
      vehicleId: widget.vehicle.id,
      type: _type,
      date: _date,
      odometer: _parseNumber(_odometerController.text),
      cost: _parseNumber(_costController.text)!,
      liters: _type == LogType.fuel
          ? _parseNumber(_litersController.text)
          : null,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdAt: existing?.createdAt ?? DateTime.now(),
    );
    try {
      if (existing == null) {
        await _db.addLog(log);
      } else {
        await _db.updateLog(log);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save the entry. $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit log entry' : 'Add log entry'),
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
                    Text(
                      'Vehicle: ${widget.vehicle.name}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: LogType.values.map((type) {
                        final selected = _type == type;
                        return ChoiceChip(
                          label: Text(type.label),
                          avatar: Icon(
                            type.icon,
                            size: 18,
                            color: selected ? type.color : null,
                          ),
                          selected: selected,
                          onSelected: (_) => setState(() => _type = type),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _dateController,
                      readOnly: true,
                      onTap: _pickDate,
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        prefixIcon: Icon(Icons.event_outlined),
                        suffixIcon: Icon(Icons.edit_calendar_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _odometerController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: InputDecoration(
                        labelText: _odometerRequired
                            ? 'Odometer (km)'
                            : 'Odometer (km, optional)',
                        prefixIcon: const Icon(Icons.speed),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) {
                          return _odometerRequired
                              ? 'Enter the odometer reading'
                              : null;
                        }
                        final parsed = double.tryParse(text);
                        if (parsed == null) return 'Enter a valid number';
                        if (parsed < 0) return 'Odometer cannot be negative';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _costController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Total cost (₱)',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                      validator: (value) {
                        final parsed = _parseNumber(value ?? '');
                        if (parsed == null) return 'Enter the total cost';
                        if (parsed < 0) return 'Cost cannot be negative';
                        return null;
                      },
                    ),
                    if (_type == LogType.fuel) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _litersController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.]'),
                          ),
                        ],
                        decoration: InputDecoration(
                          labelText: _fuelUnit == 'kWh'
                              ? 'Electricity used (kWh)'
                              : 'Liters filled',
                          prefixIcon: const Icon(Icons.opacity),
                          helperText: widget.vehicle.isElectric
                              ? 'Used to compute km/kWh for this charge.'
                              : 'Used to compute km/L for this fill-up.',
                        ),
                        validator: (value) {
                          final parsed = _parseNumber(value ?? '');
                          if (parsed == null) {
                            return 'Enter the ${_fuelUnit == 'kWh' ? 'kWh added' : 'liters filled'}';
                          }
                          if (parsed <= 0) {
                            return 'Must be greater than zero';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _notesController,
                      minLines: 2,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        hintText: 'Gas station, shop, or other details',
                        prefixIcon: Icon(Icons.notes),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          _saving ? 'Saving...' : 'Save entry',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
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
