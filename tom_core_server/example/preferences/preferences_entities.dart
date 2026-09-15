/// The reflected value type the preferences example stores.
///
/// A preference is not limited to a scalar: anything the reflection registry
/// knows can be written as one, which is what makes a preference a typed object
/// rather than a stringly-typed blob. The class is therefore the smallest thing
/// that shows it — public mutable fields and a default constructor, the shape
/// `TomUserPreferenceCodec` reads and rebuilds through the registry.
///
/// Declared here rather than in the example program because the reflection
/// generator works from `example/example_reflection.dart`'s import graph, and a
/// type it must capture has to be reachable from there.
library;

import 'package:tom_core_server/tom_core_server.dart';

/// A user's dashboard arrangement, stored as one preference.
@tomReflector
class ExampleDashboardPreference {
  /// Which panel opens first.
  String landingPanel = 'inbox';

  /// How many rows a list shows before it pages.
  int rowsPerPage = 25;

  /// Whether the side navigation starts collapsed.
  bool navigationCollapsed = false;
}
