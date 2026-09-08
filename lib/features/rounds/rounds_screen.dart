import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/components.dart';
import '../../design/glass.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import 'rounds_repository.dart';

/// ===========================================================================
/// THE CHALLENGE · a window with a prize, and the roll of who has won.
///
/// A room the app never had, on a backend that has served it all along.
///
/// When nothing is running the screen SAYS so, warmly, and shows the past
/// winners instead. An empty scoreboard with no explanation reads as broken,
/// and most of the year there genuinely is no round open.
/// ===========================================================================
class RoundsScreen extends ConsumerWidget {
  const RoundsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;
    final view = ref.watch(roundsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('The Challenge')),
      body: SafeArea(
        child: view.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(Gap.lg),
            child: LipSkeleton(height: 220),
          ),
          error: (e, _) => LipError(
            message: '$e',
            onRetry: () => ref.invalidate(roundsProvider),
          ),
          data: (v) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(roundsProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.lg,
                Gap.lg,
                Gap.huge,
              ),
              children: [
                if (v.round == null)
                  GlassSurface(
                    tier: GlassTier.raised,
                    padding: const EdgeInsets.all(Gap.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.emoji_events_outlined,
                          size: 30,
                          color: c.hues.amber.ink,
                        ),
                        const SizedBox(height: Gap.sm),
                        Text(
                          'No challenge is open right now',
                          style: LipType.subheading.copyWith(color: c.text1),
                        ),
                        const SizedBox(height: Gap.xs),
                        Text(
                          'A challenge is a window with a prize — only sittings '
                          'inside its dates count, so everybody starts level on '
                          'the day it opens. Keep practising; the next one '
                          'appears here the moment it does.',
                          style: LipType.small.copyWith(color: c.text3),
                        ),
                      ],
                    ),
                  )
                else
                  _Open(round: v.round!),

                if (v.winners.isNotEmpty) ...[
                  const SizedBox(height: Gap.lg),
                  const LipLabel('The roll'),
                  const SizedBox(height: Gap.sm),
                  for (final w in v.winners)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Gap.sm),
                      child: GlassSurface(
                        tier: GlassTier.raised,
                        padding: const EdgeInsets.all(Gap.md),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 34,
                              child: Text(
                                '#${w.position}',
                                style: LipType.bodyStrong.copyWith(
                                  color: w.position == 1
                                      ? c.hues.amber.ink
                                      : c.text3,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    w.name,
                                    style: LipType.body.copyWith(
                                      color: c.text1,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    [
                                      w.round,
                                      if (w.state.isNotEmpty) w.state,
                                    ].join(' · '),
                                    style: LipType.caption.copyWith(
                                      color: c.text3,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (w.prize.isNotEmpty)
                              Flexible(
                                child: Text(
                                  w.prize,
                                  textAlign: TextAlign.right,
                                  style: LipType.caption.copyWith(
                                    color: c.hues.green.ink,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Open extends StatelessWidget {
  const _Open({required this.round});
  final Round round;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final left = round.daysLeft;

    return GlassSurface(
      hue: c.hues.purple,
      padding: const EdgeInsets.all(Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.emoji_events_rounded,
                size: 26,
                color: c.hues.amber.ink,
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  round.name,
                  style: LipType.title.copyWith(color: c.text1),
                ),
              ),
            ],
          ),
          if (left != null) ...[
            const SizedBox(height: Gap.xs),
            Text(
              left <= 0
                  ? 'Closing today'
                  : '$left day${left == 1 ? '' : 's'} left',
              style: LipType.small.copyWith(color: c.hues.orange.ink),
            ),
          ],
          if (round.description.isNotEmpty) ...[
            const SizedBox(height: Gap.sm),
            Text(
              round.description,
              style: LipType.body.copyWith(color: c.text2),
            ),
          ],
          if (round.prizes.isNotEmpty) ...[
            const SizedBox(height: Gap.lg),
            const LipLabel('Prizes'),
            const SizedBox(height: Gap.sm),
            for (final p in round.prizes)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 34,
                      child: Text(
                        '#${p.position}',
                        style: LipType.bodyStrong.copyWith(
                          color: p.position == 1 ? c.hues.amber.ink : c.text3,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.prize,
                            style: LipType.body.copyWith(color: c.text1),
                          ),
                          if (p.note.isNotEmpty)
                            Text(
                              p.note,
                              style: LipType.caption.copyWith(color: c.text3),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: Gap.md),
          Text(
            'Every sitting you submit while this is open counts towards it. '
            'Nothing to enter.',
            style: LipType.caption.copyWith(color: c.text3),
          ),
        ],
      ),
    );
  }
}
