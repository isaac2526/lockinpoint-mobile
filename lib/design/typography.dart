import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ===========================================================================
/// THE BRAND TYPOGRAPHY LAW
///
/// The website states it plainly in `src/lib/fonts.ts`:
///
///     Space Grotesk (display) · Inter (body) · JetBrains Mono (numbers)
///
/// The app keeps all three. A more fashionable face would make the app look
/// like a different product, and looking like the same product is the whole
/// brief. Numbers get JetBrains Mono with tabular figures so a score, a
/// countdown or a question count never jitters as its digits change — which
/// on a running CBT clock is the difference between calm and cheap.
/// ===========================================================================
abstract final class LipType {
  static TextStyle _display(
    double size,
    FontWeight w, {
    double? height,
    double? spacing,
  }) => GoogleFonts.spaceGrotesk(
    fontSize: size,
    fontWeight: w,
    height: height,
    letterSpacing: spacing,
  );

  static TextStyle _body(
    double size,
    FontWeight w, {
    double? height,
    double? spacing,
  }) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: w,
    height: height,
    letterSpacing: spacing,
  );

  static TextStyle _mono(double size, FontWeight w, {double? spacing}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: w,
        letterSpacing: spacing,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  // ---- display · Space Grotesk -------------------------------------------
  static TextStyle get hero =>
      _display(32, FontWeight.w700, height: 1.14, spacing: -0.7);
  static TextStyle get title =>
      _display(24, FontWeight.w700, height: 1.2, spacing: -0.4);
  static TextStyle get heading =>
      _display(19, FontWeight.w600, height: 1.25, spacing: -0.2);
  static TextStyle get subheading => _display(16, FontWeight.w600, height: 1.3);

  // ---- body · Inter -------------------------------------------------------
  static TextStyle get body => _body(15, FontWeight.w400, height: 1.5);
  static TextStyle get bodyStrong => _body(15, FontWeight.w600, height: 1.5);
  static TextStyle get small => _body(13, FontWeight.w400, height: 1.45);
  static TextStyle get smallStrong => _body(13, FontWeight.w600, height: 1.45);
  static TextStyle get caption => _body(11.5, FontWeight.w400, height: 1.4);

  /// A question stem. Larger and looser than ordinary body text, because a
  /// student reads it slowly, once, and often on a bus.
  static TextStyle get question => _body(17, FontWeight.w400, height: 1.58);

  /// An answer option. Slightly tighter than the stem so the two are
  /// distinguishable at a glance without a rule between them.
  static TextStyle get option => _body(15.5, FontWeight.w400, height: 1.42);

  // ---- numbers and labels · JetBrains Mono --------------------------------
  static TextStyle get mono => _mono(14, FontWeight.w500);
  static TextStyle get monoBig => _mono(22, FontWeight.w600, spacing: -0.5);

  /// The uppercase micro-label above a group of choices. Letter-spaced,
  /// because uppercase without tracking reads as shouting.
  static TextStyle get label => _mono(10.5, FontWeight.w600, spacing: 1.3);
}
