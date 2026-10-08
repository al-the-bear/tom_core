/// The key value of an entity whose primary key spans several fields.
library;

/// The primary-key value of an entity whose `@TomDbTable.primaryKeyFields`
/// names more than one field — the `K` of its repository.
///
/// A table keyed by several columns, the usual shape of a join table
/// (`PRIMARY KEY (user_id, role_id)`), has no single value that addresses a
/// row. Its repository is declared `TomSqlDatasourceRepository<E,
/// TomCompositeKey>`, and every by-key method — `findById`, `deleteById`,
/// `existsById`, `findAllById`, `deleteAllById` — takes one of these:
///
/// ```dart
/// final row = await userRoles.findById(
///   TomCompositeKey({'userId': 7, 'roleId': 3}),
/// );
/// ```
///
/// The map is keyed by **field** name, the names `primaryKeyFields` lists, and
/// must carry exactly those fields: the repository refuses a key with a field
/// missing or one too many rather than matching on the fields it happens to
/// have, because a partial key addresses several rows and every by-key method
/// promises one.
///
/// Two keys are equal when they hold the same values for the same fields, in
/// any order, so a set of keys deduplicates the way a set of single ids does.
final class TomCompositeKey {
  /// Creates a key from [values], field name to value.
  TomCompositeKey(Map<String, Object?> values)
    : values = Map.unmodifiable(values);

  /// The key's values, keyed by entity field name.
  final Map<String, Object?> values;

  /// The value of [field], or `null` when the key does not carry it.
  Object? operator [](String field) => values[field];

  /// The field names this key carries.
  Iterable<String> get fields => values.keys;

  @override
  bool operator ==(Object other) {
    if (other is! TomCompositeKey) return false;
    if (other.values.length != values.length) return false;
    for (final entry in values.entries) {
      if (!other.values.containsKey(entry.key)) return false;
      if (other.values[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAllUnordered(
    values.entries.map((entry) => Object.hash(entry.key, entry.value)),
  );

  /// `(userId: 7, roleId: 3)` — the form audit records and error messages
  /// carry as the row's key.
  @override
  String toString() =>
      '(${values.entries.map((e) => '${e.key}: ${e.value}').join(', ')})';
}
