import '../../core/json.dart';

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/api.dart';
import 'activation_repository.dart';

/// ===========================================================================
/// BUYING THROUGH GOOGLE PLAY OR THE APP STORE.
///
/// Both stores require in-app purchase for digital goods on their platforms,
/// so this path is not optional if the app is to stay listed.
///
/// THE APP NEVER GRANTS ITSELF ACCESS. The store hands back a purchase token;
/// that token goes to /api/mobile/store-purchase, which asks Google or Apple
/// directly whether it is real and only then sets `activated`. A client that
/// decided its own entitlement would be defeated by anyone willing to install
/// a patched build, and the same activation has to hold on the website — where
/// there is no store to ask.
///
/// EVERY PURCHASE IS COMPLETED, including ones the backend refuses. An
/// unacknowledged Play purchase is automatically REFUNDED after three days and
/// the student loses what they paid for; a refusal we cannot verify is a
/// support conversation, not a reason to leave money in limbo.
/// ===========================================================================
class StorePurchase {
  StorePurchase(this._api);

  final Api _api;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// True only where a store actually exists. Desktop and web have none, and
  /// the plugin throws rather than returning false there.
  static bool get platformHasStore =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static String get storeName =>
      !kIsWeb && Platform.isIOS ? 'appstore' : 'play';

  /// Starts listening before any purchase is made. The stream also delivers
  /// purchases that completed while the app was closed — a student who paid
  /// and then lost signal is activated the next time they open it, without
  /// having to do anything.
  void listen({
    required void Function(String message) onDone,
    required void Function(String message) onProblem,
  }) {
    if (!platformHasStore) return;
    _sub ??= InAppPurchase.instance.purchaseStream.listen(
      (list) async {
        for (final p in list) {
          switch (p.status) {
            case PurchaseStatus.pending:
              break;
            case PurchaseStatus.canceled:
              if (p.pendingCompletePurchase) {
                await InAppPurchase.instance.completePurchase(p);
              }
            case PurchaseStatus.error:
              onProblem(
                p.error?.message ?? 'The store could not complete that.',
              );
              if (p.pendingCompletePurchase) {
                await InAppPurchase.instance.completePurchase(p);
              }
            case PurchaseStatus.purchased:
            case PurchaseStatus.restored:
              try {
                final msg = await redeemStorePurchase(
                  _api,
                  store: storeName,
                  productId: p.productID,
                  token: p.verificationData.serverVerificationData,
                );
                onDone(msg);
              } on ApiFailure catch (e) {
                onProblem(e.message);
              } finally {
                /* ALWAYS acknowledged, even when the backend refused it. An
                   unacknowledged Play purchase is refunded automatically after
                   three days, and a student who paid would silently lose both
                   the money and the access while support was still looking. */
                if (p.pendingCompletePurchase) {
                  await InAppPurchase.instance.completePurchase(p);
                }
              }
          }
        }
      },
      onError: (Object e) =>
          onProblem(humanError(e, doing: 'complete that purchase')),
    );
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// Asks the store to sell one activation. Returns a sentence when it cannot
  /// even begin — an unavailable store, or a product id the store has never
  /// heard of, which is what happens when Admin → Settings names one that was
  /// never created in the console.
  Future<String?> buy(String productId) async {
    if (!platformHasStore) return 'There is no app store on this device.';
    if (productId.isEmpty) return 'No store product has been set up yet.';

    if (!await InAppPurchase.instance.isAvailable()) {
      return 'The store is not available on this device right now.';
    }
    final found = await InAppPurchase.instance.queryProductDetails({productId});
    if (found.notFoundIDs.isNotEmpty || found.productDetails.isEmpty) {
      /* Named plainly rather than as "purchase failed": this is nearly always
         a product that exists in Admin → Settings and not in the store
         console, and saying which one turns a mystery into a five-minute fix. */
      return 'The store does not know the product "$productId". '
          'It has to be created in the store console first.';
    }
    /* A NON-CONSUMABLE: activation is bought once and belongs to the account
       for ever. Sold as a consumable, Play would let the same student buy it
       repeatedly and would not restore it on a new phone. */
    await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: found.productDetails.first),
    );
    return null;
  }

  /// Re-delivers anything already bought on this account — a new phone, a
  /// reinstall, or a purchase that completed while the app was closed.
  Future<void> restore() async {
    if (!platformHasStore) return;
    await InAppPurchase.instance.restorePurchases();
  }
}
