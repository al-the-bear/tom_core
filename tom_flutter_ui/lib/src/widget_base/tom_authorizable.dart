import '../groups/tom_ui_group.dart';

/// Interface for elements that participate in the Tom authorization system.
///
/// Implementers gain:
/// - [tomId] for resource-based authorization lookups
/// - [tomGroup] for group-level visibility control
///
/// This interface enables type-safe registration with [TomUIGroup], ensuring
/// only authorized elements can be group members. It also allows future
/// extensions like Actions to participate in the authorization system.
///
/// Currently implemented by:
/// - [TomNodeBase] — base class for all Tom widgets
///
/// Future implementations:
/// - Tom Actions (e.g., navigation actions, business operations)
/// - Menu item definitions
/// - Named routes/screens
abstract interface class TomAuthorizable {
  /// The plain ID for this element within its scope.
  ///
  /// Used for resource lookups and authorization checks.
  /// Returns `null` if this element doesn't participate in resource lookup.
  String? get tomId;

  /// The group this element belongs to, if any.
  ///
  /// Groups enable collective visibility control.
  TomUIGroup? get tomGroup;
}
