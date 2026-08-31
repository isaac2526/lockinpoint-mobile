import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/shell.dart';
import '../../core/open.dart';
import '../../core/api.dart';
import '../../design/components.dart';
import '../../design/glass.dart';
import '../../design/motion_widgets.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../design/wordmark.dart';
import '../../app/theme_controller.dart';
import '../activation/activation_screen.dart';
import '../auth/ui/verify_email_screen.dart';
import '../auth/auth_controller.dart';
import '../content/content_repository.dart';
import '../profile/profile_screen.dart';
import '../practice/practice_repository.dart';
import '../notifications/notifications_screen.dart';
import '../practice/practice_session_screen.dart';
import 'feature_grid.dart';
import 'home_carousel.dart';

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
    try {
      return await _fetch();
    } on ApiFailure catch (e) {
      /* The FIRST load, with no snapshot to fall back on. A 401 here must
         hand the student back to the front door exactly as refresh() does —
         this was the path that used to strand a freshly logged-in student on
         an error card when the phone lost its stored key. */
      /* A refused session must be ENDED, not merely re-asked. The gate now
         opens on a stored token alone, so invalidating would send the
         student straight back to a home whose every request 401s. */
      if (e.unauthorised) {
        await ref
            .read(authControllerProvider.notifier)
            .signOutBecause(e.message);
      }
      rethrow;
    }
  }

  /// Pull to refresh, and the silent refresh behind a cached paint.
  Future<void> refresh() async {
    try {
      state = AsyncData(await _fetch());
    } on ApiFailure catch (e, st) {
      if (e.unauthorised) {
        await ref
            .read(authControllerProvider.notifier)
            .signOutBecause(e.message);
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
  const DashboardScreen({super.key, this.embedded = false});

  /// True when this screen is a TAB inside the shell rather than a pushed
  /// route. An embedded screen drops its own app bar and back button — two
  /// headers stacked on one screen is the fastest way to make an app feel
  /// like a collection of pages instead of one product.
  final bool embedded;

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
                  detail: e is ApiFailure ? e.detail : null,
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
      /* The address comes from the backend, so a frozen student is never sent
         to an inbox the team stopped reading two releases ago. */
      final email = ref
          .watch(supportContactsProvider)
          .value
          ?.where((k) => k.kind == 'email')
          .firstOrNull
          ?.value;
      return LipEmpty(
        icon: Icons.ac_unit_rounded,
        title: 'Your account is on hold',
        message: email == null
            ? 'Reach the tutors from your profile and they will sort it out.'
            : 'Reach the tutors at $email and they will sort it out.',
      );
    }

    final student = (data['student'] as Map).cast<String, dynamic>();
    final counts = (data['counts'] as Map).cast<String, dynamic>();
    final resume = data['resume'] as Map?;

    final name = student['name'] as String? ?? 'Champion';
    final streak = (student['streak'] as num?)?.toInt() ?? 0;
    final activated = student['activated'] == true;
    final verified = student['emailVerified'] == true;
    final email = student['email'] as String? ?? '';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.huge),
      children: [
        // ---- the bar: menu, mark, bell -------------------------------
        Entrance(
          child: Row(
            children: [
              Builder(
                builder: (context) => IconButton(
                  /* The drawer lives on the SHELL's scaffold; this screen's own
                     inner Scaffold has none, so Scaffold.of() here found a
                     drawerless scaffold and this tap did nothing at all in
                     release builds. */
                  onPressed: () => lipShellKey.currentState?.openDrawer(),
                  icon: const Icon(Icons.menu_rounded),
                  tooltip: 'Menu',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
              ),
              const SizedBox(width: Gap.sm),
              const LipWordmark(size: 24),
              const Spacer(),
              const _BellButton(),
              const SizedBox(width: Gap.xs),
              _ProfileButton(initial: name.isEmpty ? '?' : name[0]),
            ],
          ),
        ),
        const SizedBox(height: Gap.lg),

        // ---- greeting and streak -------------------------------------
        Entrance(
          index: 1,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Welcome back, $name',
                  style: LipType.title.copyWith(color: c.text1),
                ),
              ),
              const SizedBox(width: Gap.md),
              _StreakBadge(days: streak),
            ],
          ),
        ),
        const SizedBox(height: Gap.lg),

        // ---- what the team is saying, if anything --------------------
        const HomeCarousel(),

        /* THE CODE HAS SOMEWHERE TO GO NOW. Signing up mails a six digit
           code and tells the student to "enter it on the verify page" — a
           page that existed only on the website, so a student who joined on
           their phone was handed an instruction the app could not honour. */
        if (!verified) ...[
          _VerifyNotice(email: email),
          const SizedBox(height: Gap.lg),
        ],

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

        // ---- everything LockInPoint does, in colour -------------------
        const LipLabel('What are you doing today?'),
        const SizedBox(height: Gap.md),
        const FeatureGrid(),

        const SizedBox(height: Gap.lg),

        // ---- the channel, if the team runs one -----------------------
        // Driven by a `channel` row in support_contacts. No row means no
        // card, which is better than a card opening a link nobody keeps.
        const _ChannelCard(),

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

class _VerifyNotice extends StatelessWidget {
  const _VerifyNotice({required this.email});
  final String email;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    return GlassSurface(
      tier: GlassTier.raised,
      seam: true,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VerifyEmailScreen(email: email),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.mark_email_unread_rounded, size: 20, color: c.warning),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Confirm your email',
                  style: LipType.subheading.copyWith(color: c.text1),
                ),
                const SizedBox(height: 2),
                Text(
                  'We sent you a six digit code. Tap to enter it.',
                  style: LipType.caption.copyWith(color: c.text3),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 20, color: c.text3),
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
      // The card said "one activation opens everything" and then did nothing
      // when tapped. Now it leads to the place where that actually happens.
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const ActivationScreen())),
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
          Icon(Icons.chevron_right_rounded, size: 20, color: c.text3),
        ],
      ),
    );
  }
}

class _ResumeCard extends ConsumerStatefulWidget {
  const _ResumeCard({required this.resume});
  final Map<String, dynamic> resume;

  @override
  ConsumerState<_ResumeCard> createState() => _ResumeCardState();
}

class _ResumeCardState extends ConsumerState<_ResumeCard> {
  bool _busy = false;

  Map<String, dynamic> get resume => widget.resume;

  Future<void> _continue() async {
    final attemptId = resume['id'] as String?;
    if (attemptId == null || _busy) return;
    setState(() => _busy = true);
    try {
      final sitting = await ref
          .read(practiceRepositoryProvider)
          .resume(attemptId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PracticeSessionScreen(sitting: sitting),
        ),
      );
      /* COMING BACK REFRESHES THE CARD. The student submits the paper, walks
         back to the home, and this card was still offering to continue the
         sitting they just finished — with its old "12 of 40 answered" under
         it. Tapping it then failed, which is the moment the app stopped
         looking trustworthy. The card is only as true as its last refresh. */
      if (mounted) ref.read(dashboardProvider.notifier).refresh();
    } on ApiFailure catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
      // A finished or vanished sitting should stop being offered.
      ref.read(dashboardProvider.notifier).refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
      onTap: _continue,
      semanticLabel: 'Continue where you stopped. $label',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_busy)
                SizedBox(
                  height: 19,
                  width: 19,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: c.brand,
                  ),
                )
              else
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
/// The door to the student's own page: their initial in a ring, top right of
/// the home, where every app keeps it.
class _ProfileButton extends StatelessWidget {
  const _ProfileButton({required this.initial});
  final String initial;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    return Semantics(
      button: true,
      // One clean node: a screen reader should say "Open your profile", not
      // read out the single letter inside the ring.
      container: true,
      excludeSemantics: true,
      label: 'Open your profile',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const ProfileScreen())),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: c.brandSoft,
            shape: BoxShape.circle,
            border: Border.all(color: c.brand, width: 1.3),
          ),
          alignment: Alignment.center,
          child: Text(
            initial.toUpperCase(),
            style: LipType.smallStrong.copyWith(color: c.brand),
          ),
        ),
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

/// ===========================================================================
/// THE CHANNEL CARD
///
/// The WhatsApp channel used to be a constant in `config.dart`, so moving the
/// channel meant shipping an APK. It is a `channel` row in support_contacts
/// now — and when the team runs no channel there is simply NO CARD, which is
/// better than a card that opens a link nobody maintains.
/// ===========================================================================
class _ChannelCard extends ConsumerWidget {
  const _ChannelCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;
    final channel = ref
        .watch(supportContactsProvider)
        .value
        ?.where((k) => k.kind == 'channel')
        .firstOrNull;
    if (channel == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: Gap.lg),
      child: GlassSurface(
        tier: GlassTier.raised,
        hue: c.hues.green,
        onTap: () => openOutside(context, channel.uri),
        semanticLabel: channel.label.isEmpty
            ? 'Join the LockInPoint channel'
            : channel.label,
        child: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: c.hues.green.ink.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Icon(
                Icons.campaign_rounded,
                size: 20,
                color: c.hues.green.ink,
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.label.isEmpty ? 'Join the channel' : channel.label,
                    style: LipType.subheading.copyWith(color: c.text1),
                  ),
                  if (channel.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      channel.description,
                      style: LipType.caption.copyWith(color: c.text3),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.text3),
          ],
        ),
      ),
    );
  }
}

/// ===========================================================================
/// THE BELL
///
/// Unread count from the one notification system — the same route and the
/// same acknowledgements the website's bell counts, so a notice read on a
/// laptop is read here too.
///
/// It never shows a spinner and never blocks the home screen. Before the
/// count has arrived it is simply a bell with no badge, which is what a bell
/// with nothing in it looks like anyway.
/// ===========================================================================
class _BellButton extends ConsumerWidget {
  const _BellButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;
    final unread = ref.watch(unreadCountProvider);

    return Semantics(
      button: true,
      label: unread == 0 ? 'Notifications' : 'Notifications, $unread unread',
      excludeSemantics: true,
      child: IconButton(
        tooltip: 'Notifications',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(Icons.notifications_none_rounded, color: c.text2),
            if (unread > 0)
              Positioned(
                right: -3,
                top: -3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  decoration: BoxDecoration(
                    color: c.hues.rose.ink,
                    borderRadius: BorderRadius.circular(Radii.pill),
                    border: Border.all(color: c.bgBase, width: 1.5),
                  ),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    textAlign: TextAlign.center,
                    style: LipType.label.copyWith(
                      color: Colors.white,
                      fontSize: 9.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
