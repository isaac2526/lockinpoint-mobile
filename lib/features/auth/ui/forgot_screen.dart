import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api.dart';
import '../../../design/components.dart';
import '../../../design/glass.dart';
import '../../../design/motion_widgets.dart';
import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';

/// ===========================================================================
/// FORGOT PASSWORD
///
/// The same two step flow as the website: an email receives a code, the code
/// plus a new password resets the account. Both talk to the routes that are
/// already live in production, so this works today.
/// ===========================================================================
class ForgotScreen extends ConsumerStatefulWidget {
  const ForgotScreen({super.key, this.prefillEmail});
  final String? prefillEmail;

  @override
  ConsumerState<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends ConsumerState<ForgotScreen> {
  late final _email = TextEditingController(text: widget.prefillEmail ?? '');
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _codeSent = false;
  bool _busy = false;
  bool _hidden = true;
  String? _error;
  String? _errorDetail;
  String? _notice;

  @override
  void dispose() {
    for (final c in [_email, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() {
        _errorDetail = null;
        _error = 'Enter the email you signed up with.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final res = await ref
          .read(apiProvider)
          .post('/api/auth/forgot', body: {'email': email});
      setState(() {
        _busy = false;
        _codeSent = true;
        _notice =
            (res['message'] as String?) ??
            'A reset code is on its way to $email. Check your inbox and spam.';
      });
    } on ApiFailure catch (e) {
      setState(() {
        _busy = false;
        _error = e.message;
        _errorDetail = e.detail;
      });
    }
  }

  Future<void> _reset() async {
    if (_password.text.length < 8) {
      setState(() {
        _errorDetail = null;
        _error = 'Choose a password of at least 8 characters.';
      });
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() {
        _errorDetail = null;
        _error = 'The two passwords do not match.';
      });
      return;
    }
    if (_code.text.trim().isEmpty) {
      setState(() {
        _errorDetail = null;
        _error = 'Enter the code from your email.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await ref
          .read(apiProvider)
          .post(
            '/api/auth/reset',
            body: {
              'email': _email.text.trim(),
              'code': _code.text.trim(),
              'password': _password.text,
            },
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (res['message'] as String?) ??
                'Password changed. Log in with the new one.',
          ),
        ),
      );
    } on ApiFailure catch (e) {
      setState(() {
        _busy = false;
        _error = e.message;
        _errorDetail = e.detail;
      });
    }
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
            Entrance(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reset your password',
                    style: LipType.hero.copyWith(color: c.text1),
                  ),
                  const SizedBox(height: Gap.sm),
                  Text(
                    _codeSent
                        ? 'Enter the code from your email and choose a new password.'
                        : 'We will email you a code that lets you choose a new one.',
                    style: LipType.body.copyWith(color: c.text2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Gap.xl),

            if (_error != null) ...[
              LipFormError(message: _error!, detail: _errorDetail),
              const SizedBox(height: Gap.lg),
            ],
            if (_notice != null) ...[
              _Banner(text: _notice!, colour: c.success),
              const SizedBox(height: Gap.lg),
            ],

            const LipLabel('Email'),
            const SizedBox(height: Gap.sm),
            TextFormField(
              controller: _email,
              enabled: !_codeSent,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(hintText: 'you@example.com'),
            ),
            const SizedBox(height: Gap.lg),

            if (!_codeSent)
              LipButton(
                label: 'Email me a code',
                busy: _busy,
                onPressed: _sendCode,
              )
            else ...[
              const LipLabel('Code from the email'),
              const SizedBox(height: Gap.sm),
              TextFormField(
                controller: _code,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: '6 digit code'),
              ),
              const SizedBox(height: Gap.lg),
              const LipLabel('New password'),
              const SizedBox(height: Gap.sm),
              TextFormField(
                controller: _password,
                obscureText: _hidden,
                decoration: InputDecoration(
                  hintText: 'At least 8 characters',
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
              ),
              const SizedBox(height: Gap.lg),
              const LipLabel('Confirm new password'),
              const SizedBox(height: Gap.sm),
              TextFormField(
                controller: _confirm,
                obscureText: _hidden,
                decoration: const InputDecoration(
                  hintText: 'Type it once more',
                ),
              ),
              const SizedBox(height: Gap.xl),
              LipButton(
                label: 'Change my password',
                busy: _busy,
                onPressed: _reset,
              ),
              const SizedBox(height: Gap.md),
              Center(
                child: TextButton(
                  onPressed: _busy ? null : _sendCode,
                  child: const Text('Send the code again'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.colour});
  final String text;
  final Color colour;

  @override
  Widget build(BuildContext context) => GlassSurface(
    tier: GlassTier.deep,
    radius: Radii.md,
    padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.md),
    child: Row(
      children: [
        Icon(Icons.info_outline_rounded, size: 17, color: colour),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: Text(text, style: LipType.small.copyWith(color: colour)),
        ),
      ],
    ),
  );
}
