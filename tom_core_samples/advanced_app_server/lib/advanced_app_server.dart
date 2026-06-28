/// App server for the advanced Tom Core full-stack sample.
///
/// A secured task-manager API on `tom_core_server`: it trusts the JWTs minted
/// by `advanced_auth_server`, resolves each request's principal access
/// (ownership + shares) and four-state field grades, and persists the `app_db`.
///
/// The persistence records (step 14) are wired below; the mapping layer,
/// access/grade resolvers, endpoints, and boot follow in steps 15–21. This
/// barrel is the package's stable public entry point.
library;

export 'src/persistence/app_persistence_model.dart';
