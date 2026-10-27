/// Reading codes with the device camera: the contract a Tom application
/// scans through, and a scripted stand-in for tests.
///
/// The framework holds the contract and never the camera plugin. Reading a
/// code needs a camera preview, a decoder over its frames and the platform
/// permissions both bring; an application that scans picks its plugin, keeps it
/// in its own layer, and implements [TomCodeScanner] over it — a few dozen
/// lines (the `core_flutter_code_scanner_sample` adapter over
/// `mobile_scanner` is one). Everything above the adapter — a screen that
/// scans an enrolment code, a test that drives one — is written against the
/// contract, and runs on [TomFakeCodeScanner] where there is no camera.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// The symbologies a scanner can be asked for.
///
/// The common two-dimensional and linear codes; a code the adapter's decoder
/// reports in a symbology outside this list arrives as [other].
enum TomCodeFormat {
  /// QR code.
  qrCode,

  /// Data Matrix.
  dataMatrix,

  /// Aztec.
  aztec,

  /// PDF417.
  pdf417,

  /// Code 128.
  code128,

  /// Code 39.
  code39,

  /// EAN-13.
  ean13,

  /// EAN-8.
  ean8,

  /// UPC-A.
  upcA,

  /// A symbology the scanner's decoder reported that is none of the above.
  other,
}

/// One decoded code.
class TomScannedCode {
  /// The decoded text; for a code that holds bytes no text represents, the
  /// adapter's best reading of them (often empty — see [bytes]).
  final String payload;

  /// The symbology it was read in.
  final TomCodeFormat format;

  /// The raw bytes, when the decoder reports them.
  final List<int>? bytes;

  /// When it was read.
  final DateTime scannedAt;

  /// Creates a scanned code.
  TomScannedCode({
    required this.payload,
    this.format = TomCodeFormat.qrCode,
    List<int>? bytes,
    DateTime? scannedAt,
  }) : bytes = bytes == null ? null : List.unmodifiable(bytes),
       scannedAt = scannedAt ?? DateTime.now();

  @override
  String toString() => 'TomScannedCode(${format.name}: $payload)';
}

/// Whether a scanner can read codes on this device, and if not, why.
enum TomCodeScannerAvailability {
  /// The camera can be used.
  available,

  /// The user has not been asked yet; scanning will ask.
  permissionNotRequested,

  /// The user refused the camera; the platform's settings are the way back.
  permissionDenied,

  /// The device has no camera.
  noCamera,

  /// The platform or the adapter cannot scan here (a desktop build of an
  /// adapter that only reads on mobile, say).
  unsupported,
}

/// Raised when scanning cannot start; [key] names why
/// (`code_scanner.permission_denied`, `code_scanner.no_camera`,
/// `code_scanner.unsupported`, `code_scanner.failed`, `code_scanner.disposed`).
class TomCodeScannerException extends TomException {
  /// Creates the exception; parameters mirror [TomException].
  TomCodeScannerException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.rootException,
    super.stack,
  });
}

/// A source of decoded codes: the device camera behind a plugin the
/// application chose.
///
/// The lifecycle is the stream's: [scan] opens the camera when it is listened
/// to and releases it when the subscription is cancelled. One scan runs at a
/// time. [preview] is the widget showing what the camera sees, placed by the
/// screen wherever it scans.
///
/// An implementation reports a refused permission, a missing camera and an
/// unsupported platform as a [TomCodeScannerException] on the stream (keys
/// above), never by an empty stream, so a screen can tell "nothing scanned
/// yet" from "nothing can be scanned".
abstract class TomCodeScanner {
  /// Creates a scanner.
  const TomCodeScanner();

  /// The installed scanner, or `null`: an application that scans installs its
  /// adapter at start-up ([install]), and code that wants one asks here.
  static TomCodeScanner? resolve() {
    final installed = TomBean.getBeanByType(TomCodeScanner);
    return installed is TomCodeScanner ? installed : null;
  }

  /// Installs [scanner] as the process-wide scanner, replacing one installed
  /// before.
  static void install(TomCodeScanner scanner) =>
      TomBean.overrideWithType<TomCodeScanner>(scanner);

  /// Whether scanning can work here now.
  Future<TomCodeScannerAvailability> availability();

  /// The codes the camera reads, as it reads them, of [formats] (every format
  /// the adapter supports when empty).
  ///
  /// A code that stays in view is reported once, not on every frame. The
  /// camera runs while the stream is listened to.
  Stream<TomScannedCode> scan({Set<TomCodeFormat> formats = const {}});

  /// The camera preview of the running scan.
  Widget preview(BuildContext context);

  /// Releases everything the scanner holds; it scans no more afterwards.
  Future<void> dispose();

  /// The first code [scan] reads that [accept] takes (any code when
  /// omitted), or `null` when [timeout] passes first. The camera is released
  /// either way.
  Future<TomScannedCode?> scanOnce({
    Set<TomCodeFormat> formats = const {},
    bool Function(TomScannedCode code)? accept,
    Duration? timeout,
  }) async {
    final result = Completer<TomScannedCode?>();
    late final StreamSubscription<TomScannedCode> subscription;
    Timer? timer;
    Future<void> finish(
      TomScannedCode? code, [
      Object? error,
      StackTrace? stack,
    ]) async {
      timer?.cancel();
      if (result.isCompleted) return;
      // Released before the caller hears the answer: once scanOnce returns,
      // the camera is off.
      await subscription.cancel();
      error == null
          ? result.complete(code)
          : result.completeError(error, stack);
    }

    subscription = scan(formats: formats).listen(
      (code) {
        if (accept == null || accept(code)) unawaited(finish(code));
      },
      onError: (Object error, StackTrace stack) =>
          unawaited(finish(null, error, stack)),
      onDone: () => unawaited(finish(null)),
    );
    if (timeout != null) {
      timer = Timer(timeout, () => unawaited(finish(null)));
    }
    return result.future;
  }
}

/// A [TomCodeScanner] that reads what a test tells it to.
///
/// [emit] delivers a code to the running scan; [fail] makes the next scan
/// end with an error; [availabilityValue] is what [availability] answers.
/// [listening] says whether a scan is running — whether "the camera is on".
class TomFakeCodeScanner extends TomCodeScanner {
  /// What [availability] answers.
  TomCodeScannerAvailability availabilityValue;

  /// The formats the last scan asked for.
  Set<TomCodeFormat> lastFormats = const {};

  /// How many scans were started.
  int scansStarted = 0;

  StreamController<TomScannedCode>? _running;
  TomCodeScannerException? _nextFailure;
  bool _disposed = false;

  /// Creates the scanner, available unless told otherwise.
  TomFakeCodeScanner({
    this.availabilityValue = TomCodeScannerAvailability.available,
  });

  /// Whether a scan is running.
  bool get listening => _running != null;

  /// Whether [dispose] was called.
  bool get disposed => _disposed;

  @override
  Future<TomCodeScannerAvailability> availability() async => availabilityValue;

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
    late final StreamController<TomScannedCode> controller;
    controller = StreamController<TomScannedCode>(
      onListen: () {
        scansStarted++;
        lastFormats = formats;
        _running = controller;
        final failure = _nextFailure;
        if (failure != null) {
          _nextFailure = null;
          controller.addError(failure);
        }
      },
      onCancel: () {
        if (identical(_running, controller)) _running = null;
      },
    );
    return controller.stream;
  }

  /// Delivers a code reading [payload] to the running scan; answers whether a
  /// scan was running to receive it. A code of a format the scan did not ask
  /// for is not delivered, as a real decoder would not report it.
  bool emit(String payload, {TomCodeFormat format = TomCodeFormat.qrCode}) {
    final running = _running;
    if (running == null) return false;
    if (lastFormats.isNotEmpty && !lastFormats.contains(format)) return false;
    running.add(TomScannedCode(payload: payload, format: format));
    return true;
  }

  /// Makes the next scan end with a `code_scanner.<cause>` error.
  void fail(String cause) => _nextFailure = TomCodeScannerException(
    'code_scanner.$cause',
    'The scan could not start: $cause.',
  );

  @override
  Widget preview(BuildContext context) =>
      const SizedBox.expand(key: ValueKey('tom-fake-code-scanner-preview'));

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _running?.close();
    _running = null;
  }
}
