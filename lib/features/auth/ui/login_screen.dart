import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api.dart';
import '../../../design/components.dart';
import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../design/wordmark.dart';
import '../auth_controller.dart';
import 'forgot_screen.dart';
import 'signup_screen.dart';

/// Log in with the same account as the website — the same email or username,
/// the same password. This posts to /api/auth/login, which is the route the
/// browser uses, so the device slot and the activity log stay correct.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _hidden = true;
  bool _busy = false;
  String? _error;
  String? _errorDetail;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    await ref
        .read(authControllerProvider.notifier)
        .logIn(identifier: _identifier.text, password: _password.text);

    if (!mounted) return;
    final state = ref.read(authControllerProvider);
    if (state.hasError) {
      final e = state.error;
      setState(() {
        _busy = false;
        _error = e is ApiFailure
            ? e.message
            : 'That did not work. Please try again.';
        _errorDetail = e is ApiFailure ? e.detail : null;
      });
      return;
    }
    // Signed in — the router swaps the whole tree, so just leave this screen.
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lip;

    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.huge),
          children: [
            const LipWordmark(size: 34),
            const SizedBox(height: Gap.xl),
            Text('Welcome back', style: LipType.hero.copyWith(color: c.text1)),
            const SizedBox(height: Gap.sm),
            Text(
              'Your seat in the hall is waiting.',
              style: LipType.body.copyWith(color: c.text2),
            ),
            const SizedBox(height: Gap.xl),

            if (_error != null) ...[
              LipFormError(message: _error!, detail: _errorDetail),
              const SizedBox(height: Gap.lg),
            ],

            Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const LipLabel('Email or username'),
                  const SizedBox(height: Gap.sm),
                  TextFormField(
                    controller: _identifier,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(
                      hintText: 'you@example.com',
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Enter your email or username.'
                        : null,
                  ),
                  const SizedBox(height: Gap.lg),
                  const LipLabel('Password'),
                  const SizedBox(height: Gap.sm),
                  TextFormField(
                    controller: _password,
                    obscureText: _hidden,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      hintText: 'Your password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _hidden
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                          color: c.text3,
                        ),
                        tooltip: _hidden ? 'Show password' : 'Hide password',
                        onPressed: () => setState(() => _hidden = !_hidden),
                      ),
                    ),
                    validator: (v) =>
                        (v ?? '').isEmpty ? 'Enter your password.' : null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: Gap.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ForgotScreen(
                            prefillEmail: _identifier.text.contains('@')
                                ? _identifier.text.trim()
                                : null,
                          ),
                        ),
                      ),
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: Gap.md),
            LipButton(label: 'Log in', busy: _busy, onPressed: _submit),
            const SizedBox(height: Gap.md),

            Center(
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const SignupScreen()),
                      ),
                child: const Text('New here? Create a free account'),
              ),
            ),

            const SizedBox(height: Gap.lg),
            Text(
              'One account works on one device at a time. Logging in here '
              'signs you out of your browser. A test you have already started '
              'is never interrupted.',
              style: LipType.caption.copyWith(color: c.text3),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
