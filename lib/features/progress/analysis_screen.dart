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
import 'results_screen.dart';

/// ===========================================================================
/// PERFORMANCE ANALYSIS
///
/// EVERY FLAW IN THE REFERENCE'S CHARTS, ANSWERED.
///
/// Theirs were server-rendered images: the legend sat ON TOP of the data, the
/// y-axis ran NEGATIVE for a score that cannot be negative, and the x-axis
/// was labelled "Practice Number", which no student thinks in.
///
/// Here the axis starts at zero because a percentage cannot go below it, the
/// x-axis is time, the legend is a row of chips ABOVE the plot that filter
/// the series, and under every chart is a sentence in plain English. A chart
/// tells you a number; the sentence tells you what to do about it.
/// ===========================================================================
class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  /// Which subjects are drawn. Empty means all of them.
  final _hidden = <String>{};

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(progressProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Performance analysis')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(progressProvider.notifier).refresh(),
          child: progress.when(
            loading: () => ListView(
              padding: const EdgeInsets.all(Gap.lg),
              children: const [
                LipSkeleton(height: 200),
                SizedBox(height: Gap.md),
                LipSkeleton(height: 200),
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
            data: (p) => _body(p),
          ),
        ),
      ),
    );
  }

  Widget _body(Progress p) {
    final c = context.lip;

    if (p.attempts.length < 2) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
          const LipEmpty(
            icon: Icons.insights_rounded,
            title: 'Not enough papers yet',
            message:
                'Analysis needs at least two finished sittings before it can '
                'show a trend worth reading. Sit another and come back.',
          ),
        ],
      );
    }

    // Oldest first: a trend reads left to right.
    final series = [...p.attempts.reversed];
    final shown = p.subjects.where((s) => !_hidden.contains(s.name)).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.huge),
      children: [
        if (p.insight != null) ...[
          Entrance(child: _Insight(p.insight!)),
          const SizedBox(height: Gap.lg),
        ],

        const LipLabel('Score over time'),
        const SizedBox(height: Gap.sm),
        Entrance(
          index: 1,
          child: GlassSurface(
            tier: GlassTier.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 170,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _TrendPainter(
                      values: series.map((a) => a.percent).toList(),
                      line: c.hues.blue.ink,
                      fill: c.hues.blue.tint,
                      grid: c.glassBorder,
                      label: c.text3,
                    ),
                  ),
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  '${series.length} papers, oldest on the left. '
                  'The scale runs 0 to 100 — a percentage cannot go below zero, '
                  'so the axis does not either.',
                  style: LipType.caption.copyWith(color: c.text3),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: Gap.lg),
        const LipLabel('Where your marks are going'),
        const SizedBox(height: Gap.sm),

        // The legend is a row of FILTER CHIPS above the data, never printed
        // over it. Tapping one takes that subject out of the picture.
        if (p.subjects.length > 1)
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final s in p.subjects)
                FilterChip(
                  label: Text(s.name),
                  selected: !_hidden.contains(s.name),
                  onSelected: (on) => setState(() {
                    if (on) {
                      _hidden.remove(s.name);
                    } else {
                      _hidden.add(s.name);
                    }
                  }),
                ),
            ],
          ),
        const SizedBox(height: Gap.md),

        Entrance(
          index: 2,
          child: GlassSurface(
            tier: GlassTier.card,
            child: shown.isEmpty
                ? Text(
                    'Every subject is hidden. Tap a chip above to bring one back.',
                    style: LipType.small.copyWith(color: c.text3),
                  )
                : Column(
                    children: [
                      for (final s in shown) ...[
                        SubjectBar(subject: s),
                        if (s != shown.last) const SizedBox(height: Gap.md),
                      ],
                    ],
                  ),
          ),
        ),

        const SizedBox(height: Gap.md),
        Text(
          'Sorted weakest first. The subject at the top is the one costing you '
          'the most marks, which makes it the one worth an extra hour.',
          style: LipType.caption.copyWith(color: c.text3),
        ),
      ],
    );
  }
}

class _Insight extends StatelessWidget {
  const _Insight(this.text);
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

/// A percentage trend with a zero-based axis and no legend on the data.
class _TrendPainter extends CustomPainter {
  const _TrendPainter({
    required this.values,
    required this.line,
    required this.fill,
    required this.grid,
    required this.label,
  });

  final List<double> values;
  final Color line, fill, grid, label;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    const left = 34.0;
    const bottom = 18.0;
    final plot = Rect.fromLTRB(left, 6, size.width, size.height - bottom);

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;

    // 0, 25, 50, 75, 100 — a fixed, honest scale.
    for (final v in [0, 25, 50, 75, 100]) {
      final y = plot.bottom - (v / 100) * plot.height;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(
          text: '$v',
          style: TextStyle(color: label, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(plot.left - tp.width - 6, y - tp.height / 2));
    }

    final dx = values.length == 1 ? 0.0 : plot.width / (values.length - 1);
    Offset at(int i) => Offset(
      plot.left + dx * i,
      plot.bottom - (values[i].clamp(0, 100) / 100) * plot.height,
    );

    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }

    final area = Path.from(path)
      ..lineTo(at(values.length - 1).dx, plot.bottom)
      ..lineTo(plot.left, plot.bottom)
      ..close();
    canvas.drawPath(area, Paint()..color = fill);

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = line,
    );

    // A dot per paper, so a student can count their own sittings.
    for (var i = 0; i < values.length; i++) {
      canvas.drawCircle(at(i), 3.2, Paint()..color = line);
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) => old.values != values;
}
