/// Auth server for the advanced Tom Core full-stack sample.
///
/// A JWT issuer plus a role-gated admin API on `tom_core_server`: it
/// authenticates users against `auth_db`, mints the bearer-token pair both
/// clients present, and exposes `/admin/*` CRUD for users/roles/groups and the
/// `(role, resourceKey) → TomAuthState` grant matrix.
///
/// The auth_db records, password helper, authentication service, JWT endpoints,
/// admin API, and boot are wired in steps 7–13 of the implementation plan; this
/// barrel is the package's stable public entry point.
library;
