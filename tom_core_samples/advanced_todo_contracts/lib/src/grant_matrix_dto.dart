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
/// The matrix is held as an unmodifiable deep copy so a DTO never mutates under
/// a caller; edits produce a new instance via [withAccess]. Lookups are
/// closed-safe: [accessFor] returns [TomAuthState.none] for an unset cell.
/// Equality is structural over the nested map and order-independent.
///
/// Implements [TomJsonSerializable] so the endpoint pipeline serializes a
/// single-`GrantMatrixDto` result (`GET /admin/grants`) through [toJson] rather
/// than the reflection serializer, which would drop its `final` field.
class GrantMatrixDto implements TomJsonSerializable {
  // role name -> (resourceKey -> access); deep-unmodifiable.
  final Map<String, Map<String, TomAuthState>> _matrix;

  /// Wraps [matrix] (role name → resourceKey → access) as a deep, unmodifiable
  /// copy. A `null`/empty argument yields an empty matrix.
  GrantMatrixDto([Map<String, Map<String, TomAuthState>>? matrix])
      : _matrix = _deepUnmodifiable(matrix ?? const {});

  /// Builds a matrix from per-role grade lists (the editor's natural shape).
  /// Later entries for the same `(role, resourceKey)` win.
  factory GrantMatrixDto.fromGrades(
      Map<String, List<GradedFieldDto>> gradesByRole) {
    final matrix = <String, Map<String, TomAuthState>>{};
    gradesByRole.forEach((role, grades) {
      final row = <String, TomAuthState>{};
      for (final grade in grades) {
        row[grade.resourceKey] = grade.access;
      }
      matrix[role] = row;
    });
    return GrantMatrixDto(matrix);
  }

  /// Rebuilds a matrix from its JSON shape `{role: {resourceKey: accessToken}}`.
  /// Non-string/non-map entries are skipped and unknown access tokens degrade
  /// to [TomAuthState.none] (closed-safe).
  factory GrantMatrixDto.fromJson(Map<String, Object?> json) {
    final matrix = <String, Map<String, TomAuthState>>{};
    json.forEach((role, row) {
      if (row is! Map) return;
      final parsed = <String, TomAuthState>{};
      row.forEach((key, token) {
        if (key is String) {
          parsed[key] = GradedFieldDto.parseAccess(token as String?);
        }
      });
      matrix[role] = parsed;
    });
    return GrantMatrixDto(matrix);
  }

  /// The roles (by name) the matrix carries.
  Iterable<String> get roles => _matrix.keys;

  /// An unmodifiable view of the full matrix.
  Map<String, Map<String, TomAuthState>> get matrix => _matrix;

  /// The resolved access for `(role, resourceKey)`, or [TomAuthState.none] when
  /// the cell is unset (closed-safe).
  TomAuthState accessFor(String role, String resourceKey) =>
      _matrix[role]?[resourceKey] ?? TomAuthState.none;

  /// The grades for [role] as [GradedFieldDto]s, ordered by resource key for a
  /// stable rendering. Empty when the role is absent.
  List<GradedFieldDto> gradesFor(String role) {
    final row = _matrix[role];
    if (row == null) return const [];
    final keys = row.keys.toList()..sort();
    return [
      for (final key in keys)
        GradedFieldDto(resourceKey: key, access: row[key]!),
    ];
  }

  /// Returns a new matrix with `(role, resourceKey)` set to [access], leaving
  /// this instance unchanged.
  GrantMatrixDto withAccess(
      String role, String resourceKey, TomAuthState access) {
    final copy = <String, Map<String, TomAuthState>>{
      for (final entry in _matrix.entries)
        entry.key: Map<String, TomAuthState>.of(entry.value),
    };
    (copy[role] ??= <String, TomAuthState>{})[resourceKey] = access;
    return GrantMatrixDto(copy);
  }

  /// JSON shape `{role: {resourceKey: accessToken}}` with each access as its
  /// stable token.
  @override
  Map<String, Object?> toJson() => {
        for (final entry in _matrix.entries)
          entry.key: {
            for (final cell in entry.value.entries) cell.key: cell.value.name,
          },
      };

  static Map<String, Map<String, TomAuthState>> _deepUnmodifiable(
      Map<String, Map<String, TomAuthState>> source) {
    return Map.unmodifiable({
      for (final entry in source.entries)
        entry.key: Map<String, TomAuthState>.unmodifiable(entry.value),
    });
  }

  @override
  bool operator ==(Object other) =>
      other is GrantMatrixDto && _matrixEquals(other._matrix, _matrix);

  @override
  int get hashCode {
    var hash = 0;
    _matrix.forEach((role, row) {
      var rowHash = 0;
      row.forEach((key, access) {
        rowHash ^= Object.hash(key, access);
      });
      hash ^= Object.hash(role, rowHash);
    });
    return hash;
  }

  static bool _matrixEquals(Map<String, Map<String, TomAuthState>> a,
      Map<String, Map<String, TomAuthState>> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null && !b.containsKey(entry.key)) return false;
      if (other == null || other.length != entry.value.length) return false;
      for (final cell in entry.value.entries) {
        if (other[cell.key] != cell.value) return false;
      }
    }
    return true;
  }

  @override
  String toString() {
    final roleCount = _matrix.length;
    final cellCount =
        _matrix.values.fold<int>(0, (sum, row) => sum + row.length);
    return 'GrantMatrixDto($roleCount roles, $cellCount cells)';
  }
}
