/// A screen that scans through tom_core_flutter's [TomCodeScanner] — and so
/// runs the same over the camera adapter and over the test double.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

/// What the screen says about each availability.
const Map<TomCodeScannerAvailability, String> availabilityText = {
  TomCodeScannerAvailability.available: 'The camera is ready.',
  TomCodeScannerAvailability.permissionNotRequested:
      'Scanning will ask for the camera.',
  TomCodeScannerAvailability.permissionDenied:
      'The camera was refused. Allow it in the system settings to scan.',
  TomCodeScannerAvailability.noCamera: 'This device has no camera.',
  TomCodeScannerAvailability.unsupported:
      'Scanning is not supported on this platform.',
};

/// Scans codes and lists what it read.
class ScanScreen extends StatefulWidget {
  /// The scanner the screen reads through.
  final TomCodeScanner scanner;

  /// Creates the screen.
  const ScanScreen({super.key, required this.scanner});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final List<TomScannedCode> _codes = [];
  StreamSubscription<TomScannedCode>? _scan;
  TomCodeScannerAvailability? _availability;
  bool _qrOnly = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshAvailability());
  }

  Future<void> _refreshAvailability() async {
    final availability = await widget.scanner.availability();
    if (mounted) setState(() => _availability = availability);
  }

  void _start() {
    setState(() => _error = null);
    _scan = widget.scanner
        .scan(formats: _qrOnly ? {TomCodeFormat.qrCode} : const {})
        .listen(
          (code) => setState(() => _codes.insert(0, code)),
          onError: (Object error) {
            setState(() {
              _error = error is TomCodeScannerException
                  ? error.defaultUserMessage
                  : '$error';
            });
            unawaited(_stop());
          },
        );
    setState(() {});
    unawaited(_refreshAvailability());
  }

  Future<void> _stop() async {
    final scan = _scan;
    _scan = null;
    if (mounted) setState(() {});
    await scan?.cancel();
    await _refreshAvailability();
  }

  @override
  void dispose() {
    unawaited(_scan?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scanning = _scan != null;
    final availability = _availability;
    final canScan =
        availability != null &&
        availability != TomCodeScannerAvailability.noCamera &&
        availability != TomCodeScannerAvailability.unsupported;
    return Scaffold(
      appBar: AppBar(title: const Text('Code scanner')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              availability == null ? '' : availabilityText[availability]!,
              key: const Key('availability'),
            ),
          ),
          SwitchListTile(
            key: const Key('qrOnly'),
            title: const Text('QR codes only'),
            value: _qrOnly,
            onChanged: scanning ? null : (on) => setState(() => _qrOnly = on),
          ),
          if (scanning)
            SizedBox(height: 280, child: widget.scanner.preview(context)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton.icon(
              key: const Key('toggleScan'),
              onPressed: !canScan ? null : (scanning ? _stop : _start),
              icon: Icon(scanning ? Icons.stop : Icons.qr_code_scanner),
              label: Text(scanning ? 'Stop' : 'Scan'),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                _error!,
                key: const Key('scanError'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const Divider(),
          Expanded(
            child: ListView(
              children: [
                for (final code in _codes)
                  ListTile(
                    leading: const Icon(Icons.qr_code_2),
                    title: Text(code.payload),
                    subtitle: Text(code.format.name),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
