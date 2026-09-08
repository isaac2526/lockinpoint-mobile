import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/core/api.dart';
import 'package:lockinpoint/core/presence.dart';
import 'package:lockinpoint/design/rich_text.dart';
import 'package:lockinpoint/design/theme.dart';
import 'package:lockinpoint/features/classroom/classroom_screen.dart';

/// ===========================================================================
/// THE CLASSROOM IS A WALK, NOT A WALL.
///
/// It used to be one page: a strip of exam chips across the top and every
/// subject below them, so choosing WAEC and choosing Chemistry happened in the
/// same breath. Now it is three screens — which examination, which subject,
/// what is on the shelf — and these tests hold that shape, because the
/// temptation to collapse it back into one page for "fewer taps" is exactly
/// how it got that way.
///
/// The fourth test is the one that matters most: a note's body is HTML, and
/// it used to be run through a regex that deleted every tag. H<sub>2</sub>O
/// became H2O.
/// ===========================================================================

/// A classroom backend that answers from a fixed shelf and records the shape
/// of every request, so "the subject screen asked for THIS exam" is provable.
class _Classroom extends Fake implements Api {
  final List<Map<String, dynamic>> asked = [];

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    asked.add({'path': path, ...?query});
    if (query == null || query.isEmpty) {
      return {
        'ok': true,
        'exams': [
          {'slug': 'waec', 'name': 'WAEC'},
          {'slug': 'jamb', 'name': 'JAMB'},
        ],
      };
    }
    if (query.containsKey('exam')) {
      return {
        'ok': true,
        'subjects': [
          {'id': 's-chem', 'name': 'Chemistry'},
          {'id': 's-bio', 'name': 'Biology'},
        ],
      };
    }
    if (query.containsKey('subject')) {
      return {
        'ok': true,
        'notes': [
          {'id': 'n1', 'title': 'Acids and bases'},
        ],
        'videos': const [],
        'documents': [
          {'id': 'd1', 'title': 'Past paper 2019', 'url': '/api/doc/d1'},
        ],
      };
    }
    return {
      'ok': true,
      'note': {
        'id': 'n1',
        'title': 'Acids and bases',
        'body':
            '<p>Water is <b>H<sub>2</sub>O</b> and pH is '
            r'\(-\log_{10}[H^+]\).</p>',
      },
    };
  }
}

Future<_Classroom> _open(WidgetTester tester) async {
  final api = _Classroom();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [apiProvider.overrideWithValue(api)],
      child: MaterialApp(
        theme: LipTheme.light(),
        home: const ClassroomScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('it opens by asking which examination, and nothing else', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('Which examination room?'), findsOneWidget);
    expect(find.text('WAEC'), findsOneWidget);
    expect(find.text('JAMB'), findsOneWidget);
    // No subject is on this screen. That is the whole point of the change.
    expect(find.text('Chemistry'), findsNothing);
  });

  testWidgets('choosing an examination opens its own subject screen', (
    tester,
  ) async {
    final api = await _open(tester);
    await tester.tap(find.text('WAEC'));
    await tester.pumpAndSettle();

    expect(find.text('Which subject?'), findsOneWidget);
    expect(find.text('Chemistry'), findsOneWidget);
    // It asked for the exam that was tapped, not the first in the list.
    expect(api.asked.last['exam'], 'waec');
  });

  testWidgets('choosing a subject opens the shelf, and the file is gated', (
    tester,
  ) async {
    final api = await _open(tester);
    await tester.tap(find.text('JAMB'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chemistry'));
    await tester.pumpAndSettle();

    // LipLabel upper-cases its own text, so the section headings read as
    // NOTES TO READ on screen.
    expect(find.text('NOTES TO READ'), findsOneWidget);
    expect(find.text('Acids and bases'), findsOneWidget);
    expect(find.text('FILES TO KEEP'), findsOneWidget);
    /* The document row says what the gate does. The URL is a path on the
       platform's own domain, never a public storage link — the old one
       pointed at a bucket that does not exist and would have handed out an
       unwatermarked copy if it had. */
    expect(find.text('Opens with your name on every page'), findsOneWidget);
    expect(api.asked.last['subject'], 's-chem');
  });

  testWidgets("a note's markup is rendered, not deleted", (tester) async {
    await _open(tester);
    await tester.tap(find.text('WAEC'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chemistry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Acids and bases'));
    await tester.pumpAndSettle();

    /* The body reaches the HTML renderer intact. Before this, it went through
       a regex that stripped every tag: H<sub>2</sub>O arrived as "H2O", which
       is a different molecule, and the formula was thrown away entirely. */
    final html = tester.widget<LipHtml>(find.byType(LipHtml));
    expect(html.html, contains('<sub>2</sub>'));
    expect(html.html, contains(r'\(-\log_{10}[H^+]\)'));
  });

  test('the heartbeat is silent inside its quiet window', () async {
    final api = _Counter();
    final p = Presence(api);
    await p.touch();
    await p.touch();
    await p.touch();
    // Three returns to the app in the same minute is one visit, not three
    // requests. A ping per app switch is how a heartbeat becomes a bill.
    expect(api.pings, 1);
  });

  test('the heartbeat can be forced past the window', () async {
    final api = _Counter();
    final p = Presence(api);
    await p.touch();
    await p.touch(force: true);
    expect(api.pings, 2);
  });

  test('a failed heartbeat is swallowed and retried next time', () async {
    var calls = 0;
    final p = Presence(_Failing(() => calls++));
    await p.touch(); // throws inside, must not escape
    await p.touch(force: true);
    expect(calls, 2);
  });

  test('a formula is handed to the maths renderer, not to the HTML parser', () {
    // LipHtml.prepare is the seam: every delimiter becomes a <tex> element so
    // inline maths stays inline inside its sentence.
    final out = LipHtml.prepare(r'Solve \(x^2\) then \[y = mx + c\]');
    expect(out, contains('<tex>x^2</tex>'));
    expect(out, contains('<tex d="1">y = mx + c</tex>'));
  });
}

/// ===========================================================================
/// PRESENCE · a heartbeat that is cheap or it is not shipped.
/// ===========================================================================
class _Counter extends Fake implements Api {
  int pings = 0;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    if (path == '/api/session') pings++;
    return {'ok': true, 'signedIn': true};
  }
}

/// A backend that always refuses. A missed heartbeat must cost the student
/// nothing, and must not stop the next one being sent.
class _Failing extends Fake implements Api {
  _Failing(this.onCall);
  final void Function() onCall;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    onCall();
    throw ApiFailure('no network');
  }
}
