/// The reflected entity the export example derives its columns from.
///
/// Declared beside the example rather than inside it because the example
/// imports the generated reflection, and a type the generator captures cannot
/// also live in a file that imports the generator's output.
///
/// It is captured through `example/example_reflection.dart`, the example
/// suite's single reflection root.
library;

import 'package:tom_core_server/tom_core_server.dart';

/// The same sales table the example writes out by hand, declared once.
///
/// Field for field this is `columns()` in `export_example.dart` — deliberately,
/// because the point the module makes about the reflected projection is not
/// that it produces *a* table but that it produces *that* table, so the
/// hand-written list is the second declaration and can go. The example renders
/// both and compares the bytes; a type or an order changed here and nowhere
/// else is what would break it.
///
/// The last two fields are the ones that are **not** exported by default, and
/// they are here to be absent:
///
///  * [internalRank] is named in `@TomAudited(redact: …)`, so it must not exist
///    in a second place at all — naming it in `include` is an error rather than
///    a quiet override;
///  * [receipt] is a `@TomFileReference`, so it holds a storage *key* rather
///    than content. That one is default-closed rather than shut: an audience
///    with a use for the keys gets them by asking.
///
/// The `datasource` is named and never reached. `@TomDbTable` requires one, and
/// the projection reads annotations rather than rows, so the example derives a
/// full column set with no database anywhere in the run.
@tomReflector
@TomAudited(redact: ['internalRank'])
@TomDbTable(
  datasource: 'unused_by_this_example',
  table: 'example_sale',
  primaryKeyFields: ['id'],
)
class ExampleSaleRecord {
  /// Surrogate primary key — a storage detail, and the example excludes it.
  ///
  /// Realistic rather than convenient: a row's identity is how the database
  /// finds it again, and a reader of a sales report has no use for it. `exclude`
  /// is how an export says so, keyed by this declared field name.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// The product name — derives [TomColumnType.text].
  @TomDbColumn(columnName: 'product')
  String? product;

  /// What it sold for — derives [TomColumnType.decimal].
  @TomDbColumn(columnName: 'amount')
  double? amount;

  /// When — derives [TomColumnType.timestamp].
  @TomDbColumn(columnName: 'sold')
  DateTime? sold;

  /// Whether the line is still live — derives [TomColumnType.boolean].
  @TomDbColumn(columnName: 'active')
  bool? active;

  /// The redacted column: declared out of the audit trail, and so out of here.
  @TomDbColumn(columnName: 'internal_rank')
  String? internalRank;

  /// The file column: a storage key, exported only when asked for.
  @TomDbColumn(columnName: 'receipt')
  @TomFileReference(keyPrefix: 'sales/receipt')
  String? receipt;
}
