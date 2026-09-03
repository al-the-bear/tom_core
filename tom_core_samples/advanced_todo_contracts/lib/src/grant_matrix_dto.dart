import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'graded_field_dto.dart';

/// The full `(role, resourceKey) → TomAuthState` grant matrix exchanged with
/// `GET/PUT /admin/grants`.
///
/// This is the wire shape the authadmin client's grant-matrix editor reads and
/// writes: a grid of `projectRole` (by name) × field resource key, each cell a
/// four-state [TomAuthState]. The auth server materialises a PUT into
/// `TomResourceGrant` rows via `TomGradedAccessControlInformation.toGrants`.
///
/// A reflection-first wire DTO (G-DTO): `@tomReflector`, a single plain
/// non-`final` [matrix] field, no hand-written serializer. Because the four-state
/// grade cannot cross the wire as an enum, [matrix] holds the access as its
/// stable `TomAuthState.name` token: it is a nested
/// `{role: {resourceKey: token}}` map typed `Map<String, Object?>` so the
/// reflection serializer round-trips it as a plain nested map. The wire shape is
/// therefore `{matrix: {role: {resourceKey: token}}}`. The typed helpers
/// ([accessFor], [gradesFor], [withAccess], [fromGrades]) convert tokens ↔
/// [TomAuthState] via [GradedFieldDto.parseAccess]; all four are closed-safe
/// for every degenerate input a payload can carry — an absent role, a row that
/// is not a map, an unset cell, an unrecognised token, or a cell holding
/// something that is not a string at all all resolve to [TomAuthState.none].
/// The whole decision lives in [GradedFieldDto.parseAccess], so no reader can
/// reintroduce a throwing path by narrowing the type on its own.
@tomReflector
class GrantMatrixDto {
  /// role name → (resourceKey → `TomAuthState.name` token). Held as tokens so
  /// the reflection serializer round-trips it as a plain nested map.
  Map<String, Object?> matrix;

  /// Wraps [grades] (role name → resourceKey → access) as a token map. A
  /// `null`/empty argument yields an empty matrix.
  GrantMatrixDto([Map<String, Map<String, TomAuthState>>? grades])
    : matrix = _encode(grades ?? const {});

  /// Builds a matrix from per-role grade lists (the editor's natural shape).
  /// Later entries for the same `(role, resourceKey)` win.
  factory GrantMatrixDto.fromGrades(
    Map<String, List<GradedFieldDto>> gradesByRole,
  ) {
    final grades = <String, Map<String, TomAuthState>>{};
    gradesByRole.forEach((role, list) {
      final row = <String, TomAuthState>{};
      for (final grade in list) {
        row[grade.resourceKey] = grade.accessState;
      }
      grades[role] = row;
    });
    return GrantMatrixDto(grades);
  }

  /// The roles (by name) the matrix carries.
  Iterable<String> get roles => matrix.keys;

  /// The resolved access for `(role, resourceKey)`, or [TomAuthState.none] when
  /// the cell is unset, the role is absent, or the stored value is not a
  /// recognised token (closed-safe throughout).
  TomAuthState accessFor(String role, String resourceKey) {
    final row = matrix[role];
    if (row is Map) return GradedFieldDto.parseAccess(row[resourceKey]);
    return TomAuthState.none;
  }

  /// The decoded typed grade map for [role] (`resourceKey → TomAuthState`),
  /// empty when the role is absent or its row is not a map. The natural input
  /// for `TomGradedAccessControlInformation(grades:)` on the server. A cell
  /// holding anything other than a recognised token decodes to
  /// [TomAuthState.none] rather than being dropped, so the row's key set
  /// survives intact.
  Map<String, TomAuthState> gradeMapFor(String role) {
    final row = matrix[role];
    if (row is! Map) return const {};
    return {
      for (final entry in row.entries)
        '${entry.key}': GradedFieldDto.parseAccess(entry.value),
    };
  }

  /// The grades for [role] as [GradedFieldDto]s, ordered by resource key for a
  /// stable rendering. Empty when the role is absent or its row is not a map.
  List<GradedFieldDto> gradesFor(String role) {
    final grades = [
      for (final entry in gradeMapFor(role).entries)
        GradedFieldDto(resourceKey: entry.key, access: entry.value),
    ];
    grades.sort((a, b) => a.resourceKey.compareTo(b.resourceKey));
    return grades;
  }

  /// Returns a new matrix with `(role, resourceKey)` set to [access], leaving
  /// this instance unchanged. Every other cell is decoded and re-encoded, so an
  /// unparseable value elsewhere in the grid comes back as [TomAuthState.none]
  /// rather than failing the edit.
  GrantMatrixDto withAccess(
    String role,
    String resourceKey,
    TomAuthState access,
  ) {
    final decoded = <String, Map<String, TomAuthState>>{};
    matrix.forEach((r, row) {
      if (row is Map) {
        decoded[r] = {
          for (final cell in row.entries)
            '${cell.key}': GradedFieldDto.parseAccess(cell.value),
        };
      }
    });
    (decoded[role] ??= <String, TomAuthState>{})[resourceKey] = access;
    return GrantMatrixDto(decoded);
  }

  static Map<String, Object?> _encode(
    Map<String, Map<String, TomAuthState>> grades,
  ) {
    return {
      for (final entry in grades.entries)
        entry.key: <String, Object?>{
          for (final cell in entry.value.entries) cell.key: cell.value.name,
        },
    };
  }

  @override
  String toString() {
    final roleCount = matrix.length;
    var cellCount = 0;
    for (final row in matrix.values) {
      if (row is Map) cellCount += row.length;
    }
    return 'GrantMatrixDto($roleCount roles, $cellCount cells)';
  }
}
