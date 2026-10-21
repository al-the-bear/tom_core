/// The example suite's single reflection root.
///
/// Nine of the examples need a live reflector and none can borrow the test
/// fixture's, because an example is not a test and cannot import from `test/`:
///
///  * the two-node cluster demonstration, whose SQL scheduler stores read every
///    table through `executeQuery<T>` — a call that resolves `T` through the
///    reflector and throws "Reflection has not been initialized" until the
///    generated `initializeReflection()` has run;
///  * the endpoints example, whose file-slot step registers a repository and
///    lets `TomFileSlots` derive the route from the entity's annotations;
///  * the export example, whose derived-column step reads `@TomDbColumn` off an
///    entity to build a section that has no hand-written projection to drift
///    from;
///  * the object-persistence example, whose query sentences, grouped select and
///    column grades are all resolved from one entity's annotations;
///  * the optimistic-locking example, whose version column, guarded update and
///    migration check are resolved from `ExampleArticle`'s annotations;
///  * the field-encryption example, whose blind-index lookup, audit redaction
///    and refused query are resolved from `ExamplePatientRecord`'s annotations;
///  * the preferences example, whose object preference is encoded and rebuilt
///    through the registry rather than through the type's own name;
///  * the file-storage example, whose configured stores are built by backends
///    whose settings are bound — and checked — through the reflector;
///  * the read-replicas example, which reads `@TomPrimaryReads` off the
///    framework's own entities and binds a data source's settings through the
///    reflector.
///
/// **One root, not one per example.** The generator follows this file's import
/// graph and emits `example_reflection.reflection.dart` beside it, and because
/// every root reaches the package barrel, each one costs a further ~1.7 MB of
/// generated source capturing the same framework surface. Naming the demos'
/// types here instead keeps that cost paid once, and is why a new example that
/// needs reflection should add its type to the list below rather than a second
/// root to `build.yaml`.
library;

import 'package:tom_core_server/tom_core_server.dart';

import 'endpoints/endpoints_entities.dart';
import 'export/export_entities.dart';
import 'file_storage/file_storage_backend.dart';
import 'object_persistence/object_persistence_entities.dart';
import 'preferences/preferences_entities.dart';
import 'scheduling/cluster/cluster_reflection.dart';

/// Entry point the reflection generator requires of a root. Never run.
void main() {}

/// The types this root exists to capture.
///
/// Naming them is not decoration: the generator works from the import graph, so
/// the list is what keeps the imports above load-bearing to a reader and to the
/// analyzer rather than looking like leftovers.
const List<Type> exampleReflectedTypes = <Type>[
  // Declared by the demos themselves.
  ClusterFenceRow,
  ExampleArticle,
  ExampleClaimRecord,
  ExampleDashboardPreference,
  ExampleDocumentRecord,
  ExamplePatientRecord,
  ExampleSaleRecord,
  ExampleShelfBlobStoreBackend,
  // A framework row holder, named to keep the package barrel in the graph. The
  // SQL scheduler stores map their rows into types like this one, so the
  // cluster demo needs the framework's reflected surface as much as its own.
  TomJobRunRow,
];
