/// The reflected entity the endpoints example registers a file slot for.
///
/// Declared beside the example rather than inside it because the example
/// imports the generated reflection, and a type the generator captures cannot
/// also live in a file that imports the generator's output.
///
/// It is captured through `example/example_reflection.dart`, the example
/// suite's single reflection root.
library;

import 'package:tom_core_server/tom_core_server.dart';

/// A document with one file column the network may reach and one it may not.
///
/// Both columns are `@TomFileReference`, so reflection can see both; only
/// [attachment] says `exposed: true`. That difference is the whole
/// default-closed rule, and having both on one entity is what makes it
/// demonstrable: a slot appears for the exposed column and no slot appears for
/// the other, from the same registration, in the same registry.
///
/// The `datasource` and `primaryKeyFields` are declared because `@TomDbTable`
/// requires them, and are never used — [TomFileSlots.register] reads the table
/// name and the file columns and calls no repository method, so the example
/// needs no database to show what registration decides.
@tomReflector
@TomDbTable(
  datasource: 'unused_by_this_example',
  table: 'example_document',
  primaryKeyFields: ['id'],
)
class ExampleDocumentRecord {
  /// Surrogate primary key. The `{id}` of `/files/example_document/{id}/…`.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// An ordinary column, so the entity is more than its files.
  @TomDbColumn(columnName: 'title')
  String? title;

  /// The exposed file column: reachable at `example_document/attachment`.
  @TomDbColumn(columnName: 'attachment')
  @TomFileReference(keyPrefix: 'documents/attachment', exposed: true)
  String? attachment;

  /// A file column that is exposed to nobody, and so has no slot at all.
  @TomDbColumn(columnName: 'internal_draft')
  @TomFileReference(keyPrefix: 'documents/internal')
  String? internalDraft;
}
