import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ===========================================================================
/// ONE SETUP FOR THE WHOLE SUITE. flutter_test loads this file automatically
/// before any test in this directory runs.
///
/// SharedPreferences.getInstance() NEVER COMPLETES in the test binding unless
/// mock values are set — not "throws", not "returns empty": it hangs, and
/// every widget test that touches it dies on `pumpAndSettle timed out` with
/// nothing on screen to say why. Two hours of Pointgram tests were spent
/// learning that.
///
/// Giving every test an empty store means a test that wants remembered state
/// sets it explicitly, which is what the two tests that already call
/// setMockInitialValues do — calling it again in a test simply replaces this.
/// ===========================================================================
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  await testMain();
}
