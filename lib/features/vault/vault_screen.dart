import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/vault/connectivity.dart';
import '../../core/vault/vault_db.dart';
import '../../core/vault/vault_repository.dart';
import '../../design/components.dart';
import '../../design/glass.dart';
import '../../core/vault/essential_download.dart';
import '../../core/vault/exam_download.dart';
import '../practice/practice_session_screen.dart';
import '../../design/motion_widgets.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../practice/practice_repository.dart';

/// ===========================================================================
/// THE OFFLINE VAULT
///
/// What this phone is holding, and what it can still do without a network.
///
/// The whole screen is built so a student in a place with no signal sees
/// their downloads first and an apology never. Downloading needs the network
/// and says so; everything else on this screen works regardless.
/// ===========================================================================
class VaultScreen extends ConsumerWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;
    final packs = ref.watch(vaultPacksProvider);
    final online = ref.watch(isOnlineProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline vault'),
        /* THE DOWNLOAD / UPDATE BUTTON, in the top corner, always there.
        
           There was no `actions:` on this bar at all. The only control that
           ever pulled from the server was a "Retry" that appeared solely
           while the first-launch download happened to be paused — so once
           that finished, a student who wanted the newly-added questions had
           no way to ask for them, which is exactly the button that was
           asked for. */
        actions: [const _UpdateAction()],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!online)
              LipOfflineBar(hasVault: (packs.value ?? const []).isNotEmpty),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(vaultPacksProvider),
                child: packs.when(
                  loading: () => ListView(
                    padding: const EdgeInsets.all(Gap.lg),
                    children: const [
                      LipSkeleton(height: 90),
                      SizedBox(height: Gap.md),
                      LipSkeleton(height: 90),
                    ],
                  ),
                  error: (e, _) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.15,
                      ),
                      LipError(
                        message: 'The vault could not be opened.',
                        onRetry: () => ref.invalidate(vaultPacksProvider),
                      ),
                    ],
                  ),
                  data: (list) => ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      Gap.lg,
                      Gap.lg,
                      Gap.lg,
                      Gap.huge,
                    ),
                    /* The pending banner, the examinations, then what is
                       actually on the phone. An empty vault is no longer an
                       empty SCREEN: the examinations are the thing to act
                       on, and they are what was missing. */
                    itemCount: list.length + 2,
                    separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
                    itemBuilder: (context, i) {
                      if (i == 0) return const _PendingBanner();
                      if (i == 1) return const _Examinations();
                      return Entrance(
                        index: i,
                        child: _PackCard(pack: list[i - 2]),
                      );
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Text(
                'Downloaded questions are answered and marked on this phone. '
                'Your results are sent to LockInPoint the next time you have '
                'a connection.',
                style: LipType.caption.copyWith(color: c.text3),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===========================================================================
/// DOWNLOAD, BY EXAMINATION
///
/// The vault could be FILLED subject by subject and that was the whole of it.
/// A student sitting WAEC had to find and tap Download on each of their nine
/// subjects, one at a time, with no idea what the nine would cost until they
/// had spent it.
///
/// One button per examination. While it runs: per cent, megabytes so far,
/// megabytes in total, the subject being fetched right now, and PAUSE.
/// Paused: RESUME. Failed: RETRY, and the reason in a sentence.
///
/// When an examination is already held, the button says what an update is
/// actually worth — "12 new questions" — rather than just "Update", which
/// tells a student on a metered bundle nothing they can decide with.
/// ===========================================================================
class _Examinations extends ConsumerStatefulWidget {
  const _Examinations();

  @override
  ConsumerState<_Examinations> createState() => _ExaminationsState();
}

class _ExaminationsState extends ConsumerState<_Examinations> {
  @override
  void initState() {
    super.initState();
    // After the first frame, so the notifier is not written to during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(vaultDownloadProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final st = ref.watch(vaultDownloadProvider);

    if (st.loading && st.exams.isEmpty) {
      return const LipSkeleton(height: 120);
    }

    /* NO NETWORK AND NOTHING CACHED. Said plainly, and NOT as an error card:
       a student with downloads already on the phone is here to use them, and
       this section is simply the part that needs a connection. */
    if (st.exams.isEmpty) {
      if (st.listProblem.isEmpty) return const SizedBox.shrink();
      return GlassSurface(
        padding: const EdgeInsets.all(Gap.md),
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded, size: 20, color: c.text3),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Text(
                'The list of examinations needs a connection. Your downloads '
                'below still work.',
                style: LipType.caption.copyWith(color: c.text3),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LipLabel('Download a whole examination'),
        const SizedBox(height: Gap.sm),
        for (final e in st.exams) ...[
          _ExamCard(plan: e, st: st),
          const SizedBox(height: Gap.sm),
        ],
      ],
    );
  }
}

class _ExamCard extends ConsumerWidget {
  const _ExamCard({required this.plan, required this.st});

  final ExamPlan plan;
  final VaultDownloadState st;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;
    final notifier = ref.read(vaultDownloadProvider.notifier);
    final online = ref.watch(isOnlineProvider);

    final isThisOne = st.runningExam == plan.slug;
    final running = isThisOne && st.phase == VaultRunPhase.running;
    final paused = isThisOne && st.phase == VaultRunPhase.paused;
    final failed = isThisOne && st.phase == VaultRunPhase.failed;

    // Another examination is mid-run: this one's button waits its turn
    // rather than starting a second download over the same connection.
    final busyElsewhere = st.isBusy && !isThisOne;

    String buttonLabel() {
      if (running) return 'Downloading…';
      if (paused) return 'Resume';
      if (failed) return 'Retry';
      if (plan.complete && !plan.anyUpdate) return 'Downloaded';
      if (plan.behind > 0 && plan.heldSubjects > 0) {
        return '${plan.behind} new question${plan.behind == 1 ? '' : 's'}';
      }
      return 'Download';
    }

    final nothingToDo = plan.complete && !plan.anyUpdate && !isThisOne;

    return GlassSurface(
      tier: GlassTier.raised,
      padding: const EdgeInsets.all(Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: LipType.subheading.copyWith(color: c.text1),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${plan.heldSubjects} of ${plan.subjects.length} '
                      'subjects on this phone · about '
                      '${VaultDownloadState.mb(plan.bytes)} in all',
                      style: LipType.caption.copyWith(color: c.text3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.sm),
              if (plan.heldSubjects > 0)
                IconButton(
                  tooltip: 'Remove ${plan.name} from this phone',
                  icon: Icon(Icons.delete_outline_rounded, color: c.text3),
                  onPressed: st.isBusy
                      ? null
                      : () => _confirmRemove(context, ref, plan),
                ),
            ],
          ),

          if (running || paused) ...[
            const SizedBox(height: Gap.md),
            /* FOUR HONEST NUMBERS. Per cent and megabytes come from the
               server's own count of what is there; the subject name is the
               one being fetched at this moment. A bar that reaches 90% and
               stops costs more trust than no bar at all. */
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.sm),
              child: LinearProgressIndicator(
                value: st.fraction,
                minHeight: 8,
                backgroundColor: c.glassDeep,
                valueColor: AlwaysStoppedAnimation(c.hues.blue.ink),
              ),
            ),
            const SizedBox(height: Gap.xs),
            Text(
              '${st.percent}% · ${st.sizeLine}'
              '${st.current.isEmpty ? '' : ' · ${st.current}'}',
              style: LipType.caption.copyWith(color: c.text3),
            ),
          ],

          if (failed && st.problem.isNotEmpty) ...[
            const SizedBox(height: Gap.sm),
            Text(
              st.problem,
              style: LipType.caption.copyWith(color: c.hues.rose.ink),
            ),
          ],

          const SizedBox(height: Gap.md),
          Row(
            children: [
              Expanded(
                child: LipButton(
                  label: buttonLabel(),
                  onPressed:
                      (!online || busyElsewhere || nothingToDo || running)
                      ? null
                      : () {
                          if (paused || failed) {
                            notifier.resume();
                          } else {
                            notifier.start(plan.slug);
                          }
                        },
                ),
              ),
              /* PAUSE STOPS BEFORE THE NEXT SUBJECT, and the label says so
                 rather than pretending it stops instantly. One subject's
                 pack is one request; abandoning it mid-flight would throw
                 away data the student has already paid for. */
              if (running) ...[
                const SizedBox(width: Gap.sm),
                OutlinedButton.icon(
                  onPressed: notifier.pause,
                  icon: const Icon(Icons.pause_rounded, size: 18),
                  label: const Text('Pause'),
                ),
              ],
            ],
          ),
          if (running)
            Padding(
              padding: const EdgeInsets.only(top: Gap.xs),
              child: Text(
                'Pause finishes the subject it is on, then stops.',
                style: LipType.caption.copyWith(color: c.text3),
              ),
            ),
          if (!online && !nothingToDo)
            Padding(
              padding: const EdgeInsets.only(top: Gap.xs),
              child: Text(
                'Downloading needs a connection.',
                style: LipType.caption.copyWith(color: c.text3),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    ExamPlan plan,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Remove ${plan.name}?'),
        content: Text(
          '${plan.heldSubjects} subject'
          '${plan.heldSubjects == 1 ? '' : 's'} leave this phone. You can '
          'download them again whenever you have a connection.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep them'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (yes == true) {
      await ref.read(vaultDownloadProvider.notifier).removeExam(plan.slug);
    }
  }
}

/// Papers sat offline that have not yet reached the server. Silent when there
/// are none, which is almost always.
class _PendingBanner extends ConsumerStatefulWidget {
  const _PendingBanner();

  @override
  ConsumerState<_PendingBanner> createState() => _PendingBannerState();
}

class _PendingBannerState extends ConsumerState<_PendingBanner> {
  int _pending = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _count();
  }

  Future<void> _count() async {
    final n = await ref.read(vaultProvider).pendingCount();
    if (mounted) setState(() => _pending = n);
  }

  @override
  Widget build(BuildContext context) {
    if (_pending == 0) return const SizedBox.shrink();
    final c = context.lip;
    final online = ref.watch(isOnlineProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: GlassSurface(
        hue: c.hues.amber,
        child: Row(
          children: [
            Icon(Icons.cloud_upload_rounded, size: 20, color: c.hues.amber.ink),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Text(
                '$_pending paper${_pending == 1 ? '' : 's'} sat offline, '
                'waiting to be sent.',
                style: LipType.small.copyWith(color: c.text1),
              ),
            ),
            if (online)
              TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        await ref.read(vaultProvider).syncPending();
                        await _count();
                        if (mounted) setState(() => _busy = false);
                      },
                child: Text(_busy ? 'Sending…' : 'Send now'),
              ),
          ],
        ),
      ),
    );
  }
}

class _PackCard extends ConsumerWidget {
  const _PackCard({required this.pack});
  final Pack pack;

  /// OPENING A PACK — the step that did not exist.
  ///
  /// Every piece of offline practice was already built and working:
  /// `openSitting()` assembles the paper out of the local database,
  /// `sittingFromVault()` reshapes it into what the practice screen speaks,
  /// and that screen runs happily with no network. NOTHING CALLED THEM. This
  /// card showed a downloaded subject, its question count, and a delete
  /// button — so the one thing a student downloads a pack in order to do was
  /// the one thing they could not do with it.
  Future<void> _sit(BuildContext context, WidgetRef ref) async {
    final offline = await ref.read(vaultProvider).openSitting(pack.subjectId);
    if (!context.mounted) return;
    if (offline == null) {
      /* The row exists but its questions do not — a download interrupted
         part-way. Said plainly, with the way out, rather than as a screen
         that opens on nothing. */
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'This download is incomplete. Remove it and download '
              '${pack.subjectName} again.',
            ),
          ),
        );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PracticeSessionScreen(sitting: sittingFromVault(offline)),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;

    return GlassSurface(
      tier: GlassTier.card,
      onTap: () => _sit(context, ref),
      semanticLabel:
          'Practise ${pack.subjectName} offline. '
          '${pack.examShort}, ${pack.count} questions.',
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: c.hues.teal.tint,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Icon(
              Icons.offline_bolt_rounded,
              size: 22,
              color: c.hues.teal.ink,
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pack.subjectName,
                  style: LipType.subheading.copyWith(color: c.text1),
                ),
                const SizedBox(height: 2),
                Text(
                  // The exam is named, always. WAEC and WAEC GCE are
                  // different examinations and a student must be able to see
                  // which one they are holding.
                  '${pack.examShort} · ${pack.count} questions',
                  style: LipType.small.copyWith(color: c.text3),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap to practise — no signal needed',
                  style: LipType.label.copyWith(color: c.hues.teal.ink),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove download',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('Remove ${pack.subjectName}?'),
                  content: const Text(
                    'The questions leave this phone. You can download them '
                    'again whenever you have a connection.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Keep'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await ref.read(vaultProvider).remove(pack.subjectId);
                ref.invalidate(vaultPacksProvider);
              }
            },
          ),
        ],
      ),
    );
  }
}

/// The button that puts a subject on the phone. Shown wherever a subject is
/// chosen, and honest about needing a network to do its one job.
class DownloadPackButton extends ConsumerStatefulWidget {
  const DownloadPackButton({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  final String subjectId;
  final String subjectName;

  @override
  ConsumerState<DownloadPackButton> createState() => _DownloadPackButtonState();
}

class _DownloadPackButtonState extends ConsumerState<DownloadPackButton> {
  bool _busy = false;
  bool? _have;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final have = await ref.read(vaultProvider).hasPack(widget.subjectId);
    if (mounted) setState(() => _have = have);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    if (_have == null) return const SizedBox.shrink();

    if (_have == true) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.offline_bolt_rounded, size: 17, color: c.hues.green.ink),
          const SizedBox(width: Gap.xs),
          Text(
            'Downloaded',
            style: LipType.smallStrong.copyWith(color: c.hues.green.ink),
          ),
        ],
      );
    }

    return OutlinedButton.icon(
      onPressed: _busy
          ? null
          : () async {
              setState(() => _busy = true);
              try {
                await ref.read(vaultProvider).download(widget.subjectId);
                ref.invalidate(vaultPacksProvider);
                if (!mounted) return;
                setState(() {
                  _have = true;
                  _busy = false;
                });
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${widget.subjectName} is on your phone. It works '
                        'with no connection now.',
                      ),
                    ),
                  );
                }
              } on ApiFailure catch (e) {
                if (!mounted) return;
                setState(() => _busy = false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text(e.message)));
                }
              }
            },
      icon: _busy
          ? const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.download_rounded, size: 17),
      label: Text(_busy ? 'Downloading…' : 'Download for offline'),
    );
  }
}

/// Turns a vault sitting into the shape the practice session already speaks,
/// so offline practice reuses the exact screen online practice uses.
Sitting sittingFromVault(OfflineSitting s, {int minutes = 0}) => Sitting(
  attemptId:
      'offline:${s.pack.subjectId}:${DateTime.now().millisecondsSinceEpoch}',
  mode: 'practice',
  label: '${s.pack.subjectName} · offline',
  questions: s.questions,
  passages: s.passages,
  duration: minutes * 60,
  initialIndex: 0,
);

/// Pulls anything new down, and says what it is doing while it does.
///
/// It is deliberately ONE control for both jobs. A student does not think in
/// terms of "the first download" and "an update" — they think "get me the
/// new questions", and the phone already knows which of the two that is.
class _UpdateAction extends ConsumerWidget {
  const _UpdateAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;
    final essential = ref.watch(essentialDownloadProvider);
    final running = essential.phase == EssentialPhase.running;
    final online = ref.watch(isOnlineProvider);

    if (running) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.md),
        child: Center(
          child: Text(
            /* THE MB AND THE PERCENTAGE, which is what was asked for — and
               they belong here as much as on the first-launch screen, since
               this is where a student comes to watch a big update land. */
            essential.totalBytes > 0
                ? '${essential.percent}% · ${essential.sizeLine}'
                : 'Downloading…',
            style: LipType.label.copyWith(color: c.brand),
          ),
        ),
      );
    }

    return IconButton(
      tooltip: online ? 'Check for new questions' : 'No connection',
      icon: Icon(Icons.cloud_download_rounded, color: online ? null : c.text3),
      onPressed: !online
          ? null
          : () async {
              final notifier = ref.read(essentialDownloadProvider.notifier);
              await notifier.check();
              if (ref.read(essentialDownloadProvider).phase ==
                  EssentialPhase.needed) {
                await notifier.start();
              } else if (context.mounted) {
                /* SAYING "nothing new" OUT LOUD MATTERS. A button that can
                   answer with silence is a button a student taps again and
                   again wondering whether it worked. */
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('You already have everything.'),
                    ),
                  );
              }
              ref.invalidate(vaultPacksProvider);
            },
    );
  }
}
