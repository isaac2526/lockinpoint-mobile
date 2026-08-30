import 'package:flutter/material.dart';

import '../../design/components.dart';
import '../../design/glass.dart';
import '../../design/motion_widgets.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../design/wordmark.dart';
import '../auth/ui/login_screen.dart';
import '../auth/ui/signup_screen.dart';

/// ===========================================================================
/// THE FIRST SCREEN
///
/// Written for a student who has never heard of LockInPoint. Each panel makes
/// one concrete promise in plain words: what you get, how you train, who helps
/// you. No insider phrases, no punctuation tricks, and the numbers shown are
/// real ones from the platform.
/// ===========================================================================
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, this.notice});

  /// Why the student is back here, such as an expired session.
  final String? notice;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _pages = PageController();
  int _page = 0;

  static const _panels = <_Panel>[
    _Panel(
      icon: Icons.workspace_premium_rounded,
      eyebrow: 'Built for your exams',
      title: 'Pass JAMB, WAEC, NECO and more',
      body:
          'LockInPoint prepares you for JAMB, WAEC, NECO, NABTEB, GCE and '
          'Post UTME with a huge bank of genuine past questions. Every '
          'question was asked in a real examination, and every answer comes '
          'with a clear explanation of why it is correct.',
      stats: [
        ('6', 'examinations'),
        ('1978', 'earliest paper'),
        ('5', 'countries'),
      ],
    ),
    _Panel(
      icon: Icons.timer_rounded,
      eyebrow: 'Practice and CBT',
      title: 'Train the way you will be tested',
      body:
          'Learn at your own pace in practice mode, where every answer is '
          'marked instantly with its full explanation. When you are ready, '
          'sit a timed CBT that behaves like the real exam hall, including a '
          'complete JAMB mock of 180 questions scored over 400.',
      stats: [
        ('180', 'question mock'),
        ('400', 'max score'),
        ('2hrs', 'on the clock'),
      ],
    ),
    _Panel(
      icon: Icons.auto_awesome_rounded,
      eyebrow: 'Never study alone',
      title: 'Lumi explains until you understand',
      body:
          'Meet Lumi, your personal AI tutor. Ask about any question and get '
          'a simple answer in plain English. Download question packs to keep '
          'studying when there is no internet, and sharpen your speed in '
          'five exam games with a national leaderboard.',
      stats: [
        ('24/7', 'Lumi AI tutor'),
        ('5', 'exam games'),
        ('Offline', 'study packs'),
      ],
    ),
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lip;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ---- the brand, always in view ------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xl, Gap.xl, 0),
              child: Entrance(
                child: Row(
                  children: [
                    const LipWordmark(size: 30),
                    const Spacer(),
                    Text(
                      'by Noesis Innovations',
                      style: LipType.caption.copyWith(color: c.text3),
                    ),
                  ],
                ),
              ),
            ),

            if (widget.notice != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.lg, Gap.xl, 0),
                child: GlassSurface(
                  tier: GlassTier.deep,
                  radius: Radii.md,
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.md,
                    vertical: Gap.sm,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 15,
                        color: c.warning,
                      ),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: Text(
                          widget.notice!,
                          style: LipType.caption.copyWith(color: c.text2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ---- the three panels ---------------------------------------
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _panels.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _PanelView(panel: _panels[i]),
              ),
            ),

            // ---- where you are ------------------------------------------
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_panels.length, (i) {
                final on = i == _page;
                return AnimatedContainer(
                  duration: Motion.base,
                  curve: Motion.spring,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 6,
                  width: on ? 26 : 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Radii.pill),
                    gradient: on
                        ? LinearGradient(colors: [c.brand, c.gold])
                        : null,
                    color: on ? null : c.glassBorderStrong,
                  ),
                );
              }),
            ),

            // ---- the two doors ------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.xl,
                Gap.xl,
                Gap.xl,
                Gap.xl,
              ),
              child: Entrance(
                index: 2,
                child: Column(
                  children: [
                    LipButton(
                      label: 'Create account',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: () => _open(const SignupScreen()),
                    ),
                    const SizedBox(height: Gap.md),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _open(const LoginScreen()),
                        child: const Text('Log in'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel {
  const _Panel({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.stats,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;
  final List<(String, String)> stats;
}

class _PanelView extends StatelessWidget {
  const _PanelView({required this.panel});
  final _Panel panel;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    /* Scrollable, and centred only when there is room to centre in. A short
       phone or a large accessibility font must never overflow the panel. */
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: Gap.xl, vertical: Gap.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Entrance(
            child: Container(
              height: 58,
              width: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.lg),
                gradient: LinearGradient(
                  colors: [c.brandSoft, c.accentSoft],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: c.glassBorder),
              ),
              child: Icon(panel.icon, size: 27, color: c.brand),
            ),
          ),
          const SizedBox(height: Gap.xl),
          Entrance(
            index: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  panel.eyebrow.toUpperCase(),
                  style: LipType.label.copyWith(color: c.accent),
                ),
                const SizedBox(height: Gap.sm),
                Text(panel.title, style: LipType.hero.copyWith(color: c.text1)),
                const SizedBox(height: Gap.md),
                Text(panel.body, style: LipType.body.copyWith(color: c.text2)),
              ],
            ),
          ),
          const SizedBox(height: Gap.xl),
          Entrance(
            index: 3,
            child: Row(
              children: [
                for (final (n, label) in panel.stats) ...[
                  Expanded(
                    child: GlassSurface(
                      tier: GlassTier.ultra,
                      radius: Radii.md,
                      padding: const EdgeInsets.symmetric(
                        vertical: Gap.md,
                        horizontal: Gap.sm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n,
                            style: LipType.monoBig.copyWith(color: c.brand),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            label,
                            style: LipType.caption.copyWith(color: c.text3),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (label != panel.stats.last.$2)
                    const SizedBox(width: Gap.sm),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
