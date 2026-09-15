import 'package:tom_core_kernel/tom_core_kernel.dart';
import '../datasources/queries.dart';
import '../datasources/sql_dialects.dart';
import '../datasources/types_operator.dart';
import '../little_things/server_exception.dart';
import 'persistence_annotations.dart';

/// Thrown when an entity's persistence metadata cannot be resolved (e.g. the
/// type is not registered with `tomReflector`, or has no `@TomDbTable`).
class TomAnnotationAnalyzerException extends TomServerException {
  /// Creates an annotation-analyzer exception.
  ///
  /// Never client-visible. Every failure this type reports is a wiring fault in
  /// the deployment — a type absent from the reflector, an entity without
  /// `@TomDbTable`, columns that could not be resolved — and its message quotes
  /// the entity type and the annotation it wanted. A caller can act on none of
  /// it, and a sentence compiled inside a served request would otherwise carry
  /// the deployment's shape back to whoever made that request.
  ///
  /// `clientThrow` is not a parameter, so that is an invariant of the type
  /// rather than the value it is born with — the same construction, and the
  /// same argument, as `TomResourceLocaleException`. As a re-defaulted
  /// parameter it would hide today's raise sites and stop nothing from asking
  /// to be shown tomorrow.
  TomAnnotationAnalyzerException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  }) : super(clientThrow: false);
}

/// Thrown when an entity's persistence annotations are present but malformed
/// (e.g. a `@TomDbColumn` on a non-variable declaration, or an unresolvable
/// column name).
class TomAnnotationAnalyzerSyntaxException extends TomServerException {
  /// Creates an annotation-analyzer syntax exception.
  ///
  /// Never client-visible, for the reason given on
  /// [TomAnnotationAnalyzerException] and with more force: this is the type
  /// that answers "No column match field [x] found. Must be a variable and must
  /// have @TomDbColumn annotation", which names a field of the entity and the
  /// annotation the deployment was expected to carry.
  ///
  /// A malformed *sentence* is a different matter and stays visible — see
  /// `TomQuerySyntaxException`. When the sentence came from a request it is the
  /// caller's own input, and naming the token that broke it tells them what to
  /// fix without describing the deployment.
  TomAnnotationAnalyzerSyntaxException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  }) : super(clientThrow: false);
}

/// Resolves the persistence metadata of an entity type from its reflection
/// annotations (`@TomDbTable`, `@TomDbColumn`, `@TomEntityId`, `@TomReference`).
///
/// Mixed into the typed-persistence base, its static methods read the
/// `tomReflector` [ClassMirror] of an entity and translate its annotations into
/// a [TomTypePersistenceInfo] / [TomColumnInformation]. Every result is memoised
/// per entity type and shared: a second call for the same type hands back the
/// very objects the first call returned.
///
/// That sharing is what makes the memos private and their column lists
/// unmodifiable. A resolved [TomColumnInformation] is immutable, so no holder
/// can edit one; the lists are handed out as unmodifiable views, so no holder
/// can add to or reorder one; and the memo maps are reachable from nowhere
/// else, so no caller can substitute a different answer for a type. Two
/// resolutions of the same entity therefore cannot be made to disagree, which
/// is the property the whole compile path assumes when it looks a column up
/// once and trusts it everywhere.
///
/// ## `null` is an answer here, not a failure
///
/// [findMirror], [findTable], [findDataScope] and [getPersistentColumns] each
/// return `null` for an ordinary reason — the type is not registered, carries
/// no `@TomDbTable`, declares no row scope, has no columns — and each memoises
/// that `null` alongside the answers. `containsKey` true with a `null` value is
/// therefore a *designed* state of every one of those maps, so a cache-hit path
/// must read the entry back as nullable.
///
/// Callers must not null-assert the result. `findTable(type)!` is a null check
/// written as an expression: where the caller has in fact established that the
/// type is mapped, it says so in a form that stops being true the moment the
/// branch above it moves, and where it has not, it reports `Null check operator
/// used on a null value` out of a static memo, naming neither the type nor the
/// annotation that was missing. A caller that knows the type is an entity
/// should ask [analysePersistentType], which returns a non-nullable
/// [TomTypePersistenceInfo] or names what is absent; one that is asking
/// *whether* it is should read the lookup into a local and test it.
/// `test/annotation_analyzer_null_memo_test.dart` pins both halves — the memoised
/// `null` reading back as `null`, and the absence of an assertion anywhere in
/// `lib/`.
mixin TomAnnotationAnalyzer {
  /// Cache of resolved class mirrors per entity type (`null` = not reflectable).
  static final _mirrorCache = <Type, ClassMirror?>{};

  /// Cache of resolved `@TomDbTable` annotations per entity type.
  static final _tableCache = <Type, TomDbTable?>{};

  /// Cache of resolved column metadata lists per entity type.
  static final _columnInfoCache = <Type, List<TomColumnInformation>?>{};

  /// Cache of resolved `@TomDbScope` annotations per entity type
  /// (`null` = the entity declares no row scope).
  static final _dataScopeCache = <Type, TomDbScope?>{};

  /// Cache of the column-authorized (`@TomDbColumn(authKey: …)`) columns per
  /// entity type (an empty list = the entity declares no column access rights).
  static final _authColumnCache = <Type, List<TomColumnInformation>>{};

  /// Cache of the file-reference (`@TomFileReference`) columns per entity type
  /// (an empty list = the entity references no stored files).
  static final _fileColumnCache = <Type, List<TomColumnInformation>>{};

  /// Discards every memoised answer, so the next resolution of any entity
  /// re-reads its reflection metadata. Intended for tests and for a re-boot.
  ///
  /// A server never needs this: an entity's annotations are fixed for the run.
  /// A test is the case that does — one that re-registers a fixture type it has
  /// already analysed, under a different mapping, otherwise reads the first
  /// answer back and fails as though the mapping were wrong. That failure is
  /// expensive to diagnose, because nothing about it points at a cache.
  ///
  /// Clearing all six together is the whole point: they are derived from one
  /// another — the columns come from the mirror, the row scope and the two
  /// column subsets come from the columns — so a caller emptying the ones it
  /// happens to know about would leave the rest describing an entity that no
  /// longer exists. `test/persistence_metadata_sharing_test.dart` asserts this
  /// method reaches every cache the mixin declares, including any added later.
  static void reset() {
    _mirrorCache.clear();
    _tableCache.clear();
    _columnInfoCache.clear();
    _dataScopeCache.clear();
    _authColumnCache.clear();
    _fileColumnCache.clear();
  }

  /// Resolves the full persistence metadata (table + columns) for entity [T].
  ///
  /// Throws [TomAnnotationAnalyzerException] if the type is not reflectable or
  /// has no table annotation, and [TomAnnotationAnalyzerSyntaxException] if its
  /// annotations are present but malformed — the two are separate because the
  /// first is a registration mistake and the second a declaration mistake, and
  /// they are fixed in different files.
  ///
  /// Each step names the missing thing rather than reporting the mechanism that
  /// noticed it. The three lookups answer `null` for their own ordinary reason,
  /// so a `null` here is a diagnosis, not an anomaly to be caught.
  static TomTypePersistenceInfo analysePersistentType(Type T) {
    final mirror = findMirror(T);
    if (mirror == null) {
      throw TomAnnotationAnalyzerException(
        "annotation_analyzer.analyse_persistent_type.mirror_not_found",
        "Failed to get ClassMirror for $T, it is not in tomReflector",
        parameters: {"type": "$T"},
      );
    }
    final table = findTable(T);
    if (table == null) {
      throw TomAnnotationAnalyzerException(
        "annotation_analyzer.analyse_persistent_type.table_not_found",
        "$T carries no @TomDbTable annotation, so there is no table to map "
            "it to",
        parameters: {"type": "$T"},
      );
    }
    final columns = getPersistentColumns(T);
    if (columns == null) {
      throw TomAnnotationAnalyzerException(
        "annotation_analyzer.analyse_persistent_type.columns_not_found",
        "Failed to resolve the persistent columns of $T",
        parameters: {"type": "$T"},
      );
    }
    return TomTypePersistenceInfo(mirror, table, columns);
  }

  /// Returns the cached/looked-up [ClassMirror] for [dbType], or `null` when it
  /// is not registered with `tomReflector`.
  ///
  /// `null` means one thing only: the reflector holds no mirror for [dbType].
  /// That is a normal answer — [findTable] and [getPersistentColumns] ask about
  /// types that may carry no persistence annotations at all — and it is the
  /// single failure this method absorbs, recognised by the
  /// [NoSuchCapabilityError] the reflector raises to say exactly that.
  ///
  /// Every other failure is reported as [TomAnnotationAnalyzerException] with
  /// the original as `rootException`. Absorbing them too would be cheap and
  /// actively harmful: this is the gate every entity's mapping passes through,
  /// so a swallowed error reappears one frame up as "it is not in tomReflector"
  /// — a diagnosis that is plausible, wrong, and sends the reader to the
  /// entity's annotations and its generated file, neither of which is at fault.
  /// The two it hides are the two worth hearing about. Reflection that was
  /// never initialized makes *every* type look unregistered, and the reflector
  /// raises a `StateError` naming the missing `initializeReflection()` call —
  /// the one sentence that would have ended the search. A name that resolves to
  /// something other than a class (`dynamic` and `void` are registered with
  /// every reflector that can reflect types, and a generic parameter that
  /// erased reaches here as `dynamic`) is likewise a caller-side mistake, not a
  /// gap in the reflection setup.
  static ClassMirror? findMirror(Type dbType) {
    if (_mirrorCache.containsKey(dbType)) return _mirrorCache[dbType];
    TypeMirror mirror;
    try {
      mirror = tomReflector.reflectType(dbType);
    } on NoSuchCapabilityError {
      _mirrorCache[dbType] = null;
      return null;
    } catch (error, stack) {
      throw TomAnnotationAnalyzerException(
        "annotation_analyzer.find_mirror.reflection_failed",
        "Failed to reflect $dbType: $error",
        parameters: {"type": "$dbType"},
        stack: stack,
        rootException: error,
      );
    }
    if (mirror is! ClassMirror) {
      throw TomAnnotationAnalyzerException(
        "annotation_analyzer.find_mirror.not_a_class",
        "$dbType is registered with tomReflector but is not a class "
            "(${mirror.runtimeType}), so it cannot carry persistence "
            "annotations",
        parameters: {"type": "$dbType"},
      );
    }
    _mirrorCache[dbType] = mirror;
    return mirror;
  }

  /// Returns the `@TomDbTable` annotation on [dbType], or `null` if absent.
  static TomDbTable? findTable(Type dbType) {
    if (_tableCache.containsKey(dbType)) return _tableCache[dbType];
    ClassMirror? mirror = findMirror(dbType);
    if (mirror != null) {
      for (var md in mirror.metadata) {
        if (md is TomDbTable) {
          _tableCache[dbType] = md;
          return md;
        }
      }
    }
    _tableCache[dbType] = null;
    return null;
  }

  /// The column name (and its camelCase field spelling) that marks an entity as
  /// carrying a resource key, and so as automatically grant-scoped.
  static const String resourceKeyColumn = 'resource_key';

  /// The camelCase entity-field spelling of [resourceKeyColumn].
  static const String resourceKeyField = 'resourceKey';

  /// The framework's own authorization tables — the ones the resource scope
  /// reads in order to *compute* itself — which are therefore never
  /// auto-scoped.
  ///
  /// They all carry a [resourceKeyColumn], so without this guard each would
  /// match [autoScopeFor] and filter itself: a principal could reach its own
  /// grant rows only by already holding a grant on them, which no row can
  /// satisfy, and the authorization layer would resolve to nothing at all.
  ///
  /// The entities also declare `@TomDbScope.unscoped()`, which is the readable
  /// statement of the same fact. This set is the one that survives a **stale
  /// generated `*.reflection.dart`**, whose class metadata predates the
  /// annotation — a safety invariant of the framework must not depend on a
  /// deployment having re-run code generation before it upgrades.
  ///
  /// The names are duplicated from the entities' `@TomDbTable` annotations
  /// rather than imported, because `authorization` depends on
  /// `object_persistence` and not the other way round;
  /// `test/resource_data_scope_test.dart` asserts the two agree.
  static const Set<String> resourceScopeInputTables = {
    'tom_principal_resource_grant',
    'tom_principal_delegation',
    'tom_resource_grant',
  };

  /// Returns the row-level data scope of [dbType], or `null` when the entity is
  /// unscoped.
  ///
  /// Resolution order:
  ///
  ///  1. an explicit `@TomDbScope` on the class wins — including
  ///     `@TomDbScope.unscoped()`, the deliberate opt-out, for which this
  ///     returns `null`;
  ///  2. otherwise, an entity carrying a resource-key column is scoped
  ///     automatically under [TomDbScope.resourceScope] — see [autoScopeFor];
  ///  3. otherwise the entity is unscoped.
  ///
  /// Step 2 is why grant-driven scoping is the *default*: an entity that models
  /// a grantable resource is filtered by the principal's grants without anyone
  /// remembering to annotate it, and forgetting the annotation can no longer
  /// silently publish every row.
  static TomDbScope? findDataScope(Type dbType) {
    if (_dataScopeCache.containsKey(dbType)) return _dataScopeCache[dbType];
    ClassMirror? mirror = findMirror(dbType);
    if (mirror != null) {
      for (var md in mirror.metadata) {
        if (md is TomDbScope) {
          final declared = md.isOptOut ? null : md;
          _dataScopeCache[dbType] = declared;
          return declared;
        }
      }
    }
    final auto = autoScopeFor(getPersistentColumns(dbType) ?? const []);
    _dataScopeCache[dbType] = auto;
    return auto;
  }

  /// The scope an entity with these [columns] carries implicitly, or `null` if
  /// it carries none.
  ///
  /// An entity is implicitly grant-scoped when one of its persistent columns is
  /// a resource key — the column named [resourceKeyColumn] (or declared as
  /// [resourceKeyField]). That column holds exactly the value the C-5 grant and
  /// C-6 delegation rows key on, so the rows it identifies are precisely the
  /// ones a grant admits; the synthesized annotation is identical to the one a
  /// developer would have written by hand, which keeps `@TomDbScope` the single
  /// declaration mechanism rather than adding a parallel one.
  ///
  /// The framework's own [resourceScopeInputTables] are excluded: they carry a
  /// resource key but *are* the scope's input, so scoping them would close the
  /// authorization layer against itself.
  ///
  /// The exclusion is settled once, before any column is examined, because it
  /// is a fact about the entity and not about a column: every element of a
  /// resolved column list carries the one `@TomDbTable` of the type it was
  /// resolved from — see `test/persistence_metadata_sharing_test.dart`. Asking
  /// per column would give the same answer while reading as though it might
  /// not, which for this guard is the expensive kind of ambiguity: whether a
  /// grant table gets scoped would appear to depend on where its resource key
  /// sits in the list.
  static TomDbScope? autoScopeFor(List<TomColumnInformation> columns) {
    if (columns.any(
      (column) => resourceScopeInputTables.contains(column.table.table),
    )) {
      return null;
    }
    for (final column in columns) {
      final name = column.getQueryFieldName();
      if (name.toLowerCase() == resourceKeyColumn ||
          column.declaredName == resourceKeyField) {
        return TomDbScope(field: name, scope: TomDbScope.resourceScope);
      }
    }
    return null;
  }

  /// Returns the columns of [dbType] that opt into column-level access rights
  /// (C-4) — those with a [TomColumnInformation.authKey], from a
  /// `@TomDbColumn(authKey:)` or a `@TomProtectedField` — or an empty list when
  /// the entity declares none.
  ///
  /// Cached per type. An empty result lets a repository skip all C-4 work for
  /// entities that declare no column access rights (zero overhead by default).
  static List<TomColumnInformation> findAuthColumns(Type dbType) {
    final cached = _authColumnCache[dbType];
    if (cached != null) return cached;
    final columns = getPersistentColumns(dbType) ?? const [];
    final result = List<TomColumnInformation>.unmodifiable([
      for (final column in columns)
        if (column.authKey != null) column,
    ]);
    _authColumnCache[dbType] = result;
    return result;
  }

  /// Returns the columns of [dbType] that hold a blob storage key — those
  /// annotated `@TomFileReference` — or an empty list when the entity
  /// references no stored files.
  ///
  /// Cached per type, and consulted before *any* file work is done, so an
  /// entity that stores no files never pays for the feature: no extra read on
  /// update, no select-before-delete, no store resolution.
  static List<TomColumnInformation> findFileColumns(Type dbType) {
    final cached = _fileColumnCache[dbType];
    if (cached != null) return cached;
    final columns = getPersistentColumns(dbType) ?? const [];
    final result = List<TomColumnInformation>.unmodifiable([
      for (final column in columns)
        if (column.fileReference != null) column,
    ]);
    _fileColumnCache[dbType] = result;
    return result;
  }

  /// The [TomDbType] boxes an entity may declare, mapped to their type family.
  static const Map<Type, TomSqlTypeFamily> _boxFamilies = {
    TomDbInt: TomSqlTypeFamily.integer,
    TomDbDouble: TomSqlTypeFamily.decimal,
    TomDbString: TomSqlTypeFamily.text,
    TomDbBool: TomSqlTypeFamily.boolean,
    TomDbDateTime: TomSqlTypeFamily.dateTime,
    TomDbDate: TomSqlTypeFamily.date,
    TomDbTime: TomSqlTypeFamily.time,
  };

  /// The Dart types a mapped field may have when no [TomDbType] box is declared.
  static const Map<Type, TomSqlTypeFamily> _dartFamilies = {
    int: TomSqlTypeFamily.integer,
    double: TomSqlTypeFamily.decimal,
    num: TomSqlTypeFamily.decimal,
    String: TomSqlTypeFamily.text,
    bool: TomSqlTypeFamily.boolean,
    DateTime: TomSqlTypeFamily.dateTime,
    TomZonedDate: TomSqlTypeFamily.date,
    TomZonedTime: TomSqlTypeFamily.time,
  };

  /// The type family [column] is stored in.
  ///
  /// A JSON column is text whatever its Dart type — the value is encoded before
  /// it reaches the database. Otherwise the declared [TomDbType] box decides,
  /// and only when there is none does the Dart type stand in. An unrecognised
  /// type (an enum behind a converter, say) yields [TomSqlTypeFamily.unknown],
  /// which is compatible with everything: a gap in the caller's knowledge must
  /// not be reported as a defect in the schema.
  ///
  /// Homed here rather than with either consumer because both the
  /// schema-convergence check and the reflected export projection ask the same
  /// question of the same annotations, and a second answer would be a second
  /// thing to keep in step. Note what it describes: how a value is *stored*.
  /// The Dart value a getter returns can differ — a JSON column is a `Map` in
  /// Dart and text in the database — so a consumer that cares about the Dart
  /// value must check [TomColumnInformation.declaredType] as well.
  static TomSqlTypeFamily familyOf(TomColumnInformation column) {
    if (column.column?.isJson ?? false) return TomSqlTypeFamily.text;
    final boxed = column.column?.declaredColumnType();
    if (boxed != null) {
      final family = _boxFamilies[boxed];
      if (family != null) return family;
    }
    final dartType = column.column?.declaredDartType() ?? column.declaredType;
    return _dartFamilies[dartType] ?? TomSqlTypeFamily.unknown;
  }

  /// How [column]'s type is spelled on the entity side, for reporting only.
  static String describeDeclaredType(TomColumnInformation column) {
    if (column.column?.isJson ?? false) return 'JSON';
    final boxed = column.column?.declaredColumnType();
    if (boxed != null && _boxFamilies.containsKey(boxed)) return '$boxed';
    return '${column.column?.declaredDartType() ?? column.declaredType}';
  }

  /// Returns the persistence metadata for every annotated field of [dbType]
  /// (each `@TomDbColumn` / `@TomReference`), or `null` if [dbType] is not
  /// reflectable. Throws [TomAnnotationAnalyzerSyntaxException] for an
  /// annotation on a non-variable declaration.
  ///
  /// Resolved once per type and then shared: every caller for the same entity
  /// receives the same unmodifiable list of the same immutable
  /// [TomColumnInformation] objects. Callers that need a list of their own — to
  /// filter, sort or extend — must copy it.
  static List<TomColumnInformation>? getPersistentColumns(Type dbType) {
    if (_columnInfoCache.containsKey(dbType)) {
      return _columnInfoCache[dbType];
    }
    ClassMirror? mirror = findMirror(dbType);
    if (mirror != null) {
      List<TomColumnInformation> result = [];
      for (var dEntry in mirror.declarations.entries) {
        Object? tbcObject = dEntry.value.metadata.firstWhere(
          (md) => (md is TomDbColumn || md is TomReference),
          orElse: () => Object(),
        );
        if (tbcObject is TomDbColumn) {
          // only look at declarations with TomDbColumn annotations
          if (dEntry.value is VariableMirror) {
            result.add(
              _getColumnInfo(
                dbType,
                dEntry.value as VariableMirror,
                dEntry.key,
                tbcObject.columnName,
              ),
            );
          } else {
            throw TomAnnotationAnalyzerSyntaxException(
              "annotation_analyzer.get_persistent_columns.invalid_declaration_not_variable",
              "Cannot analyse field ${dEntry.key}, declaration is not a variable declaration.",
            );
          }
        } else if (tbcObject is TomReference) {
          Object? tbcObject2 = dEntry.value.metadata.firstWhere(
            (md) => md is TomDbColumn,
            orElse: () => Object(),
          );
          if (dEntry.value is VariableMirror) {
            result.add(
              _getColumnInfo(
                dbType,
                dEntry.value as VariableMirror,
                dEntry.key,
                tbcObject2 is TomDbColumn ? tbcObject2.columnName : dEntry.key,
              ),
            );
          } else {
            throw TomAnnotationAnalyzerSyntaxException(
              "annotation_analyzer.get_persistent_columns.invalid_declaration_not_variable_for_reference",
              "Cannot analyse field ${dEntry.key}, declaration is not a variable declaration.",
            );
          }
        }
      }
      final columns = List<TomColumnInformation>.unmodifiable(result);
      _columnInfoCache[dbType] = columns;
      return columns;
    } else {
      _columnInfoCache[dbType] = null;
      return null;
    }
  }

  static TomColumnInformation _getColumnInfo(
    Type dbType,
    VariableMirror decl,
    String declaredName,
    String? field,
  ) {
    TomDbColumn? column;
    TomEntityId? entityId;
    TomReference? reference;
    TomFileReference? fileReference;
    TomProtectedField? protectedField;
    for (var md in decl.metadata) {
      if (md is TomDbColumn) {
        column = md;
      } else if (md is TomEntityId) {
        entityId = md;
      } else if (md is TomReference) {
        reference = md;
      } else if (md is TomFileReference) {
        fileReference = md;
      } else if (md is TomProtectedField) {
        protectedField = md;
      }
    }
    column ??= TomDbColumn(columnName: field);
    TomDbTable? table = findTable(dbType);
    if (table != null) {
      return TomColumnInformation(
        tableType: dbType,
        table: table,
        declaredType: decl.reflectedType,
        declaredName: declaredName,
        field: field ?? declaredName,
        column: column,
        entityId: entityId,
        reference: reference,
        fileReference: fileReference,
        protectedField: protectedField,
      );
    } else {
      throw TomAnnotationAnalyzerException(
        "annotation_analyzer.get_persistent_columns.no_table_info",
        "No table info for $dbType when trying to get column info",
      );
    }
  }

  /// Finds the [TomColumnInformation] matching [name] across [persistenceInfo],
  /// trying in order: fully-qualified `table.column`, `type.field`, the query
  /// field name, then a case-insensitive field-name match. Throws
  /// [TomAnnotationAnalyzerSyntaxException] when nothing matches.
  static TomColumnInformation determineColumn(
    String name,
    List<TomTypePersistenceInfo> persistenceInfo,
  ) {
    for (var tci in persistenceInfo) {
      for (var tc in tci.columnInfo) {
        if ("${tc.table.table}.${tc.getQueryFieldName()}" == name) {
          return tc;
        }
      }
    }
    for (var tci in persistenceInfo) {
      for (var tc in tci.columnInfo) {
        if ("${tc.tableType}.${tc.declaredName}" == name) {
          return tc;
        }
      }
    }
    for (var tci in persistenceInfo) {
      for (var tc in tci.columnInfo) {
        if (tc.getQueryFieldName() == name) {
          return tc;
        }
      }
    }
    for (var tci in persistenceInfo) {
      for (var tc in tci.columnInfo) {
        if (tc.declaredName.toUpperCase() == name.toUpperCase()) {
          return tc;
        }
      }
    }
    throw TomAnnotationAnalyzerSyntaxException(
      "annotation_analyzer.determine_column.no_column_match",
      "No column match field [$name] found. Must be a variable and must have @TomDbColumn annotation.'}",
    );
  }

  /// The `FIND BY` sentence that resolves [reference] for one already-mapped
  /// row of [owningType], together with the parameters it binds.
  ///
  /// A `@TomReference` is not a column: it is read by a *second* query over the
  /// join entity, issued once the owning row exists, and this builds that
  /// query's text. Its three column lists are three different kinds of term,
  /// which is why they cannot be written as one list:
  ///
  ///  * [TomReference.leftSideColumns] tie the join row to *this* row, so the
  ///    owner side is a value known only at read time. Written
  ///    `Join.field=Owner.field`, they are emitted as a bound parameter named
  ///    after the owner field — the value never reaches the statement text.
  ///  * [TomReference.rightSideColumns] tie the join row to the target row.
  ///    Both sides are columns, so the term is emitted verbatim.
  ///  * [TomReference.contextColumns] tie the join row to an ambient value —
  ///    the tenant, the application. Written `Join.field=:name`, they bind
  ///    `:name` from the [TomExecutionContext] installed in the current zone.
  ///
  /// [readOwningField] reads a field of the mapped row by its *declared* name.
  /// The caller holds the instance, so the read is passed in rather than the
  /// object; that is also what lets this be exercised without a database.
  ///
  /// Throws [TomAnnotationAnalyzerSyntaxException] when an expression is
  /// malformed — an authoring error in the annotation, and always reported
  /// ahead of any context lookup — and [TomAnnotationAnalyzerException] when a
  /// well-formed expression names a context value the running zone cannot
  /// supply.
  static ({String sentence, Map<String, Object?> parameters}) referenceQuery(
    TomReference reference,
    Type owningType,
    Object? Function(String field) readOwningField,
  ) {
    final terms = <String>[];
    final parameters = <String, Object?>{};
    final ownerPrefix = "$owningType.";

    for (final expression in reference.leftSideColumns) {
      final (left, right) = _referenceExpressionSides(
        expression,
        "left_side",
        "Join.field=$ownerPrefix<field>",
      );
      if (left.startsWith(ownerPrefix)) {
        throw TomAnnotationAnalyzerSyntaxException(
          "annotation_analyzer.reference_query.left_side_owner_on_left",
          "Invalid leftSideColumns expression [$expression]: the value from"
              " $owningType must be on the right, [$left] is on the left.",
          parameters: {"expression": expression, "part": left},
        );
      }
      if (!right.startsWith(ownerPrefix)) {
        throw TomAnnotationAnalyzerSyntaxException(
          "annotation_analyzer.reference_query.left_side_owner_missing",
          "Invalid leftSideColumns expression [$expression]: the right side"
              " [$right] must name a field of $owningType.",
          parameters: {"expression": expression, "part": right},
        );
      }
      final parameter = right.substring(ownerPrefix.length);
      terms.add("$left = :$parameter");
      parameters[parameter] = readOwningField(parameter);
    }

    terms.addAll(reference.rightSideColumns);

    for (final expression in reference.contextColumns) {
      final (left, right) = _referenceExpressionSides(
        expression,
        "context",
        "Join.field=:name",
      );
      if (left.startsWith(":")) {
        throw TomAnnotationAnalyzerSyntaxException(
          "annotation_analyzer.reference_query.context_value_on_left",
          "Invalid contextColumns expression [$expression]: the context value"
              " must be on the right, [$left] is on the left.",
          parameters: {"expression": expression, "part": left},
        );
      }
      if (!right.startsWith(":")) {
        throw TomAnnotationAnalyzerSyntaxException(
          "annotation_analyzer.reference_query.context_value_missing",
          "Invalid contextColumns expression [$expression]: the right side"
              " [$right] must name a context entry and start with a colon.",
          parameters: {"expression": expression, "part": right},
        );
      }
      final parameter = right.substring(1);
      final context = getFromCurrentZone<TomExecutionContext>();
      if (context == null) {
        throw TomAnnotationAnalyzerException(
          "annotation_analyzer.reference_query.no_execution_context",
          "No TomExecutionContext installed in the current zone, so the"
              " context value [$parameter] required by [$expression] cannot be"
              " read. Not running in context.",
          parameters: {"expression": expression, "paramName": parameter},
        );
      }
      final entry = context.contextMap[parameter];
      if (entry == null) {
        throw TomAnnotationAnalyzerException(
          "annotation_analyzer.reference_query.context_entry_not_found",
          "No context entry for [$parameter] found. Entries are:"
              " ${context.contextMap.keys.toList()}",
          parameters: {"expression": expression, "paramName": parameter},
        );
      }
      terms.add(expression);
      parameters[parameter] = entry.value;
    }

    if (terms.isEmpty) {
      throw TomAnnotationAnalyzerSyntaxException(
        "annotation_analyzer.reference_query.no_terms",
        "The reference to ${reference.targetEntity} via"
            " ${reference.joinEntity} declares no columns at all, so it"
            " constrains nothing and would load every row of the join.",
        parameters: {
          "targetEntity": reference.targetEntity,
          "joinEntity": reference.joinEntity,
        },
      );
    }

    return (sentence: "FIND BY ${terms.join(' AND ')}", parameters: parameters);
  }

  /// Splits a `left=right` reference expression of [kind] into its two sides.
  ///
  /// [expected] is the shape the expression should have had, quoted back in the
  /// message: the lists are strings in an annotation, so a typo is caught here
  /// rather than by the compiler, and the error has to say what was wanted.
  static (String, String) _referenceExpressionSides(
    String expression,
    String kind,
    String expected,
  ) {
    final sides = expression.split("=");
    if (sides.length != 2) {
      throw TomAnnotationAnalyzerSyntaxException(
        "annotation_analyzer.reference_query.${kind}_not_a_pair",
        "Invalid ${kind}Columns expression [$expression]: expected exactly one"
            " '=', as in [$expected].",
        parameters: {"expression": expression},
      );
    }
    return (sides[0], sides[1]);
  }
}
