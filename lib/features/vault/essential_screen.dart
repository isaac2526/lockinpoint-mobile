import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/vault/essential_download.dart';
import '../../design/components.dart';
import '../../design/glass.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';

/// ===========================================================================
/// "GETTING YOUR QUESTIONS READY" · the first-launch download.
///
/// THERE IS NO SKIP BUTTON, and there is a Continue button. Those are
/// different things and the difference is the whole design.
///
/// Skip would mean a student declines the offline data and then, three days
/// later on a bus with no signal, opens an app that cannot show them a single
/// question. They did not choose that; they chose "not now" and got "never".
/// Continue lets them use the app immediately while the rest arrives, with
/// the bar following them to the top of the screen.
///
/// EVERY NUMBER IS REAL and the megabytes are labelled an estimate, because
/// they are one. A student on a metered bundle is watching that figure decide
/// whether they can afford to finish, and a bar that says 4 MB and downloads
/// 40 costs more trust than no bar at all.
/// ===========================================================================
class EssentialDownloadScreen extends ConsumerStatefulWidget {
  const EssentialDownloadScreen({super.key, required this.onContinue});

  /// Called when the student chooses to carry on using the app. The download
  /// keeps running; this only changes where it is drawn.
  final VoidCallback onContinue;

  @override
  ConsumerState<EssentialDownloadScreen> createState() =>
      _EssentialDownloadScreenState();
}

class _EssentialDownloadScreenState
    extends ConsumerState<EssentialDownloadScreen> {
  @override
  void initState() {
    super.initState();
    // Starts itself. A student should not have to press "begin" on something
    // that has no alternative.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(essentialDownloadProvider.notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final s = ref.watch(essentialDownloadProvider);

    return Scaffold(
      backgroundColor: c.bgBase,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Gap.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.download_for_offline_rounded,
                size: 46,
                color: c.hues.teal.ink,
              ),
              const SizedBox(height: Gap.lg),
              Text(
                'Getting your questions ready',
                textAlign: TextAlign.center,
                style: LipType.title.copyWith(color: c.text1),
              ),
              const SizedBox(height: Gap.sm),
              Text(
                'Every subject, once, so LockInPoint works on a bus, in a '
                'hostel, anywhere. Notes and PDFs are separate — you choose '
                'those one at a time.',
                textAlign: TextAlign.center,
                style: LipType.small.copyWith(color: c.text3),
              ),
              const SizedBox(height: Gap.xl),

              GlassSurface(
                tier: GlassTier.raised,
                padding: const EdgeInsets.all(Gap.lg),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.pill),
                      child: LinearProgressIndicator(
                        value: s.totalBytes > 0 ? s.fraction : null,
                        minHeight: 10,
                        backgroundColor: c.glassDeep,
                        valueColor: AlwaysStoppedAnimation(c.hues.teal.ink),
                      ),
                    ),
                    const SizedBox(height: Gap.md),
                    Row(
                      children: [
                        Text(
                          '${s.percent}%',
                          style: LipType.monoBig.copyWith(color: c.text1),
                        ),
                        const Spacer(),
                        Text(
                          // "about", because it is an estimate and saying so
                          // is cheaper than being caught out by it.
                          s.sizeLine,
                          style: LipType.small.copyWith(color: c.text3),
                        ),
                      ],
                    ),
                    if (s.current.isNotEmpty) ...[
                      const SizedBox(height: Gap.xs),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          s.current,
                          style: LipType.caption.copyWith(color: c.text3),
                        ),
                      ),
                    ],
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${s.doneSubjects.length} of ${s.plans.length} subjects',
                        style: LipType.caption.copyWith(color: c.text3),
                      ),
                    ),
                  ],
                ),
              ),

              if (s.problem.isNotEmpty) ...[
                const SizedBox(height: Gap.lg),
                LipFormError(message: s.problem),
              ],

              if (s.phase == EssentialPhase.paused) ...[
                const SizedBox(height: Gap.lg),
                LipButton(
                  label: 'Try the rest again',
                  onPressed: () =>
                      ref.read(essentialDownloadProvider.notifier).start(),
                ),
              ],

              const SizedBox(height: Gap.lg),
              /* NOT a skip. The download keeps running; this only moves where
                 it is drawn. There is deliberately no way to decline it. */
              TextButton(
                onPressed: widget.onContinue,
                child: const Text('Continue while this finishes'),
              ),
              Text(
                'It keeps downloading in the background.',
                textAlign: TextAlign.center,
                style: LipType.caption.copyWith(color: c.text3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The same run, once the student has carried on: a thin bar that follows
/// them until it finishes. Silent when there is nothing to say.
class EssentialProgressBar extends ConsumerWidget {
  const EssentialProgressBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;
    final s = ref.watch(essentialDownloadProvider);
    if (s.phase != EssentialPhase.running && s.phase != EssentialPhase.paused) {
      return const SizedBox.shrink();
    }

    return Container(
      color: c.hues.teal.tint,
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
      child: Row(
        children: [
          SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: s.totalBytes > 0 ? s.fraction : null,
              valueColor: AlwaysStoppedAnimation(c.hues.teal.ink),
            ),
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              s.phase == EssentialPhase.paused
                  ? 'Some subjects still to download · ${s.percent}%'
                  : 'Getting your questions ready · ${s.percent}% · ${s.sizeLine}',
              style: LipType.caption.copyWith(color: c.hues.teal.ink),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (s.phase == EssentialPhase.paused)
            InkWell(
              onTap: () => ref.read(essentialDownloadProvider.notifier).start(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
                child: Text(
                  'Retry',
                  style: LipType.caption.copyWith(
                    color: c.hues.teal.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
