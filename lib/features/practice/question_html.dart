import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../design/theme.dart';

/// ===========================================================================
/// HOW QUESTION CONTENT IS DRAWN ON THE PHONE
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

  /// LaTeX often contains `<` and `&`, which the HTML parser would eat. Each
  /// formula is entity-escaped into its `<tex>` element and decoded on render.
  static String _escape(String tex) => tex
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
