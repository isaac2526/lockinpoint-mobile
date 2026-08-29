import 'package:flutter/material.dart';

/// ===========================================================================
/// THE LOCKINPOINT PALETTE
///
/// Every value here is lifted from the website's own `globals.css`, not
/// invented. A student moving between the browser and the app should meet the
/// same blue, the same gold, the same depth of black — that recognition is
/// most of what makes two products feel like one product.
///
/// Nothing in the app names a colour directly. Widgets read [LipColors] from
/// the theme, so light and dark are two fillings of one shape and a screen
/// cannot accidentally work in one theme and fail in the other.
/// ===========================================================================
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
    required this.isDark,
  });

  /// The canvas the glass bleeds.
  final Color bgBase;
  final List<Color> bgGradient;

  /// The three aura orbs. On the website these are blurred CSS circles behind
  /// every page; without something behind it, frosted glass has nothing to
  /// prove it is frosted.
  final Color glowA, glowB, glowC;

  /// THE SIX TIERS OF GLASS · ultra < card < raised < deep < modal.
  /// The same ladder the website uses, so a component ported from one to the
  /// other keeps its depth rather than being re-guessed.
  final Color glassUltra, glassCard, glassRaised, glassDeep, glassModal;
  final Color glassBorder, glassBorderStrong, glassEdge;
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

  final bool isDark;

  // -------------------------------------------------------------- light ----
  static const light = LipColors(
    bgBase: Color(0xFFE9EEFB),
    bgGradient: [
      Color(0xFFF3F7FF),
      Color(0xFFE7EEFC),
      Color(0xFFDDE7FA),
      Color(0xFFE6ECFB),
    ],
    glowA: Color(0x4D2450C7),
    glowB: Color(0x4DE9B83C),
    glowC: Color(0x384E84F5),
    glassUltra: Color(0x4DFFFFFF),
    glassCard: Color(0x85FFFFFF),
    glassRaised: Color(0xA8FFFFFF),
    glassDeep: Color(0x8CE1E9FA),
    glassModal: Color(0xC7FFFFFF),
    glassBorder: Color(0xB8FFFFFF),
    glassBorderStrong: Color(0xF2FFFFFF),
    glassEdge: Color(0x291436A6),
    glassHighlight: Color(0xBFFFFFFF),
    text1: Color(0xFF050A18),
    text2: Color(0xFF2A3655),
    text3: Color(0xFF43506F),
    brand: Color(0xFF12296B),
    brandStrong: Color(0xFF0C1D4D),
    brandSoft: Color(0x1A2450C7),
    gold: Color(0xFFE9B83C),
    accent: Color(0xFF8F6400),
    accentSoft: Color(0x24D4A017),
    success: Color(0xFF157347),
    successSoft: Color(0x1F157347),
    danger: Color(0xFFB42318),
    dangerSoft: Color(0x1AB42318),
    warning: Color(0xFFB54708),
    warningSoft: Color(0x1FB54708),
    ring: Color(0x732450C7),
    shadow: Color(0x1F183278),
    shadowRaised: Color(0x2E183278),
    isDark: false,
  );

  // --------------------------------------------------------------- dark ----
  static const dark = LipColors(
    bgBase: Color(0xFF040B22),
    bgGradient: [
      Color(0xFF071233),
      Color(0xFF050D26),
      Color(0xFF0A1030),
      Color(0xFF060F2C),
    ],
    glowA: Color(0x573E6BE8),
    glowB: Color(0x38E9B83C),
    glowC: Color(0x3D7C4DE9),
    glassUltra: Color(0x0F7898FF),
    glassCard: Color(0x6B18285C),
    glassRaised: Color(0x8C1E3068),
    glassDeep: Color(0x9E09112C),
    glassModal: Color(0xC7162556),
    glassBorder: Color(0x4294B0FF),
    glassBorderStrong: Color(0x70BED0FF),
    glassEdge: Color(0x3894B0FF),
    glassHighlight: Color(0x38A6BDF8),
    text1: Color(0xFFF2F6FF),
    text2: Color(0xFFC6D0E8),
    text3: Color(0xFF9CAACC),
    // In dark the deep navy becomes the ground, so the brand must lift OFF it
    // rather than sink into it. This is the one place the app does not copy the
    // website literally: #12296b on #040b22 is unreadable.
    brand: Color(0xFF7FA0F5),
    brandStrong: Color(0xFFA8BEFA),
    brandSoft: Color(0x333E6BE8),
    gold: Color(0xFFE9B83C),
    accent: Color(0xFFFFCF57),
    accentSoft: Color(0x2EE9B83C),
    success: Color(0xFF52D18B),
    successSoft: Color(0x2E52D18B),
    danger: Color(0xFFFF8595),
    dangerSoft: Color(0x2EFF8595),
    warning: Color(0xFFF0B44E),
    warningSoft: Color(0x2EF0B44E),
    ring: Color(0x7F7FA0F5),
    shadow: Color(0x80010514),
    shadowRaised: Color(0x8C00020C),
    isDark: true,
  );

  @override
  LipColors copyWith() => this;

  /// Themes are switched, never blended — a half-interpolated glass tier reads
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
