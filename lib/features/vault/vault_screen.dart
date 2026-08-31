import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/vault/connectivity.dart';
import '../../core/vault/vault_db.dart';
import '../../core/vault/vault_repository.dart';
import '../../design/components.dart';
import '../../design/glass.dart';
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
      appBar: AppBar(title: const Text('Offline vault')),
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
                  data: (list) => list.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.sizeOf(context).height * 0.1,
                            ),
                            const LipEmpty(
                              icon: Icons.download_for_offline_rounded,
                              title: 'Nothing downloaded yet',
                              message:
                                  'Open a subject in Practice and download it. '
                                  'Once it is here you can answer it anywhere — '
                                  'on a bus, in a village, with no signal at all.',
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                            Gap.lg,
                            Gap.lg,
                            Gap.lg,
                            Gap.huge,
                          ),
                          itemCount: list.length + 1,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: Gap.md),
                          itemBuilder: (context, i) {
                            if (i == 0) return const _PendingBanner();
                            return Entrance(
                              index: i,
                              child: _PackCard(pack: list[i - 1]),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;

    return GlassSurface(
      tier: GlassTier.card,
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
