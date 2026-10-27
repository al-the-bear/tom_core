/// Matching blob keys by prefix in SQL, shared by the tables that hold keys.
library;

/// [prefix] with `LIKE`'s two wildcards escaped, for `ESCAPE '!'`.
///
/// `_` is a wildcard *and* a perfectly ordinary key character — the grammar
/// allows it — so an unescaped `2026_07` matches `2026x07`, and a retention
/// pass takes a partition nobody named. `%` and `!` cannot appear in a key at
/// all, and are escaped anyway so the rule belongs to the pattern rather than
/// to the grammar: this stays correct if the key grammar ever widens.
///
/// The escape character is `!` and not the SQL-conventional backslash,
/// because MariaDB reads a backslash inside a string literal as an escape of
/// its own, so the obvious `ESCAPE` clause is an unterminated literal and a
/// syntax error, and the doubling that fixes it is one more thing to get right
/// in a place where getting it wrong deletes the wrong partition.
String escapeBlobKeyLike(String prefix) =>
    prefix.replaceAll('!', '!!').replaceAll('_', '!_').replaceAll('%', '!%');
