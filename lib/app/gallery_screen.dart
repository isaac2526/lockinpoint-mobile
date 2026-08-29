import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/components.dart';
import '../design/glass.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'theme_controller.dart';

/// ===========================================================================
/// THE COMPONENT GALLERY · Phase 0's deliverable.
///
/// Not a demo screen and not a placeholder. This is every primitive the app
/// will be built from, on one page, in both themes, so the foundation can be
/// judged BEFORE forty screens are stacked on top of it. If a colour is wrong
/// or a radius is off, this is where it costs an hour to fix rather than a day.
///
/// It is deleted when the real screens land in Phase 1.
/// ===========================================================================
class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  String _mode = 'practice';
  String? _source;
  int? _year;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.huge),
          children: [
            // ---- masthead ----------------------------------------------
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LockInPoint',
                        style: LipType.hero.copyWith(color: c.text1),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Design system · Phase 0',
                        style: LipType.small.copyWith(color: c.text3),
                      ),
                    ],
                  ),
                ),
                _ThemeToggle(
                  onTap: () => ref
                      .read(themeControllerProvider.notifier)
                      .toggle(brightness),
                  isDark: c.isDark,
                ),
              ],
            ),
            const SizedBox(height: Gap.xl),

            // ---- glass tiers -------------------------------------------
            const LipLabel('The six tiers of glass'),
            const SizedBox(height: Gap.md),
            for (final (tier, name) in const [
              (GlassTier.ultra, 'ultra'),
              (GlassTier.card, 'card'),
              (GlassTier.raised, 'raised'),
              (GlassTier.deep, 'deep'),
              (GlassTier.modal, 'modal · blurred'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: GlassSurface(
                  tier: tier,
                  blurred: tier == GlassTier.modal,
                  seam: tier == GlassTier.raised,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: LipType.bodyStrong.copyWith(color: c.text1),
                        ),
                      ),
                      Text(
                        tier == GlassTier.modal ? 'real blur' : 'translucent',
                        style: LipType.label.copyWith(color: c.text3),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: Gap.md),
            Text(
              'Only the modal tier blurs. Everything in a scrolling list is a '
              'translucent fill — same family to the eye, a fraction of the cost '
              'on a cheap phone.',
              style: LipType.caption.copyWith(color: c.text3),
            ),
            const SizedBox(height: Gap.xl),

            // ---- type scale --------------------------------------------
            const LipLabel('Typography'),
            const SizedBox(height: Gap.md),
            GlassSurface(
              tier: GlassTier.raised,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Space Grotesk',
                    style: LipType.title.copyWith(color: c.text1),
                  ),
                  Text(
                    'Heading · 19',
                    style: LipType.heading.copyWith(color: c.text1),
                  ),
                  const SizedBox(height: Gap.sm),
                  Text(
                    'Inter carries the body. A question stem is set larger and looser '
                    'than ordinary text, because a student reads it slowly, once, and '
                    'often on a moving bus.',
                    style: LipType.body.copyWith(color: c.text2),
                  ),
                  const SizedBox(height: Gap.md),
                  Row(
                    children: [
                      Text(
                        '2 4 8 · 0 6 9',
                        style: LipType.monoBig.copyWith(color: c.brand),
                      ),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Text(
                          'JetBrains Mono, tabular — a clock that never jitters',
                          style: LipType.caption.copyWith(color: c.text3),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: Gap.xl),

            // ---- the real practice chooser, in miniature ---------------
            const LipLabel('Choose your mode'),
            const SizedBox(height: Gap.md),
            Row(
              children: [
                Expanded(
                  child: LipChoiceCard(
                    icon: Icons.menu_book_rounded,
                    title: 'Practice',
                    subtitle: 'No clock. Marked as you go.',
                    selected: _mode == 'practice',
                    onTap: () => setState(() => _mode = 'practice'),
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: LipChoiceCard(
                    icon: Icons.schedule_rounded,
                    title: 'Timed CBT',
                    subtitle: 'A strict clock, like the hall.',
                    selected: _mode == 'cbt',
                    onTap: () => setState(() => _mode = 'cbt'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.lg),

            const LipLabel('Where should the questions come from?'),
            const SizedBox(height: Gap.md),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: [
                for (final (key, name) in const [
                  ('year', 'By year'),
                  ('topic', 'By topic'),
                  ('random', 'Random'),
                  ('tutorial', 'Tutorial'),
                ])
                  LipChip(
                    name,
                    selected: _source == key,
                    onTap: () => setState(() => _source = key),
                  ),
              ],
            ),

            if (_source == 'year') ...[
              const SizedBox(height: Gap.lg),
              const LipLabel('Choose a year'),
              const SizedBox(height: Gap.md),
              Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                children: [
                  for (final y in const [2024, 2023, 2022, 2021])
                    LipChip(
                      '$y',
                      count: 40 + y % 17,
                      selected: _year == y,
                      onTap: () => setState(() => _year = y),
                    ),
                ],
              ),
            ],
            const SizedBox(height: Gap.xl),

            // ---- stats --------------------------------------------------
            const LipLabel('Numbers'),
            const SizedBox(height: Gap.md),
            Row(
              children: const [
                Expanded(
                  child: LipStat(value: '284', label: 'Answered'),
                ),
                SizedBox(width: Gap.sm),
                Expanded(
                  child: LipStat(
                    value: '71%',
                    label: 'Correct',
                    tone: ChipTone.success,
                  ),
                ),
                SizedBox(width: Gap.sm),
                Expanded(
                  child: LipStat(
                    value: '12',
                    label: 'Day streak',
                    tone: ChipTone.gold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.xl),

            // ---- tone ---------------------------------------------------
            const LipLabel('Semantic tone'),
            const SizedBox(height: Gap.md),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: const [
                LipChip('Correct', tone: ChipTone.success),
                LipChip('Wrong', tone: ChipTone.danger),
                LipChip('Marked', tone: ChipTone.warning),
                LipChip('Gold', tone: ChipTone.gold),
                LipChip('Neutral'),
              ],
            ),
            const SizedBox(height: Gap.xl),

            // ---- buttons -------------------------------------------------
            const LipLabel('Actions'),
            const SizedBox(height: Gap.md),
            const LipButton(
              label: 'Start practice',
              icon: Icons.play_arrow_rounded,
            ),
            const SizedBox(height: Gap.sm),
            const LipButton(
              label: 'Start timed CBT',
              gold: true,
              icon: Icons.timer_outlined,
            ),
            const SizedBox(height: Gap.sm),
            const LipButton(label: 'Working…', busy: true),
            const SizedBox(height: Gap.xl),

            // ---- waiting, empty, offline ---------------------------------
            const LipLabel('Waiting'),
            const SizedBox(height: Gap.md),
            GlassSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  LipSkeleton(height: 18, width: 190),
                  SizedBox(height: Gap.sm),
                  LipSkeleton(height: 13),
                  SizedBox(height: Gap.xs),
                  LipSkeleton(height: 13, width: 240),
                ],
              ),
            ),
            const SizedBox(height: Gap.md),
            const LipOfflineBar(hasVault: true),
            const SizedBox(height: Gap.xs),
            const LipOfflineBar(),
            const SizedBox(height: Gap.xl),

            const LipLabel('Nothing here yet'),
            const SizedBox(height: Gap.md),
            GlassSurface(
              tier: GlassTier.deep,
              child: LipEmpty(
                icon: Icons.inbox_rounded,
                title: 'No saved questions',
                message: 'Tap the bookmark on any question and it lands here.',
                actionLabel: 'Start practising',
                onAction: () {},
              ),
            ),
            const SizedBox(height: Gap.xxl),

            Center(
              child: Text(
                'com.lockinpoint.app · 1.0.0+1',
                style: LipType.label.copyWith(color: c.text3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The sun/moon knob, matching the website's frosted pill.
class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle({required this.onTap, required this.isDark});
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    return Semantics(
      button: true,
      label: isDark ? 'Switch to light mode' : 'Switch to dark mode',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 58,
          height: 34,
          decoration: BoxDecoration(
            color: c.glassDeep,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: c.glassBorder),
          ),
          child: AnimatedAlign(
            duration: Motion.slow,
            curve: Motion.spring,
            alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: c.glassRaised,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.glassBorderStrong),
                ),
                child: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  size: 14,
                  color: isDark ? c.accent : c.accent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
