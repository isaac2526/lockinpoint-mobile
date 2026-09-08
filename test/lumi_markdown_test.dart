import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/design/lumi_markdown.dart';

/// ===========================================================================
/// LUMI'S HANDWRITING ON THE PHONE.
///
/// The app drew her answers as SelectableText, so a student read literal
/// **bold**, literal ## Step 1, and every formula as raw \frac{-b}{2a}
/// source. These hold the conversion that fixed it, and they are the same
/// cases the website's own tests hold — the two must not drift, because a
/// student reads the same answer on both.
/// ===========================================================================
void main() {
  test('a multi-line display equation survives intact', () {
    final html = lumiToHtml(
      'The formula is:\n\\[\n  x = \\frac{-b}{2a}\n\\]\nUse it.',
    );
    expect(html, contains(r'x = \frac{-b}{2a}'));
    expect(html, contains('The formula is:'));
    expect(html, contains('Use it.'));
  });

  test(r'$…$ inline maths becomes a delimiter LipHtml renders', () {
    final html = lumiToHtml(
      r'Recall that $x^2 + y^2 = r^2$ describes a circle.',
    );
    expect(html, contains(r'\(x^2 + y^2 = r^2\)'));
  });

  test('a price is not mathematics', () {
    final html = lumiToHtml(r'The book costs $5 and the pen costs $2.');
    expect(html.contains(r'\('), isFalse);
    expect(html, contains(r'$5'));
  });

  test('a less-than inside a REAL formula survives untouched', () {
    // Lifted out before the prose is escaped and put back afterwards, so what
    // reaches the renderer is the formula exactly as Lumi wrote it.
    final html = lumiToHtml(r'We need \(x < 5\) here.');
    expect(html, contains(r'\(x < 5\)'));
    expect(html, contains('We need'));
  });

  test(r'$x < 5$ is escaped rather than guessed at', () {
    /* Deliberately NOT treated as mathematics: a bare dollar run with no
       backslash, caret or underscore is as likely to be "costs $x, under 5$"
       as it is to be algebra, and inventing a formula out of a price is worse
       than leaving it alone. What matters is that it can never become a tag.
       The website's rules agree, and these two must not drift — a student
       reads the same answer on both. */
    final html = lumiToHtml(r'We need $x < 5$ here.');
    expect(html, contains('&lt;'));
    expect(RegExp(r'<\s*5').hasMatch(html), isFalse);
  });

  test('markup in the prose is escaped, not rendered', () {
    final html = lumiToHtml('Careful with <script>alert(1)</script> tags.');
    expect(html.contains('<script>'), isFalse);
    expect(html, contains('&lt;script&gt;'));
  });

  test('headings, bold, italics and code', () {
    final html = lumiToHtml(
      '## Osmosis\n**Key idea:** water moves *down* a gradient. Use `n=PV/RT`.',
    );
    expect(html, contains('<b>Osmosis</b>'));
    expect(html, contains('<b>Key idea:</b>'));
    expect(html, contains('<i>down</i>'));
    expect(html, contains('<code>n=PV/RT</code>'));
  });

  test('snake_case and 3*4 are not emphasis', () {
    final html = lumiToHtml('The value of first_name_field is 3*4 today.');
    expect(html.contains('<i>'), isFalse);
  });

  test('lists close themselves', () {
    final html = lumiToHtml(
      'Steps:\n1. Weigh it\n2. Heat it\n\nNotes:\n- dry first\n- then weigh',
    );
    expect('<ol>'.allMatches(html).length, 1);
    expect('</ol>'.allMatches(html).length, 1);
    expect('<ul>'.allMatches(html).length, 1);
    expect('</ul>'.allMatches(html).length, 1);
  });

  test('an unclosed fence still closes its tag', () {
    final html = lumiToHtml('```\nleft open');
    expect('<pre>'.allMatches(html).length, 1);
    expect('</pre>'.allMatches(html).length, 1);
  });

  test('a link keeps its words and loses its destination', () {
    final html = lumiToHtml('See [the notes](https://example.com/x) for more.');
    expect(html, contains('the notes'));
    expect(html.contains('example.com'), isFalse);
  });

  test('machine blocks never reach the student', () {
    expect(lumiToHtml('Hello genui{card{a}} there').contains('genui'), isFalse);
  });

  test('empty in, empty out', () {
    expect(lumiToHtml(''), '');
  });

  test('plain text strips the notation for copying into a notebook', () {
    final t = lumiToPlain('## Osmosis\n**Key:** \\(x^2\\) matters.');
    expect(t.contains('**'), isFalse);
    expect(t.contains('##'), isFalse);
    expect(t.contains(r'\('), isFalse);
    expect(t, contains('Osmosis'));
  });
}
