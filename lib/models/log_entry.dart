enum LogType {
  fuel('fuel', 'Fuel'),
  oilChange('oil_change', 'Oil change'),
  repair('repair', 'Repair'),
  other('other', 'Other');

  const LogType(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static LogType fromDb(String value) {
    return LogType.values.firstWhere(
      (type) => type.dbValue == value,
      orElse: () => LogType.other,
    );
  }
}

class LogEntry {
  final int id;
  final int userId;
  final int vehicleId;
  final LogType type;
  final DateTime date;
  final double? odometer;
  final double cost;
  final double? liters;
  final String? notes;
  final DateTime createdAt;

  const LogEntry({
    required this.id,
    required this.userId,
    required this.vehicleId,
    required this.type,
    required this.date,
    this.odometer,
    required this.cost,
    this.liters,
    this.notes,
    required this.createdAt,
  });

  factory LogEntry.fromMap(Map<String, Object?> map) {
    return LogEntry(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      vehicleId: map['vehicle_id'] as int,
      type: LogType.fromDb(map['type'] as String),
      date: DateTime.parse(map['date'] as String),
      odometer: (map['odometer'] as num?)?.toDouble(),
      cost: (map['cost'] as num).toDouble(),
      liters: (map['liters'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'user_id': userId,
      'vehicle_id': vehicleId,
      'type': type.dbValue,
      'date': date.toIso8601String(),
      'odometer': odometer,
      'cost': cost,
      'liters': liters,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
