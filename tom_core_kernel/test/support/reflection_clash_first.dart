/// One half of a deliberate simple-name collision.
///
/// [ClashingItem] is declared here *and* in `reflection_clash_second.dart`
/// under the same simple name. Reflection resolves a field's element type by
/// simple name, so a domain containing both cannot answer the question "which
/// `ClashingItem`?" — and must say so rather than pick one. The pair exists to
/// pin that refusal; see the `ambiguous_simple_name` test in
/// `reflection_test.dart`.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// The first of the two identically-named annotated classes.
@tomReflector
class ClashingItem {
  /// Distinguishes an instance of this class from its namesake in a report.
  String label = 'first';

  ClashingItem();
}
