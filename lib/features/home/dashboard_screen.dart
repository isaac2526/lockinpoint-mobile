import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../design/components.dart';
import '../../design/glass.dart';
import '../../design/motion_widgets.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../design/wordmark.dart';
import '../../app/theme_controller.dart';
import '../auth/auth_controller.dart';

/// ===========================================================================
/// THE HOME'S DATA · cached first, fresh behind.
///
/// Opening the app shows the LAST KNOWN home instantly from a local snapshot,
/// then refreshes it quietly. A slow network delays the numbers updating, not
/// the screen appearing. Refreshes happen exactly twice: once behind that
/// instant paint, and whenever the student pulls down. Never in a loop.
///
/// A refresh that fails while a snapshot is showing changes NOTHING on
/// screen; stale true numbers beat a fresh error. A 401 hands the student
/// back to the welcome screen through the auth controller rather than
/// stranding them on a home that will never load.
/// ===========================================================================
class DashboardController extends AsyncNotifier<Map<String, dynamic>> {
  static const _cacheKey = 'lip.dashboard-snapshot';

  @override
  Future<Map<String, dynamic>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    if (cached != null) {
      Future.microtask(refresh);
      try {
        return jsonDecode(cached) as Map<String, dynamic>;
      } catch (_) {
        // A corrupt snapshot is thrown away, not fought with.
      }
    }
    return _fetch();
  }

  /// Pull to refresh, and the silent refresh behind a cached paint.
  Future<void> refresh() async {
    try {
      state = AsyncData(await _fetch());
    } on ApiFailure catch (e, st) {
      if (e.unauthorised) {
        ref.invalidate(authControllerProvider);
        return;
      }
      // Keep showing the snapshot we have; only surface an error when there
      // is nothing better to show.
      if (!state.hasValue) state = AsyncError(e, st);
    }
  }

  Future<Map<String, dynamic>> _fetch() async {
    final data = await ref.read(apiProvider).get('/api/mobile/dashboard');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(data));
    return data;
  }
}

final dashboardProvider =
    AsyncNotifierProvider<DashboardController, Map<String, dynamic>>(
      DashboardController.new,
    );

/// ===========================================================================
/// THE STUDENT HOME
///
/// The website's dashboard, as a phone screen. Same greeting, same streak,
/// same live counts, same Continue Practice card, same destinations — read
/// from /api/mobile/dashboard, which runs the identical five queries the web
/// dashboard runs, so the two can never disagree about a student's numbers.
/// ===========================================================================
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;
    final snapshot = ref.watch(dashboardProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
          color: c.brand,
          backgroundColor: c.glassModal,
          child: snapshot.when(
            loading: () => const _Skeleton(),
            error: (e, _) => ListView(
              // A ListView so pull-to-refresh still works on the error screen —
              // otherwise a student who lost signal for one second is stuck.
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
                LipError(
                  message: e is ApiFailure
                      ? e.message
                      : 'Pull down to try again.',
                  onRetry: () => ref.read(dashboardProvider.notifier).refresh(),
                ),
                // The screen must never become a trap: whatever the server is
                // doing, the student can always walk back to the front door.
                Center(
                  child: TextButton.icon(
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).logOut(),
                    icon: const Icon(Icons.logout_rounded, size: 16),
                    label: const Text('Log out'),
                  ),
                ),
              ],
            ),
            data: (d) => _Content(data: d),
          ),
        ),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;

    if (data['frozen'] == true) {
      return LipEmpty(
        icon: Icons.ac_unit_rounded,
        title: 'Your account is on hold',
        message:
            'Reach the tutors at ${AppConfig.supportEmail} and they will sort it out.',
      );
    }

    final student = (data['student'] as Map).cast<String, dynamic>();
    final counts = (data['counts'] as Map).cast<String, dynamic>();
    final resume = data['resume'] as Map?;

    final name = student['name'] as String? ?? 'Champion';
    final streak = (student['streak'] as num?)?.toInt() ?? 0;
    final activated = student['activated'] == true;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.huge),
      children: [
        // ---- greeting and streak -------------------------------------
        Entrance(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LipWordmark(size: 26),
                    const SizedBox(height: Gap.md),
                    Text(
                      'Welcome back, $name',
                      style: LipType.title.copyWith(color: c.text1),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.md),
              _StreakBadge(days: streak),
            ],
          ),
        ),
        const SizedBox(height: Gap.lg),

        if (!activated) ...[
          _ActivationNotice(),
          const SizedBox(height: Gap.lg),
        ],

        // ---- continue practice ---------------------------------------
        if (resume != null) ...[
          _ResumeCard(resume: resume.cast<String, dynamic>()),
          const SizedBox(height: Gap.lg),
        ],

        // ---- the live numbers ----------------------------------------
        Row(
          children: [
            Expanded(
              child: LipStat(
                value: _compact(counts['questions']),
                label: 'questions live',
                tone: ChipTone.brand,
              ),
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: LipStat(
                value: '${counts['attempts'] ?? 0}',
                label: 'sittings done',
                tone: ChipTone.success,
              ),
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: LipStat(
                value: _compact(counts['notes']),
                label: 'notes & videos',
                tone: ChipTone.gold,
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.xl),

        // ---- the cards, matching the website's dashboard -------------
        const LipLabel('What are you doing today?'),
        const SizedBox(height: Gap.md),
        for (final (i, card) in _cards.indexed)
          Entrance(
            index: i + 2,
            child: Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: _DashCard(card: card),
            ),
          ),

        const SizedBox(height: Gap.lg),

        // ---- the WhatsApp channel ------------------------------------
        GlassSurface(
          tier: GlassTier.raised,
          seam: true,
          onTap: () => launchUrl(
            Uri.parse(AppConfig.whatsappChannel),
            mode: LaunchMode.externalApplication,
          ),
          semanticLabel: 'Join the LockInPoint WhatsApp Channel',
          child: Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: c.successSoft,
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: Icon(Icons.chat_rounded, size: 20, color: c.success),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Join the WhatsApp Channel',
                      style: LipType.subheading.copyWith(color: c.text1),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'New questions and exam alerts, straight to your phone.',
                      style: LipType.caption.copyWith(color: c.text3),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.text3),
            ],
          ),
        ),

        const SizedBox(height: Gap.xl),
        _Footer(email: student['email'] as String? ?? ''),
      ],
    );
  }

  /// 40,132 becomes 40.1k — a dashboard number should be read, not counted.
  static String _compact(Object? v) {
    final n = (v as num?)?.toInt() ?? 0;
    if (n < 1000) return '$n';
    if (n < 10000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '${(n / 1000).round()}k';
  }
}

// ---------------------------------------------------------------- pieces ----

class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final alive = days > 0;
    return GlassSurface(
      tier: GlassTier.deep,
      radius: Radii.md,
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                size: 16,
                color: alive ? c.accent : c.text3,
              ),
              const SizedBox(width: 4),
              Text(
                '$days',
                style: LipType.monoBig.copyWith(
                  color: alive ? c.accent : c.text3,
                ),
              ),
            ],
          ),
          Text('day streak', style: LipType.caption.copyWith(color: c.text3)),
        ],
      ),
    );
  }
}

class _ActivationNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    return GlassSurface(
      tier: GlassTier.raised,
      seam: true,
      child: Row(
        children: [
          Icon(Icons.vpn_key_rounded, size: 20, color: c.accent),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Not activated yet',
                  style: LipType.subheading.copyWith(color: c.text1),
                ),
                const SizedBox(height: 2),
                Text(
                  'Look around freely. One activation opens everything.',
                  style: LipType.caption.copyWith(color: c.text3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.resume});
  final Map<String, dynamic> resume;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final label = resume['label'] as String? ?? 'Practice';
    final done = (resume['answered'] as num?)?.toInt() ?? 0;
    final total = (resume['total'] as num?)?.toInt() ?? 0;
    final share = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);

    return GlassSurface(
      tier: GlassTier.raised,
      seam: true,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.play_circle_fill_rounded, size: 19, color: c.brand),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  'Continue where you stopped',
                  style: LipType.subheading.copyWith(color: c.text1),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Text(label, style: LipType.small.copyWith(color: c.text2)),
          const SizedBox(height: Gap.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 7,
              backgroundColor: c.glassDeep,
              valueColor: AlwaysStoppedAnimation(c.brand),
            ),
          ),
          const SizedBox(height: Gap.sm),
          Text(
            '$done of $total answered',
            style: LipType.caption.copyWith(color: c.text3),
          ),
        ],
      ),
    );
  }
}

/// The destinations, in the website's own order and wording.
const _cards = <({IconData icon, String title, String sub, bool ready})>[
  (
    icon: Icons.menu_book_rounded,
    title: 'Practice & CBT',
    sub: 'Your exam, your subject, by year, topic or random',
    ready: false,
  ),
  (
    icon: Icons.school_rounded,
    title: 'Classroom',
    sub: 'Notes, videos and files',
    ready: false,
  ),
  (
    icon: Icons.sports_esports_rounded,
    title: 'Games arena',
    sub: 'Blitz, Survival, Road to 400, Daily Ten, The Climb',
    ready: false,
  ),
  (
    icon: Icons.search_rounded,
    title: 'Question search',
    sub: 'Find any past question fast',
    ready: false,
  ),
  (
    icon: Icons.insights_rounded,
    title: 'Performance analysis',
    sub: 'Your scores, charted',
    ready: false,
  ),
  (
    icon: Icons.emoji_events_rounded,
    title: 'Leaderboard',
    sub: 'Top 50 across the platform',
    ready: false,
  ),
];

class _DashCard extends StatelessWidget {
  const _DashCard({required this.card});
  final ({IconData icon, String title, String sub, bool ready}) card;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    return GlassSurface(
      onTap: card.ready
          ? () {}
          : () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${card.title} lands in the next build.')),
            ),
      semanticLabel: '${card.title}. ${card.sub}',
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: c.brandSoft,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Icon(card.icon, size: 20, color: c.brand),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.title,
                  style: LipType.subheading.copyWith(color: c.text1),
                ),
                const SizedBox(height: 2),
                Text(card.sub, style: LipType.caption.copyWith(color: c.text3)),
              ],
            ),
          ),
          if (!card.ready)
            Text('soon', style: LipType.label.copyWith(color: c.text3))
          else
            Icon(Icons.chevron_right_rounded, color: c.text3),
        ],
      ),
    );
  }
}

class _Footer extends ConsumerWidget {
  const _Footer({required this.email});
  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;
    final brightness = Theme.of(context).brightness;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: () =>
                  ref.read(themeControllerProvider.notifier).toggle(brightness),
              icon: Icon(
                c.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                size: 17,
              ),
              label: Text(c.isDark ? 'Light mode' : 'Dark mode'),
            ),
            const SizedBox(width: Gap.md),
            TextButton.icon(
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).logOut(),
              icon: const Icon(Icons.logout_rounded, size: 17),
              label: const Text('Log out'),
            ),
          ],
        ),
        const SizedBox(height: Gap.sm),
        Text(email, style: LipType.caption.copyWith(color: c.text3)),
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(Gap.lg),
    children: const [
      LipSkeleton(height: 26, width: 170),
      SizedBox(height: Gap.lg),
      LipSkeleton(height: 74, radius: Radii.lg),
      SizedBox(height: Gap.lg),
      LipSkeleton(height: 66, radius: Radii.md),
      SizedBox(height: Gap.xl),
      LipSkeleton(height: 68, radius: Radii.lg),
      SizedBox(height: Gap.sm),
      LipSkeleton(height: 68, radius: Radii.lg),
      SizedBox(height: Gap.sm),
      LipSkeleton(height: 68, radius: Radii.lg),
    ],
  );
}
