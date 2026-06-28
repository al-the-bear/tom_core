/// App server for the advanced Tom Core full-stack sample.
///
/// A secured task-manager API on `tom_core_server`: it trusts the JWTs minted
/// by `advanced_auth_server`, resolves each request's principal access
/// (ownership + shares) and four-state field grades, and persists the `app_db`.
///
/// The persistence records (step 14), the domain↔record mapping (step 15), the
/// resource-access resolver (step 17), and the field-grade resolver (step 18)
/// are wired below; the endpoints and boot follow in steps 19–21. This barrel is
/// the package's stable public entry point.
library;

export 'src/access/field_grade_resolver.dart';
export 'src/access/resource_access_resolver.dart';
export 'src/persistence/app_mapping.dart';
export 'src/persistence/app_persistence_model.dart';
