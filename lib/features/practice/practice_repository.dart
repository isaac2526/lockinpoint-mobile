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
    slug: j['slug'] as String? ?? '',
    shortName: j['short_name'] as String? ?? '',
    fullName: j['full_name'] as String? ?? '',
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
    name: j['name'] as String? ?? '',
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
    this.subjectId,
  });

  final String id;
  final String question;
  final List<String> options;
  final List<String> letters;
  final String? passageId;
  final String? section;
  final int? year;

  /// Which subject this question belongs to, in a multi-subject sitting.
  /// Null in single-subject papers, where the answer is obvious.
  final String? subjectId;
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
    question: j['question'] as String? ?? '',
    options: ((j['options'] as List?) ?? const []).cast<String>(),
    letters: ((j['letters'] as List?) ?? const []).cast<String>(),
    passageId: j['passage_id'] as String?,
    section: j['section'] as String?,
    year: (j['year'] as num?)?.toInt(),
    answer: (j['answer'] as String?)?.toUpperCase(),
    explanation: j['explanation'] as String?,
    media: j['media'] as Map<String, dynamic>?,
    subjectId: j['subject_id'] as String?,
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
    this.subjects = const [],
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

  /// The subjects in this paper, in served order. The server has sent this
  /// list since the beginning — the app parsed it and dropped it, which is
  /// why a four-subject UTME mock rendered as one undifferentiated stream.
  final List<({String id, String name})> subjects;

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
    id: j['id'] as String? ?? '',
    question: j['question'] as String? ?? '',
    options: ((j['options'] as List?) ?? const []).cast<String>(),
    chosen: (j['chosen'] as String? ?? '').toUpperCase(),
    right: (j['right'] as String? ?? '').toUpperCase(),
    isRight: j['isRight'] == true,
    explanation: j['explanation'] as String? ?? '',
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
    this.isJamb = false,
    this.scaled = const [],
  });

  final int correct;
  final int total;
  final int overall;
  final List<({String name, int correct, int total})> perSubject;
  final List<Correction> corrections;

  /// A UTME mock is scored OUT OF 400, not as a percentage. The server has
  /// always said which this is; the app dropped the flag and printed "265%"
  /// in a circle whose thresholds painted every mock green.
  final bool isJamb;

  /// Per-subject scores on JAMB's own scale, as the server computed them.
  final List<({String name, int score})> scaled;

  /// What to show in the big circle, and what it is out of.
  String get headline => isJamb ? '$overall' : '$overall%';
  String? get outOf => isJamb ? 'out of 400' : null;

  /// Thresholds that mean the same thing on both scales: a 280 in JAMB is
  /// the same achievement as 70%.
  int get percentEquivalent => isJamb ? (overall / 4).round() : overall;

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
      subjectName: subject['name'] as String? ?? '',
      examSlug: exam['slug'] as String? ?? '',
      examShort: exam['short_name'] as String? ?? '',
      years: ((res['years'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(
            (y) => YearCount(
              (y['year'] as num).toInt(),
              (y['n'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList(),
      topics: ((res['topics'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(
            (t) => TopicCount(
              t['topic_id'] as String,
              t['name'] as String? ?? '',
              (t['n'] as num?)?.toInt() ?? 0,
              (t['n_tutorial'] as num?)?.toInt() ?? 0,
            ),
          )
          .where((t) => t.n > 0 || t.nTutorial > 0)
          .toList(),
      past: (res['past'] as num?)?.toInt() ?? 0,
      tutorial: (res['tutorial'] as num?)?.toInt() ?? 0,
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

    /// SHUFFLE THE OPTIONS. On by default, because practising a paper twice
    /// should teach the subject rather than "question 14 is C". The server
    /// leaves comprehension questions alone and records the order it used, so
    /// resuming shows the same paper the student left.
    bool shuffleOptions = true,
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
        'shuffleOptions': shuffleOptions,
        if (mode == 'cbt') 'minutes': '$minutes',
      },
    );
    return _sitting(res, label);
  }

  /// A FULL UTME SITTING — Use of English plus three chosen subjects, run
  /// through the same jamb_mock/jamb_mini engine the website has always had.
  ///
  /// The app never sent more than one subject id, so the four-subject mock —
  /// the sitting JAMB candidates actually face — could not be started from a
  /// phone at all. The server has supported subjectIds[] since the engine was
  /// written; this is the call that finally uses it.
  Future<Sitting> startUtme({
    required List<({String id, String name})> combination,
    bool mini = false,
  }) async {
    final label = combination.map((s) => s.name).join(', ');
    final res = await _api.post(
      '/api/attempts',
      body: {
        'action': 'start',
        'mode': mini ? 'jamb_mini' : 'jamb_mock',
        'examSlug': 'jamb',
        'subjectIds': combination.map((s) => s.id).toList(),
        'label': label,
        'shuffleOptions': true,
      },
    );
    return _sitting(res, label);
  }

  /// Remember the student's combination on their profile, so next time the
  /// picker opens on THEIR four subjects rather than a blank slate. Fire and
  /// forget — failing to save a preference must never block a mock.
  Future<void> saveCombination(List<String> names) async {
    try {
      await _api.post(
        '/api/profile/complete',
        body: {'subjectCombination': names.join(' · ')},
      );
    } on ApiFailure {
      // A preference, not a paper. Nothing is lost but a prefill.
    }
  }

  /// REOPEN A FINISHED PAPER. The answer key is stored on the attempt, so a
  /// sitting from last week can be walked through again — the corrections
  /// used to exist for exactly as long as the result screen stayed open.
  Future<SubmitResult> review(String attemptId) async {
    final res = await _api.post(
      '/api/attempts',
      body: {'action': 'review', 'attemptId': attemptId},
    );
    return _submitResult(res);
  }

  /// Keep this question, or let it go. The same /api/qmark the website has
  /// always used, so a question saved on a phone is in the list on the site.
  Future<void> setSaved(String questionId, bool saved) => _api.post(
    '/api/qmark',
    body: {'op': saved ? 'save' : 'unsave', 'questionId': questionId},
  );

  /// Which questions this student has already kept, so a sitting can show
  /// the bookmark already filled rather than making them guess.
  Future<Set<String>> savedIds() async {
    try {
      final res = await _api.post('/api/qmark', body: {'op': 'saved_ids'});
      return ((res['ids'] as List?) ?? const []).map((e) => '$e').toSet();
    } on ApiFailure {
      // Not knowing is not an error worth blocking a sitting for.
      return <String>{};
    }
  }

  /// A paper built from the questions this student saved.
  ///
  /// The saved list existed and nothing turned it into a sitting — so the
  /// questions a student had explicitly marked as hard were the only ones they
  /// could not practise as a set. The server picks them; the app only asks.
  Future<Sitting> startFromSaved({
    int count = 20,
    String mode = 'practice',
    int minutes = 30,
  }) async {
    final res = await _api.post(
      '/api/attempts',
      body: {
        'action': 'start',
        'mode': mode,
        'fromSaved': true,
        'count': '$count',
        'label': 'Saved questions',
        'shuffleOptions': true,
        if (mode == 'cbt') 'minutes': '$minutes',
      },
    );
    return _sitting(res, 'Saved questions');
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
      res['label'] as String? ?? 'Practice',
      initialIndex: (progress['idx'] as num?)?.toInt() ?? 0,
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
    mode: res['mode'] as String? ?? 'practice',
    label: label,
    duration: (res['duration'] as num?)?.toInt() ?? 0,
    questions: ((res['questions'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(ServedQuestion.fromJson)
        .toList(),
    passages: ((res['passages'] as Map?) ?? const {}).map(
      (k, v) => MapEntry(
        k.toString(),
        Passage(
          title: (v as Map)['title'] as String? ?? '',
          body: v['body'] as String? ?? '',
        ),
      ),
    ),
    subjects: ((res['subjects'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => (id: '${m['id'] ?? ''}', name: '${m['name'] ?? ''}'))
        .where((x) => x.id.isNotEmpty)
        .toList(),
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
    return _submitResult(res);
  }

  /// One parse for a graded paper, whether it was just submitted or is being
  /// reopened weeks later — two parsers would eventually disagree about a
  /// student's own score.
  SubmitResult _submitResult(Map<String, dynamic> res) {
    final score = ((res['score'] as Map?) ?? const {}).cast<String, dynamic>();
    return SubmitResult(
      correct: (score['correct'] as num?)?.toInt() ?? 0,
      total: (score['total'] as num?)?.toInt() ?? 0,
      overall: (score['overall'] as num?)?.toInt() ?? 0,
      perSubject: ((score['perSubject'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(
            (p) => (
              name: p['name'] as String? ?? 'Questions',
              correct: (p['correct'] as num?)?.toInt() ?? 0,
              total: (p['total'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList(),
      corrections: ((res['corrections'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(Correction.fromJson)
          .toList(),
      isJamb: score['isJamb'] == true,
      scaled: ((score['scaled'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (p) => (
              name: p['name'] as String? ?? '',
              score: (p['score'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList(),
    );
  }
}

final practiceRepositoryProvider = Provider(
  (ref) => PracticeRepository(ref.watch(apiProvider)),
);
