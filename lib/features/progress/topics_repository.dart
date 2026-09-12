import '../../core/json.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';

/// ===========================================================================
/// PER-TOPIC STRENGTH · which topic is actually costing the marks.
///
/// Subject accuracy says a student's Chemistry is at 61%. It does not say
/// that their Mole Concept is at 22% and everything else is fine, and that is
/// the difference between a chart and advice.
///
/// /api/mobile/topics has served this all along and nothing has called it.
/// The guardian portal reads the same function, so a parent and their child
/// can never be shown different numbers for the same papers.
///
/// THE HONESTY RULE travels with the data: a topic seen fewer than [minSeen]
/// times is reported separately as UNPROVEN rather than drawn as a confident
/// red bar. A student who abandons a topic they were fine at, because the app
/// told them to off two questions, has been actively harmed.
///
/// This is also the seam the platform needs for topic-by-topic practice. Only
/// year-by-year exists today, so `topicId` is carried through unused rather
/// than dropped — the day the bank starts filing questions by topic, the
/// rows here already name them.
/// ===========================================================================

class TopicRow {
  const TopicRow({
    required this.topicId,
    required this.topic,
    required this.subject,
    required this.seen,
    required this.correct,
    required this.percent,
  });

  factory TopicRow.from(Map<dynamic, dynamic> m) => TopicRow(
    topicId: asText(m['topicId']),
    topic: asText(m['topic']),
    subject: asText(m['subject']),
    seen: (asIntOrNull(m['seen'])) ?? 0,
    correct: (asIntOrNull(m['correct'])) ?? 0,
    percent: (asDouble(m['percent'])).toDouble(),
  );

  final String topicId;
  final String topic;
  final String subject;
  final int seen;
  final int correct;
  final double percent;
}

class TopicStrength {
  const TopicStrength({
    required this.minSeen,
    required this.rows,
    required this.weakest,
    required this.strongest,
    required this.unproven,
  });

  final int minSeen;
  final List<TopicRow> rows;
  final List<TopicRow> weakest;
  final List<TopicRow> strongest;

  /// Topics met, but not often enough to judge. Named rather than hidden, so
  /// the screen can say "practise these to find out".
  final List<({String topic, int seen})> unproven;

  bool get isEmpty => rows.isEmpty && unproven.isEmpty;
}

final topicStrengthProvider = FutureProvider<TopicStrength>((ref) async {
  final res = await ref.read(apiProvider).get('/api/mobile/topics');
  List<TopicRow> list(Object? raw) =>
      (asList(raw)).whereType<Map>().map(TopicRow.from).toList();
  return TopicStrength(
    minSeen: (asIntOrNull(res['minSeen'])) ?? 6,
    rows: list(res['rows']),
    weakest: list(res['weakest']),
    strongest: list(res['strongest']),
    unproven: (asList(res['unproven']))
        .whereType<Map>()
        .map(
          (m) =>
              (topic: asText(m['topic']), seen: (asIntOrNull(m['seen'])) ?? 0),
        )
        .toList(),
  );
});
