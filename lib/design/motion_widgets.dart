import 'package:flutter/material.dart';

import 'tokens.dart';

/// ===========================================================================
/// ENTRANCE
///
/// One arrival animation for the whole app: a short rise with a fade, on the
/// glide curve, staggered by position. Wrapping list items in this is what
/// makes a screen feel composed rather than dumped. Honours reduced motion by
/// simply appearing.
/// ===========================================================================
class Entrance extends StatefulWidget {
  const Entrance({super.key, required this.child, this.index = 0});

  final Widget child;

  /// Position in the stagger. Each step delays 45ms.
  final int index;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _c,
    curve: Motion.glide,
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 45 * widget.index.clamp(0, 14)), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _curve.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return widget.child;
    }
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}

/// Three dots breathing in sequence. The waiting signal for the splash and
/// anywhere a spinner would look mechanical.
class PulseDots extends StatefulWidget {
  const PulseDots({super.key, required this.color, this.size = 7});
  final Color color;
  final double size;

  @override
  State<PulseDots> createState() => _PulseDotsState();
}

class _PulseDotsState extends State<PulseDots>
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
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) => Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final t = ((_c.value + (2 - i) * 0.18) % 1.0);
        final lift = (t < 0.5 ? t : 1 - t) * 2; // 0..1..0
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.size * 0.4),
          child: Opacity(
            opacity: 0.35 + 0.65 * lift,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    ),
  );
}
