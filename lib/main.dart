import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/theme_controller.dart';
import 'design/theme.dart';
import 'design/tokens.dart';
import 'features/auth/auth_controller.dart';
import 'app/shell.dart';
import 'features/onboarding/welcome_screen.dart';
import 'features/splash/splash_screen.dart';

void main() {
  /* There is deliberately nothing to initialise before the first frame: the
     app carries no auth SDK and no compiled-in project address. Identity is
     three routes on the one backend — login, refresh, logout — and the only
     startup work is reading the keystore, which the splash already covers. */
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ProviderScope(
      /* Riverpod 3 silently retries a failed provider with backoff. On a
         phone that means a failing request is refetched again and again:
         the screen sits on its skeleton while the student's data plan burns.
         Exactly that was seen in testing. Retries here are always explicit:
         a pull to refresh, or a Try again button. */
      retry: (retryCount, error) => null,
      child: const LockInPointApp(),
    ),
  );
}

class LockInPointApp extends ConsumerWidget {
  const LockInPointApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeControllerProvider).value ?? ThemeMode.system;

    return MaterialApp(
      title: 'LockInPoint',
      debugShowCheckedModeBanner: false,
      theme: LipTheme.light(),
      darkTheme: LipTheme.dark(),
      themeMode: mode,
      home: const _Gate(),
    );
  }
}

/// Decides what a student sees the moment the app opens: the splash while the
/// keystore is read, then either the welcome or their dashboard. Nothing
/// flashes, because the unknown state is a real state rather than a guess.
class _Gate extends ConsumerWidget {
  const _Gate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    return AnimatedSwitcher(
      duration: Motion.slow,
      switchInCurve: Motion.glide,
      child: switch (auth) {
        AsyncData(value: SignedIn()) => const AppShell(key: ValueKey('home')),
        AsyncData(value: SignedOut(:final message)) => WelcomeScreen(
          key: const ValueKey('welcome'),
          notice: message,
        ),
        AsyncError() => const WelcomeScreen(key: ValueKey('welcome')),
        _ => const LipSplash(key: ValueKey('splash')),
      },
    );
  }
}
