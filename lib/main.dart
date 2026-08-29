import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/gallery_screen.dart';
import 'app/theme_controller.dart';
import 'design/aura.dart';
import 'design/theme.dart';

void main() {
  runApp(const ProviderScope(child: LockInPointApp()));
}

/// The application shell.
///
/// The aura sits ABOVE MaterialApp's builder and below every route, so the
/// glass on any screen always has the brand's light behind it to refract —
/// which is the whole reason the website's panes read as glass rather than as
/// grey boxes. Scaffolds are transparent by theme so nothing paints over it.
class LockInPointApp extends ConsumerWidget {
  const LockInPointApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Until the stored preference has loaded, follow the phone. This resolves
    // in a frame or two and never flashes the wrong theme.
    final mode = ref.watch(themeControllerProvider).value ?? ThemeMode.system;

    return MaterialApp(
      title: 'LockInPoint',
      debugShowCheckedModeBanner: false,
      theme: LipTheme.light(),
      darkTheme: LipTheme.dark(),
      themeMode: mode,
      builder: (context, child) =>
          BrandAura(child: child ?? const SizedBox.shrink()),
      home: const GalleryScreen(),
    );
  }
}
