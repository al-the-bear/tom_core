/// One half of a deliberate simple-name collision between two [TomClass]
/// subclasses, declared again under the same simple name in
/// `observable_clash_second.dart`.
///
/// A `TomList` or `TomMap` member of either must deserialize its elements as
/// *its own* class. The element type is read from the member's declaration,
/// which names the class exactly; a lookup by simple name could only refuse.
/// See the `same-named element classes` group in `observable_test.dart`.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// The first of the two identically-named observable classes.
@tomReflector
class ClashingRecord extends TomClass {
  /// Which half of the pair an instance came from.
  final TomString origin = TomString('first');

  /// A value the deserialized element carries, so a test can see it arrived.
  final TomString label = TomString('');
}
