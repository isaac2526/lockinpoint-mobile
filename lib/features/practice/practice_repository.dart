import '../../core/json.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';

/// ===========================================================================
/// THE PRACTICE CONTRACT, TYPED
///
/// Every shape here mirrors a response the website's own screens already
/// consume, from the same routes — /api/public/exam-tree for the chooser and
/// /api/attempts for the sitting itself. Nothing is invented on the phone:
/// if the two products ever disagree about what is available, one of them is
/// reading a different backend.
/// ===========================================================================

class ExamOption {
  const ExamOption({
    required this.id,
    required this.slug,
    required this.shortName,
    required this.fullName,
  });

  final String id;
  final String slug;
  final String shortName;
  final String fullName;

  static ExamOption fromJson(Map<String, dynamic> j) => ExamOption(
    id: j['id'] as String,
    slug: asText(j['slug']),
    shortName: asText(j['short_name']),
    fullName: asText(j['full_name']),
  );
}

class SubjectOption {
  const SubjectOption({
    required this.id,
    required this.name,
    required this.compulsory,
  });

  final String id;
  final String name;
  final bool compulsory;

  static SubjectOption fromJson(Map<String, dynamic> j) => SubjectOption(
    id: j['id'] as String,
    name: asText(j['name']),
    compulsory: j['compulsory'] == true,
  );
}

class YearCount {
  const YearCount(this.year, this.n);
  final int year;
  final int n;
}

class TopicCount {
  const TopicCount(this.id, this.name, this.n, this.nTutorial);
  final String id;
  final String name;
  final int n;
  final int nTutorial;
}

/// Everything the year/topic/random step needs for one subject.
class ChooserData {
  const ChooserData({
    required this.subjectName,
    required this.examSlug,
    required this.examShort,
    required this.years,
    required this.topics,
    required this.past,
    required this.tutorial,
  });

  final String subjectName;
  final String examSlug;
  final String examShort;
  final List<YearCount> years;
  final List<TopicCount> topics;
  final int past;
  final int tutorial;
}

/// One question as the server serves it. In practice mode the answer and
/// explanation ride along so the phone can mark instantly; in every other
/// mode (and on resume) they are deliberately absent and marking happens
/// server side at submit.
class ServedQuestion {
  const ServedQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.letters,
    this.passageId,
    this.section,
    this.year,
    this.answer,
    this.explanation,
    this.media,
  });

  final String id;
  final String question;
  final List<String> options;
  final List<String> letters;
  final String? passageId;
  final String? section;
  final int? year;
  final String? answer;
  final String? explanation;
  final Map<String, dynamic>? media;

  String? mediaUrl(String slot) {
    final m = media?[slot];
    if (m is Map && m['type'] == 'image' && m['url'] is String) {
      return m['url'] as String;
    }
    return null;
  }

  static ServedQuestion fromJson(Map<String, dynamic> j) => ServedQuestion(
    id: j['id'] as String,
    question: asText(j['question']),
    options: ((j['options'] as List?) ?? const []).cast<String>(),
    letters: ((j['letters'] as List?) ?? const []).cast<String>(),
    passageId: asTextOrNull(j['passage_id']),
    section: asTextOrNull(j['section']),
    year: asIntOrNull(j['year']),
    answer: (asTextOrNull(j['answer']))?.toUpperCase(),
    explanation: asTextOrNull(j['explanation']),
    media: j['media'] as Map<String, dynamic>?,
  );
}

class Passage {
  const Passage({required this.title, required this.body});
  final String title;
  final String body;
}

/// A live sitting, fresh or resumed.
class Sitting {
  const Sitting({
    required this.attemptId,
    required this.mode,
    required this.label,
    required this.questions,
    required this.passages,
    this.duration = 0,
    this.initialIndex = 0,
    this.initialAnswers = const {},
    this.initialChecked = const {},
    this.initialFlags = const {},
  });

  final String attemptId;
  final String mode;
  final String label;
  final List<ServedQuestion> questions;
  final Map<String, Passage> passages;

  /// Seconds left on the clock. Zero means untimed practice.
  ///
  /// This number is computed BY THE SERVER from the attempt's creation time,
  /// on a fresh start and on every resume alike, so closing the app cannot
  /// buy a student extra minutes.
  final int duration;

  final int initialIndex;
  final Map<String, String> initialAnswers;
  final Map<String, bool> initialChecked;
  final Map<String, bool> initialFlags;

  bool get timed => duration > 0;
}

/// One graded question, as the server marked it. This is the whole point of
/// sitting a paper: not the score, but seeing which one went wrong and why.
class Correction {
  const Correction({
    required this.id,
    required this.question,
    required this.options,
    required this.chosen,
    required this.right,
    required this.isRight,
    required this.explanation,
    this.media,
  });

  final String id;
  final String question;
  final List<String> options;

  /// The letter the student picked. Empty when they left it blank.
  final String chosen;
  final String right;
  final bool isRight;
  final String explanation;
  final Map<String, dynamic>? media;

  bool get skipped => chosen.isEmpty;

  /// Corrections carry options without their letters, so the letter is the
  /// position, exactly as the server assembled it.
  String letterAt(int i) => 'ABCDEFGH'[i];

  String? mediaUrl(String slot) {
    final m = media?[slot];
    if (m is Map && m['type'] == 'image' && m['url'] is String) {
      return m['url'] as String;
    }
    return null;
  }

  static Correction fromJson(Map<String, dynamic> j) => Correction(
    id: asText(j['id']),
    question: asText(j['question']),
    options: ((j['options'] as List?) ?? const []).cast<String>(),
    chosen: (asText(j['chosen'])).toUpperCase(),
    right: (asText(j['right'])).toUpperCase(),
    isRight: j['isRight'] == true,
    explanation: asText(j['explanation']),
    media: j['media'] as Map<String, dynamic>?,
  );
}

class SubmitResult {
  const SubmitResult({
    required this.correct,
    required this.total,
    required this.overall,
    required this.perSubject,
    this.corrections = const [],
  });

  final int correct;
  final int total;
  final int overall;
  final List<({String name, int correct, int total})> perSubject;
  final List<Correction> corrections;

  List<Correction> get missed => corrections.where((c) => !c.isRight).toList();
}

class PracticeRepository {
  PracticeRepository(this._api);
  final Api _api;

  Future<List<ExamOption>> exams() async {
    final res = await _api.get('/api/public/exam-tree');
    return ((res['exams'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(ExamOption.fromJson)
        .toList();
  }

  Future<List<SubjectOption>> subjects(String examSlug) async {
    final res = await _api.get(
      '/api/public/exam-tree',
      query: {'subjects': examSlug},
    );
    return ((res['subjects'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(SubjectOption.fromJson)
        .toList();
  }

  Future<ChooserData> chooser(String subjectId) async {
    final res = await _api.get(
      '/api/public/exam-tree',
      query: {'chooser': subjectId},
    );
    final exam = (res['exam'] as Map?)?.cast<String, dynamic>() ?? const {};
    final subject =
        (res['subject'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ChooserData(
      subjectName: asText(subject['name']),
      examSlug: asText(exam['slug']),
      examShort: asText(exam['short_name']),
      years: ((res['years'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map((y) => YearCount((y['year'] as num).toInt(), asInt(y['n'])))
          .toList(),
      topics: ((res['topics'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(
            (t) => TopicCount(
              t['topic_id'] as String,
              asText(t['name']),
              asInt(t['n']),
              asInt(t['n_tutorial']),
            ),
          )
          .where((t) => t.n > 0 || t.nTutorial > 0)
          .toList(),
      past: asInt(res['past']),
      tutorial: asInt(res['tutorial']),
    );
  }

  Future<Sitting> start({
    required String examSlug,
    required String subjectId,
    required String label,
    int? year,
    String? topicId,
    String kind = 'past',
    int count = 20,

    /// 'practice' is the untimed room with instant marking; 'cbt' is the timed
    /// one, marked at the end exactly as the real hall does it.
    String mode = 'practice',
    int minutes = 30,
  }) async {
    final res = await _api.post(
      '/api/attempts',
      body: {
        'action': 'start',
        'mode': mode,
        'examSlug': examSlug,
        'subjectIds': [subjectId],
        'count': '$count',
        'label': label,
        'year': ?year,
        'topicId': ?topicId,
        'kind': kind,
        if (mode == 'cbt') 'minutes': '$minutes',
      },
    );
    return _sitting(res, label);
  }

  Future<Sitting> resume(String attemptId) async {
    final res = await _api.post(
      '/api/attempts',
      body: {'action': 'resume', 'attemptId': attemptId},
    );
    final progress =
        (res['progress'] as Map?)?.cast<String, dynamic>() ?? const {};
    return _sitting(
      res,
      asText(res['label'], 'Practice'),
      initialIndex: asInt(progress['idx']),
      initialAnswers: ((progress['answers'] as Map?) ?? const {}).map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      ),
      initialChecked: ((progress['checked'] as Map?) ?? const {}).map(
        (k, v) => MapEntry(k.toString(), v == true),
      ),
      initialFlags: ((progress['flags'] as Map?) ?? const {}).map(
        (k, v) => MapEntry(k.toString(), v == true),
      ),
    );
  }

  Sitting _sitting(
    Map<String, dynamic> res,
    String label, {
    int initialIndex = 0,
    Map<String, String> initialAnswers = const {},
    Map<String, bool> initialChecked = const {},
    Map<String, bool> initialFlags = const {},
  }) => Sitting(
    attemptId: res['attemptId'] as String,
    mode: asText(res['mode'], 'practice'),
    label: label,
    duration: asInt(res['duration']),
    questions: ((res['questions'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(ServedQuestion.fromJson)
        .toList(),
    passages: ((res['passages'] as Map?) ?? const {}).map(
      (k, v) => MapEntry(
        k.toString(),
        Passage(
          title: (v as Map)['title'] as String? ?? '',
          body: asText(v['body']),
        ),
      ),
    ),
    initialIndex: initialIndex,
    initialAnswers: initialAnswers,
    initialChecked: initialChecked,
    initialFlags: initialFlags,
  );

  /// Autosave. Best effort by design: a lost heartbeat must never interrupt
  /// a student mid-question, so failures are swallowed here and the next
  /// answer tries again.
  Future<void> saveProgress({
    required String attemptId,
    required Map<String, String> answers,
    required Map<String, bool> checked,
    required int idx,
    Map<String, bool> flags = const {},
  }) async {
    try {
      await _api.post(
        '/api/attempts',
        body: {
          'flags': flags,
          'action': 'progress',
          'attemptId': attemptId,
          'answers': answers,
          'checked': checked,
          'idx': idx,
        },
      );
    } catch (_) {}
  }

  Future<SubmitResult> submit({
    required String attemptId,
    required Map<String, String> answers,
  }) async {
    final res = await _api.post(
      '/api/attempts',
      body: {'action': 'submit', 'attemptId': attemptId, 'answers': answers},
    );
    final score = (res['score'] as Map?)?.cast<String, dynamic>() ?? const {};
    return SubmitResult(
      correct: asInt(score['correct']),
      total: asInt(score['total']),
      overall: asInt(score['overall']),
      perSubject: ((score['perSubject'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(
            (p) => (
              name: asText(p['name'], 'Questions'),
              correct: asInt(p['correct']),
              total: asInt(p['total']),
            ),
          )
          .toList(),
      corrections: ((res['corrections'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(Correction.fromJson)
          .toList(),
    );
  }
}

final practiceRepositoryProvider = Provider(
  (ref) => PracticeRepository(ref.watch(apiProvider)),
);
