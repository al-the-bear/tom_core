/// Auth server for the advanced Tom Core full-stack sample.
///
/// A JWT issuer plus a role-gated admin API on `tom_core_server`: it
/// authenticates users against `auth_db`, mints the bearer-token pair both
/// clients present, and exposes `/admin/*` CRUD for users/roles/groups and the
/// `(role, resourceKey) → TomAuthState` grant matrix.
///
/// The auth_db records + domain/DTO mapping are defined in step 7; the password
/// helper, authentication service, JWT endpoints, admin API, and boot are wired
/// in steps 8–13 of the implementation plan. This barrel is the package's stable
/// public entry point.
library;

export 'src/persistence/auth_mapping.dart';
export 'src/persistence/auth_persistence_model.dart';
