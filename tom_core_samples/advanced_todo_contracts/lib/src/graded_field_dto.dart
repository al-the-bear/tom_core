import 'package:tom_core_kernel/tom_core_kernel.dart';

/// One resource key paired with its resolved four-state authorization.
///
/// This is the per-cell grade of the admin grant matrix ([GrantMatrixDto]): the
/// auth server's `/admin/grants` path ships a `role → resourceKey → token` map,
/// and [GrantMatrixDto.gradesFor] projects each row into these DTOs for the
/// admin console's grant editor. It carries only the kernel [TomAuthState] token
/// so the contract stays dependency-clean — the graded resolver itself lives
/// server-side and never crosses the wire.
///
/// The app client, by contrast, no longer receives per-field grades over the
/// wire: it fetches its flat `resourceKey → role` map from `GET /resource-roles`
/// and resolves each field's grade locally through the framework registry.
///
/// A reflection-first wire DTO (G-DTO): `@tomReflector`, plain non-`final`
/// fields, no hand-written serializer. The framework serializes it through the
/// reflection path ([TomReflectionInfo.getValues] /
/// [TomReflectionInfo.createInstanceFromJson]) exactly like the reflected
/// domain entities. [access] travels as the stable `TomAuthState.name` token
/// under the wire key `access`; use [accessState] for the typed enum. An
/// unset/unknown token resolves to [TomAuthState.none] (closed-safe).
@tomReflector
class GradedFieldDto {
  /// The resource key this grade applies to, e.g. `todo.item.title`.
  String resourceKey;

  /// The resolved access as its stable `TomAuthState.name` token
  /// (`none`/`disabled`/`read`/`full`). Reflection serializes this field
  /// directly under the wire key `access`; use [accessState] for the typed enum.
  String access;

  /// Creates a grade. [access] defaults to [TomAuthState.none] so an unset grade
  /// is closed by default rather than accidentally permissive.
  GradedFieldDto({
    this.resourceKey = '',
    TomAuthState access = TomAuthState.none,
  }) : access = access.name;

  /// Typed view of [access]; an unset/unrecognised token resolves to
  /// [TomAuthState.none] (closed-safe).
  TomAuthState get accessState => parseAccess(access);

  /// Sets [access] from a typed [TomAuthState].
  set accessState(TomAuthState value) => access = value.name;

  /// Parses a stored [TomAuthState] token back to its enum value. Anything that
  /// is not a recognised token — `null`, an unknown string, or a value that is
  /// not a string at all — yields [orElse] (default [TomAuthState.none], the
  /// closed/safe fallback) rather than throwing.
  ///
  /// [token] is `Object?` rather than `String?` deliberately. The grant matrix
  /// stores its cells in a `Map<String, Object?>`, so a value arriving off the
  /// wire may be any JSON type; keeping the guard here means `GrantMatrixDto`'s
  /// four readers cannot reintroduce a throwing path by narrowing the type
  /// themselves.
  static TomAuthState parseAccess(
    Object? token, {
    TomAuthState orElse = TomAuthState.none,
  }) {
    if (token is! String) return orElse;
    for (final state in TomAuthState.values) {
      if (state.name == token) return state;
    }
    return orElse;
  }

  @override
  String toString() => 'GradedFieldDto($resourceKey -> $access)';
}
