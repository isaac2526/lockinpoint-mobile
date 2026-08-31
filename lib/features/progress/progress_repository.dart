import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';

/// One paper a student has sat.
class Attempt {
  const Attempt({
    required this.id,
    required this.mode,
    required this.takenAt,
    required this.durationSeconds,
    required this.correct,
    required this.total,
    required this.percent,
    required this.overall,
    required this.isJamb,
    required this.perSubject,
  });

  final String id;
  final String mode;
  final DateTime takenAt;
  final int durationSeconds;
  final int correct;
  final int total;
  final double percent;
  final int? overall;
  final bool isJamb;
  final List<SubjectScore> perSubject;

  static Attempt from(Map<String, dynamic> j) => Attempt(
    id: j['id'] as String? ?? '',
    mode: j['mode'] as String? ?? 'practice',
    takenAt: DateTime.tryParse(j['takenAt'] as String? ?? '') ?? DateTime.now(),
    durationSeconds: (j['durationSeconds'] as num?)?.toInt() ?? 0,
    correct: (j['correct'] as num?)?.toInt() ?? 0,
    total: (j['total'] as num?)?.toInt() ?? 0,
    percent: (j['percent'] as num?)?.toDouble() ?? 0,
    overall: (j['overall'] as num?)?.toInt(),
    isJamb: j['isJamb'] == true,
    perSubject: ((j['perSubject'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => SubjectScore.from(m.cast<String, dynamic>()))
        .toList(),
  );

  /// What a student calls this sitting. The four modes the engine actually
  /// runs, named the way the website names them.
  String get modeLabel => switch (mode) {
    'cbt' => 'CBT',
    'jamb_mock' => 'JAMB mock',
    'jamb_mini' => 'JAMB mini',
    _ => 'Practice',
  };

  /// "1 hr 34 min". Never "94 min", which nobody says out loud.
  String get duration {
    if (durationSeconds <= 0) return '—';
    final m = durationSeconds ~/ 60;
    if (m < 60) return '$m min';
    return '${m ~/ 60} hr ${m % 60} min';
  }
}

class SubjectScore {
  const SubjectScore({
    required this.name,
    required this.correct,
    required this.total,
    required this.percent,
  });

  final String name;
  final int correct;
  final int total;
  final double percent;

  static SubjectScore from(Map<String, dynamic> j) => SubjectScore(
    name: j['name'] as String? ?? '',
    correct: (j['correct'] as num?)?.toInt() ?? 0,
    total: (j['total'] as num?)?.toInt() ?? 0,
    percent: (j['percent'] as num?)?.toDouble() ?? 0,
  );
}

class Progress {
  const Progress({
    required this.sittings,
    required this.questions,
    required this.correct,
    required this.accuracy,
    required this.minutes,
    required this.attempts,
    required this.subjects,
    required this.insight,
  });

  final int sittings;
  final int questions;
  final int correct;
  final double accuracy;
  final int minutes;
  final List<Attempt> attempts;
  final List<SubjectScore> subjects;

  /// The plain-English line under the charts. Null when the data cannot
  /// honestly support one — the server refuses to invent it.
  final String? insight;

  static Progress from(Map<String, dynamic> j) {
    final s = (j['summary'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Progress(
      sittings: (s['sittings'] as num?)?.toInt() ?? 0,
      questions: (s['questions'] as num?)?.toInt() ?? 0,
      correct: (s['correct'] as num?)?.toInt() ?? 0,
      accuracy: (s['accuracy'] as num?)?.toDouble() ?? 0,
      minutes: (s['minutes'] as num?)?.toInt() ?? 0,
      attempts: ((j['attempts'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => Attempt.from(m.cast<String, dynamic>()))
          .toList(),
      subjects: ((j['subjects'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => SubjectScore.from(m.cast<String, dynamic>()))
          .toList(),
      insight: j['insight'] as String?,
    );
  }
}

/// Result history and analysis are the SAME request. They are two views of
/// one answer, so asking twice would be two round trips for one truth.
class ProgressController extends AsyncNotifier<Progress> {
  @override
  Future<Progress> build() async =>
      Progress.from(await ref.read(apiProvider).get('/api/mobile/results'));

  Future<void> refresh() async {
    try {
      state = AsyncData(
        Progress.from(await ref.read(apiProvider).get('/api/mobile/results')),
      );
    } on ApiFailure catch (e, st) {
      if (!state.hasValue) state = AsyncError(e, st);
    }
  }
}

final progressProvider = AsyncNotifierProvider<ProgressController, Progress>(
  ProgressController.new,
);

/// ===========================================================================
/// PER-TOPIC STRENGTH
///
/// "Your Chemistry is 61%" is a chart. "Your Mole Concept is 22% and the rest
/// is fine" is advice, and it is the only version a student can act on
/// tonight.
///
/// THE HONESTY RULE IS THE SERVER'S, and this only renders it: a topic seen
/// fewer than `minSeen` times is not reported at all. A confident red bar off
/// two data points can send a student away from a topic they were fine at,
/// which is worse than saying nothing.
/// ===========================================================================
class TopicScore {
  const TopicScore({
    required this.topic,
    required this.subject,
    required this.seen,
    required this.correct,
    required this.percent,
  });

  final String topic;
  final String subject;
  final int seen;
  final int correct;
  final double percent;

  static TopicScore from(Map<String, dynamic> j) => TopicScore(
    topic: j['topic'] as String? ?? '',
    subject: j['subject'] as String? ?? '',
    seen: (j['seen'] as num?)?.toInt() ?? 0,
    correct: (j['correct'] as num?)?.toInt() ?? 0,
    percent: (j['percent'] as num?)?.toDouble() ?? 0,
  );
}

class TopicStrength {
  const TopicStrength({
    required this.weakest,
    required this.strongest,
    required this.rows,
    required this.unproven,
    required this.minSeen,
  });

  final List<TopicScore> weakest;
  final List<TopicScore> strongest;
  final List<TopicScore> rows;

  /// Topics met but not enough times to judge. Named rather than hidden, so
  /// the screen can say "practise these to find out".
  final List<({String topic, int seen})> unproven;
  final int minSeen;

  bool get hasAnything => rows.isNotEmpty || unproven.isNotEmpty;

  static List<TopicScore> _list(Object? raw) => ((raw as List?) ?? const [])
      .whereType<Map>()
      .map((m) => TopicScore.from(m.cast<String, dynamic>()))
      .toList();

  static TopicStrength from(Map<String, dynamic> j) => TopicStrength(
    weakest: _list(j['weakest']),
    strongest: _list(j['strongest']),
    rows: _list(j['rows']),
    unproven: ((j['unproven'] as List?) ?? const [])
        .whereType<Map>()
        .map(
          (m) => (
            topic: m['topic'] as String? ?? '',
            seen: (m['seen'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList(),
    minSeen: (j['minSeen'] as num?)?.toInt() ?? 6,
  );
}

final topicStrengthProvider = FutureProvider<TopicStrength>((ref) async {
  return TopicStrength.from(
    await ref.read(apiProvider).get('/api/mobile/topics'),
  );
});
