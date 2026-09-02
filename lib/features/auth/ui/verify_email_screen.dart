import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api.dart';
import '../../../design/components.dart';
import '../../../design/glass.dart';
import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../home/dashboard_screen.dart';

/// ===========================================================================
/// ENTER THE CODE FROM YOUR EMAIL
///
/// WHY THIS SCREEN EXISTS.
/// Signing up sends a six-digit code and an email that says, in so many
/// words, "enter it on the verify page". The website has that page. The app
/// did not — so a student who created their account on their phone read an
/// instruction the app gave them no way to follow, and the badge on their
/// dashboard stayed unverified for ever.
///
/// It posts to the same /api/auth/verify the website uses. Nothing here
/// decides whether a code is right; the server does, and says so.
/// ===========================================================================
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, this.email});

  /// Shown back to the student so they know which inbox to open.
  final String? email;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String _error = '';

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _code.text.trim();
    if (code.length < 6 || _busy) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await ref
          .read(apiProvider)
          .post('/api/auth/verify', body: {'code': code});
      if (!mounted) return;
      // The badge on the dashboard is the point of all this, so refresh it
      // before leaving rather than showing a stale "not verified".
      ref.read(dashboardProvider.notifier).refresh();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Your email is verified. Thank you.')),
        );
      Navigator.of(context).pop(true);
    } on ApiFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    return Scaffold(
      appBar: AppBar(title: const Text('Verify your email')),
      body: ListView(
        padding: const EdgeInsets.all(Gap.lg),
        children: [
          Text(
            'Check your email',
            style: LipType.heading.copyWith(color: c.text1),
          ),
          const SizedBox(height: Gap.xs),
          Text(
            widget.email == null || widget.email!.isEmpty
                ? 'We sent a six digit code to your inbox. Enter it below.'
                : 'We sent a six digit code to ${widget.email}. Enter it below.',
            style: LipType.small.copyWith(color: c.text3, height: 1.5),
          ),
          const SizedBox(height: Gap.lg),
          GlassSurface(
            tier: GlassTier.raised,
            child: TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: LipType.hero.copyWith(color: c.text1, letterSpacing: 10),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: '000000',
                counterText: '',
                border: InputBorder.none,
              ),
              // The button below lives or dies on this text, so it has to
              // rebuild as the student types — a Redeem-shaped bug this app
              // has already paid for once.
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: Gap.md),
            GlassSurface(
              tier: GlassTier.deep,
              child: Text(
                _error,
                style: LipType.small.copyWith(color: c.danger),
              ),
            ),
          ],
          const SizedBox(height: Gap.lg),
          LipButton(
            label: 'Verify my email',
            icon: Icons.verified_rounded,
            busy: _busy,
            onPressed: _code.text.trim().length == 6 && !_busy ? _submit : null,
          ),
          const SizedBox(height: Gap.md),
          Text(
            'Nothing arrived? Check your spam folder. You can keep using '
            'LockInPoint in the meantime and verify later.',
            style: LipType.caption.copyWith(color: c.text3, height: 1.5),
          ),
        ],
      ),
    );
  }
}
