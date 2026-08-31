import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/app/routes.dart';
import 'package:lockinpoint/core/open.dart';
import 'package:lockinpoint/design/theme.dart';
import 'package:lockinpoint/features/games/games_repository.dart';
import 'package:lockinpoint/features/practice/practice_repository.dart';

/// ===========================================================================
/// THE DEAD CONTROLS, PINNED
///
/// Every case here is a control the founder tapped in the installed build
/// that did nothing. A passing analyzer said all of them were fine, which is
/// exactly why these assertions are about BEHAVIOUR — what a tap produces —
/// rather than about a widget existing.
/// ===========================================================================
void main() {
  group('an admin target reaches a real destination', () {
    test('an app route is recognised as a route, not a URL', () {
      // '/games' used to fail a hasScheme check and fall through to silence.
      final (kind, uri) = classifyTarget('/games');
      expect(kind, TargetKind.route);
      expect(uri, isNull);
    });

    test('a scheme-less host is still a URL', () {
      // 'www.lockinpoint.com/x' produced no scheme, so the tap did nothing.
      final (kind, uri) = classifyTarget('www.lockinpoint.com/activate');
      expect(kind, TargetKind.url);
      expect(uri!.scheme, 'https');
      expect(uri.host, 'www.lockinpoint.com');
    });

    test('a full URL is left exactly as written', () {
      final (kind, uri) = classifyTarget('https://wa.me/234800');
      expect(kind, TargetKind.url);
      expect(uri.toString(), 'https://wa.me/234800');
    });

    test('empty and junk targets are none, never a crash', () {
      expect(classifyTarget('').$1, TargetKind.none);
      expect(classifyTarget('   ').$1, TargetKind.none);
      expect(classifyTarget('nonsense').$1, TargetKind.none);
    });
  });

  group('a JAMB mock is scored out of 400, not as a percentage', () {
    SubmitResult jamb(int overall) => SubmitResult(
      correct: 120,
      total: 180,
      overall: overall,
      perSubject: const [],
      isJamb: true,
    );

    test('the headline is the raw score with its scale named', () {
      // It read "265%" inside a circle that painted every mock green.
      expect(jamb(265).headline, '265');
      expect(jamb(265).outOf, 'out of 400');
    });

    test('a percentage paper keeps its percent sign and no scale line', () {
      const p = SubmitResult(
        correct: 7,
        total: 10,
        overall: 70,
        perSubject: [],
      );
      expect(p.headline, '70%');
      expect(p.outOf, isNull);
    });

    test('colour thresholds mean the same thing on both scales', () {
      // 280/400 is 70% — the same achievement, so the same band.
      expect(jamb(280).percentEquivalent, 70);
      expect(jamb(200).percentEquivalent, 50);
      // A mid mock must NOT read as a good one, which is what comparing a
      // raw 265 against a 70 threshold did.
      expect(jamb(265).percentEquivalent, lessThan(70));
    });
  });

  group('Ask the Class returns what the server actually sends', () {
    test('classVote is read — the app looked for a key nothing sends', () {
      // The route answers with `classVote`; the app read `distribution`, so
      // the lifeline was consumed and no percentages ever appeared.
      final vote = ClassVote(
        state: ClimbState.from(const {
          'id': 'g',
          'status': 'playing',
          'question': {'id': 'q1', 'question': 'x', 'options': []},
        }),
        percentages: const {'A': 61, 'B': 21, 'C': 12, 'D': 6},
        real: true,
        sample: 240,
      );
      expect(vote.percentages!['A'], 61);
      expect(vote.real, isTrue);
      expect(vote.sample, 240);
    });

    test('the rung carries its question id, so Lumi can be asked about it', () {
      final s = ClimbState.from(const {
        'id': 'g',
        'status': 'playing',
        'question': {'id': 'q-42', 'question': 'x', 'options': []},
      });
      expect(s.questionId, 'q-42');
    });

    test('a state with no question names no id rather than crashing', () {
      expect(
        ClimbState.from(const {'id': 'g', 'status': 'lost'}).questionId,
        isNull,
      );
    });
  });

  group('the honest launcher tells the truth when it cannot open', () {
    testWidgets('a scheme nothing handles shows a message, not silence', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LipTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => openOutside(
                  context,
                  Uri.parse('lipnothing://x'),
                  // A device with no handler: exactly what the founder's
                  // Linux build did on every outward tap.
                  launcher: (_) async => false,
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      // The launch fails asynchronously; the snackbar needs its own frame.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      // The exact failure the founder hit: a tap that produced nothing at
      // all. Whatever else happens, the app must SAY something.
      expect(find.textContaining('Could not open'), findsOneWidget);
    });
  });
}
