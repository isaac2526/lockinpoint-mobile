import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/wordmark.dart';
import '../features/auth/auth_controller.dart';
import '../features/content/content_repository.dart';
import '../features/home/dashboard_screen.dart';
import '../features/home/feature_catalogue.dart';
import '../features/leaderboard/leaderboard_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/practice/practice_flow_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/progress/analysis_screen.dart';
import '../features/progress/results_screen.dart';
import '../features/search/search_screen.dart';
import '../features/vault/vault_screen.dart';
import '../core/vault/connectivity.dart';
import '../core/vault/vault_repository.dart';
import '../design/components.dart';

/// ===========================================================================
/// THE SHELL
///
/// Four destinations, and a drawer for everything else.
///
/// FOUR, NOT SEVEN. A bottom bar is muscle memory: a student's thumb learns
/// where Practice is and stops reading the labels. Seven items destroys that
/// — the targets shrink, the words truncate, and every tap becomes a decision
/// again. So the bar holds the four things a student does most, and the
/// twelve-tile grid on Home carries the rest, where there is room for each of
/// them to have a colour, a sentence and a proper touch target.
///
/// The drawer is grouped by WHAT A THING IS FOR rather than alphabetically —
/// learning, account, guardian, contact — because that is how a student looks
/// for something they have only seen once.
/// ===========================================================================
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _tab = 0;

  static const _tabs = [
    (icon: Icons.home_rounded, off: Icons.home_outlined, label: 'Home'),
    (
      icon: Icons.rocket_launch_rounded,
      off: Icons.rocket_launch_outlined,
      label: 'Practice',
    ),
    (
      icon: Icons.leaderboard_rounded,
      off: Icons.leaderboard_outlined,
      label: 'Ranking',
    ),
    (
      icon: Icons.person_rounded,
      off: Icons.person_outline_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.lip;

    return Scaffold(
      drawer: const _LipDrawer(),
      body: Column(
        children: [
          /* THE HONEST OFFLINE BAR. It only appears when there is genuinely
             no network, and it says something DIFFERENT when the student has
             downloads — because "no connection" is the wrong sentence for a
             phone holding a thousand questions. */
          Consumer(
            builder: (context, ref, _) {
              final online = ref.watch(isOnlineProvider);
              if (online) return const SizedBox.shrink();
              final hasVault = ref.watch(hasVaultProvider).value ?? false;
              return SafeArea(
                bottom: false,
                child: LipOfflineBar(hasVault: hasVault),
              );
            },
          ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: const [
                DashboardScreen(embedded: true),
                PracticeFlowScreen(embedded: true),
                LeaderboardScreen(embedded: true),
                ProfileScreen(embedded: true),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: c.glassCard,
        indicatorColor: c.hues.blue.tint,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (final t in _tabs)
            NavigationDestination(
              icon: Icon(t.off, color: c.text3),
              selectedIcon: Icon(t.icon, color: c.hues.blue.ink),
              label: t.label,
            ),
        ],
      ),
    );
  }
}

/// ===========================================================================
/// THE DRAWER
///
/// Grouped by purpose. Every contact row comes from the backend — the app
/// carries no phone number of its own — and a group with nothing in it does
/// not render at all, so a student never meets an empty heading.
/// ===========================================================================
class _LipDrawer extends ConsumerWidget {
  const _LipDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;
    final name = switch (ref.watch(authControllerProvider).value) {
      SignedIn(:final name) => name,
      _ => 'Champion',
    };
    final contacts = ref.watch(supportContactsProvider).value ?? const [];

    void go(Widget screen) {
      Navigator.of(context).pop();
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    }

    void soon(String what) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$what arrives in the next build.')),
      );
    }

    return Drawer(
      backgroundColor: c.bgBase,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ---- who ------------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.xl,
                Gap.lg,
                Gap.lg,
              ),
              child: Row(
                children: [
                  const LipLogoMark(size: 40),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LockInPoint',
                          style: LipType.subheading.copyWith(color: c.text1),
                        ),
                        Text(
                          name,
                          style: LipType.small.copyWith(color: c.text3),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.glassBorder),

            _Group(
              label: 'Learning',
              children: [
                _Row(
                  icon: Icons.rocket_launch_rounded,
                  hue: FeatureHue.blue,
                  title: 'Practice & CBT',
                  onTap: () => go(const PracticeFlowScreen()),
                ),
                _Row(
                  icon: Icons.search_rounded,
                  hue: FeatureHue.slate,
                  title: 'Question search',
                  onTap: () => go(const SearchScreen()),
                ),
                _Row(
                  icon: Icons.leaderboard_rounded,
                  hue: FeatureHue.pink,
                  title: 'Leaderboard',
                  onTap: () => go(const LeaderboardScreen()),
                ),
                _Row(
                  icon: Icons.receipt_long_rounded,
                  hue: FeatureHue.green,
                  title: 'Result history',
                  onTap: () => go(const ResultsScreen()),
                ),
                _Row(
                  icon: Icons.insights_rounded,
                  hue: FeatureHue.indigo,
                  title: 'Performance analysis',
                  onTap: () => go(const AnalysisScreen()),
                ),
                // No device to store packs on means no row offering to.
                if (!kIsWeb)
                  _Row(
                    icon: Icons.offline_bolt_rounded,
                    hue: FeatureHue.teal,
                    title: 'Offline vault',
                    subtitle: 'Practise with no signal',
                    onTap: () => go(const VaultScreen()),
                  ),
                _Row(
                  icon: Icons.auto_stories_rounded,
                  hue: FeatureHue.violet,
                  title: 'Classroom',
                  onTap: () => soon('Classroom'),
                ),
              ],
            ),

            _Group(
              label: 'Your account',
              children: [
                _Row(
                  icon: Icons.person_rounded,
                  hue: FeatureHue.indigo,
                  title: 'Profile & Product Key',
                  onTap: () => go(const ProfileScreen()),
                ),
                _Row(
                  icon: Icons.notifications_rounded,
                  hue: FeatureHue.amber,
                  title: 'Notifications',
                  onTap: () => go(const NotificationsScreen()),
                ),
                _Row(
                  icon: Icons.account_balance_wallet_rounded,
                  hue: FeatureHue.green,
                  title: 'Activation',
                  onTap: () => soon('Activation'),
                ),
              ],
            ),

            _Group(
              label: 'Guardian',
              children: [
                _Row(
                  icon: Icons.supervisor_account_rounded,
                  hue: FeatureHue.indigo,
                  title: 'Guardian Portal',
                  subtitle: 'For a parent, teacher or school',
                  onTap: () {
                    Navigator.of(context).pop();
                    launchUrl(
                      Uri.parse(AppConfig.guardianPortal),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
              ],
            ),

            // Nothing here is written in Dart. No rows, no group.
            if (contacts.isNotEmpty)
              _Group(
                label: 'Contact',
                children: [
                  for (final k in contacts)
                    _Row(
                      icon: _contactIcon(k.kind),
                      hue: _contactHue(k.kind),
                      title: k.label.isEmpty ? k.kind : k.label,
                      subtitle: k.description.isEmpty ? null : k.description,
                      onTap: () {
                        Navigator.of(context).pop();
                        launchUrl(k.uri, mode: LaunchMode.externalApplication);
                      },
                    ),
                ],
              ),

            const SizedBox(height: Gap.xl),
          ],
        ),
      ),
    );
  }

  static IconData _contactIcon(String kind) => switch (kind) {
    'whatsapp' => Icons.chat_rounded,
    'phone' => Icons.call_rounded,
    'email' => Icons.mail_rounded,
    'channel' => Icons.campaign_rounded,
    'feedback' => Icons.rate_review_rounded,
    'rate' => Icons.star_rounded,
    'share' => Icons.share_rounded,
    'about' => Icons.info_rounded,
    _ => Icons.link_rounded,
  };

  static FeatureHue _contactHue(String kind) => switch (kind) {
    'whatsapp' || 'phone' => FeatureHue.green,
    'email' => FeatureHue.blue,
    'channel' => FeatureHue.violet,
    'feedback' || 'rate' => FeatureHue.amber,
    _ => FeatureHue.slate,
  };
}

class _Group extends StatelessWidget {
  const _Group({required this.label, required this.children});
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xs),
          child: Text(label, style: LipType.label.copyWith(color: c.text3)),
        ),
        ...children,
        const SizedBox(height: Gap.xs),
        Divider(height: 1, color: c.glassBorder),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.hue,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final FeatureHue hue;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final h = hue.of(c);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.md,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: h.tint,
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Icon(icon, size: 19, color: h.ink),
            ),
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
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: LipType.caption.copyWith(color: c.text3),
                      overflow: TextOverflow.ellipsis,
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
