import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/wordmark.dart';
import '../features/activation/activation_screen.dart';
import '../features/activity/activity_screen.dart';
import '../features/career/career_screen.dart';
import '../features/classroom/classroom_screen.dart';
import '../features/games/games_screen.dart';
import '../features/gram/gram_screen.dart';
import '../features/auth/auth_controller.dart';
import '../features/content/content_repository.dart';
import '../features/home/dashboard_screen.dart';
import '../features/home/feature_catalogue.dart';
import '../features/leaderboard/leaderboard_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/plan/plan_screen.dart';
import '../features/practice/practice_flow_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/referrals/referrals_screen.dart';
import '../features/receipts/receipts_screen.dart';
import '../features/harvest/harvest_screen.dart';
import '../features/rounds/rounds_screen.dart';
import '../features/progress/analysis_screen.dart';
import '../features/progress/results_screen.dart';
import '../features/saved/saved_screen.dart';
import '../features/search/search_screen.dart';
import '../features/theory/theory_screen.dart';
import '../features/tutor/tutor_screen.dart';
import '../features/vault/vault_screen.dart';
import '../core/vault/connectivity.dart';
import '../core/vault/essential_download.dart';
import '../features/vault/essential_screen.dart';
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

/// ===========================================================================
/// THE ONE HANDLE ON THE SHELL'S DRAWER.
///
/// THE MENU BUTTON WAS A DEAD TAP, on Home and on Practice, for the life of
/// the app. The drawer belongs to the SHELL's Scaffold — but every tab builds
/// its own Scaffold inside it, and `Scaffold.of(context)` walks UP to the
/// nearest one, which is the tab's. That Scaffold has no drawer, so
/// `openDrawer()` found a null drawer key and returned without doing
/// anything, silently, with no error to notice. The only way into the menu
/// was a left-edge drag that nothing on screen advertises.
///
/// A GlobalKey held here is addressed directly rather than looked up through
/// the widget tree, so it cannot be shadowed by an inner Scaffold no matter
/// how deeply a tab nests.
final shellDrawerKey = GlobalKey<ScaffoldState>();

/// Opens the app's menu from anywhere inside the shell. Safe to call when
/// there is no shell (a pushed route, a test): it does nothing rather than
/// throwing.
void openAppMenu() {
  final st = shellDrawerKey.currentState;
  if (st != null && !st.isDrawerOpen) st.openDrawer();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _tab = 0;

  /// The student has chosen to carry on while the text pack downloads. NOT a
  /// skip: the run keeps going and the bar follows them to the top of the
  /// screen. There is deliberately no way to decline the download — an app
  /// that lets someone say no and then fails them on a bus with no signal has
  /// not respected their choice, it has moved the failure to a worse moment.
  bool _carryOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(essentialDownloadProvider.notifier).check();
    });
  }

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

    /* THE FIRST LAUNCH. Held here rather than in a route so that choosing to
       carry on does not push a screen the back button can undo. */
    final essential = ref.watch(essentialDownloadProvider);
    final mustDownload =
        !_carryOn &&
        (essential.phase == EssentialPhase.needed ||
            essential.phase == EssentialPhase.running ||
            essential.phase == EssentialPhase.paused);
    if (mustDownload) {
      return EssentialDownloadScreen(
        onContinue: () => setState(() => _carryOn = true),
      );
    }

    return Scaffold(
      key: shellDrawerKey,
      drawer: const _LipDrawer(),
      body: Column(
        children: [
          /* THE HONEST OFFLINE BAR. It only appears when there is genuinely
             no network, and it says something DIFFERENT when the student has
             downloads — because "no connection" is the wrong sentence for a
             phone holding a thousand questions. */
          // The download that is still running, following the student.
          const EssentialProgressBar(),
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
                  icon: Icons.auto_stories_rounded,
                  hue: FeatureHue.violet,
                  title: 'Classroom',
                  subtitle: 'Notes, videos and files',
                  onTap: () => go(const ClassroomScreen()),
                ),
                /* THE OTHER HALF OF THE PAPER. Every WAEC, NECO and NABTEB
                   sitting has a written section, and until now a student
                   preparing here practised only the objectives. */
                _Row(
                  icon: Icons.edit_note_rounded,
                  hue: FeatureHue.orange,
                  title: 'Theory',
                  subtitle: 'Written questions and their marking schemes',
                  onTap: () => go(const TheoryScreen()),
                ),
                _Row(
                  icon: Icons.science_rounded,
                  hue: FeatureHue.teal,
                  title: 'Practical',
                  subtitle: 'Apparatus, observations and readings',
                  onTap: () => go(const TheoryScreen(kind: 'practical')),
                ),
                _Row(
                  icon: Icons.bookmark_rounded,
                  hue: FeatureHue.lime,
                  title: 'Saved questions',
                  onTap: () => go(const SavedScreen()),
                ),
                _Row(
                  icon: Icons.sports_esports_rounded,
                  hue: FeatureHue.purple,
                  title: 'Games arena',
                  subtitle: 'Blitz, Survival, The Climb',
                  onTap: () => go(const GamesScreen()),
                ),
                _Row(
                  icon: Icons.forum_rounded,
                  hue: FeatureHue.pink,
                  title: 'Pointgram',
                  subtitle: 'Study rooms and the Tutor Line',
                  onTap: () => go(const GramScreen()),
                ),
                _Row(
                  icon: Icons.school_rounded,
                  hue: FeatureHue.orange,
                  title: 'Career & institutions',
                  subtitle: 'Who offers your course',
                  onTap: () => go(const CareerScreen()),
                ),
                _Row(
                  icon: Icons.smart_toy_rounded,
                  hue: FeatureHue.rose,
                  title: 'Ask Lumi',
                  subtitle: 'Your AI tutor',
                  onTap: () => go(const TutorScreen()),
                ),
                _Row(
                  icon: Icons.receipt_long_rounded,
                  hue: FeatureHue.green,
                  title: 'Result history',
                  onTap: () => go(const ResultsScreen()),
                ),
                _Row(
                  icon: Icons.vpn_key_rounded,
                  hue: FeatureHue.amber,
                  title: 'Activate',
                  subtitle: 'Card, transfer or a key',
                  onTap: () => go(const ActivationScreen()),
                ),
                _Row(
                  icon: Icons.insights_rounded,
                  hue: FeatureHue.indigo,
                  title: 'Performance analysis',
                  subtitle: 'And the topics costing you marks',
                  onTap: () => go(const AnalysisScreen()),
                ),
                _Row(
                  icon: Icons.event_note_rounded,
                  hue: FeatureHue.amber,
                  title: 'Study plan',
                  subtitle: 'Fourteen days from your own weak topics',
                  onTap: () => go(const PlanScreen()),
                ),
                _Row(
                  icon: Icons.emoji_events_rounded,
                  hue: FeatureHue.purple,
                  title: 'The Challenge',
                  subtitle: 'Competition rounds and past winners',
                  onTap: () => go(const RoundsScreen()),
                ),
                _Row(
                  icon: Icons.volunteer_activism_rounded,
                  hue: FeatureHue.rose,
                  title: 'Question harvest',
                  subtitle: 'Give back the questions you remember',
                  onTap: () => go(const HarvestScreen()),
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
                  icon: Icons.history_rounded,
                  hue: FeatureHue.slate,
                  title: 'Your activity',
                  subtitle: 'Everything you have done here',
                  onTap: () => go(const ActivityScreen()),
                ),
                _Row(
                  icon: Icons.card_giftcard_rounded,
                  hue: FeatureHue.green,
                  title: 'Refer a friend',
                  subtitle: 'Your code, and what it has earned',
                  onTap: () => go(const ReferralsScreen()),
                ),
                _Row(
                  icon: Icons.receipt_rounded,
                  hue: FeatureHue.teal,
                  title: 'Receipts',
                  subtitle: 'Every payment, with its printable receipt',
                  onTap: () => go(const ReceiptsScreen()),
                ),
                /* SIGN OUT BELONGS WHERE A STUDENT LOOKS FOR IT. There was
                   no way out of the app from anywhere except the profile tab,
                   and two rows here — a second Classroom and a second
                   Activation — answered a tap with "arrives in the next
                   build" while the real rows sat a few lines above them. A
                   menu that lies about what it can do is worse than a shorter
                   menu. */
                _Row(
                  icon: Icons.logout_rounded,
                  hue: FeatureHue.rose,
                  title: 'Sign out',
                  subtitle: 'Your downloads stay on this phone',
                  onTap: () async {
                    Navigator.of(context).pop();
                    final yes = await showDialog<bool>(
                      context: context,
                      builder: (d) => AlertDialog(
                        title: const Text('Sign out?'),
                        content: const Text(
                          'Everything you have downloaded stays on this phone '
                          'and will be here when you sign back in.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(d).pop(false),
                            child: const Text('Stay'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(d).pop(true),
                            child: const Text('Sign out'),
                          ),
                        ],
                      ),
                    );
                    if (yes == true) {
                      await ref.read(authControllerProvider.notifier).logOut();
                    }
                  },
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
