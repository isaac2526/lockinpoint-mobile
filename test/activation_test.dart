import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/features/activation/activation_repository.dart';

/// ===========================================================================
/// ACTIVATION: THE PRICE IS NEVER WRITTEN IN DART
///
/// THE PROMISE THIS FILE DEFENDS:
///
///   ₦5,000 does not appear in the app. Not as a constant, not as a default,
///   not as a fallback when the server is quiet. Whatever `country_prices`
///   says is what a student is asked for, and a country with no row is a
///   VISIBLE GAP rather than a plausible wrong number.
///
/// The second promise is smaller and just as easy to break: never invite a
/// student to send money to an account that is not on the screen.
/// ===========================================================================
void main() {
  group('the offer comes from the server, whole', () {
    test('a naira price is grouped and given its symbol', () {
      final o = ActivationOffer.from({
        'activated': false,
        'price': {'amount': 5000, 'currency': 'NGN', 'note': ''},
        'accounts': [],
      });
      expect(o.priceLabel, '₦5,000');
    });

    test('a different currency is shown in ITS currency, not converted', () {
      final o = ActivationOffer.from({
        'price': {'amount': 120, 'currency': 'GHS'},
        'accounts': [],
      });
      expect(o.priceLabel, 'GH₵120');
    });

    test('a price the admin changes is simply the new price', () {
      // The whole point: no constant anywhere had to be edited for this.
      final o = ActivationOffer.from({
        'price': {'amount': 7500, 'currency': 'NGN'},
      });
      expect(o.priceLabel, '₦7,500');
    });

    test('a currency nobody has a symbol for still reads correctly', () {
      final o = ActivationOffer.from({
        'price': {'amount': 4200, 'currency': 'XOF'},
      });
      expect(o.priceLabel, 'XOF 4,200');
    });

    test('no price row means NO PRICE — not a guess', () {
      final o = ActivationOffer.from({'activated': false, 'accounts': []});
      expect(o.hasPrice, isFalse);
      expect(o.amount, isNull);
      expect(o.priceLabel, '');
    });

    test('a millions-sized figure still groups every three digits', () {
      final o = ActivationOffer.from({
        'price': {'amount': 1250000, 'currency': 'NGN'},
      });
      expect(o.priceLabel, '₦1,250,000');
    });

    test('under a thousand takes no separator', () {
      final o = ActivationOffer.from({
        'price': {'amount': 900, 'currency': 'NGN'},
      });
      expect(o.priceLabel, '₦900');
    });
  });

  group('bank accounts are a list the admin owns', () {
    test('every account the server sends is kept, in order', () {
      final o = ActivationOffer.from({
        'accounts': [
          {
            'id': 'a',
            'bankName': 'Moniepoint',
            'accountName': 'LockInPoint Ltd',
            'accountNumber': '8012345678',
            'currency': 'NGN',
            'instructions': 'Use your username as the narration',
          },
          {
            'id': 'b',
            'bankName': 'GTBank',
            'accountName': 'LockInPoint Ltd',
            'accountNumber': '0123456789',
            'currency': 'NGN',
            'instructions': '',
          },
        ],
      });
      expect(o.accounts.length, 2);
      expect(o.accounts.first.bankName, 'Moniepoint');
      expect(o.accounts.first.instructions, contains('narration'));
      expect(o.accounts.last.accountNumber, '0123456789');
    });

    test('no accounts means the screen has nothing to promise', () {
      // The website used to say "send the exact amount to our account" with
      // no account under it. The app must never inherit that.
      final o = ActivationOffer.from({'accounts': []});
      expect(o.accounts, isEmpty);
    });

    test('a malformed row does not take the whole list down', () {
      final o = ActivationOffer.from({
        'accounts': [
          {'id': 'a'},
          {'id': 'b', 'accountNumber': '0123456789'},
        ],
      });
      expect(o.accounts.length, 2);
      expect(o.accounts.first.accountNumber, '');
    });
  });

  group('an activated student is told so', () {
    test('activation and the product key survive the parse', () {
      final o = ActivationOffer.from({
        'activated': true,
        'productKey': 'LIP-7K2M-9QRT',
      });
      expect(o.activated, isTrue);
      expect(o.productKey, 'LIP-7K2M-9QRT');
    });

    test('a missing product key is empty, never the string "null"', () {
      final o = ActivationOffer.from({'activated': true});
      expect(o.productKey, '');
    });
  });
}
