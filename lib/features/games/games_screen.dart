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
import 'climb_screen.dart';
import 'games_repository.dart';

/// ===========================================================================
/// THE ARENA
///
/// Five games, purple throughout — the palette's games hue, so a student in a
/// game never mistakes it for a real sitting. That distinction matters: a
/// score here is fun, a score in Practice is a record.
///
/// Blitz 60      sixty seconds, as many as you can, combos chain
/// Survival      one wrong answer ends it
/// Daily Ten     the SAME ten questions for every student today
/// Road to 400   fifteen rungs, projected as a JAMB score
/// The Climb     the server-graded ladder, with lifelines
/// ===========================================================================

enum GameMode { blitz, survival, daily, road }

extension on GameMode {
  String get title => switch (this) {
    GameMode.blitz => 'Blitz 60',
    GameMode.survival => 'Survival',
    GameMode.daily => 'Daily Ten',
    GameMode.road => 'Road to 400',
  };

  String get blurb => switch (this) {
    GameMode.blitz => 'Sixty seconds. Chain them.',
    GameMode.survival => 'One wrong answer ends it.',
    GameMode.daily => 'The same ten for everyone today.',
    GameMode.road => 'Fifteen rungs, scored out of 400.',
  };

  IconData get icon => switch (this) {
    GameMode.blitz => Icons.local_fire_department_rounded,
    GameMode.survival => Icons.favorite_rounded,
    GameMode.daily => Icons.today_rounded,
    GameMode.road => Icons.trending_up_rounded,
  };

  int get count => switch (this) {
    GameMode.blitz => 40,
    GameMode.survival => 40,
    GameMode.daily => 10,
    GameMode.road => 15,
  };

  bool get daily => this == GameMode.daily;
}

/// Road to 400 projects onto JAMB's own scale, so the number means something
/// a student already understands rather than an arbitrary point total.
const _roadLadder = [
  40,
  60,
  90,
  120,
  150,
  180,
  210,
  240,
  265,
  290,
  310,
  330,
  355,
  380,
  400,
];

class GamesScreen extends ConsumerWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;

    Widget card({
      required IconData icon,
      required LipHue hue,
      required String title,
      required String blurb,
      required VoidCallback onTap,
      String badge = '',
    }) => GlassSurface(
      hue: hue,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: hue.ink.withValues(alpha: c.isDark ? 0.20 : 0.13),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Icon(icon, size: 24, color: hue.ink),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: LipType.subheading.copyWith(color: c.text1),
                    ),
                    if (badge.isNotEmpty) ...[
                      const SizedBox(width: Gap.sm),
                      LipChip(badge, tone: ChipTone.gold),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(blurb, style: LipType.small.copyWith(color: c.text3)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 20, color: c.text3),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Games arena')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.huge),
          children: [
            Text(
              'Real questions from the same bank, with a clock on. Nothing here '
              'touches your result history — it is practice that bites back.',
              style: LipType.small.copyWith(color: c.text3),
            ),
            const SizedBox(height: Gap.lg),
            card(
              icon: Icons.emoji_events_rounded,
              hue: c.hues.amber,
              title: 'The Climb',
              blurb: 'Fifteen rungs, three lifelines, two safety nets.',
              badge: 'GRADED BY THE SERVER',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ClimbSetupScreen(),
                ),
              ),
            ),
            const SizedBox(height: Gap.md),
            ...GameMode.values.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: Gap.md),
                child: card(
                  icon: m.icon,
                  hue: c.hues.purple,
                  title: m.title,
                  blurb: m.blurb,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => QuickGameScreen(mode: m),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// THE QUICK GAMES
// ============================================================================

class QuickGameScreen extends ConsumerStatefulWidget {
  const QuickGameScreen({super.key, required this.mode});
  final GameMode mode;

  @override
  ConsumerState<QuickGameScreen> createState() => _QuickGameScreenState();
}

class _QuickGameScreenState extends ConsumerState<QuickGameScreen> {
  List<GameQuestion>? _qs;
  String _error = '';
  bool _needActivation = false;

  int _i = 0;
  int _score = 0;
  int _combo = 0;
  int _best = 0;
  int _left = 60;
  bool _over = false;
  int? _picked;
  Timer? _clock;

  bool get _timed => widget.mode == GameMode.blitz;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final api = ref.read(apiProvider);
    setState(() {
      _error = '';
      _needActivation = false;
      _qs = null;
    });
    try {
      final qs = await gamePool(
        api,
        count: widget.mode.count,
        daily: widget.mode.daily,
      );
      if (!mounted) return;
      setState(() {
        _qs = qs;
        _i = 0;
        _score = 0;
        _combo = 0;
        _best = 0;
        _left = 60;
        _over = qs.isEmpty;
        _picked = null;
      });
      if (_timed && qs.isNotEmpty) _startClock();
    } on ApiFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _needActivation = e.data?['needActivation'] == true;
      });
    }
  }

  void _startClock() {
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _left--);
      if (_left <= 0) {
        t.cancel();
        setState(() => _over = true);
      }
    });
  }

  void _pick(int index) {
    if (_picked != null || _over) return;
    final q = _qs![_i];
    final right = index == q.answerIndex;

    setState(() {
      _picked = index;
      if (right) {
        _combo++;
        _best = _combo > _best ? _combo : _best;
        // A combo is worth more than a lone right answer, which is what makes
        // Blitz a chain rather than forty separate questions.
        _score += _timed ? 10 + (_combo - 1) * 2 : 1;
      } else {
        _combo = 0;
      }
    });

    // Survival ends on the first wrong answer. Everything else moves on.
    Future<void>.delayed(const Duration(milliseconds: 850), () {
      if (!mounted) return;
      final last = _i >= _qs!.length - 1;
      final ends = (widget.mode == GameMode.survival && !right) || last;
      setState(() {
        if (ends) {
          _over = true;
          _clock?.cancel();
        } else {
          _i++;
          _picked = null;
        }
      });
    });
  }

  /// Road to 400 reports where the student reached on JAMB's own scale.
  int get _roadScore {
    final cleared = _score.clamp(0, _roadLadder.length);
    return cleared == 0 ? 0 : _roadLadder[cleared - 1];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lip;

    if (_error.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.mode.title)),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(Gap.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LipError(message: _error, onRetry: _load),
                  if (_needActivation) ...[
                    const SizedBox(height: Gap.lg),
                    LipButton(
                      gold: true,
                      icon: Icons.vpn_key_rounded,
                      label: 'Activate to play',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ActivationScreen(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_qs == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.mode.title)),
        body: const Padding(
          padding: EdgeInsets.all(Gap.lg),
          child: Column(
            children: [
              LipSkeleton(height: 60),
              SizedBox(height: Gap.md),
              LipSkeleton(height: 220),
            ],
          ),
        ),
      );
    }

    if (_qs!.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.mode.title)),
        body: LipEmpty(
          icon: widget.mode.icon,
          title: 'The arena is empty',
          message: widget.mode.daily
              ? "Today's plate needs at least ten live questions in the bank."
              : 'The bank has no live questions for this game yet.',
        ),
      );
    }

    if (_over) return _summary(c);

    final q = _qs![_i];
    return Scaffold(
      appBar: AppBar(title: Text(widget.mode.title)),
      body: SafeArea(
        child: Column(
          children: [
            _scoreboard(c),
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
                    q.question,
                    style: LipType.question.copyWith(
                      color: c.text1,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: Gap.lg),
                  ...List.generate(q.options.length, (i) {
                    final chosen = _picked == i;
                    final isRight = i == q.answerIndex;
                    final reveal = _picked != null;
                    final tone = !reveal
                        ? null
                        : isRight
                        ? c.success
                        : (chosen ? c.danger : null);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: Gap.sm),
                      child: GlassSurface(
                        tier: GlassTier.raised,
                        selected: chosen && !reveal,
                        padding: const EdgeInsets.all(Gap.md),
                        onTap: () => _pick(i),
                        child: Row(
                          children: [
                            Text(
                              '${q.letters.length > i ? q.letters[i] : String.fromCharCode(65 + i)}. ',
                              style: LipType.option.copyWith(
                                color: tone ?? c.text3,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                q.options[i],
                                style: LipType.option.copyWith(
                                  color: tone ?? c.text1,
                                ),
                              ),
                            ),
                            if (reveal && isRight)
                              Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: c.success,
                              ),
                            if (reveal && chosen && !isRight)
                              Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: c.danger,
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scoreboard(LipColors c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
    child: Row(
      children: [
        Expanded(
          child: LipStat(
            value: '${_i + 1}/${_qs!.length}',
            label: 'question',
            tone: ChipTone.neutral,
          ),
        ),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: LipStat(
            value: '$_score',
            label: widget.mode == GameMode.road ? 'rungs' : 'score',
            tone: ChipTone.brand,
          ),
        ),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: _timed
              ? LipStat(
                  value: '$_left',
                  label: 'seconds',
                  tone: _left <= 10 ? ChipTone.danger : ChipTone.warning,
                )
              : LipStat(
                  value: '$_combo',
                  label: 'streak',
                  tone: ChipTone.success,
                ),
        ),
      ],
    ),
  );

  Widget _summary(LipColors c) {
    final road = widget.mode == GameMode.road;
    return Scaffold(
      appBar: AppBar(title: Text(widget.mode.title)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Gap.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.mode.icon, size: 52, color: c.hues.purple.ink),
                const SizedBox(height: Gap.md),
                const LipLabel('Final'),
                Text(
                  road ? '$_roadScore' : '$_score',
                  style: LipType.hero.copyWith(color: c.text1),
                ),
                if (road)
                  Text(
                    'out of 400',
                    style: LipType.small.copyWith(color: c.text3),
                  ),
                const SizedBox(height: Gap.sm),
                Text(
                  'Best streak $_best',
                  style: LipType.body.copyWith(color: c.text2),
                ),
                const SizedBox(height: Gap.xl),
                LipButton(
                  label: widget.mode.daily
                      ? 'Play the plate again'
                      : 'Play again',
                  icon: Icons.refresh_rounded,
                  onPressed: _load,
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
