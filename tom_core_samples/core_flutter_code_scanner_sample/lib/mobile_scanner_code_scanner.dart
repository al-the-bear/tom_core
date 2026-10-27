/// The adapter: tom_core_flutter's [TomCodeScanner] over the `mobile_scanner`
/// camera plugin.
///
/// This file is the whole of the plugin's reach into the application. The
/// screens scan through [TomCodeScanner] and know nothing of `mobile_scanner`;
/// swapping the plugin for another means rewriting this file and nothing else.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

/// The plugin's format for [format] — `null` for [TomCodeFormat.other], which
/// names no single symbology to ask the decoder for.
BarcodeFormat? barcodeFormatOf(TomCodeFormat format) => switch (format) {
  TomCodeFormat.qrCode => BarcodeFormat.qrCode,
  TomCodeFormat.dataMatrix => BarcodeFormat.dataMatrix,
  TomCodeFormat.aztec => BarcodeFormat.aztec,
  TomCodeFormat.pdf417 => BarcodeFormat.pdf417,
  TomCodeFormat.code128 => BarcodeFormat.code128,
  TomCodeFormat.code39 => BarcodeFormat.code39,
  TomCodeFormat.ean13 => BarcodeFormat.ean13,
  TomCodeFormat.ean8 => BarcodeFormat.ean8,
  TomCodeFormat.upcA => BarcodeFormat.upcA,
  TomCodeFormat.other => null,
};

/// The contract's format for what the plugin decoded.
TomCodeFormat tomFormatOf(BarcodeFormat format) => switch (format) {
  BarcodeFormat.qrCode || BarcodeFormat.microQrCode => TomCodeFormat.qrCode,
  BarcodeFormat.dataMatrix => TomCodeFormat.dataMatrix,
  BarcodeFormat.aztec => TomCodeFormat.aztec,
  BarcodeFormat.pdf417 => TomCodeFormat.pdf417,
  BarcodeFormat.code128 => TomCodeFormat.code128,
  BarcodeFormat.code39 => TomCodeFormat.code39,
  BarcodeFormat.ean13 => TomCodeFormat.ean13,
  BarcodeFormat.ean8 => TomCodeFormat.ean8,
  BarcodeFormat.upcA => TomCodeFormat.upcA,
  _ => TomCodeFormat.other,
};

/// The plugin's formats for a scan of [formats]: every format when empty, or
/// when [TomCodeFormat.other] asks for "anything else" too.
List<BarcodeFormat> barcodeFormatsFor(Set<TomCodeFormat> formats) {
  if (formats.isEmpty || formats.contains(TomCodeFormat.other)) {
    return const [];
  }
  return [for (final format in formats) barcodeFormatOf(format)!];
}

/// [barcode] as the contract's code, or `null` when it carries nothing to
/// report (no text and no bytes).
TomScannedCode? scannedCodeOf(Barcode barcode, {DateTime? at}) {
  final bytes = switch (barcode.rawDecodedBytes) {
    DecodedBarcodeBytes(:final bytes) => bytes,
    DecodedVisionBarcodeBytes(:final bytes, :final rawBytes) =>
      bytes ?? rawBytes,
    null => null,
  };
  final text = barcode.rawValue ?? barcode.displayValue;
  if ((text == null || text.isEmpty) && (bytes == null || bytes.isEmpty)) {
    return null;
  }
  return TomScannedCode(
    payload: text ?? '',
    format: tomFormatOf(barcode.format),
    bytes: bytes,
    scannedAt: at,
  );
}

/// The `code_scanner.*` key for a plugin error.
String scannerErrorKeyOf(MobileScannerErrorCode code) => switch (code) {
  MobileScannerErrorCode.permissionDenied => 'code_scanner.permission_denied',
  MobileScannerErrorCode.unsupported => 'code_scanner.unsupported',
  MobileScannerErrorCode.controllerDisposed => 'code_scanner.disposed',
  _ => 'code_scanner.failed',
};

/// [TomCodeScanner] over `mobile_scanner`.
///
/// Each [scan] starts a camera controller of its own and stops and disposes
/// it when the scan's subscription is cancelled. The plugin reports a code
/// once while it stays in view (`DetectionSpeed.noDuplicates`), which is what
/// the contract asks for.
///
/// The plugin cannot be asked whether a permission was granted without
/// starting the camera, so [availability] answers from the platform: the
/// platforms the plugin supports are `permissionNotRequested` until a scan
/// started, then what that scan found; the others are `unsupported`.
class MobileScannerCodeScanner extends TomCodeScanner {
  MobileScannerController? _controller;
  TomCodeScannerAvailability? _found;
  bool _disposed = false;

  /// Creates the adapter.
  MobileScannerCodeScanner();

  /// Whether the plugin can scan on this platform.
  static bool get platformSupported =>
      kIsWeb ||
      switch (defaultTargetPlatform) {
        TargetPlatform.android ||
        TargetPlatform.iOS ||
        TargetPlatform.macOS => true,
        _ => false,
      };

  @override
  Future<TomCodeScannerAvailability> availability() async {
    if (!platformSupported) return TomCodeScannerAvailability.unsupported;
    return _found ?? TomCodeScannerAvailability.permissionNotRequested;
  }

  @override
  Stream<TomScannedCode> scan({Set<TomCodeFormat> formats = const {}}) {
    if (_disposed) {
      return Stream.error(
        TomCodeScannerException(
          'code_scanner.disposed',
          'The scanner has been disposed.',
        ),
      );
    }
    StreamSubscription<BarcodeCapture>? captures;
    late final StreamController<TomScannedCode> out;
    out = StreamController<TomScannedCode>(
      onListen: () async {
        final controller = MobileScannerController(
          autoStart: false,
          detectionSpeed: DetectionSpeed.noDuplicates,
          formats: barcodeFormatsFor(formats),
        );
        _controller = controller;
        captures = controller.barcodes.listen((capture) {
          for (final barcode in capture.barcodes) {
            final code = scannedCodeOf(barcode);
            if (code != null) out.add(code);
          }
        });
        try {
          await controller.start();
          _found = TomCodeScannerAvailability.available;
        } on MobileScannerException catch (error, stack) {
          if (error.errorCode == MobileScannerErrorCode.permissionDenied) {
            _found = TomCodeScannerAvailability.permissionDenied;
          } else if (error.errorCode == MobileScannerErrorCode.unsupported) {
            _found = TomCodeScannerAvailability.unsupported;
          }
          out.addError(
            TomCodeScannerException(
              scannerErrorKeyOf(error.errorCode),
              'The camera could not start (${error.errorCode.name}).',
              rootException: error,
              stack: stack,
            ),
            stack,
          );
        }
      },
      onCancel: () async {
        await captures?.cancel();
        final controller = _controller;
        _controller = null;
        await controller?.dispose();
      },
    );
    return out.stream;
  }

  @override
  Widget preview(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const SizedBox.expand();
    return MobileScanner(controller: controller);
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }
}
