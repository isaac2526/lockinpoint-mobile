import 'package:integration_test/integration_test_driver.dart';

/// ===========================================================================
/// THE DRIVER, SO THE CHECKS CAN RUN ON A RELEASE-COMPILED BINARY.
///
/// `flutter test integration_test/…` always builds DEBUG: assertions on, JIT,
/// nothing tree-shaken. The founder installs a release build, and the two
/// differ in ways that matter — an assertion that fires in debug is skipped in
/// release, so a debug-only run can both invent failures and hide them.
///
/// `flutter drive --profile` uses the RELEASE compiler (AOT, no assertions,
/// tree-shaken) and keeps the VM service the harness needs to attach. That is
/// the closest a driven test can get to the artifact a student installs;
/// `--release` strips that service entirely, so nothing can drive it.
/// ===========================================================================
Future<void> main() => integrationDriver();
