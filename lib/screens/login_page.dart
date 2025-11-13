import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/auth_controller.dart';
import '../utils/ui_helpers.dart';
import 'home/role_home.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final auth = context.read<AuthController>();
      await auth.login(
        _usernameCtrl.text.trim(),
        _passwordCtrl.text,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RoleHomePage()),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.5,
    );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFedf2ff), Color(0xFFe2e8ff), Color(0xFFf7f9ff)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                final card = Card(
                  elevation: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFffffff), Color(0xFFf6f7ff)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isWide ? 48 : 28,
                          vertical: isWide ? 48 : 36,
                        ),
                        child: isWide
                            ? Row(
                                children: [
                                  Expanded(child: _LoginHero(subtitleStyle: subtitleStyle)),
                                  const SizedBox(width: 48),
                                  Expanded(child: _buildForm(subtitleStyle)),
                                ],
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _LoginHero(subtitleStyle: subtitleStyle),
                                  const SizedBox(height: 32),
                                  _buildForm(subtitleStyle),
                                ],
                              ),
                      ),
                    ),
                  ),
                );

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: card,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(TextStyle? subtitleStyle) {
    final theme = Theme.of(context);
    const spacing = SizedBox(height: 18);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Welcome back',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Access the Aurora ERP workspace to manage lots, rolls, and production insights.',
            style: subtitleStyle,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _usernameCtrl,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Please enter username'
                : null,
          ),
          spacing,
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Show password' : 'Hide password',
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) => (v == null || v.isEmpty)
                ? 'Please enter password'
                : null,
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.login),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(_loading ? 'Signing in…' : 'Sign in'),
              ),
              onPressed: _loading ? null : _submit,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Need help? Contact your Aurora administrator to reset or unlock your account.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  final TextStyle? subtitleStyle;

  const _LoginHero({required this.subtitleStyle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(Icons.auto_graph_outlined, size: 38, color: Colors.white),
        ),
        const SizedBox(height: 24),
        Text(
          'Aurora ERP Portal',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'A modern workspace for production teams. Build lots, track rolls, and collaborate effortlessly.',
          style: subtitleStyle,
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: const [
            _HighlightChip(icon: Icons.bolt, label: 'Fast onboarding'),
            _HighlightChip(icon: Icons.verified, label: 'Secure access'),
            _HighlightChip(icon: Icons.analytics_outlined, label: 'Actionable insights'),
          ],
        ),
      ],
    );
  }
}

class _HighlightChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HighlightChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      avatar: Icon(icon, size: 18, color: theme.colorScheme.primary),
      label: Text(label),
      backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
    );
  }
}
