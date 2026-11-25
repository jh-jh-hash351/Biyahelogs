import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../models/user.dart';
import '../services/database_service.dart';
import 'login_screen.dart';
import 'main_shell.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final DatabaseService _db = DatabaseService.instance;

  User? _user;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _db.init();
      final user = await _db.getSessionUser();
      if (!mounted) return;
      setState(() {
        _user = user;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not open the local database.\n$error';
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await _db.endSession();
    if (!mounted) return;
    setState(() => _user = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      final primary = Theme.of(context).colorScheme.primary;
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LoadingAnimationWidget.beat(
                color: primary,
                size: 44,
              ),
              const SizedBox(height: 16),
              const Text('Opening BiyaheLog...'),
            ],
          ),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storage, size: 48),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _restoreSession,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final user = _user;
    if (user == null) {
      return LoginScreen(
        onAuthenticated: (authenticated) {
          setState(() => _user = authenticated);
        },
      );
    }
    return MainShell(user: user, onLogout: _logout);
  }
}
