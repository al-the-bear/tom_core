import 'package:tom_core_kernel/tom_core_kernel.dart';

/// The full `role → (resourceKey → TomAuthState)` field-authorization matrix —
/// the wire shape of `core_server_sample`'s `GET /todos/field-states`.
///
/// A reflection-first wire DTO (G-DTO): `@tomReflector`, a single plain
/// non-`final` [states] field, no hand-written serializer. Because the
/// four-state grade cannot cross the wire as an enum, [states] holds the access
/// as its stable [TomAuthState.name] token in a nested
/// `{role: {resourceKey: token}}` map typed `Map<String, Object?>`, so the
/// reflection serializer round-trips it as a plain nested map. The wire shape is
/// therefore `{states: {role: {resourceKey: token}}}`. Lookups are closed-safe:
/// an unset cell resolves to [TomAuthState.none].
@tomReflector
class TodoFieldMatrixDto {
  /// role name → (resourceKey → [TomAuthState.name] token). Held as tokens so
  /// the reflection serializer round-trips it as a plain nested map.
  Map<String, Object?> states;

  /// Wraps [matrix] (role → resourceKey → grade) as a token map. A `null`/empty
  /// argument yields an empty matrix.
  TodoFieldMatrixDto([Map<String, Map<String, TomAuthState>>? matrix])
      : states = _encode(matrix ?? const {});

  /// The roles (by name) the matrix carries.
  Iterable<String> get roles => states.keys;

  /// The decoded typed grade map for [role] (`resourceKey → TomAuthState`),
  /// empty when the role is absent.
  Map<String, TomAuthState> statesFor(String role) {
    final row = states[role];
    if (row is! Map) return const {};
    return {
      for (final entry in row.entries)
        '${entry.key}': parseState(entry.value as String?),
    };
  }

  /// The resolved access for `(role, resourceKey)`, or [TomAuthState.none] when
  /// the cell is unset (closed-safe).
  TomAuthState accessFor(String role, String resourceKey) {
    final row = states[role];
    if (row is Map) return parseState(row[resourceKey] as String?);
    return TomAuthState.none;
  }

  /// Parses a stored [TomAuthState] token back to its enum value. A `null` or
  /// unrecognised token yields [orElse] (default [TomAuthState.none], the
  /// closed/safe fallback) rather than throwing.
  static TomAuthState parseState(
    String? token, {
    TomAuthState orElse = TomAuthState.none,
  }) {
    if (token == null) return orElse;
    for (final state in TomAuthState.values) {
      if (state.name == token) return state;
    }
    return orElse;
  }

  static Map<String, Object?> _encode(
      Map<String, Map<String, TomAuthState>> matrix) {
    return {
      for (final entry in matrix.entries)
        entry.key: <String, Object?>{
          for (final cell in entry.value.entries) cell.key: cell.value.name,
        },
    };
  }

  @override
  String toString() {
    var cells = 0;
    for (final row in states.values) {
      if (row is Map) cells += row.length;
    }
    return 'TodoFieldMatrixDto(${states.length} roles, $cells cells)';
  }
}
