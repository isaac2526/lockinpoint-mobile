import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/core/api.dart';
import 'package:lockinpoint/core/json.dart';
import 'package:lockinpoint/design/broke.dart';

/// ===========================================================================
/// A STUDENT NEVER READS A DART EXCEPTION.
///
/// The owner did, on his own activities page:
///
///     Type int is not a subtype of type string in type cast
///
/// Seventeen screens rendered `message: '$e'` straight into their error card,
/// and five more spelled the same thing out longhand. Every one is gone; these
/// tests are what stops them coming back.
/// ===========================================================================
void main() {
  group('humanError', () {
    test('the exact class of error he saw never reaches the screen', () {
      // What a bad cast actually throws.
      Object thrown;
      try {
        // ignore: unnecessary_cast
        thrown = (12 as Object) as String;
      } catch (e) {
        thrown = e;
      }
      final shown = humanError(thrown, doing: 'load your activities');
      expect(
        shown,
        "We couldn't load your activities right now. Please try again.",
      );
      expect(shown, isNot(contains('subtype')));
      expect(shown, isNot(contains('int')));
      expect(shown, isNot(contains('cast')));
    });

    test("an ApiFailure's message was written for a person, so it passes", () {
      expect(
        humanError(ApiFailure('No connection. Try again in a moment.')),
        'No connection. Try again in a moment.',
      );
    });

    test('the server sentence wins over the generic one', () {
      expect(
        humanError(
          ApiFailure('Activate your account to open theory papers.'),
          doing: 'open this paper',
        ),
        'Activate your account to open theory papers.',
      );
    });

    test('nothing technical survives, whatever is thrown', () {
      final nasties = <Object>[
        StateError('Bad state: No element'),
        TypeError(),
        FormatException('Unexpected character (at character 1)'),
        ArgumentError.notNull('subjectId'),
        Exception('PostgrestException(message: column x does not exist)'),
      ];
      for (final e in nasties) {
        final shown = humanError(e, doing: 'load your results');
        expect(
          shown,
          "We couldn't load your results right now. Please try again.",
        );
        for (final leak in [
          'Exception',
          'Error',
          'Postgrest',
          'column',
          'null',
        ]) {
          expect(shown.contains(leak), isFalse, reason: '$leak leaked from $e');
        }
      }
    });

    test('a null failure is still a sentence', () {
      expect(
        humanError(null, doing: 'do that'),
        "We couldn't do that right now. Please try again.",
      );
    });
  });

  group('describeFailure', () {
    test('keeps the technical truth for the console', () {
      // The detail must NOT be lost — it is what a developer debugs from.
      final d = describeFailure(StateError('No element'));
      expect(d, contains('No element'));
    });

    test("an ApiFailure's detail rides along", () {
      final d = describeFailure(
        ApiFailure('Not signed in.', detail: 'GET /api/mobile/activity → 401'),
      );
      expect(d, contains('401'));
      expect(d, contains('/api/mobile/activity'));
    });

    test('a stack trace is appended when there is one', () {
      final d = describeFailure(StateError('x'), StackTrace.current);
      expect(d.split('\n').length, greaterThan(1));
    });
  });

  testWidgets('the build-failure screen says something a student can act on', (
    tester,
  ) async {
    /* Flutter's default here prints the exception on a red background, and in
       a release build shows a bare grey rectangle that says nothing at all.
       This is what ErrorWidget.builder installs instead — it cannot recover
       the screen, but it can tell the truth in a sentence.

       It is tested as a WIDGET rather than by swapping ErrorWidget.builder,
       because flutter_test asserts that builder is never reassigned. */
    await tester.pumpWidget(const MaterialApp(home: SomethingBroke()));

    expect(find.text('This part did not load'), findsOneWidget);
    expect(find.textContaining('Tutor Bello'), findsOneWidget);
    // Nothing technical, and nothing that needs a theme to render.
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.textContaining('subtype'), findsNothing);
  });

  testWidgets('it renders with no theme, no providers and no network', (
    tester,
  ) async {
    // It has to survive being shown when whatever it replaced could not be
    // built — including when the theme itself is the thing that failed.
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SomethingBroke(),
      ),
    );
    expect(find.text('This part did not load'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
