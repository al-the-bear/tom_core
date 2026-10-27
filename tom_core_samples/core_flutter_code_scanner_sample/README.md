# Code Scanner Sample

An application that reads QR codes and barcodes with the device camera through
tom_core_flutter's `TomCodeScanner` contract. The framework holds the contract;
the camera plugin — here [`mobile_scanner`](https://pub.dev/packages/mobile_scanner)
— lives in this application, behind one adapter file.

| File | What it is |
| ---- | ---------- |
| `lib/mobile_scanner_code_scanner.dart` | The adapter: `MobileScannerCodeScanner` implements `TomCodeScanner` over `mobile_scanner`, with the format, code and error mappings as plain functions |
| `lib/scan_screen.dart` | A screen that scans through the contract: availability, start and stop, the camera preview, the codes read |
| `lib/main.dart` | Installs the adapter (`TomCodeScanner.install`) and shows the screen |
| `test/mobile_scanner_mapping_test.dart` | The adapter's mappings, tested without a camera |
| `test/scan_screen_test.dart` | The screen, driven through `TomFakeCodeScanner` |

## The shape to copy

The adapter is the only file that imports the plugin. Everything above it is
written against `TomCodeScanner`:

```dart
// at start-up
TomCodeScanner.install(MobileScannerCodeScanner());

// wherever a code is wanted
final code = await TomCodeScanner.resolve()!.scanOnce(
  formats: {TomCodeFormat.qrCode},
  accept: (code) => code.payload.startsWith('otpauth://'),
  timeout: const Duration(minutes: 1),
);
```

So the screens run unchanged on `TomFakeCodeScanner` in a widget test, and
moving to another plugin means rewriting the adapter and nothing else.

The adapter maps the plugin onto the contract:

- **A scan.** It starts a camera controller when the scan is listened to, with
  `DetectionSpeed.noDuplicates` so a code that stays in view is reported once.
  It stops and disposes the controller when the subscription is cancelled.
- **Errors.** A plugin error becomes a `TomCodeScannerException` on the
  stream: `code_scanner.permission_denied`, `.unsupported`, `.disposed` or
  `.failed`.
- **Availability.** The plugin cannot say whether the camera permission was
  granted without starting the camera. So `availability()` answers
  `unsupported` off Android, iOS, macOS and the web, `permissionNotRequested`
  before the first scan, and afterwards what that scan found.

## Running it

The sample tracks no platform folders. Add the ones you run on, then grant the
camera:

```bash
flutter create --empty --platforms=android .   # once per platform: or ios, macos, web
flutter run
```

| Platform | What the camera needs |
| -------- | --------------------- |
| iOS | `NSCameraUsageDescription` in `ios/Runner/Info.plist` |
| macOS | `NSCameraUsageDescription` in `macos/Runner/Info.plist`, and `com.apple.security.device.camera` in both entitlements files |
| Android | nothing: the plugin declares the permission and asks at the first scan |
| Web | a secure origin (`localhost` counts); the browser asks |

## Tests

```bash
flutter test
```

Neither suite needs a camera.
