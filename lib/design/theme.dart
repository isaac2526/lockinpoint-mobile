import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';
import 'typography.dart';

/// ===========================================================================
/// THE THEME
///
/// Two themes built deliberately, not one inverted. Both are assembled from
/// the same [LipColors] shape, so a widget that reads its colours from the
/// theme cannot be legible in one and unreadable in the other — the failure
/// that makes most "dark mode" feel bolted on.
/// ===========================================================================
abstract final class LipTheme {
  static ThemeData light() => _build(LipColors.light);
  static ThemeData dark() => _build(LipColors.dark);

  static ThemeData _build(LipColors c) {
    final base = c.isDark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);

    final scheme =
        ColorScheme.fromSeed(
          seedColor: c.brand,
          brightness: c.isDark ? Brightness.dark : Brightness.light,
        ).copyWith(
          primary: c.brand,
          secondary: c.gold,
          error: c.danger,
          surface: c.bgBase,
          onSurface: c.text1,
        );

    return base.copyWith(
      colorScheme: scheme,
      extensions: [c],

      // The page is a solid colour and the Scaffold paints it. There is no
      // aura behind it any more: white in light, near-black in dark.
      scaffoldBackgroundColor: c.bgBase,
      canvasColor: c.bgBase,
      splashColor: c.brandSoft,
      highlightColor: c.brandSoft,
      dividerColor: c.glassBorder,

      textTheme: TextTheme(
        displayLarge: LipType.hero,
        titleLarge: LipType.title,
        titleMedium: LipType.heading,
        titleSmall: LipType.subheading,
        bodyLarge: LipType.body,
        bodyMedium: LipType.small,
        bodySmall: LipType.caption,
        labelLarge: LipType.bodyStrong,
        labelSmall: LipType.label,
      ).apply(bodyColor: c.text1, displayColor: c.text1),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: LipType.heading.copyWith(color: c.text1),
        iconTheme: IconThemeData(color: c.text1),
        systemOverlayStyle: c.isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),

      // A tap target below 48dp is a tap target a tired student misses.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.brand,
          foregroundColor: c.isDark ? const Color(0xFF040B22) : Colors.white,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          textStyle: LipType.bodyStrong,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.text1,
          minimumSize: const Size(0, 52),
          side: BorderSide(color: c.glassBorderStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          textStyle: LipType.bodyStrong,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.brand,
          minimumSize: const Size(0, 44),
          textStyle: LipType.smallStrong,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.glassDeep,
        hintStyle: LipType.body.copyWith(color: c.text3),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: c.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: c.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: c.brand, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: c.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: c.danger, width: 1.6),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: false,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.isDark ? c.glassModal : c.brandStrong,
        contentTextStyle: LipType.small.copyWith(
          color: c.isDark ? c.text1 : Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.brand,
        linearTrackColor: c.glassDeep,
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _LipPageTransition(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// A page transition that glides rather than bounces: a short horizontal slide
/// with a fade. Android's default zoom transition is heavier than this app
/// wants, and on a low-end device it is where dropped frames show first.
class _LipPageTransition extends PageTransitionsBuilder {
  const _LipPageTransition();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Motion.glide);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0.045, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

/// Read the palette. Every widget in the app gets its colours through here.
extension LipColorsContext on BuildContext {
  LipColors get lip => Theme.of(this).extension<LipColors>() ?? LipColors.light;
}
