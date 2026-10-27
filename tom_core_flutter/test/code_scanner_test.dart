/// The code-scanner contract, driven through its test double: a scan's
/// lifecycle (the camera runs while it is listened to), the formats it asks
/// for, scanOnce's three endings, errors that say why nothing can be scanned,
/// and installing a scanner — and the module's scanner example, run as the
/// executable documentation it is quoted as.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

import '../example/security/code_scanner_example.dart' as example;

void main() {
  late TomFakeCodeScanner scanner;

  setUp(() => scanner = TomFakeCodeScanner());
  tearDown(TomBean.resetBeanContext);

  group('a scan', () {
    test(
      'runs while it is listened to, and reads what the camera sees',
      () async {
        final codes = <TomScannedCode>[];
        expect(scanner.listening, isFalse);
        final subscription = scanner.scan().listen(codes.add);
        await pumpEventQueue();
        expect(scanner.listening, isTrue);
        expect(scanner.emit('otpauth://totp/Tom:ada?secret=ABC'), isTrue);
        expect(
          scanner.emit('4006381333931', format: TomCodeFormat.ean13),
          isTrue,
        );
        await pumpEventQueue();
        expect(codes.map((c) => c.payload), [
          'otpauth://totp/Tom:ada?secret=ABC',
          '4006381333931',
        ]);
        expect(codes.last.format, TomCodeFormat.ean13);
        await subscription.cancel();
        expect(scanner.listening, isFalse, reason: 'cancelling releases it');
        expect(scanner.emit('late'), isFalse);
      },
    );

    test('reads only the formats it asks for', () async {
      final codes = <TomScannedCode>[];
      final subscription = scanner
          .scan(formats: {TomCodeFormat.qrCode})
          .listen(codes.add);
      await pumpEventQueue();
      expect(scanner.lastFormats, {TomCodeFormat.qrCode});
      scanner
        ..emit('9780201633610', format: TomCodeFormat.ean13)
        ..emit('https://example.com/item/7');
      await pumpEventQueue();
      expect(codes.single.payload, 'https://example.com/item/7');
      await subscription.cancel();
    });

    test('that cannot start says why, rather than staying empty', () async {
      scanner.fail('permission_denied');
      await expectLater(
        scanner.scan(),
        emitsError(
          isA<TomCodeScannerException>().having(
            (e) => e.key,
            'key',
            'code_scanner.permission_denied',
          ),
        ),
      );
      await scanner.dispose();
      await expectLater(
        scanner.scan(),
        emitsError(
          isA<TomCodeScannerException>().having(
            (e) => e.key,
            'key',
            'code_scanner.disposed',
          ),
        ),
      );
    });

    test('availability is the scanner\'s answer', () async {
      expect(
        await scanner.availability(),
        TomCodeScannerAvailability.available,
      );
      scanner.availabilityValue = TomCodeScannerAvailability.noCamera;
      expect(await scanner.availability(), TomCodeScannerAvailability.noCamera);
    });
  });

  group('scanOnce', () {
    test('answers the first code it accepts and releases the camera', () async {
      final found = scanner.scanOnce(
        accept: (code) => code.payload.startsWith('otpauth://'),
      );
      await pumpEventQueue();
      scanner
        ..emit('https://example.com')
        ..emit('otpauth://totp/Tom:ada?secret=ABC');
      expect((await found)!.payload, 'otpauth://totp/Tom:ada?secret=ABC');
      expect(scanner.listening, isFalse);
    });

    test(
      'answers null when the time runs out, and releases the camera',
      () async {
        final found = scanner.scanOnce(
          timeout: const Duration(milliseconds: 100),
        );
        await pumpEventQueue();
        expect(scanner.listening, isTrue);
        expect(await found, isNull);
        expect(scanner.listening, isFalse);
      },
    );

    test('passes on why it could not scan', () async {
      scanner.fail('no_camera');
      await expectLater(
        scanner.scanOnce(),
        throwsA(
          isA<TomCodeScannerException>().having(
            (e) => e.key,
            'key',
            'code_scanner.no_camera',
          ),
        ),
      );
      expect(scanner.listening, isFalse);
    });
  });

  test('an installed scanner is the one code asks for', () {
    expect(TomCodeScanner.resolve(), isNull);
    TomCodeScanner.install(scanner);
    expect(TomCodeScanner.resolve(), same(scanner));
    final other = TomFakeCodeScanner();
    TomCodeScanner.install(other);
    expect(TomCodeScanner.resolve(), same(other));
  });

  test('code_scanner_example.run() completes its assertions', () async {
    await example.run();
  });

  testWidgets('the preview is a widget the screen places', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(builder: scanner.preview),
      ),
    );
    expect(
      find.byKey(const ValueKey('tom-fake-code-scanner-preview')),
      findsOneWidget,
    );
  });
}
