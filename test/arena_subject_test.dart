import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/core/api.dart';
import 'package:lockinpoint/design/theme.dart';
import 'package:lockinpoint/features/games/games_repository.dart';
import 'package:lockinpoint/features/games/games_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ===========================================================================
/// "THE GAMES MUST ASK SUBJECT AND EXAMINATION — NO YORUBA"
///
/// The arena never asked. gamePool() sent a count and nothing else, and
/// /api/games/pool has accepted `exam` and `subject` since the day it was
/// written — it says so in its own header. So a WAEC science candidate was
/// handed Yoruba, Literature and whatever else was in the bank.
///
/// Being asked a question from a subject you do not offer is not a game. It is
/// a reason to close the app.
/// ===========================================================================
class _Pool extends Fake implements Api {
  final List<Map<String, dynamic>> asked = [];

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    asked.add({'path': path, ...?query});
    if (path.contains('exam-tree')) {
      final q = query ?? const {};
      if (q.containsKey('subjects')) {
        return {
          'ok': true,
          'subjects': [
            {'id': 'chem1', 'name': 'Chemistry'},
            {'id': 'yor1', 'name': 'Yoruba'},
          ],
        };
      }
      return {
        'ok': true,
        'exams': [
          {
            'id': 'e1',
            'slug': 'waec',
            'short_name': 'WAEC',
            'full_name': 'WASSCE',
          },
        ],
      };
    }
    return {'ok': true, 'questions': const []};
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the pool request actually carries the exam and the subject', () async {
    final api = _Pool();
    await gamePool(api, count: 10, examSlug: 'waec', subjectId: 'chem1');

    final q = api.asked.last;
    expect(q['exam'], 'waec');
    expect(q['subject'], 'chem1');
  });

  test('nothing chosen sends nothing, rather than an empty filter', () async {
    /* An empty `subject=` would be a filter for a subject with no id, which
       is not the same as "no filter" and could match nothing at all. */
    final api = _Pool();
    await gamePool(api, count: 10);
    expect(api.asked.last.containsKey('exam'), isFalse);
    expect(api.asked.last.containsKey('subject'), isFalse);
  });

  testWidgets('the arena asks before it starts a game', (tester) async {
    final api = _Pool();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiProvider.overrideWithValue(api)],
        child: MaterialApp(theme: LipTheme.light(), home: const GamesScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Tapping a mode must NOT go straight into questions.
    await tester.tap(find.text('Blitz 60').first);
    await tester.pumpAndSettle();

    expect(
      find.text('Which examination?'),
      findsOneWidget,
      reason: 'the arena started a game without asking what the student sits',
    );

    await tester.tap(find.text('WAEC'));
    await tester.pumpAndSettle();
    expect(find.text('Which subject?'), findsOneWidget);
    // Yoruba is offered to somebody who sits it — the point is being ASKED.
    expect(find.text('Chemistry'), findsOneWidget);

    await tester.tap(find.text('Chemistry'));
    await tester.pumpAndSettle();

    // And the game it opened asked the server for THAT subject.
    final pool = api.asked.lastWhere((a) => '${a['path']}'.contains('pool'));
    expect(pool['exam'], 'waec');
    expect(pool['subject'], 'chem1');
  });

  testWidgets('it asks ONCE — the second game remembers', (tester) async {
    SharedPreferences.setMockInitialValues({
      'lip.arena-choice': ['waec', 'WAEC', 'chem1', 'Chemistry'],
    });
    final api = _Pool();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiProvider.overrideWithValue(api)],
        child: MaterialApp(theme: LipTheme.light(), home: const GamesScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Blitz 60').first);
    await tester.pumpAndSettle();

    expect(
      find.text('Which examination?'),
      findsNothing,
      reason:
          'a student should not re-pick their own subject every time they '
          'want sixty seconds of practice',
    );
  });

  testWidgets('and the remembered choice is visible and changeable', (
    tester,
  ) async {
    /* A setting asked once and never shown again is not a convenience, it is
       a trap: a student who picked Chemistry in January and now wants Physics
       would have no idea why every game is Chemistry. */
    SharedPreferences.setMockInitialValues({
      'lip.arena-choice': ['waec', 'WAEC', 'chem1', 'Chemistry'],
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiProvider.overrideWithValue(_Pool())],
        child: MaterialApp(theme: LipTheme.light(), home: const GamesScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('WAEC · Chemistry'), findsOneWidget);
    await tester.tap(find.text('WAEC · Chemistry'));
    await tester.pumpAndSettle();
    expect(find.text('Which examination?'), findsOneWidget);
  });
}
