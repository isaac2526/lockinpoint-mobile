import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/theme_controller.dart';
import 'core/json.dart';
import 'core/presence.dart';
import 'design/broke.dart';
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

  /* ===================================================================
     THE LAST LINE OF DEFENCE.

     Seventeen screens used to render `'$e'` — the raw Dart exception —
     straight into their error card, which is how the owner came to be
     reading "Type int is not a subtype of type string in type cast" on
     his own activities page. Those are all gone.

     But a widget can still throw during BUILD, and Flutter's default
     answer to that is the grey-on-red error box with the exception text
     in it. In a release build it is a bare grey rectangle — which is
     arguably worse, because it says nothing at all.

     So: a calm card that names what happened in one sentence, and the
     real error to the console for whoever is debugging. Nothing here
     recovers the screen — it cannot — but a student meets a sentence
     rather than a stack.
     =================================================================== */
  ErrorWidget.builder = (details) {
    debugPrint(
      '[lockinpoint] widget build failed: '
      '${describeFailure(details.exception, details.stack)}',
    );
    return const SomethingBroke();
  };

  /* Anything the framework catches outside a build — a gesture callback, a
     ticker, a future with no handler. Logged, never shown: the screen is
     still usable and interrupting it would be worse than the fault. */
  FlutterError.onError = (details) {
    debugPrint(
      '[lockinpoint] ${describeFailure(details.exception, details.stack)}',
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[lockinpoint] uncaught: ${describeFailure(error, stack)}');
    return true;
  };

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
