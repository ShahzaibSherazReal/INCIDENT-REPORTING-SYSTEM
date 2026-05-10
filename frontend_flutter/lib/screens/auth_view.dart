import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/supabase_network_feedback.dart';
import 'signup_view.dart';
import '../widgets/glass.dart';

class AuthView extends StatefulWidget {
  const AuthView({super.key});

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> with SingleTickerProviderStateMixin {
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String? _error;
  LoginPortal _portal = LoginPortal.user;

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _intro.dispose();
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _openSignUp() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const SignUpView()),
    );
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
              child: FadeTransition(
                opacity: CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic)),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: GlassPanel(
                      padding: const EdgeInsets.all(28),
                      borderRadius: 26,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(
                            Icons.shield_moon_outlined,
                            size: 44,
                            color: const Color(0xFF5BB0FF).withValues(alpha: 0.95),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'AIRS',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 6,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Sign in',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.45),
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Sign in as',
                            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.48)),
                          ),
                          const SizedBox(height: 8),
                          SegmentedButton<LoginPortal>(
                            segments: const [
                              ButtonSegment(
                                value: LoginPortal.user,
                                label: Text('User'),
                                icon: Icon(Icons.person_outline_rounded, size: 18),
                              ),
                              ButtonSegment(
                                value: LoginPortal.operator,
                                label: Text('Operator'),
                                icon: Icon(Icons.engineering_outlined, size: 18),
                              ),
                              ButtonSegment(
                                value: LoginPortal.administrator,
                                label: Text('Staff'),
                                icon: Icon(Icons.admin_panel_settings_outlined, size: 18),
                              ),
                            ],
                            selected: {_portal},
                            onSelectionChanged: (s) => setState(() => _portal = s.first),
                          ),
                          if (_portal == LoginPortal.operator) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Operator sign-in only works if this email/username was registered as an operator.',
                              style: TextStyle(fontSize: 11.5, height: 1.35, color: Colors.orange.shade200.withValues(alpha: 0.85)),
                            ),
                          ],
                          if (_portal == LoginPortal.administrator) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Built-in accounts (case-insensitive username): Admin / admin + password admin123 (Admin). '
                              'Superadmin / superadmin + admin321 (Super Administrator).',
                              style: TextStyle(fontSize: 11.5, height: 1.35, color: Colors.amber.shade100.withValues(alpha: 0.88)),
                            ),
                          ],
                          const SizedBox(height: 18),
                          TextField(
                            controller: _identifierCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email or username',
                              hintText: 'you@company.com or jane_doe',
                              prefixIcon: Icon(Icons.account_circle_outlined, size: 20),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _passwordCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 14),
                            Text(
                              _error!,
                              style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 13),
                            ),
                          ],
                          const SizedBox(height: 22),
                          FilledButton(
                            onPressed: auth.isLoading
                                ? null
                                : () async {
                                    try {
                                      setState(() => _error = null);
                                      await context.read<AuthProvider>().signIn(
                                            identifier: _identifierCtrl.text.trim(),
                                            password: _passwordCtrl.text,
                                            portal: _portal,
                                          );
                                    } catch (e) {
                                      setState(() => _error = readableSupabaseNetworkFailure(e));
                                    }
                                  },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: auth.isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2.2),
                                    )
                                  : const Text('Continue'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed: auth.isLoading ? null : _openSignUp,
                            child: const Text('Create an account'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed: () => context.read<AuthProvider>().continueAsGuest(),
                            child: const Text('Guest'),
                          ),
                        ],
                      ),
                    ),
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
