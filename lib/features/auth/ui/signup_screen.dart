import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api.dart';
import '../../../design/components.dart';
import '../../../design/glass.dart';
import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../design/wordmark.dart';
import '../auth_controller.dart';
import 'login_screen.dart';

/// The five nations LockInPoint serves, matching `src/lib/countries.ts`.
const _countries = <({String code, String name, String dial, String flag})>[
  (code: 'NG', name: 'Nigeria', dial: '+234', flag: '🇳🇬'),
  (code: 'GH', name: 'Ghana', dial: '+233', flag: '🇬🇭'),
  (code: 'SL', name: 'Sierra Leone', dial: '+232', flag: '🇸🇱'),
  (code: 'LR', name: 'Liberia', dial: '+231', flag: '🇱🇷'),
  (code: 'GM', name: 'The Gambia', dial: '+220', flag: '🇬🇲'),
];

/// ===========================================================================
/// CREATE AN ACCOUNT
///
/// The same fields the website's signup form collects, in the same order, so
/// the account created here is indistinguishable from one created in a
/// browser. Posts to /api/auth/signup and then signs in.
///
/// The form is in two steps rather than one long scroll: a phone keyboard eats
/// half the screen, and ten fields under it is where people give up.
/// ===========================================================================
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _stepOne = GlobalKey<FormState>();
  final _stepTwo = GlobalKey<FormState>();

  final _surname = TextEditingController();
  final _firstName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _referral = TextEditingController();

  String _gender = 'male';
  String _country = 'NG';
  bool _hidden = true;
  int _step = 0;
  bool _busy = false;
  String? _error;

  String get _dial => _countries.firstWhere((c) => c.code == _country).dial;

  @override
  void dispose() {
    for (final c in [
      _surname,
      _firstName,
      _username,
      _email,
      _password,
      _phone,
      _referral,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_stepTwo.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    await ref.read(authControllerProvider.notifier).signUp({
      'surname': _surname.text.trim(),
      'first_name': _firstName.text.trim(),
      'username': _username.text.trim(),
      'gender': _gender,
      'email': _email.text.trim(),
      'password': _password.text,
      'phone': _phone.text.trim(),
      'dial_code': _dial,
      'country_code': _country,
      'referral': _referral.text.trim(),
    });

    if (!mounted) return;
    final state = ref.read(authControllerProvider);
    if (state.hasError) {
      final e = state.error;
      setState(() {
        _busy = false;
        _step = 0; // most failures are the email or the username
        _error = e is ApiFailure
            ? e.message
            : 'That did not work. Please try again.';
      });
      return;
    }
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lip;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: _step == 1 ? () => setState(() => _step = 0) : null,
        ),
        title: Text(
          'Step ${_step + 1} of 2',
          style: LipType.small.copyWith(color: c.text3),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.huge),
          children: [
            const LipWordmark(size: 34),
            const SizedBox(height: Gap.xl),
            Text(
              _step == 0 ? 'Create your account' : 'Almost there',
              style: LipType.hero.copyWith(color: c.text1),
            ),
            const SizedBox(height: Gap.sm),
            Text(
              _step == 0
                  ? 'Free to open. See everything before you pay for anything.'
                  : 'Where we can reach you, and where you are sitting from.',
              style: LipType.body.copyWith(color: c.text2),
            ),
            const SizedBox(height: Gap.xl),

            if (_error != null) ...[
              GlassSurface(
                tier: GlassTier.deep,
                radius: Radii.md,
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.md,
                  vertical: Gap.md,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 17,
                      color: c.danger,
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: Text(
                        _error!,
                        style: LipType.small.copyWith(color: c.danger),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Gap.lg),
            ],

            if (_step == 0) _one(c) else _two(c),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- step 1 --
  Widget _one(dynamic c) => Form(
    key: _stepOne,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _field(
                _firstName,
                'First name',
                'Kweku',
                autofill: AutofillHints.givenName,
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: _field(
                _surname,
                'Surname',
                'Adeola',
                autofill: AutofillHints.familyName,
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.lg),
        _field(
          _username,
          'Username',
          'e.g. sharpshooter01',
          validator: (v) {
            final s = (v ?? '').trim();
            if (s.isEmpty) return 'Pick a username.';
            if (s.length < 3) return 'At least 3 characters.';
            return null;
          },
        ),
        const SizedBox(height: Gap.lg),
        _field(
          _email,
          'Email',
          'you@example.com',
          keyboard: TextInputType.emailAddress,
          autofill: AutofillHints.email,
          validator: (v) {
            final s = (v ?? '').trim();
            if (s.isEmpty) return 'Enter your email.';
            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) {
              return 'That does not look like an email address.';
            }
            return null;
          },
        ),
        const SizedBox(height: Gap.lg),
        const LipLabel('Password'),
        const SizedBox(height: Gap.sm),
        TextFormField(
          controller: _password,
          obscureText: _hidden,
          autofillHints: const [AutofillHints.newPassword],
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
          // The server rejects under 8; say so here rather than after a
          // round trip that loses everything typed.
          validator: (v) => (v ?? '').length < 8
              ? 'Choose a password of at least 8 characters.'
              : null,
        ),
        const SizedBox(height: Gap.lg),
        const LipLabel('You are'),
        const SizedBox(height: Gap.sm),
        Row(
          children: [
            for (final g in const ['male', 'female']) ...[
              LipChip(
                g == 'male' ? 'Male' : 'Female',
                selected: _gender == g,
                onTap: () => setState(() => _gender = g),
              ),
              const SizedBox(width: Gap.sm),
            ],
          ],
        ),
        const SizedBox(height: Gap.xl),
        LipButton(
          label: 'Continue',
          icon: Icons.arrow_forward_rounded,
          onPressed: () {
            if (_stepOne.currentState?.validate() ?? false) {
              setState(() {
                _step = 1;
                _error = null;
              });
            }
          },
        ),
        const SizedBox(height: Gap.md),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
            child: const Text('I already have an account'),
          ),
        ),
      ],
    ),
  );

  // ---------------------------------------------------------------- step 2 --
  Widget _two(dynamic c) => Form(
    key: _stepTwo,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LipLabel('Country'),
        const SizedBox(height: Gap.sm),
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            for (final country in _countries)
              LipChip(
                '${country.flag}  ${country.name}',
                selected: _country == country.code,
                onTap: () => setState(() => _country = country.code),
              ),
          ],
        ),
        const SizedBox(height: Gap.lg),
        const LipLabel('Phone number'),
        const SizedBox(height: Gap.sm),
        Row(
          children: [
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: Gap.md),
              decoration: BoxDecoration(
                color: c.glassDeep,
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(color: c.glassBorder),
              ),
              alignment: Alignment.center,
              child: Text(_dial, style: LipType.mono.copyWith(color: c.text1)),
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: const InputDecoration(hintText: '8012345678'),
                validator: (v) => (v ?? '').trim().length < 7
                    ? 'Enter your phone number.'
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.lg),
        _field(
          _referral,
          'Referral code (optional)',
          '5 characters from a friend',
          required: false,
          maxLength: 5,
          caps: true,
        ),
        const SizedBox(height: Gap.xl),
        LipButton(label: 'Create my account', busy: _busy, onPressed: _submit),
        const SizedBox(height: Gap.md),
        Text(
          'We send a code to your email to confirm it is yours.',
          style: LipType.caption.copyWith(color: c.text3),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label,
    String hint, {
    TextInputType? keyboard,
    String? autofill,
    String? Function(String?)? validator,
    bool required = true,
    int? maxLength,
    bool caps = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      LipLabel(label),
      const SizedBox(height: Gap.sm),
      TextFormField(
        controller: controller,
        keyboardType: keyboard,
        autofillHints: autofill == null ? null : [autofill],
        maxLength: maxLength,
        textCapitalization: caps
            ? TextCapitalization.characters
            : TextCapitalization.none,
        decoration: InputDecoration(hintText: hint, counterText: ''),
        validator:
            validator ??
            (required
                ? (v) => (v ?? '').trim().isEmpty ? 'This one is needed.' : null
                : null),
      ),
    ],
  );
}
