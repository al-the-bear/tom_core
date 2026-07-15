/// Entry point for the Tom Flutter UI component showcase.
///
/// The showcase deliberately uses the *direct-parameter* form of every Tom
/// widget (`label:`, `text:`, `value:` …) so no [TomTextResourceProvider]
/// lookup is required for the **teaching snippets** — each snippet is
/// copy-paste-ready on its own. The showcase's own **interactive chrome** — the
/// code panel's copy-button tooltip — is different: it is real application text,
/// so G-RES-1 applies and it is resolved from the [chromeTexts] bundle installed
/// here (see `common/chrome_texts.dart` for the exemption boundary).
library;

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'common/chrome_texts.dart';
import 'showcase_app.dart';

void main() {
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(chromeTexts),
  );
  runApp(ShowcaseApp());
}
