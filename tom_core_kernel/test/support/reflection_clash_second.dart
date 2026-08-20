/// The other half of a deliberate simple-name collision.
///
/// See `reflection_clash_first.dart` for why the pair exists.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// The second of the two identically-named annotated classes.
@tomReflector
class ClashingItem {
  /// Distinguishes an instance of this class from its namesake in a report.
  String label = 'second';

  ClashingItem();
}
