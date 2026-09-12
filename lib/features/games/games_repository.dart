import '../../core/json.dart';
import '../../core/api.dart';

/// ===========================================================================
/// THE GAMES ARENA
///
/// Four quick games over one endpoint, and The Climb over another.
///
/// WHAT THE APP DOES NOT DO: mark The Climb. Its answer key never leaves the
/// server — grading, the rung, the safety nets and the lifelines are all held
/// there, because a ladder graded on the phone is a ladder beaten with a
/// debugger. The quick games DO get their key with the question, exactly as
/// the website's do: they are practice with a timer on, not a competition,
/// and the same pool endpoint serves both so the two can never diverge.
/// ===========================================================================

class GameQuestion {
  const GameQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.letters,
    required this.answer,
    this.explanation = '',
    this.year,
  });

  final String id;
  final String question;
  final List<String> options;
  final List<String> letters;
  final String answer;
  final String explanation;
  final int? year;

  int get answerIndex {
    final i = letters.indexOf(answer.toUpperCase());
    return i >= 0 && i < options.length ? i : -1;
  }

  static GameQuestion from(Map<String, dynamic> j) => GameQuestion(
    id: asText(j['id']),
    question: asText(j['question']),
    options: asTextList(j['options']),
    letters: asTextList(j['letters']),
    answer: (asText(j['answer'])).toUpperCase(),
    explanation: asText(j['explanation']),
    year: asIntOrNull(j['year']),
  );
}

/// A plate of questions for one of the quick games.
///
/// `daily` makes it the same plate for every student today — that is the whole
/// point of the Daily Ten, and it is the server that guarantees it, not a
/// shuffle here.
/// The arena's questions.
///
/// [examSlug] AND [subjectId] WERE NEVER SENT. /api/games/pool has accepted
/// both since it was written — it says so in its own header — and the app
/// asked for neither, so a WAEC science candidate was handed Yoruba,
/// Literature and anything else that happened to be in the bank. Being asked
/// a question from a subject you do not offer is not a game; it is a reason
/// to close the app.
Future<List<GameQuestion>> gamePool(
  Api api, {
  int count = 15,
  bool daily = false,
  bool fourOnly = false,
  String examSlug = '',
  String subjectId = '',
}) async {
  final res = await api.get(
    '/api/games/pool',
    query: {
      'count': '$count',
      if (daily) 'day': '1',
      if (fourOnly) 'four': '1',
      if (examSlug.isNotEmpty) 'exam': examSlug,
      if (subjectId.isNotEmpty) 'subject': subjectId,
    },
  );
  return (asList(res['questions']))
      .whereType<Map>()
      .map((m) => GameQuestion.from(m.cast<String, dynamic>()))
      .toList();
}

// --------------------------------------------------------------- the climb --

/// One rung of The Climb, exactly as the server describes it. The app renders
/// this and nothing more: it never computes a score, a rung or what is banked.
class ClimbState {
  const ClimbState({
    required this.id,
    required this.rung,
    required this.total,
    required this.ladder,
    required this.firstNet,
    required this.secondNet,
    required this.banked,
    required this.status,
    required this.score,
    required this.lifelines,
    required this.seconds,
    required this.question,
    required this.options,
  });

  final String id;
  final int rung;
  final int total;
  final List<int> ladder;
  final int firstNet;
  final int? secondNet;
  final int banked;

  /// playing · won · lost · walked
  final String status;
  final int score;

  /// Which lifelines are still available to spend.
  final Map<String, bool> lifelines;

  /// Null in classic mode. Seconds for this rung in clock mode, with any
  /// banked time already added on the final question.
  final int? seconds;

  final String question;

  /// Letter → text. Options removed by Fifty-Fifty are simply absent, because
  /// the server sends what is left rather than telling the app what to hide.
  final List<({String letter, String text})> options;

  bool get playing => status == 'playing';

  static ClimbState from(Map<String, dynamic> s) {
    final q = s['question'];
    return ClimbState(
      id: asText(s['id']),
      rung: asInt(s['rung'], 1),
      total: asInt(s['total'], 15),
      ladder: (asList(s['ladder'])).map((e) => asInt(e)).toList(),
      firstNet: asInt(s['firstNet'], 5),
      secondNet: asIntOrNull(s['secondNet']),
      banked: asInt(s['banked']),
      status: asText(s['status'], 'playing'),
      score: asInt(s['score']),
      lifelines: {
        for (final e in asMap(s['lifelines']).entries) e.key: e.value == true,
      },
      seconds: asIntOrNull(s['seconds']),
      question: q is Map ? (asText(q['question'])) : '',
      options: q is Map
          ? (asList(q['options']))
                .whereType<Map>()
                .map((o) => (letter: '${o['letter']}', text: '${o['text']}'))
                .toList()
          : const [],
    );
  }
}

/// What came back from answering: whether it was right, what was right, and
/// the sentence explaining why.
class ClimbAnswer {
  const ClimbAnswer({
    required this.correct,
    required this.won,
    required this.right,
    required this.explanation,
    required this.state,
    this.unlockedDoubleDip = false,
    this.dipRemaining = false,
  });

  final bool correct;
  final bool won;

  /// Null while a Double Dip is still live — the server withholds the answer
  /// so the second guess is still a guess.
  final String? right;
  final String explanation;
  final ClimbState? state;
  final bool unlockedDoubleDip;
  final bool dipRemaining;
}

class ClimbApi {
  const ClimbApi(this._api);
  final Api _api;

  Future<Map<String, dynamic>> _post(Map<String, dynamic> body) =>
      _api.post('/api/games/ladder', body: body);

  /// WHAT THE CHOOSER NEEDS BEFORE A SINGLE QUESTION IS DEALT.
  ///
  /// The app never called this. It went straight to `op: "start"` with no
  /// subject, and the server — which has required one since the Yoruba fix —
  /// answered "Pick a subject to climb." every single time. The Climb was
  /// unstartable from the phone, which is exactly what "the climb is saying
  /// rubbish" describes.
  ///
  /// The server does the thinking here: it returns only subjects with enough
  /// questions to fill all fifteen rungs, and marks the ones this student
  /// actually sits — inferred from their own past attempts and study plan
  /// rather than from a form nobody filled in.
  Future<ClimbSetup> setup() async {
    final res = await _post({'op': 'setup'});
    return ClimbSetup.from(res);
  }

  Future<ClimbState> start({
    required List<String> lifelines,
    String mode = 'classic',
    String? exam,
    String? subject,
  }) async {
    final res = await _post({
      'op': 'start',
      'lifelines': lifelines,
      'mode': mode,
      'exam': ?exam,
      'subject': ?subject,
    });
    return ClimbState.from(asMap(res['state']));
  }

  Future<ClimbState> state(String gameId) async {
    final res = await _post({'op': 'state', 'gameId': gameId});
    return ClimbState.from(asMap(res['state']));
  }

  Future<ClimbState> setNet(String gameId, int rung) async {
    final res = await _post({'op': 'set_net', 'gameId': gameId, 'rung': rung});
    return ClimbState.from(asMap(res['state']));
  }

  /// Spend a lifeline. The server decides what it reveals — Fifty-Fifty comes
  /// back as a state with two options gone, Ask the Class as a distribution.
  Future<Map<String, dynamic>> lifeline(String gameId, String which) =>
      _post({'op': 'lifeline', 'gameId': gameId, 'which': which});

  Future<ClimbAnswer> answer(
    String gameId,
    String letter, {
    int? timeLeft,
    bool secondGuess = false,
  }) async {
    final res = await _post({
      'op': 'answer',
      'gameId': gameId,
      'letter': letter,
      'timeLeft': ?timeLeft,
      if (secondGuess) 'secondGuess': true,
    });
    final st = res['state'];
    return ClimbAnswer(
      correct: res['correct'] == true,
      won: res['won'] == true,
      right: asTextOrNull(res['right']),
      explanation: asText(res['explanation']),
      state: st is Map ? ClimbState.from(st.cast<String, dynamic>()) : null,
      unlockedDoubleDip: res['unlockedDoubleDip'] == true,
      dipRemaining: res['dipRemaining'] == true,
    );
  }

  /// Stop and keep what is banked. A real decision, so the UI confirms it.
  Future<ClimbState> walk(String gameId) async {
    final res = await _post({'op': 'walk', 'gameId': gameId});
    return ClimbState.from(asMap(res['state']));
  }
}

/// A subject the ladder can actually be built from.
class ClimbSubject {
  const ClimbSubject({
    required this.id,
    required this.name,
    required this.exam,
    required this.examName,
    required this.ready,
    required this.mine,
  });

  final String id;
  final String name;
  final String exam;
  final String examName;

  /// How many questions stand behind it. The server only ever sends subjects
  /// that can fill the whole ladder, so this is for showing, not for judging.
  final int ready;

  /// True when this student has actually sat this subject before, or it is in
  /// their study plan. The chooser puts these first — the answer to "Yoruba
  /// keeps coming up and I don't offer it".
  final bool mine;

  static ClimbSubject from(Map<String, dynamic> j) => ClimbSubject(
    id: asText(j['id']),
    name: asText(j['name']),
    exam: asText(j['exam']),
    examName: asText(j['examName']),
    ready: asInt(j['ready']),
    mine: j['mine'] == true,
  );
}

class ClimbSetup {
  const ClimbSetup({required this.subjects, required this.anyReady});

  final List<ClimbSubject> subjects;

  /// False when the question bank cannot fill a ladder in ANY subject. That
  /// is a different sentence to "pick a subject", and a student deserves to
  /// be told which of the two it is.
  final bool anyReady;

  /// This student's own subjects first, then the rest, each group by name.
  List<ClimbSubject> get ordered {
    final mine = subjects.where((s) => s.mine).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final rest = subjects.where((s) => !s.mine).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return [...mine, ...rest];
  }

  static ClimbSetup from(Map<String, dynamic> j) => ClimbSetup(
    subjects: (asList(j['subjects']))
        .whereType<Map>()
        .map((m) => ClimbSubject.from(m.cast<String, dynamic>()))
        .toList(),
    anyReady: j['anyReady'] == true,
  );
}
