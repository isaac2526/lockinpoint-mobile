import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../practice/practice_repository.dart';
import '../practice/practice_session_screen.dart';
import '../../design/components.dart';
import '../../design/glass.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import 'saved_repository.dart';

/// ===========================================================================
/// SAVED QUESTIONS
///
/// Lime, per the palette, because "kept" is not "correct" and not "selected".
/// Each card opens to show the answer and the working; closed, it is just the
/// question, so the list can be used as revision rather than as a spoiler.
/// ===========================================================================
class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  int _page = 1;
  bool _busy = false;

  /// Build a sitting from everything this student kept.
  Future<void> _practise() async {
    // Resolved before the gap: the screen can be popped while the server is
    // still assembling the paper.
    final repo = ref.read(practiceRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      final sitting = await repo.startFromSaved(count: 40);
      if (!mounted) return;
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => PracticeSessionScreen(sitting: sitting),
        ),
      );
    } on ApiFailure catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final page = ref.watch(savedQuestionsProvider(_page));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved questions'),
        actions: [
          /* PRACTISE THEM. The saved list existed and nothing turned it into a
             paper, so the questions a student had marked as hard were the only
             ones they could not sit as a set. */
          if ((page.value?.questions.isNotEmpty ?? false))
            TextButton.icon(
              onPressed: _busy ? null : _practise,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Practise'),
            ),
        ],
      ),
      body: SafeArea(
        child: page.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(Gap.lg),
            child: Column(
              children: [
                LipSkeleton(height: 110),
                SizedBox(height: Gap.md),
                LipSkeleton(height: 110),
              ],
            ),
          ),
          error: (e, _) => LipError(
            message: '$e',
            onRetry: () => ref.invalidate(savedQuestionsProvider(_page)),
          ),
          data: (p) => p.questions.isEmpty
              ? const LipEmpty(
                  icon: Icons.bookmark_rounded,
                  title: 'Nothing saved yet',
                  message:
                      'Tap the bookmark on any question while you practise. '
                      'Everything you keep waits here, with its working.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.lg,
                    Gap.lg,
                    Gap.lg,
                    Gap.huge,
                  ),
                  itemCount: p.questions.length + 1,
                  itemBuilder: (_, i) {
                    if (i == p.questions.length) {
                      return _Pager(
                        page: _page,
                        total: p.total,
                        onPage: (n) => setState(() => _page = n),
                      );
                    }
                    return _SavedCard(
                      /* KEYED BY THE QUESTION, NOT THE SLOT. Without this,
                         removing one saved question handed its State - busy
                         flag stuck true, expanded flag and all - to whatever
                         question slid into that position: an identical-looking
                         bookmark button that was dead forever, and an answer
                         revealed on a question nobody tapped. */
                      key: ValueKey(p.questions[i].id),
                      q: p.questions[i],
                      onRemoved: () {
                        ref.invalidate(savedQuestionsProvider(_page));
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text('Removed from your list.'),
                            ),
                          );
                      },
                    );
                  },
                ),
        ),
      ),
      backgroundColor: c.bgBase,
    );
  }
}

class _SavedCard extends ConsumerStatefulWidget {
  const _SavedCard({super.key, required this.q, required this.onRemoved});
  final SavedQuestion q;
  final VoidCallback onRemoved;

  @override
  ConsumerState<_SavedCard> createState() => _SavedCardState();
}

class _SavedCardState extends ConsumerState<_SavedCard> {
  bool _open = false;
  bool _busy = false;

  Future<void> _remove() async {
    final api = ref.read(apiProvider);
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await unsaveQuestion(api, widget.q.id);
      widget.onRemoved();
    } on ApiFailure catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      /* A FAILED REMOVE MUST NOT LOOK LIKE A DEAD BUTTON. It used to reset
         the busy flag and say nothing at all, so a student offline tapped it
         over and over, concluding the app was broken. */
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not remove that one. Try again.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final q = widget.q;
    final correct = q.answerIndex;

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: GlassSurface(
        hue: c.hues.lime,
        onTap: () => setState(() => _open = !_open),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    [
                      q.subject,
                      if (q.year != null) '${q.year}',
                    ].where((s) => s.isNotEmpty).join(' · '),
                    style: LipType.label.copyWith(color: c.text3),
                  ),
                ),
                IconButton(
                  onPressed: _busy ? null : _remove,
                  tooltip: 'Remove from saved',
                  icon: Icon(
                    Icons.bookmark_remove_rounded,
                    size: 20,
                    color: c.text3,
                  ),
                ),
              ],
            ),
            Text(
              q.question,
              style: LipType.question.copyWith(color: c.text1, height: 1.45),
            ),
            const SizedBox(height: Gap.md),
            ...List.generate(q.options.length, (i) {
              final isAnswer = _open && correct == i;
              return Padding(
                padding: const EdgeInsets.only(bottom: Gap.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${String.fromCharCode(65 + i)}. ',
                      style: LipType.option.copyWith(
                        color: isAnswer ? c.success : c.text3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        q.options[i],
                        style: LipType.option.copyWith(
                          color: isAnswer ? c.success : c.text2,
                        ),
                      ),
                    ),
                    if (isAnswer)
                      Icon(Icons.check_rounded, size: 18, color: c.success),
                  ],
                ),
              );
            }),
            if (!_open)
              Padding(
                padding: const EdgeInsets.only(top: Gap.sm),
                child: Text(
                  'Tap to see the answer and the working',
                  style: LipType.caption.copyWith(color: c.text3),
                ),
              ),
            if (_open && q.explanation.isNotEmpty) ...[
              const SizedBox(height: Gap.md),
              const LipLabel('Why'),
              const SizedBox(height: Gap.xs),
              Text(
                q.explanation,
                style: LipType.small.copyWith(color: c.text2, height: 1.5),
              ),
            ],
            if (_open && q.explanation.isEmpty && correct == null) ...[
              const SizedBox(height: Gap.sm),
              Text(
                'No answer recorded for this one yet.',
                style: LipType.small.copyWith(color: c.text3),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({required this.page, required this.total, required this.onPage});

  final int page;
  final int total;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final pages = (total / 20).ceil().clamp(1, 9999);
    if (pages <= 1) return const SizedBox(height: Gap.lg);
    return Padding(
      padding: const EdgeInsets.only(top: Gap.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: page <= 1 ? null : () => onPage(page - 1),
            child: const Text('Back'),
          ),
          Text(
            'Page $page of $pages',
            style: LipType.small.copyWith(color: c.text3),
          ),
          TextButton(
            onPressed: page >= pages ? null : () => onPage(page + 1),
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }
}
