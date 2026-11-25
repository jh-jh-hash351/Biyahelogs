import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  final _settings = SettingsService.instance;

  AppSettings? _prefs;
  PermissionStatus _notificationStatus = PermissionStatus.denied;
  PermissionStatus _cameraStatus = PermissionStatus.denied;
  PermissionStatus _photosStatus = PermissionStatus.denied;
  bool _loading = true;
  String? _error;

  bool get _supportsRuntimePermissions {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissions();
    }
  }

  Future<void> _load() async {
    try {
      final prefs = await _settings.load();
      if (!mounted) return;
      setState(() {
        _prefs = prefs;
        _error = null;
      });
      await _refreshPermissions();
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load settings. $error';
        _loading = false;
      });
    }
  }

  Future<void> _refreshPermissions() async {
    if (!_supportsRuntimePermissions) {
      setState(() {
        _notificationStatus = PermissionStatus.granted;
        _cameraStatus = PermissionStatus.granted;
        _photosStatus = PermissionStatus.granted;
      });
      return;
    }
    final results = await Future.wait([
      Permission.notification.status,
      Permission.camera.status,
      Permission.photos.status,
    ]);
    if (!mounted) return;
    setState(() {
      _notificationStatus = results[0];
      _cameraStatus = results[1];
      _photosStatus = results[2];
    });
  }

  Future<void> _updatePrefs(AppSettings next) async {
    setState(() => _prefs = next);
    await _settings.save(next);
  }

  Future<void> _toggleNotifications(bool enabled) async {
    final current = _prefs;
    if (current == null) return;

    if (enabled && _supportsRuntimePermissions) {
      final status = await Permission.notification.request();
      if (!mounted) return;
      setState(() => _notificationStatus = status);
      if (!status.isGranted && !status.isLimited) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status.isPermanentlyDenied
                  ? 'Notifications are blocked. Open system settings to allow them.'
                  : 'Notification permission was not granted.',
            ),
            action: status.isPermanentlyDenied
                ? SnackBarAction(
                    label: 'Settings',
                    onPressed: openAppSettings,
                  )
                : null,
          ),
        );
        await _updatePrefs(current.copyWith(notificationsEnabled: false));
        return;
      }
    }

    await _updatePrefs(current.copyWith(notificationsEnabled: enabled));
  }

  Future<void> _requestPermission(Permission permission) async {
    if (!_supportsRuntimePermissions) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Runtime permissions are managed by the OS on this platform.',
          ),
        ),
      );
      return;
    }

    var status = await permission.status;
    if (status.isPermanentlyDenied) {
      final opened = await openAppSettings();
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open system settings.'),
          ),
        );
      }
      return;
    }

    status = await permission.request();
    if (!mounted) return;
    await _refreshPermissions();
    if (!mounted) return;

    if (!status.isGranted && !status.isLimited) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status.isPermanentlyDenied
                ? 'Permission blocked. Open system settings to allow it.'
                : 'Permission was not granted.',
          ),
          action: status.isPermanentlyDenied
              ? SnackBarAction(
                  label: 'Settings',
                  onPressed: openAppSettings,
                )
              : null,
        ),
      );
    }
  }

  String _statusLabel(PermissionStatus status) {
    if (status.isGranted || status.isLimited) return 'Allowed';
    if (status.isPermanentlyDenied) return 'Blocked';
    if (status.isRestricted) return 'Restricted';
    return 'Not allowed';
  }

  Color _statusColor(PermissionStatus status, ColorScheme scheme) {
    if (status.isGranted || status.isLimited) return const Color(0xFF15803D);
    if (status.isPermanentlyDenied || status.isRestricted) {
      return scheme.error;
    }
    return scheme.onSurfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefs = _prefs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
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
                          onPressed: () {
                            setState(() => _loading = true);
                            _load();
                          },
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    _SectionHeader(
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      subtitle:
                          'Reminders for oil changes, upkeep, and spending.',
                    ),
                    const SizedBox(height: 10),
                    _SettingsCard(
                      children: [
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          secondary: Icon(
                            Icons.notifications_active_outlined,
                            color: theme.colorScheme.primary,
                          ),
                          title: const Text('Enable notifications'),
                          subtitle: const Text(
                            'Master switch for BiyaheLog alerts',
                          ),
                          value: prefs!.notificationsEnabled,
                          onChanged: _toggleNotifications,
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          secondary: const Icon(Icons.oil_barrel),
                          title: const Text('Oil change reminders'),
                          subtitle: const Text(
                            'Alert when an oil change may be due',
                          ),
                          value: prefs.oilChangeReminders,
                          onChanged: prefs.notificationsEnabled
                              ? (value) => _updatePrefs(
                                    prefs.copyWith(oilChangeReminders: value),
                                  )
                              : null,
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          secondary: const Icon(Icons.build_outlined),
                          title: const Text('Maintenance alerts'),
                          subtitle: const Text(
                            'General upkeep and service reminders',
                          ),
                          value: prefs.maintenanceAlerts,
                          onChanged: prefs.notificationsEnabled
                              ? (value) => _updatePrefs(
                                    prefs.copyWith(maintenanceAlerts: value),
                                  )
                              : null,
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          secondary: const Icon(Icons.payments_outlined),
                          title: const Text('Spending alerts'),
                          subtitle: const Text(
                            'Heads-up when monthly fuel costs rise',
                          ),
                          value: prefs.spendingAlerts,
                          onChanged: prefs.notificationsEnabled
                              ? (value) => _updatePrefs(
                                    prefs.copyWith(spendingAlerts: value),
                                  )
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _SectionHeader(
                      icon: Icons.security_outlined,
                      title: 'App permissions',
                      subtitle:
                          'Control what BiyaheLog can access on this device.',
                    ),
                    const SizedBox(height: 10),
                    _SettingsCard(
                      children: [
                        _PermissionTile(
                          icon: Icons.notifications_outlined,
                          title: 'Notifications',
                          subtitle: 'Needed for reminders and alerts',
                          statusLabel: _statusLabel(_notificationStatus),
                          statusColor: _statusColor(
                            _notificationStatus,
                            theme.colorScheme,
                          ),
                          actionLabel: (_notificationStatus.isGranted ||
                                  _notificationStatus.isLimited)
                              ? 'Allowed'
                              : (_notificationStatus.isPermanentlyDenied
                                  ? 'Open settings'
                                  : 'Allow'),
                          onAction: (_notificationStatus.isGranted ||
                                  _notificationStatus.isLimited)
                              ? null
                              : () => _requestPermission(
                                    Permission.notification,
                                  ),
                        ),
                        const Divider(height: 1),
                        _PermissionTile(
                          icon: Icons.photo_library_outlined,
                          title: 'Photos',
                          subtitle: 'Attach receipt or damage photos to logs',
                          statusLabel: _statusLabel(_photosStatus),
                          statusColor: _statusColor(
                            _photosStatus,
                            theme.colorScheme,
                          ),
                          actionLabel: (_photosStatus.isGranted ||
                                  _photosStatus.isLimited)
                              ? 'Allowed'
                              : (_photosStatus.isPermanentlyDenied
                                  ? 'Open settings'
                                  : 'Allow'),
                          onAction: (_photosStatus.isGranted ||
                                  _photosStatus.isLimited)
                              ? null
                              : () => _requestPermission(Permission.photos),
                        ),
                        const Divider(height: 1),
                        _PermissionTile(
                          icon: Icons.photo_camera_outlined,
                          title: 'Camera',
                          subtitle: 'Capture photos for expense receipts',
                          statusLabel: _statusLabel(_cameraStatus),
                          statusColor: _statusColor(
                            _cameraStatus,
                            theme.colorScheme,
                          ),
                          actionLabel: (_cameraStatus.isGranted ||
                                  _cameraStatus.isLimited)
                              ? 'Allowed'
                              : (_cameraStatus.isPermanentlyDenied
                                  ? 'Open settings'
                                  : 'Allow'),
                          onAction: (_cameraStatus.isGranted ||
                                  _cameraStatus.isLimited)
                              ? null
                              : () => _requestPermission(Permission.camera),
                        ),
                      ],
                    ),
                    if (_supportsRuntimePermissions) ...[
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: openAppSettings,
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('Open system app settings'),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      Text(
                        'On desktop, notification and media permissions are handled by Windows or macOS.',
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

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String statusLabel;
  final Color statusColor;
  final String actionLabel;
  final VoidCallback? onAction;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.statusColor,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  statusLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (onAction == null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.check_circle, color: statusColor, size: 22),
            )
          else
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
        ],
      ),
    );
  }
}
