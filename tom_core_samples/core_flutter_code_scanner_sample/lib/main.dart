/// Entry point: installs the camera adapter as the application's
/// [TomCodeScanner] and shows the scan screen.
library;

import 'package:flutter/material.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

import 'mobile_scanner_code_scanner.dart';
import 'scan_screen.dart';

void main() {
  TomCodeScanner.install(MobileScannerCodeScanner());
  runApp(
    MaterialApp(
      title: 'Code scanner',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: ScanScreen(scanner: TomCodeScanner.resolve()!),
    ),
  );
}
