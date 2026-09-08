/// ===========================================================================
/// LUMI'S HANDWRITING, ON THE PHONE.
///
/// Lumi writes markdown with LaTeX inside it. The app rendered that as
/// SelectableText — so a student read literal `**bold**`, literal `## Step 1`,
/// and every formula as raw `\frac{-b}{2a}` source. The website had exactly
/// the same fault and the same cause: the answer is not plain text.
///
/// Rather than build a second renderer, this turns the markdown into the same
/// small HTML that [LipHtml] already draws — which means the LaTeX is handed
/// to flutter_math by the one code path that has always done it, and bold,
/// lists and tables come along for free.
///
/// THE ORDER IS THE WHOLE TRICK, and it is the order lib/rich-text.ts uses on
/// the server for question content:
///
///   1. lift every formula out into a placeholder, BEFORE anything else
///   2. escape the prose
///   3. mark up the prose
///   4. put the formulae back, untouched
///
/// Step 1 first, because a `<` inside a formula is not a tag and a `*` inside
/// one is not emphasis. Step 4 last, because nothing after it may touch them.
///
/// Pure, and therefore tested — these rules are wrong in ways that are only
/// visible in a screenshot.
/// ===========================================================================
library;

/// Longest delimiters first: `$$…$$` must never be read as two `$…$`.
final _mathBlocks = <RegExp>[
  RegExp(r'\$\$[\s\S]*?\$\$'),
  RegExp(r'\\\[[\s\S]*?\\\]'),
  RegExp(
    r'\\begin\{(equation\*?|align\*?|aligned|gather\*?|array|cases|matrix|[bpvBV]matrix|split)\}[\s\S]*?\\end\{\1\}',
  ),
  RegExp(r'\\\([\s\S]*?\\\)'),
];

/// `$…$` is deliberately last and deliberately fussy. A single dollar is also
/// money — "it costs $5" must not become mathematics — so a run only counts if
/// it carries something no price ever does.
final _dollar = RegExp(r'\$([^$\n]{1,200})\$');
final _looksMathematical = RegExp(r'[\\^_]');

final _fence = RegExp(r'^\s*```');
final _rule = RegExp(r'^(-{3,}|_{3,}|\*{3,})$');
final _heading = RegExp(r'^(#{1,6})\s+(.*)$');
final _quote = RegExp(r'^&gt;\s?');
final _bullet = RegExp(r'^[*\-+]\s+(.*)$');
final _numbered = RegExp(r'^(\d{1,3})[.)]\s+(.*)$');
final _machine = RegExp(r'genui\{[\s\S]*?\}\}?');

String _escape(String t) =>
    t.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

String _inline(String t) => t
    // `code` first: nothing inside it is interpreted further.
    .replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => '<code>${m[1]}</code>')
    .replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (m) => '<b>${m[1]}</b>')
    .replaceAllMapped(RegExp(r'__([^_]+)__'), (m) => '<b>${m[1]}</b>')
    // Single * and _ for italics, but never mid-word: snake_case_names and
    // 3*4 are not emphasis.
    .replaceAllMapped(
      RegExp(r'(^|[\s(])\*([^*\n]+)\*(?=[\s).,;:!?]|$)'),
      (m) => '${m[1]}<i>${m[2]}</i>',
    )
    .replaceAllMapped(
      RegExp(r'(^|[\s(])_([^_\n]+)_(?=[\s).,;:!?]|$)'),
      (m) => '${m[1]}<i>${m[2]}</i>',
    )
    // A markdown link keeps its words and loses its destination. Lumi has no
    // business sending a student to an arbitrary URL from inside an answer.
    .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => '${m[1]}');

/// Lumi's answer as the small HTML [LipHtml] draws.
String lumiToHtml(String raw) {
  if (raw.isEmpty) return '';

  // Machine blocks are teaching aids that leaked; students never see them.
  var work = raw.replaceAll(_machine, '');

  // 1 · lift the mathematics out
  final math = <String>[];
  String keep(String m) {
    math.add(m);
    return '@@LUMIMATH${math.length - 1}@@';
  }

  for (final re in _mathBlocks) {
    work = work.replaceAllMapped(re, (m) => keep(m[0]!));
  }
  work = work.replaceAllMapped(
    _dollar,
    (m) => _looksMathematical.hasMatch(m[1]!) ? keep('\\(${m[1]}\\)') : m[0]!,
  );

  // 2 · escape the prose
  work = _escape(work);

  // 3 · markdown, line by line, so a list and a heading can see their own line
  final out = StringBuffer();
  String? list;
  var fenced = false;
  void closeList() {
    if (list != null) {
      out.write('</$list>');
      list = null;
    }
  }

  for (final line in work.replaceAll('\r\n', '\n').split('\n')) {
    if (_fence.hasMatch(line)) {
      closeList();
      out.write(fenced ? '</pre>' : '<pre>');
      fenced = !fenced;
      continue;
    }
    if (fenced) {
      out.write('$line\n');
      continue;
    }

    final t = line.trim();
    if (t.isEmpty) {
      closeList();
      continue;
    }
    if (_rule.hasMatch(t)) {
      closeList();
      out.write('<hr />');
      continue;
    }

    final h = _heading.firstMatch(t);
    if (h != null) {
      closeList();
      out.write('<p><b>${_inline(h[2]!)}</b></p>');
      continue;
    }
    if (_quote.hasMatch(t)) {
      closeList();
      out.write(
        '<blockquote>${_inline(t.replaceFirst(_quote, ''))}</blockquote>',
      );
      continue;
    }

    final b = _bullet.firstMatch(t);
    if (b != null) {
      if (list != 'ul') {
        closeList();
        out.write('<ul>');
        list = 'ul';
      }
      out.write('<li>${_inline(b[1]!)}</li>');
      continue;
    }

    final n = _numbered.firstMatch(t);
    if (n != null) {
      if (list != 'ol') {
        closeList();
        out.write('<ol>');
        list = 'ol';
      }
      out.write('<li>${_inline(n[2]!)}</li>');
      continue;
    }

    closeList();
    out.write('<p>${_inline(t)}</p>');
  }
  closeList();
  if (fenced) out.write('</pre>');

  // 4 · the formulae go back exactly as written
  return out.toString().replaceAllMapped(
    RegExp(r'@@LUMIMATH(\d+)@@'),
    (m) => math[int.parse(m[1]!)],
  );
}

/// The same answer as plain text — for copying into a notebook, and anywhere
/// markup would be wrong.
String lumiToPlain(String raw) => raw
    .replaceAll(_machine, '')
    .replaceAll(RegExp(r'\$\$|\\\[|\\\]|\\\(|\\\)'), ' ')
    .replaceAll(RegExp(r'[*_`#>]'), '')
    .replaceAll(RegExp(r'\n{2,}'), '\n')
    .trim();
