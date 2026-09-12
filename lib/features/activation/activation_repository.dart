import '../../core/json.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';

/// ===========================================================================
/// WHAT ACTIVATION COSTS, AND EVERY WAY TO PAY IT
///
/// NOT ONE FIGURE IN THIS FILE. The price comes from `country_prices` through
/// `/api/mobile/activation`, decided for the student's own country, and the
/// bank accounts come from the same table the website's activation page
/// reads. If Isaac changes either in the admin panel, the next launch of the
/// app shows the change — no release, no store review, no APK.
///
/// A country with no price row returns null and the app SAYS so. A wrong
/// number that nobody notices for a term is worse than a visible gap that
/// takes a minute to fill.
/// ===========================================================================

class BankAccount {
  const BankAccount({
    required this.id,
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
    required this.currency,
    required this.instructions,
  });

  final String id;
  final String bankName;
  final String accountName;
  final String accountNumber;
  final String currency;
  final String instructions;

  static BankAccount from(Map<String, dynamic> j) => BankAccount(
    id: asText(j['id']),
    bankName: asText(j['bankName']),
    accountName: asText(j['accountName']),
    accountNumber: asText(j['accountNumber']),
    currency: asText(j['currency']),
    instructions: asText(j['instructions']),
  );

  /// Copying beats retyping a ten digit number into a banking app.
  Future<void> copy() => Clipboard.setData(ClipboardData(text: accountNumber));
}

/// Which ways to pay this build may offer, decided by the BACKEND.
///
/// A "Buy on Google Play" button that cannot complete a purchase is worse
/// than no button: the student taps it, nothing happens, and they conclude
/// the app is broken rather than that a key is missing. So a store counts as
/// available only when its credentials AND its product id are saved in
/// Admin → Settings, and the app renders exactly what it is told.
class PayWays {
  const PayWays({
    required this.card,
    required this.transfer,
    required this.key,
    required this.play,
    required this.appStore,
    required this.playProduct,
    required this.appStoreProduct,
  });

  final bool card;
  final bool transfer;
  final bool key;
  final bool play;
  final bool appStore;
  final String playProduct;
  final String appStoreProduct;

  static const none = PayWays(
    card: true,
    transfer: false,
    key: true,
    play: false,
    appStore: false,
    playProduct: '',
    appStoreProduct: '',
  );

  static PayWays from(Object? methods, Object? products) {
    final m = methods is Map ? methods : const {};
    final p = products is Map ? products : const {};
    return PayWays(
      card: m['card'] != false,
      transfer: m['transfer'] == true,
      key: m['key'] != false,
      play: m['play'] == true,
      appStore: m['appstore'] == true,
      playProduct: asText(p['play']),
      appStoreProduct: asText(p['appstore']),
    );
  }
}

class ActivationOffer {
  const ActivationOffer({
    required this.activated,
    required this.productKey,
    required this.amount,
    required this.currency,
    required this.note,
    required this.accounts,
    required this.ways,
  });

  final bool activated;
  final String productKey;

  /// Null when this student's country has no price row. The screen says so
  /// rather than inventing a number.
  final num? amount;
  final String currency;
  final String note;
  final List<BankAccount> accounts;
  final PayWays ways;

  bool get hasPrice => amount != null;

  /// ₦5,000 · GH₵ 120 — grouped, with the symbol the currency actually uses.
  String get priceLabel {
    if (amount == null) return '';
    final whole = amount!.round().toString();
    final grouped = whole.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );
    const symbols = {
      'NGN': '₦',
      'GHS': 'GH₵',
      'USD': '\$',
      'GBP': '£',
      'EUR': '€',
    };
    final s = symbols[currency.toUpperCase()];
    return s != null ? '$s$grouped' : '$currency $grouped';
  }

  static ActivationOffer from(Map<String, dynamic> j) {
    final price = j['price'];
    return ActivationOffer(
      activated: j['activated'] == true,
      productKey: asText(j['productKey']),
      amount: asDoubleOrNull(asMapOrNull(price)?['amount']),
      currency: price is Map ? (asText(price['currency'])) : '',
      note: price is Map ? (asText(price['note'])) : '',
      accounts: (asList(j['accounts']))
          .whereType<Map>()
          .map((m) => BankAccount.from(m.cast<String, dynamic>()))
          .toList(),
      ways: PayWays.from(j['methods'], j['products']),
    );
  }
}

final activationOfferProvider = FutureProvider<ActivationOffer>((ref) async {
  final res = await ref.read(apiProvider).get('/api/mobile/activation');
  return ActivationOffer.from(res);
});

/// Redeem a key the student already holds. The server decides; this only asks.
///
/// Takes the Api rather than a ref, so the caller resolves it BEFORE the
/// await. Reading a provider off a widget's ref after an async gap is how a
/// disposed screen reaches into a torn-down container.
Future<String> redeemKey(Api api, String code) async {
  final res = await api.post('/api/activate/key', body: {'code': code.trim()});
  return (asTextOrNull(res['message'])) ??
      (res['ok'] == true ? 'Activated!' : 'That key did not work.');
}

/// ===========================================================================
/// PAYING WITHOUT LEAVING THE APP.
///
/// Uploading a transfer receipt used to mean opening the browser and signing
/// in again to send a screenshot the phone already had — three steps and a
/// second login for the payment path most Nigerian students actually use.
///
/// Two requests, in order, exactly as the website does it:
///   1. the image to /api/upload-proof, which returns the stored path;
///   2. that path to /api/activate/transfer, which files the claim.
///
/// The order matters: the transfer route REFUSES a proof it did not store
/// itself, matched against this student's own id, so a crafted request cannot
/// plant a link in the admin review queue.
/// ===========================================================================
Future<String> sendTransferProof(
  Api api, {
  required String imagePath,
  String note = '',
}) async {
  final up = await api.upload(
    '/api/upload-proof',
    filePath: imagePath,
    fieldName: 'file',
  );
  final stored = asText(up['url']);
  if (stored.isEmpty) {
    throw ApiFailure(
      'The screenshot uploaded but the server did not say where it went. '
      'Try again in a moment.',
    );
  }
  final claim = await api.post(
    '/api/activate/transfer',
    body: {'proof_path': stored, 'note': note},
  );
  return asTextOrNull(claim['message']) ??
      'Noted. An admin will confirm your transfer and activate you.';
}

/// Hands a store receipt to the backend, which is the only thing that decides
/// whether it means anything — the app never grants itself access.
Future<String> redeemStorePurchase(
  Api api, {
  required String store,
  required String productId,
  required String token,
}) async {
  final res = await api.post(
    '/api/mobile/store-purchase',
    body: {'store': store, 'productId': productId, 'token': token},
  );
  return asText(res['message'], 'You are activated. Welcome in.');
}
