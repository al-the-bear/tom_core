/// Auth server for the advanced Tom Core full-stack sample.
///
/// A JWT issuer plus a role-gated admin API on `tom_core_server`: it
/// authenticates users against `auth_db`, mints the bearer-token pair both
/// clients present, and exposes `/admin/*` CRUD for users/roles/groups and the
/// `(role, resourceKey) → TomAuthState` grant matrix.
///
/// The `auth_db` records and their domain/DTO mapping live in
/// `src/persistence/`, the password helper in
/// `src/auth/password_hashing.dart`, and the login itself in
/// `src/auth/authentication_service.dart`; the JWT endpoints
/// (`src/endpoints/auth_endpoints.dart`) and the admin API
/// (`src/endpoints/admin_endpoints.dart`) are assembled into a running server
/// by `bin/auth_server_start.dart`. This barrel is the package's stable public
/// entry point.
library;

export 'src/auth/authentication_service.dart';
export 'src/auth/password_hashing.dart';
export 'src/auth/two_factor_enrolment_store.dart';
export 'src/endpoints/admin_endpoints.dart';
export 'src/endpoints/auth_endpoints.dart';
export 'src/persistence/auth_mapping.dart';
export 'src/persistence/auth_persistence_model.dart';
export 'src/resources/auth_resource_bundles.dart';
