import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../datasources/types_operator.dart';
import '../little_things/server_exception.dart';
import 'persistence_annotations.dart';
import 'query_builder.dart';

/// Thrown when a `@TomDbScope` names a scope kind that no resolver is
/// registered for in [TomDataScopeRegistry].
class TomDataScopeException extends TomServerException {
  /// Creates a data-scope exception.
  TomDataScopeException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

/// Thrown when a write (save/update/delete) targets a row outside the current
/// principal's `@TomDbScope` (C-3 write enforcement).
///
/// The read paths *filter* out-of-scope rows; a write names a specific row (or
/// creates one), so the correct response is to *reject* — a principal must not
/// update or delete a row it could not itself read, nor create a row scoped to
/// a value it is not allowed. Raising this (rather than silently affecting zero
/// rows) makes the violation explicit to the caller.
class TomDataScopeAuthorizationException extends TomServerException {
  /// Creates a data-scope write-authorization exception.
  TomDataScopeAuthorizationException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
    super.clientThrow,
  });
}

/// Maps the current [TomPrincipal] to the set of scope-field values it is
/// allowed to see for a given scope kind.
///
/// Returning an empty list denies every row (the principal sees nothing);
/// returning `null` opts out of scoping entirely (every row is visible). A
/// `null` principal (unauthenticated request) is handled by each resolver — the
/// built-in resolvers treat it as "no allowed values" (deny), which is the
/// secure default.
typedef TomDataScopeResolver = List<Object?>? Function(TomPrincipal? principal);

/// Maps the current [TomPrincipal] to the **union of id-sets** it is allowed to
/// see for a given scope kind, resolved *asynchronously* (e.g. by querying a
/// second database for share-mode delegations).
///
/// Where a [TomDataScopeResolver] renders a single `<col> IN (…)` AND-predicate,
/// an async resolver contributes an OR of one `IN` list per group, so the row
/// scope can be the **union** of independently-computed id-sets (owned ids ∪
/// shared-via-containment ids) rather than a single intersecting set. Each inner
/// list is one id-set; the groups are OR-ed together (their union is the visible
/// set). The interpretation of the outer result mirrors the sync resolver:
///
///  - `null` opts out of scoping entirely (every row visible);
///  - an empty outer list denies every row (deny-all — the secure default a
///    `null` principal resolves to);
///  - `[[a, b], [c]]` renders `(<col> IN (a, b) OR <col> IN (c))`;
///  - `[[a, b]]` renders the plain `<col> IN (a, b)` (a single group, no OR).
typedef TomAsyncDataScopeResolver =
    Future<List<List<Object?>>?> Function(TomPrincipal? principal);

/// The grant-driven source behind the built-in `resource` scope kind
/// ([TomDbScope.resourceScope]).
///
/// The resource scope filters rows by the resource keys a principal holds a
/// grant for — direct ownership grants folded with the share/absence
/// delegations that are active right now. Resolving that needs the
/// authorization layer (grant store, delegation resolver, role registry), which
/// sits *above* persistence; this interface is the inversion that keeps the
/// dependency pointing the right way. `object_persistence` declares the hook,
/// `authorization` implements and installs it
/// (`TomResourceDataScope.install`).
///
/// While no source is installed the built-in resolver denies every row: an
/// unwired scope must be a closed door, not an open one.
abstract class TomResourceScopeSource {
  /// The resource keys [principal] may **read** — grade `read` or `full`.
  Future<List<Object?>> readableResourceKeys(TomPrincipal? principal);

  /// The resource keys [principal] may **write** — grade `full` only, so a
  /// `read` grant admits a row to queries but rejects every write to it.
  Future<List<Object?>> writableResourceKeys(TomPrincipal? principal);
}

/// Registry of the named row-scope resolvers a `@TomDbScope` can reference.
///
/// Three resolvers are registered out of the box:
///
///  - `'owner'` — the principal's own id (`principal.id`); a `null` principal
///    sees nothing;
///  - `'group'` — the principal's groups (`principal.aci.groups`); a `null`
///    principal sees nothing;
///  - `'resource'` ([TomDbScope.resourceScope]) — the resource keys the
///    principal holds a grant for, resolved asynchronously through the
///    installed [resourceScopeSource]; denies every row while no source is
///    installed.
///
/// Applications register their own scope kinds (e.g. `'organization'`,
/// `'tenant'`) via [register] (synchronous, single AND-predicate) or
/// [registerAsync] (asynchronous, union/OR predicate over multiple id-sets);
/// [reset] restores just the built-ins (used by tests to undo custom
/// registrations).
///
/// A scope kind is resolved by *one* seam: [isAsync] tells the repository which
/// path to take. Registering an async resolver for a kind already registered
/// synchronously (or vice versa) is not meaningful — a kind is either a sync
/// value-list scope or an async union scope, and the two maps are kept disjoint
/// by the callers (a kind is registered in exactly one of them).
///
/// Each kind may additionally register a **write** resolver. It answers a
/// narrower question than the read resolver — "which values may this principal
/// *modify*" as opposed to "which may it *see*" — and the two genuinely differ:
/// the `resource` scope admits a `read`-graded key to queries but rejects every
/// write to it, and an application scope ("may read every tenant, may write only
/// my own") has the same shape. A kind with no write resolver writes exactly
/// what it reads, which is what every scope did before the seam existed.
class TomDataScopeRegistry {
  TomDataScopeRegistry._();

  static Map<String, TomDataScopeResolver> _defaults() => {
    'owner': (principal) =>
        principal == null ? const <Object?>[] : <Object?>[principal.id],
    'group': (principal) =>
        principal == null ? const <Object?>[] : principal.aci.groups,
  };

  static Map<String, TomAsyncDataScopeResolver> _asyncDefaults() => {
    TomDbScope.resourceScope: (principal) async {
      final source = resourceScopeSource;
      if (source == null) return const <List<Object?>>[];
      return [await source.readableResourceKeys(principal)];
    },
  };

  static Map<String, TomAsyncDataScopeResolver> _asyncWriteDefaults() => {
    TomDbScope.resourceScope: (principal) async {
      final source = resourceScopeSource;
      if (source == null) return const <List<Object?>>[];
      return [await source.writableResourceKeys(principal)];
    },
  };

  /// The installed grant source backing the built-in `resource` scope kind, or
  /// `null` while none is installed (in which case the scope denies every row).
  ///
  /// Installed by `TomResourceDataScope.install` from the authorization layer;
  /// deliberately *not* cleared by [reset], which restores scope-kind
  /// registrations rather than tearing down the deployment's wiring.
  static TomResourceScopeSource? resourceScopeSource;

  static final Map<String, TomDataScopeResolver> _resolvers = _defaults();

  static final Map<String, TomDataScopeResolver> _writeResolvers = {};

  static final Map<String, TomAsyncDataScopeResolver> _asyncResolvers =
      _asyncDefaults();

  static final Map<String, TomAsyncDataScopeResolver> _asyncWriteResolvers =
      _asyncWriteDefaults();

  /// Registers (or replaces) the synchronous [resolver] for the scope kind
  /// [scope], optionally with a narrower [write] resolver naming the values the
  /// principal may modify (defaulting to the readable values when omitted).
  static void register(
    String scope,
    TomDataScopeResolver resolver, {
    TomDataScopeResolver? write,
  }) {
    _resolvers[scope] = resolver;
    if (write == null) {
      _writeResolvers.remove(scope);
    } else {
      _writeResolvers[scope] = write;
    }
  }

  /// Registers (or replaces) the asynchronous [resolver] for the scope kind
  /// [scope] — the union/OR path a shared-entity scope uses to fold ownership
  /// and share-mode delegations resolved from another database into one visible
  /// id-set (RCB8) — optionally with a narrower [write] resolver.
  static void registerAsync(
    String scope,
    TomAsyncDataScopeResolver resolver, {
    TomAsyncDataScopeResolver? write,
  }) {
    _asyncResolvers[scope] = resolver;
    if (write == null) {
      _asyncWriteResolvers.remove(scope);
    } else {
      _asyncWriteResolvers[scope] = write;
    }
  }

  /// The synchronous resolver for scope kind [scope], or `null` if none is
  /// registered.
  static TomDataScopeResolver? resolverFor(String scope) => _resolvers[scope];

  /// The synchronous **write** resolver for scope kind [scope], or `null` when
  /// the kind writes exactly what it reads.
  static TomDataScopeResolver? writeResolverFor(String scope) =>
      _writeResolvers[scope];

  /// The asynchronous resolver for scope kind [scope], or `null` if none is
  /// registered.
  static TomAsyncDataScopeResolver? asyncResolverFor(String scope) =>
      _asyncResolvers[scope];

  /// The asynchronous **write** resolver for scope kind [scope], or `null` when
  /// the kind writes exactly what it reads.
  static TomAsyncDataScopeResolver? asyncWriteResolverFor(String scope) =>
      _asyncWriteResolvers[scope];

  /// Whether scope kind [scope] resolves asynchronously (registered via
  /// [registerAsync]). The repository dispatches on this to pick the async
  /// union path over the synchronous value-list path.
  static bool isAsync(String scope) => _asyncResolvers.containsKey(scope);

  /// Restores the built-in resolvers, discarding any custom registrations
  /// (synchronous *and* asynchronous, read *and* write).
  static void reset() {
    _resolvers
      ..clear()
      ..addAll(_defaults());
    _writeResolvers.clear();
    _asyncResolvers
      ..clear()
      ..addAll(_asyncDefaults());
    _asyncWriteResolvers
      ..clear()
      ..addAll(_asyncWriteDefaults());
  }
}

/// A resolved row-scope predicate: the boolean [predicate] to AND into a
/// query's `WHERE`, plus the [parameters] the predicate binds (one entry per
/// allowed scope value, keyed by the placeholder name).
class TomDataScopePredicate {
  /// The predicate (`<field> IN (:__tomscope_0, …)` or a `FALSE` deny literal).
  final TomOperator<TomDbBool> predicate;

  /// The bind values for the predicate's parameters, keyed by placeholder name.
  final Map<String, Object?> parameters;

  /// Bundles a scope [predicate] with the [parameters] it binds.
  TomDataScopePredicate(this.predicate, this.parameters);
}

/// A zone marker that suppresses row-scope resolution for the reads performed
/// inside it (installed by [TomDataScope.runUnscoped]).
///
/// An **async** data-scope resolver (RCB8) enumerates a principal's visible
/// id-set by reading the very entities it scopes — walking the containment tree
/// through the same repositories. Those nested reads must **not** re-enter scope
/// resolution, or the resolver would recurse into itself indefinitely. A
/// resolver runs its enumeration inside [TomDataScope.runUnscoped], which places
/// this marker in the zone; the repository's scope resolution opts out whenever
/// it is present.
class TomDataScopeBypass {
  /// Creates the bypass marker (a plain sentinel; its mere presence in the zone
  /// is the signal).
  const TomDataScopeBypass();
}

/// Builds the row-scope predicate for an entity's `@TomDbScope` from the
/// current principal's allowed values, using one bound parameter per value.
class TomDataScope {
  TomDataScope._();

  /// The prefix of the generated scope parameter names (`__tomscope_0`, …),
  /// chosen so it cannot collide with an application's own bind names.
  static const String parameterPrefix = '__tomscope_';

  /// Whether the current zone suppresses row-scope resolution — i.e. we are
  /// inside a [runUnscoped] body (an async resolver enumerating its own visible
  /// set). The repository consults this before resolving a scope so the
  /// resolver's enumeration reads do not re-enter scope resolution.
  static bool get isBypassed =>
      getFromCurrentZone<TomDataScopeBypass>() != null;

  /// Runs [body] with row-scope resolution suppressed for every read it
  /// performs (RCB8). An async data-scope resolver wraps its containment
  /// enumeration in this so the reads that *compute* the visible id-set are not
  /// themselves re-scoped — the guard against unbounded resolver recursion.
  static Future<T> runUnscoped<T>(Future<T> Function() body) => runZoned(
    body,
    zoneValues: const {TomDataScopeBypass: TomDataScopeBypass()},
  );

  /// Builds the scope predicate for [scope] on column [col] from [principal]'s
  /// allowed values, resolved through [TomDataScopeRegistry].
  ///
  /// Returns:
  ///  - `null` when the resolver opts out (its result is `null`) — no scoping;
  ///  - a `FALSE` predicate when the principal has no allowed values — deny all
  ///    (avoids emitting the syntactically invalid `IN ()`);
  ///  - `<col> IN (:__tomscope_0, …)` otherwise, one bound [Parameter] per
  ///    value so no value is concatenated into the SQL (C-7).
  ///
  /// Throws [TomDataScopeException] if `scope.scope` names an unregistered kind.
  /// Pass [forWrite] to resolve the (possibly narrower) set the principal may
  /// *modify* rather than the set it may see.
  static TomDataScopePredicate? build(
    TomQueryBuilder builder,
    TomDbScope scope,
    TomColumnInformation col,
    TomPrincipal? principal, {
    bool forWrite = false,
  }) {
    final values = allowedValues(scope, principal, forWrite: forWrite);
    if (values == null) return null;
    return inList(builder, col, values);
  }

  /// Builds the row-scope predicate for an **async** [scope] on column [col]
  /// from [principal]'s allowed id-sets, resolved through the async resolver
  /// registered in [TomDataScopeRegistry] (RCB8).
  ///
  /// Returns:
  ///  - `null` when the resolver opts out (its result is `null`) — no scoping;
  ///  - a `FALSE` predicate when the resolver denies every row (empty result);
  ///  - the union predicate [anyOf] renders otherwise — `<col> IN (…)` for a
  ///    single id-set, or `(<col> IN (…) OR <col> IN (…))` when the resolver
  ///    contributes several id-sets (owned ids ∪ shared-via-containment ids).
  ///
  /// Throws [TomDataScopeException] if `scope.scope` names a kind no async
  /// resolver is registered for.
  /// Pass [forWrite] to resolve the (possibly narrower) set the principal may
  /// *modify* rather than the set it may see.
  static Future<TomDataScopePredicate?> buildAsync(
    TomQueryBuilder builder,
    TomDbScope scope,
    TomColumnInformation col,
    TomPrincipal? principal, {
    bool forWrite = false,
  }) async {
    final groups = await _asyncGroups(scope, principal, forWrite: forWrite);
    if (groups == null) return null;
    return anyOf(builder, col, groups);
  }

  /// Resolves the raw id-set groups for an async [scope], honouring the write
  /// resolver when [forWrite] is set (falling back to the read resolver when the
  /// kind registers none).
  static Future<List<List<Object?>>?> _asyncGroups(
    TomDbScope scope,
    TomPrincipal? principal, {
    required bool forWrite,
  }) async {
    final resolver =
        (forWrite
            ? TomDataScopeRegistry.asyncWriteResolverFor(scope.scope)
            : null) ??
        TomDataScopeRegistry.asyncResolverFor(scope.scope);
    if (resolver == null) {
      throw TomDataScopeException(
        'data_scope.build.unknown_async_scope',
        'No async data-scope resolver registered for scope kind '
            '"${scope.scope}" (field "${scope.field}"). Register one with '
            'TomDataScopeRegistry.registerAsync.',
      );
    }
    return resolver(principal);
  }

  /// Builds the **union** predicate over the id-set [groups] for column [col]:
  /// an OR of one `<col> IN (…)` list per group, so the visible set is the
  /// union of the groups (owned ids ∪ shared-via-containment ids) rather than
  /// their intersection (RCB8 (b)).
  ///
  /// An empty [groups] renders a `FALSE` deny-all predicate (no group can match
  /// any row). A single group renders the plain `IN` list — no `OR` wrapper —
  /// so the common one-set case is identical to [inList]. Each group's
  /// placeholders are namespaced by its index (`__tomscope_0_`, `__tomscope_1_`,
  /// …) on top of the shared [parameterPrefix], so the OR-ed `IN` lists cannot
  /// collide on bind names, and every value still rides the prepared-statement
  /// protocol as a bound parameter (C-7).
  ///
  /// A multi-group union is wrapped in an explicit parenthesis group. The
  /// caller ANDs this predicate into a larger `WHERE` (`base AND <scope>`); an
  /// unparenthesised `a OR b` would bind as `(base AND a) OR b`, letting the
  /// second id-set escape the base filter and leak rows. Grouping makes the
  /// union a single AND-operand — `base AND (a OR b)` — so it intersects the
  /// base query exactly as a single `IN` list does.
  static TomDataScopePredicate anyOf(
    TomQueryBuilder builder,
    TomColumnInformation col,
    List<List<Object?>> groups,
  ) {
    if (groups.isEmpty) {
      return TomDataScopePredicate(builder.boolOp(false), const {});
    }
    final predicates = <TomOperator<TomDbBool>>[];
    final parameters = <String, Object?>{};
    for (var g = 0; g < groups.length; g++) {
      final sub = inList(
        builder,
        col,
        groups[g],
        prefix: '$parameterPrefix${g}_',
      );
      predicates.add(sub.predicate);
      parameters.addAll(sub.parameters);
    }
    final combined = predicates.length == 1
        ? predicates.first
        : builder.group(builder.or(predicates));
    return TomDataScopePredicate(combined, parameters);
  }

  /// Builds `<col> IN (:prefix0, :prefix1, …)` binding **one parameter per
  /// value** in [values] — the single per-element IN renderer every IN-list
  /// caller shares (RCA5) — returning the predicate with its bind-parameter
  /// map.
  ///
  /// An empty [values] renders a `FALSE` predicate: `IN ()` is invalid SQL, so
  /// a bare FALSE is the correct empty-set filter (an id-list of no ids matches
  /// no rows, a scope of no allowed values denies every row). [prefix]
  /// namespaces the generated parameter names so a caller that ANDs this with
  /// another bound predicate — e.g. an id list (`__idlist_`) combined with a
  /// row scope (`__tomscope_`, the default [parameterPrefix]) — cannot collide.
  ///
  /// Rendering N placeholders here, rather than binding a whole `Iterable` to a
  /// single `?`, is what makes `IN (…)` work over the prepared-statement
  /// protocol: the MySQL driver does not expand a bound list, and no value is
  /// concatenated into the SQL (C-7).
  static TomDataScopePredicate inList(
    TomQueryBuilder builder,
    TomColumnInformation col,
    Iterable<Object?> values, {
    String prefix = parameterPrefix,
  }) {
    final list = values.toList();
    if (list.isEmpty) {
      return TomDataScopePredicate(builder.boolOp(false), const {});
    }
    final parameters = <String, Object?>{};
    final names = <String>[];
    for (var i = 0; i < list.length; i++) {
      final name = '$prefix$i';
      names.add(name);
      parameters[name] = list[i];
    }
    return TomDataScopePredicate(inColumn(builder, col, names), parameters);
  }

  /// Resolves the scope-field values [principal] is allowed for [scope] through
  /// [TomDataScopeRegistry].
  ///
  /// Returns the resolver's result verbatim: `null` when the resolver opts out
  /// of scoping (every value allowed), an empty list to deny every value, or the
  /// list of allowed values. Throws [TomDataScopeException] when `scope.scope`
  /// names a kind no resolver is registered for. Shared by the read-side
  /// predicate [build] and the write-side membership check [permits].
  ///
  /// Pass [forWrite] to resolve the (possibly narrower) set the principal may
  /// *modify*; a kind that registers no write resolver writes what it reads.
  static List<Object?>? allowedValues(
    TomDbScope scope,
    TomPrincipal? principal, {
    bool forWrite = false,
  }) {
    final resolver =
        (forWrite
            ? TomDataScopeRegistry.writeResolverFor(scope.scope)
            : null) ??
        TomDataScopeRegistry.resolverFor(scope.scope);
    if (resolver == null) {
      throw TomDataScopeException(
        'data_scope.build.unknown_scope',
        'No data-scope resolver registered for scope kind "${scope.scope}" '
            '(field "${scope.field}"). Register one with '
            'TomDataScopeRegistry.register.',
      );
    }
    return resolver(principal);
  }

  /// Resolves the scope-field values [principal] is allowed for an **async**
  /// [scope], flattened from the resolver's OR-groups into one membership set.
  ///
  /// The read path keeps the groups apart because each renders its own `IN`
  /// list; a membership check ("may this principal write this value") only asks
  /// whether the value appears in *any* group, so the flattened union is the
  /// right shape. `null` (the resolver opted out) is passed through, so the
  /// result feeds [permits] exactly as [allowedValues] does.
  static Future<List<Object?>?> allowedValuesAsync(
    TomDbScope scope,
    TomPrincipal? principal, {
    bool forWrite = false,
  }) async {
    final groups = await _asyncGroups(scope, principal, forWrite: forWrite);
    if (groups == null) return null;
    return [for (final group in groups) ...group];
  }

  /// Whether [value] falls within the [allowed] scope values a resolver produced
  /// for a principal (C-3 write membership).
  ///
  /// A `null` [allowed] means the resolver opted out of scoping, so every value
  /// is permitted; an empty list permits nothing (deny-all); otherwise the value
  /// must be one of the allowed values. This is the pure counterpart of the
  /// read-side `<col> IN (…)` predicate: a write whose scope-field value is not
  /// permitted targets a row the principal could not read, and is rejected.
  static bool permits(List<Object?>? allowed, Object? value) =>
      allowed == null || allowed.contains(value);

  /// Builds `<col> IN (:name0, :name1, …)` referencing [col] against one bound
  /// parameter per name in [parameterNames], dispatching the column/parameter
  /// SQL type on the column's declared Dart type (`int` → integer, otherwise
  /// string — the two realistic scope-value types).
  static TomOperator<TomDbBool> inColumn(
    TomQueryBuilder builder,
    TomColumnInformation col,
    List<String> parameterNames,
  ) {
    final field = col.getQueryFieldName();
    if (col.declaredType == int) {
      return builder.isIn<TomDbInt>(builder.intF(field, col), [
        for (final n in parameterNames) builder.p<TomDbInt>(n),
      ]);
    }
    return builder.isIn<TomDbString>(builder.textF(field, col), [
      for (final n in parameterNames) builder.p<TomDbString>(n),
    ]);
  }

  /// Builds `<col> = :parameterName`, dispatching the SQL type on [col]'s
  /// declared Dart type the same way [inColumn] does. Used to keep a primary-key
  /// equality typed consistently when a scope predicate is ANDed onto it.
  static TomOperator<TomDbBool> columnEqualsParam(
    TomQueryBuilder builder,
    TomColumnInformation col,
    String parameterName,
  ) {
    final field = col.getQueryFieldName();
    if (col.declaredType == int) {
      return builder.eq<TomDbInt>(
        builder.intF(field, col),
        builder.p<TomDbInt>(parameterName),
      );
    }
    return builder.eq<TomDbString>(
      builder.textF(field, col),
      builder.p<TomDbString>(parameterName),
    );
  }
}
