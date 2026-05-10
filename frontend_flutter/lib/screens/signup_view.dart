import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../services/supabase_network_feedback.dart';
import '../widgets/glass.dart';

class SignUpView extends StatefulWidget {
  const SignUpView({super.key});

  @override
  State<SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends State<SignUpView> {
  final _emailCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  var _registerAsOperator = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  static final _userPattern = RegExp(r'^[a-zA-Z0-9_]{2,32}$');

  Future<void> _submit() async {
    setState(() => _error = null);
    final email = _emailCtrl.text.trim();
    final user = _userCtrl.text.trim();
    final p1 = _passCtrl.text;
    final p2 = _pass2Ctrl.text;
    final code = _codeCtrl.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email.');
      return;
    }
    if (!_userPattern.hasMatch(user)) {
      setState(() => _error = 'Username: 2–32 letters, numbers, or underscore.');
      return;
    }
    if (p1.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (p1 != p2) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    if (_registerAsOperator) {
      if (!RegExp(r'^\d{6}$').hasMatch(code)) {
        setState(() => _error = 'Enter the 6-digit operator code.');
        return;
      }
      if (code != kOperatorInviteCode) {
        setState(() => _error = 'Invalid operator code.');
        return;
      }
    }

    try {
      await context.read<AuthProvider>().signUp(
            email: email,
            username: user,
            password: p1,
            registerAsOperator: _registerAsOperator,
            operatorCode: code,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = readableSupabaseNetworkFailure(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: GlassPanel(
                  padding: const EdgeInsets.all(26),
                  borderRadius: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Create account',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.94),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Choose a normal user account or an operator account (requires invite code).',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.45), height: 1.35),
                      ),
                      const SizedBox(height: 22),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          ChoiceChip(
                            label: const Text('User'),
                            selected: !_registerAsOperator,
                            onSelected: (_) => setState(() {
                              _registerAsOperator = false;
                              _codeCtrl.clear();
                            }),
                          ),
                          ChoiceChip(
                            label: const Text('Operator'),
                            selected: _registerAsOperator,
                            onSelected: (_) => setState(() => _registerAsOperator = true),
                          ),
                        ],
                      ),
                      if (_registerAsOperator) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Operators need a 6-digit invite code from your administrator (trial setup uses six zeros).',
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade200.withValues(alpha: 0.85)),
                        ),
                      ],
                      const SizedBox(height: 18),
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _userCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          hintText: 'Used to sign in without email',
                          prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _pass2Ctrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirm password',
                          prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
                        ),
                      ),
                      if (_registerAsOperator) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _codeCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: const InputDecoration(
                            labelText: 'Operator invite code',
                            counterText: '',
                            prefixIcon: Icon(Icons.pin_outlined, size: 20),
                          ),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(_error!, style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 13)),
                      ],
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed: auth.isLoading ? null : _submit,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: auth.isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.2),
                                )
                              : const Text('Sign up'),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Back to sign in'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
