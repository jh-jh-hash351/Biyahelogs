import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show databaseFactoryFfi, sqfliteFfiInit;

import '../models/log_entry.dart';
import '../models/user.dart';
import '../models/vehicle.dart';

class UsernameTakenException implements Exception {
  const UsernameTakenException();

  @override
  String toString() => 'That username is already taken.';
}

class LastVehicleException implements Exception {
  const LastVehicleException();

  @override
  String toString() => 'Keep at least one vehicle in your garage.';
}

class DatabaseService {
  DatabaseService();

  static final DatabaseService instance = DatabaseService();

  Database? _db;

  Database get _database {
    final db = _db;
    if (db == null) {
      throw StateError('DatabaseService.init() must be called first.');
    }
    return db;
  }

  Future<void> init({String? databasePath}) async {
    if (_db != null) return;
    final isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux);
    if (isDesktop) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final path =
        databasePath ?? p.join(await getDatabasesPath(), 'biyahe_log.db');
    _db = await openDatabase(
      path,
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createSchema,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL COLLATE NOCASE UNIQUE,
        password_hash TEXT NOT NULL,
        salt TEXT NOT NULL,
        security_question TEXT,
        security_answer_hash TEXT,
        security_salt TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE vehicles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        engine TEXT NOT NULL,
        plate_number TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        vehicle_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        date TEXT NOT NULL,
        odometer REAL,
        cost REAL NOT NULL,
        liters REAL,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_vehicles_user ON vehicles (user_id)',
    );
    await db.execute(
      'CREATE INDEX idx_logs_vehicle_date ON logs (vehicle_id, date DESC)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add security question columns to existing users table
      await db.execute(
        'ALTER TABLE users ADD COLUMN security_question TEXT',
      );
      await db.execute(
        'ALTER TABLE users ADD COLUMN security_answer_hash TEXT',
      );
      await db.execute(
        'ALTER TABLE users ADD COLUMN security_salt TEXT',
      );
    }
  }

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _hashPassword(String password, String salt) {
    List<int> value = utf8.encode('$salt:$password');
    for (var i = 0; i < 1000; i++) {
      value = sha256.convert(value).bytes;
    }
    return base64Url.encode(value);
  }

  Future<User> register({
    required String username,
    required String password,
    required String vehicleName,
    required String vehicleType,
    required String engineType,
    String? plateNumber,
    String? securityQuestion,
    String? securityAnswer,
  }) async {
    final salt = _generateSalt();
    final hash = _hashPassword(password, salt);
    final now = DateTime.now().toIso8601String();

    String? secSalt;
    String? secAnswerHash;
    if (securityQuestion != null && securityAnswer != null) {
      secSalt = _generateSalt();
      secAnswerHash = _hashPassword(securityAnswer.trim().toLowerCase(), secSalt);
    }

    late User user;
    await _database.transaction((txn) async {
      final existing = await txn.query(
        'users',
        columns: ['id'],
        where: 'username = ? COLLATE NOCASE',
        whereArgs: [username],
        limit: 1,
      );
      if (existing.isNotEmpty) throw const UsernameTakenException();

      final userId = await txn.insert('users', {
        'username': username,
        'password_hash': hash,
        'salt': salt,
        'security_question': securityQuestion,
        'security_answer_hash': secAnswerHash,
        'security_salt': secSalt,
        'created_at': now,
      });
      final vehicleId = await txn.insert('vehicles', {
        'user_id': userId,
        'name': vehicleName,
        'type': vehicleType,
        'engine': engineType,
        'plate_number': plateNumber,
        'created_at': now,
      });
      user = User(id: userId, username: username, createdAt: DateTime.now());
      await txn.insert('settings', {
        'key': 'active_vehicle_$userId',
        'value': '$vehicleId',
      });
    });
    return user;
  }

  Future<User?> login(String username, String password) async {
    final rows = await _database.query(
      'users',
      where: 'username = ? COLLATE NOCASE',
      whereArgs: [username],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final hash = _hashPassword(password, row['salt'] as String);
    if (hash != row['password_hash']) return null;
    return User.fromMap(row);
  }

  Future<User?> getUser(int id) async {
    final rows = await _database.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return User.fromMap(rows.first);
  }

  Future<User?> getSessionUser() async {
    final value = await _getSetting('session_user_id');
    final id = int.tryParse(value ?? '');
    if (id == null) return null;
    return getUser(id);
  }

  Future<void> startSession(int userId) async {
    await _setSetting('session_user_id', '$userId');
  }

  Future<void> endSession() async {
    await _deleteSetting('session_user_id');
  }

  Future<int?> getActiveVehicleId(int userId) async {
    final value = await _getSetting('active_vehicle_$userId');
    return int.tryParse(value ?? '');
  }

  Future<void> setActiveVehicleId(int userId, int vehicleId) async {
    await _setSetting('active_vehicle_$userId', '$vehicleId');
  }

  Future<String?> _getSetting(String key) async {
    final rows = await _database.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> _setSetting(String key, String value) async {
    await _database.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _deleteSetting(String key) async {
    await _database.delete('settings', where: 'key = ?', whereArgs: [key]);
  }

  // ── Forgot Password ──────────────────────────────────────────────────────────

  /// Returns the security question for the given username, or null if the
  /// user does not exist or has no security question set.
  Future<String?> getSecurityQuestion(String username) async {
    final rows = await _database.query(
      'users',
      columns: ['security_question'],
      where: 'username = ? COLLATE NOCASE',
      whereArgs: [username],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['security_question'] as String?;
  }

  /// Verifies the security answer and, if correct, resets the password.
  /// Returns true on success, false if the answer is wrong.
  /// Throws if the user is not found or has no security question.
  Future<bool> resetPasswordWithSecurityAnswer({
    required String username,
    required String answer,
    required String newPassword,
  }) async {
    final rows = await _database.query(
      'users',
      where: 'username = ? COLLATE NOCASE',
      whereArgs: [username],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('User not found.');
    final row = rows.first;

    final secSalt = row['security_salt'] as String?;
    final secHash = row['security_answer_hash'] as String?;
    if (secSalt == null || secHash == null) {
      throw Exception('No security question set for this account.');
    }

    final candidateHash = _hashPassword(answer.trim().toLowerCase(), secSalt);
    if (candidateHash != secHash) return false;

    // Answer is correct – update the password
    final newSalt = _generateSalt();
    final newHash = _hashPassword(newPassword, newSalt);
    await _database.update(
      'users',
      {'password_hash': newHash, 'salt': newSalt},
      where: 'username = ? COLLATE NOCASE',
      whereArgs: [username],
    );
    return true;
  }

  // ── Vehicles ─────────────────────────────────────────────────────────────────

  Future<List<Vehicle>> getVehicles(int userId) async {
    final rows = await _database.query(
      'vehicles',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'id ASC',
    );
    return rows.map(Vehicle.fromMap).toList();
  }

  Future<Vehicle?> getVehicle(int id) async {
    final rows = await _database.query(
      'vehicles',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Vehicle.fromMap(rows.first);
  }

  Future<Vehicle> createVehicle({
    required int userId,
    required String name,
    required String type,
    required String engine,
    String? plateNumber,
  }) async {
    final createdAt = DateTime.now();
    final id = await _database.insert('vehicles', {
      'user_id': userId,
      'name': name,
      'type': type,
      'engine': engine,
      'plate_number': plateNumber,
      'created_at': createdAt.toIso8601String(),
    });
    return Vehicle(
      id: id,
      userId: userId,
      name: name,
      type: type,
      engine: engine,
      plateNumber: plateNumber,
      createdAt: createdAt,
    );
  }

  Future<void> updateVehicle(Vehicle vehicle) async {
    await _database.update(
      'vehicles',
      {
        'name': vehicle.name,
        'type': vehicle.type,
        'engine': vehicle.engine,
        'plate_number': vehicle.plateNumber,
      },
      where: 'id = ?',
      whereArgs: [vehicle.id],
    );
  }

  Future<void> deleteVehicle(int vehicleId) async {
    final vehicle = await getVehicle(vehicleId);
    if (vehicle == null) return;
    final count = Sqflite.firstIntValue(
      await _database.rawQuery(
        'SELECT COUNT(*) FROM vehicles WHERE user_id = ?',
        [vehicle.userId],
      ),
    );
    if ((count ?? 0) <= 1) throw const LastVehicleException();
    await _database.delete('vehicles', where: 'id = ?', whereArgs: [vehicleId]);
    final activeId = await getActiveVehicleId(vehicle.userId);
    if (activeId == vehicleId) {
      await _deleteSetting('active_vehicle_${vehicle.userId}');
    }
  }

  // ── Logs ─────────────────────────────────────────────────────────────────────

  Future<List<LogEntry>> getLogsForVehicle(int vehicleId) async {
    final rows = await _database.query(
      'logs',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(LogEntry.fromMap).toList();
  }

  /// Paginated version: returns [pageSize] logs starting from [offset].
  Future<List<LogEntry>> getLogsForVehiclePaged(
    int vehicleId, {
    required int offset,
    required int pageSize,
  }) async {
    final rows = await _database.query(
      'logs',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'date DESC, id DESC',
      limit: pageSize,
      offset: offset,
    );
    return rows.map(LogEntry.fromMap).toList();
  }

  Future<int> getLogCount(int vehicleId) async {
    final result = await _database.rawQuery(
      'SELECT COUNT(*) FROM logs WHERE vehicle_id = ?',
      [vehicleId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<LogEntry?> getLog(int id) async {
    final rows = await _database.query(
      'logs',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LogEntry.fromMap(rows.first);
  }

  Future<LogEntry> addLog(LogEntry log) async {
    final id = await _database.insert('logs', log.toMap());
    return LogEntry(
      id: id,
      userId: log.userId,
      vehicleId: log.vehicleId,
      type: log.type,
      date: log.date,
      odometer: log.odometer,
      cost: log.cost,
      liters: log.liters,
      notes: log.notes,
      createdAt: log.createdAt,
    );
  }

  Future<void> updateLog(LogEntry log) async {
    await _database.update(
      'logs',
      log.toMap(),
      where: 'id = ?',
      whereArgs: [log.id],
    );
  }

  Future<void> deleteLog(int id) async {
    await _database.delete('logs', where: 'id = ?', whereArgs: [id]);
  }
}
