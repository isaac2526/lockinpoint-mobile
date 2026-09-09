import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../design/components.dart';
import '../../design/glass.dart';
import '../../design/rich_text.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import 'theory_repository.dart';

/// ===========================================================================
/// THEORY AND PRACTICAL · the half of the paper that is not multiple choice.
///
/// THE SAME WALK AS THE CLASSROOM, on separate pages, because that is the
/// order the decision is actually made in:
///
///   which examination  ->  which subject  ->  what is in it  ->  the paper
///
/// It used to open on a single flat list of every subject from every board at
/// once — "everything moded together". The examination step was missing
/// entirely.
///
/// AND IT SHOWS BOTH HALVES NOW. A subject holds two different things and the
/// app could only ever see one of them: the SESSIONS Tutor Bello writes in
/// Admin (stored in `notes`) and the PAST PAPERS the PDF importer produces
/// (stored in `theory_questions`). This room read only the second, so every
/// session he wrote by hand was live on the website and invisible on the
/// phone.
///
/// THE MODEL ANSWER IS BEHIND A TAP, always. A theory question with its
/// marking scheme already on the screen is a passage to read, not a question
/// to attempt — and the entire value of theory practice is writing your own
/// answer first and then finding out how close it was.
/// ===========================================================================
class TheoryScreen extends ConsumerWidget {
  const TheoryScreen({super.key, this.kind = 'theory'});

  /// 'theory' or 'practical'. Two different papers with different
  /// conventions; a student revising one is not revising the other.
  final String kind;

  String get _title => kind == 'practical' ? 'Practical' : 'Theory';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;
    final exams = ref.watch(theoryExamsProvider(kind));

    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: SafeArea(
        child: exams.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(Gap.lg),
            child: LipSkeleton(height: 220),
          ),
          error: (e, _) => LipError(
            message: e is ApiFailure ? e.message : '$e',
            detail: e is ApiFailure ? e.detail : null,
            onRetry: () => ref.invalidate(theoryExamsProvider(kind)),
          ),
          data: (list) => list.isEmpty
              ? LipEmpty(
                  icon: Icons.edit_note_rounded,
                  title: 'No $_title papers yet',
                  message:
                      'These are the written questions — the half of the paper '
                      'that is not multiple choice. They appear here as the '
                      'tutors upload them.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.lg,
                    Gap.lg,
                    Gap.lg,
                    Gap.huge,
                  ),
                  children: [
                    Text(
                      'Which examination?',
                      style: LipType.title.copyWith(color: c.text1),
                    ),
                    const SizedBox(height: Gap.xs),
                    Text(
                      kind == 'practical'
                          ? 'Apparatus, observations and readings — written '
                                'out, the way the practical paper asks.'
                          : 'Written questions and full sessions from your '
                                'tutor. Write your answer first, then compare.',
                      style: LipType.small.copyWith(color: c.text3),
                    ),
                    const SizedBox(height: Gap.lg),
                    for (final e in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Gap.md),
                        child: GlassSurface(
                          hue: c.hues.orange,
                          padding: const EdgeInsets.all(Gap.lg),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  TheorySubjectsScreen(exam: e, kind: kind),
                            ),
                          ),
                          child: _Row(
                            title: e.name,
                            subtitle: [
                              if (e.full.isNotEmpty && e.full != e.name) e.full,
                              '${e.subjects} subject'
                                  '${e.subjects == 1 ? '' : 's'}',
                            ].join(' · '),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Step two: which subject, inside the examination just chosen.
class TheorySubjectsScreen extends ConsumerWidget {
  const TheorySubjectsScreen({
    super.key,
    required this.exam,
    required this.kind,
  });

  final TheoryExam exam;
  final String kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;
    final key = (kind: kind, exam: exam.slug);
    final subjects = ref.watch(theorySubjectsProvider(key));

    return Scaffold(
      appBar: AppBar(title: Text(exam.name)),
      body: SafeArea(
        child: subjects.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(Gap.lg),
            child: LipSkeleton(height: 200),
          ),
          error: (e, _) => LipError(
            message: e is ApiFailure ? e.message : '$e',
            detail: e is ApiFailure ? e.detail : null,
            onRetry: () => ref.invalidate(theorySubjectsProvider(key)),
          ),
          data: (list) => list.isEmpty
              ? const LipEmpty(
                  icon: Icons.edit_note_rounded,
                  title: 'Nothing here yet',
                  message:
                      'No subject under this examination has papers or '
                      'sessions filed yet.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.lg,
                    Gap.lg,
                    Gap.lg,
                    Gap.huge,
                  ),
                  children: [
                    Text(
                      'Which subject?',
                      style: LipType.title.copyWith(color: c.text1),
                    ),
                    const SizedBox(height: Gap.lg),
                    for (final s in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Gap.md),
                        child: GlassSurface(
                          hue: c.hues.orange,
                          padding: const EdgeInsets.all(Gap.lg),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  TheoryShelfScreen(subject: s, kind: kind),
                            ),
                          ),
                          child: _Row(
                            title: s.name,
                            /* BOTH HALVES ARE COUNTED. A subject with three
                               written sessions and no imported paper used to
                               read "0 questions" — or not appear at all. */
                            subtitle: [
                              if (s.sessions > 0)
                                '${s.sessions} session'
                                    '${s.sessions == 1 ? '' : 's'}',
                              if (s.questions > 0)
                                '${s.questions} question'
                                    '${s.questions == 1 ? '' : 's'}',
                            ].join(' · '),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Step three: what this subject holds. The tutor's written sessions first —
/// they are the thing he made by hand — then the past papers by year.
class TheoryShelfScreen extends ConsumerWidget {
  const TheoryShelfScreen({
    super.key,
    required this.subject,
    required this.kind,
  });

  final TheorySubject subject;
  final String kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;
    final key = (subject: subject.id, kind: kind);
    final shelf = ref.watch(theoryShelfProvider(key));

    return Scaffold(
      appBar: AppBar(title: Text(subject.name)),
      body: SafeArea(
        child: shelf.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(Gap.lg),
            child: LipSkeleton(height: 160),
          ),
          error: (e, _) => LipError(
            message: e is ApiFailure ? e.message : '$e',
            detail: e is ApiFailure ? e.detail : null,
            onRetry: () => ref.invalidate(theoryShelfProvider(key)),
          ),
          data: (shelf) => shelf.isEmpty
              ? const LipEmpty(
                  icon: Icons.edit_note_rounded,
                  title: 'Nothing filed yet',
                  message: 'No sessions and no papers for this subject yet.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.lg,
                    Gap.lg,
                    Gap.lg,
                    Gap.huge,
                  ),
                  children: [
                    if (shelf.sessions.isNotEmpty) ...[
                      const LipLabel('Sessions from your tutor'),
                      const SizedBox(height: Gap.sm),
                      for (final n in shelf.sessions)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Gap.sm),
                          child: GlassSurface(
                            padding: const EdgeInsets.all(Gap.md),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => TheorySessionScreen(
                                  id: n.id,
                                  title: n.title,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.menu_book_rounded,
                                  size: 20,
                                  color: c.hues.orange.ink,
                                ),
                                const SizedBox(width: Gap.md),
                                Expanded(
                                  child: Text(
                                    n.title,
                                    style: LipType.body.copyWith(
                                      color: c.text1,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 20,
                                  color: c.text3,
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: Gap.lg),
                    ],
                    if (shelf.years.isNotEmpty) ...[
                      const LipLabel('Past papers'),
                      const SizedBox(height: Gap.sm),
                      Wrap(
                        spacing: Gap.sm,
                        runSpacing: Gap.sm,
                        children: [
                          for (final y in shelf.years)
                            LipChip(
                              '${y.year}',
                              count: y.n,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => TheoryPaperScreen(
                                    subject: subject,
                                    kind: kind,
                                    year: y.year,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// One written session, opened. Its body is the rich HTML the tutor typed,
/// drawn as HTML — not stripped to plain text, which is what happened to
/// every other note in this app before LipHtml existed.
class TheorySessionScreen extends ConsumerWidget {
  const TheorySessionScreen({super.key, required this.id, required this.title});

  final String id;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;
    final session = ref.watch(theorySessionProvider(id));

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: session.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(Gap.lg),
            child: LipSkeleton(height: 300),
          ),
          error: (e, _) => LipError(
            message: e is ApiFailure ? e.message : '$e',
            detail: e is ApiFailure ? e.detail : null,
            onRetry: () => ref.invalidate(theorySessionProvider(id)),
          ),
          data: (n) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              Gap.lg,
              Gap.lg,
              Gap.lg,
              Gap.huge,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n.title, style: LipType.title.copyWith(color: c.text1)),
                const SizedBox(height: Gap.md),
                LipHtml(
                  n.html,
                  baseStyle: LipType.body.copyWith(color: c.text1, height: 1.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One row of the walk: a title, a line under it, a chevron.
class _Row extends StatelessWidget {
  const _Row({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: LipType.subheading.copyWith(color: c.text1)),
              if (subtitle.isNotEmpty)
                Text(subtitle, style: LipType.caption.copyWith(color: c.text3)),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, size: 20, color: c.text3),
      ],
    );
  }
}

class TheoryPaperScreen extends ConsumerWidget {
  const TheoryPaperScreen({
    super.key,
    required this.subject,
    required this.kind,
    required this.year,
  });
  final TheorySubject subject;
  final String kind;
  final int year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (subject: subject.id, kind: kind, year: year);
    final paper = ref.watch(theoryPaperProvider(key));

    return Scaffold(
      appBar: AppBar(title: Text('${subject.name} · $year')),
      body: SafeArea(
        child: paper.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(Gap.lg),
            child: LipSkeleton(height: 260),
          ),
          error: (e, _) => LipError(
            message: '$e',
            onRetry: () => ref.invalidate(theoryPaperProvider(key)),
          ),
          data: (qs) => qs.isEmpty
              ? const LipEmpty(
                  icon: Icons.edit_note_rounded,
                  title: 'This paper is empty',
                  message: 'Nothing has been filed under this year yet.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.lg,
                    Gap.lg,
                    Gap.lg,
                    Gap.huge,
                  ),
                  itemCount: qs.length,
                  itemBuilder: (_, i) => _Question(q: qs[i]),
                ),
        ),
      ),
    );
  }
}

/// One question, and the answer it will not show until asked.
class _Question extends ConsumerStatefulWidget {
  const _Question({required this.q});
  final TheoryQuestion q;

  @override
  ConsumerState<_Question> createState() => _QuestionState();
}

class _QuestionState extends ConsumerState<_Question> {
  TheoryAnswer? _answer;
  bool _busy = false;
  String _problem = '';

  Future<void> _reveal() async {
    setState(() {
      _busy = true;
      _problem = '';
    });
    try {
      final a = await revealAnswer(ref.read(apiProvider), widget.q.id);
      if (mounted) setState(() => _answer = a);
    } on ApiFailure catch (e) {
      if (mounted) setState(() => _problem = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final q = widget.q;

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: GlassSurface(
        tier: GlassTier.card,
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (q.number.isNotEmpty)
                  Text(
                    q.number,
                    style: LipType.bodyStrong.copyWith(
                      color: c.hues.orange.ink,
                    ),
                  ),
                const Spacer(),
                if (q.marks != null)
                  Text(
                    '${q.marks} mark${q.marks == 1 ? '' : 's'}',
                    style: LipType.caption.copyWith(color: c.text3),
                  ),
              ],
            ),
            const SizedBox(height: Gap.sm),
            LipHtml(
              q.html,
              baseStyle: LipType.body.copyWith(color: c.text1, height: 1.55),
            ),
            const SizedBox(height: Gap.md),

            if (_answer == null) ...[
              /* BEHIND A TAP, always. A theory question with its marking
                 scheme already on the screen is a passage to read, not a
                 question to attempt. */
              OutlinedButton.icon(
                onPressed: _busy ? null : _reveal,
                icon: const Icon(Icons.visibility_outlined, size: 17),
                label: Text(
                  _busy
                      ? 'Opening…'
                      : 'Write yours first · then show the answer',
                ),
              ),
              if (_problem.isNotEmpty) ...[
                const SizedBox(height: Gap.sm),
                LipFormError(message: _problem),
              ],
            ] else if (!_answer!.hasAnswer)
              Text(
                'This paper was filed without its marking scheme. The question '
                'is still worth attempting — compare it with your own notes.',
                style: LipType.small.copyWith(color: c.text3),
              )
            else
              GlassSurface(
                tier: GlassTier.deep,
                padding: const EdgeInsets.all(Gap.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LipLabel('The marking scheme'),
                    const SizedBox(height: Gap.xs),
                    LipHtml(
                      _answer!.html,
                      baseStyle: LipType.body.copyWith(
                        color: c.text2,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
