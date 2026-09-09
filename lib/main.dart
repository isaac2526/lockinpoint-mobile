import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/theme_controller.dart';
import 'core/presence.dart';
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
      /* COMING BACK TO WHERE YOU WERE.
      
         Android kills a backgrounded app to reclaim RAM — routinely, on the
         cheap phones most of these students carry — and this app had no state
         restoration at all. Not "some": none. So a student reading a note,
         who took a call, came back to the Home tab with an empty back stack
         and had to find their place again from the beginning.
      
         Naming a restoration scope is what turns the framework on. Without
         this one line every RestorableProperty in the app is inert, which is
         why adding them alone would have changed nothing. */
      restorationScopeId: 'lockinpoint',
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
        AsyncData(value: SignedIn()) => const _Present(
          child: AppShell(key: ValueKey('home')),
        ),
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

/// Starts the presence heartbeat for as long as a student is signed in, and
/// stops it the moment they are not. Wrapping the shell rather than living in
/// main() is deliberate: a signed-out app has nothing to say to /api/session,
/// and starting the observer anyway would ping on every resume of the welcome
/// screen for ever.
class _Present extends ConsumerStatefulWidget {
  const _Present({required this.child});
  final Widget child;

  @override
  ConsumerState<_Present> createState() => _PresentState();
}

class _PresentState extends ConsumerState<_Present> {
  Presence? _presence;

  @override
  void initState() {
    super.initState();
    final p = ref.read(presenceProvider);
    _presence = p;
    p.start();
  }

  @override
  void dispose() {
    _presence?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
