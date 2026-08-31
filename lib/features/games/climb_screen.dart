import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../design/components.dart';
import '../../design/glass.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../activation/activation_screen.dart';
import '../tutor/tutor_screen.dart';
import 'games_repository.dart';

/// ===========================================================================
/// THE CLIMB
///
/// Fifteen rungs in five bands, one fixed safety net, and a SECOND NET THE
/// PLAYER PLACES THEMSELVES — a wager they have to commit to out loud, which
/// is what makes this better than the format it borrows from.
///
/// THE APP GRADES NOTHING. Every answer goes to the server and comes back
/// judged; the rung, the score, what is banked and which lifelines remain are
/// all read from the server's reply. The answer key is never sent to the
/// phone, so the game cannot be beaten with a debugger — which is the entire
/// reason the ladder lives server-side.
/// ===========================================================================

const _lifelineNames = {
  'fifty': ('Fifty-fifty', 'Two wrong options disappear'),
  'class': ('Ask the class', 'What other students actually chose'),
  'lumi': ('Ask Lumi', 'A nudge from your tutor'),
  'switch': ('Switch the question', 'Swap it for another of the same weight'),
  'doubledip': ('Double dip', 'A second guess — earned at rung ten'),
};

class ClimbSetupScreen extends ConsumerStatefulWidget {
  const ClimbSetupScreen({super.key});

  @override
  ConsumerState<ClimbSetupScreen> createState() => _ClimbSetupScreenState();
}

class _ClimbSetupScreenState extends ConsumerState<ClimbSetupScreen> {
  final _chosen = <String>{'fifty', 'class', 'lumi'};
  String _mode = 'classic';
  bool _busy = false;
  String _error = '';
  bool _needActivation = false;

  Future<void> _start() async {
    final api = ref.read(apiProvider);
    setState(() {
      _busy = true;
      _error = '';
      _needActivation = false;
    });
    try {
      final state = await ClimbApi(api)
          .start(lifelines: _chosen.toList(), mode: _mode);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => ClimbScreen(initial: state)),
      );
    } on ApiFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _needActivation = e.data?['needActivation'] == true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lip;

    return Scaffold(
      appBar: AppBar(title: const Text('The Climb')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.huge),
          children: [
            GlassSurface(
              hue: c.hues.amber,
              child: Text(
                'Fifteen questions, easiest first. Clear rung five and you keep '
                'those points whatever happens after. Somewhere above that you '
                'place a SECOND net yourself — and once placed it cannot move.',
                style: LipType.body.copyWith(color: c.text1, height: 1.5),
              ),
            ),
            const SizedBox(height: Gap.lg),
            const LipLabel('Pick exactly three lifelines'),
            const SizedBox(height: Gap.sm),
            ..._lifelineNames.entries.map((e) {
              final on = _chosen.contains(e.key);
              return Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: GlassSurface(
                  tier: GlassTier.raised,
                  selected: on,
                  padding: const EdgeInsets.all(Gap.md),
                  onTap: () => setState(() {
                    if (on) {
                      _chosen.remove(e.key);
                    } else if (_chosen.length < 3) {
                      _chosen.add(e.key);
                    }
                  }),
                  child: Row(
                    children: [
                      Icon(
                        on ? Icons.check_circle_rounded : Icons.circle_outlined,
                        size: 20,
                        color: on ? c.brand : c.text3,
                      ),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.value.$1,
                              style: LipType.subheading.copyWith(
                                color: c.text1,
                              ),
                            ),
                            Text(
                              e.value.$2,
                              style: LipType.caption.copyWith(color: c.text3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: Gap.lg),
            const LipLabel('Mode'),
            const SizedBox(height: Gap.sm),
            Row(
              children: [
                Expanded(
                  child: LipChoiceCard(
                    icon: Icons.self_improvement_rounded,
                    title: 'Classic',
                    subtitle: 'No clock. Think as long as you like.',
                    selected: _mode == 'classic',
                    onTap: () => setState(() => _mode = 'classic'),
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: LipChoiceCard(
                    icon: Icons.timer_rounded,
                    title: 'Clock',
                    subtitle: 'Unused seconds bank onto the last question.',
                    selected: _mode == 'clock',
                    onTap: () => setState(() => _mode = 'clock'),
                  ),
                ),
              ],
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: Gap.lg),
              LipFormError(message: _error),
              if (_needActivation) ...[
                const SizedBox(height: Gap.md),
                LipButton(
                  gold: true,
                  icon: Icons.vpn_key_rounded,
                  label: 'Activate to climb',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ActivationScreen(),
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: Gap.xl),
            LipButton(
              gold: true,
              label: _chosen.length == 3
                  ? 'Start climbing'
                  : 'Pick ${3 - _chosen.length} more',
              busy: _busy,
              onPressed: _chosen.length == 3 ? _start : null,
            ),
          ],
        ),
      ),
    );
  }
}

class ClimbScreen extends ConsumerStatefulWidget {
  const ClimbScreen({super.key, required this.initial});
  final ClimbState initial;

  @override
  ConsumerState<ClimbScreen> createState() => _ClimbScreenState();
}

class _ClimbScreenState extends ConsumerState<ClimbScreen> {
  late ClimbState _s;
  String _message = '';
  String? _revealed;
  String? _picked;
  bool _busy = false;

  /// Double Dip has been spent and is waiting to absorb one wrong answer.
  /// Without this the server never hears `secondGuess` and the lifeline is
  /// bought for nothing.
  bool _dipArmed = false;
  Map<String, int>? _classSays;
  int _left = 0;
  Timer? _clock;

  /// The question the student is looking at, so Ask Lumi is about THIS rung
  /// rather than the game in general. Null when the server did not name one,
  /// in which case Lumi opens as a plain chat.
  String? get _currentQuestionId => _s.questionId;

  @override
  void initState() {
    super.initState();
    _s = widget.initial;
    _armClock();
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  void _armClock() {
    _clock?.cancel();
    final secs = _s.seconds;
    if (secs == null || !_s.playing) return;
    setState(() => _left = secs);
    _clock = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _left--);
      if (_left <= 0) {
        t.cancel();
        // Out of time is a wrong answer, and the server must be the one to
        // say so — sending an empty letter lets it judge and end the game.
        _answer('');
      }
    });
  }

  Future<void> _answer(String letter, {bool second = false}) async {
    if (_busy) return;
    final api = ref.read(apiProvider);
    _clock?.cancel();
    setState(() {
      _busy = true;
      _picked = letter;
      _message = '';
    });
    try {
      final a = await ClimbApi(api).answer(
        _s.id,
        letter,
        timeLeft: _s.seconds == null ? null : _left,
        // The FIRST wrong answer after arming the dip is the one the server
        // must be told about; a second wrong answer really does end it.
        secondGuess: second || _dipArmed,
      );
      if (!mounted) return;

      if (!a.correct && a.right == null) {
        // Double Dip absorbed it: wrong, the game continues, and the server
        // has deliberately not said what the answer is — so the second guess
        // is still a guess.
        setState(() {
          _dipArmed = false;
          _message = 'Not that one. Your double dip gives you one more try.';
          _picked = null;
          _busy = false;
        });
        _armClock();
        return;
      }

      setState(() {
        _revealed = a.right;
        _message = a.explanation;
        _dipArmed = false;
        if (a.state != null) _s = a.state!;
        _busy = false;
      });

      /* A LOST CLIMB STILL TEACHES. The ending screen used to replace the
         question the instant a wrong answer landed, so the student never saw
         which option was right — even though the server had just sent it.
         Hold the reveal on screen first. */
      if (!_s.playing && a.right != null) {
        await Future<void>.delayed(const Duration(milliseconds: 2200));
        if (!mounted) return;
        setState(() {});
      }

      if (_s.playing) {
        // A beat to read the explanation, then the next rung.
        /* THE READING BEAT IS A PAUSE, NOT A WINDOW. The next rung used to
           arrive with the PREVIOUS question's explanation still under it and
           its options already live — a tap in that gap was silently wiped by
           the delayed reset. _busy holds through the beat, so the options
           stay inert until the new question is really on screen. */
        setState(() => _busy = true);
        await Future<void>.delayed(const Duration(milliseconds: 1400));
        if (!mounted) return;
        setState(() {
          _picked = null;
          _revealed = null;
          _classSays = null;
          _message = '';
          _busy = false;
        });
        _armClock();
      }
    } on ApiFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e.message;
        _busy = false;
        _picked = null;
      });
    }
  }

  Future<void> _spend(String which) async {
    final api = ref.read(apiProvider);
    final navigator = Navigator.of(context);

    /* ASK LUMI IS A CONVERSATION, NOT A PAYLOAD. The route says so in its own
       comment — "Lumi is answered by the chat panel" — and returns only a
       state. The app was hunting a hint key that is never sent, so the
       lifeline vanished and showed nothing at all. It now spends the lifeline
       and OPENS Lumi on this very question. */
    setState(() => _busy = true);
    try {
      final vote = await ClimbApi(api).lifeline(_s.id, which);
      if (!mounted) return;
      setState(() {
        if (vote?.state != null) _s = vote!.state!;
        if (vote?.percentages != null) {
          _classSays = vote!.percentages;
          _message = vote.real
              ? 'How ${vote.sample} students answered this one.'
              : 'Too few students have met this question — that split is an '
                    'estimate, not a crowd.';
        }
        /* DOUBLE DIP IS ARMED, and the student is told. The server only
           honours a second guess when the app SENDS secondGuess, which it
           never did — so the earned lifeline protected nothing and the next
           wrong answer still ended the climb. */
        if (which == 'doubledip') {
          _dipArmed = true;
          _message = 'Double dip is live: your next answer gets a second try.';
        }
        _busy = false;
      });

      if (which == 'lumi') {
        await navigator.push<void>(
          MaterialPageRoute(
            builder: (_) => TutorScreen(
              questionId: _currentQuestionId,
              opening:
                  'Give me a hint for this question — do not tell me the '
                  'answer outright.',
            ),
          ),
        );
      }
      _armClock();
    } on ApiFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e.message;
        _busy = false;
      });
      _armClock();
    }
  }

  Future<void> _placeNet() async {
    final api = ref.read(apiProvider);
    final chosen = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) {
        final c = ctx.lip;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(Gap.lg),
            children: [
              Text(
                'Place your second net',
                style: LipType.title.copyWith(color: c.text1),
              ),
              const SizedBox(height: Gap.xs),
              Text(
                'Above where you are now, below the top. Once placed it cannot '
                'move — that is the whole wager.',
                style: LipType.small.copyWith(color: c.text3),
              ),
              const SizedBox(height: Gap.md),
              ...List.generate(_s.total - 1, (i) => i + 1)
                  .where((r) => r > _s.firstNet && r > _s.rung)
                  .map(
                    (r) => ListTile(
                      title: Text(
                        'Rung $r · ${_s.ladder.length >= r ? _s.ladder[r - 1] : 0} points',
                        style: LipType.body.copyWith(color: c.text1),
                      ),
                      onTap: () => Navigator.of(ctx).pop(r),
                    ),
                  ),
            ],
          ),
        );
      },
    );
    if (chosen == null || !mounted) return;
    try {
      final st = await ClimbApi(api).setNet(_s.id, chosen);
      if (!mounted) return;
      setState(() => _s = st);
    } on ApiFailure catch (e) {
      if (!mounted) return;
      setState(() => _message = e.message);
    }
  }

  Future<void> _walk() async {
    final api = ref.read(apiProvider);
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Walk away?'),
        content: Text('You keep ${_s.score} points and the climb ends here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep climbing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Walk away'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    _clock?.cancel();
    try {
      final st = await ClimbApi(api).walk(_s.id);
      if (!mounted) return;
      setState(() => _s = st);
    } on ApiFailure catch (e) {
      if (!mounted) return;
      setState(() => _message = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    if (!_s.playing) return _ending(c);

    return PopScope(
      /* A LIVE CLIMB IS NOT ABANDONED BY ACCIDENT. Back used to drop a
         server-graded game on the floor: points gone, the game still
         "playing" on the server, no way back into it. Walking away is a
         decision with a number attached, so it is made deliberately. */
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) _walk();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Rung ${_s.rung} of ${_s.total}'),
          actions: [
            TextButton(
              onPressed: _busy ? null : _walk,
              child: const Text('Walk'),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              _header(c),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.lg,
                    Gap.md,
                    Gap.lg,
                    Gap.huge,
                  ),
                  children: [
                    Text(
                      _s.question,
                      style: LipType.question.copyWith(
                        color: c.text1,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: Gap.lg),
                    ..._s.options.map((o) {
                      final chosen = _picked == o.letter;
                      final right = _revealed == o.letter;
                      final wrongPick = chosen && _revealed != null && !right;
                      final share = _classSays?[o.letter];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: Gap.sm),
                        child: GlassSurface(
                          tier: GlassTier.raised,
                          selected: chosen && _revealed == null,
                          padding: const EdgeInsets.all(Gap.md),
                          onTap: _busy ? null : () => _answer(o.letter),
                          child: Row(
                            children: [
                              Text(
                                '${o.letter}. ',
                                style: LipType.option.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: right
                                      ? c.success
                                      : wrongPick
                                      ? c.danger
                                      : c.text3,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  o.text,
                                  style: LipType.option.copyWith(
                                    color: right
                                        ? c.success
                                        : wrongPick
                                        ? c.danger
                                        : c.text1,
                                  ),
                                ),
                              ),
                              if (share != null)
                                LipChip('$share%', tone: ChipTone.neutral),
                            ],
                          ),
                        ),
                      );
                    }),
                    if (_message.isNotEmpty) ...[
                      const SizedBox(height: Gap.md),
                      GlassSurface(
                        tier: GlassTier.deep,
                        child: Text(
                          _message,
                          style: LipType.small.copyWith(
                            color: c.text2,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: Gap.lg),
                    _lifelines(c),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(LipColors c) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
    child: Row(
      children: [
        Expanded(
          child: LipStat(
            value: '${_s.score}',
            label: 'points',
            tone: ChipTone.brand,
          ),
        ),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: LipStat(
            value: '${_s.banked}',
            label: 'banked',
            tone: ChipTone.success,
          ),
        ),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: _s.seconds == null
              ? GestureDetector(
                  onTap: _s.secondNet == null ? _placeNet : null,
                  child: LipStat(
                    value: _s.secondNet == null ? 'SET' : '${_s.secondNet}',
                    label: 'second net',
                    tone: ChipTone.gold,
                  ),
                )
              : LipStat(
                  value: '$_left',
                  label: 'seconds',
                  tone: _left <= 5 ? ChipTone.danger : ChipTone.warning,
                ),
        ),
      ],
    ),
  );

  Widget _lifelines(LipColors c) {
    final available = _s.lifelines.entries.where((e) => e.value).toList();
    if (available.isEmpty) {
      return Text(
        'Every lifeline is spent. From here it is just you.',
        style: LipType.small.copyWith(color: c.text3),
      );
    }
    return Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.sm,
      children: [
        for (final e in available)
          LipChip(
            _lifelineNames[e.key]?.$1 ?? e.key,
            tone: ChipTone.gold,
            onTap: _busy ? null : () => _spend(e.key),
          ),
        if (_s.secondNet == null && _s.seconds != null)
          LipChip(
            'Place second net',
            tone: ChipTone.brand,
            onTap: _busy ? null : _placeNet,
          ),
      ],
    );
  }

  Widget _ending(LipColors c) {
    final (icon, tint, headline) = switch (_s.status) {
      'won' => (
        Icons.workspace_premium_rounded,
        c.success,
        'You reached the top',
      ),
      'walked' => (Icons.handshake_rounded, c.accent, 'You walked away'),
      _ => (Icons.trending_down_rounded, c.danger, 'The climb ended'),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('The Climb')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Gap.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 56, color: tint),
                const SizedBox(height: Gap.md),
                Text(headline, style: LipType.title.copyWith(color: c.text1)),
                const SizedBox(height: Gap.sm),
                const LipLabel('You keep'),
                Text(
                  '${_s.score}',
                  style: LipType.hero.copyWith(color: c.text1),
                ),
                Text('points', style: LipType.small.copyWith(color: c.text3)),
                if (_message.isNotEmpty) ...[
                  const SizedBox(height: Gap.lg),
                  Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: LipType.small.copyWith(color: c.text2, height: 1.5),
                  ),
                ],
                const SizedBox(height: Gap.xl),
                LipButton(
                  gold: true,
                  icon: Icons.refresh_rounded,
                  label: 'Climb again',
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => const ClimbSetupScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: Gap.sm),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back to the arena'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
