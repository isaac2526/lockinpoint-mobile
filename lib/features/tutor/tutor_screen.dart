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

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy || _cool > 0) return;

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
      _turns.add(Turn('model', reply.text));
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
                      itemBuilder: (_, i) => i == _turns.length
                          ? const Padding(
                              padding: EdgeInsets.only(bottom: Gap.md),
                              child: LipSkeleton(height: 60),
                            )
                          : _Bubble(turn: _turns[i]),
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
  const _Bubble({required this.turn});
  final Turn turn;

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
                      color: mine ? c.text1 : c.text2,
                      height: 1.5,
                    ),
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
