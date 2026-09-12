import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/core/api.dart';
import 'package:lockinpoint/design/theme.dart';
import 'package:lockinpoint/features/classroom/classroom_screen.dart';
import 'package:lockinpoint/features/theory/theory_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ===========================================================================
/// THEORY AND THE CLASSROOM, OFF SIGNAL
///
/// Both rooms went straight to the network at every step. A student on a bus
/// could not so much as SEE the list of subjects whose notes they had already
/// downloaded — the shelf was an error card, and the material behind it,
/// already on the phone and already theirs, was unreachable through it.
///
/// The one that matters most is a SESSION or a NOTE read once: a student who
/// opened Tutor Bello's walked solution last night on wifi should be able to
/// revise from it this morning, without having had to know in advance to
/// press Keep.
///
/// This is the real journey — read it online, kill the network, open the app
/// again — not a check that a provider exists.
/// ===========================================================================
class _Server extends Fake implements Api {
  bool online = true;
  final List<String> asked = [];

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final q = query ?? const {};
    asked.add('$path ${q.keys.join(",")}');
    if (!online) throw ApiFailure('No connection. Try again in a moment.');

    if (path.contains('theory')) {
      if (q.containsKey('session')) {
        return {
          'ok': true,
          'session': {
            'id': 'n1',
            'title': 'Momentum, walked through',
            'body_html': '<p>Start from Newton&rsquo;s second law.</p>',
          },
        };
      }
      if (q.containsKey('subject')) {
        return {
          'ok': true,
          'sessions': [
            {'id': 'n1', 'title': 'Momentum, walked through'},
          ],
          'years': const [],
          'topics': const [],
        };
      }
      if (q.containsKey('exam')) {
        return {
          'ok': true,
          'subjects': [
            {'id': 's1', 'name': 'Physics', 'exam': 'WAEC', 'sessions': 1},
          ],
        };
      }
      return {
        'ok': true,
        'exams': [
          {
            'slug': 'waec',
            'name': 'WAEC',
            'full': 'West African',
            'subjects': 1,
          },
        ],
        'subjects': const [],
      };
    }

    // The classroom.
    if (q.containsKey('note')) {
      return {
        'ok': true,
        'note': {'title': 'Balancing equations', 'body': 'Start with atoms.'},
      };
    }
    if (q.containsKey('subject')) {
      return {
        'ok': true,
        'notes': [
          {'id': 'c1', 'title': 'Balancing equations', 'kind': 'note'},
        ],
        'videos': const [],
        'documents': const [],
      };
    }
    if (q.containsKey('exam')) {
      return {
        'ok': true,
        'subjects': [
          {'id': 'sub1', 'name': 'Chemistry'},
        ],
      };
    }
    return {
      'ok': true,
      'exams': [
        {'slug': 'waec', 'name': 'WAEC'},
      ],
    };
  }
}

/// A genuine cold start: a second ProviderScope at the same position would be
/// reused, container and all, and the "second launch" would quietly re-show
/// the first launch's answer.
Future<void> _launch(WidgetTester tester, Api api, Widget home) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [apiProvider.overrideWithValue(api)],
      child: MaterialApp(theme: LipTheme.light(), home: home),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Theory: a walk taken online can be retaken with no network', (
    tester,
  ) async {
    final api = _Server();

    // ── ONLINE: exam → subject → shelf → session ──
    await _launch(tester, api, const TheoryScreen());
    await tester.tap(find.text('WAEC'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Physics'));
    await tester.pumpAndSettle();
    expect(find.text('Momentum, walked through'), findsOneWidget);
    await tester.tap(find.text('Momentum, walked through'));
    await tester.pumpAndSettle();

    // ── THE NETWORK GOES ──
    api.online = false;
    await _launch(tester, api, const TheoryScreen());

    expect(
      find.text('WAEC'),
      findsOneWidget,
      reason: 'the examinations were an error card off signal',
    );
    await tester.tap(find.text('WAEC'));
    await tester.pumpAndSettle();
    expect(find.text('Physics'), findsOneWidget);
    await tester.tap(find.text('Physics'));
    await tester.pumpAndSettle();

    expect(
      find.text('Momentum, walked through'),
      findsOneWidget,
      reason: 'the shelf of what this subject holds must survive',
    );
    await tester.tap(find.text('Momentum, walked through'));
    await tester.pumpAndSettle();

    /* THE ONE THAT MATTERS. The session opens from storage, so a student
       revising on a bus reads the tutor's own walked solution. */
    expect(find.text('Momentum, walked through'), findsWidgets);
    expect(find.text('That did not load'), findsNothing);
  });

  testWidgets('Classroom: the shelf and a note survive going off signal', (
    tester,
  ) async {
    final api = _Server();

    await _launch(tester, api, const ClassroomScreen());
    await tester.tap(find.text('WAEC'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chemistry'));
    await tester.pumpAndSettle();
    expect(find.text('Balancing equations'), findsOneWidget);

    api.online = false;
    await _launch(tester, api, const ClassroomScreen());

    expect(find.text('WAEC'), findsOneWidget);
    await tester.tap(find.text('WAEC'));
    await tester.pumpAndSettle();
    expect(
      find.text('Chemistry'),
      findsOneWidget,
      reason:
          'a student could not even see the subject whose notes they '
          'had already downloaded',
    );
    await tester.tap(find.text('Chemistry'));
    await tester.pumpAndSettle();
    expect(find.text('Balancing equations'), findsOneWidget);
    expect(find.text('That did not load'), findsNothing);
  });

  testWidgets('a room NEVER opened online still fails honestly', (
    tester,
  ) async {
    /* Nothing to fall back on. Inventing an empty shelf would be worse than
       saying so — a student would conclude the tutor had written nothing. */
    final api = _Server()..online = false;
    await _launch(tester, api, const TheoryScreen());
    expect(find.text('WAEC'), findsNothing);
    expect(find.textContaining('No connection'), findsWidgets);
  });
}
