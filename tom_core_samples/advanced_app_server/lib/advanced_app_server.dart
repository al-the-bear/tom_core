/// App server for the advanced Tom Core full-stack sample.
///
/// A secured task-manager API on `tom_core_server`: it trusts the JWTs minted
/// by `advanced_auth_server`, resolves each request's principal access
/// (ownership + shares) and four-state field grades, and persists the `app_db`.
///
/// The persistence records, mapping layer, access/grade resolvers, endpoints,
/// and boot are wired in steps 14–21 of the implementation plan; this barrel is
/// the package's stable public entry point.
library;
