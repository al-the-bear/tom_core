/// What a store that keeps records for tenants in a system table does when a
/// tenant is purged.
library;

/// A store of a system table that records a tenant on its rows — the job
/// queue, the blob manifest, delivery reports, the suppression list, OAuth
/// sign-in state, service accounts and their API keys, saved audit questions —
/// and so can delete a
/// purged tenant's records. `TomTenancy.purgeTenant` calls it on every store
/// it is handed.
abstract interface class TomTenantData {
  /// Deletes every record this store keeps for [tenant]; answers how many.
  Future<int> purgeTenant(String tenant);
}
