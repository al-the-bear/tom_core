/// The reflected row type the two-node cluster demonstration adds to the
/// framework's own.
///
/// `TomSqlJobStore`, `TomSqlLeaseLock` and `TomSqlSchedulerNodes` all read their
/// tables through `executeQuery<T>`, which takes a `ClassMirror` of `T` — so
/// every one of them throws "Reflection has not been initialized" until the
/// generated `initializeReflection()` has run. That is not a quirk of the demo:
/// it is what any deployment does at start-up, and the demo would be lying about
/// the wiring if it dodged it.
///
/// The generated `initializeReflection()` the demo calls comes from
/// `example/example_reflection.reflection.dart` — the example suite's single
/// reflection root, which imports this file. It is shared rather than
/// demo-local because every root reaches the package barrel and so costs a
/// further ~1.7 MB of generated source capturing the same framework surface.
library;

import 'package:tom_core_server/tom_core_server.dart';

/// The downstream resource the fencing scenario guards.
///
/// The fencing token only means something if *something* checks it. A lease
/// whose token nobody compares against is a lease with a counter attached, not a
/// fence. So the demo gives node A and node B a shared row to fight over, and
/// makes every write to it conditional on the writer's token:
///
/// ```sql
/// UPDATE demo_fenced_resource SET holder = :h, fence = :token
///  WHERE name = :n AND fence <= :token
/// ```
///
/// A write carrying a token the resource has already seen surpassed affects zero
/// rows. That is the whole fencing protocol, and it is why a node that stalled
/// past its lease cannot corrupt the work of the node that replaced it.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["irrelevant"],
)
class ClusterFenceRow {
  /// The resource's name — one row, keyed by it.
  @TomDbColumn(columnName: "name")
  String name = "";

  /// The node whose write last landed.
  @TomDbColumn(columnName: "holder")
  String holder = "";

  /// The highest fencing token ever accepted for this resource.
  @TomDbColumn(columnName: "fence")
  int fence = 0;
}
