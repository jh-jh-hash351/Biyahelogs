import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final bool notificationsEnabled;
  final bool oilChangeReminders;
  final bool maintenanceAlerts;
  final bool spendingAlerts;

  const AppSettings({
    required this.notificationsEnabled,
    required this.oilChangeReminders,
    required this.maintenanceAlerts,
    required this.spendingAlerts,
  });

  AppSettings copyWith({
    bool? notificationsEnabled,
    bool? oilChangeReminders,
    bool? maintenanceAlerts,
    bool? spendingAlerts,
  }) {
    return AppSettings(
      notificationsEnabled:
          notificationsEnabled ?? this.notificationsEnabled,
      oilChangeReminders: oilChangeReminders ?? this.oilChangeReminders,
      maintenanceAlerts: maintenanceAlerts ?? this.maintenanceAlerts,
      spendingAlerts: spendingAlerts ?? this.spendingAlerts,
    );
  }
}

class SettingsService {
  SettingsService._();

  static final SettingsService instance = SettingsService._();

  static const _keyNotifications = 'settings_notifications_enabled';
  static const _keyOilChange = 'settings_oil_change_reminders';
  static const _keyMaintenance = 'settings_maintenance_alerts';
  static const _keySpending = 'settings_spending_alerts';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<AppSettings> load() async {
    final prefs = await _ensurePrefs();
    return AppSettings(
      notificationsEnabled: prefs.getBool(_keyNotifications) ?? true,
      oilChangeReminders: prefs.getBool(_keyOilChange) ?? true,
      maintenanceAlerts: prefs.getBool(_keyMaintenance) ?? true,
      spendingAlerts: prefs.getBool(_keySpending) ?? false,
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await _ensurePrefs();
    await Future.wait([
      prefs.setBool(_keyNotifications, settings.notificationsEnabled),
      prefs.setBool(_keyOilChange, settings.oilChangeReminders),
      prefs.setBool(_keyMaintenance, settings.maintenanceAlerts),
      prefs.setBool(_keySpending, settings.spendingAlerts),
    ]);
  }
}
