import 'package:flutter/material.dart';

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
///
/// THE FACES ARE BUNDLED, NOT FETCHED.
/// These three families used to arrive through `google_fonts`, which downloads
/// them from Google's servers ON FIRST LAUNCH — three network round trips
/// before a single word could be painted, on the exact connection least able
/// to afford them. They now ship inside the app as assets (see `pubspec.yaml`),
/// so the first frame draws in the real typeface with no network at all, and
/// a student opening the app in a place with no signal still gets the brand
/// rather than a fallback.
///
/// SIZES ARE DELIBERATELY GENEROUS.
/// An earlier scale put 56% of all type at 13px or below. A student reads a
/// question stem slowly, once, often on a moving bus, sometimes on a cracked
/// screen. Every size below is a floor, not a target: readability first, and
/// the polish has to be earned some other way than by shrinking the words.
/// ===========================================================================
abstract final class LipFonts {
  static const display = 'SpaceGrotesk';
  static const body = 'Inter';
  static const mono = 'JetBrainsMono';
}

abstract final class LipType {
  static TextStyle _display(
    double size,
    FontWeight w, {
    double? height,
    double? spacing,
  }) => TextStyle(
    fontFamily: LipFonts.display,
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
  }) => TextStyle(
    fontFamily: LipFonts.body,
    fontSize: size,
    fontWeight: w,
    height: height,
    letterSpacing: spacing,
  );

  static TextStyle _mono(double size, FontWeight w, {double? spacing}) =>
      TextStyle(
        fontFamily: LipFonts.mono,
        fontSize: size,
        fontWeight: w,
        letterSpacing: spacing,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  // ---- display · Space Grotesk -------------------------------------------
  static TextStyle get hero =>
      _display(34, FontWeight.w700, height: 1.14, spacing: -0.7);
  static TextStyle get title =>
      _display(26, FontWeight.w700, height: 1.2, spacing: -0.4);
  static TextStyle get heading =>
      _display(21, FontWeight.w600, height: 1.25, spacing: -0.2);
  static TextStyle get subheading => _display(18, FontWeight.w600, height: 1.3);

  // ---- body · Inter -------------------------------------------------------
  static TextStyle get body => _body(16.5, FontWeight.w400, height: 1.5);
  static TextStyle get bodyStrong => _body(16.5, FontWeight.w600, height: 1.5);
  static TextStyle get small => _body(14.5, FontWeight.w400, height: 1.45);
  static TextStyle get smallStrong =>
      _body(14.5, FontWeight.w600, height: 1.45);
  static TextStyle get caption => _body(13, FontWeight.w400, height: 1.4);

  /// A question stem. The largest reading surface in the whole product, and
  /// the one a student stares at longest — so it is the largest body size we
  /// have, with the loosest leading.
  static TextStyle get question => _body(19.5, FontWeight.w400, height: 1.58);

  /// An answer option. Slightly tighter than the stem so the two are
  /// distinguishable at a glance without a rule between them.
  static TextStyle get option => _body(17.5, FontWeight.w400, height: 1.42);

  // ---- numbers and labels · JetBrains Mono --------------------------------
  static TextStyle get mono => _mono(15, FontWeight.w500);
  static TextStyle get monoBig => _mono(26, FontWeight.w600, spacing: -0.5);

  /// The uppercase micro-label above a group of choices. Letter-spaced,
  /// because uppercase without tracking reads as shouting. The one size in
  /// the scale allowed below 13, because it is never a sentence.
  static TextStyle get label => _mono(11.5, FontWeight.w600, spacing: 1.3);
}
