/// Reflection root for the two-node cluster demonstration.
///
/// `TomSqlJobStore`, `TomSqlLeaseLock` and `TomSqlSchedulerNodes` all read their
/// tables through `executeQuery<T>`, which takes a `ClassMirror` of `T` — so
/// every one of them throws "Reflection has not been initialized" until the
/// generated `initializeReflection()` has run. That is not a quirk of the demo:
/// it is what any deployment does at start-up, and the demo would be lying about
/// the wiring if it dodged it.
///
/// The generator (`reflection_generation.sh`, configured in `build.yaml`)
/// follows this file's import graph and emits `cluster_reflection.reflection.dart`
/// beside it. Importing the package barrel captures the row holders the three
/// stores map their rows into (`TomJobRunRow`, `TomLeaseRow`,
/// `TomSchedulerNodeRow`) along with the rest of the reflected server surface.
///
/// [ClusterFenceRow] is declared here rather than in a file of its own so the
/// demo has exactly one reflection root. A second root would mean a second
/// ~60k-line generated file capturing the same barrel.
library;

import 'package:tom_core_server/tom_core_server.dart';

/// Entry point the reflection generator requires of a root. Never run.
void main() {}

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
  primaryKeyField: "irrelevant",
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
