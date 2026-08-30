import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/design/theme.dart';
import 'package:lockinpoint/features/leaderboard/leaderboard_screen.dart';

class _FakeLadder extends Fake implements LeaderboardRepository {
  _FakeLadder(this._rows);
  final List<LadderRow> _rows;

  @override
  Future<List<LadderRow>> top() async => _rows;
}

Future<void> _pump(WidgetTester tester, List<LadderRow> rows) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        leaderboardRepositoryProvider.overrideWithValue(_FakeLadder(rows)),
      ],
      child: MaterialApp(
        theme: LipTheme.light(),
        home: const LeaderboardScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const rows = [
    LadderRow(rank: 1, name: 'sharpshooter01', points: 4820, streak: 12),
    LadderRow(rank: 2, name: 'Amina T.', points: 3990, streak: 0),
    LadderRow(rank: 3, name: 'Kweku A.', points: 3110, streak: 4),
    LadderRow(rank: 4, name: 'Ngozi O.', points: 2400, streak: 1),
  ];

  testWidgets('shows the ladder in the order the server ranked it', (
    tester,
  ) async {
    await _pump(tester, rows);
    expect(find.text('sharpshooter01'), findsOneWidget);
    expect(find.text('4820'), findsOneWidget);
    // Outside the top three the rank is a number, not a trophy.
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('a live streak is shown beside the points', (tester) async {
    await _pump(tester, rows);
    expect(find.text('12d'), findsOneWidget);
    // A student with no streak gets no badge rather than a zero.
    expect(find.text('0d'), findsNothing);
  });

  testWidgets('the points law is stated, not hidden', (tester) async {
    await _pump(tester, rows);
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
    await _pump(tester, const []);
    expect(find.text('The ladder is empty'), findsOneWidget);
    expect(find.textContaining('Be the first name on it'), findsOneWidget);
  });
}
