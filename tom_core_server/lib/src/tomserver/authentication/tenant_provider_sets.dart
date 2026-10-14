/// External-identity provider sets installed per tenant, beside the
/// deployment's own.
///
/// A tenant that federates with identity providers of its own — its staff
/// directory, its customer's Entra ID — gets a provider set of its own, and a
/// sign-in in that tenant offers and accepts only those providers. A tenant
/// with no set of its own uses the deployment's. The sets come from the
/// configuration (`oauth.tenants.<id>.providers`, `saml.tenants.<id>.providers`)
/// or are installed at run time by a deployment that keeps its federation
/// sources in its own database, and replaced when the tenant changes them.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Values of type [T] — a provider set — keyed by tenant id.
class TomTenantProviderSets<T> {
  final Map<String, T> _byTenant = {};

  /// Installs [set] for [tenantId], replacing the tenant's previous one.
  ///
  /// Throws `tenancy.id.invalid` for an id that is not a tenant id.
  void install(String tenantId, T set) {
    TomTenantContext.validate(tenantId);
    _byTenant[tenantId] = set;
  }

  /// Removes [tenantId]'s set, so the tenant uses the deployment's again;
  /// answers the removed set, or `null` when it had none.
  T? remove(String tenantId) => _byTenant.remove(tenantId);

  /// [tenantId]'s own set, or `null` when it has none.
  T? forTenant(String tenantId) => _byTenant[tenantId];

  /// The set of the tenant in context, or `null` outside every tenant and for
  /// a tenant with no set of its own.
  T? get current {
    final tenant = TomTenantContext.currentId;
    return tenant == null ? null : _byTenant[tenant];
  }

  /// The tenants that have a set of their own.
  Set<String> get tenants => Set.unmodifiable(_byTenant.keys);

  /// Removes every tenant's set.
  void clear() => _byTenant.clear();
}
