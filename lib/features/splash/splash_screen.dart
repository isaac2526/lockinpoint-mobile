import 'package:flutter/material.dart';

import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../design/wordmark.dart';

/// ===========================================================================
/// THE FIRST FRAME
///
/// A splash has one honest job: fill the gap between the icon being tapped
/// and the app being usable, and make that gap feel intentional. It must
/// never CREATE the gap.
///
/// So nothing here waits for anything. The animation runs for 900ms because
/// that is how long the motion takes to look finished, and the gate above it
/// swaps to the real screen the instant the keystore has been read — which is
/// usually sooner. If the app is ready in 300ms the student sees 300ms of
/// this and then their dashboard. The splash is never the reason they wait.
///
/// Everything it draws is already in memory: the mark is a CustomPainter, the
/// faces are bundled assets, and the season line comes from whatever the home
/// snapshot last knew. There is not one network request on this screen.
/// ===========================================================================
class LipSplash extends StatefulWidget {
  const LipSplash({super.key, this.season});

  /// The exam season, when the app already knows it from the last home
  /// snapshot. Absent on a first-ever launch, and that is fine — the line
  /// simply does not appear rather than showing a guess.
  final String? season;

  @override
  State<LipSplash> createState() => _LipSplashState();
}

class _LipSplashState extends State<LipSplash> with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  /// A slow, continuous ring sweep. Separate from [_c] so it keeps turning
  /// for as long as the splash lives rather than freezing at the end of the
  /// entrance — a stopped spinner reads as a hang.
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    _ring.dispose();
    super.dispose();
  }

  Animation<double> _in(
    double from,
    double to, {
    Curve curve = Curves.easeOut,
  }) => CurvedAnimation(
    parent: _c,
    curve: Interval(from, to, curve: curve),
  );

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final mark = _in(0, 0.55, curve: Motion.spring);
    final name = _in(0.30, 0.75);
    final motto = _in(0.45, 0.9);
    final foot = _in(0.6, 1);

    /* GENUINELY CENTRED.

       This was a Column of Spacer(flex: 3) … content … Spacer(flex: 4) …
       footer. Two things followed. The uneven flexes pushed the mark above
       the middle, and the footer took real height BELOW the second spacer, so
       the block a student actually looks at sat noticeably high — worse on a
       short screen, where the footer is a larger share of the page.

       A Stack fixes both. The mark and the wordmark are centred against the
       WHOLE screen, and the footer is pinned to the bottom where it belongs,
       taking no part in the centring at all. */
    return Scaffold(
      backgroundColor: c.bgBase,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ---- the mark, arriving inside a turning ring ----------
                  AnimatedBuilder(
                    animation: Listenable.merge([_c, _ring]),
                    builder: (context, child) => SizedBox(
                      width: 132,
                      height: 132,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(132, 132),
                            painter: _RingPainter(
                              sweep: _ring.value,
                              arrival: mark.value,
                              color: c.brand,
                              track: c.glassBorder,
                            ),
                          ),
                          Transform.scale(
                            scale: 0.7 + 0.3 * mark.value,
                            child: Opacity(opacity: mark.value, child: child),
                          ),
                        ],
                      ),
                    ),
                    child: const LipLogoMark(size: 76),
                  ),

                  const SizedBox(height: Gap.xl),

                  _Rise(
                    t: name,
                    child: Text(
                      'LockInPoint',
                      style: LipType.hero.copyWith(color: c.text1),
                    ),
                  ),
                  const SizedBox(height: Gap.sm),
                  _Rise(
                    t: motto,
                    child: Text(
                      'Lock in. Pass everything.',
                      style: LipType.body.copyWith(color: c.text2),
                    ),
                  ),

                  if (widget.season != null && widget.season!.isNotEmpty) ...[
                    const SizedBox(height: Gap.lg),
                    _Rise(
                      t: motto,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Gap.md,
                          vertical: Gap.xs + 2,
                        ),
                        decoration: BoxDecoration(
                          color: c.hues.amber.tint,
                          borderRadius: BorderRadius.circular(Radii.pill),
                        ),
                        child: Text(
                          widget.season!,
                          style: LipType.label.copyWith(
                            color: c.hues.amber.ink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Pinned, and outside the centring: a footer that takes part in
            // it is a footer that pushes the logo off centre.
            Positioned(
              left: Gap.lg,
              right: Gap.lg,
              bottom: Gap.xl,
              child: _Rise(
                t: foot,
                child: Column(
                  children: [
                    Text(
                      'JAMB · WAEC · NECO · NABTEB · GCE · Post-UTME',
                      style: LipType.caption.copyWith(color: c.text3),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Gap.sm),
                    Text(
                      'Built in Nigeria by Noesis Innovations',
                      style: LipType.caption.copyWith(color: c.text3),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fade up a few pixels. The whole entrance vocabulary of this screen.
class _Rise extends StatelessWidget {
  const _Rise({required this.t, required this.child});
  final Animation<double> t;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: t,
    builder: (_, c) => Opacity(
      opacity: t.value,
      child: Transform.translate(
        offset: Offset(0, 14 * (1 - t.value)),
        child: c,
      ),
    ),
    child: child,
  );
}

/// A track with a bright arc travelling around it. The arc grows as the mark
/// arrives, so the two motions read as one gesture rather than two widgets
/// animating near each other.
class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.sweep,
    required this.arrival,
    required this.color,
    required this.track,
  });

  final double sweep;
  final double arrival;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final centre = rect.center;
    final radius = size.width / 2 - 3;
    const twoPi = 6.283185307179586;

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = track,
    );

    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      sweep * twoPi - 1.5708,
      0.9 * arrival * twoPi * 0.25,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.sweep != sweep || old.arrival != arrival || old.color != color;
}
