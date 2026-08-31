import 'package:flutter/material.dart';

/// ===========================================================================
/// THE LOCKINPOINT PALETTE
///
/// LockInPoint is BLUE. It is not blue everywhere.
///
/// A student should be able to glance at the home screen and know, without
/// reading a word, which tile is practice and which is the leaderboard —
/// because each part of the app owns a colour. What keeps a dozen colours
/// from becoming a mess is that every one of them is mixed to the SAME
/// RECIPE: one fixed lightness and saturation band per theme, walked around
/// the colour wheel. Many hues, one product.
///
/// FOUNDATIONS ARE SOLID, NOT GRADIENTS.
/// Light mode stands on white. Dark mode stands on near-black NEUTRAL —
/// #08090B, not a deep navy — with surfaces layered above it in real,
/// opaque steps. Dark is designed here in its own right rather than being
/// the light theme with the lights turned off: the blues brighten, the
/// borders lift, the shadows deepen, and every pairing stays readable.
///
/// Nothing in the app names a colour directly. Widgets read [LipColors] from
/// the theme, so light and dark are two fillings of one shape and a screen
/// cannot accidentally work in one theme and fail in the other.
/// ===========================================================================

/// One feature's colour identity: the surface it sits on, and the ink that
/// sits on that surface. Always used as a pair, so contrast is decided once
/// here rather than guessed at every call site.
@immutable
class LipHue {
  const LipHue(this.tint, this.ink);

  /// The card or tile fill.
  final Color tint;

  /// The icon and title drawn on [tint]. Also legible on the page background.
  final Color ink;
}

/// THE TWELVE. Each one means something; none is decoration.
@immutable
class LipHues {
  const LipHues({
    required this.blue,
    required this.indigo,
    required this.violet,
    required this.purple,
    required this.pink,
    required this.rose,
    required this.orange,
    required this.amber,
    required this.lime,
    required this.green,
    required this.teal,
    required this.slate,
  });

  /// blue — practice, and every primary action
  final LipHue blue;

  /// indigo — analysis and insight
  final LipHue indigo;

  /// violet — the classroom
  final LipHue violet;

  /// purple — games and challenges
  final LipHue purple;

  /// pink — the leaderboard and anything social
  final LipHue pink;

  /// rose — mistakes, danger, a wrong answer
  final LipHue rose;

  /// orange — submitting, and anything that cannot be undone
  final LipHue orange;

  /// amber — time pressure, streaks
  final LipHue amber;

  /// lime — bookmarks and saved things
  final LipHue lime;

  /// green — progress, a right answer, money earned
  final LipHue green;

  /// teal — notes and science
  final LipHue teal;

  /// slate — utilities that should not shout: search, settings
  final LipHue slate;

  /// Every hue in display order, for anything that needs to walk them.
  List<LipHue> get all => [
    blue,
    indigo,
    violet,
    purple,
    pink,
    rose,
    orange,
    amber,
    lime,
    green,
    teal,
    slate,
  ];

  /* THE RECIPE, AND THE ONE PLACE IT BENDS.
     Tints are one fixed lightness/saturation band walked around the wheel —
     that is what makes twelve colours read as one product. The INKS are not
     a fixed band, and could not be: green and yellow carry far more
     luminance than blue at the same lightness, so a single L would leave
     lime unreadable while blue was pitch dark. Each ink is instead solved to
     clear the SAME contrast target (5.5:1) against its own tint. The
     discipline is the ratio, not the number — and the test suite measures
     it rather than trusting the eye. */
  static const lightSet = LipHues(
    blue: LipHue(Color(0xFFDFE9FB), Color(0xFF2759B0)),
    indigo: LipHue(Color(0xFFE2DFFB), Color(0xFF3728B8)),
    violet: LipHue(Color(0xFFECDFFB), Color(0xFF6B28B8)),
    purple: LipHue(Color(0xFFF6DFFB), Color(0xFF9126AB)),
    pink: LipHue(Color(0xFFFBDFED), Color(0xFFA52465)),
    rose: LipHue(Color(0xFFFBE0DF), Color(0xFFA92A25)),
    orange: LipHue(Color(0xFFFBEADF), Color(0xFF904D20)),
    amber: LipHue(Color(0xFFFBF1DF), Color(0xFF7D5A1C)),
    lime: LipHue(Color(0xFFEEFBDF), Color(0xFF466F18)),
    green: LipHue(Color(0xFFDFFBED), Color(0xFF197145)),
    teal: LipHue(Color(0xFFDFFAFB), Color(0xFF186C6F)),
    slate: LipHue(Color(0xFFEEEFF1), Color(0xFF555F75)),
  );

  static const darkSet = LipHues(
    blue: LipHue(Color(0xFF1A2332), Color(0xFF6A99E9)),
    indigo: LipHue(Color(0xFF1C1A32), Color(0xFF9187ED)),
    violet: LipHue(Color(0xFF251A32), Color(0xFFB17EEC)),
    purple: LipHue(Color(0xFF2E1A32), Color(0xFFD271EA)),
    pink: LipHue(Color(0xFF321A26), Color(0xFFE96FAC)),
    rose: LipHue(Color(0xFF321B1A), Color(0xFFEA7571)),
    orange: LipHue(Color(0xFF32241A), Color(0xFFE38647)),
    amber: LipHue(Color(0xFF322A1A), Color(0xFFE1A337)),
    lime: LipHue(Color(0xFF27321A), Color(0xFF92E137)),
    green: LipHue(Color(0xFF1A3226), Color(0xFF37E18C)),
    teal: LipHue(Color(0xFF1A3232), Color(0xFF37DCE1)),
    slate: LipHue(Color(0xFF25272D), Color(0xFF979EAD)),
  );
}

@immutable
class LipColors extends ThemeExtension<LipColors> {
  const LipColors({
    required this.bgBase,
    required this.bgGradient,
    required this.glowA,
    required this.glowB,
    required this.glowC,
    required this.glassUltra,
    required this.glassCard,
    required this.glassRaised,
    required this.glassDeep,
    required this.glassModal,
    required this.glassBorder,
    required this.glassBorderStrong,
    required this.glassEdge,
    required this.glassHighlight,
    required this.text1,
    required this.text2,
    required this.text3,
    required this.brand,
    required this.brandStrong,
    required this.brandSoft,
    required this.gold,
    required this.accent,
    required this.accentSoft,
    required this.success,
    required this.successSoft,
    required this.danger,
    required this.dangerSoft,
    required this.warning,
    required this.warningSoft,
    required this.ring,
    required this.shadow,
    required this.shadowRaised,
    required this.hues,
    required this.isDark,
  });

  /// The page. A solid colour, deliberately: white in light, near-black
  /// neutral in dark. Nothing bleeds through it.
  final Color bgBase;

  /// Kept so the four-stop background of older screens still compiles. Every
  /// stop is now the SAME colour — the gradient era is over.
  final List<Color> bgGradient;

  /// Formerly the three aura orbs. Fully transparent now; a solid foundation
  /// has nothing to refract.
  final Color glowA, glowB, glowC;

  /// THE SURFACE LADDER · ultra < card < raised < deep < modal.
  /// These are real opaque steps away from [bgBase], not translucency. The
  /// names are inherited so no call site had to change; the values are not.
  final Color glassUltra, glassCard, glassRaised, glassDeep, glassModal;
  final Color glassBorder, glassBorderStrong, glassEdge;

  /// Retained at zero alpha: surfaces no longer carry a highlight sheen.
  final Color glassHighlight;

  /// Text tiers. text1 is nearly black in light and nearly white in dark.
  final Color text1, text2, text3;

  final Color brand, brandStrong, brandSoft;
  final Color gold, accent, accentSoft;
  final Color success, successSoft;
  final Color danger, dangerSoft;
  final Color warning, warningSoft;
  final Color ring;
  final Color shadow, shadowRaised;

  /// The twelve feature colours for this theme.
  final LipHues hues;

  final bool isDark;

  // -------------------------------------------------------------- light ----
  /// Foundation: white. Cards sit a step ABOVE the page rather than being cut
  /// out of it, which is why the page is a hair off-white and the cards are
  /// pure white.
  static const light = LipColors(
    bgBase: Color(0xFFF6F7FB),
    bgGradient: [
      Color(0xFFF6F7FB),
      Color(0xFFF6F7FB),
      Color(0xFFF6F7FB),
      Color(0xFFF6F7FB),
    ],
    glowA: Color(0x00000000),
    glowB: Color(0x00000000),
    glowC: Color(0x00000000),
    glassUltra: Color(0xFFFFFFFF),
    glassCard: Color(0xFFFFFFFF),
    glassRaised: Color(0xFFFFFFFF),
    glassDeep: Color(0xFFEFF2F8),
    glassModal: Color(0xFFFFFFFF),
    glassBorder: Color(0xFFE4E8F1),
    glassBorderStrong: Color(0xFFCFD7E5),
    glassEdge: Color(0x14101828),
    glassHighlight: Color(0x00000000),
    text1: Color(0xFF0B1020),
    text2: Color(0xFF414B63),
    text3: Color(0xFF6C7690),
    brand: Color(0xFF1D4ED8),
    brandStrong: Color(0xFF12296B),
    brandSoft: Color(0x141D4ED8),
    gold: Color(0xFFD9A213),
    accent: Color(0xFF8A6100),
    accentSoft: Color(0x1FD9A213),
    success: Color(0xFF107A46),
    successSoft: Color(0x1A107A46),
    danger: Color(0xFFB42318),
    dangerSoft: Color(0x1AB42318),
    warning: Color(0xFFB25A09),
    warningSoft: Color(0x1FB25A09),
    ring: Color(0x5C1D4ED8),
    shadow: Color(0x0F101828),
    shadowRaised: Color(0x1A101828),
    hues: LipHues.lightSet,
    isDark: false,
  );

  // --------------------------------------------------------------- dark ----
  /// Foundation: NEUTRAL near-black. Not navy, not "dark blue" — #08090B, so
  /// the blues and the twelve hues above it actually read as colours rather
  /// than as shades of the background.
  static const dark = LipColors(
    bgBase: Color(0xFF08090B),
    bgGradient: [
      Color(0xFF08090B),
      Color(0xFF08090B),
      Color(0xFF08090B),
      Color(0xFF08090B),
    ],
    glowA: Color(0x00000000),
    glowB: Color(0x00000000),
    glowC: Color(0x00000000),
    glassUltra: Color(0xFF121316),
    glassCard: Color(0xFF141519),
    glassRaised: Color(0xFF1B1D22),
    glassDeep: Color(0xFF0F1013),
    glassModal: Color(0xFF1B1D22),
    glassBorder: Color(0xFF272A31),
    glassBorderStrong: Color(0xFF3A3E48),
    glassEdge: Color(0x14FFFFFF),
    glassHighlight: Color(0x00000000),
    text1: Color(0xFFF4F6F9),
    text2: Color(0xFFB9C0CC),
    text3: Color(0xFF8A92A1),
    brand: Color(0xFF7BA0FF),
    brandStrong: Color(0xFFA9C1FF),
    brandSoft: Color(0x2E7BA0FF),
    gold: Color(0xFFE9B83C),
    accent: Color(0xFFFFCF57),
    accentSoft: Color(0x2EE9B83C),
    success: Color(0xFF4ED18B),
    successSoft: Color(0x2E4ED18B),
    danger: Color(0xFFFF8A93),
    dangerSoft: Color(0x2EFF8A93),
    warning: Color(0xFFF0B44E),
    warningSoft: Color(0x2EF0B44E),
    ring: Color(0x807BA0FF),
    shadow: Color(0x66000000),
    shadowRaised: Color(0x80000000),
    hues: LipHues.darkSet,
    isDark: true,
  );

  @override
  LipColors copyWith() => this;

  /// Themes are switched, never blended — a half-interpolated surface reads
  /// as a rendering bug rather than a transition.
  @override
  LipColors lerp(ThemeExtension<LipColors>? other, double t) =>
      t < 0.5 ? this : (other as LipColors? ?? this);
}

/// ===========================================================================
/// SPACING · one 4pt ladder, used everywhere.
/// Numbers chosen by hand look chosen by hand. These do not.
/// ===========================================================================
abstract final class Gap {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double huge = 48;
}

/// Corner radii. The website's glass is generously rounded; a phone wants a
/// little more, because a small surface with a small radius reads as sharp.
abstract final class Radii {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double pill = 999;
}

/// ===========================================================================
/// MOTION · the website's two curves, named.
///
///   spring  cubic-bezier(.2,.9,.25,1.1) — overshoots slightly, for anything
///           that ARRIVES: a sheet, a toggle knob, a selected state
///   glide   cubic-bezier(.16,.84,.3,1)  — never overshoots, for anything that
///           MOVES: a page transition, a progress bar
///
/// Durations are short on purpose. On a mid-range Android phone a 300ms
/// transition feels like waiting; 180ms feels like the app is keeping up.
/// ===========================================================================
abstract final class Motion {
  static const spring = Cubic(0.2, 0.9, 0.25, 1.1);
  static const glide = Cubic(0.16, 0.84, 0.3, 1);

  static const fast = Duration(milliseconds: 140);
  static const base = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 320);
}

/// ===========================================================================
/// BLUR · the website's three strengths.
///
/// Every one of these forces the layer beneath into an offscreen buffer, which
/// is the single most expensive thing this app can ask a cheap Android phone to
/// do. THE RULE: glass on chrome — the bottom bar, sheets, dialogs, the aura —
/// never on the cards inside a scrolling list. A list card gets a translucent
/// fill and a hairline border instead: the same family to the eye, a fraction
/// of the cost. See GlassSurface, which enforces this.
/// ===========================================================================
abstract final class Blurs {
  static const double one = 14;
  static const double two = 22;
  static const double three = 34;
}
