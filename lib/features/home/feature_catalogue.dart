import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// ===========================================================================
/// WHAT LOCKINPOINT DOES, AND WHAT COLOUR EACH OF IT IS
///
/// One list, because a feature that exists in three places drifts in three
/// directions. The home grid, the drawer and the bottom bar all read from
/// here, so renaming Classroom renames it everywhere.
///
/// COLOUR CARRIES MEANING. Every tile owns a hue from the twelve-colour
/// palette and keeps it for life — practice is always blue, the classroom is
/// always violet, the leaderboard is always pink. A student learns the
/// colours without being taught them, and after a week they stop reading the
/// labels. That is the whole point of giving twelve features twelve colours
/// rather than painting them all in the brand blue.
///
/// `ready` is honest. A tile whose backend the app cannot reach yet says so
/// when tapped rather than opening an empty screen and blaming the network.
/// ===========================================================================
enum FeatureHue {
  blue,
  indigo,
  violet,
  purple,
  pink,
  rose,
  orange,
  amber,
  lime,
  green,
  teal,
  slate,
}

extension FeatureHueX on FeatureHue {
  LipHue of(LipColors c) => switch (this) {
    FeatureHue.blue => c.hues.blue,
    FeatureHue.indigo => c.hues.indigo,
    FeatureHue.violet => c.hues.violet,
    FeatureHue.purple => c.hues.purple,
    FeatureHue.pink => c.hues.pink,
    FeatureHue.rose => c.hues.rose,
    FeatureHue.orange => c.hues.orange,
    FeatureHue.amber => c.hues.amber,
    FeatureHue.lime => c.hues.lime,
    FeatureHue.green => c.hues.green,
    FeatureHue.teal => c.hues.teal,
    FeatureHue.slate => c.hues.slate,
  };

  static FeatureHue parse(String? name) => FeatureHue.values.firstWhere(
    (h) => h.name == name,
    orElse: () => FeatureHue.blue,
  );
}

@immutable
class Feature {
  const Feature({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.hue,
    this.ready = true,
    this.badge = '',
  });

  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final FeatureHue hue;

  /// False while the app cannot yet reach this feature's backend.
  final bool ready;

  /// "NEW", "BETA" — admin-settable through `feature_tiles`.
  final String badge;

  Feature copyWith({
    String? title,
    String? subtitle,
    String? badge,
    FeatureHue? hue,
  }) => Feature(
    key: key,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    icon: icon,
    hue: hue ?? this.hue,
    ready: ready,
    badge: badge ?? this.badge,
  );
}

/// The app's own grid. `feature_tiles` in the admin panel can rename, recolour,
/// reorder, badge or hide any of these — but the app works before anyone has
/// configured a single row, which is why the defaults live here.
const kFeatures = <Feature>[
  Feature(
    key: 'practice',
    title: 'Practice & CBT',
    subtitle: 'Real past questions, timed or open',
    icon: Icons.rocket_launch_rounded,
    hue: FeatureHue.blue,
  ),
  Feature(
    key: 'classroom',
    title: 'Classroom',
    subtitle: 'Notes, materials and video lessons',
    icon: Icons.auto_stories_rounded,
    hue: FeatureHue.violet,
    ready: false,
  ),
  Feature(
    key: 'search',
    title: 'Question search',
    subtitle: 'Find any question, fast',
    icon: Icons.search_rounded,
    hue: FeatureHue.slate,
  ),
  Feature(
    key: 'history',
    title: 'Result history',
    subtitle: 'Every paper you have sat',
    icon: Icons.receipt_long_rounded,
    hue: FeatureHue.green,
  ),
  Feature(
    key: 'analysis',
    title: 'Performance analysis',
    subtitle: 'Where your marks are going',
    icon: Icons.insights_rounded,
    hue: FeatureHue.indigo,
  ),
  Feature(
    key: 'games',
    title: 'Games arena',
    subtitle: 'Blitz, Survival, The Climb',
    icon: Icons.sports_esports_rounded,
    hue: FeatureHue.purple,
    ready: false,
  ),
  Feature(
    key: 'challenge',
    title: 'Challenge',
    subtitle: 'Compete for prizes',
    icon: Icons.emoji_events_rounded,
    hue: FeatureHue.amber,
    ready: false,
  ),
  Feature(
    key: 'leaderboard',
    title: 'Leaderboard',
    subtitle: 'Your rank, nationally and locally',
    icon: Icons.leaderboard_rounded,
    hue: FeatureHue.pink,
  ),
  Feature(
    key: 'bookmarks',
    title: 'Saved questions',
    subtitle: 'Everything you kept',
    icon: Icons.bookmark_rounded,
    hue: FeatureHue.lime,
    ready: false,
  ),
  Feature(
    key: 'vault',
    title: 'Offline vault',
    subtitle: 'Downloaded questions, no signal needed',
    icon: Icons.offline_bolt_rounded,
    hue: FeatureHue.teal,
  ),
  Feature(
    key: 'career',
    title: 'Career & institutions',
    subtitle: 'Courses, schools and cut-offs',
    icon: Icons.school_rounded,
    hue: FeatureHue.orange,
    ready: false,
  ),
  Feature(
    key: 'tutor',
    title: 'Ask Lumi',
    subtitle: 'Your AI tutor, any question',
    icon: Icons.smart_toy_rounded,
    hue: FeatureHue.rose,
    ready: false,
  ),
];

/// Backend tiles name their icon as a string. This is the only place that
/// turns one into a glyph, so an unknown name degrades to a sensible default
/// rather than crashing a home screen.
IconData iconNamed(String? name, IconData fallback) => switch (name) {
  'practice' || 'rocket' => Icons.rocket_launch_rounded,
  'classroom' || 'book' => Icons.auto_stories_rounded,
  'search' => Icons.search_rounded,
  'notes' || 'science' => Icons.science_rounded,
  'history' || 'receipt' => Icons.receipt_long_rounded,
  'analysis' || 'chart' => Icons.insights_rounded,
  'games' => Icons.sports_esports_rounded,
  'trophy' || 'challenge' => Icons.emoji_events_rounded,
  'leaderboard' => Icons.leaderboard_rounded,
  'bookmark' => Icons.bookmark_rounded,
  'school' || 'career' => Icons.school_rounded,
  'robot' || 'tutor' => Icons.smart_toy_rounded,
  'key' => Icons.vpn_key_rounded,
  'wallet' || 'activation' => Icons.account_balance_wallet_rounded,
  _ => fallback,
};

/// The app's defaults, with any admin overrides applied on top.
///
/// A row in `feature_tiles` may rename a tile, recolour it, badge it, reorder
/// it or remove it. A row whose key the app does not know is IGNORED rather
/// than rendered as a dead tile — the admin panel cannot invent a screen.
List<Feature> mergeFeatureTiles(List<Map<String, dynamic>> rows) {
  if (rows.isEmpty) return kFeatures;

  final byKey = {for (final f in kFeatures) f.key: f};
  final out = <Feature>[];

  for (final r in rows) {
    final base = byKey[r['key'] as String? ?? ''];
    if (base == null) continue;
    out.add(
      base.copyWith(
        title: (r['title'] as String?)?.trim().isNotEmpty == true
            ? r['title'] as String
            : null,
        subtitle: (r['subtitle'] as String?)?.trim().isNotEmpty == true
            ? r['subtitle'] as String
            : null,
        badge: (r['badge'] as String?) ?? '',
        hue: r['hue'] == null ? null : FeatureHueX.parse(r['hue'] as String),
      ),
    );
  }

  // A tile the admin has not mentioned still belongs on the grid; silence is
  // not a request to hide something.
  final named = out.map((f) => f.key).toSet();
  out.addAll(kFeatures.where((f) => !named.contains(f.key)));
  return out;
}
