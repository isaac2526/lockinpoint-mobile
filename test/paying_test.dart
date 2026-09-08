import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/core/api.dart';
import 'package:lockinpoint/features/activation/activation_repository.dart';

/// ===========================================================================
/// PAYING · the two things that are silent when they go wrong.
///
///   1. WHICH BUTTONS EXIST is the server's decision, not the app's. A "Buy on
///      Google Play" button that cannot complete a purchase is worse than no
///      button: the student taps it, nothing happens, and they conclude the
///      app is broken rather than that a key is missing in Admin → Settings.
///
///   2. THE RECEIPT IS TWO REQUESTS IN ORDER. The image goes to
///      /api/upload-proof, which returns where it was stored; that path goes
///      to /api/activate/transfer, which REFUSES any proof it did not store
///      itself. Sending them out of order, or sending the local file path
///      instead of the stored one, fails in a way that reads as "your
///      screenshot was not recognised".
/// ===========================================================================

class _Server extends Fake implements Api {
  _Server({this.uploadAnswer, this.claimAnswer});
  final Map<String, dynamic>? uploadAnswer;
  final Map<String, dynamic>? claimAnswer;

  final List<String> order = [];
  Object? lastBody;

  @override
  Future<Map<String, dynamic>> upload(
    String path, {
    required String filePath,
    required String fieldName,
    Map<String, dynamic>? fields,
  }) async {
    order.add(path);
    expect(fieldName, 'file', reason: 'the route reads form.get("file")');
    return uploadAnswer ?? {'ok': true};
  }

  @override
  Future<Map<String, dynamic>> post(String path, {Object? body}) async {
    order.add(path);
    lastBody = body;
    return claimAnswer ?? {'ok': true};
  }
}

void main() {
  group('which ways to pay are offered', () {
    test('a store with keys but no product id is NOT offered', () {
      final w = PayWays.from(
        {'card': true, 'transfer': true, 'key': true, 'play': false},
        {'play': ''},
      );
      expect(w.play, isFalse);
      expect(w.transfer, isTrue);
    });

    test('a store the server calls ready is offered, with its product', () {
      final w = PayWays.from(
        {'play': true},
        {'play': 'lockinpoint_activation'},
      );
      expect(w.play, isTrue);
      expect(w.playProduct, 'lockinpoint_activation');
    });

    test('an older server that says nothing still offers card and key', () {
      // A build talking to a deployment from before `methods` existed must
      // not lose the two paths that have always worked.
      final w = PayWays.from(null, null);
      expect(w.card, isTrue);
      expect(w.key, isTrue);
      expect(w.transfer, isFalse);
      expect(w.play, isFalse);
    });

    test('the offer carries the ways through from the envelope', () {
      final o = ActivationOffer.from({
        'activated': false,
        'accounts': [],
        'methods': {'transfer': true, 'play': true},
        'products': {'play': 'p1'},
      });
      expect(o.ways.transfer, isTrue);
      expect(o.ways.playProduct, 'p1');
    });
  });

  group('sending a transfer receipt', () {
    test('uploads first, then files the claim with the STORED path', () async {
      final s = _Server(
        uploadAnswer: {
          'ok': true,
          'url':
              'https://x.supabase.co/storage/v1/object/public/media/'
              'proofs/user-1-999.jpg',
        },
        claimAnswer: {'ok': true, 'message': 'Noted!'},
      );
      final msg = await sendTransferProof(
        s,
        imagePath: '/phone/local/IMG_0001.jpg',
        note: 'sent at 10am',
      );

      expect(s.order, ['/api/upload-proof', '/api/activate/transfer']);
      final body = s.lastBody as Map;
      // The STORED url, never the local file path — the transfer route pins
      // bucket, folder and owner, and a local path fails all three.
      expect(body['proof_path'], contains('/media/proofs/user-1-'));
      expect(body['proof_path'], isNot(contains('IMG_0001')));
      expect(body['note'], 'sent at 10am');
      expect(msg, 'Noted!');
    });

    test('an upload that returns no url never files a claim', () async {
      final s = _Server(uploadAnswer: {'ok': true});
      await expectLater(
        sendTransferProof(s, imagePath: '/tmp/a.jpg'),
        throwsA(isA<ApiFailure>()),
      );
      // Crucially: the claim was NOT sent. Filing one with an empty proof
      // would be rejected by the server anyway, but the student would be told
      // their screenshot was not recognised rather than that it never landed.
      expect(s.order, ['/api/upload-proof']);
    });
  });

  test('a store receipt is handed over, never trusted locally', () async {
    final s = _Server(claimAnswer: {'ok': true, 'message': 'You are in.'});
    final msg = await redeemStorePurchase(
      s,
      store: 'play',
      productId: 'p1',
      token: 'purchase-token',
    );
    expect(s.order, ['/api/mobile/store-purchase']);
    final body = s.lastBody as Map;
    expect(body['store'], 'play');
    expect(body['token'], 'purchase-token');
    expect(msg, 'You are in.');
  });
}
