/// App server for the advanced Tom Core full-stack sample.
///
/// A secured task-manager API on `tom_core_server`: it trusts the JWTs minted
/// by `advanced_auth_server`, resolves each request's principal access
/// (ownership + shares) and four-state field grades, and persists the `app_db`.
///
/// The persistence records (step 14), the domain↔record mapping (step 15), and
/// the resource-access resolver (step 17) are wired below; the field-grade
/// resolver, endpoints, and boot follow in steps 18–21. This barrel is the
/// package's stable public entry point.
library;

export 'src/access/resource_access_resolver.dart';
export 'src/persistence/app_mapping.dart';
export 'src/persistence/app_persistence_model.dart';
