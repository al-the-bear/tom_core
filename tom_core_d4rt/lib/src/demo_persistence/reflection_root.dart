/// Reflection root for the d4rt tool's persistence demo.
///
/// The reflection generator (`reflection_generation.sh` → build_runner) only
/// processes a root that declares `main()`, and captures the `@tomReflector`
/// types reachable from its import graph. This file imports
/// `demo_persistence.dart` (and, transitively, the `tom_core_server` barrel), so
/// the generated `reflection_root.reflection.dart` captures [D4rtDemoTaskRecord]
/// and the reflected server surface. The d4rt tool calls that generated
/// `initializeReflection()` once at boot (`d4rtMain`), seeding `tomReflector` so
/// scripts can `reflectType()` these types inside the AOT `bin/d4rt_test`.
///
/// The body is intentionally empty — the file exists only to be the reflection
/// root, never to be run.
library;

import 'demo_persistence.dart';

/// Entry point required by the reflection generator; never executed. It names
/// the demo types so the `demo_persistence.dart` import is retained (and the
/// analyzer stays clean) while the generator walks the import graph.
void main() {
  final captured = <Type>[D4rtDemoTaskRecord, D4rtDemoTaskRepository];
  assert(captured.isNotEmpty);
}
