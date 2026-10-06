import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';

/// ===========================================================================
/// THE STUDY PLAN
///
/// Built from THIS student's weakest topics, not from a template. A plan that
/// says "Monday: Chemistry" for everyone is a printed timetable with extra
/// steps; this one changes as the weaknesses do.
///
/// The server refuses to build one before a few papers have been sat, and the
/// screen says so rather than showing an empty fortnight — a plan from no data
/// is a guess wearing a schedule's clothes.
/// ===========================================================================

class PlanItem {
  const PlanItem({
    required this.id,
    required this.dueOn,
    required this.label,
    required this.targetQuestions,
    required this.done,
    this.topicId,
  });

  final String id;
  final DateTime dueOn;
  final String label;
  final int targetQuestions;
  final bool done;
  final String? topicId;

  bool get isToday {
    final now = DateTime.now();
    return dueOn.year == now.year &&
        dueOn.month == now.month &&
        dueOn.day == now.day;
  }

  bool get isOverdue => !done && dueOn.isBefore(DateTime.now()) && !isToday;

  static PlanItem from(Map<String, dynamic> j) => PlanItem(
    id: j['id'] as String? ?? '',
    dueOn: DateTime.tryParse('${j['dueOn']}') ?? DateTime.now(),
    label: j['label'] as String? ?? '',
    targetQuestions: (j['targetQuestions'] as num?)?.toInt() ?? 20,
    done: j['done'] == true,
    topicId: j['topicId'] as String?,
  );
}

class StudyPlan {
  const StudyPlan({
    required this.exists,
    required this.minutesPerDay,
    required this.items,
  });

  final bool exists;
  final int minutesPerDay;
  final List<PlanItem> items;

  int get doneCount => items.where((i) => i.done).length;
  double get percent => items.isEmpty ? 0 : doneCount / items.length;

  static StudyPlan from(Map<String, dynamic> j) {
    final plan = j['plan'];
    return StudyPlan(
      exists: plan is Map,
      minutesPerDay: plan is Map
          ? ((plan['minutesPerDay'] as num?)?.toInt() ?? 30)
          : 30,
      items: ((j['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => PlanItem.from(m.cast<String, dynamic>()))
          .toList(),
    );
  }
}

final studyPlanProvider = FutureProvider<StudyPlan>((ref) async {
  return StudyPlan.from(await ref.read(apiProvider).get('/api/mobile/plan'));
});

/// Build (or rebuild) a plan. Takes the Api rather than a ref so it is
/// resolved before the await.
Future<String> buildPlan(Api api, {required int minutesPerDay}) async {
  final res = await api.post(
    '/api/mobile/plan',
    body: {'minutesPerDay': minutesPerDay},
  );
  return res['message'] as String? ?? 'Your plan is ready.';
}

Future<void> tickPlanItem(Api api, String itemId, {bool undo = false}) =>
    api.post(
      '/api/mobile/plan',
      body: {'op': 'done', 'itemId': itemId, 'undo': undo},
    );
