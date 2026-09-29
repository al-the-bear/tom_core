/// Phase 5 backing state — Demo M (Cupertino string + bool + selection).
///
/// One shared `TomClass` so a Material form and a Cupertino form can
/// both bind to it; the demo wires pair-wise observer sync so edits
/// in either panel propagate to the other.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

@tomReflector
class Phase5DemoState extends TomClass {
  /// Free-form text — drives the string-input row.
  late final name = TomString('Apollo 11');

  /// Closed-set string — drives the picker / dropdown row.
  late final color = TomString('blue');

  /// Closed-set string with a small enum — drives the segmented row.
  late final size = TomString('M');

  /// Multi-select — drives the filter-chips row. An observable list binds
  /// to a `List<String>` field like any scalar: `setValues` re-types the
  /// serialized list on the way in.
  late final tags = TomList<TomString>()..add(TomString('alpha'));

  /// Free-form text — drives the search row.
  late final search = TomString('');

  /// Boolean — drives the switch row.
  late final notifications = TomBool(true);

  /// Boolean — drives the toggle row.
  late final darkMode = TomBool(false);
}

Phase5DemoState phase5DemoState = Phase5DemoState();

// ---------------------------------------------------------------------------
// Sources reused by both panels (Material + Cupertino).
// ---------------------------------------------------------------------------

class _ColorSource extends TomSelectableSource<String> {
  @override
  Future<List<SelectableItem<String>>> getItems() async => const [
    SelectableItem<String>(value: 'red', label: 'Red'),
    SelectableItem<String>(value: 'green', label: 'Green'),
    SelectableItem<String>(value: 'blue', label: 'Blue'),
    SelectableItem<String>(value: 'yellow', label: 'Yellow'),
    SelectableItem<String>(value: 'purple', label: 'Purple'),
  ];
}

class _SizeSource extends TomSelectableSource<String> {
  @override
  Future<List<SelectableItem<String>>> getItems() async => const [
    SelectableItem<String>(value: 'S', label: 'S'),
    SelectableItem<String>(value: 'M', label: 'M'),
    SelectableItem<String>(value: 'L', label: 'L'),
  ];
}

class _TagSource extends TomSelectableSource<String> {
  @override
  Future<List<SelectableItem<String>>> getItems() async => const [
    SelectableItem<String>(value: 'alpha', label: 'Alpha'),
    SelectableItem<String>(value: 'beta', label: 'Beta'),
    SelectableItem<String>(value: 'gamma', label: 'Gamma'),
    SelectableItem<String>(value: 'delta', label: 'Delta'),
    SelectableItem<String>(value: 'epsilon', label: 'Epsilon'),
  ];
}

final TomSelectableSource<String> phase5ColorSource = _ColorSource();
final TomSelectableSource<String> phase5SizeSource = _SizeSource();
final TomSelectableSource<String> phase5TagSource = _TagSource();

// ---------------------------------------------------------------------------
// Phase 5b — Cupertino numeric + date/time backing state.
// ---------------------------------------------------------------------------

/// One shared `TomClass` for Demo N — every field a different numeric /
/// date / time / duration / range type so all 9 Phase 5b Cupertino
/// concretes have a real `TomObject` to bind to.
@tomReflector
class Phase5bDemoState extends TomClass {
  /// Quantity — drives [TomCupertinoFormIntInput].
  late final quantity = TomInt(8);

  /// Brightness 0..100 — drives [TomCupertinoFormIntPicker].
  late final brightness = TomInt(50);

  /// Generic decimal — drives [TomCupertinoFormDoubleInput].
  late final ratio = TomDouble(1.5);

  /// Currency value — drives [TomCupertinoFormCurrencyDoubleInput].
  late final price = TomDouble(199.99);

  /// Date — drives [TomCupertinoFormDatePicker].
  late final eventDate = TomDateTime(DateTime(2026, 5, 12));

  /// Date+time — drives [TomCupertinoFormDateTimePicker].
  late final eventDateTime = TomDateTime(DateTime(2026, 5, 12, 9, 30));

  /// Note: time / duration / date-range fields stay form-local on Demo N —
  /// `TimeOfDay`, `Duration`, and `DateTimeRange` aren't first-class
  /// TomObject types here, so the form carries those values via the
  /// `TomField` itself rather than binding to a TomClass property.
}

Phase5bDemoState phase5bDemoState = Phase5bDemoState();

// ---------------------------------------------------------------------------
// Phase 5c — Cupertino search / lookup / file + nullable backing state.
// ---------------------------------------------------------------------------

/// Backing TomClass for Demo O (Cupertino search/lookup/file + nullable).
///
/// `search` and `lookup` carry the *value* of the selected item directly
/// (not a label) — the form-side label resolver picks a display string
/// from the source snapshot. Search/lookup over `City` / `Country` types
/// can't bind into the kernel because there's no `TomObject<City>` /
/// `TomObject<Country>`, so the demo lets those fields stay form-local
/// (mirrors the Phase 4 Demo K pattern).
///
/// The four nullable fields *can* bind: `TomNString`, `TomNInt`,
/// `TomNDouble`, `TomNDateTime` exist in the kernel.
@tomReflector
class Phase5cDemoState extends TomClass {
  /// Free-form caption — drives the nullable string input.
  late final notes = TomNString(null);

  /// Optional age — drives the nullable int input.
  late final age = TomNInt(null);

  /// Optional score — drives the nullable double input.
  late final score = TomNDouble(null);

  /// Optional birthday — drives the nullable date input.
  late final birthday = TomNDateTime(null);
}

Phase5cDemoState phase5cDemoState = Phase5cDemoState();

// ---------------------------------------------------------------------------
// Phase 5c — Demo P backing state (family-swap by breakpoint).
//
// Demo P shows how a single form declaration can resolve to either
// Material or Cupertino concretes via [FormFieldFamily]. The state
// mirrors the cross-section of fields the family supports.
// ---------------------------------------------------------------------------

@tomReflector
class Phase5cFamilyState extends TomClass {
  late final fullName = TomString('Ada Lovelace');
  late final quantity = TomInt(3);
  late final ratio = TomDouble(0.75);
  late final notifyMe = TomBool(true);
  late final eventDate = TomDateTime(DateTime(2026, 6, 15));
}

Phase5cFamilyState phase5cFamilyState = Phase5cFamilyState();
