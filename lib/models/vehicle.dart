const List<String> vehicleTypes = [
  'Motorcycle',
  'Tricycle',
  'Car',
  'SUV / Pickup',
  'Van',
  'Truck',
  'Bus',
  'Jeepney',
  'Other',
];

const List<String> engineTypes = [
  'Gasoline',
  'Diesel',
  'Hybrid',
  'Electric',
  'Other',
];

class Vehicle {
  final int id;
  final int userId;
  final String name;
  final String type;
  final String engine;
  final String? plateNumber;
  final DateTime createdAt;

  const Vehicle({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.engine,
    this.plateNumber,
    required this.createdAt,
  });

  bool get isElectric => engine == 'Electric';

  String get fuelUnit => isElectric ? 'kWh' : 'L';

  String get efficiencyUnit => isElectric ? 'km/kWh' : 'km/L';

  factory Vehicle.fromMap(Map<String, Object?> map) {
    return Vehicle(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      name: map['name'] as String,
      type: map['type'] as String,
      engine: map['engine'] as String,
      plateNumber: map['plate_number'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
