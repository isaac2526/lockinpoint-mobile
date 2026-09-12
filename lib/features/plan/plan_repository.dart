import '../../core/json.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';

/// ===========================================================================
/// THE STUDY PLAN
///
/// /api/mobile/plan has existed all along and nothing has ever called it. It
/// is not a template: the backend builds fourteen days out of THIS student's
/// weakest topics, so two students with the same exam date get different
/// plans and a student who fixes a topic stops being sent back to it.
///
/// It is REGENERATED rather than edited — a plan is a suggestion about the
/// next fortnight, not a document to maintain.
/// ===========================================================================

class PlanItem {
  const PlanItem({
    required this.id,
    required this.dueOn,
    required this.label,
    required this.kind,
    required this.targetQuestions,
    required this.done,
  });

  factory PlanItem.from(Map<dynamic, dynamic> m) => PlanItem(
    id: asText(m['id']),
    dueOn: DateTime.tryParse('${m['dueOn'] ?? m['due_on'] ?? ''}'),
    label: asText(m['label']),
    kind: asText(m['kind'], 'practice'),
    targetQuestions:
        (m['targetQuestions'] ?? m['target_questions'] ?? 0) as int? ?? 0,
    done: (m['doneAt'] ?? m['done_at']) != null,
  );

  final String id;
  final DateTime? dueOn;
  final String label;
  final String kind;
  final int targetQuestions;
  final bool done;

  bool get isToday {
    final d = dueOn;
    if (d == null) return false;
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool get isPast {
    final d = dueOn;
    if (d == null) return false;
    final today = DateTime.now();
    return d.isBefore(DateTime(today.year, today.month, today.day));
  }
}

class StudyPlan {
  const StudyPlan({
    required this.id,
    required this.targetDate,
    required this.minutesPerDay,
    required this.items,
  });

  final String id;
  final DateTime? targetDate;
  final int minutesPerDay;
  final List<PlanItem> items;

  int get done => items.where((i) => i.done).length;

  /// Whole days between now and the exam. Negative once it has passed, which
  /// the screen says out loud rather than showing "-3 days to go".
  int? get daysLeft {
    final t = targetDate;
    if (t == null) return null;
    final now = DateTime.now();
    return DateTime(
      t.year,
      t.month,
      t.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  /// Everything due today or overdue and not yet done — the only part of a
  /// fourteen-day plan a student can act on right now.
  List<PlanItem> get todayAndOverdue =>
      items.where((i) => !i.done && (i.isToday || i.isPast)).toList();
}

final studyPlanProvider = FutureProvider<StudyPlan?>((ref) async {
  final res = await ref.read(apiProvider).get('/api/mobile/plan');
  final p = res['plan'];
  if (p is! Map) return null;
  return StudyPlan(
    id: asText(p['id']),
    targetDate: DateTime.tryParse(
      '${p['targetDate'] ?? p['target_date'] ?? ''}',
    ),
    minutesPerDay:
        (p['minutesPerDay'] ?? p['minutes_per_day'] ?? 30) as int? ?? 30,
    items: ((res['items'] as List?) ?? const [])
        .whereType<Map>()
        .map(PlanItem.from)
        .toList(),
  );
});

/// Builds or rebuilds the plan, then makes the next read fetch it fresh.
///
/// Takes a [WidgetRef] rather than a [Ref]: every caller is a screen, and a
/// screen holds the widget flavour. Riverpod's two Ref types are not
/// interchangeable, and threading the provider container through instead
/// would buy nothing.
Future<void> buildPlan(
  WidgetRef ref, {
  required DateTime targetDate,
  required int minutesPerDay,
}) async {
  await ref
      .read(apiProvider)
      .post(
        '/api/mobile/plan',
        body: {
          'targetDate': targetDate.toIso8601String().substring(0, 10),
          'minutesPerDay': minutesPerDay,
        },
      );
  ref.invalidate(studyPlanProvider);
}

/// The body that ticks one day off — pulled out so it can be tested without
/// a widget tree, because getting it wrong is silent and expensive.
///
/// `op` decides which of the route's TWO jobs runs. Left off, the request
/// does not fail: it REBUILDS the whole fortnight, and a student who meant to
/// tick one box watches their plan change underneath them.
Map<String, Object> planTickBody(String itemId, {required bool done}) => {
  'op': 'done',
  'itemId': itemId,
  if (!done) 'undo': true,
};

/// Marks one day's task done. The plan is a promise a student keeps to
/// themselves; ticking it off has to be one tap and has to stick.
Future<void> markPlanItem(
  WidgetRef ref,
  String itemId, {
  required bool done,
}) async {
  await ref
      .read(apiProvider)
      .post('/api/mobile/plan', body: planTickBody(itemId, done: done));
  ref.invalidate(studyPlanProvider);
}
