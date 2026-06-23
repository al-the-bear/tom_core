/// Entry point for the Tom Flutter UI component showcase.
///
/// The showcase deliberately uses the *direct-parameter* form of every Tom
/// widget (`label:`, `text:`, `value:` …) so no [TomTextResourceProvider]
/// lookup is required — each snippet is copy-paste-ready on its own. We still
/// install an empty application provider so that any widget which probes the
/// singleton finds a valid (empty) scope rather than triggering lazy defaults.
library;

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'showcase_app.dart';

void main() {
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(const <String, dynamic>{}),
  );
  runApp(const ShowcaseApp());
}
