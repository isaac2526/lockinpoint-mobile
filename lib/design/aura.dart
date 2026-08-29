import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tokens.dart';
import 'theme.dart';

/// ===========================================================================
/// THE BRAND AURA
///
/// The website's `BrandAura` is three blurred orbs of blue, gold and violet
/// behind every page, with the LB mark standing in the middle of them. It is
/// what the glass blurs — frosted panes over a flat colour have nothing to
/// prove they are frosted.
///
/// I checked before writing this: there is no three.js and no WebGL on the
/// website. It is pure CSS. So this is not an approximation of a 3D scene, it
/// is the same thing drawn the same way, and it can drift more smoothly here
/// than it does in a browser because it is painted on the raster thread.
///
/// Painted with a CustomPainter rather than stacked blurred Containers: three
/// radial gradients cost one paint, whereas three `ImageFiltered` layers cost
/// three offscreen buffers and would eat the frame budget on a cheap phone
/// before a single screen had drawn.
/// ===========================================================================
class BrandAura extends StatefulWidget {
  const BrandAura({super.key, this.child, this.animate = true});

  final Widget? child;

  /// Off in tests, and off when the platform asks for reduced motion.
  final bool animate;

  @override
  State<BrandAura> createState() => _BrandAuraState();
}

class _BrandAuraState extends State<BrandAura>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 34),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _drift.repeat();
  }

  @override
  void didUpdateWidget(covariant BrandAura old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_drift.isAnimating) {
      _drift.repeat();
    } else if (!widget.animate && _drift.isAnimating) {
      _drift.stop();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    // A student who has asked the system to reduce motion should not be given
    // a slowly breathing background.
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final live = widget.animate && !reduce;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: c.bgGradient,
          stops: const [0.0, 0.4, 0.74, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (live)
            AnimatedBuilder(
              animation: _drift,
              builder: (context, _) =>
                  CustomPaint(painter: _AuraPainter(c, _drift.value)),
            )
          else
            CustomPaint(painter: _AuraPainter(c, 0)),
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

class _AuraPainter extends CustomPainter {
  _AuraPainter(this.c, this.t);

  final LipColors c;

  /// 0..1, one full cycle of the drift.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final wobble = math.sin(t * 2 * math.pi);
    final wobble2 = math.cos(t * 2 * math.pi);

    // Blue, upper left — the dominant light.
    _orb(
      canvas,
      Offset(w * (0.18 + 0.05 * wobble), h * (0.12 + 0.03 * wobble2)),
      w * 0.72,
      c.glowA,
    );
    // Gold, lower right — the warm counterweight.
    _orb(
      canvas,
      Offset(w * (0.86 - 0.04 * wobble2), h * (0.74 + 0.04 * wobble)),
      w * 0.62,
      c.glowB,
    );
    // The third, low and central, filling the space between them.
    _orb(
      canvas,
      Offset(w * (0.5 + 0.06 * wobble2), h * (1.02 - 0.03 * wobble)),
      w * 0.80,
      c.glowC,
    );
  }

  void _orb(Canvas canvas, Offset centre, double radius, Color colour) {
    final rect = Rect.fromCircle(center: centre, radius: radius);
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [colour, colour.withValues(alpha: 0)],
          stops: const [0.0, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_AuraPainter old) => old.t != t || old.c != c;
}
