/// Executable example for the code-scanner contract of `tom_core_flutter`'s
/// security module.
///
/// Scanning is written against [TomCodeScanner]; the camera plugin lives in
/// the application behind an adapter it writes (the
/// `core_flutter_code_scanner_sample` adapter over `mobile_scanner` is one).
/// This example runs on [TomFakeCodeScanner], the test double, and shows what
/// code above the adapter does: install a scanner, ask whether it can scan,
/// take the first code of a kind, give up after a while, and hear why a scan
/// could not start.
///
/// Run it with `flutter test test/code_scanner_test.dart`, which calls [run]
/// and fails when an assertion below does not hold.
library;

import 'package:tom_core_flutter/tom_core_flutter.dart';

Future<void> run() async {
  // Example 1: the application installs its scanner once, at start-up; code
  // that wants to scan asks for it.
  final fake = TomFakeCodeScanner();
  TomCodeScanner.install(fake);
  final scanner = TomCodeScanner.resolve()!;
  print('installed: ${scanner.runtimeType}');
  assert(identical(scanner, fake));

  // Example 2: ask before offering a scan button.
  final availability = await scanner.availability();
  print('availability: ${availability.name}');
  assert(availability == TomCodeScannerAvailability.available);

  // Example 3: the first enrolment code — other codes the camera sees are
  // passed over, and the camera is off again once the answer is in.
  final enrolment = scanner.scanOnce(
    formats: {TomCodeFormat.qrCode},
    accept: (code) => code.payload.startsWith('otpauth://'),
  );
  await Future<void>.delayed(Duration.zero);
  fake
    ..emit('https://example.com/menu')
    ..emit('otpauth://totp/Tom:ada?secret=JBSWY3DPEHPK3PXP');
  final code = await enrolment;
  print('scanned: ${code!.payload}');
  assert(code.payload.startsWith('otpauth://totp/'));
  assert(!fake.listening);

  // Example 4: a scan nobody completes answers null after its timeout.
  final nothing = await scanner.scanOnce(
    timeout: const Duration(milliseconds: 20),
  );
  print('after the timeout: $nothing');
  assert(nothing == null);

  // Example 5: a scan that cannot start says why.
  fake.fail('permission_denied');
  try {
    await scanner.scanOnce();
    assert(false, 'the scan should have failed');
  } on TomCodeScannerException catch (error) {
    print('refused: ${error.key}');
    assert(error.key == 'code_scanner.permission_denied');
  }

  await scanner.dispose();
  TomBean.resetBeanContext();
}

Future<void> main() => run();
