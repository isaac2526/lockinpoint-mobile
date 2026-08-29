import 'package:flutter/material.dart';

import '../../design/components.dart';
import '../../design/glass.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../design/wordmark.dart';
import '../auth/ui/login_screen.dart';
import '../auth/ui/signup_screen.dart';

/// ===========================================================================
/// THE FIRST SCREEN
///
/// What the website's landing page says, said in the space a phone has. Every
/// line here is LockInPoint's own copy — the gold pill about the exam hall,
/// the three numbers, the six things the platform does — because the app
/// should introduce the product a student may already know, not a new one.
///
/// Three panels, then the two doors. No paragraphs.
/// ===========================================================================
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, this.notice});

  /// Why the student is back here — an expired session, a device takeover.
  final String? notice;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _pages = PageController();
  int _page = 0;

  static const _panels = <_Panel>[
    _Panel(
      icon: Icons.verified_rounded,
      eyebrow: 'Since 1978',
      title: 'Every question here sat in a real exam hall first',
      body:
          'JAMB, WAEC, NECO, NABTEB, GCE and Post UTME. Past questions from each '
          'exam’s true first year — and an empty year says so, rather than '
          'inventing something.',
      stats: [
        ('1978', 'earliest paper'),
        ('5', 'nations'),
        ('6', 'examinations'),
      ],
    ),
    _Panel(
      icon: Icons.timer_outlined,
      eyebrow: 'Practice and CBT',
      title: 'The hall, before the hall',
      body:
          'Practise untimed with the answer and the full working after every '
          'question — or sit the strict clock, question map and all. The full '
          'JAMB mock runs 180 questions over 400, exactly like the day itself.',
      stats: [
        ('180', 'question mock'),
        ('400', 'scored over'),
        ('2hr', 'one clock'),
      ],
    ),
    _Panel(
      icon: Icons.auto_awesome_rounded,
      eyebrow: 'Lumi AI · offline · games',
      title: 'A tutor who never gets tired of you',
      body:
          'Ask Lumi anything mid-question and get plain English back. Download '
          'what you need for the days the data finishes. Then go and win '
          'something in the games arena.',
      stats: [('24/7', 'Lumi'), ('Offline', 'your packs'), ('5', 'games')],
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
            // ---- the mark, always in view -------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xl, Gap.xl, 0),
              child: Row(
                children: [
                  const LipWordmark(size: 30),
                  const Spacer(),
                  Text(
                    'a Noesis product',
                    style: LipType.caption.copyWith(color: c.text3),
                  ),
                ],
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
                Gap.lg,
              ),
              child: Column(
                children: [
                  LipButton(
                    label: 'Create a free account',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () => _open(const SignupScreen()),
                  ),
                  const SizedBox(height: Gap.md),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _open(const LoginScreen()),
                      child: const Text('I already have an account'),
                    ),
                  ),
                  const SizedBox(height: Gap.md),
                  Text(
                    'See everything free. One activation opens it all.',
                    style: LipType.caption.copyWith(color: c.text3),
                    textAlign: TextAlign.center,
                  ),
                ],
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
       phone — or a large accessibility font — otherwise overflows the panel,
       which is exactly the device this app is for. */
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: Gap.xl, vertical: Gap.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
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
          const SizedBox(height: Gap.xl),
          Text(
            panel.eyebrow.toUpperCase(),
            style: LipType.label.copyWith(color: c.accent),
          ),
          const SizedBox(height: Gap.sm),
          Text(panel.title, style: LipType.hero.copyWith(color: c.text1)),
          const SizedBox(height: Gap.md),
          Text(panel.body, style: LipType.body.copyWith(color: c.text2)),
          const SizedBox(height: Gap.xl),
          Row(
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
                if (label != panel.stats.last.$2) const SizedBox(width: Gap.sm),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
