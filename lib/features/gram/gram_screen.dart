import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../design/components.dart';
import '../../design/glass.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
    /* POLLED, NOT PUSHED. A socket on a Nigerian mobile connection spends
       more of its life reconnecting than connected, and every reconnection
       is data. Twelve seconds is slow enough to be cheap and quick enough
       that a room feels alive. */
    _poll = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _load(quiet: true),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    try {
      final f = await loadRoom(
        ref.read(apiProvider),
        groupId: widget.room?.id,
        dm: widget.dm,
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
      ref.read(apiProvider),
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
                      itemBuilder: (_, i) => _Line(m: feed.messages[i]),
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
  const _Line({required this.m});
  final GramMessage m;

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
                  SelectableText(
                    m.body,
                    style: LipType.body.copyWith(color: c.text1, height: 1.4),
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
