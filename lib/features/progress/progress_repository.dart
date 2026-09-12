import '../../core/json.dart';

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
    id: asText(j['id']),
    mode: asText(j['mode'], 'practice'),
    takenAt: DateTime.tryParse(asText(j['takenAt'])) ?? DateTime.now(),
    durationSeconds: asInt(j['durationSeconds']),
    correct: asInt(j['correct']),
    total: asInt(j['total']),
    percent: asDouble(j['percent'], 0),
    overall: asIntOrNull(j['overall']),
    isJamb: j['isJamb'] == true,
    perSubject: (asList(j['perSubject']))
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
    name: asText(j['name']),
    correct: asInt(j['correct']),
    total: asInt(j['total']),
    percent: asDouble(j['percent'], 0),
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
    final s = asMap(j['summary']);
    return Progress(
      sittings: asInt(s['sittings']),
      questions: asInt(s['questions']),
      correct: asInt(s['correct']),
      accuracy: asDouble(s['accuracy'], 0),
      minutes: asInt(s['minutes']),
      attempts: (asList(j['attempts']))
          .whereType<Map>()
          .map((m) => Attempt.from(m.cast<String, dynamic>()))
          .toList(),
      subjects: (asList(j['subjects']))
          .whereType<Map>()
          .map((m) => SubjectScore.from(m.cast<String, dynamic>()))
          .toList(),
      insight: asTextOrNull(j['insight']),
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
