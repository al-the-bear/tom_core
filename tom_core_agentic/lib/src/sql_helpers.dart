// SQLite query-building helpers.
//
// Any SQLite-backed store repeats the same three domain-free idioms: a
// `?,?,?` placeholder run for an `IN (…)` clause, a non-cryptographic
// hash to disambiguate a derived identifier, and a "string → safe SQL
// identifier" sanitiser. Each was hand-rolled at every call site, and
// the placeholder separator even drifted (`','` vs `', '`). These are
// those idioms, with one definition each.

/// Builds a comma-separated run of `count` bind placeholders for an
/// `IN (…)` clause: `sqlPlaceholders(3)` ⇒ `'?,?,?'`.
///
/// [count] must be non-negative; `0` yields the empty string (the
/// caller is responsible for not emitting an empty `IN ()`). The
/// [separator] defaults to `','` — pass `', '` only when a human will
/// read the SQL, since the two are equivalent to SQLite.
String sqlPlaceholders(int count, {String separator = ','}) {
  if (count < 0) {
    throw ArgumentError.value(count, 'count', 'must be non-negative');
  }
  return List<String>.filled(count, '?').join(separator);
}

/// FNV-1a 32-bit hash of [s], computed over its UTF-16 code units.
///
/// FNV-1a is **not** cryptographic. Its only job here is to
/// disambiguate the readable prefix of a derived identifier (e.g. a
/// per-model vector table name) so two similar inputs do not collide on
/// the truncated, sanitised portion. The actual collision detector is
/// whatever `UNIQUE` constraint guards the derived name; a collision in
/// the astronomically-unlikely worst case surfaces there.
int fnv1a32(String s) {
  const int offset = 0x811c9dc5;
  const int prime = 0x01000193;
  var hash = offset;
  for (var i = 0; i < s.length; i++) {
    hash ^= s.codeUnitAt(i) & 0xff;
    hash = (hash * prime) & 0xffffffff;
  }
  return hash;
}

/// Lowercases [input] and replaces every character outside `[a-z0-9_]`
/// with `_`, capping the result at [maxLength] characters.
///
/// Produces the readable, SQL-safe prefix portion of a derived
/// identifier. It is deliberately lossy and **not** injective — pair it
/// with a hash suffix (see [fnv1a32]) when uniqueness matters.
String sqlSafeIdentifier(String input, {int maxLength = 32}) {
  if (maxLength < 0) {
    throw ArgumentError.value(maxLength, 'maxLength', 'must be non-negative');
  }
  final lower = input.toLowerCase();
  final out = StringBuffer();
  for (var i = 0; i < lower.length && out.length < maxLength; i++) {
    final ch = lower.codeUnitAt(i);
    final isAlnum = (ch >= 0x30 && ch <= 0x39) || // 0-9
        (ch >= 0x61 && ch <= 0x7a); // a-z
    final isUnderscore = ch == 0x5f; // _
    out.write(isAlnum || isUnderscore ? String.fromCharCode(ch) : '_');
  }
  return out.toString();
}
