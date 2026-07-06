/// Resolves a domain enum value's display text from the installed resource
/// bundle (step 16 / G-RES-5).
///
/// The shared `advanced_todo_domain` enums carry no hardcoded display strings:
/// each value only knows its `global.<enumtype>.<value>` resource key
/// ([EnumResourceKey.resourceKey]). This client-side helper is the one place
/// that turns that key into text, looking it up in the singleton
/// [TomTextResourceProvider] the session installs from the server-sent bundle.
/// A key absent from the bundle degrades to the key itself (the provider's
/// fallback), so a missing translation is visible rather than silently blank.
library;

import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// The display text for [value], resolved from the installed resource bundle
/// under its `global.<enumtype>.<value>` key.
String enumText(Enum value) =>
    TomTextResourceProvider.getAppResources().getText(value.resourceKey);
