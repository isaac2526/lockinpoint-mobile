import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which theme the student has chosen, remembered across launches.
///
/// Three states, not two. A student can pin Light, pin Dark, or say "follow my
/// phone" — and until they choose, the app opens LIGHT, because the white face
/// with the blue and gold is the brand's first impression and a first launch
/// should not depend on how the student happens to have their phone set.
///
/// The website stores the same choice under `bmxd-theme`; the key here is
/// deliberately different because the two do not share storage and pretending
/// otherwise would be a lie waiting to confuse someone.
class ThemeController extends AsyncNotifier<ThemeMode> {
  static const _key = 'lip.theme-mode';

  @override
  Future<ThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    return switch (prefs.getString(_key)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      /* First launch opens in LIGHT, deliberately: the clean white face with
         the blue and gold is the brand's first impression. The student can
         switch after signing in and the choice is remembered. */
      _ => ThemeMode.light,
    };
  }

  Future<void> set(ThemeMode mode) async {
    state = AsyncData(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  /// The toggle: whatever we are showing now, show the other one. From
  /// `system` it commits to the opposite of what the phone is currently doing,
  /// so one tap always visibly changes something.
  Future<void> toggle(Brightness current) async {
    final next = switch (state.value ?? ThemeMode.light) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.light,
      ThemeMode.system =>
        current == Brightness.dark ? ThemeMode.light : ThemeMode.dark,
    };
    await set(next);
  }
}

final themeControllerProvider =
    AsyncNotifierProvider<ThemeController, ThemeMode>(ThemeController.new);
