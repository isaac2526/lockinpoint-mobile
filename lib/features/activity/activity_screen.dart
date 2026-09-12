import '../../core/json.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/components.dart';
import '../../design/glass.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import 'activity_repository.dart';

/// ===========================================================================
/// EVERYTHING YOU HAVE DONE HERE.
///
/// One page per forty rows, newest first, with the walk-forward-and-back that
/// the search screen already uses — a student looking for the day they
/// activated does not want to scroll a year.
/// ===========================================================================
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  int _page = 1;

  static const _icons = {
    'login': Icons.login_rounded,
    'practice': Icons.rocket_launch_rounded,
    'check': Icons.check_circle_rounded,
    'game': Icons.sports_esports_rounded,
    'key': Icons.vpn_key_rounded,
    'flag': Icons.flag_rounded,
    'robot': Icons.smart_toy_rounded,
    'bell': Icons.notifications_rounded,
    'wallet': Icons.account_balance_wallet_rounded,
    'upload': Icons.upload_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final page = ref.watch(activityProvider(_page));

    return Scaffold(
      appBar: AppBar(title: const Text('Your activity')),
      body: SafeArea(
        child: page.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(Gap.lg),
            child: LipSkeleton(height: 300),
          ),
          error: (e, _) => LipError(
            message: humanError(e, doing: 'load your activities'),
            onRetry: () => ref.invalidate(activityProvider(_page)),
          ),
          data: (p) => p.rows.isEmpty && _page == 1
              ? const LipEmpty(
                  icon: Icons.history_rounded,
                  title: 'Nothing recorded yet',
                  message:
                      'Sittings, activations and everything else you do here '
                      'will appear on this page.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.lg,
                    Gap.lg,
                    Gap.lg,
                    Gap.huge,
                  ),
                  children: [
                    Text(
                      '${p.total} thing${p.total == 1 ? '' : 's'} recorded',
                      style: LipType.small.copyWith(color: c.text3),
                    ),
                    const SizedBox(height: Gap.md),
                    for (final r in p.rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Gap.sm),
                        child: GlassSurface(
                          tier: GlassTier.raised,
                          padding: const EdgeInsets.all(Gap.md),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _icons[r.icon] ?? Icons.circle_outlined,
                                size: 19,
                                color: c.hues.slate.ink,
                              ),
                              const SizedBox(width: Gap.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.title,
                                      style: LipType.body.copyWith(
                                        color: c.text1,
                                      ),
                                    ),
                                    if (r.detail.isNotEmpty)
                                      Text(
                                        r.detail,
                                        style: LipType.caption.copyWith(
                                          color: c.text2,
                                        ),
                                      ),
                                    Text(
                                      _when(r.at),
                                      style: LipType.caption.copyWith(
                                        color: c.text3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: Gap.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _page > 1
                              ? () => setState(() => _page--)
                              : null,
                          child: const Text('Newer'),
                        ),
                        Text(
                          'Page $_page',
                          style: LipType.caption.copyWith(color: c.text3),
                        ),
                        TextButton(
                          onPressed: p.hasMore
                              ? () => setState(() => _page++)
                              : null,
                          child: const Text('Older'),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// Relative for anything recent, then the date. "3 days ago" stops meaning
  /// anything past about a week, and a student looking for the day they
  /// activated wants the date.
  static String _when(DateTime? at) {
    if (at == null) return '';
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} minutes ago';
    if (d.inHours < 24) return '${d.inHours} hours ago';
    if (d.inDays == 1) return 'yesterday';
    if (d.inDays < 7) return '${d.inDays} days ago';
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${at.day} ${months[at.month - 1]} ${at.year}';
  }
}
