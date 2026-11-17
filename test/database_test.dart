import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:biyahe_log/models/log_entry.dart';
import 'package:biyahe_log/models/vehicle.dart';
import 'package:biyahe_log/services/database_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseService db;

  setUp(() async {
    db = DatabaseService();
    await db.init(databasePath: inMemoryDatabasePath);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> registerSampleUser() async {
    await db.register(
      username: 'juan',
      password: 'secret1',
      vehicleName: 'My Raider',
      vehicleType: 'Motorcycle',
      engineType: 'Gasoline',
    );
  }

  LogEntry sampleLog({
    required int userId,
    required int vehicleId,
    LogType type = LogType.fuel,
    double? odometer,
    double cost = 500,
    double? liters,
    DateTime? date,
  }) {
    return LogEntry(
      id: 0,
      userId: userId,
      vehicleId: vehicleId,
      type: type,
      date: date ?? DateTime(2026, 9, 1),
      odometer: odometer,
      cost: cost,
      liters: liters,
      createdAt: DateTime(2026, 9, 1),
    );
  }

  test('registers, logs in, and rejects duplicate usernames', () async {
    await registerSampleUser();

    final user = await db.login('JUAN', 'secret1');
    expect(user, isNotNull);
    expect(user!.username, 'juan');

    expect(await db.login('juan', 'wrong-password'), isNull);
    expect(await db.login('nobody', 'secret1'), isNull);

    await expectLater(
      db.register(
        username: 'JuAn',
        password: 'another1',
        vehicleName: 'Other bike',
        vehicleType: 'Motorcycle',
        engineType: 'Gasoline',
      ),
      throwsA(isA<UsernameTakenException>()),
    );
  });

  test('persists the local session and active vehicle', () async {
    await registerSampleUser();
    final user = (await db.login('juan', 'secret1'))!;
    final vehicle = (await db.getVehicles(user.id)).single;

    expect(await db.getSessionUser(), isNull);
    await db.startSession(user.id);
    expect((await db.getSessionUser())!.id, user.id);

    expect(await db.getActiveVehicleId(user.id), vehicle.id);
    await db.endSession();
    expect(await db.getSessionUser(), isNull);
  });

  test('creates, updates, selects, and deletes vehicles', () async {
    await registerSampleUser();
    final user = (await db.login('juan', 'secret1'))!;
    final first = (await db.getVehicles(user.id)).single;

    final second = await db.createVehicle(
      userId: user.id,
      name: 'Delivery trike',
      type: 'Tricycle',
      engine: 'Gasoline',
      plateNumber: 'ABC 123',
    );
    expect(await db.getVehicles(user.id), hasLength(2));

    await db.setActiveVehicleId(user.id, second.id);
    expect(await db.getActiveVehicleId(user.id), second.id);

    final renamed = await db.getVehicle(second.id);
    expect(renamed!.plateNumber, 'ABC 123');
    await db.updateVehicle(
      Vehicle(
        id: second.id,
        userId: user.id,
        name: 'Weekend trike',
        type: 'Tricycle',
        engine: 'Gasoline',
        plateNumber: null,
        createdAt: second.createdAt,
      ),
    );
    final updated = await db.getVehicle(second.id);
    expect(updated!.name, 'Weekend trike');
    expect(updated.plateNumber, isNull);

    await db.deleteVehicle(second.id);
    expect(await db.getVehicles(user.id), hasLength(1));
    expect(await db.getActiveVehicleId(user.id), isNull);

    await expectLater(
      db.deleteVehicle(first.id),
      throwsA(isA<LastVehicleException>()),
    );
  });

  test('adds, reads, edits, and deletes log entries', () async {
    await registerSampleUser();
    final user = (await db.login('juan', 'secret1'))!;
    final vehicle = (await db.getVehicles(user.id)).single;

    final first = await db.addLog(
      sampleLog(
        userId: user.id,
        vehicleId: vehicle.id,
        odometer: 1000,
        liters: 25,
        cost: 1500,
        date: DateTime(2026, 9, 1),
      ),
    );
    final second = await db.addLog(
      sampleLog(
        userId: user.id,
        vehicleId: vehicle.id,
        odometer: 1300,
        liters: 10,
        cost: 600,
        date: DateTime(2026, 9, 10),
      ),
    );

    final logs = await db.getLogsForVehicle(vehicle.id);
    expect(logs, hasLength(2));
    expect(logs.first.id, second.id);
    expect(logs.first.odometer, 1300);

    final edited = LogEntry(
      id: second.id,
      userId: user.id,
      vehicleId: vehicle.id,
      type: LogType.fuel,
      date: second.date,
      odometer: 1300,
      cost: 650,
      liters: 10,
      notes: 'Shell station',
      createdAt: second.createdAt,
    );
    await db.updateLog(edited);
    final reloaded = await db.getLog(second.id);
    expect(reloaded!.cost, 650);
    expect(reloaded.notes, 'Shell station');

    await db.deleteLog(first.id);
    expect(await db.getLogsForVehicle(vehicle.id), hasLength(1));
  });

  test('deleting a vehicle also deletes its log history', () async {
    await registerSampleUser();
    final user = (await db.login('juan', 'secret1'))!;
    final vehicle = (await db.getVehicles(user.id)).single;
    await db.addLog(
      sampleLog(userId: user.id, vehicleId: vehicle.id, odometer: 500),
    );
    await db.createVehicle(
      userId: user.id,
      name: 'Second vehicle',
      type: 'Car',
      engine: 'Hybrid',
    );

    await db.deleteVehicle(vehicle.id);

    expect(await db.getLogsForVehicle(vehicle.id), isEmpty);
  });
}
