import 'dart:async';

import '../little_things/exception_base.dart';
import '../little_things/little_things.dart';

/// Raised when a scope cannot be built or used as one.
///
/// Keys are `scope_ids.<operation>.<condition>`:
/// `scope_ids.init_scope.empty_id`, `scope_ids.init_scope.separator_in_id`,
/// and `scope_ids.use_scope.no_identity`.
class TomScopeException extends TomException {
  TomScopeException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
    super.uuid,
    super.serverCallError,
  });
}

/// The character that separates path segments, and therefore the one character
/// a scope id may not contain.
const String _scopePathSeparator = '.';

/// Shared scope-installation policy for [TomScope.runInScope] and
/// [TomScopeMixin.runInScope].
///
/// Every install goes through here, which is what makes the identity check
/// below a property of the module rather than of one call site.
///
/// If [scope] is already the current zone scope (identical reference), [body]
/// runs directly without creating a new zone — this prevents duplicate scope
/// nesting. Otherwise [body] runs in a child zone carrying [scope].
T _runScoped<T>(TomScope scope, T Function() body) {
  _requireScopeIdentity(scope, 'Cannot install a scope on the zone');
  if (identical(scope, TomScope.current)) return body();
  return runZoned(body, zoneValues: {TomScope: scope});
}

/// Refuses a [TomScopeMixin] instance whose [TomScopeMixin.initScope] has never
/// run, naming the class and the missing call.
///
/// [attemptedAction] opens the message, so the reader learns what was refused
/// before why. Anything that is not an uninitialised mixin passes: a
/// hand-rolled `implements TomScope` has no initialisation window this module
/// knows about.
///
/// Without this, a half-built instance installs silently and the failure
/// surfaces at whichever later call first asks for a path — a resource lookup
/// or an authorization check, on a stack that mentions neither scopes nor the
/// constructor that skipped [TomScopeMixin.initScope].
void _requireScopeIdentity(TomScope? scope, String attemptedAction) {
  if (scope is! TomScopeMixin || scope._hasIdentity) return;
  throw TomScopeException(
    'scope_ids.use_scope.no_identity',
    '$attemptedAction: ${scope.runtimeType} has no scope identity because '
        'initScope() was never called on it. Call initScope(scopeId: ..., '
        'parentScope: ...) exactly once — from the constructor, or on the '
        'constructed instance once its parent is known.',
    parameters: {'type': scope.runtimeType.toString()},
  );
}

/// Refuses a scope id that cannot survive being joined into a path.
///
/// The path is this module's entire output — a prefix for resource and
/// authorization lookups — and it is built by joining ids with
/// [_scopePathSeparator]. An id containing the separator therefore forges a
/// segment boundary: `'a.b'` under no parent renders exactly as the unrelated
/// chain `'a'` → `'b'`, so a scope named from data (a tenant, a row key, a
/// user-supplied label) can name another scope's resources. An empty id is the
/// same defect seen from the other end — it renders as a bare `''` at the root,
/// which consumers are told to read as "no scope at all", or as a doubled
/// separator further down.
///
/// Checked once per scope, at the only place an id is ever accepted, rather
/// than on every path build.
void _requireUsableScopeId(String scopeId) {
  if (scopeId.isEmpty) {
    throw TomScopeException(
      'scope_ids.init_scope.empty_id',
      'A scope id must not be empty: an empty segment renders as the empty '
          'path, which is how callers are told to spell "no scope at all".',
      parameters: {'scopeId': scopeId},
    );
  }
  if (scopeId.contains(_scopePathSeparator)) {
    throw TomScopeException(
      'scope_ids.init_scope.separator_in_id',
      'A scope id must not contain "$_scopePathSeparator": ids are joined '
          'with it to build the scope path, so "$scopeId" would be '
          'indistinguishable from a deeper chain of separate scopes.',
      parameters: {'scopeId': scopeId, 'separator': _scopePathSeparator},
    );
  }
}

/// A hierarchical, zone-propagated identifier used to namespace resource
/// lookups (e.g. `app.checkout.orderForm`).
///
/// Scopes form a parent chain rooted at [defaultScope]. The active scope is
/// carried on the current [Zone], so [current] resolves to whichever scope was
/// installed by the nearest enclosing [withScope] / [runInScope] call.
abstract class TomScope {
  /// This scope's local identifier (the last segment of its path).
  String get id;

  /// The enclosing scope, or `null` for the root [defaultScope].
  TomScope? get parent;

  /// The root scope used when no scope is installed on the current zone.
  ///
  /// Immutable by design: it is the root of every scope path, so reassigning it
  /// at runtime would change resource resolution for the whole process. Use
  /// [withScope] or [runInScope] instead — they install a scope on a child
  /// zone, so the change reaches that body and the callbacks it schedules,
  /// never the caller or the rest of the process.
  static final TomScope defaultScope = TomScopeBase(
    scopeId: 'default',
    parentScope: null,
  );

  /// The scope installed on the current [Zone], or [defaultScope] if none.
  static TomScope get current => getFromCurrentZone<TomScope>() ?? defaultScope;

  /// Runs [body] in a new child scope named [scope], parented to [current].
  ///
  /// The scope rides on a child [Zone], which bounds *reachability*, not
  /// lifetime. The caller's own continuation after this call never sees the
  /// scope — but anything [body] schedules (a `Future`, `Timer` or stream
  /// subscription) inherits the zone and observes the scope whenever it later
  /// runs. A fire-and-forget `Future` started here therefore keeps this scope
  /// for its entire life, however long that outlasts [body].
  ///
  /// Zone inheritance covers callbacks the async machinery schedules; it does
  /// not cover a closure that is merely *stored* here and invoked directly by
  /// someone else later, which runs in the invoker's scope. Wrap those with
  /// [InScopeBuilder].
  static T withScope<T>(String scope, T Function() body) {
    return runZoned(
      body,
      zoneValues: {
        TomScope: TomScopeBase(scopeId: scope, parentScope: current),
      },
    );
  }

  /// Runs [body] inside this scope's zone.
  ///
  /// If this scope is already the current zone scope (identical reference),
  /// [body] is executed directly without creating a new zone.
  /// This prevents duplicate scope nesting.
  T runInScope<T>(T Function() body) => _runScoped(this, body);

  /// Builds the scope path for any TomScope instance.
  /// Returns a dot-separated string (e.g., "app.checkout.orderForm").
  ///
  /// **The parent chain must be acyclic.** The walk is iterative and
  /// unguarded, so a loop does not raise `StackOverflowError` — it spins
  /// silently, appending segments until the heap is exhausted and the isolate
  /// dies. In a server that is the whole process.
  ///
  /// No guard is needed for scopes this module builds, because none of them can
  /// form a loop: [withScope] and the [TomScopeBase] constructor take a parent
  /// that already exists, and [TomScopeMixin.initScope] refuses one that is not
  /// yet initialised and then writes the link once. Every parent is therefore
  /// strictly older than its child, and a chain that only ever moves backwards
  /// in time cannot return to where it started.
  ///
  /// The requirement binds anything that implements [TomScope] by hand: such a
  /// type supplies its own [parent], outside that argument and outside any
  /// check this module can make.
  static String buildScopePath(TomScope scope) {
    final List<String> parts = [];
    TomScope? current = scope;
    while (current != null) {
      // Elide only the actual root sentinel ([defaultScope]) — identified by
      // identity, not by its 'default' id string. A legitimate domain scope
      // whose local id happens to be 'default' is not the sentinel and must
      // keep its segment in the path.
      if (!identical(current, TomScope.defaultScope)) {
        parts.add(current.id);
      }
      current = current.parent;
    }
    return parts.reversed.join('.');
  }

  /// Returns the full scope path as a dot-separated string.
  /// Used as a prefix for resource lookups.
  String getScopePath() => buildScopePath(this);
}

/// Concrete [TomScope] built from a scope id and an optional parent.
class TomScopeBase with TomScopeMixin {
  TomScopeBase({required String scopeId, TomScope? parentScope}) {
    initScope(scopeId: scopeId, parentScope: parentScope);
  }
}

/// Reusable [TomScope] implementation backing [TomScopeBase].
///
/// Mix into a class and call [initScope] exactly once to set the scope's
/// identity — usually from the constructor. The backing fields are write-once,
/// and [initScope] is the only thing that writes them.
mixin TomScopeMixin on Object implements TomScope {
  late final String _id;
  late final TomScope? _parent;

  /// Whether [initScope] has run.
  ///
  /// Tracked separately because Dart offers no way to ask a `late` field
  /// whether it has been written — reading it to find out throws, which is the
  /// very failure this flag exists to pre-empt.
  bool _hasIdentity = false;

  /// Initialises this scope's identity.
  ///
  /// The single write-once entry point: call it exactly once, from the
  /// constructor or — for a scope whose parent is only known later — on the
  /// constructed instance. [TomScopeBase] and [TomScope.withScope] both route
  /// here, so the checks below hold for every scope the module builds.
  ///
  /// [scopeId] must be non-empty and must not contain `.`, because ids are
  /// joined with `.` to form the scope path. Both are refused with a
  /// [TomScopeException]: an id that carries the separator forges a segment
  /// boundary, so the scope renders as a path belonging to a different, deeper
  /// chain — and the path is what resource and authorization lookups are keyed
  /// on. Ids written as literals in source can never trip this; ids derived
  /// from data are exactly what the check is for.
  ///
  /// [parentScope] must already have an identity of its own. Checking it here
  /// rather than when the path is built is what keeps the check O(1): an
  /// initialised scope then has a fully initialised chain by induction, since
  /// the identity is write-once and a parent cannot lose one later.
  ///
  /// The same rule is also what keeps the chain **acyclic**, which
  /// [TomScope.buildScopePath] relies on and does not verify. Requiring the
  /// parent to be initialised already makes it strictly older than its child,
  /// and writing the link once means it stays that way — so following parents
  /// always moves backwards in time and can never arrive back at where it
  /// started. Closing a loop would need this call to accept a scope that is not
  /// yet initialised, or to run a second time on a scope that already is;
  /// neither is allowed.
  void initScope({required String scopeId, TomScope? parentScope}) {
    // Validate before mutating: a rejected call must leave the instance in the
    // state it was in, still initialisable.
    _requireUsableScopeId(scopeId);
    _requireScopeIdentity(parentScope, 'Cannot use a scope as parentScope');
    _id = scopeId;
    _parent = parentScope;
    _hasIdentity = true;
  }

  @override
  String get id {
    _requireScopeIdentity(this, 'Cannot read a scope id');
    return _id;
  }

  @override
  TomScope? get parent {
    _requireScopeIdentity(this, 'Cannot read a scope parent');
    return _parent;
  }

  @override
  String getScopePath() => TomScope.buildScopePath(this);

  @override
  T runInScope<T>(T Function() body) => _runScoped(this, body);
}

/// Captures a [TomScope] at construction time and wraps callback functions
/// so they execute within that scope when called later.
///
/// Flutter calls builder callbacks (e.g., `itemBuilder`, `builder`) outside
/// the original zone. This wrapper ensures Tom widgets created inside those
/// callbacks still get the correct scope for resource resolution.
///
/// Usage in Tom widget constructors:
/// ```dart
/// class TomFoo extends TomNodeBase {
///   final WidgetBuilder _builder;
///   TomFoo({required WidgetBuilder builder, super.scope})
///       : _builder = InScopeBuilder(scope: scope).wrap1(builder);
/// }
/// ```
class InScopeBuilder {
  final TomScope _scope;

  InScopeBuilder({TomScope? scope}) : _scope = scope ?? TomScope.current;

  /// Wraps a 0-argument callback.
  R Function() wrap0<R>(R Function() fn) =>
      () => _scope.runInScope(() => fn());

  /// Wraps a 1-argument callback.
  R Function(A) wrap1<R, A>(R Function(A) fn) =>
      (a) => _scope.runInScope(() => fn(a));

  /// Wraps a 2-argument callback.
  R Function(A, B) wrap2<R, A, B>(R Function(A, B) fn) =>
      (a, b) => _scope.runInScope(() => fn(a, b));

  /// Wraps a 3-argument callback.
  R Function(A, B, C) wrap3<R, A, B, C>(R Function(A, B, C) fn) =>
      (a, b, c) => _scope.runInScope(() => fn(a, b, c));

  /// Wraps a 4-argument callback.
  R Function(A, B, C, D) wrap4<R, A, B, C, D>(R Function(A, B, C, D) fn) =>
      (a, b, c, d) => _scope.runInScope(() => fn(a, b, c, d));

  /// Wraps a 5-argument callback.
  R Function(A, B, C, D, E) wrap5<R, A, B, C, D, E>(
    R Function(A, B, C, D, E) fn,
  ) =>
      (a, b, c, d, e) => _scope.runInScope(() => fn(a, b, c, d, e));

  /// Wraps a nullable 0-argument callback. Returns null if [fn] is null.
  R Function()? wrap0n<R>(R Function()? fn) => fn == null ? null : wrap0(fn);

  /// Wraps a nullable 1-argument callback. Returns null if [fn] is null.
  R Function(A)? wrap1n<R, A>(R Function(A)? fn) =>
      fn == null ? null : wrap1(fn);

  /// Wraps a nullable 2-argument callback. Returns null if [fn] is null.
  R Function(A, B)? wrap2n<R, A, B>(R Function(A, B)? fn) =>
      fn == null ? null : wrap2(fn);

  /// Wraps a nullable 3-argument callback. Returns null if [fn] is null.
  R Function(A, B, C)? wrap3n<R, A, B, C>(R Function(A, B, C)? fn) =>
      fn == null ? null : wrap3(fn);

  /// Wraps a nullable 4-argument callback. Returns null if [fn] is null.
  R Function(A, B, C, D)? wrap4n<R, A, B, C, D>(R Function(A, B, C, D)? fn) =>
      fn == null ? null : wrap4(fn);

  /// Wraps a nullable 5-argument callback. Returns null if [fn] is null.
  R Function(A, B, C, D, E)? wrap5n<R, A, B, C, D, E>(
    R Function(A, B, C, D, E)? fn,
  ) => fn == null ? null : wrap5(fn);

  /// Wraps a callback with one positional and named parameters.
  /// Use for Flutter's `InputCounterWidgetBuilder` and similar typedefs
  /// that use named parameters.
  R Function(
    A, {
    required B currentLength,
    required C maxLength,
    required D isFocused,
  })
  wrapCounter<R, A, B, C, D>(
    R Function(
      A, {
      required B currentLength,
      required C maxLength,
      required D isFocused,
    })
    fn,
  ) =>
      (a, {required currentLength, required maxLength, required isFocused}) =>
          _scope.runInScope(
            () => fn(
              a,
              currentLength: currentLength,
              maxLength: maxLength,
              isFocused: isFocused,
            ),
          );
}
