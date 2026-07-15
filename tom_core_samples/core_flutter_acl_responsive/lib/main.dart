/// Entry point for the Tom Flutter UI responsive showcase.
///
/// Two things must happen before the first frame:
///
///  1. [initializeReflection] — the forms bind reflected `@tomReflector`
///     entities ([CompanyProfile], [ResponsiveProfile]); their field metadata
///     comes from the generated `reflection_seed.reflection.dart`, so reflection
///     has to be registered before any form is constructed.
///  2. The [chromeTexts] bundle is installed. The showcase's teaching snippets
///     resolve their field labels through `labelTextOverride` (no resource file
///     needed), but the showcase's own **interactive chrome** — the code panel's
///     copy-button tooltip — is real application text, so G-RES-1 applies and it
///     is resolved from this bundle (see `common/chrome_texts.dart` for the
///     exemption boundary).
library;

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'common/chrome_texts.dart';
import 'reflection_seed.dart';
import 'showcase_app.dart';

void main() {
  initializeReflection();
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(chromeTexts),
  );
  runApp(ResponsiveApp());
}
