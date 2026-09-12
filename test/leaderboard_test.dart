import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/core/smart_cache.dart';
import 'package:lockinpoint/design/theme.dart';
import 'package:lockinpoint/features/leaderboard/leaderboard_screen.dart';

class _FakeLadder extends Fake implements LeaderboardRepository {
  _FakeLadder(this._board);
  final Ladder _board;

  /// The scope the screen last asked for, so a test can prove that tapping a
  /// chip actually re-asks the server rather than filtering on the phone.
  String? asked;

  @override
  Future<Cached<Ladder>> board(String scope) async {
    asked = scope;
    // Live, so these tests are about what a fresh board looks like. The
    // stale path has its own file: smart_cache_test.dart.
    return Cached(value: _board, savedAt: DateTime.now());
  }
}

/// Rows are built the way the app builds them — out of the JSON the route
/// really sends. A test that constructs the model by hand cannot catch a key
/// the parser reads under the wrong name, which is precisely the defect that
/// left state, last seen and the longest streak off this screen.
LadderRow _row({
  required int rank,
  required String name,
  required int points,
  int streak = 0,
  int longestStreak = 0,
  String state = '',
  String institution = '',
  String lastSeen = '',
  bool isMe = false,
}) => LadderRow.fromJson({
  'rank': rank,
  'userId': 'u$rank',
  'name': name,
  'points': points,
  'streak': streak,
  'longestStreak': longestStreak,
  'minutes': 0,
  'country': 'Nigeria',
  'state': state,
  'institution': institution,
  'lastSeen': lastSeen,
  'isMe': isMe,
});

Future<_FakeLadder> _pump(WidgetTester tester, Ladder board) async {
  final fake = _FakeLadder(board);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [leaderboardRepositoryProvider.overrideWithValue(fake)],
      child: MaterialApp(
        theme: LipTheme.light(),
        home: const LeaderboardScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  final rows = [
    _row(
      rank: 1,
      name: 'sharpshooter01',
      points: 4820,
      streak: 12,
      longestStreak: 31,
      state: 'Lagos',
      institution: 'UNILAG',
      lastSeen: 'now',
    ),
    _row(rank: 2, name: 'Amina T.', points: 3990, state: 'Kano'),
    _row(rank: 3, name: 'Kweku A.', points: 3110, streak: 4),
    _row(rank: 4, name: 'Ngozi O.', points: 2400, streak: 1),
  ];

  final board = Ladder(
    rows: rows,
    me: null,
    scopes: const [
      LadderScope(key: 'national', label: 'National', available: true),
      LadderScope(key: 'state', label: 'Lagos', available: true),
      LadderScope(key: 'school', label: 'My school', available: false),
    ],
    total: 4,
    message: '',
  );

  testWidgets('shows the ladder in the order the server ranked it', (
    tester,
  ) async {
    await _pump(tester, board);
    expect(find.text('sharpshooter01'), findsOneWidget);
    expect(find.text('4820'), findsOneWidget);
    // Outside the top three the rank is a number, not a trophy.
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('a live streak is shown beside the points', (tester) async {
    await _pump(tester, board);
    expect(find.text('12d streak'), findsOneWidget);
    // A student with no streak gets no badge rather than a zero.
    expect(find.text('0d streak'), findsNothing);
  });

  testWidgets('the state and school are on the row', (tester) async {
    await _pump(tester, board);
    // The route has always sent these; the row used to drop them.
    expect(find.text('Lagos · UNILAG'), findsOneWidget);
    expect(find.text('Kano'), findsOneWidget);
  });

  testWidgets('last seen and the record streak ride under the name', (
    tester,
  ) async {
    await _pump(tester, board);
    // A 12-day streak beside a 31-day record reads as a stumble; 12 alone
    // reads as a beginner.
    expect(find.text('now · best 31d'), findsOneWidget);
  });

  testWidgets('the record is not repeated when it IS the live streak', (
    tester,
  ) async {
    await _pump(
      tester,
      Ladder(
        rows: [
          _row(
            rank: 1,
            name: 'Steady',
            points: 10,
            streak: 9,
            longestStreak: 9,
          ),
        ],
        me: null,
        scopes: const [],
        total: 1,
        message: '',
      ),
    );
    expect(find.text('best 9d'), findsNothing);
    expect(find.text('9d streak'), findsOneWidget);
  });

  testWidgets('choosing a scope re-asks the server for that scope', (
    tester,
  ) async {
    final fake = await _pump(tester, board);
    expect(fake.asked, 'national');
    await tester.tap(find.text('Lagos').last);
    await tester.pumpAndSettle();
    // Ranking is the server's. The phone must never filter a board itself.
    expect(fake.asked, 'state');
  });

  testWidgets('a scope the student cannot use says why, and does not ask', (
    tester,
  ) async {
    final fake = await _pump(tester, board);
    await tester.tap(find.text('My school'));
    await tester.pumpAndSettle();
    expect(fake.asked, 'national');
    expect(find.textContaining('Add your school'), findsOneWidget);
  });

  testWidgets('my own rung is shown even when it is not in the top hundred', (
    tester,
  ) async {
    await _pump(
      tester,
      Ladder(
        rows: rows,
        me: _row(rank: 4312, name: 'You', points: 90, isMe: true),
        scopes: const [],
        total: 9000,
        message: '',
      ),
    );
    // LipLabel uppercases what it is given, so the heading on screen is
    // WHERE YOU ARE. Matching the sentence case would have passed for the
    // wrong reason on a screen that had scrolled to the bottom anyway.
    await tester.dragUntilVisible(
      find.text('WHERE YOU ARE'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    // Being 4,312th is information. A blank space is not.
    expect(find.text('4312'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
  });

  testWidgets('a broken board does not look like an empty one', (tester) async {
    await _pump(
      tester,
      const Ladder(
        rows: [],
        me: null,
        scopes: [],
        total: 0,
        message: 'The board is warming up. Try again shortly.',
      ),
    );
    expect(find.textContaining('warming up'), findsOneWidget);
    expect(find.text('The ladder is empty'), findsNothing);
  });

  testWidgets('the points law is stated, not hidden', (tester) async {
    await _pump(tester, board);
    await tester.dragUntilVisible(
      find.text('Every correct answer'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(find.text('Every correct answer'), findsOneWidget);
    expect(find.text('Each day of a live streak'), findsOneWidget);
  });

  testWidgets('an empty ladder invites the student onto it', (tester) async {
    await _pump(tester, Ladder.empty);
    expect(find.text('The ladder is empty'), findsOneWidget);
    expect(find.textContaining('Be the first name on it'), findsOneWidget);
  });
}
