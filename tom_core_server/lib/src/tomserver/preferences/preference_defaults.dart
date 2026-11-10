/// Default preferences beneath every principal's own: the deployment's, and
/// each role's.
///
/// ## The order a value is chosen in
///
/// For a key, a principal reads, in this order:
///
/// 1. its own value ([TomUserPreferences]);
/// 2. a default of a role it holds — of several, the one with the highest
///    [TomPreferenceDefault.precedence], then the role name first in code-unit
///    order, so the answer never depends on the order roles are listed in;
/// 3. the deployment's default;
///
/// and nothing when none of the three exists. Deleting its own value brings
/// the default back; a default is never copied into the principal's rows.
///
/// ## Who writes them
///
/// The server. This is an administrative service with no endpoint of its own:
/// which roles get which defaults is a deployment's policy, and an application
/// that lets an administrator edit them puts this service behind its own
/// administrative gate.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../object_persistence/crud_repository.dart';
import 'preference_default.dart';
import 'user_preferences_service.dart';

/// Reads and writes [TomPreferenceDefault]s.
///
/// Installed as a bean so [TomUserPreferences] can find it:
///
/// ```dart
/// TomBean.withType<TomPreferenceDefaults>(
///   TomPreferenceDefaults(TomPreferenceDefaultRepository()),
/// );
/// ```
class TomPreferenceDefaults {
  /// The repository default rows are read and written through.
  final TomSqlDatasourceRepository<TomPreferenceDefault, int> repository;

  /// Creates the service over [repository].
  const TomPreferenceDefaults(this.repository);

  /// The installed [TomPreferenceDefaults] bean, or `null` when none is
  /// registered — in which case no principal reads a default.
  static TomPreferenceDefaults? resolve() {
    final installed = TomBean.getBeanByType(TomPreferenceDefaults);
    return installed is TomPreferenceDefaults ? installed : null;
  }

  /// The longest role name a role default can name.
  static const int maxRoleLength = 191;

  /// Sets the deployment's default under [key] to [value].
  Future<TomUserPreferenceDto> setForDeployment<T extends Object>(
    String key,
    T value,
  ) => _write(TomPreferenceDefaultScope.deployment, '', key, value, 0);

  /// Sets the default under [key] for the holders of [role] to [value];
  /// [precedence] decides between the defaults of several roles a principal
  /// holds — see the library documentation.
  Future<TomUserPreferenceDto> setForRole<T extends Object>(
    String role,
    String key,
    T value, {
    int precedence = 0,
  }) async {
    _validateRole(role);
    return _write(TomPreferenceDefaultScope.role, role, key, value, precedence);
  }

  /// Removes the deployment's default under [key]; answers whether one was
  /// there.
  Future<bool> removeForDeployment(String key) =>
      _remove(TomPreferenceDefaultScope.deployment, '', key);

  /// Removes [role]'s default under [key]; answers whether one was there.
  Future<bool> removeForRole(String role, String key) async {
    _validateRole(role);
    return _remove(TomPreferenceDefaultScope.role, role, key);
  }

  /// Every default, deployment defaults first, then by role and key.
  Future<List<TomPreferenceDefault>> all() async {
    final rows = await repository.findAll();
    int compare(TomPreferenceDefault a, TomPreferenceDefault b) =>
        a.scope != b.scope
        ? a.scope.index.compareTo(b.scope.index)
        : a.scopeName != b.scopeName
        ? a.scopeName.compareTo(b.scopeName)
        : a.preferenceKey.compareTo(b.preferenceKey);
    return rows..sort(compare);
  }

  /// The default a holder of [roles] reads under each key that has one, keyed
  /// by preference key.
  Future<Map<String, TomUserPreferenceDto>> effectiveFor(
    Iterable<String> roles,
  ) async {
    final held = roles.toSet();
    final rows = await repository.findAll();
    final chosen = <String, TomPreferenceDefault>{};
    for (final row in rows) {
      if (row.scope == TomPreferenceDefaultScope.role &&
          !held.contains(row.scopeName)) {
        continue;
      }
      final current = chosen[row.preferenceKey];
      if (current == null || _outranks(row, current)) {
        chosen[row.preferenceKey] = row;
      }
    }
    return {
      for (final MapEntry(:key, :value) in chosen.entries) key: value.toDto(),
    };
  }

  /// The default a holder of [roles] reads under [key], or `null`.
  Future<TomUserPreferenceDto?> effectiveValue(
    String key,
    Iterable<String> roles,
  ) async {
    TomUserPreferenceKeys.validate(key);
    final held = roles.toSet();
    final rows = await repository.findByQuerySentence(
      'FIND BY preference_key = :key',
      {'key': key},
    );
    TomPreferenceDefault? chosen;
    for (final row in rows) {
      if (row.scope == TomPreferenceDefaultScope.role &&
          !held.contains(row.scopeName)) {
        continue;
      }
      if (chosen == null || _outranks(row, chosen)) chosen = row;
    }
    return chosen?.toDto();
  }

  /// Whether [a] is chosen over [b] for one key: a role default over the
  /// deployment's, the higher precedence, then the role name first.
  static bool _outranks(TomPreferenceDefault a, TomPreferenceDefault b) {
    if (a.scope != b.scope) return a.scope == TomPreferenceDefaultScope.role;
    if (a.precedence != b.precedence) return a.precedence > b.precedence;
    return a.scopeName.compareTo(b.scopeName) < 0;
  }

  Future<TomUserPreferenceDto> _write<T extends Object>(
    TomPreferenceDefaultScope scope,
    String name,
    String key,
    T value,
    int precedence,
  ) async {
    TomUserPreferenceKeys.validate(key);
    final row = TomPreferenceDefault(
      scopeKind: scope.name,
      scopeName: name,
      preferenceKey: key,
      valueType: TomUserPreferenceCodec.typeNameOf(value, key),
      valueJson: TomUserPreferenceCodec.encodeValue(value, key),
      precedence: precedence,
      updatedAt: DateTime.now().toUtc(),
    );
    final saved = await repository.saveByKey(
      row,
      conflictFields: const [
        'tenantId',
        'scopeKind',
        'scopeName',
        'preferenceKey',
      ],
    );
    return saved.toDto();
  }

  Future<bool> _remove(
    TomPreferenceDefaultScope scope,
    String name,
    String key,
  ) async {
    TomUserPreferenceKeys.validate(key);
    final removed = await repository.deleteByQuerySentence(
      'DELETE BY scope_kind = :kind AND scope_name = :name '
      'AND preference_key = :key',
      {'kind': scope.name, 'name': name, 'key': key},
    );
    return removed > 0;
  }

  static void _validateRole(String role) {
    if (role.isEmpty || role.length > maxRoleLength) {
      throw TomUserPreferenceException(
        'preferences.default.invalid_role',
        'A role default needs a role name of 1 to $maxRoleLength characters.',
        parameters: {'role': role},
      );
    }
  }
}
