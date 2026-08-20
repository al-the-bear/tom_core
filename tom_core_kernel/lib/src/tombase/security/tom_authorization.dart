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
/// Members implement [TomAuthorizable], ensuring type-safe access to [tomId]
/// and [authorizationGroup] properties.
///
/// ```dart
/// final shippingGroup = TomAuthorizationGroup('shipping',
///     mode: AuthGroupMode.controlsAll);
/// TomTextField(tomId: 'street', authorizationGroup: shippingGroup, ...),
/// TomTextField(tomId: 'city', authorizationGroup: shippingGroup, ...),
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
  void register(TomAuthorizable element) {
    _members.add(WeakReference(element));
  }

  /// Unregisters an element from this group.
  void unregister(TomAuthorizable element) {
    _members.removeWhere((ref) => identical(ref.target, element));
  }

  /// All currently registered members (excludes garbage-collected elements).
  Iterable<TomAuthorizable> get members sync* {
    final toRemove = <WeakReference<TomAuthorizable>>[];
    for (final ref in _members) {
      final target = ref.target;
      if (target == null) {
        toRemove.add(ref);
      } else {
        yield target;
      }
    }
    _members.removeAll(toRemove);
  }

  /// Number of registered members.
  int get memberCount {
    _cleanupStaleReferences();
    return _members.length;
  }

  /// Whether the group has no live members (after pruning stale references).
  bool get isEmpty {
    _cleanupStaleReferences();
    return _members.isEmpty;
  }

  /// Whether the group has at least one live member.
  bool get isNotEmpty => !isEmpty;

  void _cleanupStaleReferences() {
    _members.removeWhere((ref) => ref.target == null);
  }

  /// Resolves the full canonical path for this group.
  String resolveGroupPath() {
    final scopePath = TomScope.current.getScopePath();
    if (scopePath.isNotEmpty) return '$scopePath.$groupId';
    return groupId;
  }

  /// Gets the authorization state for this group.
  TomAuthState get authState {
    final fullPath = resolveGroupPath();
    return TomAuthorization.resolveAuth(fullPath);
  }

  /// Applies this group's authorization mode to a member's state.
  ///
  /// - [controlsAll]: group state replaces the member's state
  /// - [controlsWidest]: group state is the ceiling (narrows the member)
  /// - [controlsNarrowest]: group state is the floor (widens the member)
  TomAuthState applyMode(TomAuthState memberState) {
    final groupState = authState;
    return switch (mode) {
      AuthGroupMode.controlsAll => groupState,
      AuthGroupMode.controlsWidest => memberState.narrow(groupState),
      AuthGroupMode.controlsNarrowest => memberState.widen(groupState),
    };
  }

  /// Whether all visible members share the same effective auth state.
  ///
  /// Returns `true` if:
  /// - The group is empty, or
  /// - All members have identical [effectiveAuthState] values
  bool get isUniform {
    TomAuthState? firstState;
    for (final member in members) {
      final state = member.effectiveAuthState;
      if (state == TomAuthState.none) continue; // Skip hidden members
      if (firstState == null) {
        firstState = state;
      } else if (state != firstState) {
        return false;
      }
    }
    return true;
  }

  /// The most restrictive effective auth state among all visible members.
  ///
  /// Returns [TomAuthState.full] if the group is empty or all members are hidden.
  /// State ordering from most to least restrictive: none < disabled < read < full.
  TomAuthState get mostRestrictive {
    var result = TomAuthState.full;
    for (final member in members) {
      final state = member.effectiveAuthState;
      if (state == TomAuthState.none) continue; // Skip hidden members
      result = result.narrow(state);
    }
    return result;
  }

  /// Finds a member by [tomId] within this group.
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

  static TomAuthorizationAdapter? _adapter;

  /// Installs the [TomAuthorizationAdapter] that backs [resolveAuth].
  ///
  /// When no adapter is set, authorization resolves to [TomAuthState.full]
  /// (development mode).
  static set adapter(TomAuthorizationAdapter adapter) => _adapter = adapter;

  /// Resolves authorization for the given resource key path.
  ///
  /// Returns [TomAuthState.full] if no adapter is set (development mode).
  static TomAuthState resolveAuth(String resourceKeyPath) {
    return _adapter?.resolveAuth(resourceKeyPath) ?? TomAuthState.full;
  }

  /// Resets the adapter. Intended for testing only.
  static void reset() => _adapter = null;
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
