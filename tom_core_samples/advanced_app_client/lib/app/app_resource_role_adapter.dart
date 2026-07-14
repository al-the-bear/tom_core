/// The [TomAuthorizationAdapter] the app installs at login (RCC2): a
/// [TomResourceRoleAdapter] over the principal's `resourceRoles`, guarded so it
/// only gates *resource keys* and leaves every other authorizable permissive.
///
/// RCC2 installs a global adapter so the item screen resolves each field's
/// resource-level state *through the framework registry* rather than stamping a
/// DB-resolved grade directly. But a bare [TomResourceRoleAdapter] answers **every**
/// authorization lookup — and the app has many that are not resource keys: action
/// canonical paths (`todo.item.save`, `board.share`), form-field scope paths
/// (`todo.item.title`), and chrome. Those are not in the `resourceRoles` map, so a
/// bare adapter would collapse them to [TomAuthState.none] and disable the whole
/// UI. Before RCC2 no adapter was installed, so they resolved to the framework's
/// permissive default (`full`); this wrapper preserves exactly that for them.
///
/// The discriminator is the key shape the sample already uses: resource keys are
/// `<type>:<id>` (they contain a `:` — see [ResourceRoleKeys]), while action /
/// field / group paths are dotted (`todo.item.save`). So a key with a `:` is
/// delegated to the wrapped [TomResourceRoleAdapter] (closed by design: no role →
/// `none`); any other key stays permissive (`full`), matching pre-RCC2 behaviour.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A [TomResourceRoleAdapter] that gates only `<type>:<id>` resource keys and
/// resolves every other path to [TomAuthState.full] (the framework's no-adapter
/// default).
class AppResourceRoleAdapter implements TomAuthorizationAdapter {
  /// The wrapped resource-role adapter that resolves resource keys through the
  /// principal's `resourceRoles` and the [TomResourceRoleRegistry].
  final TomResourceRoleAdapter _resourceRoles;

  /// Builds the adapter over the principal's `resourceKey → roleName` map
  /// (typically `principal.aci.resourceRoles`).
  AppResourceRoleAdapter(Map<String, String> resourceRoles)
      : _resourceRoles = TomResourceRoleAdapter(resourceRoles);

  @override
  TomAuthState resolveAuth(String resourceKeyPath) {
    // Only `<type>:<id>` resource keys are gated by the registry; dotted action /
    // field / group paths keep the permissive default the app had before RCC2.
    if (!resourceKeyPath.contains(':')) return TomAuthState.full;
    return _resourceRoles.resolveAuth(resourceKeyPath);
  }
}
