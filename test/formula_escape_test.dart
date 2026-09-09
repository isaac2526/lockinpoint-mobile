import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/design/rich_text.dart';

/// ===========================================================================
/// A FORMULA SURVIVES THE ROUND TRIP.
///
/// Question bodies are sanitised on the server, which turns `<` into `&lt;`.
/// LipHtml then escaped that AGAIN into `&amp;lt;`; the HTML parser decoded
/// one level back to the literal text `&lt;`; and the maths renderer was
/// handed `a &lt; b`, which is not LaTeX. It failed and printed its own
/// escaped source on the screen.
///
/// Every inequality in the bank was affected — Practice, Review, Search,
/// Theory, Practical and the offline pack.
/// ===========================================================================
void main() {
  group('entity decoding', () {
    test('the sanitiser\'s escapes come back as real characters', () {
      expect(LipHtml.decodeEntities('a &lt; b'), 'a < b');
      expect(LipHtml.decodeEntities('a &gt; b'), 'a > b');
      expect(LipHtml.decodeEntities('P &amp; Q'), 'P & Q');
    });

    test('numeric and hex entities decode', () {
      expect(LipHtml.decodeEntities('&#60;'), '<');
      expect(LipHtml.decodeEntities('&#x3C;'), '<');
      expect(LipHtml.decodeEntities('&#8804;'), '≤');
    });

    test('an entity this app does not know is left exactly as written', () {
      // Guessing would corrupt a formula silently, which is worse than
      // showing it unchanged.
      expect(LipHtml.decodeEntities('&fnof;'), '&fnof;');
      expect(LipHtml.decodeEntities('AT&T'), 'AT&T');
      expect(LipHtml.decodeEntities('&notanentity;'), '&notanentity;');
    });

    test('a control character is never produced', () {
      expect(LipHtml.decodeEntities('&#0;'), '&#0;');
      expect(LipHtml.decodeEntities('&#x1FFFFF;'), '&#x1FFFFF;');
    });
  });

  group('prepare', () {
    String texOf(String prepared) {
      final m = RegExp(
        r'<tex[^>]*>(.*?)</tex>',
        dotAll: true,
      ).firstMatch(prepared);
      return m?.group(1) ?? '';
    }

    test('an inequality reaches the renderer as LaTeX, not as its source', () {
      // What the server actually sends after sanitising \(a < b\).
      final out = LipHtml.prepare(r'Given \(a &lt; b\), find x.');
      // Escaped exactly once: the parser decodes this back to `a < b`.
      expect(texOf(out), 'a &lt; b');
      expect(
        out.contains('&amp;lt;'),
        isFalse,
        reason: 'double-escaped — the renderer would print the source',
      );
    });

    test('an ampersand inside an alignment survives', () {
      final out = LipHtml.prepare(r'\[x &amp;= 1\]');
      expect(texOf(out), 'x &amp;= 1');
      expect(out.contains('&amp;amp;'), isFalse);
    });

    test('display and inline maths are told apart', () {
      expect(LipHtml.prepare(r'\[x\]').contains('d="1"'), isTrue);
      expect(LipHtml.prepare(r'$$x$$').contains('d="1"'), isTrue);
      expect(LipHtml.prepare(r'\(x\)').contains('d="1"'), isFalse);
    });

    test('a formula with no entities is untouched', () {
      expect(texOf(LipHtml.prepare(r'\(x^2 + y^2 = r^2\)')), 'x^2 + y^2 = r^2');
    });

    test('surrounding markup is left alone', () {
      // Only the formula is rewritten; the sanitised HTML around it must
      // still be HTML when it reaches the parser.
      final out = LipHtml.prepare(r'H<sub>2</sub>O and \(a &lt; b\)');
      expect(out.contains('<sub>2</sub>'), isTrue);
    });
  });
}
