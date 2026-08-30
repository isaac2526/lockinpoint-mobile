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
class LadderRow {
  const LadderRow({
    required this.rank,
    required this.name,
    required this.points,
    required this.streak,
  });

  final int rank;
  final String name;
  final int points;
  final int streak;

  static LadderRow fromJson(Map<String, dynamic> j) => LadderRow(
    rank: (j['rank'] as num?)?.toInt() ?? 0,
    name: j['name'] as String? ?? 'Student',
    points: (j['points'] as num?)?.toInt() ?? 0,
    streak: (j['streak'] as num?)?.toInt() ?? 0,
  );
}

class LeaderboardRepository {
  LeaderboardRepository(this._api);
  final Api _api;

  Future<List<LadderRow>> top() async {
    final res = await _api.get('/api/leaderboard');
    return ((res['rows'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(LadderRow.fromJson)
        .toList();
  }
}

final leaderboardRepositoryProvider = Provider(
  (ref) => LeaderboardRepository(ref.watch(apiProvider)),
);

final leaderboardProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(leaderboardRepositoryProvider).top(),
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
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(leaderboardProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(leaderboardProvider),
          child: rows.when(
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
                  onRetry: () => ref.invalidate(leaderboardProvider),
                ),
              ],
            ),
            data: (list) => list.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.15,
                      ),
                      const LipEmpty(
                        icon: Icons.emoji_events_rounded,
                        title: 'The ladder is empty',
                        message: 'Nobody has sat a paper yet. Be the first name on it.',
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(Gap.md),
                    itemCount: list.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: Gap.sm),
                    itemBuilder: (context, i) => i == list.length
                        ? const _PointsLaw()
                        : Entrance(
                            index: i,
                            child: _Rung(row: list[i]),
                          ),
                  ),
          ),
        ),
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
    return GlassSurface(
      tier: top3 ? GlassTier.raised : GlassTier.card,
      seam: row.rank == 1,
      padding: const EdgeInsets.all(Gap.md),
      semanticLabel:
          'Rank ${row.rank}, ${row.name}, ${row.points} points'
          '${row.streak > 0 ? ", ${row.streak} day streak" : ""}',
      child: Row(
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
            child: Text(
              row.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (top3 ? LipType.bodyStrong : LipType.body).copyWith(
                color: c.text1,
              ),
            ),
          ),
          if (row.streak > 0) ...[
            Text(
              '${row.streak}d',
              style: LipType.caption.copyWith(color: c.accent),
            ),
            const SizedBox(width: Gap.sm),
          ],
          Text(
            '${row.points}',
            style: LipType.mono.copyWith(color: top3 ? c.brand : c.text2),
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
