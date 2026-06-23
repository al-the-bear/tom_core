/// The reflected domain the responsive showcase forms bind to.
///
/// A responsive *forms* showcase binds domain objects into editable forms and
/// then re-flows / re-styles / swaps the family of those forms as the viewport
/// changes — so, like `core_flutter_form_showcase` (and unlike the pure widget
/// gallery `core_flutter_ui_showcase`), this sample carries `@tomReflector`
/// entities and a `build_runner` codegen step.
///
/// Two flat entities, mirroring the verified `tom_flutter_form_test` baselines
/// so the snippets stay faithful to a working source:
///
///  * [CompanyProfile] — string fields behind the breakpoint-field-style and
///    row-breakpoint screens (every field a kernel `TomString`).
///  * [ResponsiveProfile] — the mixed-type entity behind the family-swap screen
///    (string / int / double / bool / date), so the Material↔Cupertino swap has
///    a real field of each shape to round-trip across the breakpoint.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A company's basic profile — the entity behind the breakpoint-field-style and
/// row-breakpoint screens. Every field is a [TomString] so the whole entity
/// reflects against `tom_core_kernel` alone.
@tomReflector
class CompanyProfile extends TomClass {
  /// Required company name.
  late final name = TomString('Acme Corporation');

  /// Industry, chosen from a dropdown source.
  late final industry = TomString('tech');

  /// Tax identifier — pattern validated.
  late final taxId = TomString('US-12345-ABC');

  /// Public website URL — pattern validated.
  late final website = TomString('https://acme.example.com');
}

/// The mixed-type entity behind the family-swap screen. Mirrors the verified
/// `Phase5cFamilyState` from `tom_flutter_form_test` so the Material↔Cupertino
/// swap teaches one field of every common shape (string / int / double / bool /
/// date) round-tripping across the 700 px breakpoint on one shared state.
@tomReflector
class ResponsiveProfile extends TomClass {
  /// Free-form text — drives the family-aware string input.
  late final fullName = TomString('Ada Lovelace');

  /// Integer — drives the family-aware int input.
  late final quantity = TomInt(3);

  /// Decimal — drives the family-aware double input.
  late final ratio = TomDouble(0.75);

  /// Boolean — drives the family-aware switch.
  late final notifyMe = TomBool(true);

  /// Date — drives the family-aware date picker.
  late final eventDate = TomDateTime(DateTime(2026, 6, 15));
}
