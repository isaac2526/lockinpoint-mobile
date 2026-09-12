import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/core/vault/vault_db.dart';
import 'package:lockinpoint/design/rich_text.dart';
import 'package:lockinpoint/design/theme.dart';
import 'package:lockinpoint/features/practice/practice_repository.dart';

/// ===========================================================================
/// REAL QUESTIONS, WITH REAL FORMATTING, ALL THE WAY TO THE PIXELS
///
/// Not "does LipHtml compile". These are question bodies of the exact shape
/// the bank holds — chemistry with subscripts, algebra with LaTeX, a
/// comprehension passage with italics, a list of options — checked for what
/// actually reaches the widget tree.
///
/// THE DEFECT THIS PROVES GONE. `ServedQuestion.question` meant two different
/// things depending on where it came from. /api/attempts sanitises in place,
/// so ONLINE it was the HTML. /api/mobile/pack sends `question` as readable
/// plain text and `question_html` as the markup — and the app read the plain
/// one. Both go to the same LipHtml widget, so the very same question was
/// formatted online and flat offline. And the vault had nowhere to put the
/// markup at all: its table had no column for it.
/// ===========================================================================

/// The real shape of a chemistry question as the bank stores it.
const kChem =
    'Which of the following is the formula of <b>tetraoxosulphate(VI)</b> '
    'acid?<br/>Consider H<sub>2</sub>SO<sub>4</sub> and its <i>conjugate '
    'base</i>.';

/// Algebra with both maths delimiters the site uses.
const kAlgebra =
    r'Solve \(x^2 - 5x + 6 = 0\) and show that '
    r'\[x = \frac{-b \pm \sqrt{b^2-4ac}}{2a}\]';

/// The inequality that used to print its own escaped source on screen.
const kInequality = r'Given that \(a &lt; b\), which is true?';

const kList =
    '<p>Consider these:</p><ul><li>Sodium</li><li>Potassium</li>'
    '<li><u>Calcium</u></li></ul>';

/// Every widget of type [T] in the tree, so a test can look at what was drawn
/// rather than at what was passed in.
List<T> drawn<T extends Widget>(WidgetTester t) =>
    t.widgetList<T>(find.byType(T)).toList();

Future<void> render(WidgetTester tester, String html) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: LipTheme.light(),
      home: Scaffold(body: SingleChildScrollView(child: LipHtml(html))),
    ),
  );
  await tester.pump();
}

void main() {
  group('what the student actually sees', () {
    testWidgets('bold, italic, underline and subscripts survive as STYLE', (
      tester,
    ) async {
      await render(tester, kChem);

      // The tags themselves must never be on screen.
      expect(find.textContaining('<b>'), findsNothing);
      expect(find.textContaining('<sub>'), findsNothing);
      expect(find.textContaining('&lt;'), findsNothing);

      /* flutter_html draws one RichText per block, with the styling in the
         SPANS. Walking them is the only honest way to assert that "bold"
         reached the screen as weight rather than as characters. */
      final styles = <TextStyle>[];
      void walk(InlineSpan s) {
        if (s is TextSpan) {
          if (s.style != null) styles.add(s.style!);
          for (final c in s.children ?? const <InlineSpan>[]) {
            walk(c);
          }
        }
      }

      for (final r in drawn<RichText>(tester)) {
        walk(r.text);
      }

      expect(styles, isNotEmpty, reason: 'nothing was drawn at all');
      expect(
        styles.any((s) => s.fontWeight == FontWeight.bold),
        isTrue,
        reason: 'tetraoxosulphate(VI) was written <b> and came out unbolded',
      );
      expect(
        styles.any((s) => s.fontStyle == FontStyle.italic),
        isTrue,
        reason: 'conjugate base was written <i> and came out upright',
      );

      // The whole text is present, subscripts and all.
      final all = drawn<RichText>(tester)
          .map((r) => r.text.toPlainText())
          .join(' ');
      expect(all, contains('tetraoxosulphate(VI)'));
      expect(all, contains('2'), reason: 'the subscripts vanished');
      expect(all, contains('conjugate base'));
    });

    testWidgets('underline is drawn as a line, not as the letters "u"', (
      tester,
    ) async {
      await render(tester, kList);
      final styles = <TextStyle>[];
      void walk(InlineSpan s) {
        if (s is TextSpan) {
          if (s.style != null) styles.add(s.style!);
          for (final c in s.children ?? const <InlineSpan>[]) {
            walk(c);
          }
        }
      }

      for (final r in drawn<RichText>(tester)) {
        walk(r.text);
      }
      expect(
        styles.any((s) => s.decoration == TextDecoration.underline),
        isTrue,
        reason: 'Calcium was written <u> and came out plain',
      );
    });

    testWidgets('a list renders its items, and not its tags', (tester) async {
      await render(tester, kList);
      final all = drawn<RichText>(tester)
          .map((r) => r.text.toPlainText())
          .join(' ');
      for (final item in ['Sodium', 'Potassium', 'Calcium']) {
        expect(all, contains(item));
      }
      expect(all, isNot(contains('<li>')));
      expect(all, isNot(contains('<ul>')));
    });

    testWidgets('mathematics is typeset, not printed as LaTeX', (tester) async {
      await render(tester, kAlgebra);

      /* THE POINT. If Math.tex never got built, the student is reading
         "\\frac{-b \\pm \\sqrt{b^2-4ac}}{2a}" as literal characters. */
      expect(
        find.byType(Math),
        findsNWidgets(2),
        reason: 'one inline formula and one display formula were expected',
      );

      final all = drawn<RichText>(tester)
          .map((r) => r.text.toPlainText())
          .join(' ');
      expect(all, isNot(contains(r'\frac')));
      expect(all, isNot(contains(r'\[')));
      expect(all, isNot(contains(r'\(')));
    });

    testWidgets('an inequality does not print its own escaped source', (
      tester,
    ) async {
      /* The formula arrives already escaped by the server, so `\(a < b\)`
         reaches this widget as `\(a &lt; b\)`. Escaping it again made
         `&amp;lt;`, which Math.tex could not parse — it fell through to the
         error fallback and PRINTED the escaped source on the screen. */
      await render(tester, kInequality);
      expect(find.byType(Math), findsOneWidget);
      final all = drawn<RichText>(tester)
          .map((r) => r.text.toPlainText())
          .join(' ');
      expect(all, isNot(contains('&lt;')));
      expect(all, isNot(contains('&amp;')));
    });

    testWidgets('an image inside question media is drawn', (tester) async {
      /* Images do not travel in the HTML — the sanitiser strips <img> on
         purpose, because question text comes from five importers and student
         submissions. They travel in `media`, and that is the path to check. */
      final q = ServedQuestion.fromJson(const {
        'id': 'q1',
        'question': 'Study the diagram.',
        'options': ['A', 'B'],
        'letters': ['A', 'B'],
        'media': {
          'stem': {'type': 'image', 'url': 'https://example.com/d.png'},
        },
      });
      expect(q.mediaUrl('stem'), 'https://example.com/d.png');
      expect(q.mediaUrl('nothing'), isNull);
    });
  });

  group('the same question, online and offline', () {
    test('the pack sends BOTH, and the markup is the one that is used', () {
      /* This is the whole defect. /api/mobile/pack sends `question` as
         readable plain text (for search and previews) and `question_html` as
         the markup. The app read the plain one. */
      final q = ServedQuestion.fromJson({
        'id': 'q1',
        'question': 'Which is the formula of tetraoxosulphate(VI) acid?',
        'question_html': kChem,
        'options': const ['H2SO4', 'HCl'],
        'options_html': const ['H<sub>2</sub>SO<sub>4</sub>', '<b>HCl</b>'],
        'letters': const ['A', 'B'],
        'explanation': 'It is H2SO4.',
        'explanation_html': 'It is <b>H<sub>2</sub>SO<sub>4</sub></b>.',
      });

      expect(q.question, kChem);
      expect(q.options.first, contains('<sub>'));
      expect(q.explanation, contains('<b>'));
    });

    test('a route that sanitises in place is not broken by the preference', () {
      // /api/attempts sends ONLY `question`, already sanitised to HTML. The
      // fallback must not turn that into nothing.
      final q = ServedQuestion.fromJson({
        'id': 'q1',
        'question': kChem,
        'options': const ['<b>A</b>'],
        'letters': const ['A'],
      });
      expect(q.question, kChem);
      expect(q.options.first, '<b>A</b>');
    });
  });

  group('the vault keeps the markup now', () {
    late VaultDb db;
    setUp(() => db = VaultDb.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('a downloaded question comes back formatted', () async {
      await db.savePack(
        pack: const {
          'subjectId': 's1',
          'subjectName': 'Chemistry',
          'examSlug': 'waec',
          'examShort': 'WAEC',
        },
        questions: [
          {
            'id': 'q1',
            'question': 'Which is the formula of tetraoxosulphate(VI) acid?',
            'question_html': kChem,
            'options': const ['H2SO4'],
            'options_html': const ['H<sub>2</sub>SO<sub>4</sub>'],
            'letters': const ['A'],
            'answer': 'A',
            'explanation': 'It is H2SO4.',
            'explanation_html': 'It is <b>H<sub>2</sub>SO<sub>4</sub></b>.',
          },
        ],
        passages: const [],
      );

      final rows = await db.questionsFor('s1');
      expect(rows, hasLength(1));
      expect(rows.first.questionHtml, kChem);
      expect(rows.first.optionsHtmlJson, contains('<sub>'));
      expect(rows.first.explanationHtml, contains('<b>'));

      // And the READABLE text is still kept beside it — previews and search
      // want it, and it is the fallback for packs from an older build.
      expect(rows.first.question, isNot(contains('<b>')));
    });

    test('a pack from an older build still opens, unformatted', () async {
      // No *_html keys at all, exactly as the previous version stored them.
      await db.savePack(
        pack: const {'subjectId': 's2', 'subjectName': 'Physics'},
        questions: [
          {
            'id': 'q2',
            'question': 'Define momentum.',
            'options': const ['p = mv'],
            'letters': const ['A'],
          },
        ],
        passages: const [],
      );
      final rows = await db.questionsFor('s2');
      expect(rows.first.questionHtml, isNull);
      expect(rows.first.question, 'Define momentum.');
    });
  });
}
