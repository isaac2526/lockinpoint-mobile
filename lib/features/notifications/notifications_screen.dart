import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../design/components.dart';
import '../../design/glass.dart';
import '../../design/motion_widgets.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../home/feature_catalogue.dart';

/// ===========================================================================
/// NOTIFICATIONS
///
/// The same feed the website's bell shows, from the same route, counted the
/// same way. There is one notification system and this is its phone screen.
///
/// A notice is TYPED, and the type does real work: it chooses the icon and
/// the colour, so a student can tell a results announcement from a quote of
/// the day before reading a word. It can carry an attribution, an image and
/// any number of buttons — all of it admin-managed, so a feature tour is a
/// row somebody typed rather than a tutorial screen somebody shipped.
/// ===========================================================================
class NoticeFeed extends AsyncNotifier<Map<String, dynamic>> {
  @override
  Future<Map<String, dynamic>> build() async =>
      ref.read(apiProvider).get('/api/notices/pending');

  Future<void> refresh() async {
    try {
      state = AsyncData(
        await ref.read(apiProvider).get('/api/notices/pending'),
      );
    } on ApiFailure catch (e, st) {
      if (!state.hasValue) state = AsyncError(e, st);
    }
  }

  /// Mark everything currently shown as read. The server writes one
  /// acknowledgement per notice — the same ones the bell counts — so the
  /// badge really does clear.
  Future<void> markAllRead() async {
    try {
      await ref.read(apiProvider).post('/api/announcements');
      await refresh();
    } on ApiFailure {
      // A badge that fails to clear is not worth an error screen.
    }
  }
}

final noticeFeedProvider =
    AsyncNotifierProvider<NoticeFeed, Map<String, dynamic>>(NoticeFeed.new);

/// How many are unread, for the bell. Never throws and never blocks a screen.
final unreadCountProvider = Provider<int>((ref) {
  final v = ref.watch(noticeFeedProvider).value;
  return (v?['count'] as num?)?.toInt() ?? 0;
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(noticeFeedProvider);
    final unread = ref.watch(unreadCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () =>
                  ref.read(noticeFeedProvider.notifier).markAllRead(),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(noticeFeedProvider.notifier).refresh(),
          child: feed.when(
            loading: () => ListView(
              padding: const EdgeInsets.all(Gap.lg),
              children: const [
                LipSkeleton(height: 120),
                SizedBox(height: Gap.md),
                LipSkeleton(height: 120),
                SizedBox(height: Gap.md),
                LipSkeleton(height: 120),
              ],
            ),
            error: (e, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.sizeOf(context).height * 0.15),
                LipError(
                  message: e is ApiFailure
                      ? e.message
                      : 'Pull down to try again.',
                  onRetry: () =>
                      ref.read(noticeFeedProvider.notifier).refresh(),
                ),
              ],
            ),
            data: (d) {
              final items = ((d['items'] as List?) ?? const [])
                  .whereType<Map>()
                  .map((m) => m.cast<String, dynamic>())
                  .toList();

              if (items.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
                    const LipEmpty(
                      icon: Icons.notifications_none_rounded,
                      title: 'Nothing yet',
                      message:
                          'Results, announcements and updates from the '
                          'LockInPoint team will appear here.',
                    ),
                  ],
                );
              }

              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  Gap.lg,
                  Gap.lg,
                  Gap.lg,
                  Gap.huge,
                ),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
                itemBuilder: (context, i) =>
                    Entrance(index: i, child: _NoticeCard(items[i])),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The type decides the colour and the glyph, so the feed is scannable before
/// it is readable.
({IconData icon, FeatureHue hue}) noticeLook(String kind) => switch (kind) {
  'news' => (icon: Icons.newspaper_rounded, hue: FeatureHue.indigo),
  'update' => (icon: Icons.system_update_rounded, hue: FeatureHue.teal),
  'quote' => (icon: Icons.format_quote_rounded, hue: FeatureHue.violet),
  'winners' => (icon: Icons.emoji_events_rounded, hue: FeatureHue.amber),
  'tour' => (icon: Icons.explore_rounded, hue: FeatureHue.green),
  'promo' => (icon: Icons.local_offer_rounded, hue: FeatureHue.pink),
  _ => (icon: Icons.campaign_rounded, hue: FeatureHue.blue),
};

class _NoticeCard extends StatelessWidget {
  const _NoticeCard(this.n);
  final Map<String, dynamic> n;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final kind = n['kind'] as String? ?? 'announcement';
    final look = noticeLook(kind);
    final hue = look.hue.of(c);
    final seen = n['seen'] == true;
    final actions = ((n['actions'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => m.cast<String, dynamic>())
        .toList();
    final attribution = (n['attribution'] as String? ?? '').trim();

    return GlassSurface(
      tier: GlassTier.card,
      // Read notices step back rather than disappearing: the feed is a record,
      // not an inbox to be emptied.
      selected: !seen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: hue.tint,
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: Icon(look.icon, size: 20, color: hue.ink),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n['title'] as String? ?? '',
                      style: LipType.subheading.copyWith(color: c.text1),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _ago(n['created_at'] as String?),
                      style: LipType.caption.copyWith(color: c.text3),
                    ),
                  ],
                ),
              ),
              if (!seen)
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: hue.ink,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),

          if ((n['body'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(height: Gap.md),
            _Body(n['body'] as String),
          ],

          if (attribution.isNotEmpty) ...[
            const SizedBox(height: Gap.sm),
            Text(
              attribution,
              style: LipType.smallStrong.copyWith(color: c.text2),
            ),
          ],

          if (actions.isNotEmpty) ...[
            const SizedBox(height: Gap.md),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: [
                for (final a in actions)
                  OutlinedButton(
                    onPressed: () => _go(context, a['target'] as String? ?? ''),
                    child: Text(a['label'] as String? ?? 'Open'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// An internal route or an external link — the target says which by whether
  /// it carries a scheme, so one admin field serves both.
  void _go(BuildContext context, String target) {
    if (target.isEmpty) return;
    final uri = Uri.tryParse(target);
    if (uri != null && uri.hasScheme) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Opening $target')));
  }

  static String _ago(String? iso) {
    if (iso == null) return '';
    final t = DateTime.tryParse(iso);
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) {
      return '${d.inHours} hr${d.inHours == 1 ? '' : 's'} ago';
    }
    if (d.inDays < 7) return '${d.inDays} day${d.inDays == 1 ? '' : 's'} ago';
    return '${t.day}/${t.month}/${t.year}';
  }
}

/// A very small markdown renderer: bold runs, bullet and numbered lines, and
/// blank lines as paragraph breaks.
///
/// Deliberately not a markdown package. The bodies an admin writes are short
/// and this handles what they actually use, without adding a dependency —
/// and anything it does not understand still renders as its own plain text
/// rather than as a wall of asterisks.
class _Body extends StatelessWidget {
  const _Body(this.raw);
  final String raw;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final lines = raw.replaceAll('\r\n', '\n').split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          if (line.trim().isEmpty)
            const SizedBox(height: Gap.sm)
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text.rich(
                _inline(line, c.text2),
                style: LipType.body.copyWith(color: c.text2),
              ),
            ),
      ],
    );
  }

  /// **bold** becomes bold. Everything else is left exactly as typed.
  static TextSpan _inline(String line, Color colour) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    var at = 0;
    for (final m in pattern.allMatches(line)) {
      if (m.start > at) {
        spans.add(TextSpan(text: line.substring(at, m.start)));
      }
      spans.add(
        TextSpan(
          text: m.group(1),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      at = m.end;
    }
    if (at < line.length) {
      spans.add(TextSpan(text: line.substring(at)));
    }
    return TextSpan(children: spans);
  }
}
