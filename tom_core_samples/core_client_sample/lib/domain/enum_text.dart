/// Resolves a domain enum value's display text from the installed resource
/// bundle (G-RES-5).
///
/// The shared `todo_domain` enums carry no hardcoded display strings: each value
/// only knows its `global.<enumtype>.<value>` resource key
/// ([EnumResourceKey.resourceKey]). This client-side helper is the one place
/// that turns that key into text, looking it up in the singleton
/// [TomTextResourceProvider] that `main` (and the tests) install from
/// [appTexts]. A key absent from the bundle degrades to the key itself (the
/// provider's fallback), so a missing translation is visible rather than
/// silently blank.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:todo_domain/todo_domain.dart';

/// The display text for [value], resolved from the installed resource bundle
/// under its `global.<enumtype>.<value>` key.
String enumText(Enum value) =>
    TomTextResourceProvider.getAppResources().getText(value.resourceKey);
