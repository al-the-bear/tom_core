/// App server for the advanced Tom Core full-stack sample.
///
/// A secured task-manager API on `tom_core_server`: it trusts the JWTs minted
/// by `advanced_auth_server`, resolves each request's principal access
/// (ownership + shares) and four-state field grades, and persists the `app_db`.
///
/// The persistence records, the domain↔record mapping, the resource-access
/// resolver, the field-grade resolver, the read endpoints, the write
/// endpoints, and the share endpoints + live boot are all wired below. This
/// barrel is the package's stable public entry point.
library;

export 'src/access/column_grade_resolver.dart';
export 'src/access/field_grade_resolver.dart';
export 'src/access/ownership_grant_writer.dart';
export 'src/access/resource_role_resolver.dart';
export 'src/access/share_delegation_store.dart';
export 'src/access/visible_resource_resolver.dart';
export 'src/endpoints/app_endpoints.dart';
export 'src/persistence/app_mapping.dart';
export 'src/persistence/app_persistence_model.dart';
export 'src/resources/app_resource_bundles.dart';
