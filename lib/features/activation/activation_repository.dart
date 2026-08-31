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
    id: j['id'] as String? ?? '',
    bankName: j['bankName'] as String? ?? '',
    accountName: j['accountName'] as String? ?? '',
    accountNumber: j['accountNumber'] as String? ?? '',
    currency: j['currency'] as String? ?? '',
    instructions: j['instructions'] as String? ?? '',
  );

  /// Copying beats retyping a ten digit number into a banking app.
  Future<void> copy() => Clipboard.setData(ClipboardData(text: accountNumber));
}

class ActivationOffer {
  const ActivationOffer({
    required this.activated,
    required this.productKey,
    required this.amount,
    required this.currency,
    required this.note,
    required this.accounts,
  });

  final bool activated;
  final String productKey;

  /// Null when this student's country has no price row. The screen says so
  /// rather than inventing a number.
  final num? amount;
  final String currency;
  final String note;
  final List<BankAccount> accounts;

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
      productKey: j['productKey'] as String? ?? '',
      amount: price is Map ? price['amount'] as num? : null,
      currency: price is Map ? (price['currency'] as String? ?? '') : '',
      note: price is Map ? (price['note'] as String? ?? '') : '',
      accounts: ((j['accounts'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => BankAccount.from(m.cast<String, dynamic>()))
          .toList(),
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
  return (res['message'] as String?) ??
      (res['ok'] == true ? 'Activated!' : 'That key did not work.');
}
