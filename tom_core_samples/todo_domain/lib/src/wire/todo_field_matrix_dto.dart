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
/// therefore `{states: {role: {resourceKey: token}}}`. Lookups are closed-safe
/// for every degenerate input a payload can carry — an absent role, a row that
/// is not a map, an unset cell, an unrecognised token, or a cell holding
/// something that is not a string at all all resolve to [TomAuthState.none].
/// The whole decision lives in [parseState], so no reader can reintroduce a
/// throwing path by narrowing the type on its own.
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
  /// empty when the role is absent or its row is not a map. A cell holding
  /// anything other than a recognised token decodes to [TomAuthState.none]
  /// rather than being dropped, so the row's key set survives intact.
  Map<String, TomAuthState> statesFor(String role) {
    final row = states[role];
    if (row is! Map) return const {};
    return {
      for (final entry in row.entries) '${entry.key}': parseState(entry.value),
    };
  }

  /// The resolved access for `(role, resourceKey)`, or [TomAuthState.none] when
  /// the cell is unset, the role is absent, or the stored value is not a
  /// recognised token (closed-safe throughout).
  TomAuthState accessFor(String role, String resourceKey) {
    final row = states[role];
    if (row is Map) return parseState(row[resourceKey]);
    return TomAuthState.none;
  }

  /// Parses a stored [TomAuthState] token back to its enum value. Anything that
  /// is not a recognised token — `null`, an unknown string, or a value that is
  /// not a string at all — yields [orElse] (default [TomAuthState.none], the
  /// closed/safe fallback) rather than throwing.
  ///
  /// [token] is `Object?` rather than `String?` deliberately: [states] is typed
  /// `Map<String, Object?>`, so a cell arriving off the wire may hold any JSON
  /// value, and this is the single place that decides what a non-token means. A
  /// caller that narrowed the type first would only move the failure into its
  /// own cast.
  static TomAuthState parseState(
    Object? token, {
    TomAuthState orElse = TomAuthState.none,
  }) {
    if (token is! String) return orElse;
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
