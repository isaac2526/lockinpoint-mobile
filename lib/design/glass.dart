import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'tokens.dart';
import 'theme.dart';

/// The surface ladder: how far a thing sits above the page.
enum GlassTier { ultra, card, raised, deep, modal }

/// ===========================================================================
/// A SURFACE
///
/// A fill, a hairline, a SHADOW SIZED BY TIER, and a light sheen along the
/// top edge. Give it a [hue] and it takes on a feature's identity: the tint
/// becomes the fill and the ink becomes the border, so the pairing is decided
/// in the palette rather than guessed here.
///
/// IT USED TO BE FLAT, AND IN LIGHT MODE IT WAS INVISIBLE.
///
/// The shadow rendered only when a caller passed `elevated: true`, and almost
/// nothing did. glassUltra, glassCard, glassRaised and glassModal were all
/// #FFFFFF. glassHighlight — the sheen, the one thing that makes a surface
/// read as glass rather than as paper — was declared, set to fully
/// transparent, and never read by a single widget. So a card was a white
/// rectangle on a near-white page with a hairline round it, which is exactly
/// what "the whole surface ladder is one colour" means.
///
/// Depth is a property of the TIER now, not a favour a caller remembers to
/// ask for. `elevated` still lifts a surface one step further for the rare
/// thing that must float above its own neighbours.
///
/// [blurred] survives for chrome only — a sheet, a dialog, the overlay Lumi
/// arrives in. It defaults to FALSE because `BackdropFilter` forces everything
/// beneath it into an offscreen buffer every frame, and one per card in a
/// scrolling list will drop frames on a ₦45,000 phone. The discipline is
/// enforced by the default, not by a note nobody re-reads.
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
    this.hue,
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

  /// The feature colour this surface belongs to. When set, the fill is the
  /// hue's tint and the border is its ink — the pair the palette guarantees
  /// is readable together.
  final LipHue? hue;

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

  /// How far off the page this tier sits. `deep` is RECESSED — a well, not a
  /// card — so it casts nothing.
  ///
  /// These are deliberately modest. A drop shadow per card is cheap; a
  /// BackdropFilter per card is not, and this app has to stay smooth on a
  /// ₦45,000 phone. Depth here is painted, not composited.
  List<BoxShadow> _shadows(LipColors c) {
    if (tier == GlassTier.deep) return const [];
    return switch (tier) {
      GlassTier.ultra => [
        BoxShadow(color: c.shadow, blurRadius: 10, offset: const Offset(0, 2)),
      ],
      GlassTier.card => [
        BoxShadow(color: c.shadow, blurRadius: 16, offset: const Offset(0, 4)),
      ],
      GlassTier.raised => [
        BoxShadow(
          color: c.shadowRaised,
          blurRadius: 26,
          offset: const Offset(0, 8),
        ),
      ],
      GlassTier.modal => [
        BoxShadow(
          color: c.shadowRaised,
          blurRadius: 40,
          offset: const Offset(0, 16),
        ),
      ],
      GlassTier.deep => const [],
    };
  }

  /// The sheen: light catching the top edge, fading out by a third of the
  /// way down. It is what separates glass from paper, and it costs one
  /// gradient — no buffer, no filter, no frame budget.
  bool get _sheen => tier == GlassTier.raised || tier == GlassTier.modal;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final shape = BorderRadius.circular(radius);

    final tinted = hue;
    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: tinted?.tint ?? _fill(c),
        borderRadius: shape,
        border: Border.all(
          color: selected
              ? c.brand
              : (tinted == null
                    ? c.glassBorder
                    : tinted.ink.withValues(alpha: c.isDark ? 0.22 : 0.16)),
          width: selected ? 1.6 : 1,
        ),
        /* THE SHEEN, at last. A tinted surface keeps its own colour — laying
           white over a feature's tint would wash out the very thing the tint
           is there to say. */
        gradient: _sheen && tinted == null
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.34],
                colors: [c.glassHighlight, _fill(c)],
              )
            : null,
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

    /* DEPTH IS THE TIER'S, NOT THE CALLER'S. This used to run only when
       somebody passed `elevated: true`, and almost nobody did — so nearly
       every card in the app was drawn with no shadow at all. */
    final shadows = <BoxShadow>[
      ...(_shadows(c)),
      if (selected)
        BoxShadow(color: c.ring, blurRadius: 18, offset: const Offset(0, 6)),
      if (elevated)
        BoxShadow(
          color: c.shadowRaised,
          blurRadius: 34,
          offset: const Offset(0, 14),
        ),
    ];
    if (shadows.isNotEmpty) {
      surface = DecoratedBox(
        decoration: BoxDecoration(borderRadius: shape, boxShadow: shadows),
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
