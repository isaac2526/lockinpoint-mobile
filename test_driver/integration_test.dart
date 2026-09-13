import 'package:integration_test/integration_test_driver.dart';

/// ===========================================================================
/// THE THREE LINES WITHOUT WHICH NO INTEGRATION TEST RUNS AT ALL.
///
/// `flutter drive --driver=test_driver/integration_test.dart --target=…` needs
/// a driver file, and this repository never had one. So both journey jobs in
/// `check` — the offline vault run and the acceptance drive — died in under a
/// second with
///
///     Test file not found: test_driver/integration_test.dart
///
/// on every push, while the unit job beside them passed. Two real tests in
/// integration_test/ have therefore never executed in CI: the vault run that
/// sits a paper with the network off, and the walk that taps every row of the
/// menu. A red job that is red for a missing file teaches everybody to ignore
/// the red.
///
/// It is deliberately empty of logic. integrationDriver() is the standard
/// shim: it waits for the app under test to report, collects the result and
/// exits with it. Anything clever in here would be running on the host rather
/// than on the device, which is the opposite of what these tests are for.
/// ===========================================================================
Future<void> main() => integrationDriver();
