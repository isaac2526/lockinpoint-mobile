import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import 'theme.dart';

/// ===========================================================================
/// HOW RICH CONTENT IS DRAWN ON THE PHONE
///
/// This lived under features/practice, so only practice, search and review
/// used it. Everything ELSE that carries markup drew it as stripped plain
/// text — the classroom's notes ran the HTML through a regex that deleted
/// every tag, which turns H<sub>2</sub>O into H2O and x<sup>2</sup> into x2:
/// wrong in chemistry and wrong in every index. It belongs in the design
/// system, where any screen can reach it.
///
/// The server serves question text as sanitised HTML — a deliberately small
/// tag set (bold, italics, sup/sub, lists, tables) with LaTeX left INSIDE the
/// text between the site's three delimiters: \( \) inline, and \[ \] or $$ $$
/// for display maths. The website typesets those with KaTeX; this widget is
/// the mobile half of that same contract.
///
/// The trick: before parsing, every LaTeX span is rewritten into a private
/// `<tex>` element, and a tag extension renders each one with flutter_math.
/// That keeps inline maths INLINE — "solve \(x^2\) for x" stays one sentence —
/// which naive splitting into separate widgets would break.
///
/// A formula that fails to parse falls back to its written source. Wrong-
/// looking maths a student can still read beats a blank space.
/// ===========================================================================
class LipHtml extends StatelessWidget {
  const LipHtml(this.html, {super.key, this.baseStyle});

  final String html;
  final TextStyle? baseStyle;

  static final _display1 = RegExp(r'\\\[(.+?)\\\]', dotAll: true);
  static final _display2 = RegExp(r'\$\$(.+?)\$\$', dotAll: true);
  static final _inline = RegExp(r'\\\((.+?)\\\)', dotAll: true);

  /// THE FORMULA ARRIVES ALREADY ESCAPED, AND ESCAPING IT AGAIN BROKE IT.
  ///
  /// Question bodies are sanitised on the server, which turns `<` into
  /// `&lt;`. So an inequality written `\(a < b\)` reaches this widget as
  /// `\(a &lt; b\)`. `_escape` then made that `&amp;lt;`; the HTML parser
  /// decoded one level back to the literal text `&lt;`; and Math.tex was
  /// handed `a &lt; b`, which is not LaTeX. It failed, fell through to
  /// onErrorFallback, and PRINTED ITS OWN ESCAPED SOURCE on the screen.
  ///
  /// Every inequality, every `\langle`, every `a &amp; b` in a formula was
  /// affected — across Practice, Review, Search, Theory, Practical and the
  /// offline pack. Decoding first makes the round trip lossless: decode to
  /// real characters, escape once, let the parser decode once.
  static final _entity = RegExp(
    r'&(#x?[0-9a-fA-F]+|[a-zA-Z][a-zA-Z0-9]{1,31});',
  );

  static String decodeEntities(String s) => s.replaceAllMapped(_entity, (m) {
    final body = m[1]!;
    if (body.startsWith('#')) {
      final hex = body.startsWith('#x') || body.startsWith('#X');
      final digits = body.substring(hex ? 2 : 1);
      final code = int.tryParse(digits, radix: hex ? 16 : 10);
      /* A code point outside Unicode, or a control character, is left as
             written rather than turned into something unprintable. */
      if (code == null || code < 0x20 || code > 0x10FFFF) return m[0]!;
      return String.fromCharCode(code);
    }
    return switch (body.toLowerCase()) {
      'lt' => '<',
      'gt' => '>',
      'amp' => '&',
      'quot' => '"',
      'apos' => "'",
      'nbsp' => '\u00A0',
      'times' => '\u00D7',
      'minus' => '\u2212',
      'le' => '\u2264',
      'ge' => '\u2265',
      'ne' => '\u2260',
      // An entity this app does not know is left exactly as it was
      // written. Guessing would corrupt the formula silently.
      _ => m[0]!,
    };
  });

  /// LaTeX often contains `<` and `&`, which the HTML parser would eat. Each
  /// formula is decoded to real characters, then entity-escaped ONCE into its
  /// `<tex>` element, and decoded again on render.
  static String _escape(String tex) =>
      decodeEntities(tex)
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;');

  static String prepare(String raw) => raw
      .replaceAllMapped(_display1, (m) => '<tex d="1">${_escape(m[1]!)}</tex>')
      .replaceAllMapped(_display2, (m) => '<tex d="1">${_escape(m[1]!)}</tex>')
      .replaceAllMapped(_inline, (m) => '<tex>${_escape(m[1]!)}</tex>');

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final style = baseStyle ?? DefaultTextStyle.of(context).style;

    return Html(
      data: prepare(html),
      style: {
        'body': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          fontSize: FontSize(style.fontSize ?? 15),
          fontFamily: style.fontFamily,
          fontWeight: style.fontWeight,
          lineHeight: style.height != null ? LineHeight(style.height!) : null,
          color: style.color ?? c.text1,
        ),
        'p': Style(margin: Margins.only(bottom: 6)),
        'table': Style(border: Border.all(color: c.glassBorder)),
        'td': Style(
          padding: HtmlPaddings.all(6),
          border: Border.all(color: c.glassBorder),
        ),
        'th': Style(
          padding: HtmlPaddings.all(6),
          border: Border.all(color: c.glassBorder),
        ),
        'code': Style(backgroundColor: c.glassDeep, fontFamily: 'monospace'),
        'mark': Style(backgroundColor: c.accentSoft),
      },
      extensions: [
        TagExtension(
          tagsToExtend: const {'tex'},
          builder: (ec) {
            final src = ec.element?.text ?? '';
            final display = ec.attributes['d'] == '1';
            final math = Math.tex(
              src,
              mathStyle: display ? MathStyle.display : MathStyle.text,
              textStyle: TextStyle(
                fontSize: (style.fontSize ?? 15) + 1,
                color: style.color ?? c.text1,
              ),
              onErrorFallback: (_) => Text(src, style: style),
            );
            if (!display) return math;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: math,
              ),
            );
          },
        ),
      ],
    );
  }
}
