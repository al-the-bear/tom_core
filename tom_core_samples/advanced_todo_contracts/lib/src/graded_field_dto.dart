import 'package:tom_core_kernel/tom_core_kernel.dart';

/// One resource key paired with its resolved four-state authorization.
///
/// The app server projects a principal's per-field grade into these and ships
/// them alongside each item (see `GET /items/{id}/field-states`); both Flutter
/// clients render [access] onto field visibility/interactivity. It carries only
/// the kernel [TomAuthState] so the contract stays dependency-clean — the graded
/// resolver itself lives server-side and never crosses the wire.
///
/// Serialization is hand-written ([toJson]/[fromJson]) rather than reflection:
/// the advanced sample's endpoints exchange plain JSON maps (mirroring
/// `core_server_sample`'s `Map<String, Object>` surface), and the client core
/// maps them with pure functions. [fromJson] is closed-safe: an absent or
/// unrecognised access token degrades to [TomAuthState.none] (hidden/denied)
/// rather than throwing.
class GradedFieldDto {
  /// The resource key this grade applies to, e.g. `todo.item.title`.
  final String resourceKey;

  /// The resolved four-state access level for [resourceKey].
  final TomAuthState access;

  /// Creates a grade. Defaults to [TomAuthState.none] so an unset grade is
  /// closed by default rather than accidentally permissive.
  const GradedFieldDto({
    this.resourceKey = '',
    this.access = TomAuthState.none,
  });

  /// Rebuilds a grade from its JSON shape `{resourceKey, access}`. Unknown or
  /// missing values degrade to empty/[TomAuthState.none] (closed-safe).
  factory GradedFieldDto.fromJson(Map<String, Object?> json) => GradedFieldDto(
        resourceKey: (json['resourceKey'] as String?) ?? '',
        access: parseAccess(json['access'] as String?),
      );

  /// The [access] level as its stable token (`none`/`disabled`/`read`/`full`) —
  /// the same representation the persistence layer round-trips.
  String get accessName => access.name;

  /// JSON shape `{resourceKey, access}` with [access] as its stable token.
  Map<String, Object?> toJson() => {
        'resourceKey': resourceKey,
        'access': access.name,
      };

  /// Parses a stored [TomAuthState] token back to its enum value. A `null` or
  /// unrecognised token yields [orElse] (default [TomAuthState.none], the
  /// closed/safe fallback) rather than throwing.
  static TomAuthState parseAccess(
    String? token, {
    TomAuthState orElse = TomAuthState.none,
  }) {
    if (token == null) return orElse;
    for (final state in TomAuthState.values) {
      if (state.name == token) return state;
    }
    return orElse;
  }

  @override
  bool operator ==(Object other) =>
      other is GradedFieldDto &&
      other.resourceKey == resourceKey &&
      other.access == access;

  @override
  int get hashCode => Object.hash(resourceKey, access);

  @override
  String toString() => 'GradedFieldDto($resourceKey -> ${access.name})';
}
