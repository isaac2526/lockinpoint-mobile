import '../../core/json.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../design/components.dart';
import '../../design/glass.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../practice/practice_repository.dart';
import 'plan_repository.dart';

/// The exams, for the planner's own picker. Shared with Practice — one
/// list of exams in the product, not two that can disagree.
final _planExamsProvider = FutureProvider<List<ExamOption>>(
  (ref) => ref.watch(practiceRepositoryProvider).exams(),
);

final _planSubjectsProvider =
    FutureProvider.family<List<SubjectOption>, String>(
      (ref, examSlug) =>
          ref.watch(practiceRepositoryProvider).subjects(examSlug),
    );

/// ===========================================================================
/// THE STUDY PLAN · fourteen days, built from this student's own weak topics.
///
/// The room the app never had. The backend has built these plans all along
/// and nothing has ever asked for one.
///
/// The screen shows TODAY first and the fortnight underneath, because a plan
/// a student has to scroll to act on is a plan they stop opening.
/// ===========================================================================
class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(studyPlanProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Study plan')),
      body: SafeArea(
        child: plan.when(
          /* AN ERROR WHILE RELOADING IS STILL AN ERROR.
             An AsyncValue can be in error AND loading at the same time, and
             `when` looks at loading FIRST — so a screen that failed to load sat
             on a pulsing skeleton for ever while the real message ("No
             connection") waited in a state nothing ever drew. These two flags
             say: if we already know something, show it; a reload is not a reason
             to blank the screen or throw away a good answer. */
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const Padding(
            padding: EdgeInsets.all(Gap.lg),
            child: LipSkeleton(height: 240),
          ),
          error: (e, _) => LipError(
            message: humanError(e, doing: 'load your study plan'),
            onRetry: () => ref.invalidate(studyPlanProvider),
          ),
          data: (p) => p == null ? const _NoPlanYet() : _Plan(plan: p),
        ),
      ),
    );
  }
}

class _NoPlanYet extends ConsumerStatefulWidget {
  const _NoPlanYet();

  @override
  ConsumerState<_NoPlanYet> createState() => _NoPlanYetState();
}

class _NoPlanYetState extends ConsumerState<_NoPlanYet> {
  DateTime? _date;
  int _minutes = 30;
  bool _busy = false;
  String _problem = '';

  /// The exam being offered, and the subjects inside it this student sits.
  /// Optional: a student with a history of attempts already tells the server
  /// what they sit, and the server prefers their weak topics to anything
  /// chosen here. This is what makes a plan possible on DAY ONE.
  String? _examSlug;
  final Set<String> _subjects = {};

  Future<void> _build() async {
    final when = _date;
    if (when == null) {
      setState(() => _problem = 'Pick the day you sit the exam.');
      return;
    }
    setState(() {
      _busy = true;
      _problem = '';
    });
    try {
      await buildPlan(
        ref,
        targetDate: when,
        minutesPerDay: _minutes,
        subjectIds: _subjects.toList(),
      );
    } on ApiFailure catch (e) {
      if (mounted) setState(() => _problem = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.huge),
      children: [
        Text(
          'Build your fortnight',
          style: LipType.title.copyWith(color: c.text1),
        ),
        const SizedBox(height: Gap.xs),
        Text(
          'Fourteen days, built from the topics that are actually costing you '
          'marks — not a timetable that says the same thing to everybody.',
          style: LipType.small.copyWith(color: c.text3),
        ),
        const SizedBox(height: Gap.lg),

        const LipLabel('When do you sit it?'),
        const SizedBox(height: Gap.sm),
        GlassSurface(
          tier: GlassTier.raised,
          padding: const EdgeInsets.all(Gap.md),
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              firstDate: now,
              lastDate: now.add(const Duration(days: 730)),
              initialDate: _date ?? now.add(const Duration(days: 60)),
            );
            if (picked != null) setState(() => _date = picked);
          },
          child: Row(
            children: [
              Icon(Icons.event_rounded, size: 20, color: c.hues.amber.ink),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Text(
                  _date == null
                      ? 'Choose the exam date'
                      : '${_date!.day}/${_date!.month}/${_date!.year}',
                  style: LipType.body.copyWith(color: c.text1),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: c.text3),
            ],
          ),
        ),

        const SizedBox(height: Gap.lg),
        const LipLabel('Which exam are you sitting?'),
        const SizedBox(height: Gap.sm),
        Consumer(
          builder: (context, ref, _) => ref
              .watch(_planExamsProvider)
              .when(
                skipLoadingOnReload: true,
                skipLoadingOnRefresh: true,
                loading: () => const LipSkeleton(height: 44),
                error: (e, _) => LipError(
                  message: humanError(e, doing: 'load the exams'),
                  onRetry: () => ref.invalidate(_planExamsProvider),
                ),
                data: (exams) => Wrap(
                  spacing: Gap.sm,
                  runSpacing: Gap.sm,
                  children: [
                    for (final x in exams)
                      LipChip(
                        x.shortName.isEmpty ? x.fullName : x.shortName,
                        selected: _examSlug == x.slug,
                        onTap: () => setState(() {
                          _examSlug = x.slug;
                          // The old exam's subjects are not this exam's.
                          _subjects.clear();
                        }),
                      ),
                  ],
                ),
              ),
        ),

        if (_examSlug != null) ...[
          const SizedBox(height: Gap.lg),
          const LipLabel('Which subjects?'),
          const SizedBox(height: Gap.sm),
          Consumer(
            builder: (context, ref, _) => ref
                .watch(_planSubjectsProvider(_examSlug!))
                .when(
                  skipLoadingOnReload: true,
                  skipLoadingOnRefresh: true,
                  loading: () => const LipSkeleton(height: 88),
                  error: (e, _) => LipError(
                    message: humanError(e, doing: 'load the subjects'),
                    onRetry: () =>
                        ref.invalidate(_planSubjectsProvider(_examSlug!)),
                  ),
                  data: (subjects) => Wrap(
                    spacing: Gap.sm,
                    runSpacing: Gap.sm,
                    children: [
                      for (final sub in subjects)
                        LipChip(
                          sub.name,
                          selected: _subjects.contains(sub.id),
                          onTap: () => setState(
                            () => _subjects.contains(sub.id)
                                ? _subjects.remove(sub.id)
                                : _subjects.add(sub.id),
                          ),
                        ),
                    ],
                  ),
                ),
          ),
          const SizedBox(height: Gap.xs),
          Text(
            'Tick the ones you actually offer. Once you have sat a few '
            'papers the plan is rebuilt from your own weak topics instead.',
            style: LipType.caption.copyWith(color: c.text3),
          ),
        ],

        const SizedBox(height: Gap.lg),
        const LipLabel('How long a day, honestly?'),
        const SizedBox(height: Gap.sm),
        /* UP TO FIFTEEN HOURS. This stopped at two, which is not the day of
           anybody in the last fortnight before an exam — the person most
           likely to be sitting here. A holiday candidate reading all day
           could not describe their day to the planner at all. */
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            for (final m in const [
              15,
              30,
              45,
              60,
              90,
              120,
              180,
              240,
              300,
              360,
              480,
              600,
              720,
              900,
            ])
              LipChip(
                m < 60
                    ? '$m min'
                    : '${m ~/ 60}h${m % 60 == 0 ? '' : ' ${m % 60}m'}',
                selected: _minutes == m,
                onTap: () => setState(() => _minutes = m),
              ),
          ],
        ),
        const SizedBox(height: Gap.xs),
        Text(
          _minutes >= 480
              ? 'A long day. Break it up — and if you miss one, rebuild '
                    'rather than trying to catch up.'
              : 'Be honest. A plan built on hours you do not have is a plan '
                    'you abandon on day three.',
          style: LipType.caption.copyWith(color: c.text3),
        ),

        if (_problem.isNotEmpty) ...[
          const SizedBox(height: Gap.lg),
          LipFormError(message: _problem),
        ],
        const SizedBox(height: Gap.lg),
        LipButton(
          label: _busy ? 'Building…' : 'Build my plan',
          onPressed: _busy ? null : _build,
        ),
      ],
    );
  }
}

class _Plan extends ConsumerWidget {
  const _Plan({required this.plan});
  final StudyPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;
    final left = plan.daysLeft;
    final due = plan.todayAndOverdue;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(studyPlanProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.huge),
        children: [
          GlassSurface(
            hue: c.hues.amber,
            padding: const EdgeInsets.all(Gap.lg),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        left == null
                            ? 'Your plan'
                            : left < 0
                            ? 'That exam has passed'
                            : left == 0
                            ? 'The exam is today'
                            : '$left day${left == 1 ? '' : 's'} to go',
                        style: LipType.title.copyWith(color: c.text1),
                      ),
                      Text(
                        '${plan.minutesPerDay} minutes a day · '
                        '${plan.done} of ${plan.items.length} done',
                        style: LipType.small.copyWith(color: c.text3),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Rebuild from my weakest topics now',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Rebuild plan')),
                        body: const SafeArea(child: _NoPlanYet()),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.lg),

          if (due.isNotEmpty) ...[
            const LipLabel('Do this now'),
            const SizedBox(height: Gap.sm),
            for (final i in due) _Item(item: i, urgent: true),
            const SizedBox(height: Gap.lg),
          ],

          const LipLabel('The fortnight'),
          const SizedBox(height: Gap.sm),
          for (final i in plan.items) _Item(item: i, urgent: false),
        ],
      ),
    );
  }
}

class _Item extends ConsumerWidget {
  const _Item({required this.item, required this.urgent});
  final PlanItem item;
  final bool urgent;

  static const _months = [
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;
    final d = item.dueOn;
    final when = d == null ? '' : '${d.day} ${_months[d.month - 1]}';

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: GlassSurface(
        tier: GlassTier.raised,
        padding: const EdgeInsets.all(Gap.md),
        child: Row(
          children: [
            Checkbox(
              value: item.done,
              onChanged: (v) => markPlanItem(ref, item.id, done: v ?? false),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label.isEmpty ? 'Practice' : item.label,
                    style: LipType.body.copyWith(
                      color: item.done ? c.text3 : c.text1,
                      decoration: item.done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  Text(
                    '$when · ${item.targetQuestions} questions',
                    style: LipType.caption.copyWith(
                      color: urgent && !item.done ? c.hues.orange.ink : c.text3,
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
