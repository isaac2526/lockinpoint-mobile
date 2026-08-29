import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'tokens.dart';
import 'theme.dart';

/// The six tiers of glass, matching the website's ladder exactly.
enum GlassTier { ultra, card, raised, deep, modal }

/// ===========================================================================
/// GLASS, WITH A BUDGET
///
/// `BackdropFilter` is the single most expensive thing this app can ask a
/// cheap Android phone to do: it forces everything beneath into an offscreen
/// buffer, every frame. Put one on each card in a scrolling list and a ₦45,000
/// phone drops frames before the list has finished its first fling.
///
/// So [GlassSurface] takes [blurred] and it defaults to FALSE.
///
///   blurred: true   · chrome only — the bottom bar, sheets, dialogs, the
///                     overlay a calculator or Lumi arrives in. A handful on
///                     screen at once, never in a scroller.
///   blurred: false  · everything else. A translucent fill, a hairline border,
///                     the same inner highlight. To the eye it belongs to the
///                     same family; to the GPU it is an ordinary rectangle.
///
/// That is the whole discipline. It is enforced by the default, not by a note
/// in a document nobody re-reads.
/// ===========================================================================
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.tier = GlassTier.card,
    this.blurred = false,
    this.radius = Radii.lg,
    this.padding = const EdgeInsets.all(Gap.lg),
    this.margin,
    this.onTap,
    this.selected = false,
    this.seam = false,
    this.elevated = false,
    this.semanticLabel,
  });

  final Widget child;
  final GlassTier tier;
  final bool blurred;
  final double radius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  /// Draws the brand ring. Used for a chosen option, a picked year, a mode.
  final bool selected;

  /// The gold hairline across the top — the website's `seam`, reserved for a
  /// surface that is meant to feel important.
  final bool seam;

  final bool elevated;
  final String? semanticLabel;

  Color _fill(LipColors c) => switch (tier) {
    GlassTier.ultra => c.glassUltra,
    GlassTier.card => c.glassCard,
    GlassTier.raised => c.glassRaised,
    GlassTier.deep => c.glassDeep,
    GlassTier.modal => c.glassModal,
  };

  double _blur() => switch (tier) {
    GlassTier.ultra || GlassTier.card => Blurs.one,
    GlassTier.raised || GlassTier.deep => Blurs.two,
    GlassTier.modal => Blurs.three,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final shape = BorderRadius.circular(radius);

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: _fill(c),
        borderRadius: shape,
        border: Border.all(
          color: selected ? c.brand : c.glassBorder,
          width: selected ? 1.6 : 1,
        ),
        // The inner top highlight is what makes a flat rectangle read as a
        // pane of glass catching light rather than a grey box.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.glassHighlight, c.glassHighlight.withValues(alpha: 0)],
          stops: const [0, 0.42],
        ),
      ),
      child: Padding(padding: padding, child: child),
    );

    if (seam) surface = _Seam(radius: radius, child: surface);

    if (blurred) {
      surface = ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: _blur(), sigmaY: _blur()),
          child: surface,
        ),
      );
    } else {
      surface = ClipRRect(borderRadius: shape, child: surface);
    }

    if (elevated || selected) {
      surface = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: shape,
          boxShadow: [
            BoxShadow(
              color: selected ? c.ring : c.shadow,
              blurRadius: selected ? 18 : 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: surface,
      );
    }

    if (onTap != null) {
      surface = _Pressable(onTap: onTap!, radius: radius, child: surface);
    }

    if (margin != null) surface = Padding(padding: margin!, child: surface);
    if (semanticLabel != null) {
      /* container + excludeSemantics so a screen reader announces ONE thing —
         "Timed CBT. A strict clock., button" — rather than reading the icon,
         the title and the subtitle as three disconnected fragments. */
      surface = Semantics(
        label: semanticLabel,
        button: onTap != null,
        container: true,
        excludeSemantics: true,
        child: surface,
      );
    }
    return surface;
  }
}

/// The gold hairline. Faint at the edges, bright in the middle — the same
/// gradient the website paints across the top of a raised pane.
class _Seam extends StatelessWidget {
  const _Seam({required this.child, required this.radius});
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    return Stack(
      children: [
        child,
        Positioned(
          left: radius * 0.6,
          right: radius * 0.6,
          top: 0,
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  c.gold.withValues(alpha: 0),
                  c.gold.withValues(alpha: 0.55),
                  c.glassBorderStrong,
                  c.gold.withValues(alpha: 0.45),
                  c.gold.withValues(alpha: 0),
                ],
                stops: const [0.04, 0.22, 0.5, 0.78, 0.96],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A press that answers immediately. The website's `lift` is a hover effect,
/// and a phone has no hover — so the equivalent is a small, fast scale on
/// touch down. 40ms in, 140ms out: the app feels like it heard you.
class _Pressable extends StatefulWidget {
  const _Pressable({
    required this.child,
    required this.onTap,
    required this.radius,
  });
  final Widget child;
  final VoidCallback onTap;
  final double radius;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.975 : 1,
        duration: _down ? const Duration(milliseconds: 40) : Motion.fast,
        curve: Motion.spring,
        child: widget.child,
      ),
    );
  }
}
