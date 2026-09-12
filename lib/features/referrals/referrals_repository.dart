import '../../core/json.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';

/// ===========================================================================
/// REFERRALS
///
/// /api/referrals has served this all along and the app has never asked. A
/// student sharing their code from the website and a student sharing it from
/// the app are now looking at the same balance, the same minimum and the same
/// list of requests.
///
/// EVERY FIGURE COMES FROM THE SERVER, in the student's own currency. There
/// is no naira amount written anywhere in this file: the reward, the minimum
/// and the balance are all rows an admin edits, converted server-side, so a
/// rate change reaches the phone on the next open rather than in the next
/// release.
/// ===========================================================================

class Money {
  const Money(this.currency, this.amount, this.label);
  final String currency;
  final num amount;
  final String label;

  static Money from(Object? m) {
    if (m is! Map) return const Money('', 0, '');
    return Money(
      asText(m['currency']),
      (m['amount'] as num?) ?? 0,
      asText(m['label']),
    );
  }
}

class Withdrawal {
  const Withdrawal({
    required this.amount,
    required this.currency,
    required this.status,
    required this.at,
  });
  final num amount;
  final String currency;
  final String status;
  final DateTime? at;
}

class Referrals {
  const Referrals({
    required this.code,
    required this.joined,
    required this.activated,
    required this.reward,
    required this.minimum,
    required this.balance,
    required this.earned,
    required this.canWithdraw,
    required this.withdrawals,
  });

  final String code;
  final int joined;
  final int activated;
  final Money reward;
  final Money minimum;
  final Money balance;
  final Money earned;

  /// Decided by the SERVER's own comparison of balance against minimum, so
  /// the button and the refusal can never disagree.
  final bool canWithdraw;
  final List<Withdrawal> withdrawals;

  Future<void> copyCode() => Clipboard.setData(ClipboardData(text: code));
}

final referralsProvider = FutureProvider<Referrals>((ref) async {
  final res = await ref.read(apiProvider).get('/api/referrals');
  final balanceNgn = (res['balanceNgn'] as num?) ?? 0;
  final minNgn = (res['minNgn'] as num?) ?? 0;
  return Referrals(
    code: asText(res['code']),
    joined: (asIntOrNull(res['joined'])) ?? 0,
    activated: (asIntOrNull(res['activated'])) ?? 0,
    reward: Money.from(res['reward']),
    minimum: Money.from(res['min']),
    balance: Money.from(res['balance']),
    earned: Money.from(res['earned']),
    canWithdraw: balanceNgn >= minNgn && minNgn > 0,
    withdrawals: ((res['withdrawals'] as List?) ?? const [])
        .whereType<Map>()
        .map(
          (w) => Withdrawal(
            amount:
                (w['amount_local'] as num?) ?? (w['amount_ngn'] as num?) ?? 0,
            currency: asText(w['currency'], 'NGN'),
            status: asText(w['status'], 'pending'),
            at: DateTime.tryParse('${w['created_at'] ?? ''}'),
          ),
        )
        .toList(),
  );
});

/// Asks for a payout. Returns the server's own sentence either way — it
/// checks the balance, the minimum and the account details, and a client that
/// second-guesses any of those will eventually disagree with it.
Future<String> requestPayout(
  Api api, {
  required String accountName,
  required String bankName,
  required String accountNumber,
}) async {
  try {
    final res = await api.post(
      '/api/referrals',
      body: {
        'account_name': accountName,
        'bank_name': bankName,
        'account_number': accountNumber,
      },
    );
    return asText(res['message'], 'Request received.');
  } on ApiFailure catch (e) {
    return e.message;
  }
}
