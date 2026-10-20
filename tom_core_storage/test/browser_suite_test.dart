/// Runs the browser-only tests, so that they run at all.
///
/// `test/browser/` carries `@TestOn('browser')` files. An ordinary `dart test`
/// **skips** them silently — which would make the IndexedDB medium a
/// durability guarantee that nothing checks. So the package's own suite drives
/// them on Chrome and fails if they do not pass. The cost is one Chrome compile
/// per suite run, the price of the only place the browser medium is executed.
@Timeout(Duration(minutes: 10))
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  // Every skip names what would make it run.
  String? skipReason() {
    if (Platform.environment['TOM_SKIP_BROWSER_TESTS'] == '1') {
      return 'TOM_SKIP_BROWSER_TESTS=1 is set; unset it to exercise '
          'IndexedDB in a real browser';
    }
    final dart = Platform.resolvedExecutable;
    if (!(dart.endsWith('dart') || dart.endsWith('dart.exe'))) {
      return 'not run under `dart test`, so there is no Dart CLI to start '
          'the browser run with';
    }
    return null;
  }

  test('STORAGE-BROWSER-1: test/browser passes on Chrome', () async {
    final result = await Process.run(Platform.resolvedExecutable, const [
      'test',
      '-p',
      'chrome',
      'test/browser',
    ]);
    expect(
      result.exitCode,
      0,
      reason:
          'the browser-only suite failed. It is the only place the '
          'IndexedDB medium is executed rather than compiled:\n'
          '${result.stdout}\n${result.stderr}',
    );
  }, skip: skipReason());
}
