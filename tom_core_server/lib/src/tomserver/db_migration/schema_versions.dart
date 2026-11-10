/// Schema version skew: how the migration versions a node's code carries
/// compare with the versions a schema — the system schema's histories, or a
/// tenant's — has recorded, during a rolling deploy or after a partial run.
library;

/// How a schema's recorded versions stand against the code's.
enum TomSchemaSkew {
  /// Every history is at the code's version.
  current,

  /// A history is below the code's version: the code expects tables the
  /// schema does not have yet. Not served.
  behind,

  /// A history is above the code's version, and every migration in between is
  /// marked `-- tom:expand`: the schema only grew, the code still works on it.
  /// Served.
  aheadCompatible,

  /// A history is above the code's version and a migration in between is not
  /// marked expand — it removed or changed what this code reads. Not served.
  aheadIncompatible;

  /// Whether a schema in this state is served.
  bool get isServed =>
      this == TomSchemaSkew.current || this == TomSchemaSkew.aheadCompatible;
}

/// The comparison of one target — the system schema's histories, or one
/// tenant's — with the code: per history (`<datasource>/<schema>` for the
/// system schema, `<datasource>` for a tenant), the code's highest version,
/// the recorded one, and the lowest code version the recorded schema still
/// serves.
class TomSchemaVersionCheck {
  /// A check of [target].
  const TomSchemaVersionCheck(
    this.target,
    this.skew, {
    this.code = const {},
    this.recorded = const {},
    this.requires = const {},
  });

  /// The target: `system` or `tenant:<id>`.
  final String target;

  /// How it stands; the worst of its histories.
  final TomSchemaSkew skew;

  /// The highest version the code's tree carries, per history.
  final Map<String, int> code;

  /// The highest version the schema has recorded, per history; a history the
  /// schema has never been migrated by is absent.
  final Map<String, int> recorded;

  /// The lowest code version the recorded schema still serves, per history:
  /// the highest recorded migration not marked expand.
  final Map<String, int> requires;

  /// What was seen, for a log line or a readiness check: `current`, or each
  /// history that is not, with its versions.
  String get detail {
    if (skew == TomSchemaSkew.current) return 'current';
    return [
      skew.name,
      for (final history in code.keys)
        if ((recorded[history] ?? 0) != code[history])
          '$history: code ${code[history]}, schema '
              '${recorded[history] ?? 'none'}'
              '${requires.containsKey(history) ? ', requires ${requires[history]}' : ''}',
    ].join('; ');
  }

  @override
  String toString() => '$target: $detail';

  /// The marker of an expand migration: a leading comment line
  /// `-- tom:expand`. An expand migration only adds — a table, a nullable or
  /// defaulted column, an index — so the code of the release before it still
  /// works on the schema it leaves.
  static const String expandMarker = '-- tom:expand';

  /// Whether [script] is marked expand: one of its leading comment lines —
  /// before the first statement — is [expandMarker] (case and the space after
  /// `--` aside).
  static bool isExpand(String script) {
    for (final raw in script.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (!line.startsWith('--')) return false;
      final comment = line.substring(2).trim().toLowerCase();
      if (comment == 'tom:expand') return true;
    }
    return false;
  }

  /// The lowest code version a schema migrated by [scripts] (version → script)
  /// serves: the highest version whose script is not marked expand, `0` when
  /// every one is.
  static int requiredCodeVersion(Map<int, String> scripts) {
    var requires = 0;
    for (final MapEntry(key: version, value: script) in scripts.entries) {
      if (!isExpand(script) && version > requires) requires = version;
    }
    return requires;
  }

  /// How a history recorded at [recorded] — or never migrated, `null` — that
  /// serves code from [requires] stands against the code's [code].
  static TomSchemaSkew skewOf(int code, int? recorded, int? requires) {
    final schema = recorded ?? 0;
    if (schema < code) return TomSchemaSkew.behind;
    if (schema == code) return TomSchemaSkew.current;
    return (requires ?? schema) <= code
        ? TomSchemaSkew.aheadCompatible
        : TomSchemaSkew.aheadIncompatible;
  }

  /// The worst of [skews]: behind and ahead-incompatible before
  /// ahead-compatible before current.
  static TomSchemaSkew worst(Iterable<TomSchemaSkew> skews) {
    var result = TomSchemaSkew.current;
    for (final skew in skews) {
      if (_rank(skew) > _rank(result)) result = skew;
    }
    return result;
  }

  static int _rank(TomSchemaSkew skew) => switch (skew) {
    TomSchemaSkew.current => 0,
    TomSchemaSkew.aheadCompatible => 1,
    TomSchemaSkew.aheadIncompatible => 2,
    TomSchemaSkew.behind => 3,
  };
}
