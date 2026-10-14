/// The grant-driven row scope fed by an external item-authorization
/// authority: a row is visible when its resource key is an item the principal
/// reaches at a level that grants `read`, and writable at one that grants
/// `full`.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../object_persistence/data_scope.dart';
import 'item_authorization_client.dart';

/// A [TomResourceScopeSource] that asks the authority, through [client], which
/// items of each of [itemTypes] a principal reaches.
///
/// For each type the readable keys are the items at the type's weakest level
/// that grants `read` or above ([TomItemType.lowestLevelGranting]), the
/// writable keys those at its weakest level that grants `full`; a type with no
/// such level contributes nothing. Keys are item keys, `<type>:<id>`, so the
/// scoped table's resource-key column holds item keys. The lists are gathered
/// page by page and cached until a change names their subject or type.
class TomItemAuthorityScopeSource implements TomResourceScopeSource {
  /// Creates the source for [itemTypes].
  TomItemAuthorityScopeSource(this.client, Iterable<TomItemType> itemTypes)
    : itemTypes = List.unmodifiable(itemTypes);

  /// The client asked.
  final TomItemAuthorizationClient client;

  /// The item types whose items the scoped tables hold.
  final List<TomItemType> itemTypes;

  /// Installs this source behind the built-in `resource` scope kind,
  /// replacing the one installed before.
  void install() => TomDataScopeRegistry.resourceScopeSource = this;

  @override
  Future<List<Object?>> readableResourceKeys(TomPrincipal? principal) =>
      _keys(principal, TomAuthState.read);

  @override
  Future<List<Object?>> writableResourceKeys(TomPrincipal? principal) =>
      _keys(principal, TomAuthState.full);

  Future<List<Object?>> _keys(
    TomPrincipal? principal,
    TomAuthState grade,
  ) async {
    final keys = <Object?>[];
    for (final type in itemTypes) {
      final minimumLevel = type.lowestLevelGranting(grade);
      if (minimumLevel == null) continue;
      final ids = await client.accessibleItemIds(
        principal,
        type,
        minimumLevel: minimumLevel,
      );
      keys.addAll(ids.map(type.keyFor));
    }
    return keys;
  }
}
