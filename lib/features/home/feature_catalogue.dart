import 'package:flutter/foundation.dart' show kIsWeb;

import '../../core/json.dart';

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

/// Which band of the home screen a tile belongs to.
///
/// TWENTY-ONE IDENTICAL TILES IN ONE WALL IS NOT A HOME SCREEN, it is a
/// contents page. The grid carried twelve, and every room added since —
/// Theory, Practical, Pointgram, the Study Plan, the Challenge, activity,
/// referrals, receipts, the harvest — was reachable only from the drawer. So
/// the owner opened the app, looked at the dashboard, and correctly said the
/// new features were not there. A drawer is where you go when you already
/// know what you are looking for; a dashboard is how you find out what exists.
///
/// They are all on it now, in four bands a student can scan: what you study,
/// what you compete in, who you talk to, and what is yours.
enum FeatureBand { study, compete, community, you }

extension FeatureBandX on FeatureBand {
  String get label => switch (this) {
    FeatureBand.study => 'Study',
    FeatureBand.compete => 'Compete',
    FeatureBand.community => 'Community',
    FeatureBand.you => 'Yours',
  };
}

@immutable
class Feature {
  const Feature({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.hue,
    this.band = FeatureBand.study,
    this.ready = true,
    this.badge = '',
  });

  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final FeatureHue hue;
  final FeatureBand band;

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
    band: band,
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
    band: FeatureBand.study,
    hue: FeatureHue.blue,
  ),
  Feature(
    key: 'classroom',
    title: 'Classroom',
    subtitle: 'Notes, materials and video lessons',
    icon: Icons.auto_stories_rounded,
    band: FeatureBand.study,
    hue: FeatureHue.violet,
  ),
  Feature(
    key: 'search',
    title: 'Question search',
    subtitle: 'Find any question, fast',
    icon: Icons.search_rounded,
    band: FeatureBand.study,
    hue: FeatureHue.slate,
  ),
  Feature(
    key: 'history',
    title: 'Result history',
    subtitle: 'Every paper you have sat',
    icon: Icons.receipt_long_rounded,
    band: FeatureBand.compete,
    hue: FeatureHue.green,
  ),
  Feature(
    key: 'analysis',
    title: 'Performance analysis',
    subtitle: 'Where your marks are going',
    icon: Icons.insights_rounded,
    band: FeatureBand.compete,
    hue: FeatureHue.indigo,
  ),
  Feature(
    key: 'games',
    title: 'Games arena',
    subtitle: 'Blitz, Survival, The Climb',
    icon: Icons.sports_esports_rounded,
    band: FeatureBand.compete,
    hue: FeatureHue.purple,
  ),
  Feature(
    key: 'challenge',
    title: 'The Climb',
    subtitle: 'Fifteen rungs, three lifelines',
    icon: Icons.emoji_events_rounded,
    band: FeatureBand.compete,
    hue: FeatureHue.amber,
  ),
  Feature(
    key: 'leaderboard',
    title: 'Leaderboard',
    subtitle: 'Your rank, nationally and locally',
    icon: Icons.leaderboard_rounded,
    band: FeatureBand.compete,
    hue: FeatureHue.pink,
  ),
  Feature(
    key: 'bookmarks',
    title: 'Saved questions',
    subtitle: 'Everything you kept',
    icon: Icons.bookmark_rounded,
    band: FeatureBand.you,
    hue: FeatureHue.lime,
  ),
  Feature(
    key: 'vault',
    title: 'Offline vault',
    subtitle: 'Downloaded questions, no signal needed',
    icon: Icons.offline_bolt_rounded,
    band: FeatureBand.you,
    hue: FeatureHue.teal,
  ),
  Feature(
    key: 'career',
    title: 'Career & institutions',
    subtitle: 'Courses, schools and cut-offs',
    icon: Icons.school_rounded,
    band: FeatureBand.study,
    hue: FeatureHue.orange,
  ),
  Feature(
    key: 'tutor',
    title: 'Ask Lumi',
    subtitle: 'Your AI tutor, any question',
    icon: Icons.smart_toy_rounded,
    band: FeatureBand.study,
    hue: FeatureHue.rose,
  ),

  // ---- the rooms that were reachable only from the drawer ---------------
  /* EVERY ONE OF THESE EXISTED AND WORKED. None of them was on this grid, so
     the owner's verdict — "the remaining features of the app isn't their" —
     was correct about the only surface he actually looks at. */
  Feature(
    key: 'theory',
    title: 'Theory',
    subtitle: 'Written questions and their marking schemes',
    icon: Icons.edit_note_rounded,
    band: FeatureBand.study,
    hue: FeatureHue.amber,
  ),
  Feature(
    key: 'practical',
    title: 'Practical',
    subtitle: 'Apparatus, observations and readings',
    icon: Icons.science_rounded,
    band: FeatureBand.study,
    hue: FeatureHue.lime,
  ),
  Feature(
    key: 'plan',
    title: 'Study plan',
    subtitle: 'Fourteen days from your own weak topics',
    icon: Icons.event_note_rounded,
    band: FeatureBand.study,
    hue: FeatureHue.teal,
  ),
  Feature(
    key: 'rounds',
    title: 'UTME Challenge',
    subtitle: 'Competition rounds and past winners',
    icon: Icons.military_tech_rounded,
    band: FeatureBand.compete,
    hue: FeatureHue.violet,
  ),
  Feature(
    key: 'gram',
    title: 'Pointgram',
    subtitle: 'Study rooms and the Tutor Line',
    icon: Icons.forum_rounded,
    band: FeatureBand.community,
    hue: FeatureHue.blue,
  ),
  Feature(
    key: 'harvest',
    title: 'Question harvest',
    subtitle: 'Give back the questions you remember',
    icon: Icons.volunteer_activism_rounded,
    band: FeatureBand.community,
    hue: FeatureHue.rose,
  ),
  Feature(
    key: 'referrals',
    title: 'Refer a friend',
    subtitle: 'Your code, and what it has earned',
    icon: Icons.card_giftcard_rounded,
    band: FeatureBand.community,
    hue: FeatureHue.green,
  ),
  Feature(
    key: 'activity',
    title: 'Your activity',
    subtitle: 'Everything you have done here',
    icon: Icons.history_rounded,
    band: FeatureBand.you,
    hue: FeatureHue.slate,
  ),
  Feature(
    key: 'receipts',
    title: 'Receipts',
    subtitle: 'Every payment, with its printable receipt',
    icon: Icons.receipt_rounded,
    band: FeatureBand.you,
    hue: FeatureHue.indigo,
  ),
  Feature(
    key: 'activate',
    title: 'Activate',
    subtitle: 'Card, transfer or a key',
    icon: Icons.vpn_key_rounded,
    band: FeatureBand.you,
    hue: FeatureHue.amber,
  ),
];

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
  if (rows.isEmpty) return visibleFeatures;

  final byKey = {for (final f in visibleFeatures) f.key: f};
  final out = <Feature>[];

  for (final r in rows) {
    final base = byKey[asText(r['key'])];
    if (base == null) continue;
    out.add(
      base.copyWith(
        title: asTextOrNull(r['title'])?.trim().isNotEmpty == true
            ? asText(r['title'])
            : null,
        subtitle: asTextOrNull(r['subtitle'])?.trim().isNotEmpty == true
            ? asText(r['subtitle'])
            : null,
        badge: asText(r['badge']),
        hue: r['hue'] == null ? null : FeatureHueX.parse(asText(r['hue'])),
      ),
    );
  }

  // A tile the admin has not mentioned still belongs on the grid; silence is
  // not a request to hide something.
  final named = out.map((f) => f.key).toSet();
  out.addAll(visibleFeatures.where((f) => !named.contains(f.key)));
  return out;
}

/// The grid for THIS platform.
///
/// The offline vault stores questions on a device; a browser tab has nowhere
/// to put them. Rather than show a tile that would apologise when tapped, the
/// web build simply does not offer it — the same codebase, adapted where the
/// platform genuinely differs.
List<Feature> get visibleFeatures =>
    kIsWeb ? kFeatures.where((f) => f.key != 'vault').toList() : kFeatures;
