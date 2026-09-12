import '../../core/json.dart';
import '../../app/shell.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../design/components.dart';
import '../../design/glass.dart';
import '../../design/motion_widgets.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';

/// One rung of the ladder, as the server ranks it.
///
/// Every field here is one the route has always sent and the phone has always
/// thrown away. `/api/leaderboard` shapes a row with a state, a country, a
/// school, a last-seen and a longest streak; this model read four keys out of
/// thirteen, so the board on the phone was a name and a number where the same
/// board in a browser was a person.
class LadderRow {
  const LadderRow({
    required this.rank,
    required this.userId,
    required this.name,
    required this.points,
    required this.streak,
    required this.longestStreak,
    required this.minutes,
    required this.country,
    required this.state,
    required this.institution,
    required this.lastSeen,
    required this.isMe,
  });

  final int rank;
  final String userId;
  final String name;
  final int points;

  /// The streak running right now. It dies the day it is broken.
  final int streak;

  /// The best one ever reached. Worth showing precisely because the live one
  /// takes the record with it when it goes — a 2-day streak beside a 31-day
  /// record reads as a stumble, and a bare 2 reads as a beginner.
  final int longestStreak;

  final int minutes;
  final String country;
  final String state;
  final String institution;

  /// Already coarsened by the server — "now", "3h ago", "yesterday". The
  /// phone never sees a timestamp, so it cannot publish one by accident.
  final String lastSeen;

  final bool isMe;

  static LadderRow fromJson(Map<String, dynamic> j) => LadderRow(
    rank: asInt(j['rank']),
    userId: asText(j['userId']),
    name: asText(j['name'], 'Student'),
    points: asInt(j['points']),
    streak: asInt(j['streak']),
    longestStreak: asInt(j['longestStreak']),
    minutes: asInt(j['minutes']),
    country: asText(j['country']),
    state: asText(j['state']),
    institution: asText(j['institution']),
    lastSeen: asText(j['lastSeen']),
    isMe: j['isMe'] == true,
  );

  /// The one line under the name: where this student is, and when they were
  /// last here. Empty parts are dropped rather than left as stray separators.
  String get place => [
    state,
    if (state.isEmpty) country,
    institution,
  ].where((s) => s.trim().isNotEmpty).join(' · ');
}

/// Which slice of the world is being ranked. The server decides which of
/// these a given student may ask for — a student with no state on their
/// profile cannot narrow to one, so that tab arrives unavailable rather than
/// arriving and then returning nothing.
class LadderScope {
  const LadderScope({
    required this.key,
    required this.label,
    required this.available,
  });

  final String key;
  final String label;
  final bool available;

  static LadderScope fromJson(Map<String, dynamic> j) => LadderScope(
    key: asText(j['key'], 'national'),
    label: asText(j['label'], 'National'),
    available: j['available'] == true,
  );
}

/// A whole board: its rungs, this student's own rung wherever it sits, how
/// many people are on it, and which other slices they may look at.
class Ladder {
  const Ladder({
    required this.rows,
    required this.me,
    required this.scopes,
    required this.total,
    required this.message,
  });

  final List<LadderRow> rows;

  /// This student's row EVEN WHEN IT IS NOT IN THE TOP HUNDRED. Being
  /// 4,312th is information; a blank space is not.
  final LadderRow? me;

  final List<LadderScope> scopes;
  final int total;

  /// Set when the board could not be built. An empty board and a broken
  /// board must not look the same — the route is careful about this and the
  /// phone must be too.
  final String message;

  static const empty = Ladder(
    rows: [],
    me: null,
    scopes: [],
    total: 0,
    message: '',
  );
}

class LeaderboardRepository {
  LeaderboardRepository(this._api);
  final Api _api;

  Future<Ladder> board(String scope) async {
    final res = await _api.get(
      '/api/leaderboard',
      query: {if (scope.isNotEmpty) 'scope': scope},
    );
    final rows = ((res['rows'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => LadderRow.fromJson(m.cast<String, dynamic>()))
        .toList();
    final meJson = (res['me'] as Map?)?.cast<String, dynamic>();
    return Ladder(
      rows: rows,
      me: meJson == null ? null : LadderRow.fromJson(meJson),
      scopes: ((res['scopes'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => LadderScope.fromJson(m.cast<String, dynamic>()))
          .toList(),
      total: asIntOrNull(res['total']) ?? rows.length,
      message: res['ok'] == false ? (asText(res['message'])) : '',
    );
  }
}

final leaderboardRepositoryProvider = Provider(
  (ref) => LeaderboardRepository(ref.watch(apiProvider)),
);

/// Which slice is being looked at. Kept outside the future so switching tabs
/// does not tear the screen down and rebuild it from a spinner.
class LadderScopeChoice extends Notifier<String> {
  @override
  String build() => 'national';

  void choose(String key) => state = key;
}

final ladderScopeProvider = NotifierProvider<LadderScopeChoice, String>(
  LadderScopeChoice.new,
);

final leaderboardProvider = FutureProvider.autoDispose<Ladder>(
  (ref) => ref
      .watch(leaderboardRepositoryProvider)
      .board(ref.watch(ladderScopeProvider)),
);

/// ===========================================================================
/// THE LEADERBOARD
///
/// The website's own points law, unchanged and stated on the screen so the
/// ladder is never mysterious: ten a correct answer, twenty five a finished
/// sitting, a hundred for each day of a live streak, five for showing up.
///
/// Ranking is entirely the server's. The phone sorts nothing and computes no
/// points, so the app and the website can never show a student two different
/// positions.
/// ===========================================================================
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key, this.embedded = false});

  /// True when this screen is a TAB inside the shell rather than a pushed
  /// route. An embedded screen drops its own app bar and back button — two
  /// headers stacked on one screen is the fastest way to make an app feel
  /// like a collection of pages instead of one product.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(leaderboardProvider);
    return Scaffold(
      /* AN EMBEDDED TAB STILL NEEDS THE MENU. Dropping the AppBar
         entirely left Ranking and Profile with no way into the drawer at
         all — not even a dead button — so two of the four tabs simply had
         no menu. It keeps a bar with the hamburger and no back arrow. */
      appBar: AppBar(
        title: const Text('Leaderboard'),
        automaticallyImplyLeading: !embedded,
        leading: embedded
            ? IconButton(
                onPressed: openAppMenu,
                icon: const Icon(Icons.menu_rounded),
                tooltip: 'Menu',
              )
            : null,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(leaderboardProvider),
          child: board.when(
            loading: () => ListView(
              padding: const EdgeInsets.all(Gap.md),
              children: const [
                LipSkeleton(height: 64),
                SizedBox(height: Gap.sm),
                LipSkeleton(height: 64),
                SizedBox(height: Gap.sm),
                LipSkeleton(height: 64),
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
                  detail: e is ApiFailure ? e.detail : null,
                  onRetry: () => ref.invalidate(leaderboardProvider),
                ),
              ],
            ),
            data: (l) => _Board(board: l),
          ),
        ),
      ),
    );
  }
}

class _Board extends ConsumerWidget {
  const _Board({required this.board});
  final Ladder board;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(ladderScopeProvider);
    final me = board.me;

    /// My own rung is repeated at the bottom only when it is NOT already on
    /// screen. Showing it twice is worse than not showing it at all.
    final meIsListed = me != null && board.rows.any((r) => r.isMe);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(Gap.md),
      children: [
        if (board.scopes.isNotEmpty) ...[
          _Scopes(scopes: board.scopes, chosen: scope),
          const SizedBox(height: Gap.md),
        ],
        if (board.message.isNotEmpty) ...[
          LipFormError(message: board.message),
          const SizedBox(height: Gap.md),
        ] else if (board.total > 0) ...[
          Text(
            board.total == 1
                ? 'One student on this board'
                : '${board.total} students on this board',
            style: LipType.small.copyWith(color: context.lip.text3),
          ),
          const SizedBox(height: Gap.md),
        ],
        if (board.rows.isEmpty && board.message.isEmpty)
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.sizeOf(context).height * 0.10,
            ),
            child: const LipEmpty(
              icon: Icons.emoji_events_rounded,
              title: 'The ladder is empty',
              message: 'Nobody has sat a paper yet. Be the first name on it.',
            ),
          ),
        for (var i = 0; i < board.rows.length; i++) ...[
          Entrance.inList(
            index: i,
            child: _Rung(row: board.rows[i]),
          ),
          const SizedBox(height: Gap.sm),
        ],
        if (me != null && !meIsListed) ...[
          const SizedBox(height: Gap.md),
          const LipLabel('Where you are'),
          const SizedBox(height: Gap.sm),
          _Rung(row: me),
        ],
        const _PointsLaw(),
      ],
    );
  }
}

/// National, my country, my state, my school. A scope the server marked
/// unavailable is shown greyed rather than hidden, because its absence is
/// itself the message: fill in your state and this board appears.
class _Scopes extends ConsumerWidget {
  const _Scopes({required this.scopes, required this.chosen});
  final List<LadderScope> scopes;
  final String chosen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final s in scopes) ...[
            Opacity(
              opacity: s.available ? 1 : 0.45,
              child: LipChip(
                s.label,
                selected: s.key == chosen,
                onTap: s.available
                    ? () => ref.read(ladderScopeProvider.notifier).choose(s.key)
                    : () => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            s.key == 'state'
                                ? 'Add your state on your profile and this '
                                      'board opens.'
                                : s.key == 'school'
                                ? 'Add your school on your profile and this '
                                      'board opens.'
                                : 'Not available yet.',
                            style: LipType.small.copyWith(color: c.text1),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: Gap.sm),
          ],
        ],
      ),
    );
  }
}

class _Rung extends StatelessWidget {
  const _Rung({required this.row});
  final LadderRow row;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final top3 = row.rank <= 3;
    final place = row.place;

    return GlassSurface(
      tier: top3 || row.isMe ? GlassTier.raised : GlassTier.card,
      seam: row.rank == 1,
      selected: row.isMe,
      padding: const EdgeInsets.all(Gap.md),
      semanticLabel:
          'Rank ${row.rank}, ${row.name}, ${row.points} points'
          '${place.isEmpty ? "" : ", $place"}'
          '${row.streak > 0 ? ", ${row.streak} day streak" : ""}'
          '${row.longestStreak > row.streak ? ", best ${row.longestStreak} days" : ""}'
          '${row.lastSeen.isEmpty ? "" : ", last seen ${row.lastSeen}"}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 38,
            child: top3
                ? Icon(
                    Icons.emoji_events_rounded,
                    size: 22,
                    color: switch (row.rank) {
                      1 => c.gold,
                      2 => c.text2,
                      _ => c.warning,
                    },
                  )
                : Text(
                    '${row.rank}',
                    style: LipType.mono.copyWith(color: c.text3),
                  ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        row.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: (top3 ? LipType.bodyStrong : LipType.body)
                            .copyWith(color: c.text1),
                      ),
                    ),
                    if (row.isMe) ...[
                      const SizedBox(width: Gap.sm),
                      Text(
                        'you',
                        style: LipType.label.copyWith(color: c.brand),
                      ),
                    ],
                  ],
                ),
                if (place.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      place,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LipType.label.copyWith(color: c.text3),
                    ),
                  ),
                if (row.lastSeen.isNotEmpty || row.longestStreak > row.streak)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      [
                        if (row.lastSeen.isNotEmpty) row.lastSeen,
                        if (row.longestStreak > row.streak)
                          'best ${row.longestStreak}d',
                      ].join(' · '),
                      style: LipType.label.copyWith(color: c.text3),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Gap.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${row.points}',
                style: LipType.mono.copyWith(color: top3 ? c.brand : c.text2),
              ),
              if (row.streak > 0)
                Text(
                  '${row.streak}d streak',
                  style: LipType.label.copyWith(color: c.accent),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The ladder is stated, not hidden. A student who knows how points are earned
/// can go and earn them.
class _PointsLaw extends StatelessWidget {
  const _PointsLaw();

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    const law = [
      ('Every correct answer', '10'),
      ('Every sitting you finish', '25'),
      ('Each day of a live streak', '100'),
      ('Opening the app', '5'),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: Gap.lg),
      child: GlassSurface(
        tier: GlassTier.deep,
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LipLabel('How points are earned'),
            const SizedBox(height: Gap.md),
            for (final (what, n) in law)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        what,
                        style: LipType.small.copyWith(color: c.text2),
                      ),
                    ),
                    Text(n, style: LipType.mono.copyWith(color: c.brand)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
