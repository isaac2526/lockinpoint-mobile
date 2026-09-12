import '../../core/json.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/vault/materials.dart';
import '../../design/components.dart';
import '../../design/glass.dart';
import '../../design/motion_widgets.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';

/// ===========================================================================
/// RECEIPTS
///
/// /receipts has been on the website since the beginning; on the phone a
/// student could watch the money leave and never see a record of it. Every
/// payment, activation key and transfer that ever touched this account, each
/// with the branded PDF the server already knows how to make.
///
/// The document is fetched through `/api/receipt-pdf/<reference>`, which checks
/// that the reference belongs to the caller and floods every page with the
/// owner's name — so a receipt saved to a phone is as hard to forge as one
/// printed from a browser.
/// ===========================================================================
class Receipt {
  const Receipt({
    required this.reference,
    required this.amount,
    required this.currency,
    required this.label,
    required this.status,
    required this.createdAt,
    required this.receiptPath,
  });

  final String reference;
  final num amount;
  final String currency;
  final String label;
  final String status;
  final String createdAt;
  final String receiptPath;

  bool get settled => status == 'success' || status == 'manual';

  static Receipt fromJson(Map<String, dynamic> j) => Receipt(
    reference: asText(j['reference']),
    amount: (j['amount'] as num?) ?? 0,
    currency: asText(j['currency'], 'NGN'),
    label: asText(j['label'], 'Payment'),
    status: asText(j['status']),
    createdAt: asText(j['createdAt']),
    receiptPath: asText(j['receiptPath']),
  );

  /// The symbol where there is one, the code where there is not. A currency
  /// the platform starts selling in tomorrow renders as "GHS 40" rather than
  /// as a blank.
  String get money {
    final n = amount == amount.roundToDouble()
        ? amount.round().toString()
        : amount.toStringAsFixed(2);
    final withCommas = n.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );
    return switch (currency.toUpperCase()) {
      'NGN' => '₦$withCommas',
      'USD' => '\$$withCommas',
      'GBP' => '£$withCommas',
      'EUR' => '€$withCommas',
      _ => '${currency.toUpperCase()} $withCommas',
    };
  }

  String get when {
    final t = DateTime.tryParse(createdAt)?.toLocal();
    if (t == null) return '';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${t.day} ${months[t.month - 1]} ${t.year}';
  }
}

final receiptsProvider = FutureProvider.autoDispose<List<Receipt>>((ref) async {
  final res = await ref.read(apiProvider).get('/api/mobile/receipts');
  return ((res['receipts'] as List?) ?? const [])
      .whereType<Map>()
      .map((m) => Receipt.fromJson(m.cast<String, dynamic>()))
      .toList();
});

class ReceiptsScreen extends ConsumerWidget {
  const ReceiptsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(receiptsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Receipts')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(receiptsProvider),
          child: list.when(
            loading: () => ListView(
              padding: const EdgeInsets.all(Gap.lg),
              children: const [
                LipSkeleton(height: 88),
                SizedBox(height: Gap.md),
                LipSkeleton(height: 88),
              ],
            ),
            error: (e, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.sizeOf(context).height * 0.15),
                LipError(
                  message: e is ApiFailure ? e.message : 'Pull down to retry.',
                  detail: e is ApiFailure ? e.detail : null,
                  onRetry: () => ref.invalidate(receiptsProvider),
                ),
              ],
            ),
            data: (rows) => rows.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.15,
                      ),
                      const LipEmpty(
                        icon: Icons.receipt_long_rounded,
                        title: 'No receipts yet',
                        message:
                            'Every payment, key and transfer will appear here '
                            'with its own printable receipt.',
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(Gap.lg),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
                    itemBuilder: (context, i) =>
                        Entrance.inList(index: i, child: _ReceiptCard(rows[i])),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard(this.r);
  final Receipt r;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    return GlassSurface(
      tier: GlassTier.card,
      semanticLabel:
          '${r.label}, ${r.money}, ${r.when}, '
          '${r.settled ? "paid" : r.status}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.label,
                  style: LipType.bodyStrong.copyWith(color: c.text1),
                ),
              ),
              Text(r.money, style: LipType.mono.copyWith(color: c.brand)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (r.when.isNotEmpty)
                Text(r.when, style: LipType.small.copyWith(color: c.text3)),
              const Spacer(),
              LipChip(
                r.settled ? 'Paid' : r.status,
                tone: r.settled ? ChipTone.success : ChipTone.warning,
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  r.reference,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LipType.label.copyWith(color: c.text3),
                ),
              ),
              IconButton(
                tooltip: 'Copy reference',
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: r.reference));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reference copied.')),
                  );
                },
              ),
            ],
          ),
          if (r.settled && r.receiptPath.isNotEmpty) ...[
            const SizedBox(height: Gap.sm),
            _OpenReceipt(receipt: r),
          ],
        ],
      ),
    );
  }
}

/// Fetches the receipt through the session and opens it.
///
/// IT USED TO LAUNCH THE URL IN THE PHONE'S BROWSER. `/api/receipt-pdf/<ref>`
/// checks that the reference belongs to the caller and floods every page with
/// the owner's name — so it needs the session, and the browser has none. An
/// app-only student got a raw `{"ok":false,"message":"Log in first."}` blob
/// where their receipt should have been.
class _OpenReceipt extends ConsumerStatefulWidget {
  const _OpenReceipt({required this.receipt});
  final Receipt receipt;

  @override
  ConsumerState<_OpenReceipt> createState() => _OpenReceiptState();
}

class _OpenReceiptState extends ConsumerState<_OpenReceipt> {
  bool _busy = false;

  Future<void> _open() async {
    setState(() => _busy = true);
    final r = widget.receipt;
    final said = await ref
        .read(documentOpenerProvider)
        .open(
          // The reference names the cached file, so re-opening the same receipt
          // never costs a second download.
          id: 'receipt-${r.reference}',
          url: r.receiptPath,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (said == null) return;

    if (said == 'openInBrowser') {
      await launchUrl(
        Uri.parse('${AppConfig.apiBase}${r.receiptPath}'),
        mode: LaunchMode.externalApplication,
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(said)));
  }

  @override
  Widget build(BuildContext context) => LipButton(
    label: 'Open receipt',
    icon: Icons.picture_as_pdf_rounded,
    expand: true,
    busy: _busy,
    onPressed: _open,
  );
}
