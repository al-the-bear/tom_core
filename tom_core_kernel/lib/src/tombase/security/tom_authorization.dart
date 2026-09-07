/// Tom Authorization — UI authorization primitives for the Tom framework.
///
/// This file defines the core authorization types used by the UI layer:
/// - [TomAuthState] — the four-state authorization outcome
/// - [TomAuthorizable] — interface for elements that participate in authorization
/// - [TomAuthorizationGroup] — group of related authorizables with collective control
/// - [TomAuthorization] — global singleton for resolving authorization state
/// - [TomAuthorizer] — per-widget/action authorizer that can modify auth outcomes
/// - [TomAuthorizerStrategy] — how authorizer interacts with resource authorization
/// - [TomUIStateController] — build-time callback for narrowing widget state
library;

import 'dart:collection';

import '../scope_ids/scope_ids.dart';

// =============================================================================
// TomAuthState — four authorization states
// =============================================================================

/// The four authorization states for a UI element.
///
/// These map to distinct visual/behavioral outcomes:
/// - [none] — element is hidden (as if it doesn't exist)
/// - [disabled] — element is visible but greyed out, no content shown;
///   indicates data may exist but cannot be seen or might not exist
/// - [read] — element shows current value/state in read-only mode
/// - [full] — element is fully interactive/editable
enum TomAuthState {
  /// Hidden — the element does not exist from the user's perspective.
  none,

  /// Disabled — visible but greyed out, no content. Indicates data
  /// may exist but cannot be accessed or might not exist for this object.
  disabled,

  /// Read-only — displays current value/state but cannot be modified.
  read,

  /// Full access — the element is fully interactive and editable.
  full;

  /// Whether this state allows the element to be visible.
  bool get isVisible => this != none;

  /// Whether this state allows the element to be interactive.
  bool get isInteractive => this == full;

  /// Whether this state shows content (read or full).
  bool get showsContent => this == read || this == full;

  /// Returns the more restrictive of two states.
  ///
  /// State ordering from most to least restrictive:
  /// none < disabled < read < full
  TomAuthState narrow(TomAuthState other) {
    if (index <= other.index) return this;
    return other;
  }

  /// Returns the less restrictive of two states.
  TomAuthState widen(TomAuthState other) {
    if (index >= other.index) return this;
    return other;
  }
}

// =============================================================================
// TomAuthorizable — interface for authorization participants
// =============================================================================

/// Interface for elements that participate in the Tom authorization system.
///
/// Implementers gain:
/// - [tomId] for resource-based authorization lookups
/// - [tomGroup] for group-level visibility control
/// - [effectiveAuthState] — the resolved authorization state for this element
///
/// Implemented by:
/// - Tom widgets (via TomNodeBase, TomWidgetMixin)
/// - Tom actions (via TomAction)
/// - Menu item definitions, named routes/screens
abstract interface class TomAuthorizable {
  /// The plain ID for this element within its scope.
  ///
  /// Used for resource lookups and authorization checks.
  /// Returns `null` if this element doesn't participate in resource lookup.
  String? get tomId;

  /// The authorization group this element belongs to, if any.
  ///
  /// Groups enable collective visibility control.
  TomAuthorizationGroup? get tomGroup;

  /// The effective authorization state for this element.
  ///
  /// This should return the final resolved state after applying:
  /// 1. Resource-based authorization (via [tomId])
  /// 2. Group authorization (via [tomGroup])
  /// 3. Any local overrides or authorizers
  ///
  /// Implementers should call their own resolution logic (e.g.,
  /// `resolveEffectiveAuth()`) and return the result.
  TomAuthState get effectiveAuthState;
}

// =============================================================================
// AuthGroupMode — how a group's auth state applies to members
// =============================================================================

/// Determines how a [TomAuthorizationGroup]'s auth state applies to its members.
enum AuthGroupMode {
  /// Group state replaces all member states (after form-level narrowing).
  controlsAll,

  /// Group state is the ceiling — members can be narrower but not wider.
  controlsWidest,

  /// Group state is the floor — members that would be more restrictive
  /// are elevated to the group's state.
  controlsNarrowest,
}

// =============================================================================
// TomAuthorizationGroup — collective authorization control
// =============================================================================

/// A group of related Tom elements that share authorization control.
///
/// Members implement [TomAuthorizable], which is what gives the group
/// type-safe access to their [TomAuthorizable.tomId] and
/// [TomAuthorizable.tomGroup] properties.
///
/// Membership is established by registering with the group:
///
/// ```dart
/// final shipping = TomAuthorizationGroup('shipping',
///     mode: AuthGroupMode.controlsAll);
/// shipping.register(streetField);
/// shipping.register(cityField);
/// ```
///
/// UI packages built on this kernel wire the same thing up declaratively. In
/// Tom Flutter UI the input widgets take the group as `tomGroup` and register
/// themselves — note the name, since form- and container-level widgets in that
/// package spell the same concept `authorizationGroup`:
///
/// ```dart
/// TomTextField(tomId: 'street', tomGroup: shipping, ...),
/// TomTextField(tomId: 'city', tomGroup: shipping, ...),
/// ```
///
/// Group paths follow the pattern: `<scopePath>.<groupId>`.
class TomAuthorizationGroup {
  /// The group ID.
  final String groupId;

  /// How this group's auth state applies to its members.
  final AuthGroupMode mode;

  /// Registered members stored as weak references.
  final Set<WeakReference<TomAuthorizable>> _members =
      HashSet<WeakReference<TomAuthorizable>>(
        equals: (a, b) => identical(a.target, b.target),
        hashCode: (ref) => identityHashCode(ref.target),
      );

  TomAuthorizationGroup(
    this.groupId, {
    this.mode = AuthGroupMode.controlsWidest,
  });

  /// Registers a [TomAuthorizable] element with this group.
  ///
  /// Registration is independent of visibility: an element whose
  /// [TomAuthorizable.effectiveAuthState] is [TomAuthState.none] is registered
  /// like any other, it simply does not show up in [members] while hidden.
  void register(TomAuthorizable element) {
    _members.add(WeakReference(element));
  }

  /// Unregisters an element from this group.
  ///
  /// Works on the raw registrations rather than on [members], so a hidden
  /// element can still be removed by whoever put it there.
  void unregister(TomAuthorizable element) {
    _members.removeWhere((ref) => identical(ref.target, element));
  }

  /// The group's visible members: every live registration whose
  /// [TomAuthorizable.effectiveAuthState] is not [TomAuthState.none].
  ///
  /// A hidden member does not exist from the user's perspective, so it does
  /// not exist for inspection either. This is the *single* place that filter
  /// is applied — [memberCount], [isEmpty], [isNotEmpty], [findMember],
  /// [isUniform] and [mostRestrictive] are all defined in terms of this
  /// getter, which is what stops them from disagreeing about who is in the
  /// group. Registration bookkeeping ([register] / [unregister]) deliberately
  /// bypasses it.
  ///
  /// The result is a snapshot rather than a lazy view. Building it eagerly is
  /// what lets every caller prune garbage-collected registrations — including
  /// the callers ([isEmpty], [findMember]) that stop reading after the first
  /// hit and would otherwise never reach the pruning step.
  Iterable<TomAuthorizable> get members {
    final stale = <WeakReference<TomAuthorizable>>[];
    final visible = <TomAuthorizable>[];
    for (final ref in _members) {
      final target = ref.target;
      if (target == null) {
        stale.add(ref);
      } else if (target.effectiveAuthState != TomAuthState.none) {
        visible.add(target);
      }
    }
    _members.removeAll(stale);
    return visible;
  }

  /// Number of visible members — see [members].
  int get memberCount => members.length;

  /// Whether the group has no visible members — see [members].
  ///
  /// A group all of whose members are hidden reports empty: there is nothing
  /// there for the user to see, which is the question callers are asking.
  bool get isEmpty => members.isEmpty;

  /// Whether the group has at least one visible member — see [members].
  bool get isNotEmpty => !isEmpty;

  /// Resolves the full canonical path for this group, in [scope].
  ///
  /// [scope] defaults to the ambient [TomScope.current], which is right
  /// whenever the caller is standing in the frame it is asking about. It is
  /// wrong for the two cases a scope is passed as a *value* rather than
  /// installed on a zone — a member constructed with an explicit `scope`, and
  /// a callback wrapped by [ScopeCapture] — and those are exactly the cases
  /// that supply it here.
  ///
  /// The member's own path and this one have to come out of the same frame:
  /// they are a `<prefix>.<id>` pair, and a prefix that differs between them
  /// looks up a ceiling that belongs to some other member.
  String resolveGroupPath([TomScope? scope]) {
    final scopePath = (scope ?? TomScope.current).getScopePath();
    if (scopePath.isNotEmpty) return '$scopePath.$groupId';
    return groupId;
  }

  /// Gets the authorization state for this group in the ambient scope.
  TomAuthState get authState => _authStateIn(null);

  /// Applies this group's authorization mode to a member's state.
  ///
  /// - [AuthGroupMode.controlsAll]: group state replaces the member's state
  /// - [AuthGroupMode.controlsWidest]: group state is the ceiling (narrows
  ///   the member)
  /// - [AuthGroupMode.controlsNarrowest]: group state is the floor (widens
  ///   the member)
  ///
  /// [scope] is the frame the group is resolved in — see [resolveGroupPath].
  /// A caller that resolved the member's own path against an explicit scope
  /// must pass the same one, or the two halves of the composition disagree
  /// about where they are and the group's ceiling is applied to the wrong
  /// member, or to none.
  TomAuthState applyMode(TomAuthState memberState, [TomScope? scope]) {
    final groupState = _authStateIn(scope);
    return switch (mode) {
      AuthGroupMode.controlsAll => groupState,
      AuthGroupMode.controlsWidest => memberState.narrow(groupState),
      AuthGroupMode.controlsNarrowest => memberState.widen(groupState),
    };
  }

  TomAuthState _authStateIn(TomScope? scope) =>
      TomAuthorization.resolveAuth(resolveGroupPath(scope));

  /// Whether all visible members share the same effective auth state.
  ///
  /// Returns `true` for a group with no visible members — see [members].
  bool get isUniform {
    TomAuthState? firstState;
    for (final member in members) {
      final state = member.effectiveAuthState;
      if (firstState == null) {
        firstState = state;
      } else if (state != firstState) {
        return false;
      }
    }
    return true;
  }

  /// The most restrictive effective auth state among the visible members.
  ///
  /// Returns [TomAuthState.none] when there are no visible members — see
  /// [members]. An empty group and a group whose members are all hidden are
  /// the same thing from the user's perspective: both show nothing, and
  /// `none` is what "nothing to show" is called everywhere else in this API.
  ///
  /// [TomAuthState.full] is the identity element of the narrowing fold below,
  /// not an answer. Returning it for an empty group would report the most
  /// permissive state possible for the one case where the group displays
  /// nothing at all — so a container gating on `mostRestrictive == full`
  /// would treat a fully hidden group as fully editable.
  ///
  /// Note the deliberate asymmetry with [isUniform], which stays `true` for a
  /// group with no visible members: "all of nothing satisfies anything" is
  /// vacuously true, whereas "the narrowest of nothing" has a truthful answer.
  ///
  /// State ordering from most to least restrictive:
  /// `none < disabled < read < full`.
  TomAuthState get mostRestrictive {
    final visible = members;
    if (visible.isEmpty) return TomAuthState.none;
    var result = TomAuthState.full;
    for (final member in visible) {
      result = result.narrow(member.effectiveAuthState);
    }
    return result;
  }

  /// Finds a visible member by [tomId] within this group — see [members].
  ///
  /// Returns `null` for a member that is registered but hidden.
  TomAuthorizable? findMember(String tomId) {
    for (final member in members) {
      if (member.tomId == tomId) return member;
    }
    return null;
  }

  @override
  String toString() => 'TomAuthorizationGroup($groupId, mode: $mode)';
}

// =============================================================================
// TomAuthorizationAdapter & TomAuthorization — global authorization singleton
// =============================================================================

/// Adapter that resolves authorization state for a given resource key path.
///
/// Implementations bridge the kernel security layer to the UI:
/// - Kernel-backed adapter uses resource key protection
/// - Test implementations can return predetermined results
abstract class TomAuthorizationAdapter {
  TomAuthState resolveAuth(String resourceKeyPath);
}

/// Global authorization singleton.
///
/// Initialized at app startup with a concrete adapter. Widgets, forms, and
/// actions access it directly — no InheritedWidget or BuildContext needed.
///
/// ```dart
/// // App startup
/// TomAuthorization.adapter = MyAuthorizationAdapter();
///
/// // Usage anywhere
/// final auth = TomAuthorization.resolveAuth('checkout.email');
/// ```
class TomAuthorization {
  TomAuthorization._();

  /// The installed [TomAuthorizationAdapter] backing [resolveAuth], or `null`
  /// when none is installed — in which case authorization resolves to
  /// [TomAuthState.full] (development mode).
  ///
  /// Readable so that a diagnostics screen or a startup assertion can ask
  /// what is wired, and so that code installing an adapter for one operation
  /// can put the previous one back rather than tearing down whatever the
  /// application had:
  ///
  /// ```dart
  /// final saved = TomAuthorization.adapter;
  /// TomAuthorization.adapter = ReadOnlyAuthorizationAdapter();
  /// // ...
  /// TomAuthorization.adapter = saved;
  /// ```
  ///
  /// Assigning `null` uninstalls. [reset] does the same and stays the named
  /// teardown hook for tests; the two coincide here because this class holds
  /// nothing besides the adapter.
  static TomAuthorizationAdapter? adapter;

  /// Resolves authorization for the given resource key path.
  ///
  /// Returns [TomAuthState.full] if no adapter is set (development mode).
  static TomAuthState resolveAuth(String resourceKeyPath) {
    return adapter?.resolveAuth(resourceKeyPath) ?? TomAuthState.full;
  }

  /// Resets the adapter. Intended for testing only.
  static void reset() => adapter = null;
}

// =============================================================================
// TomAuthorizer — per-element authorization modifier
// =============================================================================

/// Strategy for how a [TomAuthorizer] interacts with resource authorization.
///
/// - [authorizerDecides]: The authorizer has full control. It receives the
///   resource authorization state and can return any state, including widening.
/// - [authorizerNarrowsOnly]: The authorizer can only narrow (further restrict)
///   the resource authorization. It cannot widen access.
enum TomAuthorizerStrategy {
  /// The authorizer has full control over the final state.
  /// It receives the resource auth state and can return any state.
  authorizerDecides,

  /// The authorizer can only narrow the resource authorization.
  /// The final state is the more restrictive of resource auth and authorizer result.
  authorizerNarrowsOnly,
}

/// Per-element authorizer that can modify the authorization outcome.
///
/// Attached to individual widgets or actions. The authorizer is informed of
/// the resource-based authorization state and can modify it according to the
/// [TomAuthorizerStrategy].
///
/// ```dart
/// TomElevatedButton(
///   tomId: 'save',
///   authorizer: TomAuthorizer(
///     strategy: TomAuthorizerStrategy.authorizerNarrowsOnly,
///     resolve: (resourceAuth) {
///       // Disable save when no changes exist
///       if (!hasChanges) return TomAuthState.disabled;
///       return resourceAuth;
///     },
///   ),
/// )
/// ```
class TomAuthorizer {
  /// The strategy controlling how authorizer interacts with resource auth.
  final TomAuthorizerStrategy strategy;

  /// Resolves the authorization state given the resource-based state.
  ///
  /// The [resourceAuth] is the state determined by the global
  /// [TomAuthorization] singleton. The return value is the authorizer's
  /// desired state.
  final TomAuthState Function(TomAuthState resourceAuth) resolve;

  const TomAuthorizer({
    this.strategy = TomAuthorizerStrategy.authorizerNarrowsOnly,
    required this.resolve,
  });

  /// Computes the effective authorization state by combining the resource
  /// authorization with this authorizer's resolution.
  TomAuthState effectiveAuth(TomAuthState resourceAuth) {
    final authorizerResult = resolve(resourceAuth);
    switch (strategy) {
      case TomAuthorizerStrategy.authorizerDecides:
        return authorizerResult;
      case TomAuthorizerStrategy.authorizerNarrowsOnly:
        return resourceAuth.narrow(authorizerResult);
    }
  }

  /// Creates an authorizer that always returns the given [state], regardless
  /// of resource authorization.
  factory TomAuthorizer.fixed(TomAuthState state) => TomAuthorizer(
    strategy: TomAuthorizerStrategy.authorizerDecides,
    resolve: (_) => state,
  );

  /// Creates an authorizer from an action's authorization.
  ///
  /// Applies the default pattern: when action auth is [TomAuthState.none]
  /// but widget resource auth is [TomAuthState.full], the result is
  /// [TomAuthState.disabled] (button visible but greyed out).
  factory TomAuthorizer.fromAction({
    required TomAuthState Function() actionAuth,
  }) => TomAuthorizer(
    strategy: TomAuthorizerStrategy.authorizerDecides,
    resolve: (resourceAuth) {
      final aAuth = actionAuth();
      // Widget hidden → stay hidden
      if (resourceAuth == TomAuthState.none) return TomAuthState.none;
      // Widget full + action none → disabled (shows button exists but unavailable)
      if (resourceAuth == TomAuthState.full && aAuth == TomAuthState.none) {
        return TomAuthState.disabled;
      }
      // Otherwise, narrow to the most restrictive
      return resourceAuth.narrow(aAuth);
    },
  );
}

// =============================================================================
// TomUIStateController — build-time state narrowing
// =============================================================================

/// Build-time callback that can further narrow a widget's effective state.
///
/// The main difference between authorization and UI state control:
/// - **Authorization** happens at widget creation time (construction-time)
/// - **UI state controller** runs at build time and can further narrow based
///   on dynamic business rules
///
/// The controller CANNOT widen authorization — it can only narrow.
///
/// ```dart
/// TomElevatedButton(
///   tomId: 'reorder',
///   uiStateController: TomUIStateController(
///     resolve: (currentAuth, data) {
///       // Disable reorder when list is empty
///       if (items.isEmpty) return TomAuthState.disabled;
///       // Check row-specific ownership
///       if (data case {'ownerId': int id} when id != currentUserId) {
///         return TomAuthState.read;
///       }
///       return currentAuth;
///     },
///   ),
/// )
/// ```
class TomUIStateController {
  /// Resolves the final UI state given the current authorization state.
  ///
  /// The [currentAuth] is the combined result of resource authorization
  /// and any [TomAuthorizer]. The return value can only narrow this state.
  ///
  /// The optional [data] parameter provides context for row-level decisions,
  /// such as checking if the current user owns a list item.
  final TomAuthState Function(TomAuthState currentAuth, Object? data) resolve;

  const TomUIStateController({required this.resolve});

  /// Applies this controller, ensuring the result never widens [currentAuth].
  ///
  /// The optional [data] is passed to the resolver for row-specific decisions.
  TomAuthState apply(TomAuthState currentAuth, {Object? data}) {
    final result = resolve(currentAuth, data);
    // Never widen — take the more restrictive
    return currentAuth.narrow(result);
  }
}
