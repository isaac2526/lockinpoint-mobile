import '../../core/json.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/shell.dart' show openAppMenu;
import '../../core/api.dart';
import '../../design/components.dart';
import '../../design/lumi_markdown.dart';
import '../../design/rich_text.dart';
import '../../design/glass.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../activation/activation_screen.dart';
import 'chats_repository.dart';
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
  const TutorScreen({
    super.key,
    this.questionId,
    this.opening,
    this.embedded = false,
  });

  /// Set when Lumi is opened from inside a question. The server looks the
  /// question up itself — the app never sends the stem, and never the answer.
  final String? questionId;
  final String? opening;

  /// True when Lumi is a TAB in the bottom bar rather than a pushed route.
  /// An embedded screen shows the menu where the back arrow would be, because
  /// a tab has nowhere to go back to.
  final bool embedded;

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

  /// The conversation these turns belong to. Null while Lumi is opened from
  /// inside a question — that is a nudge about the question in front of the
  /// student, not a conversation worth keeping in their list of fifteen.
  String? _chatId;
  String _chatTitle = '';
  String _notice = '';

  @override
  void initState() {
    super.initState();
    final opening = widget.opening?.trim();
    if (opening != null && opening.isNotEmpty) _input.text = opening;
    // Opened on its own, Lumi picks up the last conversation. "Where they
    // stopped" is not a feature that needs a feature — it is opening the
    // right chat.
    if (widget.questionId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openLast());
    }
  }

  Future<void> _openLast() async {
    final api = ref.read(apiProvider);
    try {
      final list = await api.get('/api/ai/chats');
      final chats = (asList(list['chats'])).whereType<Map>().toList();
      if (chats.isEmpty || !mounted) return;
      await _open(LumiChat.from(chats.first));
    } on ApiFailure {
      /* A tutor that refuses to open because it could not fetch a list of old
         conversations would be a worse tutor. The new-chat path still works. */
    }
  }

  Future<void> _open(LumiChat chat) async {
    final api = ref.read(apiProvider);
    try {
      final msgs = await loadChat(api, chat.id);
      if (!mounted) return;
      setState(() {
        _chatId = chat.id;
        _chatTitle = chat.title;
        _notice = '';
        _turns
          ..clear()
          ..addAll(msgs.map((m) => Turn(m.role, m.text)));
      });
      _toBottom();
    } on ApiFailure catch (e) {
      if (mounted) setState(() => _notice = e.message);
    }
  }

  Future<void> _newChat() async {
    final api = ref.read(apiProvider);
    try {
      final c = await newChat(api);
      if (!mounted) return;
      setState(() {
        _chatId = c.id;
        _chatTitle = c.title;
        _notice = '';
        _turns.clear();
      });
      ref.invalidate(lumiChatsProvider);
    } on ApiFailure catch (e) {
      // The server's sentence names the oldest conversation, so the student
      // knows exactly what to delete.
      if (mounted) setState(() => _notice = e.message);
    }
  }

  Future<void> _chatsSheet() async {
    final api = ref.read(apiProvider);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => _ChatsSheet(
        onOpen: (c) {
          Navigator.of(sheet).pop();
          _open(c);
        },
        onNew: () {
          Navigator.of(sheet).pop();
          _newChat();
        },
        onRename: (c, title) async {
          await renameChat(api, c.id, title);
          if (mounted && c.id == _chatId) setState(() => _chatTitle = title);
        },
        onDelete: (c) async {
          await deleteChat(api, c.id);
          if (!mounted) return;
          if (c.id == _chatId) {
            setState(() {
              _chatId = null;
              _chatTitle = '';
              _turns.clear();
            });
          }
        },
      ),
    );
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

    /* A conversation is created on the FIRST message, not when the screen
       opens, so a student who opens Lumi and changes their mind has not spent
       one of their fifteen on an empty chat. Never for a question-side ask. */
    var id = _chatId;
    if (id == null && widget.questionId == null) {
      try {
        final c = await newChat(api);
        id = c.id;
        if (mounted) {
          setState(() {
            _chatId = c.id;
            _chatTitle = c.title;
          });
        }
      } on ApiFailure catch (e) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _notice = e.message;
          _turns.removeLast();
        });
        return;
      }
    }

    final reply = await askLumi(
      api,
      text,
      history: history,
      questionId: widget.questionId,
      chatId: id,
    );
    if (!mounted) return;

    setState(() {
      _busy = false;
      _needActivation = reply.needActivation;
      _turns.add(Turn('model', reply.text));
    });
    if (id != null) ref.invalidate(lumiChatsProvider);
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
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ask Lumi'),
            if (_chatTitle.isNotEmpty)
              Text(
                _chatTitle,
                style: LipType.caption.copyWith(color: context.lip.text3),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        automaticallyImplyLeading: !widget.embedded,
        leading: widget.embedded
            ? IconButton(
                onPressed: openAppMenu,
                icon: const Icon(Icons.menu_rounded),
                tooltip: 'Menu',
              )
            : null,
        actions: [
          // Only when Lumi is a conversation. Opened from a question she is a
          // nudge about that question, and a chat list would be noise.
          if (widget.questionId == null) ...[
            IconButton(
              tooltip: 'New conversation',
              icon: const Icon(Icons.add_comment_outlined),
              onPressed: _newChat,
            ),
            IconButton(
              tooltip: 'Your conversations',
              icon: const Icon(Icons.forum_outlined),
              onPressed: _chatsSheet,
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            /* The server's own sentence — "you have 15 conversations, delete
               one to start another; your oldest is …". Named rather than a
               generic refusal, so the student knows what to do about it. */
            if (_notice.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, 0),
                child: LipFormError(message: _notice),
              ),
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
                          ? const _Thinking()
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

/// ===========================================================================
/// LUMI, THINKING
///
/// A grey rectangle sat here. It is what every list in this app shows while
/// a row loads, and in a conversation it says the wrong thing entirely: a
/// student cannot tell "she is working on it" from "this screen is broken".
///
/// So it is a bubble on her side of the conversation, with her name on it and
/// three dots that move. THE DOTS ARE THE POINT — a still image after four
/// seconds looks stuck, and Lumi takes four seconds on a hard question.
///
/// The line under the dots changes as the wait grows, because a wait that is
/// ACKNOWLEDGED is a different experience from a wait that is not. Nothing
/// here is a lie: it does not claim to know what she is doing, only how long
/// she has been at it.
/// ===========================================================================
class _Thinking extends StatefulWidget {
  const _Thinking();

  @override
  State<_Thinking> createState() => _ThinkingState();
}

class _ThinkingState extends State<_Thinking>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  /// How long she has been thinking, in whole seconds. Only used to choose
  /// the line, so it ticks once a second rather than every frame.
  int _seconds = 0;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _c.dispose();
    super.dispose();
  }

  String get _line {
    if (_seconds < 3) return 'Lumi is thinking…';
    if (_seconds < 8) return 'Working through it…';
    if (_seconds < 20) return 'This one needs a moment. Still going.';
    return 'Still going — a long answer takes longer.';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GlassSurface(
          tier: GlassTier.raised,
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.md,
            vertical: Gap.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _c,
                builder: (context, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Padding(
                        padding: EdgeInsets.only(right: i == 2 ? 0 : 4),
                        child: Opacity(
                          /* Each dot a third of a cycle behind the last, so
                             the row reads as a wave rather than a blink. */
                          opacity:
                              0.25 +
                              0.75 *
                                  (0.5 +
                                      0.5 *
                                          math.sin(
                                            (_c.value - i / 3) * 2 * math.pi,
                                          )),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: c.hues.violet.ink,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.md),
              Text(_line, style: LipType.caption.copyWith(color: c.text3)),
            ],
          ),
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
                  /* LUMI WRITES MARKDOWN WITH LATEX IN IT, and this drew it
                     as plain text — so a student read literal **bold**,
                     literal ## Step 1, and every formula as raw
                     \frac{-b}{2a} source. Their own messages ARE plain text
                     and stay that way. */
                  if (mine)
                    SelectableText(
                      turn.text,
                      style: LipType.body.copyWith(color: c.text1, height: 1.5),
                    )
                  else ...[
                    LipHtml(
                      lumiToHtml(turn.text),
                      baseStyle: LipType.body.copyWith(
                        color: c.text2,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: Gap.sm),
                    Row(
                      children: [
                        InkWell(
                          onTap: () {
                            /* The MARKDOWN is copied, not the rendered text: a
                               student pasting into their notes wants the bold
                               and the formulae, and a copy that silently drops
                               them is worse than no button. */
                            Clipboard.setData(ClipboardData(text: turn.text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copied'),
                                duration: Duration(milliseconds: 900),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 2,
                              horizontal: 4,
                            ),
                            child: Text(
                              'Copy',
                              style: LipType.caption.copyWith(color: c.text3),
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
        ],
      ),
    );
  }
}

/// ===========================================================================
/// THE FIFTEEN CONVERSATIONS.
///
/// The cap is the SERVER's, so this sheet never has to guess: it asks for a
/// new chat and is told, in a sentence naming the oldest, when the list is
/// full. Nothing is deleted on a student's behalf — a conversation someone
/// was relying on must not vanish because they started another.
/// ===========================================================================
class _ChatsSheet extends ConsumerWidget {
  const _ChatsSheet({
    required this.onOpen,
    required this.onNew,
    required this.onRename,
    required this.onDelete,
  });

  final void Function(LumiChat) onOpen;
  final VoidCallback onNew;
  final Future<void> Function(LumiChat, String) onRename;
  final Future<void> Function(LumiChat) onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;
    final list = ref.watch(lumiChatsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
        child: list.when(
          /* AN ERROR WHILE RELOADING IS STILL AN ERROR.
             An AsyncValue can be in error AND loading at the same time, and
             `when` looks at loading FIRST — so a screen that failed to load sat
             on a pulsing skeleton for ever while the real message ("No
             connection") waited in a state nothing ever drew. These two flags
             say: if we already know something, show it; a reload is not a reason
             to blank the screen or throw away a good answer. */
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const Padding(
            padding: EdgeInsets.all(Gap.lg),
            child: LipSkeleton(height: 160),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Text(
              humanError(e, doing: 'reach Lumi'),
              style: LipType.small.copyWith(color: c.danger),
            ),
          ),
          data: (l) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your conversations',
                      style: LipType.subheading.copyWith(color: c.text1),
                    ),
                  ),
                  Text(
                    '${l.chats.length} of ${l.max}',
                    style: LipType.caption.copyWith(color: c.text3),
                  ),
                ],
              ),
              const SizedBox(height: Gap.sm),
              LipButton(
                label: l.isFull
                    ? 'Delete one to start another'
                    : 'New conversation',
                onPressed: l.isFull ? null : onNew,
              ),
              const SizedBox(height: Gap.md),
              if (l.chats.isEmpty)
                Text(
                  'Nothing yet. Ask Lumi anything and it starts here.',
                  style: LipType.small.copyWith(color: c.text3),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: l.chats.length,
                    itemBuilder: (_, i) {
                      final chat = l.chats[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          chat.title,
                          style: LipType.body.copyWith(color: c.text1),
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => onOpen(chat),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Rename',
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () async {
                                final name = await _ask(context, chat.title);
                                if (name == null || name.trim().isEmpty) return;
                                await onRename(chat, name.trim());
                                ref.invalidate(lumiChatsProvider);
                              },
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: c.danger,
                              ),
                              onPressed: () async {
                                final yes = await showDialog<bool>(
                                  context: context,
                                  builder: (d) => AlertDialog(
                                    title: const Text(
                                      'Delete this conversation?',
                                    ),
                                    content: Text(
                                      '"${chat.title}" and everything in it. '
                                      'This cannot be undone.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(d).pop(false),
                                        child: const Text('Keep'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.of(d).pop(true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (yes != true) return;
                                await onDelete(chat);
                                ref.invalidate(lumiChatsProvider);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<String?> _ask(BuildContext context, String current) {
    final ctrl = TextEditingController(text: current);
    return showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Name this conversation'),
        content: TextField(controller: ctrl, autofocus: true, maxLength: 80),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(d).pop(ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
