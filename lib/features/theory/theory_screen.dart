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
/// The same walk as the classroom, because it is the same decision a student
/// is making: which subject, then which year, then the paper.
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
    final subjects = ref.watch(theorySubjectsProvider(kind));

    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: SafeArea(
        child: subjects.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(Gap.lg),
            child: LipSkeleton(height: 220),
          ),
          error: (e, _) => LipError(
            message: '$e',
            onRetry: () => ref.invalidate(theorySubjectsProvider(kind)),
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
                      'Which subject?',
                      style: LipType.title.copyWith(color: c.text1),
                    ),
                    const SizedBox(height: Gap.xs),
                    Text(
                      kind == 'practical'
                          ? 'Apparatus, observations and readings — written out, '
                                'the way the practical paper asks for them.'
                          : 'Written questions with their marking schemes. Write '
                                'your answer first, then compare.',
                      style: LipType.small.copyWith(color: c.text3),
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
                                  TheoryYearsScreen(subject: s, kind: kind),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.name,
                                      style: LipType.subheading.copyWith(
                                        color: c.text1,
                                      ),
                                    ),
                                    Text(
                                      [
                                        if (s.exam.isNotEmpty) s.exam,
                                        '${s.questions} question'
                                            '${s.questions == 1 ? '' : 's'}',
                                      ].join(' · '),
                                      style: LipType.caption.copyWith(
                                        color: c.text3,
                                      ),
                                    ),
                                  ],
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
                  ],
                ),
        ),
      ),
    );
  }
}

class TheoryYearsScreen extends ConsumerWidget {
  const TheoryYearsScreen({
    super.key,
    required this.subject,
    required this.kind,
  });
  final TheorySubject subject;
  final String kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;
    final years = ref.watch(
      theoryYearsProvider((subject: subject.id, kind: kind)),
    );

    return Scaffold(
      appBar: AppBar(title: Text(subject.name)),
      body: SafeArea(
        child: years.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(Gap.lg),
            child: LipSkeleton(height: 160),
          ),
          error: (e, _) => LipError(
            message: '$e',
            onRetry: () => ref.invalidate(
              theoryYearsProvider((subject: subject.id, kind: kind)),
            ),
          ),
          data: (list) => list.isEmpty
              ? const LipEmpty(
                  icon: Icons.edit_note_rounded,
                  title: 'No papers filed yet',
                  message: 'Nothing for this subject has a year on it yet.',
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
                      'Which year?',
                      style: LipType.title.copyWith(color: c.text1),
                    ),
                    const SizedBox(height: Gap.lg),
                    Wrap(
                      spacing: Gap.sm,
                      runSpacing: Gap.sm,
                      children: [
                        for (final y in list)
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
                ),
        ),
      ),
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
