/// A one-row driver result set built from column text, for row-mapper tests
/// that need no server.
///
/// The MySQL text protocol delivers every column as text, so a row is fully
/// described by its column names and values. Typed reads go through the
/// driver's own `MySQLColumnType.convertStringValueToProvidedType`, the
/// function the real `ResultSetRow` calls, so a conversion the driver refuses
/// is refused here for the same reason.
library;

import 'package:mysql_client/mysql_protocol.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// A driver row over text columns, read the way the driver reads text.
class TextRow implements ResultSetRow {
  /// A row holding [cells], keyed by column name.
  TextRow(this.cells);

  /// The column values by name; a `null` value is SQL `NULL`.
  final Map<String, String?> cells;

  String? _text(String name) {
    if (!cells.containsKey(name)) {
      // The real row raises this too: a column that was never selected is a
      // query mistake, not a null value.
      throw MySQLClientException('There is no column with name: $name');
    }
    return cells[name];
  }

  @override
  String? colByName(String columnName) => _text(columnName);

  @override
  T? typedColByName<T>(String columnName) => MySQLColumnType.varStringType
      .convertStringValueToProvidedType<T>(_text(columnName), 255);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'The text row was asked for ${invocation.memberName}, which the row '
    'mapper does not use.',
  );
}

/// A result set holding exactly one [TextRow] over [cells].
class OneTextRow extends IResultSet {
  /// A result set whose single row holds [cells].
  OneTextRow(this.cells);

  /// The row's column values by name.
  final Map<String, String?> cells;

  @override
  int get numOfColumns => cells.length;

  @override
  int get numOfRows => 1;

  @override
  BigInt get affectedRows => BigInt.zero;

  @override
  BigInt get lastInsertID => BigInt.zero;

  @override
  Iterable<ResultSetRow> get rows => [TextRow(cells)];

  @override
  Iterable<ResultSetColumn> get cols => [
    for (final name in cells.keys)
      ResultSetColumn(
        name: name,
        type: MySQLColumnType.varStringType,
        length: 255,
      ),
  ];
}
