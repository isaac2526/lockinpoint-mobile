import 'package:flutter/material.dart';

import 'theme.dart';
import 'typography.dart';

/// ===========================================================================
/// THE CROWNED MARK
///
/// A faithful port of the website's `LogoMark`: the graduated LP, gold dot on
/// the L, gold check scoring the point, the cap seated at ten degrees on the P.
/// Same 512 viewBox, same coordinates, same gradients — drawn on a Canvas
/// rather than pulled in as an SVG so it needs no parser and no extra package.
/// ===========================================================================
class LipLogoMark extends StatelessWidget {
  const LipLogoMark({super.key, this.size = 34});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _MarkPainter()),
  );
}

class _MarkPainter extends CustomPainter {
  // The website's gradients, exactly.
  static const _blueFrom = Color(0xFF4A79F2);
  static const _blueTo = Color(0xFF0F2C86);
  static const _goldFrom = Color(0xFFF7D269);
  static const _goldTo = Color(0xFFC98F1B);
  static const _capShadow = Color(0xFF10307E);

  @override
  void paint(Canvas canvas, Size size) {
    // Everything below is written against the 512 grid the SVG uses, then
    // scaled once — so the coordinates can be compared to the original line
    // for line rather than re-derived.
    final k = size.width / 512.0;
    canvas.save();
    canvas.scale(k);

    final whole = Rect.fromLTWH(0, 0, 512, 512);
    final blue = Paint()
      ..shader = const LinearGradient(colors: [_blueFrom, _blueTo])
          .createShader(whole);
    final gold = Paint()
      ..shader = const LinearGradient(colors: [_goldFrom, _goldTo])
          .createShader(whole);

    // The blue tile, then the near-white face inside it.
    canvas.drawRRect(
      RRect.fromRectAndRadius(whole, const Radius.circular(116)),
      blue,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(46, 46, 420, 420),
        const Radius.circular(96),
      ),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFE9EFFF)],
        ).createShader(const Rect.fromLTWH(46, 46, 420, 420)),
    );

    // The thin gold keyline.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(68, 68, 376, 376),
        const Radius.circular(80),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = const Color(0xFFE4B84C).withValues(alpha: 0.55),
    );

    final stroke = Paint()
      ..shader = blue.shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 42
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // The L.
    canvas.drawPath(
      Path()
        ..moveTo(160, 178)
        ..lineTo(160, 364)
        ..lineTo(260, 364),
      stroke,
    );
    // The P's stem.
    canvas.drawPath(
      Path()
        ..moveTo(244, 178)
        ..lineTo(244, 280),
      stroke,
    );
    // The P's bowl — an arc of radius 51, exactly as the SVG's `a 51 51`.
    canvas.drawPath(
      Path()
        ..moveTo(244, 189)
        ..lineTo(291, 189)
        ..arcToPoint(
          const Offset(291, 291),
          radius: const Radius.circular(51),
          clockwise: true,
        )
        ..lineTo(244, 291),
      stroke,
    );

    // The gold dot crowning the L.
    canvas.drawCircle(const Offset(160, 178), 18, gold);

    // The gold check that scores the point.
    canvas.drawPath(
      Path()
        ..moveTo(290, 330)
        ..lineTo(314, 357)
        ..lineTo(363, 295),
      Paint()
        ..shader = gold.shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = 25
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // The graduation cap, seated at ten degrees.
    canvas.save();
    canvas.translate(182, 124);
    canvas.rotate(10 * 3.1415926535 / 180);
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(108, -41)
        ..lineTo(216, 0)
        ..lineTo(108, 41)
        ..close(),
      blue,
    );
    canvas.drawPath(
      Path()
        ..moveTo(18, 0)
        ..lineTo(108, -34)
        ..lineTo(198, 0)
        ..lineTo(108, 34)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );
    canvas.drawPath(
      Path()
        ..moveTo(56, 14)
        ..lineTo(56, 41)
        ..cubicTo(56, 61, 160, 61, 160, 41)
        ..lineTo(160, 14)
        ..lineTo(108, 34)
        ..close(),
      Paint()..color = _capShadow,
    );
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => false;
}

/// The mark and the name together. "LockIn" in the ink, "Point" in the accent
/// blue — the website's own split.
class LipWordmark extends StatelessWidget {
  const LipWordmark({super.key, this.size = 30, this.markOnly = false});
  final double size;
  final bool markOnly;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    if (markOnly) return LipLogoMark(size: size);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LipLogoMark(size: size),
        SizedBox(width: size * 0.28),
        RichText(
          text: TextSpan(
            style: LipType.title.copyWith(
              fontSize: size * 0.66,
              color: c.text1,
              letterSpacing: -0.6,
            ),
            children: [
              const TextSpan(text: 'LockIn'),
              TextSpan(
                text: 'Point',
                style: TextStyle(color: c.brand),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
