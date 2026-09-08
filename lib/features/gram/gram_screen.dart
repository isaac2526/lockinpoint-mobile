import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../design/components.dart';
import '../../design/glass.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import 'gram_gate.dart';
import 'gram_repository.dart';

/// ===========================================================================
/// POINTGRAM · study rooms, and the Tutor Line.
///
/// Twelve endpoints the app could not reach, because the identity walk behind
/// them read a cookie and the app carries a bearer token. Every one of them
/// answered 401.
///
/// A ROOM IS NOT A CHAT APP. It is a study room with a tutor in it. Class
/// mode silences students; slow mode paces them; a frozen account reads but
/// does not speak. The SERVER decides all of that, and this screen shows
/// whatever sentence it sends back rather than inventing one from a status
/// code — "Class mode is on, only the tutors can speak for now" is a
/// different thing to a student than "could not send".
/// ===========================================================================
class GramScreen extends ConsumerWidget {
  const GramScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;
    final lobby = ref.watch(gramLobbyProvider);
    final gate = ref.watch(gramGateProvider).value;

    /* A LOCKED ROOM IS A DOOR, NOT A WALL. The app used to answer a lock with
       "ask in class" and no way to act on it, because /api/gram/gate had
       never been called from here. A student who HAS the code could not use
       it. */
    if (gate != null && gate.enabled && gate.locked && !gate.passed) {
      return const _Knock();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Pointgram')),
      body: SafeArea(
        child: lobby.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(Gap.lg),
            child: LipSkeleton(height: 220),
          ),
          error: (e, _) => LipError(
            message: '$e',
            onRetry: () => ref.invalidate(gramLobbyProvider),
          ),
          data: (l) => !l.open
              ? const LipEmpty(
                  icon: Icons.forum_outlined,
                  title: 'The rooms are closed',
                  message:
                      'Pointgram is switched off, or behind a code the tutors '
                      'have set. Ask in class.',
                )
              : RefreshIndicator(
                  onRefresh: () async => ref.invalidate(gramLobbyProvider),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      Gap.lg,
                      Gap.lg,
                      Gap.lg,
                      Gap.huge,
                    ),
                    children: [
                      // The Tutor Line first: it is the one room that is only
                      // ever about this student.
                      _RoomCard(
                        title: 'Tutor Line',
                        subtitle: 'Just you and the tutors',
                        icon: Icons.support_agent_rounded,
                        hue: c.hues.amber,
                        unread: l.dmUnread,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const GramRoomScreen(dm: true),
                          ),
                        ),
                      ),
                      const SizedBox(height: Gap.lg),
                      const LipLabel('Study rooms'),
                      const SizedBox(height: Gap.sm),
                      if (l.rooms.isEmpty)
                        Text(
                          'No rooms are open yet.',
                          style: LipType.small.copyWith(color: c.text3),
                        ),
                      for (final r in l.rooms)
                        _RoomCard(
                          title: r.name,
                          subtitle: r.waiting
                              ? 'Waiting for a tutor to let you in'
                              : r.last.isNotEmpty
                              ? r.last
                              : r.description,
                          icon: r.locked
                              ? Icons.campaign_rounded
                              : Icons.forum_rounded,
                          hue: r.locked ? c.hues.orange : c.hues.pink,
                          unread: r.unread,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => GramRoomScreen(room: r),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.hue,
    required this.unread,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final LipHue hue;
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: GlassSurface(
        hue: hue,
        padding: const EdgeInsets.all(Gap.md),
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 22, color: hue.ink),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: LipType.bodyStrong.copyWith(color: c.text1),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: LipType.caption.copyWith(color: c.text3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (unread > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: c.hues.rose.ink,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Text(
                  '$unread',
                  style: LipType.caption.copyWith(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One room, or the Tutor Line.
class GramRoomScreen extends ConsumerStatefulWidget {
  const GramRoomScreen({super.key, this.room, this.dm = false});
  final GramRoom? room;
  final bool dm;

  @override
  ConsumerState<GramRoomScreen> createState() => _GramRoomScreenState();
}

class _GramRoomScreenState extends ConsumerState<GramRoomScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  GramFeed? _feed;
  String _problem = '';
  bool _busy = false;
  Timer? _poll;
  Timer? _beat;

  /* THE CLIENT IS HELD, NOT LOOKED UP LATE.
     dispose() sends one last heartbeat to say this student has left the room
     — and reading a provider there throws outright:

       Bad state: Using "ref" when a widget is about to or has been unmounted

     which is not a test artefact. It would have fired on a real phone every
     single time a student backed out of a room. Read once while mounted,
     used everywhere after. */
  late final Api _api;

  @override
  void initState() {
    super.initState();
    _api = ref.read(apiProvider);
    _load();
    /* POLLED, NOT PUSHED. A socket on a Nigerian mobile connection spends
       more of its life reconnecting than connected, and every reconnection
       is data. Twelve seconds is slow enough to be cheap and quick enough
       that a room feels alive. */
    _poll = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _load(quiet: true),
    );

    /* THE HEARTBEAT. /api/gram/ping is what puts this student in everyone
       else's Online list and drives the "someone is typing" line — and no
       client on a phone had ever called it, so an app user was invisible in
       a room they were sitting in. The server counts a heartbeat fresh for
       twenty seconds, so fifteen keeps a name from flickering out between
       beats without doubling the traffic. */
    gramPing(_api, groupId: widget.room?.id);
    _beat = Timer.periodic(
      const Duration(seconds: 15),
      (_) => gramPing(_api, groupId: widget.room?.id),
    );
  }

  /// Adds or removes my reaction, then re-reads the room so the count shown
  /// is the server's rather than one the phone guessed at.
  Future<void> _react(String messageId, String icon) async {
    final said = await reactToGram(_api, messageId, icon);
    if (!mounted) return;
    if (said != null) setState(() => _problem = said);
    await _load(quiet: true);
  }

  Future<void> _vote(String messageId, int option) async {
    final said = await voteInGram(_api, messageId, option);
    if (!mounted) return;
    if (said != null) setState(() => _problem = said);
    await _load(quiet: true);
  }

  @override
  void dispose() {
    _poll?.cancel();
    _beat?.cancel();
    /* LEAVING THE ROOM IS ITSELF A STATE. Without this the student stays in
       everyone else's Online list for another forty-five seconds after they
       have gone. */
    gramPing(_api, state: 'away');
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    try {
      /* MY OWN MESSAGES WERE NEVER MINE. loadRoom decides which side of the
         room a bubble sits on by comparing the message's user_id against the
         reader's, and this call had never passed one — so every line a
         student wrote came back looking like a classmate's, on the left, in
         the wrong colour. The identity comes from the gate, which is the one
         place the server states it. */
      final f = await loadRoom(
        _api,
        groupId: widget.room?.id,
        dm: widget.dm,
        myId: ref.read(gramGateProvider).value?.myUid,
      );
      if (!mounted) return;
      setState(() {
        _feed = f;
        if (!quiet) _problem = '';
      });
      _toBottom();
    } on ApiFailure catch (e) {
      if (!mounted || quiet) return;
      setState(() => _problem = e.message);
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _problem = '';
    });
    final refusal = await sendGram(
      _api,
      groupId: widget.room?.id,
      dm: widget.dm,
      body: text,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      // The server's own sentence. "Class mode is on" is a different thing to
      // a student than "could not send".
      _problem = refusal ?? '';
      if (refusal == null) _input.clear();
    });
    if (refusal == null) await _load(quiet: true);
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    }
  });

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final feed = _feed;
    final room = widget.room;
    final canPost = feed?.canPost ?? true;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.dm ? 'Tutor Line' : room?.name ?? 'Room'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (room != null && room.locked)
              Container(
                width: double.infinity,
                color: c.hues.orange.tint,
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.lg,
                  vertical: Gap.sm,
                ),
                child: Text(
                  'Class mode · only the tutors are speaking',
                  style: LipType.caption.copyWith(color: c.hues.orange.ink),
                ),
              ),
            /* WHO IS HERE, AND WHO IS TYPING. Both have ridden in this
               route's response since Pointgram shipped and neither had ever
               been read by the app, so a room with eleven people in it looked
               identical to an empty one. */
            if (feed != null &&
                !widget.dm &&
                (feed.typing.isNotEmpty || feed.online > 0))
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.lg,
                  vertical: 4,
                ),
                child: Text(
                  feed.typing.isNotEmpty
                      ? feed.typing.length == 1
                            ? '${feed.typing.first.username} is '
                                  '${feed.typing.first.state}…'
                            : '${feed.typing.length} people are typing…'
                      : feed.memberCount > 0
                      ? '${feed.online} here now · ${feed.memberCount} in this room'
                      : '${feed.online} here now',
                  style: LipType.label.copyWith(
                    color: feed.typing.isNotEmpty ? c.brand : c.text3,
                  ),
                ),
              ),
            Expanded(
              child: feed == null
                  ? const Padding(
                      padding: EdgeInsets.all(Gap.lg),
                      child: LipSkeleton(height: 200),
                    )
                  : feed.messages.isEmpty
                  ? LipEmpty(
                      icon: Icons.forum_outlined,
                      title: widget.dm ? 'Nothing yet' : 'Quiet in here',
                      message: widget.dm
                          ? 'Ask the tutors anything. Only they can see this.'
                          : 'Be the one who starts it.',
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(
                        Gap.lg,
                        Gap.lg,
                        Gap.lg,
                        Gap.lg,
                      ),
                      itemCount: feed.messages.length,
                      itemBuilder: (_, i) {
                        final m = feed.messages[i];
                        return _Line(
                          m: m,
                          reactions: feed.reactions[m.id] ?? const {},
                          myReaction: feed.myReactions[m.id],
                          votes: feed.votes[m.id] ?? const {},
                          myVote: feed.myVotes[m.id],
                          onReact: (icon) => _react(m.id, icon),
                          onVote: (opt) => _vote(m.id, opt),
                        );
                      },
                    ),
            ),
            if (_problem.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.sm),
                child: LipFormError(message: _problem),
              ),
            if (room != null && !room.joined)
              Padding(
                padding: const EdgeInsets.all(Gap.lg),
                child: LipButton(
                  label: room.waiting
                      ? 'Waiting for a tutor to let you in'
                      : 'Join this room',
                  onPressed: room.waiting
                      ? null
                      : () async {
                          final msg = await joinRoom(
                            ref.read(apiProvider),
                            room.id,
                          );
                          if (!mounted) return;
                          setState(() => _problem = msg ?? '');
                          ref.invalidate(gramLobbyProvider);
                          await _load();
                        },
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        enabled: canPost,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: canPost
                              ? 'Say something…'
                              : feed?.blockedBecause ?? 'Read only',
                        ),
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    IconButton.filled(
                      onPressed: canPost && !_busy ? _send : null,
                      icon: const Icon(Icons.send_rounded),
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

class _Line extends StatelessWidget {
  const _Line({
    required this.m,
    this.reactions = const {},
    this.myReaction,
    this.votes = const {},
    this.myVote,
    this.onReact,
    this.onVote,
  });

  final GramMessage m;
  final Map<String, int> reactions;
  final String? myReaction;
  final Map<int, int> votes;
  final int? myVote;
  final void Function(String icon)? onReact;
  final void Function(int option)? onVote;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    if (m.deleted) {
      return Padding(
        padding: const EdgeInsets.only(bottom: Gap.sm),
        child: Text(
          'This message was deleted',
          style: LipType.caption.copyWith(color: c.text3),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Row(
        mainAxisAlignment: m.mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Flexible(
            child: GlassSurface(
              tier: m.mine ? GlassTier.raised : GlassTier.card,
              // The orange tick. A tutor's word in a study room carries weight
              // and must be distinguishable from a confident classmate's.
              hue: m.tutor ? c.hues.orange : null,
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.md,
                vertical: Gap.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!m.mine)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          m.who,
                          style: LipType.caption.copyWith(
                            color: m.tutor ? c.hues.orange.ink : c.text3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (m.tutor) ...[
                          const SizedBox(width: 3),
                          Icon(
                            Icons.verified_rounded,
                            size: 12,
                            color: c.hues.orange.ink,
                          ),
                        ],
                      ],
                    ),
                  if (m.body.isNotEmpty)
                    SelectableText(
                      m.body,
                      style: LipType.body.copyWith(color: c.text1, height: 1.4),
                    ),
                  /* A POLL IS ANSWERABLE NOW. Its options ride in `meta` and
                     the app used to drop them, so a poll was an empty grey
                     bubble with nothing in it and nothing to do. */
                  if (m.type == 'poll' &&
                      m.options.isNotEmpty &&
                      onVote != null)
                    GramPoll(
                      options: m.options,
                      counts: votes,
                      mine: myVote,
                      onVote: onVote!,
                    ),
                  if (m.type != 'text' &&
                      m.type != 'poll' &&
                      m.mediaUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        m.type == 'voice'
                            ? 'Voice note — open in the browser to play'
                            : 'Attachment — open in the browser to view',
                        style: LipType.label.copyWith(color: c.text3),
                      ),
                    ),
                  if (onReact != null) ...[
                    const SizedBox(height: 4),
                    GramReactions(
                      counts: reactions,
                      mine: myReaction,
                      onTap: onReact!,
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
/// THE DOOR
///
/// Shown only when the server itself says the rooms are locked and this
/// client has not presented the code. The website has always had this box;
/// the app answered the same lock with a sentence and no field, so a student
/// holding the right code could not get in from their phone.
/// ===========================================================================
class _Knock extends ConsumerStatefulWidget {
  const _Knock();

  @override
  ConsumerState<_Knock> createState() => _KnockState();
}

class _KnockState extends ConsumerState<_Knock> {
  final _pin = TextEditingController();
  bool _busy = false;
  String _refusal = '';

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _try() async {
    setState(() {
      _busy = true;
      _refusal = '';
    });
    final said = await ref.read(gramGateProvider.notifier).knock(_pin.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _refusal = said ?? '';
    });
    // The door opened: the lobby behind it is stale by definition.
    if (said == null) ref.invalidate(gramLobbyProvider);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    return Scaffold(
      appBar: AppBar(title: const Text('Pointgram')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.huge, Gap.lg, Gap.lg),
          children: [
            Icon(Icons.lock_rounded, size: 44, color: c.hues.orange.ink),
            const SizedBox(height: Gap.lg),
            Text(
              'The rooms are locked',
              textAlign: TextAlign.center,
              style: LipType.subheading.copyWith(color: c.text1),
            ),
            const SizedBox(height: Gap.sm),
            Text(
              'The tutors set a room code. Type it once and this phone '
              'remembers it until the code is changed.',
              textAlign: TextAlign.center,
              style: LipType.small.copyWith(color: c.text2),
            ),
            const SizedBox(height: Gap.lg),
            TextField(
              controller: _pin,
              enabled: !_busy,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              onSubmitted: (_) => _try(),
              decoration: const InputDecoration(labelText: 'Room code'),
            ),
            if (_refusal.isNotEmpty) ...[
              const SizedBox(height: Gap.md),
              LipFormError(message: _refusal),
            ],
            const SizedBox(height: Gap.lg),
            LipButton(
              label: 'Go in',
              expand: true,
              busy: _busy,
              onPressed: _try,
            ),
          ],
        ),
      ),
    );
  }
}

/// The six icons, drawn. The set is the server's — it refuses anything else —
/// so this map exists to render exactly those and nothing more.
IconData gramReactionIcon(String name) => switch (name) {
  'fire' => Icons.local_fire_department_rounded,
  'star' => Icons.star_rounded,
  'check' => Icons.check_circle_rounded,
  'trophy' => Icons.emoji_events_rounded,
  'diamond' => Icons.diamond_rounded,
  _ => Icons.smart_toy_rounded,
};

/// The reactions already on a message, plus a way to add one. Tapping the
/// icon you already chose takes it back — the server's rule, mirrored here so
/// the app never shows two of mine.
class GramReactions extends StatelessWidget {
  const GramReactions({
    super.key,
    required this.counts,
    required this.mine,
    required this.onTap,
  });

  final Map<String, int> counts;
  final String? mine;
  final void Function(String icon) onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    return Wrap(
      spacing: Gap.sm,
      runSpacing: 4,
      children: [
        for (final icon in gramReactionIcons)
          if ((counts[icon] ?? 0) > 0 || icon == mine)
            InkWell(
              onTap: () => onTap(icon),
              borderRadius: BorderRadius.circular(Radii.pill),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: icon == mine ? c.brandSoft : c.glassDeep,
                  borderRadius: BorderRadius.circular(Radii.pill),
                  border: Border.all(
                    color: icon == mine ? c.brand : c.glassBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      gramReactionIcon(icon),
                      size: 13,
                      color: icon == mine ? c.brand : c.text3,
                    ),
                    if ((counts[icon] ?? 0) > 0) ...[
                      const SizedBox(width: 3),
                      Text(
                        '${counts[icon]}',
                        style: LipType.label.copyWith(
                          color: icon == mine ? c.brand : c.text3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        // The way in when nothing has been reacted to yet.
        InkWell(
          onTap: () => _pick(context),
          borderRadius: BorderRadius.circular(Radii.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Icon(Icons.add_reaction_outlined, size: 14, color: c.text3),
          ),
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final icon in gramReactionIcons)
                IconButton(
                  iconSize: 26,
                  icon: Icon(gramReactionIcon(icon)),
                  onPressed: () => Navigator.of(sheet).pop(icon),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) onTap(chosen);
  }
}

/// A poll, with its bars and its vote. The website has always sent a poll's
/// options inside `meta`; the app dropped them, so a poll arrived as an empty
/// grey bubble that could not be answered.
class GramPoll extends StatelessWidget {
  const GramPoll({
    super.key,
    required this.options,
    required this.counts,
    required this.mine,
    required this.onVote,
  });

  final List<String> options;
  final Map<int, int> counts;
  final int? mine;
  final void Function(int option) onVote;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < options.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: InkWell(
              onTap: () => onVote(i),
              borderRadius: BorderRadius.circular(Radii.sm),
              child: Stack(
                children: [
                  // The bar behind the words, so a share is read at a glance
                  // rather than counted.
                  Positioned.fill(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: total == 0 ? 0 : (counts[i] ?? 0) / total,
                      child: Container(
                        decoration: BoxDecoration(
                          color: i == mine ? c.brandSoft : c.glassDeep,
                          borderRadius: BorderRadius.circular(Radii.sm),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Gap.sm,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        if (i == mine) ...[
                          Icon(
                            Icons.check_circle_rounded,
                            size: 13,
                            color: c.brand,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            options[i],
                            style: LipType.small.copyWith(
                              color: c.text1,
                              fontWeight: i == mine
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          '${counts[i] ?? 0}',
                          style: LipType.label.copyWith(color: c.text3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 4),
        Text(
          total == 1 ? 'One vote' : '$total votes',
          style: LipType.label.copyWith(color: c.text3),
        ),
      ],
    );
  }
}
