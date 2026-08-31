import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../design/components.dart';
import '../../design/glass.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../activation/activation_screen.dart';
import 'tutor_repository.dart';

/// ===========================================================================
/// ASK LUMI
///
/// A tutor, not a search box. Rose throughout — Lumi's own colour, so a
/// student never confuses her answer with a marked question.
///
/// TWO REFUSALS THIS SCREEN TAKES SERIOUSLY, because both used to arrive as
/// an anonymous red sentence:
///
///   NOT ACTIVATED — offers the activation screen, not an apology.
///   TOO FAST      — counts the wait down and disables the send button, so a
///                   student cannot tap their way into the same refusal five
///                   times and conclude the app is broken.
/// ===========================================================================
class TutorScreen extends ConsumerStatefulWidget {
  const TutorScreen({super.key, this.questionId, this.opening});

  /// Set when Lumi is opened from inside a question. The server looks the
  /// question up itself — the app never sends the stem, and never the answer.
  final String? questionId;
  final String? opening;

  @override
  ConsumerState<TutorScreen> createState() => _TutorScreenState();
}

class _TutorScreenState extends ConsumerState<TutorScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _turns = <Turn>[];

  bool _busy = false;
  bool _needActivation = false;
  int _cool = 0;
  Timer? _coolTimer;

  @override
  void initState() {
    super.initState();
    final opening = widget.opening?.trim();
    if (opening != null && opening.isNotEmpty) _input.text = opening;
  }

  @override
  void dispose() {
    _coolTimer?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _coolTimer?.cancel();
    setState(() => _cool = seconds);
    _coolTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cool--);
      if (_cool <= 0) t.cancel();
    });
  }

  /// The last thing asked, kept so a failed answer can be retried with one
  /// tap instead of retyped from memory.
  String _lastAsked = '';

  Future<void> _retry() {
    if (_lastAsked.isEmpty || _busy) return Future.value();
    // Drop the failed exchange so the transcript reads clean after recovery.
    setState(() {
      if (_turns.isNotEmpty && !_turns.last.mine) _turns.removeLast();
      if (_turns.isNotEmpty && _turns.last.mine) _turns.removeLast();
    });
    _input.text = _lastAsked;
    return _send();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy || _cool > 0) return;
    _lastAsked = text;

    // Resolved before the gap, so a screen that is popped mid-answer does not
    // reach back into a container that has already been torn down.
    final api = ref.read(apiProvider);
    final history = List<Turn>.from(_turns);

    setState(() {
      _turns.add(Turn('user', text));
      _input.clear();
      _busy = true;
      _needActivation = false;
    });
    _toBottom();

    final reply = await askLumi(
      api,
      text,
      history: history,
      questionId: widget.questionId,
    );
    if (!mounted) return;

    setState(() {
      _busy = false;
      _needActivation = reply.needActivation;
      _turns.add(Turn(reply.ok ? 'model' : 'error', reply.text));
    });
    if (reply.coolSeconds != null) _startCooldown(reply.coolSeconds!);
    _toBottom();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lip;

    return Scaffold(
      appBar: AppBar(title: const Text('Ask Lumi')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _turns.isEmpty
                  ? const LipEmpty(
                      icon: Icons.smart_toy_rounded,
                      title: 'Ask Lumi anything',
                      message:
                          'A hard question, a topic that will not stick, a '
                          'method you half remember. She explains — she does '
                          'not just hand you the answer.',
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(
                        Gap.lg,
                        Gap.lg,
                        Gap.lg,
                        Gap.md,
                      ),
                      itemCount: _turns.length + (_busy ? 1 : 0),
                      /* THE INSTANT ACKNOWLEDGEMENT. The old busy state was a
                         LipSkeleton - a component that deliberately waits
                         200ms before appearing and then looks like an empty
                         placeholder box. For an answer that takes twenty
                         seconds, that read as a frozen screen, which is
                         exactly what the founder reported. The thinking
                         bubble appears the same frame the send lands, names
                         who is thinking, and moves the whole time. */
                      itemBuilder: (_, i) => i == _turns.length
                          ? const _ThinkingBubble()
                          : _Bubble(
                              turn: _turns[i],
                              onRetry:
                                  _turns[i].role == 'error' &&
                                      i == _turns.length - 1
                                  ? _retry
                                  : null,
                            ),
                    ),
            ),
            if (_needActivation)
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.sm),
                child: LipButton(
                  gold: true,
                  icon: Icons.vpn_key_rounded,
                  label: 'Activate to keep asking',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ActivationScreen(),
                    ),
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.sm,
                Gap.lg,
                Gap.md,
              ),
              decoration: BoxDecoration(
                color: c.glassRaised,
                border: Border(top: BorderSide(color: c.glassBorder)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: LipType.body.copyWith(color: c.text1),
                      decoration: InputDecoration(
                        hintText: _cool > 0
                            ? 'Lumi is catching up · ${_cool}s'
                            : 'Ask your question…',
                      ),
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  IconButton.filled(
                    onPressed: _busy || _cool > 0 ? null : _send,
                    style: IconButton.styleFrom(
                      backgroundColor: c.hues.rose.ink,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.send_rounded, size: 20),
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

class _Bubble extends StatelessWidget {
  const _Bubble({required this.turn, this.onRetry});
  final Turn turn;

  /// Offered only under a failed reply - a student should recover a lost
  /// answer with one tap, not by retyping the question from memory.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final mine = turn.mine;

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Flexible(
            child: GlassSurface(
              tier: mine ? GlassTier.raised : GlassTier.card,
              hue: mine ? null : c.hues.rose,
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.md,
                vertical: Gap.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!mine) ...[
                    const LipLabel('Lumi'),
                    const SizedBox(height: Gap.xs),
                  ],
                  SelectableText(
                    turn.text,
                    style: LipType.body.copyWith(
                      color: turn.role == 'error'
                          ? c.danger
                          : mine
                          ? c.text1
                          : c.text2,
                      height: 1.5,
                    ),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: Gap.sm),
                    LipChip('Try again', tone: ChipTone.brand, onTap: onRetry),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Lumi is thinking" with three breathing dots — visible the same frame the
/// question is sent. An acknowledgement is not decoration: without one, a
/// twenty-second answer is indistinguishable from a dead screen.
class _ThinkingBubble extends StatefulWidget {
  const _ThinkingBubble();

  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Row(
        children: [
          Flexible(
            child: GlassSurface(
              tier: GlassTier.card,
              hue: c.hues.rose,
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.md,
                vertical: Gap.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const LipLabel('Lumi'),
                  const SizedBox(height: Gap.sm),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'thinking',
                        style: LipType.small.copyWith(color: c.text2),
                      ),
                      const SizedBox(width: Gap.sm),
                      AnimatedBuilder(
                        animation: _c,
                        builder: (_, _) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var d = 0; d < 3; d++)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Opacity(
                                  /* Each dot breathes a third of a cycle
                                     behind the last, so the row reads as
                                     motion rather than a blink. */
                                  opacity:
                                      0.25 +
                                      0.75 *
                                          (0.5 + 0.5 * _wave(_c.value - d / 3)),
                                  child: Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: c.hues.rose.ink,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A smooth -1..1 wave without dart:math imports the file does not need.
double _wave(double t) {
  final x = (t - t.floor()) * 2;
  return x < 1 ? 2 * x - 1 : 3 - 2 * x;
}
