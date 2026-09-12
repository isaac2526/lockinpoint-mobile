import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../design/components.dart';
import '../../design/glass.dart';
import '../../design/motion_widgets.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import 'progress_repository.dart';

/// ===========================================================================
/// RESULT HISTORY
///
/// EVERY FLAW IN THE REFERENCE'S VERSION, ANSWERED.
///
/// Theirs collided the duration and the date into one another mid-line, ran
/// the per-subject scores together as a comma sentence the eye cannot search,
/// rendered 64% and 1.25% in identical weight and colour, and buried the mode
/// as the last text line.
///
/// Here a score is a coloured dial, the subjects are aligned bars sorted by
/// where marks are being lost, the mode is a badge, and the date and duration
/// sit on their own baselines where they cannot touch.
/// ===========================================================================
class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Result history')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(progressProvider.notifier).refresh(),
          child: progress.when(
            /* AN ERROR WHILE RELOADING IS STILL AN ERROR.
               An AsyncValue can be in error AND loading at the same time, and
               `when` looks at loading FIRST — so a screen that failed to load sat
               on a pulsing skeleton for ever while the real message ("No
               connection") waited in a state nothing ever drew. These two flags
               say: if we already know something, show it; a reload is not a reason
               to blank the screen or throw away a good answer. */
            skipLoadingOnReload: true,
            skipLoadingOnRefresh: true,
            loading: () => ListView(
              padding: const EdgeInsets.all(Gap.lg),
              children: const [
                LipSkeleton(height: 96),
                SizedBox(height: Gap.md),
                LipSkeleton(height: 130),
                SizedBox(height: Gap.md),
                LipSkeleton(height: 130),
              ],
            ),
            error: (e, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.sizeOf(context).height * 0.15),
                LipError(
                  message: e is ApiFailure
                      ? e.message
                      : 'Pull down to try again.',
                  onRetry: () => ref.read(progressProvider.notifier).refresh(),
                ),
              ],
            ),
            data: (p) {
              if (p.attempts.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
                    const LipEmpty(
                      icon: Icons.receipt_long_rounded,
                      title: 'No papers yet',
                      message:
                          'Finish a practice or CBT sitting and it will appear '
                          'here, with the marks broken down subject by subject.',
                    ),
                  ],
                );
              }

              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  Gap.lg,
                  Gap.lg,
                  Gap.lg,
                  Gap.huge,
                ),
                itemCount: p.attempts.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
                itemBuilder: (context, i) {
                  if (i == 0) return _Summary(p);
                  return Entrance(
                    index: i,
                    child: _AttemptCard(p.attempts[i - 1]),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A score's colour is its band. 64% and 1.25% must never look alike.
LipHue bandOf(LipColors c, double percent) => percent >= 70
    ? c.hues.green
    : percent >= 50
    ? c.hues.amber
    : c.hues.rose;

class _Summary extends StatelessWidget {
  const _Summary(this.p);
  final Progress p;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final stats = [
      ('Papers', '${p.sittings}', c.hues.blue),
      ('Questions', '${p.questions}', c.hues.indigo),
      ('Accuracy', '${p.accuracy.toStringAsFixed(0)}%', bandOf(c, p.accuracy)),
      (
        'Time',
        p.minutes >= 60 ? '${p.minutes ~/ 60}h' : '${p.minutes}m',
        c.hues.violet,
      ),
    ];

    return Column(
      children: [
        Row(
          children: [
            for (final (i, s) in stats.indexed) ...[
              if (i > 0) const SizedBox(width: Gap.sm),
              Expanded(
                child: GlassSurface(
                  hue: s.$3,
                  padding: const EdgeInsets.symmetric(
                    vertical: Gap.md,
                    horizontal: Gap.sm,
                  ),
                  child: Column(
                    children: [
                      Text(
                        s.$2,
                        style: LipType.monoBig.copyWith(
                          color: s.$3.ink,
                          fontSize: 21,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(s.$1, style: LipType.label.copyWith(color: c.text3)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        if (p.insight != null) ...[
          const SizedBox(height: Gap.md),
          _InsightCard(p.insight!),
        ],
      ],
    );
  }
}

/// The sentence a chart cannot say. Present only when the server judged the
/// data strong enough to support one.
class _InsightCard extends StatelessWidget {
  const _InsightCard(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    return GlassSurface(
      hue: c.hues.indigo,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_rounded, size: 20, color: c.hues.indigo.ink),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(text, style: LipType.body.copyWith(color: c.text1)),
          ),
        ],
      ),
    );
  }
}

class _AttemptCard extends StatelessWidget {
  const _AttemptCard(this.a);
  final Attempt a;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final band = bandOf(c, a.percent);
    final subjects = [...a.perSubject]
      ..sort((x, y) => x.percent.compareTo(y.percent));

    return GlassSurface(
      tier: GlassTier.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The dial. A number you can see the shape of.
              SizedBox(
                width: 58,
                height: 58,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(58, 58),
                      painter: _Dial(
                        value: a.percent / 100,
                        colour: band.ink,
                        track: c.glassBorder,
                      ),
                    ),
                    Text(
                      '${a.percent.round()}%',
                      style: LipType.smallStrong.copyWith(color: band.ink),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Gap.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: c.hues.slate.tint,
                            borderRadius: BorderRadius.circular(Radii.pill),
                          ),
                          child: Text(
                            a.modeLabel,
                            style: LipType.label.copyWith(
                              color: c.hues.slate.ink,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          a.isJamb && a.overall != null
                              ? '${a.overall}/400'
                              : '${a.correct}/${a.total}',
                          style: LipType.bodyStrong.copyWith(color: c.text1),
                        ),
                      ],
                    ),
                    const SizedBox(height: Gap.sm),
                    // Date and duration on their OWN lines. In the reference
                    // these two collided into "10 se2026/02/28".
                    Text(
                      _date(a.takenAt),
                      style: LipType.small.copyWith(color: c.text2),
                    ),
                    Text(
                      a.duration,
                      style: LipType.small.copyWith(color: c.text3),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (subjects.isNotEmpty) ...[
            const SizedBox(height: Gap.md),
            Divider(height: 1, color: c.glassBorder),
            const SizedBox(height: Gap.md),
            // Weakest first: the subject costing marks is the one to see.
            for (final s in subjects) ...[
              SubjectBar(subject: s),
              if (s != subjects.last) const SizedBox(height: Gap.sm),
            ],
          ],
        ],
      ),
    );
  }

  static String _date(DateTime t) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${t.day} ${months[t.month - 1]} ${t.year}';
  }
}

/// One subject's marks, as a bar the eye can compare down a column.
class SubjectBar extends StatelessWidget {
  const SubjectBar({super.key, required this.subject});
  final SubjectScore subject;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final band = bandOf(c, subject.percent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                subject.name,
                style: LipType.small.copyWith(color: c.text2),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${subject.correct}/${subject.total}',
              style: LipType.small.copyWith(color: c.text3),
            ),
            const SizedBox(width: Gap.sm),
            SizedBox(
              width: 44,
              child: Text(
                '${subject.percent.round()}%',
                textAlign: TextAlign.right,
                style: LipType.smallStrong.copyWith(color: band.ink),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.pill),
          child: LinearProgressIndicator(
            value: (subject.percent / 100).clamp(0, 1),
            minHeight: 6,
            backgroundColor: c.glassDeep,
            valueColor: AlwaysStoppedAnimation(band.ink),
          ),
        ),
      ],
    );
  }
}

class _Dial extends CustomPainter {
  const _Dial({required this.value, required this.colour, required this.track});
  final double value;
  final Color colour;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 3;
    canvas.drawCircle(
      centre,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = track,
    );
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: r),
      -1.5708,
      6.283185307179586 * value.clamp(0, 1),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = colour,
    );
  }

  @override
  bool shouldRepaint(_Dial old) => old.value != value || old.colour != colour;
}
