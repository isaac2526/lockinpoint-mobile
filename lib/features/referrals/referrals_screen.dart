import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../design/components.dart';
import '../../design/glass.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import 'referrals_repository.dart';

/// ===========================================================================
/// REFERRALS · your code, what it has earned, and how to be paid.
///
/// NOT ONE FIGURE IN THIS FILE. The reward, the minimum, the balance and the
/// currency all come from the server in the student's own money, so a rate
/// change reaches the phone on the next open rather than in the next release.
///
/// THE SERVER DECIDES WHETHER A PAYOUT CAN BE ASKED FOR. It checks the
/// balance, the minimum and the account details; a client that second-guesses
/// any of those will eventually disagree with it, and the student is the one
/// who finds out.
/// ===========================================================================
class ReferralsScreen extends ConsumerWidget {
  const ReferralsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;
    final r = ref.watch(referralsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Refer a friend')),
      body: SafeArea(
        child: r.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(Gap.lg),
            child: LipSkeleton(height: 240),
          ),
          error: (e, _) => LipError(
            message: '$e',
            onRetry: () => ref.invalidate(referralsProvider),
          ),
          data: (d) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(referralsProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.lg,
                Gap.lg,
                Gap.huge,
              ),
              children: [
                GlassSurface(
                  hue: c.hues.green,
                  padding: const EdgeInsets.all(Gap.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const LipLabel('Your code'),
                      const SizedBox(height: Gap.xs),
                      Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              d.code.isEmpty ? '—' : d.code,
                              style: LipType.monoBig.copyWith(color: c.text1),
                            ),
                          ),
                          if (d.code.isNotEmpty)
                            IconButton(
                              tooltip: 'Copy',
                              icon: const Icon(Icons.copy_rounded, size: 19),
                              onPressed: () async {
                                await d.copyCode();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Code copied')),
                                );
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: Gap.sm),
                      Text(
                        'They type it when they sign up. You earn '
                        '${d.reward.label} once they activate — not when they '
                        'join, which is the part most people get wrong.',
                        style: LipType.small.copyWith(color: c.text3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Gap.lg),

                Row(
                  children: [
                    Expanded(
                      child: LipStat(
                        value: '${d.joined}',
                        label: 'joined with it',
                        tone: ChipTone.neutral,
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: LipStat(
                        value: '${d.activated}',
                        label: 'activated',
                        tone: ChipTone.success,
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: LipStat(
                        value: d.balance.label,
                        label: 'to withdraw',
                        tone: ChipTone.gold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.lg),

                if (!d.canWithdraw)
                  GlassSurface(
                    tier: GlassTier.deep,
                    padding: const EdgeInsets.all(Gap.md),
                    child: Text(
                      'You can withdraw once your balance reaches '
                      '${d.minimum.label}. Keep sharing.',
                      style: LipType.small.copyWith(color: c.text2),
                    ),
                  )
                else
                  LipButton(
                    gold: true,
                    label: 'Withdraw ${d.balance.label}',
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (_) => const _PayoutSheet(),
                    ),
                  ),

                if (d.withdrawals.isNotEmpty) ...[
                  const SizedBox(height: Gap.lg),
                  const LipLabel('Your requests'),
                  const SizedBox(height: Gap.sm),
                  for (final w in d.withdrawals)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Gap.sm),
                      child: GlassSurface(
                        tier: GlassTier.raised,
                        padding: const EdgeInsets.all(Gap.md),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${w.currency} ${w.amount}',
                                style: LipType.body.copyWith(color: c.text1),
                              ),
                            ),
                            LipChip(
                              w.status,
                              tone: w.status == 'paid'
                                  ? ChipTone.success
                                  : w.status == 'declined'
                                  ? ChipTone.danger
                                  : ChipTone.warning,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PayoutSheet extends ConsumerStatefulWidget {
  const _PayoutSheet();

  @override
  ConsumerState<_PayoutSheet> createState() => _PayoutSheetState();
}

class _PayoutSheetState extends ConsumerState<_PayoutSheet> {
  final _name = TextEditingController();
  final _bank = TextEditingController();
  final _number = TextEditingController();
  bool _busy = false;
  String _message = '';

  @override
  void dispose() {
    _name.dispose();
    _bank.dispose();
    _number.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _message = '';
    });
    final msg = await requestPayout(
      ref.read(apiProvider),
      accountName: _name.text.trim(),
      bankName: _bank.text.trim(),
      accountNumber: _number.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = msg;
    });
    ref.invalidate(referralsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Gap.lg,
        0,
        Gap.lg,
        MediaQuery.viewInsetsOf(context).bottom + Gap.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Where should it go?',
            style: LipType.subheading.copyWith(color: c.text1),
          ),
          const SizedBox(height: Gap.sm),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Account name'),
          ),
          const SizedBox(height: Gap.sm),
          TextField(
            controller: _bank,
            decoration: const InputDecoration(labelText: 'Bank name'),
          ),
          const SizedBox(height: Gap.sm),
          TextField(
            controller: _number,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Account number'),
          ),
          if (_message.isNotEmpty) ...[
            const SizedBox(height: Gap.md),
            Text(_message, style: LipType.small.copyWith(color: c.text2)),
          ],
          const SizedBox(height: Gap.lg),
          LipButton(
            label: _busy ? 'Sending…' : 'Request payout',
            busy: _busy,
            onPressed: _busy ? null : _send,
          ),
          const SizedBox(height: Gap.xs),
          Text(
            'The team pays verified requests within 24 to 48 hours.',
            style: LipType.caption.copyWith(color: c.text3),
          ),
        ],
      ),
    );
  }
}
