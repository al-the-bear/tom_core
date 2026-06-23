/// The reflected domain the showcase forms bind to.
///
/// A *forms* showcase is, by definition, about binding domain objects into
/// editable forms — that is the whole point of `tom_flutter_ui`'s `TomForm<T>`.
/// So unlike the sibling `core_flutter_ui_showcase` (a pure widget gallery that
/// needs no reflection), this sample carries `@tomReflector`-annotated entities
/// and a `build_runner` codegen step.
///
/// The entities are deliberately *flat* (no nested `TomClass`) and *kernel-only*
/// (every field is a `TomString` from `tom_core_kernel`), so each entity itself
/// reflects against `tom_core_kernel` alone. The *overall* generated graph is
/// still large, because the reflection seed also reflects the `TomForm`
/// subclasses that bind these entities — and reflecting a form necessarily
/// reflects its `@tomReflector` field-widget types from `tom_flutter_ui`. That
/// is unavoidable and matches the verified `tom_flutter_form_test` precedent;
/// see `reflection_seed.dart` for why the forms must be in the graph. The
/// entity shapes mirror that precedent's `CompanyProfile` / `OrderItem` so the
/// snippets stay faithful to a working baseline.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A company's basic profile — the entity behind the field-type, validation,
/// layout and theming cells. Every field is a [TomString] so the whole entity
/// reflects against `tom_core_kernel` alone.
@tomReflector
class CompanyProfile extends TomClass {
  /// Required company name.
  late final name = TomString('');

  /// Industry, chosen from a dropdown source.
  late final industry = TomString('');

  /// Tax identifier — pattern + (simulated) async uniqueness validation.
  late final taxId = TomString('');

  /// Public website URL — pattern validated.
  late final website = TomString('');

  /// Free-text description — multi-line, length-capped.
  late final description = TomString('');
}

/// A single line item of an order — the entity behind the list cells. Kept as
/// strings (parsed at display time) exactly like the `form_test` precedent, so
/// the list/table patterns compose with the string-backed form widgets.
@tomReflector
class OrderItem extends TomClass {
  /// Product name — a type-ahead search picker over the catalogue.
  late final productName = TomString('');

  /// Quantity — required, must be a positive integer.
  late final quantity = TomString('1');

  /// Unit price — required, must be a non-negative decimal.
  late final unitPrice = TomString('0.00');

  /// Free-text notes.
  late final notes = TomString('');
}
