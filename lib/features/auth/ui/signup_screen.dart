import '../../../core/json.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api.dart';
import '../../../design/components.dart';
import '../../../design/motion_widgets.dart';
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
/// The same fields the website collects, checked BEFORE the round trip:
///
///   · the username is checked live against the platform while you type,
///     through the same endpoint the website uses
///   · the password has a strength meter and must be confirmed twice
///   · the referral code is checked for shape as you type
///
/// Nothing is discovered at the submit button that could have been said while
/// the student was still on the field.
/// ===========================================================================
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

enum _NameCheck { idle, checking, free, taken, invalid }

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _stepOne = GlobalKey<FormState>();
  final _stepTwo = GlobalKey<FormState>();

  final _surname = TextEditingController();
  final _firstName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _phone = TextEditingController();
  final _referral = TextEditingController();

  String _gender = 'male';
  String _country = 'NG';
  bool _hidden = true;
  int _step = 0;
  bool _busy = false;
  String? _error;
  String? _errorDetail;

  Timer? _nameDebounce;
  _NameCheck _nameCheck = _NameCheck.idle;
  String _nameWhy = '';

  String get _dial => _countries.firstWhere((c) => c.code == _country).dial;

  @override
  void initState() {
    super.initState();
    _username.addListener(_onUsernameChanged);
    _password.addListener(() => setState(() {}));
    _referral.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameDebounce?.cancel();
    for (final c in [
      _surname,
      _firstName,
      _username,
      _email,
      _password,
      _confirm,
      _phone,
      _referral,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Live availability, debounced so a fast typist costs one request, not ten.
  void _onUsernameChanged() {
    final name = _username.text.trim();
    _nameDebounce?.cancel();
    if (name.length < 3) {
      setState(() => _nameCheck = _NameCheck.idle);
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9_.]{3,20}$').hasMatch(name)) {
      setState(() {
        _nameCheck = _NameCheck.invalid;
        _nameWhy = 'Letters, numbers, dot and underscore only.';
      });
      return;
    }
    setState(() => _nameCheck = _NameCheck.checking);
    _nameDebounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final res = await ref
            .read(apiProvider)
            .get('/api/auth/check-username', query: {'u': name});
        if (!mounted || _username.text.trim() != name) return;
        final free = res['free'];
        setState(() {
          if (free == true) {
            _nameCheck = _NameCheck.free;
            _nameWhy = 'This name is yours.';
          } else if (free == false) {
            _nameCheck = _NameCheck.taken;
            _nameWhy =
                (asTextOrNull(res['why'])) ?? 'Already taken. Try another.';
          } else {
            _nameCheck = _NameCheck.idle;
          }
        });
      } catch (_) {
        // Offline is not a verdict; the server will still check on submit.
        if (mounted) setState(() => _nameCheck = _NameCheck.idle);
      }
    });
  }

  /// 0..3. Length is the backbone; variety is the refinement.
  int get _strength {
    final p = _password.text;
    if (p.length < 8) return 0;
    var score = 1;
    if (p.length >= 12) score++;
    final variety = [
      RegExp(r'[a-z]'),
      RegExp(r'[A-Z]'),
      RegExp(r'[0-9]'),
      RegExp(r'[^a-zA-Z0-9]'),
    ].where((r) => r.hasMatch(p)).length;
    if (variety >= 3) score++;
    return score;
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
        _step = 0; // most rejections concern the email or the username
        _error = e is ApiFailure
            ? e.message
            : 'That did not work. Please try again.';
        _errorDetail = e is ApiFailure ? e.detail : null;
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
            const Entrance(child: LipWordmark(size: 34)),
            const SizedBox(height: Gap.xl),
            Entrance(
              index: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _step == 0 ? 'Create your account' : 'Almost there',
                    style: LipType.hero.copyWith(color: c.text1),
                  ),
                  const SizedBox(height: Gap.sm),
                  Text(
                    _step == 0 ? 'A free account opens the question bank.' : 'Where we can reach you, and where you are sitting from.',
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

            if (_step == 0) _one(c) else _two(c),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- step 1 --
  Widget _one(dynamic c) => Form(
    key: _stepOne,
    child: Entrance(
      index: 2,
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

          // ---- username with the live verdict -----------------------
          const LipLabel('Username'),
          const SizedBox(height: Gap.sm),
          TextFormField(
            controller: _username,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'e.g. sharpshooter01',
              suffixIcon: switch (_nameCheck) {
                _NameCheck.checking => const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                _NameCheck.free => Icon(
                  Icons.check_circle_rounded,
                  color: c.success,
                ),
                _NameCheck.taken || _NameCheck.invalid => Icon(
                  Icons.cancel_rounded,
                  color: c.danger,
                ),
                _ => null,
              },
            ),
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.isEmpty) return 'Pick a username.';
              if (s.length < 3) return 'At least 3 characters.';
              if (_nameCheck == _NameCheck.taken) {
                return 'That username is taken. Pick another one.';
              }
              if (_nameCheck == _NameCheck.invalid) return _nameWhy;
              return null;
            },
          ),
          if (_nameCheck == _NameCheck.free ||
              _nameCheck == _NameCheck.taken ||
              _nameCheck == _NameCheck.invalid) ...[
            const SizedBox(height: Gap.xs),
            Text(
              _nameWhy,
              style: LipType.caption.copyWith(
                color: _nameCheck == _NameCheck.free ? c.success : c.danger,
              ),
            ),
          ],
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

          // ---- password with the strength meter ---------------------
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
            validator: (v) => (v ?? '').length < 8
                ? 'Choose a password of at least 8 characters.'
                : null,
          ),
          if (_password.text.isNotEmpty) ...[
            const SizedBox(height: Gap.sm),
            _StrengthMeter(strength: _strength),
          ],
          const SizedBox(height: Gap.lg),

          const LipLabel('Confirm password'),
          const SizedBox(height: Gap.sm),
          TextFormField(
            controller: _confirm,
            obscureText: _hidden,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(hintText: 'Type it once more'),
            validator: (v) => (v ?? '') != _password.text
                ? 'The two passwords do not match.'
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
    ),
  );

  // ---------------------------------------------------------------- step 2 --
  Widget _two(dynamic c) {
    final ref5 = _referral.text.trim();
    return Form(
      key: _stepTwo,
      child: Entrance(
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
                  child: Text(
                    _dial,
                    style: LipType.mono.copyWith(color: c.text1),
                  ),
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

            const LipLabel('Referral code, if a friend gave you one'),
            const SizedBox(height: Gap.sm),
            TextFormField(
              controller: _referral,
              maxLength: 5,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: '5 character code',
                counterText: '',
              ),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return null; // genuinely optional
                if (s.length != 5) {
                  return 'A referral code is exactly 5 characters.';
                }
                return null;
              },
            ),
            if (ref5.isNotEmpty && ref5.length < 5) ...[
              const SizedBox(height: Gap.xs),
              Text(
                '${5 - ref5.length} more character${5 - ref5.length == 1 ? '' : 's'} to go.',
                style: LipType.caption.copyWith(color: c.text3),
              ),
            ],
            const SizedBox(height: Gap.xl),
            LipButton(
              label: 'Create my account',
              busy: _busy,
              onPressed: _submit,
            ),
            const SizedBox(height: Gap.md),
            Text(
              'We send a code to your email to confirm it is yours.',
              style: LipType.caption.copyWith(color: c.text3),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String hint, {
    TextInputType? keyboard,
    String? autofill,
    String? Function(String?)? validator,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      LipLabel(label),
      const SizedBox(height: Gap.sm),
      TextFormField(
        controller: controller,
        keyboardType: keyboard,
        autofillHints: autofill == null ? null : [autofill],
        decoration: InputDecoration(hintText: hint),
        validator:
            validator ??
            (v) => (v ?? '').trim().isEmpty ? 'This one is needed.' : null,
      ),
    ],
  );
}

/// Weak, Good, Strong. Three segments filling with the tone of the verdict, so
/// the student sees the password improving as they type it.
class _StrengthMeter extends StatelessWidget {
  const _StrengthMeter({required this.strength});
  final int strength;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final (label, colour) = switch (strength) {
      0 => ('Too short', c.danger),
      1 => ('Weak', c.warning),
      2 => ('Good', c.success),
      _ => ('Strong', c.success),
    };
    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: Motion.base,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.pill),
                color: i < strength ? colour : c.glassDeep,
              ),
            ),
          ),
          const SizedBox(width: Gap.xs),
        ],
        const SizedBox(width: Gap.sm),
        Text(label, style: LipType.caption.copyWith(color: colour)),
      ],
    );
  }
}
