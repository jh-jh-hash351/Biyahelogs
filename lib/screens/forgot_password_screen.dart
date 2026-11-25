import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../services/database_service.dart';

/// A three-step flow:
///  1. Enter username → fetch security question
///  2. Answer the security question
///  3. Set a new password
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

enum _Step { username, answer, newPassword }

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _db = DatabaseService.instance;

  final _formKey = GlobalKey<FormState>();

  // Step 1
  final _usernameController = TextEditingController();
  // Step 2
  String? _securityQuestion;
  final _answerController = TextEditingController();
  // Step 3
  final _newPasswordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  _Step _step = _Step.username;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _answerController.dispose();
    _newPasswordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ── Step handlers ────────────────────────────────────────────────────────────

  Future<void> _fetchQuestion() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final question = await _db.getSecurityQuestion(
        _usernameController.text.trim(),
      );
      if (!mounted) return;
      if (question == null || question.isEmpty) {
        setState(() {
          _error =
              'No security question found for that username. '
              'Make sure you registered with a security question.';
          _loading = false;
        });
        return;
      }
      setState(() {
        _securityQuestion = question;
        _step = _Step.answer;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong: $e';
        _loading = false;
      });
    }
  }

  Future<void> _verifyAnswer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // We just move to the next step here; actual verification happens on reset
      setState(() {
        _step = _Step.newPassword;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong: $e';
        _loading = false;
      });
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ok = await _db.resetPasswordWithSecurityAnswer(
        username: _usernameController.text.trim(),
        answer: _answerController.text,
        newPassword: _newPasswordController.text,
      );
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _error = 'Incorrect answer. Please go back and try again.';
          _loading = false;
        });
        return;
      }
      // Success – pop and show snackbar
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset successfully! Please log in again.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ── Back handling ─────────────────────────────────────────────────────────

  void _goBack() {
    setState(() {
      _error = null;
      if (_step == _Step.answer) _step = _Step.username;
      if (_step == _Step.newPassword) _step = _Step.answer;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: _step == _Step.username,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step != _Step.username) _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Forgot password',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _step == _Step.username
                ? () => Navigator.of(context).pop()
                : _goBack,
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _formKey,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: _buildStep(theme, colorScheme),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(ThemeData theme, ColorScheme colorScheme) {
    return switch (_step) {
      _Step.username => _buildUsernameStep(theme, colorScheme),
      _Step.answer => _buildAnswerStep(theme, colorScheme),
      _Step.newPassword => _buildNewPasswordStep(theme, colorScheme),
    };
  }

  // ── Step 1 – username ─────────────────────────────────────────────────────

  Widget _buildUsernameStep(ThemeData theme, ColorScheme colorScheme) {
    return _StepCard(
      key: const ValueKey('username'),
      icon: Icons.person_search_outlined,
      iconColor: colorScheme.primary,
      title: 'Find your account',
      subtitle: 'Enter your username to look up your security question.',
      error: _error,
      children: [
        TextFormField(
          controller: _usernameController,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.username],
          onFieldSubmitted: (_) => _fetchQuestion(),
          decoration: const InputDecoration(
            labelText: 'Username',
            prefixIcon: Icon(Icons.person_outline),
          ),
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Enter your username' : null,
        ),
        const SizedBox(height: 20),
        _ActionButton(
          loading: _loading,
          label: 'Continue',
          onPressed: _fetchQuestion,
        ),
      ],
    );
  }

  // ── Step 2 – security answer ──────────────────────────────────────────────

  Widget _buildAnswerStep(ThemeData theme, ColorScheme colorScheme) {
    return _StepCard(
      key: const ValueKey('answer'),
      icon: Icons.shield_outlined,
      iconColor: const Color(0xFFEA8C00),
      title: 'Security question',
      subtitle: 'Answer the question you set when you registered.',
      error: _error,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _securityQuestion ?? '',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _answerController,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _verifyAnswer(),
          decoration: const InputDecoration(
            labelText: 'Your answer',
            prefixIcon: Icon(Icons.lock_outline),
          ),
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Enter your answer' : null,
        ),
        const SizedBox(height: 20),
        _ActionButton(
          loading: _loading,
          label: 'Next',
          onPressed: _verifyAnswer,
        ),
      ],
    );
  }

  // ── Step 3 – new password ─────────────────────────────────────────────────

  Widget _buildNewPasswordStep(ThemeData theme, ColorScheme colorScheme) {
    return _StepCard(
      key: const ValueKey('newPassword'),
      icon: Icons.lock_reset_outlined,
      iconColor: const Color(0xFF15803D),
      title: 'Set a new password',
      subtitle: 'Choose a strong password for your account.',
      error: _error,
      children: [
        TextFormField(
          controller: _newPasswordController,
          obscureText: _obscureNew,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'New password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureNew
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () =>
                  setState(() => _obscureNew = !_obscureNew),
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Enter a new password';
            if (v.length < 6) return 'Password must be at least 6 characters';
            return null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _confirmController,
          obscureText: _obscureConfirm,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _resetPassword(),
          decoration: InputDecoration(
            labelText: 'Confirm password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Confirm your password';
            if (v != _newPasswordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        _ActionButton(
          loading: _loading,
          label: 'Reset password',
          onPressed: _resetPassword,
        ),
      ],
    );
  }
}

// ── Shared widgets ──────────────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? error;
  final List<Widget> children;

  const _StepCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.error,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, size: 36, color: iconColor),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...children,
                if (error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 18,
                          color: colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            error!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final bool loading;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.loading,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? Center(
                child: LoadingAnimationWidget.beat(
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 24,
                ),
              )
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
