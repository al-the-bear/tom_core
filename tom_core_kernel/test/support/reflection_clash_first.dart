/// One half of a deliberate simple-name collision.
///
/// [ClashingItem] is declared here *and* in `reflection_clash_second.dart`
/// under the same simple name. The pair pins both halves of what that means.
/// `singleElementType` and `mapValueElementType` are handed a bare collection,
/// whose element type exists only as text, so they cannot answer "which
/// `ClashingItem`?" and must say so rather than pick one. The field walk reads
/// a field's element type from the field's own mirror, so collections of each
/// deserialize as themselves. See the `ambiguous_simple_name` and
/// `ClashingItemsHolder` tests in `reflection_test.dart`.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// The first of the two identically-named annotated classes.
@tomReflector
class ClashingItem {
  /// Distinguishes an instance of this class from its namesake in a report.
  String label = 'first';

  ClashingItem();
}
