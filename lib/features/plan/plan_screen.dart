import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../design/components.dart';
import '../../design/glass.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import 'plan_repository.dart';

/// ===========================================================================
/// THE STUDY PLAN
///
/// Fourteen days, built from the student's own weakest topics. Amber, the
/// palette's time hue, because this screen is about when rather than what.
///
/// Today is pinned at the top and named. A plan a student has to scroll to
/// find their day in is a plan they stop opening.
/// ===========================================================================
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  int _minutes = 30;
  bool _busy = false;
  String _message = '';

  Future<void> _build() async {
    final api = ref.read(apiProvider);
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      final m = await buildPlan(api, minutesPerDay: _minutes);
      if (!mounted) return;
      setState(() => _message = m);
      ref.invalidate(studyPlanProvider);
    } on ApiFailure catch (e) {
      if (!mounted) return;
      setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _tick(PlanItem item) async {
    final api = ref.read(apiProvider);
    try {
      await tickPlanItem(api, item.id, undo: item.done);
      ref.invalidate(studyPlanProvider);
    } on ApiFailure catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final plan = ref.watch(studyPlanProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Study plan')),
      body: SafeArea(
        child: plan.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(Gap.lg),
            child: LipSkeleton(height: 260),
          ),
          error: (e, _) => LipError(
            message: '$e',
            onRetry: () => ref.invalidate(studyPlanProvider),
          ),
          data: (p) => ListView(
            padding: const EdgeInsets.fromLTRB(
              Gap.lg,
              Gap.lg,
              Gap.lg,
              Gap.huge,
            ),
            children: [
              if (!p.exists) ...[
                GlassSurface(
                  hue: c.hues.amber,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'A plan built from your own papers',
                        style: LipType.subheading.copyWith(color: c.text1),
                      ),
                      const SizedBox(height: Gap.xs),
                      Text(
                        'Fourteen days, aimed at the topics you are actually '
                        'losing marks on. It is not a template — two students '
                        'sitting the same exam get different plans.',
                        style: LipType.small.copyWith(
                          color: c.text2,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Gap.lg),
              ] else ...[
                GlassSurface(
                  hue: c.hues.amber,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${p.doneCount} of ${p.items.length} days done',
                              style: LipType.subheading.copyWith(
                                color: c.text1,
                              ),
                            ),
                          ),
                          Text(
                            '${(p.percent * 100).round()}%',
                            style: LipType.heading.copyWith(color: c.brand),
                          ),
                        ],
                      ),
                      const SizedBox(height: Gap.sm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(Radii.pill),
                        child: LinearProgressIndicator(
                          value: p.percent,
                          minHeight: 8,
                          backgroundColor: c.glassDeep,
                          valueColor: AlwaysStoppedAnimation(c.brand),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Gap.lg),
                ...p.items.map((i) => _Row(item: i, onTap: () => _tick(i))),
                const SizedBox(height: Gap.lg),
              ],

              const LipLabel('Minutes a day you can give it'),
              const SizedBox(height: Gap.sm),
              Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                children: [
                  for (final m in const [15, 30, 45, 60, 90])
                    LipChip(
                      '$m min',
                      selected: _minutes == m,
                      onTap: () => setState(() => _minutes = m),
                    ),
                ],
              ),
              const SizedBox(height: Gap.md),
              LipButton(
                gold: true,
                icon: Icons.event_note_rounded,
                label: p.exists ? 'Rebuild my plan' : 'Build my plan',
                busy: _busy,
                onPressed: _build,
              ),
              if (p.exists) ...[
                const SizedBox(height: Gap.xs),
                Text(
                  'Rebuilding replaces this plan with a fresh one from your '
                  'latest results. Days already ticked off are not kept — the '
                  'point is what to do next, not a record of what you did.',
                  style: LipType.caption.copyWith(color: c.text3),
                ),
              ],
              if (_message.isNotEmpty) ...[
                const SizedBox(height: Gap.md),
                GlassSurface(
                  tier: GlassTier.deep,
                  padding: const EdgeInsets.all(Gap.md),
                  child: Text(
                    _message,
                    style: LipType.small.copyWith(color: c.text2),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.onTap});
  final PlanItem item;
  final VoidCallback onTap;

  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    // Today is named rather than dated. "Today" is the word a student is
    // looking for; "31 Aug" makes them do arithmetic.
    final when = item.isToday
        ? 'Today'
        : '${_days[item.dueOn.weekday - 1]} ${item.dueOn.day}';

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: GlassSurface(
        tier: item.isToday ? GlassTier.raised : GlassTier.card,
        selected: item.isToday && !item.done,
        padding: const EdgeInsets.all(Gap.md),
        onTap: onTap,
        child: Row(
          children: [
            Icon(
              item.done ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 22,
              color: item.done
                  ? c.success
                  : item.isOverdue
                  ? c.warning
                  : c.text3,
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: LipType.body.copyWith(
                      color: item.done ? c.text3 : c.text1,
                      decoration: item.done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  Text(
                    '$when · ${item.targetQuestions} questions'
                    '${item.isOverdue ? " · missed" : ""}',
                    style: LipType.caption.copyWith(
                      color: item.isOverdue ? c.warning : c.text3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
