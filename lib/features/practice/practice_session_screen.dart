import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/speech.dart';
import '../tutor/tutor_screen.dart';
import '../../design/components.dart';
import '../../design/glass.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../home/dashboard_screen.dart';
import 'practice_repository.dart';
import 'question_html.dart';
import 'review_screen.dart';

/// ===========================================================================
/// A SITTING · both rooms
///
/// PRACTICE is untimed: pick an answer, see at once whether it is right, read
/// the explanation, move on. The server sends the answer key with a fresh
/// practice paper, so marking costs no round trip and works in a tunnel.
///
/// CBT is the timed room and behaves like the hall: a clock, no marking until
/// the paper goes in, and time up submits by itself. The key is never in a
/// timed payload, and this screen would ignore it if it were.
///
/// Both autosave every answer in the background. An untimed sitting survives
/// leaving and comes back as the Continue card; a timed one keeps running,
/// and the exit offered is the one that keeps the score.
/// ===========================================================================
class PracticeSessionScreen extends ConsumerStatefulWidget {
  const PracticeSessionScreen({
    super.key,
    required this.sitting,
    this.clock = DateTime.now,
  });

  final Sitting sitting;

  /// Where "now" comes from. Production reads the wall clock, deliberately:
  /// the deadline is a point in time, so a phone that sleeps or an isolate
  /// that stalls cannot slow the exam down. Tests hand in their own clock
  /// because a wall clock cannot be fast-forwarded.
  @visibleForTesting
  final DateTime Function() clock;

  @override
  ConsumerState<PracticeSessionScreen> createState() => _SessionState();
}

class _SessionState extends ConsumerState<PracticeSessionScreen> {
  /// Questions this student has kept. Loaded once when the sitting opens so
  /// the bookmark shows its real state instead of starting hollow.
  final Set<String> _saved = <String>{};

  late int _idx = widget.sitting.questions.isEmpty
      ? 0
      : widget.sitting.initialIndex.clamp(
          0,
          widget.sitting.questions.length - 1,
        );
  late final Map<String, String> _answers = {...widget.sitting.initialAnswers};
  late final Map<String, bool> _checked = {...widget.sitting.initialChecked};
  late final Map<String, bool> _flags = {...widget.sitting.initialFlags};

  Timer? _saveDebounce;
  Timer? _tick;

  /// The moment the clock runs out, fixed once from the server's own count of
  /// seconds remaining. Everything after is measured against the wall clock,
  /// so a phone that sleeps or an isolate that stalls cannot slow the exam
  /// down — the deadline is a point in time, not a number being decremented.
  DateTime? _deadline;

  bool _submitting = false;
  SubmitResult? _result;

  Sitting get sitting => widget.sitting;
  ServedQuestion get q => sitting.questions[_idx];

  /// A resumed sitting arrives without the answer key, and a timed CBT never
  /// carries one at all — marking is the server's job at submit. The screen
  /// says which room the student is in rather than pretending.
  bool get _canMark =>
      !sitting.timed && q.answer != null && q.answer!.isNotEmpty;

  /// Whole seconds left, rounded UP: with 119.4 seconds to go the clock reads
  /// 02:00, not 01:59, and it reaches 00:00 exactly when the time is gone.
  int get _left {
    final d = _deadline;
    if (d == null) return 0;
    final ms = d.difference(widget.clock()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  @override
  void initState() {
    super.initState();
    /* Fire and forget, and INSULATED. A sitting must never wait on a
       bookmark list — and must never fail to open because fetching one
       threw. The paper is the point; the stars are a convenience. */
    try {
      ref.read(practiceRepositoryProvider).savedIds().then((ids) {
        if (mounted) setState(() => _saved.addAll(ids));
      }, onError: (_) {});
    } catch (_) {
      // No repository available (a widget test, a torn-down container).
    }
    if (sitting.timed) {
      _deadline = widget.clock().add(Duration(seconds: sitting.duration));
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (_left == 0) {
          _tick?.cancel();
          // Time is up. The paper goes in exactly as it would in the hall.
          _submit(force: true);
        } else {
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  void _queueSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 2), _saveNow);
  }

  /// Writes progress immediately. Called on the way out as well as on the
  /// debounce, because a student who answers and leaves within two seconds
  /// would otherwise lose that answer: dispose cancels the pending timer, and
  /// the answer would never have left the phone.
  Future<void> _saveNow() {
    _saveDebounce?.cancel();
    return ref
        .read(practiceRepositoryProvider)
        .saveProgress(
          attemptId: sitting.attemptId,
          answers: _answers,
          checked: _checked,
          flags: _flags,
          idx: _idx,
        );
  }

  void _choose(String letter) {
    if (_checked[q.id] == true) return; // marked answers are final
    setState(() {
      _answers[q.id] = letter;
      if (_canMark) _checked[q.id] = true;
    });
    _queueSave();
  }

  Future<void> _toggleSaved() async {
    final id = q.id;
    final wasSaved = _saved.contains(id);
    final repo = ref.read(practiceRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    // Optimistic: the star fills under the thumb, and rolls back if the
    // server disagrees. A bookmark that waits on a round trip feels broken.
    setState(() => wasSaved ? _saved.remove(id) : _saved.add(id));
    try {
      await repo.setSaved(id, !wasSaved);
    } on ApiFailure catch (e) {
      if (!mounted) return;
      setState(() => wasSaved ? _saved.add(id) : _saved.remove(id));
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _go(int to) {
    if (to < 0 || to >= sitting.questions.length) return;
    setState(() => _idx = to);
    _queueSave();
  }

  Future<void> _submit({bool force = false}) async {
    if (_submitting) return;
    final unanswered = sitting.questions.length - _answers.length;
    if (unanswered > 0 && !force) {
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
    _tick?.cancel();
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

  /// Every question at a glance: answered, flagged, or still blank. This is
  /// what makes a timed sitting navigable — a student who skipped question 14
  /// must be able to get back to it without tapping through thirteen others.
  Future<void> _openGrid() async {
    final jump = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final c = context.lip;
        return GlassSurface(
          tier: GlassTier.modal,
          blurred: true,
          radius: Radii.lg,
          padding: const EdgeInsets.all(Gap.lg),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LipLabel('All questions'),
                const SizedBox(height: Gap.md),
                Flexible(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: Gap.sm,
                      runSpacing: Gap.sm,
                      children: [
                        for (var i = 0; i < sitting.questions.length; i++)
                          _GridPip(
                            number: i + 1,
                            answered: _answers.containsKey(
                              sitting.questions[i].id,
                            ),
                            flagged: _flags[sitting.questions[i].id] == true,
                            current: i == _idx,
                            onTap: () => Navigator.pop(context, i),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Gap.md),
                Row(
                  children: [
                    Icon(Icons.flag_rounded, size: 14, color: c.warning),
                    const SizedBox(width: Gap.sm),
                    Text(
                      'Flagged for another look',
                      style: LipType.caption.copyWith(color: c.text3),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (jump != null && mounted) _go(jump);
  }

  Future<void> _leave() async {
    /* Practice and CBT part ways here, and the difference is told plainly.
       An untimed sitting waits on the dashboard. A timed one does not: the
       clock runs on the server whether the app is open or not, and the
       Continue card deliberately never offers a timed paper back. So the
       student is offered the exit that keeps their work. */
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(sitting.timed ? 'Leave the exam?' : 'Leave this sitting?'),
        content: Text(
          sitting.timed
              ? 'The clock keeps running, and a timed paper is not offered '
                    'again from the dashboard. Submit now to keep your score.'
              : 'Your progress is saved. You can continue from the dashboard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'stay'),
            child: const Text('Stay'),
          ),
          if (sitting.timed)
            TextButton(
              onPressed: () => Navigator.pop(context, 'leave'),
              child: const Text('Leave anyway'),
            ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, sitting.timed ? 'submit' : 'leave'),
            child: Text(sitting.timed ? 'Submit now' : 'Leave'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'submit') {
      await _submit(force: true);
    } else if (choice == 'leave') {
      // The last answer goes up BEFORE the screen goes away.
      await _saveNow();
      if (!mounted) return;
      ref.invalidate(dashboardProvider);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) {
      return ResultView(result: _result!, label: sitting.label);
    }
    /* The server refuses to open an empty paper, so this is only reachable by
       resuming a sitting whose questions have since gone. Say so and let the
       student out, rather than indexing into nothing. */
    if (sitting.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: LipEmpty(
          icon: Icons.inbox_rounded,
          title: 'This sitting has no questions',
          message: 'Start a fresh one from the dashboard.',
          actionLabel: 'Back',
          onAction: () => Navigator.of(context).pop(),
        ),
      );
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
                    if (sitting.timed) _Clock(left: _left),
                    IconButton(
                      onPressed: _openGrid,
                      icon: const Icon(Icons.grid_view_rounded, size: 20),
                      tooltip: 'All questions',
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
              /* THE SUBJECT RAIL. A four-subject UTME mock served as one
                 undifferentiated stream of 180 questions is unusable: a
                 candidate works subject by subject and needs to SEE where
                 English ends and Physics begins. The server has sent the
                 subjects list all along; the app dropped it. One chip per
                 subject - the one you are inside is lit, tapping jumps to
                 that subject's first question. Single-subject papers show
                 nothing, because a rail of one is noise. */
              if (sitting.subjects.length > 1)
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                    children: [
                      for (final sub in sitting.subjects)
                        Padding(
                          padding: const EdgeInsets.only(right: Gap.sm),
                          child: Center(
                            child: LipChip(
                              sub.name,
                              selected: q.subjectId == sub.id,
                              onTap: () {
                                final first = sitting.questions.indexWhere(
                                  (x) => x.subjectId == sub.id,
                                );
                                if (first >= 0) _go(first);
                              },
                            ),
                          ),
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
        Padding(
          padding: const EdgeInsets.only(bottom: Gap.sm),
          child: Row(
            children: [
              if (q.year != null) ...[
                LipChip('${q.year}'),
                const SizedBox(width: Gap.sm),
              ],
              if ((q.section ?? '').isNotEmpty) LipChip(q.section!),
              const Spacer(),
              // Flagging is how a student says "come back to this" without
              // losing their place, and it survives leaving and resuming.
              LipChip(
                _flags[q.id] == true ? 'Flagged' : 'Flag',
                tone: _flags[q.id] == true
                    ? ChipTone.warning
                    : ChipTone.neutral,
                onTap: () {
                  setState(() {
                    if (_flags[q.id] == true) {
                      _flags.remove(q.id);
                    } else {
                      _flags[q.id] = true;
                    }
                  });
                  _queueSave();
                },
              ),
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: LipHtml(
                      q.question,
                      baseStyle: LipType.question.copyWith(color: c.text1),
                    ),
                  ),
                  /* READ IT ALOUD. Uses the device's own engine, so it costs
                     nothing, needs no key, and works with the network off —
                     which matters, because the offline vault is exactly where
                     a student practising on a bus will use it. */
                  /* THE BOOKMARK THE SAVED SCREEN KEPT PROMISING. Its
                     empty state told students to "tap the bookmark on a
                     question while you practise" — a button that existed on
                     no screen, so an app-only student could never save
                     anything and Practise-my-saved was permanently empty. */
                  IconButton(
                    tooltip: _saved.contains(q.id)
                        ? 'Remove from saved'
                        : 'Save this question',
                    onPressed: _toggleSaved,
                    icon: Icon(
                      _saved.contains(q.id)
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      size: 21,
                      color: _saved.contains(q.id)
                          ? context.lip.hues.lime.ink
                          : context.lip.text3,
                    ),
                  ),
                  if (speechSupported) _SpeakButton(question: q),
                  /* ASK LUMI ABOUT THIS ONE. The entry point existed as a
                     constructor parameter - TutorScreen(questionId) - and
                     nothing in the app ever passed it, so the tutor could
                     never be asked about the question in front of the
                     student. Practice mode only, the same rule the website
                     enforces: in a timed CBT the tutor stays outside the
                     hall. The id alone travels - the server looks the
                     question up itself and never surrenders the answer. */
                  if (sitting.mode == 'practice')
                    IconButton(
                      tooltip: 'Ask Lumi about this question',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => TutorScreen(
                            questionId: q.id,
                            opening: 'Help me with this question.',
                          ),
                        ),
                      ),
                      icon: Icon(
                        Icons.smart_toy_rounded,
                        size: 21,
                        color: context.lip.hues.rose.ink,
                      ),
                    ),
                ],
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

/// The exam clock. Monospaced with tabular figures so the digits do not jitter
/// as they count down, and it turns to danger inside the last minute — the one
/// moment a student needs to be told without reading anything.
class _Clock extends StatelessWidget {
  const _Clock({required this.left});

  /// Whole seconds remaining.
  final int left;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final urgent = left <= 60;
    final low = left <= 300;
    final mm = (left ~/ 60).toString().padLeft(2, '0');
    final ss = (left % 60).toString().padLeft(2, '0');
    return Semantics(
      liveRegion: urgent,
      label: urgent ? '$left seconds left' : '${left ~/ 60} minutes left',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 5),
        decoration: BoxDecoration(
          color: urgent
              ? c.dangerSoft
              : low
              ? c.warningSoft
              : c.glassDeep,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Text(
          '$mm:$ss',
          style: LipType.mono.copyWith(
            color: urgent
                ? c.danger
                : low
                ? c.warning
                : c.text2,
          ),
        ),
      ),
    );
  }
}

/// One square in the question grid.
class _GridPip extends StatelessWidget {
  const _GridPip({
    required this.number,
    required this.answered,
    required this.flagged,
    required this.current,
    required this.onTap,
  });

  final int number;
  final bool answered;
  final bool flagged;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final bg = flagged
        ? c.warningSoft
        : answered
        ? c.brandSoft
        : c.glassDeep;
    final fg = flagged
        ? c.warning
        : answered
        ? c.brand
        : c.text3;
    return Semantics(
      button: true,
      label:
          'Question $number, '
          '${flagged
              ? 'flagged'
              : answered
              ? 'answered'
              : 'not answered'}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: Container(
          height: 40,
          width: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(Radii.sm),
            border: Border.all(
              color: current ? c.brand : c.glassBorder,
              width: current ? 2 : 1,
            ),
          ),
          child: Text(
            '$number',
            style: LipType.smallStrong.copyWith(color: fg),
          ),
        ),
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
/// The graded paper. Public because the Results history reopens the SAME
/// sheet for a sitting from last week — two correction screens would
/// eventually disagree about a student's own marks.
class ResultView extends StatelessWidget {
  const ResultView({super.key, required this.result, required this.label});

  final SubmitResult result;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    /* A JAMB MOCK IS OUT OF 400. Comparing a 265 against a 70 threshold
       painted every mock green and printed "265%" in the circle. The
       equivalent percentage keeps one meaning for the colour on both
       scales. */
    final good = result.percentEquivalent >= 70;
    final mid = result.percentEquivalent >= 50;
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
                  result.headline,
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
            // The review comes FIRST, and in gold. The score is the least
            // useful thing on this screen; going back through the ones you
            // missed is the whole reason the paper was worth sitting.
            if (result.corrections.isNotEmpty) ...[
              LipButton(
                label: result.missed.isEmpty
                    ? 'Go through the paper'
                    : 'See what you missed',
                icon: Icons.fact_check_rounded,
                gold: true,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ReviewScreen(result: result, label: label),
                  ),
                ),
              ),
              const SizedBox(height: Gap.sm),
            ],
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

/// Speak this question, or stop if it is already speaking.
///
/// A ValueListenableBuilder rather than setState: the speaking flag changes
/// when the ENGINE finishes, which can be a minute after the tap, and
/// rebuilding the whole sitting for it would be wasteful.
class _SpeakButton extends ConsumerWidget {
  const _SpeakButton({required this.question});
  final ServedQuestion question;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;
    final speech = ref.watch(speechProvider);

    return ValueListenableBuilder<bool>(
      valueListenable: speech.speaking,
      builder: (_, speaking, _) => IconButton(
        tooltip: speaking ? 'Stop reading' : 'Read this question aloud',
        onPressed: () => speaking
            ? speech.stop()
            : speech.question(
                question.question,
                question.options,
                question.letters,
              ),
        icon: Icon(
          speaking ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
          size: 22,
          color: speaking ? c.brand : c.text3,
        ),
      ),
    );
  }
}
