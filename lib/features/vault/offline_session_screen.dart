import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/speech.dart';
import '../../core/vault/vault_repository.dart';
import '../../design/components.dart';
import '../../design/glass.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../practice/practice_repository.dart';
import '../practice/question_html.dart';

/// ===========================================================================
/// AN OFFLINE SITTING — THE SCREEN THAT WAS MISSING
///
/// The vault could download, store, mark and sync — the repository under it
/// was proven on a real device with the network cut — and yet a student could
/// not USE any of it, because no screen existed to answer a downloaded
/// question. The vault was a store with no reader: a list of packs whose only
/// button was delete.
///
/// This is that reader. Everything on this screen is LOCAL: the questions,
/// the passages, the marking, the explanations. Nothing here may touch the
/// network, and the one thing that eventually should — sending the finished
/// result home — is QUEUED, not sent, and the queue drains when a connection
/// exists.
///
/// Instant marking, like the practice room: the pack carries every answer and
/// explanation precisely so that a student on a bus gets told WHY, not just
/// scored. A timed offline CBT can come later; a working offline room comes
/// first.
/// ===========================================================================
class OfflineSessionScreen extends ConsumerStatefulWidget {
  const OfflineSessionScreen({super.key, required this.sitting});
  final OfflineSitting sitting;

  @override
  ConsumerState<OfflineSessionScreen> createState() => _OfflineState();
}

class _OfflineState extends ConsumerState<OfflineSessionScreen> {
  int _i = 0;

  /// question id → chosen letter.
  final _chosen = <String, String>{};

  /// question ids whose answer has been revealed.
  final _checked = <String>{};

  bool _finished = false;
  OfflineScore? _score;
  final _startedAt = DateTime.now();

  List<ServedQuestion> get _qs => widget.sitting.questions;
  ServedQuestion get _q => _qs[_i];

  void _pick(String letter) {
    // A revealed question is settled. Changing the answer after seeing the
    // key would teach the score to lie to the student who earned it.
    if (_checked.contains(_q.id) || _finished) return;
    setState(() => _chosen[_q.id] = letter);
  }

  void _check() {
    if (_chosen[_q.id] == null) return;
    setState(() => _checked.add(_q.id));
  }

  Future<void> _finish() async {
    final unanswered = _qs.where((q) => _chosen[q.id] == null).length;
    if (unanswered > 0) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('$unanswered unanswered'),
          content: const Text(
            'Unanswered questions score nothing. Finish anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep going'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Finish'),
            ),
          ],
        ),
      );
      if (sure != true) return;
    }
    if (!mounted) return;

    final vault = ref.read(vaultProvider);
    final score = vault.score(_qs, _chosen);
    final duration = DateTime.now().difference(_startedAt).inSeconds;

    /* QUEUED, NEVER SENT. This screen exists for the moments with no signal;
       even with one, the result goes through the same queue so the behaviour
       is identical everywhere. The local id makes a retry idempotent. */
    await vault.queueResult(
      localId:
          'off-${DateTime.now().millisecondsSinceEpoch}-${widget.sitting.pack.subjectId}',
      pack: widget.sitting.pack,
      correct: score.correct,
      total: score.total,
      durationSeconds: duration,
      answers: _chosen,
    );

    // Best effort, instantly abandoned when there is no network — which is
    // the normal case here and not an error.
    vault.syncPending().catchError((_) => 0);

    if (!mounted) return;
    setState(() {
      _finished = true;
      _score = score;
      _checked.addAll(_qs.map((q) => q.id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    if (_finished) return _result(c);

    final q = _q;
    final chosen = _chosen[q.id];
    final revealed = _checked.contains(q.id);
    final passage = q.passageId == null
        ? null
        : widget.sitting.passages[q.passageId!];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sitting.pack.subjectName),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: Gap.md),
              child: Text(
                '${_i + 1} / ${_qs.length}',
                style: LipType.smallStrong.copyWith(color: c.text2),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Gap.lg,
                  Gap.md,
                  Gap.lg,
                  Gap.huge,
                ),
                children: [
                  // The chip says where these questions can be answered:
                  // anywhere. It is the whole point of the room.
                  Row(
                    children: [
                      LipChip(
                        '${widget.sitting.pack.examShort} · offline',
                        tone: ChipTone.brand,
                      ),
                      const Spacer(),
                      if (speechSupported) _SpeakButton(question: q),
                    ],
                  ),
                  if (passage != null) ...[
                    const SizedBox(height: Gap.md),
                    GlassSurface(
                      tier: GlassTier.deep,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (passage.title.isNotEmpty) ...[
                            Text(
                              passage.title,
                              style: LipType.subheading.copyWith(
                                color: c.text1,
                              ),
                            ),
                            const SizedBox(height: Gap.xs),
                          ],
                          LipHtml(
                            passage.body,
                            baseStyle: LipType.body.copyWith(
                              color: c.text2,
                              height: 1.55,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: Gap.md),
                  GlassSurface(
                    tier: GlassTier.raised,
                    padding: const EdgeInsets.all(Gap.lg),
                    child: LipHtml(
                      q.question,
                      baseStyle: LipType.question.copyWith(color: c.text1),
                    ),
                  ),
                  const SizedBox(height: Gap.md),
                  for (final (idx, opt) in q.options.indexed) ...[
                    Builder(
                      builder: (context) {
                        final letter = q.letters.length > idx
                            ? q.letters[idx]
                            : String.fromCharCode(65 + idx);
                        final isChosen = chosen == letter;
                        final isRight = q.answer == letter;
                        final tone = !revealed
                            ? null
                            : isRight
                            ? c.success
                            : (isChosen ? c.danger : null);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: Gap.sm),
                          child: GlassSurface(
                            tier: GlassTier.raised,
                            selected: isChosen && !revealed,
                            padding: const EdgeInsets.all(Gap.md),
                            onTap: () => _pick(letter),
                            child: Row(
                              children: [
                                Text(
                                  '$letter. ',
                                  style: LipType.option.copyWith(
                                    color: tone ?? c.text3,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Expanded(
                                  child: LipHtml(
                                    opt,
                                    baseStyle: LipType.option.copyWith(
                                      color: tone ?? c.text1,
                                    ),
                                  ),
                                ),
                                if (revealed && isRight)
                                  Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: c.success,
                                  ),
                                if (revealed && isChosen && !isRight)
                                  Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: c.danger,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  if (revealed && (q.explanation ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: Gap.sm),
                    GlassSurface(
                      hue: c.hues.teal,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const LipLabel('Why'),
                          const SizedBox(height: Gap.xs),
                          LipHtml(
                            q.explanation!,
                            baseStyle: LipType.body.copyWith(
                              color: c.text1,
                              height: 1.55,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _controls(c, chosen != null, revealed),
          ],
        ),
      ),
    );
  }

  Widget _controls(LipColors c, bool answered, bool revealed) => Container(
    padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.md),
    decoration: BoxDecoration(
      color: c.glassRaised,
      border: Border(top: BorderSide(color: c.glassBorder)),
    ),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Previous',
          onPressed: _i == 0 ? null : () => setState(() => _i--),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: revealed
              ? LipButton(
                  label: _i == _qs.length - 1 ? 'Finish' : 'Next question',
                  onPressed: () =>
                      _i == _qs.length - 1 ? _finish() : setState(() => _i++),
                )
              : LipButton(
                  label: answered ? 'Check answer' : 'Pick an option',
                  onPressed: answered ? _check : null,
                ),
        ),
        IconButton(
          tooltip: 'Next',
          onPressed: _i == _qs.length - 1 ? null : () => setState(() => _i++),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
        TextButton(onPressed: _finish, child: const Text('Finish')),
      ],
    ),
  );

  Widget _result(LipColors c) {
    final s = _score!;
    final pct = s.total == 0 ? 0 : (s.correct / s.total * 100).round();
    return Scaffold(
      appBar: AppBar(title: Text(widget.sitting.pack.subjectName)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.huge),
          children: [
            GlassSurface(
              hue: c.hues.teal,
              seam: true,
              child: Column(
                children: [
                  const LipLabel('Marked on this phone'),
                  const SizedBox(height: Gap.sm),
                  Text('$pct%', style: LipType.hero.copyWith(color: c.text1)),
                  Text(
                    '${s.correct} of ${s.total} correct',
                    style: LipType.body.copyWith(color: c.text2),
                  ),
                  const SizedBox(height: Gap.sm),
                  Text(
                    'This result is saved on the phone and reaches your '
                    'LockInPoint record the next time you have a connection. '
                    'Nothing is lost if that is next week.',
                    textAlign: TextAlign.center,
                    style: LipType.small.copyWith(color: c.text3, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Gap.lg),
            const LipLabel('The ones that got away'),
            const SizedBox(height: Gap.sm),
            if (s.wrongIds.isEmpty)
              Text(
                'None. Every answer you gave was right.',
                style: LipType.body.copyWith(color: c.text2),
              )
            else
              for (final q in _qs.where((q) => s.wrongIds.contains(q.id))) ...[
                GlassSurface(
                  tier: GlassTier.raised,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LipHtml(
                        q.question,
                        baseStyle: LipType.body.copyWith(color: c.text1),
                      ),
                      const SizedBox(height: Gap.xs),
                      Text(
                        'You picked ${_chosen[q.id] ?? '—'} · answer ${q.answer ?? '—'}',
                        style: LipType.smallStrong.copyWith(color: c.danger),
                      ),
                      if ((q.explanation ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: Gap.xs),
                        LipHtml(
                          q.explanation!,
                          baseStyle: LipType.small.copyWith(
                            color: c.text2,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: Gap.sm),
              ],
            const SizedBox(height: Gap.md),
            LipButton(
              icon: Icons.refresh_rounded,
              label: 'Sit it again',
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: Gap.sm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Back to the vault'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Same speak affordance as the online room — the device's own engine, so it
/// works exactly where this screen lives: nowhere near a network.
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
