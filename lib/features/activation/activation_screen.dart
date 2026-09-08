import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../design/components.dart';
import '../../design/glass.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import 'activation_repository.dart';
import 'store_purchase.dart';

/// ===========================================================================
/// ACTIVATION
///
/// Three doors, and the app is honest about which of them is open.
///
///   CARD — Paystack, opened in the browser rather than a webview, because a
///          bank's 3-D Secure page and an in-app webview disagree often
///          enough that a student loses a payment over it.
///   TRANSFER — the accounts an admin manages. Never the sentence "send it to
///          our account" with nothing underneath it; if the list is empty the
///          screen says transfer is not set up rather than pretending.
///   KEY — the seven digit key an agent sells.
///
///   STORE — Google Play or the App Store, which both REQUIRE in-app purchase
///          for digital goods on their own platforms. The button appears only
///          when the backend says that store's credentials AND its product id
///          are saved: a purchase button that cannot complete a purchase is
///          worse than none, because the student concludes the app is broken.
///
/// AND THE RECEIPT IS SENT FROM HERE. Uploading a transfer screenshot used to
/// mean opening the browser and signing in a second time to send an image the
/// phone already had — three steps, on the payment path most students here
/// actually use.
/// ===========================================================================
class ActivationScreen extends ConsumerStatefulWidget {
  const ActivationScreen({super.key});

  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  final _key = TextEditingController();
  String _message = '';
  bool _ok = false;
  bool _busy = false;
  String _copied = '';
  StorePurchase? _store;

  @override
  void initState() {
    super.initState();
    /* Listening starts before any button is pressed. The purchase stream also
       delivers purchases that completed while the app was closed, so a student
       who paid and then lost signal is activated the next time they open it
       without having to do anything at all. */
    if (StorePurchase.platformHasStore) {
      _store = StorePurchase(ref.read(apiProvider))
        ..listen(
          onDone: (m) {
            if (!mounted) return;
            setState(() {
              _message = m;
              _ok = true;
              _busy = false;
            });
            ref.invalidate(activationOfferProvider);
          },
          onProblem: (m) {
            if (!mounted) return;
            setState(() {
              _message = m;
              _ok = false;
              _busy = false;
            });
          },
        );
    }
  }

  @override
  void dispose() {
    _key.dispose();
    _store?.dispose();
    super.dispose();
  }

  /// The transfer receipt, sent without leaving the app.
  Future<void> _sendReceipt() async {
    final api = ref.read(apiProvider);
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // The route refuses anything over 4MB, and a modern phone camera makes
      // files well past that. Shrinking here means a student is never told
      // their own screenshot is too big.
      maxWidth: 1600,
      imageQuality: 82,
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      final m = await sendTransferProof(api, imagePath: picked.path);
      if (!mounted) return;
      setState(() {
        _message = m;
        _ok = true;
      });
      ref.invalidate(activationOfferProvider);
    } on ApiFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e.message;
        _ok = false;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _buyFromStore(String productId) async {
    setState(() {
      _busy = true;
      _message = '';
    });
    final problem = await _store?.buy(productId);
    if (!mounted) return;
    if (problem != null) {
      setState(() {
        _message = problem;
        _ok = false;
        _busy = false;
      });
    }
    // Otherwise the purchase stream answers — including much later, and even
    // after the app has been closed and reopened.
  }

  Future<void> _redeem() async {
    // Resolved before the gap, deliberately — see redeemKey's note.
    final api = ref.read(apiProvider);
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      final m = await redeemKey(api, _key.text);
      if (!mounted) return;
      setState(() {
        _message = m;
        _ok = m.toLowerCase().contains('activ');
      });
      if (_ok) ref.invalidate(activationOfferProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = '$e';
        _ok = false;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final offer = ref.watch(activationOfferProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Activate')),
      body: SafeArea(
        child: offer.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(Gap.lg),
            child: Column(
              children: [
                LipSkeleton(height: 120),
                SizedBox(height: Gap.md),
                LipSkeleton(height: 200),
              ],
            ),
          ),
          error: (e, _) => LipError(
            message: '$e',
            onRetry: () => ref.invalidate(activationOfferProvider),
          ),
          data: (o) => o.activated
              ? _Activated(productKey: o.productKey)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.lg,
                    Gap.lg,
                    Gap.lg,
                    Gap.huge,
                  ),
                  children: [
                    // ---- the price, from the server ----------------------
                    GlassSurface(
                      tier: GlassTier.raised,
                      seam: true,
                      child: Column(
                        children: [
                          const LipLabel('One payment · everything opens'),
                          const SizedBox(height: Gap.sm),
                          if (o.hasPrice)
                            Text(
                              o.priceLabel,
                              style: LipType.hero.copyWith(color: c.brand),
                            )
                          else
                            Text(
                              'Pricing for your country is not set yet',
                              textAlign: TextAlign.center,
                              style: LipType.subheading.copyWith(
                                color: c.text2,
                              ),
                            ),
                          if (o.note.isNotEmpty) ...[
                            const SizedBox(height: Gap.xs),
                            Text(
                              o.note,
                              textAlign: TextAlign.center,
                              style: LipType.small.copyWith(color: c.text3),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: Gap.lg),

                    // ---- card ------------------------------------------
                    LipButton(
                      gold: true,
                      icon: Icons.credit_card_rounded,
                      label: 'Pay by card, transfer or USSD',
                      onPressed: () => launchUrl(
                        Uri.parse('${AppConfig.apiBase}/activate'),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: Gap.xs),
                      child: Text(
                        'Secured by Paystack. It opens in your browser so your '
                        "bank's confirmation page works properly.",
                        textAlign: TextAlign.center,
                        style: LipType.caption.copyWith(color: c.text3),
                      ),
                    ),
                    const SizedBox(height: Gap.lg),

                    // ---- the stores -------------------------------------
                    // Rendered only when the SERVER says that store can
                    // complete a purchase. See PayWays.
                    if (o.ways.play && StorePurchase.platformHasStore) ...[
                      LipButton(
                        icon: Icons.shop_rounded,
                        label: 'Buy on Google Play',
                        busy: _busy,
                        onPressed: _busy
                            ? null
                            : () => _buyFromStore(o.ways.playProduct),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: Gap.xs),
                        child: Text(
                          'Charged to the account already on this phone. '
                          'Activates everywhere, website included.',
                          textAlign: TextAlign.center,
                          style: LipType.caption.copyWith(color: c.text3),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _store?.restore(),
                        child: const Text('I already paid · restore it'),
                      ),
                      const SizedBox(height: Gap.lg),
                    ] else if (o.ways.appStore &&
                        StorePurchase.platformHasStore) ...[
                      LipButton(
                        icon: Icons.shop_rounded,
                        label: 'Buy on the App Store',
                        busy: _busy,
                        onPressed: _busy
                            ? null
                            : () => _buyFromStore(o.ways.appStoreProduct),
                      ),
                      TextButton(
                        onPressed: () => _store?.restore(),
                        child: const Text('I already paid · restore it'),
                      ),
                      const SizedBox(height: Gap.lg),
                    ],

                    // ---- transfer ---------------------------------------
                    const LipLabel('Direct bank transfer'),
                    const SizedBox(height: Gap.sm),
                    if (o.accounts.isEmpty)
                      GlassSurface(
                        tier: GlassTier.deep,
                        child: Text(
                          'Bank transfer is not set up for your country yet. '
                          'Use the card button above, or message support.',
                          style: LipType.small.copyWith(color: c.text2),
                        ),
                      )
                    else
                      ...o.accounts.map(
                        (a) => Padding(
                          padding: const EdgeInsets.only(bottom: Gap.sm),
                          child: GlassSurface(
                            tier: GlassTier.deep,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (a.accountName.isNotEmpty)
                                  Text(
                                    a.accountName,
                                    style: LipType.subheading.copyWith(
                                      color: c.text1,
                                    ),
                                  ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: SelectableText(
                                        a.accountNumber,
                                        style: LipType.title.copyWith(
                                          color: c.text1,
                                          fontFamily: 'JetBrainsMono',
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () async {
                                        await a.copy();
                                        if (!context.mounted) return;
                                        setState(() => _copied = a.id);
                                      },
                                      icon: Icon(
                                        _copied == a.id
                                            ? Icons.check_rounded
                                            : Icons.copy_rounded,
                                        size: 16,
                                      ),
                                      label: Text(
                                        _copied == a.id ? 'Copied' : 'Copy',
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  [
                                    a.bankName,
                                    a.currency,
                                  ].where((s) => s.isNotEmpty).join(' · '),
                                  style: LipType.small.copyWith(color: c.text2),
                                ),
                                if (a.instructions.isNotEmpty) ...[
                                  const SizedBox(height: Gap.xs),
                                  Text(
                                    a.instructions,
                                    style: LipType.caption.copyWith(
                                      color: c.text3,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (o.accounts.isNotEmpty) ...[
                      const SizedBox(height: Gap.xs),
                      Text(
                        'After sending, tap below to upload your receipt. An '
                        'admin confirms and activates you — usually the same day.',
                        style: LipType.small.copyWith(color: c.text3),
                      ),
                      const SizedBox(height: Gap.sm),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _sendReceipt,
                        icon: const Icon(Icons.upload_file_rounded, size: 18),
                        label: Text(
                          _busy
                              ? 'Sending…'
                              : 'I have sent it · upload my receipt',
                        ),
                      ),
                    ],
                    const SizedBox(height: Gap.lg),

                    // ---- key --------------------------------------------
                    const LipLabel('I have an activation key'),
                    const SizedBox(height: Gap.sm),
                    TextField(
                      controller: _key,
                      keyboardType: TextInputType.number,
                      maxLength: 7,
                      style: LipType.title.copyWith(
                        color: c.text1,
                        fontFamily: 'JetBrainsMono',
                        letterSpacing: 3,
                      ),
                      decoration: const InputDecoration(
                        hintText: '4829175',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: Gap.sm),
                    LipButton(
                      label: 'Redeem key',
                      busy: _busy,
                      onPressed: _key.text.trim().length < 4 ? null : _redeem,
                    ),
                    if (_message.isNotEmpty) ...[
                      const SizedBox(height: Gap.md),
                      GlassSurface(
                        tier: GlassTier.deep,
                        padding: const EdgeInsets.all(Gap.md),
                        child: Text(
                          _message,
                          style: LipType.small.copyWith(
                            color: _ok ? c.success : c.danger,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _Activated extends StatelessWidget {
  const _Activated({required this.productKey});
  final String productKey;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded, size: 56, color: c.success),
            const SizedBox(height: Gap.md),
            Text(
              'You are fully activated',
              style: LipType.title.copyWith(color: c.text1),
            ),
            const SizedBox(height: Gap.xs),
            Text(
              'Every exam, every year, every feature. Go and lock in.',
              textAlign: TextAlign.center,
              style: LipType.body.copyWith(color: c.text2),
            ),
            if (productKey.isNotEmpty) ...[
              const SizedBox(height: Gap.lg),
              const LipLabel('Your product key'),
              const SizedBox(height: Gap.xs),
              SelectableText(
                productKey,
                style: LipType.heading.copyWith(
                  color: c.brand,
                  fontFamily: 'JetBrainsMono',
                  letterSpacing: 2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
