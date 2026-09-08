import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/core/api.dart';
import 'package:lockinpoint/design/theme.dart';
import 'package:lockinpoint/features/activity/activity_screen.dart';
import 'package:lockinpoint/features/plan/plan_repository.dart';
import 'package:lockinpoint/features/plan/plan_screen.dart';
import 'package:lockinpoint/features/rounds/rounds_repository.dart';
import 'package:lockinpoint/features/rounds/rounds_screen.dart';

/// ===========================================================================
/// THREE ROOMS THE APP NEVER HAD, ON BACKENDS THAT WERE ALWAYS THERE.
///
/// /api/mobile/plan, /api/mobile/rounds and the activity log were all built,
/// tested and serving, and the app called none of them. These tests hold the
/// two things easiest to get wrong while wiring a room like that:
///
///   1. A NULL answer is a real answer. No study plan yet and no competition
///      running are the normal states, and both must read as an invitation
///      rather than as breakage.
///   2. The write must say which job it wants. The plan route does two things
///      behind one POST, and an `op` left off does not fail — it silently
///      REBUILDS the whole fortnight when the student meant to tick one box.
/// ===========================================================================

class _Server extends Fake implements Api {
  _Server(this.answers);
  final Map<String, Map<String, dynamic>> answers;
  final List<({String path, Object? body})> posts = [];

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async => answers[path] ?? {'ok': true};

  @override
  Future<Map<String, dynamic>> post(String path, {Object? body}) async {
    posts.add((path: path, body: body));
    return {'ok': true};
  }
}

Future<void> _pump(WidgetTester tester, Widget home, _Server server) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [apiProvider.overrideWithValue(server)],
      child: MaterialApp(theme: LipTheme.light(), home: home),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the study plan', () {
    testWidgets('with no plan yet, it invites you to build one', (
      tester,
    ) async {
      final s = _Server({
        '/api/mobile/plan': {'ok': true, 'plan': null, 'items': []},
      });
      await _pump(tester, const PlanScreen(), s);
      expect(find.text('Build your fortnight'), findsOneWidget);
      expect(find.text('Build my plan'), findsOneWidget);
    });

    testWidgets('it refuses to build without an exam date, and says why', (
      tester,
    ) async {
      final s = _Server({
        '/api/mobile/plan': {'ok': true, 'plan': null, 'items': []},
      });
      await _pump(tester, const PlanScreen(), s);
      await tester.tap(find.text('Build my plan'));
      await tester.pumpAndSettle();
      expect(find.text('Pick the day you sit the exam.'), findsOneWidget);
      // Nothing was sent: a plan with no date is not a plan.
      expect(s.posts, isEmpty);
    });

    testWidgets('an existing plan leads with what is due now', (tester) async {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final s = _Server({
        '/api/mobile/plan': {
          'ok': true,
          'plan': {
            'id': 'p1',
            'targetDate': DateTime.now()
                .add(const Duration(days: 30))
                .toIso8601String(),
            'minutesPerDay': 45,
          },
          'items': [
            {
              'id': 'i1',
              'dueOn': today,
              'label': 'Mole concept · Chemistry',
              'kind': 'practice',
              'targetQuestions': 20,
              'done': false,
            },
          ],
        },
      });
      await _pump(tester, const PlanScreen(), s);
      expect(find.text('30 days to go'), findsOneWidget);
      expect(find.text('DO THIS NOW'), findsOneWidget);
      expect(find.textContaining('Mole concept'), findsWidgets);
    });

    test('ticking an item says WHICH job it wants', () {
      // The route does two things behind one POST. Without `op` it does not
      // fail — it rebuilds the entire fortnight when the student meant to
      // tick one box, and their plan silently changes underneath them.
      // This asserts the PRODUCTION body builder, not a copy of it.
      final ticked = planTickBody('i1', done: true);
      expect(ticked['op'], 'done');
      expect(ticked['itemId'], 'i1');
      expect(ticked.containsKey('undo'), isFalse);

      expect(planTickBody('i1', done: false)['undo'], true);
    });
  });

  group('the challenge', () {
    testWidgets('no round open reads as an invitation, not as breakage', (
      tester,
    ) async {
      final s = _Server({
        '/api/mobile/rounds': {'ok': true, 'round': null, 'winners': []},
      });
      await _pump(tester, const RoundsScreen(), s);
      expect(find.text('No challenge is open right now'), findsOneWidget);
    });

    testWidgets('an open round shows its days left and its prizes', (
      tester,
    ) async {
      final s = _Server({
        '/api/mobile/rounds': {
          'ok': true,
          'round': {
            'id': 'r1',
            'name': 'UTME Challenge',
            'description': 'Every sitting this month counts.',
            'startsAt': DateTime.now()
                .subtract(const Duration(days: 3))
                .toIso8601String(),
            'endsAt': DateTime.now()
                .add(const Duration(days: 5))
                .toIso8601String(),
            'prizes': [
              {'position': 1, 'prize': 'A data bundle', 'note': 'Every month'},
            ],
          },
          'winners': [
            {
              'round': 'March Challenge',
              'position': 1,
              'name': 'ada',
              'prize': 'A data bundle',
              'state': 'Lagos',
            },
          ],
        },
      });
      await _pump(tester, const RoundsScreen(), s);
      expect(find.text('UTME Challenge'), findsOneWidget);
      expect(find.text('5 days left'), findsOneWidget);
      expect(find.text('THE ROLL'), findsOneWidget);
      // A username, never an email: this board is public.
      expect(find.text('ada'), findsOneWidget);
    });

    test('a round with no end date does not invent a countdown', () {
      final r = Round.from({'id': 'r', 'name': 'Open'});
      expect(r.daysLeft, isNull);
    });
  });

  group('activity history', () {
    testWidgets('an empty log says what will fill it', (tester) async {
      final s = _Server({
        '/api/mobile/activity': {
          'ok': true,
          'rows': [],
          'total': 0,
          'hasMore': false,
        },
      });
      await _pump(tester, const ActivityScreen(), s);
      expect(find.text('Nothing recorded yet'), findsOneWidget);
    });

    testWidgets('rows carry their sentence, not their database slug', (
      tester,
    ) async {
      final s = _Server({
        '/api/mobile/activity': {
          'ok': true,
          'total': 1,
          'hasMore': false,
          'rows': [
            {
              'id': 'a1',
              'type': 'attempt_submit',
              'title': 'Finished a sitting',
              'icon': 'check',
              'detail': 'cbt · scored 68%',
              'at': DateTime.now()
                  .subtract(const Duration(hours: 3))
                  .toIso8601String(),
            },
          ],
        },
      });
      await _pump(tester, const ActivityScreen(), s);
      expect(find.text('Finished a sitting'), findsOneWidget);
      expect(find.text('attempt_submit'), findsNothing);
      expect(find.text('3 hours ago'), findsOneWidget);
    });
  });
}
