/// The scan screen, driven through the contract's test double: it starts and
/// stops the camera, lists what is read, asks only for QR codes when told to,
/// and says why it cannot scan.
library;

import 'package:core_flutter_code_scanner_sample/scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

void main() {
  late TomFakeCodeScanner scanner;

  setUp(() => scanner = TomFakeCodeScanner());

  Future<void> show(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: ScanScreen(scanner: scanner)));
    await tester.pumpAndSettle();
  }

  testWidgets('scans, lists what it reads, and stops', (tester) async {
    await show(tester);
    expect(find.text('The camera is ready.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('toggleScan')));
    await tester.pump();
    expect(scanner.listening, isTrue);
    expect(scanner.lastFormats, {TomCodeFormat.qrCode});
    expect(
      find.byKey(const ValueKey('tom-fake-code-scanner-preview')),
      findsOneWidget,
    );

    scanner.emit('https://example.com/item/7');
    // Not delivered: the screen asked for QR codes only.
    scanner.emit('4006381333931', format: TomCodeFormat.ean13);
    await tester.pump();
    expect(find.text('https://example.com/item/7'), findsOneWidget);
    expect(find.text('4006381333931'), findsNothing);

    await tester.tap(find.byKey(const Key('toggleScan')));
    await tester.pumpAndSettle();
    expect(scanner.listening, isFalse);
    expect(
      find.byKey(const ValueKey('tom-fake-code-scanner-preview')),
      findsNothing,
    );
  });

  testWidgets('with every format, reads what the camera sees', (tester) async {
    await show(tester);
    await tester.tap(find.byKey(const Key('qrOnly')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('toggleScan')));
    await tester.pump();
    expect(scanner.lastFormats, isEmpty);
    scanner.emit('4006381333931', format: TomCodeFormat.ean13);
    await tester.pump();
    expect(find.text('4006381333931'), findsOneWidget);
    expect(find.text('ean13'), findsOneWidget);
  });

  testWidgets('says why a scan could not start', (tester) async {
    scanner.fail('permission_denied');
    await show(tester);
    await tester.tap(find.byKey(const Key('toggleScan')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scanError')), findsOneWidget);
    expect(scanner.listening, isFalse);
  });

  testWidgets('offers no scan where none can run', (tester) async {
    scanner.availabilityValue = TomCodeScannerAvailability.noCamera;
    await show(tester);
    expect(find.text('This device has no camera.'), findsOneWidget);
    final button = tester.widget<ButtonStyleButton>(
      find.byKey(const Key('toggleScan')),
    );
    expect(button.onPressed, isNull);
  });
}
