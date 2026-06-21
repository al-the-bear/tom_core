/// Entry point for the Tom Flutter UI forms showcase.
///
/// Two things must happen before the first frame:
///
///  1. [initializeReflection] — the forms bind reflected `@tomReflector`
///     entities ([CompanyProfile], [OrderItem]); their field metadata comes
///     from the generated `reflection_seed.reflection.dart`, so reflection has
///     to be registered before any form is constructed.
///  2. An (empty) application resource provider is installed so any widget that
///     probes the singleton finds a valid scope. The showcase resolves labels
///     through `labelTextOverride`, so no resource file is needed — error keys
///     fall through to their raw key, which is intentionally instructive.
library;

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'reflection_seed.dart';
import 'showcase_app.dart';

void main() {
  initializeReflection();
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(const <String, dynamic>{}),
  );
  runApp(const ShowcaseApp());
}
