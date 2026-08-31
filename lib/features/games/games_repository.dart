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
    id: j['id'] as String? ?? '',
    question: j['question'] as String? ?? '',
    options: ((j['options'] as List?) ?? const []).map((o) => '$o').toList(),
    letters: ((j['letters'] as List?) ?? const []).map((o) => '$o').toList(),
    answer: (j['answer'] as String? ?? '').toUpperCase(),
    explanation: j['explanation'] as String? ?? '',
    year: j['year'] is int ? j['year'] as int : null,
  );
}

/// A plate of questions for one of the quick games.
///
/// `daily` makes it the same plate for every student today — that is the whole
/// point of the Daily Ten, and it is the server that guarantees it, not a
/// shuffle here.
Future<List<GameQuestion>> gamePool(
  Api api, {
  int count = 15,
  bool daily = false,
  bool fourOnly = false,
}) async {
  final res = await api.get(
    '/api/games/pool',
    query: {
      'count': '$count',
      if (daily) 'day': '1',
      if (fourOnly) 'four': '1',
    },
  );
  return ((res['questions'] as List?) ?? const [])
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
      id: s['id'] as String? ?? '',
      rung: (s['rung'] as num?)?.toInt() ?? 1,
      total: (s['total'] as num?)?.toInt() ?? 15,
      ladder: ((s['ladder'] as List?) ?? const [])
          .map((e) => (e as num).toInt())
          .toList(),
      firstNet: (s['firstNet'] as num?)?.toInt() ?? 5,
      secondNet: (s['secondNet'] as num?)?.toInt(),
      banked: (s['banked'] as num?)?.toInt() ?? 0,
      status: s['status'] as String? ?? 'playing',
      score: (s['score'] as num?)?.toInt() ?? 0,
      lifelines: {
        for (final e in ((s['lifelines'] as Map?) ?? const {}).entries)
          '${e.key}': e.value == true,
      },
      seconds: (s['seconds'] as num?)?.toInt(),
      question: q is Map ? (q['question'] as String? ?? '') : '',
      options: q is Map
          ? ((q['options'] as List?) ?? const [])
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
    return ClimbState.from((res['state'] as Map).cast<String, dynamic>());
  }

  Future<ClimbState> state(String gameId) async {
    final res = await _post({'op': 'state', 'gameId': gameId});
    return ClimbState.from((res['state'] as Map).cast<String, dynamic>());
  }

  Future<ClimbState> setNet(String gameId, int rung) async {
    final res = await _post({'op': 'set_net', 'gameId': gameId, 'rung': rung});
    return ClimbState.from((res['state'] as Map).cast<String, dynamic>());
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
      right: res['right'] as String?,
      explanation: res['explanation'] as String? ?? '',
      state: st is Map ? ClimbState.from(st.cast<String, dynamic>()) : null,
      unlockedDoubleDip: res['unlockedDoubleDip'] == true,
      dipRemaining: res['dipRemaining'] == true,
    );
  }

  /// Stop and keep what is banked. A real decision, so the UI confirms it.
  Future<ClimbState> walk(String gameId) async {
    final res = await _post({'op': 'walk', 'gameId': gameId});
    return ClimbState.from((res['state'] as Map).cast<String, dynamic>());
  }
}
