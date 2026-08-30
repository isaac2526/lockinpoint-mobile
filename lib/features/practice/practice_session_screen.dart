import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../design/components.dart';
import '../../design/glass.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../home/dashboard_screen.dart';
import 'practice_repository.dart';
import 'question_html.dart';

/// ===========================================================================
/// A PRACTICE SITTING
///
/// Practice is the untimed room: pick an answer, see at once whether it is
/// right, read the explanation, move on. The server sent the answer key with
/// the questions (practice mode only), so marking costs no round trip and
/// works in a tunnel.
///
/// Every answer autosaves in the background. Leaving the room keeps the
/// sitting alive — it becomes the Continue card on the dashboard. Submitting
/// grades it for good and feeds the streak.
/// ===========================================================================
class PracticeSessionScreen extends ConsumerStatefulWidget {
  const PracticeSessionScreen({super.key, required this.sitting});

  final Sitting sitting;

  @override
  ConsumerState<PracticeSessionScreen> createState() => _SessionState();
}

class _SessionState extends ConsumerState<PracticeSessionScreen> {
  late int _idx = widget.sitting.initialIndex.clamp(
    0,
    widget.sitting.questions.length - 1,
  );
  late final Map<String, String> _answers = {...widget.sitting.initialAnswers};
  late final Map<String, bool> _checked = {...widget.sitting.initialChecked};

  Timer? _saveDebounce;
  bool _submitting = false;
  SubmitResult? _result;

  Sitting get sitting => widget.sitting;
  ServedQuestion get q => sitting.questions[_idx];

  /// A resumed sitting arrives without the answer key — the server only sends
  /// it on a fresh practice start. Marking then waits for submit, and the
  /// screen says so instead of pretending.
  bool get _canMark => q.answer != null && q.answer!.isNotEmpty;

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }

  void _queueSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 2), () {
      ref
          .read(practiceRepositoryProvider)
          .saveProgress(
            attemptId: sitting.attemptId,
            answers: _answers,
            checked: _checked,
            idx: _idx,
          );
    });
  }

  void _choose(String letter) {
    if (_checked[q.id] == true) return; // marked answers are final
    setState(() {
      _answers[q.id] = letter;
      if (_canMark) _checked[q.id] = true;
    });
    _queueSave();
  }

  void _go(int to) {
    if (to < 0 || to >= sitting.questions.length) return;
    setState(() => _idx = to);
    _queueSave();
  }

  Future<void> _submit() async {
    final unanswered = sitting.questions.length - _answers.length;
    if (unanswered > 0) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Submit now?'),
          content: Text(
            unanswered == 1
                ? 'One question has no answer yet.'
                : '$unanswered questions have no answer yet.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep going'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      );
      if (sure != true) return;
    }
    setState(() => _submitting = true);
    try {
      final result = await ref
          .read(practiceRepositoryProvider)
          .submit(attemptId: sitting.attemptId, answers: _answers);
      if (!mounted) return;
      setState(() => _result = result);
      // The dashboard's attempt count and streak just changed.
      ref.invalidate(dashboardProvider);
    } on ApiFailure catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _leave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave this sitting?'),
        content: const Text(
          'Your progress is saved. You can continue from the dashboard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      ref.invalidate(dashboardProvider);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) {
      return _ResultView(result: _result!, label: sitting.label);
    }
    final c = context.lip;
    final total = sitting.questions.length;
    final answered = _answers.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.sm, Gap.md, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _leave,
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Leave',
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sitting.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: LipType.smallStrong.copyWith(color: c.text1),
                          ),
                          Text(
                            'Question ${_idx + 1} of $total · $answered answered',
                            style: LipType.caption.copyWith(color: c.text3),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Submit'),
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.pill),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : (_idx + 1) / total,
                  minHeight: 3,
                  backgroundColor: c.glassDeep,
                  valueColor: AlwaysStoppedAnimation(c.brand),
                ),
              ),
              Expanded(child: _questionView()),
              _navBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _questionView() {
    final c = context.lip;
    final chosen = _answers[q.id];
    final marked = _checked[q.id] == true;
    final passage = q.passageId == null ? null : sitting.passages[q.passageId];

    return ListView(
      key: ValueKey(q.id),
      padding: const EdgeInsets.all(Gap.md),
      children: [
        if (q.year != null || (q.section ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.sm),
            child: Wrap(
              spacing: Gap.sm,
              children: [
                if (q.year != null) LipChip('${q.year}'),
                if ((q.section ?? '').isNotEmpty) LipChip(q.section!),
              ],
            ),
          ),
        if (passage != null) ...[
          _PassageCard(passage: passage),
          const SizedBox(height: Gap.md),
        ],
        GlassSurface(
          tier: GlassTier.raised,
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LipHtml(
                q.question,
                baseStyle: LipType.question.copyWith(color: c.text1),
              ),
              if (q.mediaUrl('question') != null) ...[
                const SizedBox(height: Gap.md),
                _MediaImage(url: q.mediaUrl('question')!),
              ],
            ],
          ),
        ),
        const SizedBox(height: Gap.md),
        for (final (i, opt) in q.options.indexed) ...[
          _OptionRow(
            letter: q.letters.length > i ? q.letters[i] : 'ABCDEFGH'[i],
            html: opt,
            mediaUrl: q.mediaUrl(
              (q.letters.length > i ? q.letters[i] : 'ABCDEFGH'[i])
                  .toLowerCase(),
            ),
            chosen:
                chosen == (q.letters.length > i ? q.letters[i] : 'ABCDEFGH'[i]),
            marked: marked,
            right: q.answer,
            onTap: () =>
                _choose(q.letters.length > i ? q.letters[i] : 'ABCDEFGH'[i]),
          ),
          const SizedBox(height: Gap.sm),
        ],
        if (marked && (q.explanation ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: Gap.sm),
          GlassSurface(
            tier: GlassTier.deep,
            padding: const EdgeInsets.all(Gap.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LipLabel('Why'),
                const SizedBox(height: Gap.sm),
                LipHtml(
                  q.explanation!,
                  baseStyle: LipType.small.copyWith(color: c.text2),
                ),
                if (q.mediaUrl('explanation') != null) ...[
                  const SizedBox(height: Gap.md),
                  _MediaImage(url: q.mediaUrl('explanation')!),
                ],
              ],
            ),
          ),
        ],
        if (!_canMark && chosen != null)
          Padding(
            padding: const EdgeInsets.only(top: Gap.sm),
            child: Text(
              'Marking for this resumed sitting happens when you submit.',
              style: LipType.caption.copyWith(color: c.text3),
            ),
          ),
        const SizedBox(height: Gap.xl),
      ],
    );
  }

  Widget _navBar() {
    final c = context.lip;
    final last = _idx == sitting.questions.length - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.md),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: _idx == 0 ? null : () => _go(_idx - 1),
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Previous question',
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: LipButton(
              label: last ? 'Finish and submit' : 'Next question',
              gold: last,
              busy: _submitting,
              onPressed: last ? _submit : () => _go(_idx + 1),
            ),
          ),
          if (!last) ...[
            const SizedBox(width: Gap.md),
            Text(
              '${_idx + 1}/${sitting.questions.length}',
              style: LipType.mono.copyWith(color: c.text3),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.letter,
    required this.html,
    required this.chosen,
    required this.marked,
    required this.right,
    required this.onTap,
    this.mediaUrl,
  });

  final String letter;
  final String html;
  final bool chosen;
  final bool marked;
  final String? right;
  final VoidCallback onTap;
  final String? mediaUrl;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final isRight = marked && right == letter;
    final isWrongPick = marked && chosen && right != letter;

    final (border, bg, fg) = isRight
        ? (c.success, c.successSoft, c.success)
        : isWrongPick
        ? (c.danger, c.dangerSoft, c.danger)
        : chosen
        ? (c.brand, c.brandSoft, c.brand)
        : (c.glassBorder, c.glassRaised, c.text2);

    return Semantics(
      button: true,
      selected: chosen,
      label: 'Option $letter',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Container(
          padding: const EdgeInsets.all(Gap.md),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 26,
                width: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: chosen || isRight ? border : c.glassDeep,
                ),
                child: isRight
                    ? const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      )
                    : isWrongPick
                    ? const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Colors.white,
                      )
                    : Text(
                        letter,
                        style: LipType.smallStrong.copyWith(
                          color: chosen ? Colors.white : c.text3,
                        ),
                      ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LipHtml(
                      html,
                      baseStyle: LipType.option.copyWith(
                        color: marked && (isRight || isWrongPick)
                            ? fg
                            : c.text1,
                      ),
                    ),
                    if (mediaUrl != null) ...[
                      const SizedBox(height: Gap.sm),
                      _MediaImage(url: mediaUrl!),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PassageCard extends StatefulWidget {
  const _PassageCard({required this.passage});
  final Passage passage;

  @override
  State<_PassageCard> createState() => _PassageCardState();
}

class _PassageCardState extends State<_PassageCard> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    return GlassSurface(
      tier: GlassTier.deep,
      padding: const EdgeInsets.all(Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Row(
              children: [
                Icon(Icons.menu_book_rounded, size: 16, color: c.brand),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    widget.passage.title.isEmpty
                        ? 'Read the passage'
                        : widget.passage.title,
                    style: LipType.smallStrong.copyWith(color: c.text1),
                  ),
                ),
                Icon(
                  _open
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: c.text3,
                ),
              ],
            ),
          ),
          if (_open) ...[
            const SizedBox(height: Gap.sm),
            LipHtml(
              widget.passage.body,
              baseStyle: LipType.small.copyWith(color: c.text2),
            ),
          ],
        ],
      ),
    );
  }
}

class _MediaImage extends StatelessWidget {
  const _MediaImage({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.md),
      child: CachedNetworkImage(
        imageUrl: url,
        placeholder: (_, _) => const LipSkeleton(height: 140),
        errorWidget: (_, _, _) => Container(
          padding: const EdgeInsets.all(Gap.md),
          color: c.glassDeep,
          child: Text(
            'The diagram could not load. Check your connection.',
            style: LipType.caption.copyWith(color: c.text3),
          ),
        ),
      ),
    );
  }
}

/// The graded end of a sitting: the score, per subject lines, and the way out.
class _ResultView extends StatelessWidget {
  const _ResultView({required this.result, required this.label});

  final SubmitResult result;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final good = result.overall >= 70;
    final mid = result.overall >= 50;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Gap.lg),
          children: [
            const SizedBox(height: Gap.xl),
            Center(
              child: Container(
                height: 120,
                width: 120,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: good
                      ? c.successSoft
                      : mid
                      ? c.accentSoft
                      : c.dangerSoft,
                  border: Border.all(
                    color: good
                        ? c.success
                        : mid
                        ? c.accent
                        : c.danger,
                    width: 3,
                  ),
                ),
                child: Text(
                  '${result.overall}%',
                  style: LipType.monoBig.copyWith(
                    fontSize: 30,
                    color: good
                        ? c.success
                        : mid
                        ? c.accent
                        : c.danger,
                  ),
                ),
              ),
            ),
            const SizedBox(height: Gap.lg),
            Center(
              child: Text(
                good
                    ? 'Sharp. Keep this pace.'
                    : mid
                    ? 'Solid ground. Push higher.'
                    : 'Every master was once a beginner.',
                style: LipType.heading.copyWith(color: c.text1),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: Gap.sm),
            Center(
              child: Text(
                '${result.correct} of ${result.total} correct · $label',
                style: LipType.small.copyWith(color: c.text3),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: Gap.xl),
            for (final p in result.perSubject) ...[
              GlassSurface(
                tier: GlassTier.raised,
                padding: const EdgeInsets.all(Gap.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.name,
                        style: LipType.smallStrong.copyWith(color: c.text1),
                      ),
                    ),
                    Text(
                      '${p.correct}/${p.total}',
                      style: LipType.mono.copyWith(color: c.text2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Gap.sm),
            ],
            const SizedBox(height: Gap.lg),
            LipButton(
              label: 'Back to the dashboard',
              icon: Icons.home_rounded,
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            ),
          ],
        ),
      ),
    );
  }
}
