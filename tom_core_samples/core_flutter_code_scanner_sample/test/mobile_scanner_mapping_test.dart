/// The adapter's translation between the plugin and the contract: formats both
/// ways, a decoded barcode to a scanned code, plugin errors to the contract's
/// keys. Pure functions, so they are tested without a camera.
library;

import 'dart:typed_data';

import 'package:core_flutter_code_scanner_sample/mobile_scanner_code_scanner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

void main() {
  test('every contract format maps to a plugin format and back', () {
    for (final format in TomCodeFormat.values) {
      final plugin = barcodeFormatOf(format);
      if (format == TomCodeFormat.other) {
        expect(plugin, isNull);
      } else {
        expect(tomFormatOf(plugin!), format, reason: format.name);
      }
    }
    expect(tomFormatOf(BarcodeFormat.microQrCode), TomCodeFormat.qrCode);
    expect(tomFormatOf(BarcodeFormat.codabar), TomCodeFormat.other);
  });

  test('a scan of no formats, or of "other", asks the decoder for all', () {
    expect(barcodeFormatsFor(const {}), isEmpty);
    expect(
      barcodeFormatsFor({TomCodeFormat.qrCode, TomCodeFormat.other}),
      isEmpty,
    );
    expect(
      barcodeFormatsFor({TomCodeFormat.qrCode, TomCodeFormat.ean13}).toSet(),
      {BarcodeFormat.qrCode, BarcodeFormat.ean13},
    );
  });

  test('a decoded barcode becomes a scanned code, an empty one nothing', () {
    final at = DateTime.utc(2026, 10, 27, 12);
    final code = scannedCodeOf(
      Barcode(
        rawValue: 'otpauth://totp/Tom:ada?secret=ABC',
        format: BarcodeFormat.qrCode,
        rawDecodedBytes: DecodedBarcodeBytes(
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
      ),
      at: at,
    )!;
    expect(code.payload, 'otpauth://totp/Tom:ada?secret=ABC');
    expect(code.format, TomCodeFormat.qrCode);
    expect(code.bytes, [1, 2, 3]);
    expect(code.scannedAt, at);
    expect(
      scannedCodeOf(
        const Barcode(
          displayValue: '4006381333931',
          format: BarcodeFormat.ean13,
        ),
      )!.payload,
      '4006381333931',
    );
    expect(scannedCodeOf(const Barcode()), isNull);
  });

  test('plugin errors become the contract\'s keys', () {
    expect(
      scannerErrorKeyOf(MobileScannerErrorCode.permissionDenied),
      'code_scanner.permission_denied',
    );
    expect(
      scannerErrorKeyOf(MobileScannerErrorCode.unsupported),
      'code_scanner.unsupported',
    );
    expect(
      scannerErrorKeyOf(MobileScannerErrorCode.genericError),
      'code_scanner.failed',
    );
    expect(
      scannerErrorKeyOf(MobileScannerErrorCode.controllerDisposed),
      'code_scanner.disposed',
    );
  });

  test(
    'a disposed adapter refuses a scan before it touches the camera',
    () async {
      final scanner = MobileScannerCodeScanner();
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
    },
  );
}
