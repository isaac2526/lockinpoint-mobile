import 'package:flutter/material.dart';

import 'glass.dart';
import 'theme.dart';
import 'tokens.dart';
import 'typography.dart';

/// ===========================================================================
/// THE PRIMITIVES
///
/// Every screen is built from these. A screen that reaches past them for a
/// raw Container with a hand-picked colour is how forty screens start looking
/// like they were built by forty people.
/// ===========================================================================

/// The uppercase micro-label above a group. "CHOOSE YOUR MODE".
class LipLabel extends StatelessWidget {
  const LipLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: LipType.label.copyWith(color: context.lip.text3),
  );
}

/// Semantic tone. Kept separate from the brand accent so "correct" is never
/// confused with "selected" — a distinction a student learns in one second and
/// relies on for an hour.
enum ChipTone { neutral, brand, success, danger, warning, gold }

class LipChip extends StatelessWidget {
  const LipChip(
    this.text, {
    super.key,
    this.tone = ChipTone.neutral,
    this.count,
    this.onTap,
    this.selected = false,
  });

  final String text;
  final ChipTone tone;

  /// A trailing number — how many questions a topic holds, say.
  final int? count;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final (fg, bg) = switch (selected ? ChipTone.brand : tone) {
      ChipTone.neutral => (c.text2, c.glassDeep),
      ChipTone.brand => (c.brand, c.brandSoft),
      ChipTone.success => (c.success, c.successSoft),
      ChipTone.danger => (c.danger, c.dangerSoft),
      ChipTone.warning => (c.warning, c.warningSoft),
      ChipTone.gold => (c.accent, c.accentSoft),
    };

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: selected ? c.brand : c.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: LipType.smallStrong.copyWith(color: fg)),
          if (count != null) ...[
            const SizedBox(width: Gap.sm),
            Text(
              '$count',
              style: LipType.label.copyWith(color: fg.withValues(alpha: 0.75)),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return chip;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: chip,
      ),
    );
  }
}

/// A choice in a group — the mode cards, the source cards. One icon, a title,
/// a line of explanation, and a brand ring when it is the chosen one.
class LipChoiceCard extends StatelessWidget {
  const LipChoiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GlassSurface(
        tier: GlassTier.raised,
        selected: selected,
        onTap: enabled ? onTap : null,
        semanticLabel: '$title. $subtitle',
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 19, color: selected ? c.brand : c.text2),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    title,
                    style: LipType.subheading.copyWith(
                      color: selected ? c.brand : c.text1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.sm),
            Text(subtitle, style: LipType.caption.copyWith(color: c.text3)),
          ],
        ),
      ),
    );
  }
}

/// A number and its name. Score, streak, questions ready.
class LipStat extends StatelessWidget {
  const LipStat({
    super.key,
    required this.value,
    required this.label,
    this.tone = ChipTone.neutral,
  });

  final String value;
  final String label;
  final ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final colour = switch (tone) {
      ChipTone.success => c.success,
      ChipTone.danger => c.danger,
      ChipTone.gold => c.accent,
      ChipTone.brand => c.brand,
      _ => c.text1,
    };
    return GlassSurface(
      tier: GlassTier.deep,
      radius: Radii.md,
      padding: const EdgeInsets.symmetric(vertical: Gap.md, horizontal: Gap.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: LipType.monoBig.copyWith(color: colour)),
          const SizedBox(height: 2),
          Text(
            label,
            style: LipType.caption.copyWith(color: c.text3),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// The primary action. Gold means "this is the serious one" — starting a timed
/// CBT, submitting a paper — exactly as it does on the website.
class LipButton extends StatelessWidget {
  const LipButton({
    super.key,
    required this.label,
    this.onPressed,
    this.gold = false,
    this.busy = false,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool gold;
  final bool busy;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final bg = gold ? c.gold : c.brand;
    // Gold is a light colour in both themes, so its text is always the dark
    // ink. Deriving this rather than hardcoding keeps it right if gold moves.
    final fg = gold
        ? const Color(0xFF241A00)
        : (c.isDark ? const Color(0xFF040B22) : Colors.white);

    final button = FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(backgroundColor: bg, foregroundColor: fg),
      child: busy
          ? SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: Gap.sm),
                ],
                Text(label),
              ],
            ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// ===========================================================================
/// WAITING, EMPTINESS AND FAILURE
///
/// Three states every screen needs and most apps bolt on last. Building them
/// as primitives means a screen gets all three for free and none of them look
/// improvised.
/// ===========================================================================

/// A shimmering placeholder shaped like the content that is coming.
///
/// It waits 200ms before appearing: a response that arrives in 80ms should
/// never flash a skeleton, because a flash reads as a glitch, not as speed.
class LipSkeleton extends StatefulWidget {
  const LipSkeleton({
    super.key,
    this.height = 16,
    this.width,
    this.radius = Radii.sm,
  });
  final double height;
  final double? width;
  final double radius;

  @override
  State<LipSkeleton> createState() => _LipSkeletonState();
}

class _LipSkeletonState extends State<LipSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final x = _c.value * 2 - 1;
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(x - 0.6, 0),
              end: Alignment(x + 0.6, 0),
              colors: [c.glassDeep, c.glassRaised, c.glassDeep],
            ),
          ),
        );
      },
    );
  }
}

/// Nothing here yet — and what to do about it. An empty state without an
/// action leaves the student stuck on a dead screen.
class LipEmpty extends StatelessWidget {
  const LipEmpty({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 58,
              width: 58,
              decoration: BoxDecoration(
                color: c.brandSoft,
                borderRadius: BorderRadius.circular(Radii.lg),
              ),
              child: Icon(icon, color: c.brand, size: 26),
            ),
            const SizedBox(height: Gap.lg),
            Text(
              title,
              style: LipType.heading.copyWith(color: c.text1),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Gap.sm),
            Text(
              message,
              style: LipType.small.copyWith(color: c.text3),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: Gap.xl),
              LipButton(
                label: actionLabel!,
                onPressed: onAction,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Something went wrong — said in a way that tells the student what to do.
/// No apology, no error code, always a way forward.
class LipError extends StatelessWidget {
  const LipError({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => LipEmpty(
    icon: Icons.wifi_off_rounded,
    title: 'That did not load',
    message: message,
    actionLabel: onRetry == null ? null : 'Try again',
    onAction: onRetry,
  );
}

/// The bar that appears when the phone loses signal. Not a dialog — a student
/// mid-question must not be interrupted, only informed.
class LipOfflineBar extends StatelessWidget {
  const LipOfflineBar({super.key, this.hasVault = false});

  /// Whether anything is downloaded, which changes the message from a warning
  /// into a reassurance.
  final bool hasVault;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    return Container(
      width: double.infinity,
      color: hasVault ? c.successSoft : c.warningSoft,
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
      child: Row(
        children: [
          Icon(
            hasVault ? Icons.offline_bolt_rounded : Icons.cloud_off_rounded,
            size: 15,
            color: hasVault ? c.success : c.warning,
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              hasVault
                  ? 'Offline · your downloaded packs still work'
                  : 'No connection',
              style: LipType.caption.copyWith(
                color: hasVault ? c.success : c.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
