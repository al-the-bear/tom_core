/// Entry point for the Tom Flutter UI responsive showcase.
///
/// Two things must happen before the first frame:
///
///  1. [initializeReflection] — the forms bind reflected `@tomReflector`
///     entities ([CompanyProfile], [ResponsiveProfile]); their field metadata
///     comes from the generated `reflection_seed.reflection.dart`, so reflection
///     has to be registered before any form is constructed.
///  2. The [showcaseTexts] bundle is installed. The showcase's teaching snippets
///     resolve their field labels through `labelTextOverride` (no resource file
///     needed), but two categories are real application text and so fall under
///     G-RES-1: the **interactive chrome** ([chromeTexts] — the code panel's
///     copy-button tooltip) and the **validator messages**
///     ([companyValidationTexts]). Installing the union before the first frame is
///     what stops a validator's `error.*` key rendering as its own name; see
///     `common/chrome_texts.dart` for the exemption boundary.
library;

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'common/chrome_texts.dart';
import 'reflection_seed.dart';
import 'showcase_app.dart';

void main() {
  initializeReflection();
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(showcaseTexts),
  );
  runApp(ResponsiveApp());
}
