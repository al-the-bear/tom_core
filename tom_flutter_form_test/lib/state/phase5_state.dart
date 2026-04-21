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

  // Note: the multi-select `tags` field is intentionally NOT part of
  // the shared `TomClass` state. `TomList<TomString>` produces a
  // `List<TomString>` value that the bind() / setValues() path cannot
  // re-type into the `List<String>` expected by the form field. The
  // demo keeps tags state form-local on each side and relies on the
  // pair-wise observer sync (`_pairList`) to propagate edits.

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
