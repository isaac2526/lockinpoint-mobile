import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme_controller.dart';
import '../../core/api.dart';
import '../../core/config.dart';
import '../../design/components.dart';
import '../../design/glass.dart';
import '../../design/motion_widgets.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../auth/auth_controller.dart';
import '../content/content_repository.dart';
import '../home/dashboard_screen.dart';

/// ===========================================================================
/// THE STUDENT'S PROFILE
///
/// The website's /profile, as a phone screen: who the account belongs to,
/// whether it is activated, the referral code that earns ₦500 a friend, and
/// the doors — WhatsApp channel, support email, appearance, log out.
///
/// It reads the SAME snapshot the dashboard holds, so opening it costs no
/// request at all: the identity was already fetched in the home's one round
/// trip, and pull-to-refresh here refreshes both screens at once.
/// ===========================================================================
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, this.embedded = false});

  /// True when this screen is a TAB inside the shell rather than a pushed
  /// route. An embedded screen drops its own app bar and back button — two
  /// headers stacked on one screen is the fastest way to make an app feel
  /// like a collection of pages instead of one product.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: embedded ? null : AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
          child: snapshot.when(
            loading: () => ListView(
              padding: const EdgeInsets.all(Gap.lg),
              children: const [
                LipSkeleton(height: 96),
                SizedBox(height: Gap.md),
                LipSkeleton(height: 72),
                SizedBox(height: Gap.md),
                LipSkeleton(height: 220),
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
                  onRetry: () => ref.read(dashboardProvider.notifier).refresh(),
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
    final student =
        (data['student'] as Map?)?.cast<String, dynamic>() ?? const {};

    final first = student['name'] as String? ?? 'Champion';
    final surname = student['surname'] as String? ?? '';
    final fullName = '$first $surname'.trim();
    final email = student['email'] as String? ?? '';
    final username = student['username'] as String?;
    final phone = student['phone'] as String?;
    final dial = student['dialCode'] as String? ?? '';
    final country = student['countryCode'] as String?;
    final activated = student['activated'] == true;
    final code = student['referralCode'] as String?;
    final productKey = student['productKey'] as String?;
    final state = student['state'] as String?;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.huge),
      children: [
        // ---- who this is ---------------------------------------------
        Entrance(
          child: GlassSurface(
            tier: GlassTier.raised,
            seam: true,
            semanticLabel: 'Signed in as $fullName, $email',
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: c.brandSoft,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.brand, width: 1.4),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    first.isEmpty ? '?' : first[0].toUpperCase(),
                    style: LipType.title.copyWith(color: c.brand),
                  ),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: LipType.subheading.copyWith(color: c.text1),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: LipType.small.copyWith(color: c.text3),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.md),

        // ---- refer and earn ------------------------------------------
        if (code != null) ...[
          Entrance(
            index: 1,
            child: GlassSurface(
              tier: GlassTier.raised,
              onTap: () => _copy(
                context,
                '${AppConfig.apiBase}/signup?ref=$code',
                'Your invite link is copied. Send it to a friend!',
              ),
              semanticLabel:
                  'Refer and earn 500 naira. Tap to copy your invite link.',
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: c.accentSoft,
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '₦',
                      style: LipType.subheading.copyWith(color: c.accent),
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Refer and earn ₦500',
                          style: LipType.smallStrong.copyWith(color: c.text1),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Every friend who joins with your link and '
                          'activates pays you. Tap to copy your link.',
                          style: LipType.caption.copyWith(color: c.text3),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.copy_rounded, size: 18, color: c.text3),
                ],
              ),
            ),
          ),
          const SizedBox(height: Gap.md),
        ],

        // ---- the product key -----------------------------------------
        if (productKey != null && productKey.isNotEmpty) ...[
          Entrance(
            index: 2,
            child: GlassSurface(
              tier: GlassTier.raised,
              hue: c.hues.indigo,
              onTap: () => _copy(
                context,
                productKey,
                'Product Key copied. Give it to your parent or teacher.',
              ),
              semanticLabel: 'Your Product Key is $productKey. Tap to copy it.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'YOUR PRODUCT KEY',
                        style: LipType.label.copyWith(color: c.hues.indigo.ink),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.copy_rounded,
                        size: 16,
                        color: c.hues.indigo.ink,
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.sm),
                  Text(
                    productKey,
                    style: LipType.monoBig.copyWith(color: c.hues.indigo.ink),
                  ),
                  const SizedBox(height: Gap.xs),
                  Text(
                    'A parent, teacher or school uses this to follow your '
                    'progress in the Guardian Portal. It is not a password '
                    'and it unlocks nothing on its own.',
                    style: LipType.caption.copyWith(color: c.text3),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Gap.md),
        ],

        // ---- the record ----------------------------------------------
        Entrance(
          index: 3,
          child: GlassSurface(
            tier: GlassTier.card,
            child: Column(
              children: [
                _DetailRow(label: 'Username', value: username ?? '·'),
                _DetailRow(
                  label: 'Phone',
                  value: (phone == null || phone.isEmpty)
                      ? '·'
                      : '$dial $phone'.trim(),
                ),
                _DetailRow(label: 'Country', value: country ?? '·'),
                _DetailRow(label: 'State', value: state ?? '·'),
                _DetailRow(
                  label: 'Account',
                  value: activated ? 'Activated' : 'Not activated yet',
                  valueColor: activated ? c.success : c.warning,
                ),
                if (code != null)
                  _DetailRow(
                    label: 'Referral code',
                    value: code,
                    onTap: () => _copy(context, code, 'Referral code copied.'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.lg),

        // ---- appearance ----------------------------------------------
        const LipLabel('Appearance'),
        const SizedBox(height: Gap.sm),
        Entrance(index: 4, child: _ThemeChoice()),
        const SizedBox(height: Gap.lg),

        // ---- reach us ------------------------------------------------
        // Every row below comes from the backend. A new support line is a row
        // in the admin panel, not a release.
        const LipLabel('Stay connected'),
        const SizedBox(height: Gap.sm),
        Entrance(index: 5, child: _ContactCard()),
        const SizedBox(height: Gap.xl),

        // ---- the exit ------------------------------------------------
        TextButton.icon(
          onPressed: () => ref.read(authControllerProvider.notifier).logOut(),
          icon: const Icon(Icons.logout_rounded, size: 17),
          label: const Text('Log out'),
        ),
      ],
    );
  }

  void _copy(BuildContext context, String text, String toast) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(toast)));
  }
}

/// ===========================================================================
/// HOW TO REACH LOCKINPOINT — from the backend, every time.
///
/// The WhatsApp channel and the support address used to be constants in
/// `config.dart`, which meant changing a phone number meant shipping an APK.
/// They are rows now, and a channel is a LIST: two support numbers show as
/// two rows, exactly as the team runs them.
///
/// The Guardian Portal sits here too — a link out to a website, deliberately,
/// because a parent following a candidate should not have to install a second
/// app on a phone they may share.
/// ===========================================================================
class _ContactCard extends ConsumerWidget {
  static const _order = [
    'whatsapp',
    'phone',
    'email',
    'channel',
    'feedback',
    'facebook',
    'instagram',
    'x',
    'tiktok',
    'youtube',
    'telegram',
    'rate',
    'share',
    'about',
    'link',
  ];

  static const _icons = <String, IconData>{
    'whatsapp': Icons.chat_rounded,
    'phone': Icons.call_rounded,
    'email': Icons.mail_rounded,
    'channel': Icons.campaign_rounded,
    'feedback': Icons.rate_review_rounded,
    'facebook': Icons.public_rounded,
    'instagram': Icons.camera_alt_rounded,
    'x': Icons.public_rounded,
    'tiktok': Icons.music_note_rounded,
    'youtube': Icons.play_circle_rounded,
    'telegram': Icons.send_rounded,
    'rate': Icons.star_rounded,
    'share': Icons.share_rounded,
    'about': Icons.info_rounded,
    'link': Icons.link_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;
    final contacts = ref.watch(supportContactsProvider).value ?? const [];

    final sorted = [
      ...contacts,
    ]..sort((a, b) => _order.indexOf(a.kind).compareTo(_order.indexOf(b.kind)));

    IconData iconFor(String kind) => _icons[kind] ?? Icons.link_rounded;
    Color tintFor(String kind) => switch (kind) {
      'whatsapp' || 'phone' => c.hues.green.ink,
      'email' => c.hues.blue.ink,
      'channel' => c.hues.violet.ink,
      'feedback' || 'rate' => c.hues.amber.ink,
      _ => c.hues.slate.ink,
    };

    final rows = <Widget>[
      // The Guardian Portal is ours, not a support contact, so it is not in
      // the table — but it belongs in the same list to a student's eye.
      _LinkRow(
        icon: Icons.supervisor_account_rounded,
        color: c.hues.indigo.ink,
        title: 'Guardian Portal',
        subtitle: 'For a parent, teacher or school following you',
        onTap: () => launchUrl(
          Uri.parse(AppConfig.guardianPortal),
          mode: LaunchMode.externalApplication,
        ),
      ),
      for (final k in sorted)
        _LinkRow(
          icon: iconFor(k.kind),
          color: tintFor(k.kind),
          title: k.label.isEmpty ? k.kind : k.label,
          subtitle: k.description.isNotEmpty ? k.description : k.value,
          onTap: () => launchUrl(k.uri, mode: LaunchMode.externalApplication),
        ),
    ];

    return GlassSurface(
      tier: GlassTier.card,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: c.glassBorder),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// One fact about the account: its name on the left, its value on the right.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.onTap,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.sm + 2),
      child: Row(
        children: [
          Text(label, style: LipType.small.copyWith(color: c.text3)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: LipType.smallStrong.copyWith(color: valueColor ?? c.text1),
              textAlign: TextAlign.right,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: Gap.sm),
            Icon(Icons.copy_rounded, size: 14, color: c.text3),
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

/// System, light, dark — the same three states the controller holds, each one
/// tap away, the current one ringed.
class _ThemeChoice extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeControllerProvider).value ?? ThemeMode.light;
    final set = ref.read(themeControllerProvider.notifier).set;

    Widget option(ThemeMode m, IconData icon, String label) => Expanded(
      child: Semantics(
        button: true,
        selected: mode == m,
        label: '$label theme',
        child: GlassSurface(
          tier: GlassTier.card,
          selected: mode == m,
          onTap: () => set(m),
          padding: const EdgeInsets.symmetric(vertical: Gap.md),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: mode == m ? context.lip.brand : context.lip.text2,
              ),
              const SizedBox(height: Gap.xs),
              Text(
                label,
                style: LipType.label.copyWith(
                  color: mode == m ? context.lip.brand : context.lip.text2,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Row(
      children: [
        option(ThemeMode.system, Icons.brightness_auto_rounded, 'System'),
        const SizedBox(width: Gap.sm),
        option(ThemeMode.light, Icons.light_mode_rounded, 'Light'),
        const SizedBox(width: Gap.sm),
        option(ThemeMode.dark, Icons.dark_mode_rounded, 'Dark'),
      ],
    );
  }
}

/// A door out of the app: icon, name, where it leads.
class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: LipType.smallStrong.copyWith(color: c.text1),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: LipType.caption.copyWith(color: c.text3),
                  ),
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
