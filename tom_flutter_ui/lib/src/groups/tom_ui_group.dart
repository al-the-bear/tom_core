import 'dart:collection';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../resource_auth/tom_auth_state.dart';
import '../widget_base/tom_authorizable.dart';

/// A group of related Tom UI elements that share visibility control.
///
/// Members implement [TomAuthorizable], ensuring type-safe access to [tomId]
/// and [tomGroup] properties. Regular Flutter widgets cannot be added directly.
///
/// Groups are created manually and passed directly to widgets:
///
/// ```dart
/// final shippingGroup = TomUIGroup('shipping');
///
/// // In widget construction
/// TomTextField(tomId: 'street', tomGroup: shippingGroup, ...),
/// TomTextField(tomId: 'city', tomGroup: shippingGroup, ...),
/// ```
///
/// Group paths follow the pattern: `<scopePath>.<groupId>` where scopePath
/// comes from [TomScope.current].
class TomUIGroup {
  /// The group ID.
  final String groupId;

  /// Registered members of this group, stored as weak references.
  ///
  /// Using weak references ensures elements can be garbage collected after
  /// disposal without requiring explicit unregistration.
  ///
  /// Members are [TomAuthorizable] instances, providing type-safe access to
  /// [tomId] and [tomGroup] without duck typing.
  final Set<WeakReference<TomAuthorizable>> _members =
      HashSet<WeakReference<TomAuthorizable>>(
    equals: (a, b) => identical(a.target, b.target),
    hashCode: (ref) => identityHashCode(ref.target),
  );

  /// Creates a group with the given [groupId].
  TomUIGroup(this.groupId);

  /// Registers a [TomAuthorizable] element with this group using a weak
  /// reference.
  ///
  /// Called automatically when widget is mounted (via State.initState or
  /// StatelessWidget lifecycle).
  void register(TomAuthorizable element) {
    _members.add(WeakReference(element));
  }

  /// Unregisters an element from this group.
  ///
  /// Optional — elements will be removed during cleanup when their weak
  /// reference targets are garbage collected.
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
    // Clean up stale references
    _members.removeAll(toRemove);
  }

  /// Number of registered members.
  int get memberCount {
    _cleanupStaleReferences();
    return _members.length;
  }

  /// Whether this group has any members.
  bool get isEmpty {
    _cleanupStaleReferences();
    return _members.isEmpty;
  }

  /// Whether this group has members.
  bool get isNotEmpty => !isEmpty;

  /// Removes weak references whose targets have been garbage collected.
  void _cleanupStaleReferences() {
    _members.removeWhere((ref) => ref.target == null);
  }

  /// Resolves the full canonical path for this group.
  ///
  /// Uses [TomScope.current] to prepend scope path.
  String resolveGroupPath() {
    final scopePath = TomScope.current.getScopePath();
    if (scopePath.isNotEmpty) {
      return '$scopePath.$groupId';
    }
    return groupId;
  }

  /// Checks if this group is visible according to authorization.
  bool get isVisible {
    final fullPath = resolveGroupPath();
    return TomUIAuthorization.resolveAuth(fullPath).visible;
  }

  /// Checks if this group is readonly according to authorization.
  bool get isReadonly {
    final fullPath = resolveGroupPath();
    return TomUIAuthorization.resolveAuth(fullPath).readonly;
  }

  /// Gets the full authorization state for this group.
  TomAuthState get auth {
    final fullPath = resolveGroupPath();
    return TomUIAuthorization.resolveAuth(fullPath);
  }

  /// Finds a member by [tomId] within this group.
  ///
  /// Returns `null` if no member with the given [tomId] is found.
  TomAuthorizable? findMember(String tomId) {
    for (final member in members) {
      if (member.tomId == tomId) return member;
    }
    return null;
  }

  @override
  String toString() => 'TomUIGroup($groupId)';
}
