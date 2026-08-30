import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/theme_controller.dart';
import 'core/config.dart';
import 'design/aura.dart';
import 'design/theme.dart';
import 'design/motion_widgets.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'design/wordmark.dart';
import 'features/auth/auth_controller.dart';
import 'features/home/dashboard_screen.dart';
import 'features/onboarding/welcome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /* Supabase is initialised for its auth session handling. Every read of real
     data still goes through the LockInPoint API, because RLS deliberately
     grants no anonymous access to questions, attempts, notes or documents. */
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: const String.fromEnvironment(
      'LIP_SUPABASE_ANON',
      defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNmcXN1Z3Zxbmt1aXV2dG9kdXNoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQzMTc5ODAsImV4cCI6MjA5OTg5Mzk4MH0.UdeUp71M2FGw9_G3EeGyJXrKORZBA2apz8kXNT-DPcY',
    ),
  );

  runApp(const ProviderScope(child: LockInPointApp()));
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
      // The aura sits under every route, so the glass always has the brand's
      // light behind it to refract.
      builder: (context, child) =>
          BrandAura(child: child ?? const SizedBox.shrink()),
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
