import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/theme_controller.dart';
import 'design/theme.dart';
import 'design/motion_widgets.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'design/wordmark.dart';
import 'features/auth/auth_controller.dart';
import 'features/home/dashboard_screen.dart';
import 'features/onboarding/welcome_screen.dart';

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
        AsyncData(value: SignedIn()) => const DashboardScreen(
          key: ValueKey('home'),
        ),
        AsyncData(value: SignedOut(:final message)) => WelcomeScreen(
          key: const ValueKey('welcome'),
          notice: message,
        ),
        AsyncError() => const WelcomeScreen(key: ValueKey('welcome')),
        _ => const _Splash(key: ValueKey('splash')),
      },
    );
  }
}

/// The first thing anyone sees: the crowned mark arriving with a spring, the
/// name fading in beneath it, three dots breathing while the keystore is read.
/// It usually lives for well under a second, and it should feel alive for all
/// of it.
class _Splash extends StatefulWidget {
  const _Splash({super.key});

  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lip = context.lip;
    final pop = CurvedAnimation(parent: _c, curve: Motion.spring);
    final fade = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.35, 1, curve: Curves.easeOut),
    );
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: Tween(begin: 0.72, end: 1.0).animate(pop),
              child: FadeTransition(
                opacity: pop,
                child: const LipLogoMark(size: 84),
              ),
            ),
            const SizedBox(height: Gap.lg),
            FadeTransition(
              opacity: fade,
              child: Text(
                'LockInPoint',
                style: LipType.title.copyWith(color: lip.text1),
              ),
            ),
            const SizedBox(height: Gap.xl),
            FadeTransition(
              opacity: fade,
              child: PulseDots(color: lip.brand),
            ),
          ],
        ),
      ),
    );
  }
}
