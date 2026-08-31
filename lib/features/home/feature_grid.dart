import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/glass.dart';
import '../../design/motion_widgets.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../content/content_repository.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../practice/practice_flow_screen.dart';
import '../progress/analysis_screen.dart';
import '../progress/results_screen.dart';
import '../search/search_screen.dart';
import '../vault/vault_screen.dart';
import 'feature_catalogue.dart';

/// ===========================================================================
/// THE GRID
///
/// Two columns of tiles, each in its own colour.
///
/// The old home was a vertical list of identical blue rows, and a student
/// scanning it had to READ every one to find anything. Colour does that work
/// instead: after a week the eye goes straight to violet for the classroom
/// and pink for the leaderboard without the labels being read at all.
///
/// Titles, colours, order and badges can all be overridden from the admin
/// panel — but the defaults live in the app, so the grid is right on a first
/// launch before anyone has configured a single row.
/// ===========================================================================
class FeatureGrid extends ConsumerWidget {
  const FeatureGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiles = ref.watch(featureTilesProvider).value ?? const [];
    final features = mergeFeatureTiles(tiles);

    return LayoutBuilder(
      builder: (context, box) {
        /* Two columns on a phone, more when there is genuinely room — a
           tablet or the web build. The tile keeps its proportions rather
           than stretching into a letterbox. */
        final columns = box.maxWidth > 720 ? 4 : (box.maxWidth > 520 ? 3 : 2);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: Gap.md,
            crossAxisSpacing: Gap.md,
            childAspectRatio: 0.92,
          ),
          itemCount: features.length,
          itemBuilder: (context, i) => Entrance(
            index: i + 3,
            child: FeatureTile(feature: features[i]),
          ),
        );
      },
    );
  }
}

class FeatureTile extends StatelessWidget {
  const FeatureTile({super.key, required this.feature});
  final Feature feature;

  /// Where a tile goes. A feature whose backend the app cannot reach yet says
  /// so plainly instead of opening a screen that will only apologise.
  void _open(BuildContext context) {
    final Widget? destination = switch (feature.key) {
      'practice' => const PracticeFlowScreen(),
      'search' => const SearchScreen(),
      'leaderboard' => const LeaderboardScreen(),
      'history' => const ResultsScreen(),
      'analysis' => const AnalysisScreen(),
      'vault' => const VaultScreen(),
      _ => null,
    };
    if (destination != null) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => destination));
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('${feature.title} arrives in the next build.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final hue = feature.hue.of(c);
    final dim = !feature.ready;

    return GlassSurface(
      hue: hue,
      padding: const EdgeInsets.all(Gap.md),
      onTap: () => _open(context),
      semanticLabel:
          '${feature.title}. ${feature.subtitle}'
          '${feature.badge.isNotEmpty ? '. ${feature.badge}' : ''}'
          '${dim ? '. Coming soon' : ''}',
      child: Opacity(
        opacity: dim ? 0.62 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    // A stronger wash of the tile's own ink, so the glyph sits
                    // on its colour rather than floating on the fill.
                    color: hue.ink.withValues(alpha: c.isDark ? 0.20 : 0.13),
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  child: Icon(feature.icon, size: 23, color: hue.ink),
                ),
                const Spacer(),
                if (feature.badge.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Gap.sm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: c.hues.orange.ink,
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                    child: Text(
                      feature.badge.toUpperCase(),
                      style: LipType.label.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                  )
                else if (dim)
                  Text('SOON', style: LipType.label.copyWith(color: hue.ink)),
              ],
            ),
            const Spacer(),
            Text(
              feature.title,
              style: LipType.subheading.copyWith(color: hue.ink),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              feature.subtitle,
              style: LipType.small.copyWith(color: c.text2),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
