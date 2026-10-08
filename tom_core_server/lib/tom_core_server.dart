/// Tom Core Server — the server half of the Tom stack.
///
/// Twenty modules over `tom_core_kernel`: the `TomServer` that composes a shelf
/// pipeline in front of a reflected endpoint router, the object persistence,
/// datasource and migration layers beneath it, and the services a deployment
/// builds on those — authentication and authorization, audit, messaging,
/// export, file storage, scheduling, caching, preferences and localized
/// resources.
///
/// Everything is exported from this one library, so `TomServer`,
/// `TomSqlDatasourceRepository` and `TomAuditTrail` are all reachable from a
/// single import:
///
/// ```dart
/// import 'package:tom_core_server/tom_core_server.dart';
/// ```
///
/// Each module has a guide under `doc/` and a runnable sample under
/// `example/`; `example/tom_core_server_example.dart` is the index of the
/// samples and runs them all.
library;

export 'src/tomserver/audit/audit_anchor.dart';
export 'src/tomserver/audit/audit_anchor_monitor.dart';
export 'src/tomserver/audit/audit_anchor_store.dart';
export 'src/tomserver/audit/audit_query.dart';
export 'src/tomserver/audit/audit_record.dart';
export 'src/tomserver/audit/audit_sink.dart';
export 'src/tomserver/audit/audit_trail.dart';
export 'src/tomserver/audit/sql_audit_sink.dart';
export 'src/tomserver/audit/sql_audit_sql.dart';
export 'src/tomserver/authentication/authentication_server.dart';
export 'src/tomserver/authentication/jwt_signing.dart';
export 'src/tomserver/authentication/oauth_authentication_service.dart';
export 'src/tomserver/authentication/oauth_endpoints.dart';
export 'src/tomserver/authentication/oauth_flow.dart';
export 'src/tomserver/authentication/oauth_identity.dart';
export 'src/tomserver/authentication/oauth_provider.dart';
export 'src/tomserver/authentication/oauth_state_sql.dart';
export 'src/tomserver/authentication/oauth_tokens.dart';
export 'src/tomserver/authentication/server_self_login.dart';
export 'src/tomserver/authentication/sql_oauth_state_store.dart';
export 'src/tomserver/authentication/two_factor.dart';
export 'src/tomserver/authentication/two_factor_attempts.dart';
export 'src/tomserver/authentication/two_factor_delivered_code.dart';
export 'src/tomserver/authentication/two_factor_enrolment.dart';
export 'src/tomserver/authentication/two_factor_policy.dart';
export 'src/tomserver/authentication/two_factor_webauthn.dart';
export 'src/tomserver/authentication/webauthn_software_authenticator.dart';
export 'src/tomserver/authorization/authorization_cache.dart';
export 'src/tomserver/authorization/graded_authorization.dart';
export 'src/tomserver/authorization/principal_delegation.dart';
export 'src/tomserver/authorization/principal_resource_grant.dart';
export 'src/tomserver/authorization/resource_data_scope.dart';
export 'src/tomserver/cmdline/args.dart';
export 'src/tomserver/cmdline/env_file.dart';
export 'src/tomserver/configuration/base_server_configuration.dart';
export 'src/tomserver/configuration/runtime_environment.dart';
export 'src/tomserver/configuration/tom_config.dart';
export 'src/tomserver/configuration/yaml_resources.dart';
export 'src/tomserver/cache/server_cache.dart';
export 'src/tomserver/datasources/datasource_initialization.dart';
export 'src/tomserver/datasources/framework_table.dart';
export 'src/tomserver/datasources/mariadb_datasource.dart';
export 'src/tomserver/datasources/mariadb_sql_dialect.dart';
export 'src/tomserver/datasources/queries.dart';
export 'src/tomserver/datasources/sql_dialects.dart';
export 'src/tomserver/datasources/sql_failure_mode.dart';
export 'src/tomserver/datasources/sql_instant.dart';
export 'src/tomserver/datasources/sql_lexer.dart';
export 'src/tomserver/datasources/sql_placeholder_scan.dart';
export 'src/tomserver/datasources/types_operator.dart';
export 'src/tomserver/db_migration/db_migration.dart';
export 'src/tomserver/db_migration/framework_convergence.dart';
export 'src/tomserver/db_migration/mariadb_migration_adapter.dart';
export 'src/tomserver/db_migration/schema_convergence.dart';
export 'src/tomserver/db_migration/schema_ddl_reader.dart';
export 'src/tomserver/db_migration/schema_model.dart';
export 'src/tomserver/endpoints/endpoint_annotation.dart';
export 'src/tomserver/endpoints/endpoint_pipeline.dart';
export 'src/tomserver/endpoints/endpoint_results.dart';
export 'src/tomserver/endpoints/file_endpoint.dart';
export 'src/tomserver/endpoints/form_binding.dart';
export 'src/tomserver/endpoints/web_socket_endpoint.dart';
export 'src/tomserver/export/blob_export_store.dart';
export 'src/tomserver/export/csv_renderer.dart';
export 'src/tomserver/export/export_service.dart';
export 'src/tomserver/export/export_store.dart';
export 'src/tomserver/export/pdf_renderer.dart';
export 'src/tomserver/export/tabular_renderer.dart';
export 'src/tomserver/export/tabular_result.dart';
export 'src/tomserver/export/xlsx_renderer.dart';
export 'src/tomserver/file_storage/aws_v4_signer.dart';
export 'src/tomserver/file_storage/blob_store.dart';
export 'src/tomserver/file_storage/blob_store_backends.dart';
export 'src/tomserver/file_storage/blob_store_registry.dart';
export 'src/tomserver/file_storage/database_blob_sql.dart';
export 'src/tomserver/file_storage/database_blob_store.dart';
export 'src/tomserver/file_storage/directory_blob_store.dart';
export 'src/tomserver/file_storage/s3_blob_store.dart';
export 'src/tomserver/healthcheck/health_check.dart';
export 'src/tomserver/little_things/request_id.dart';
export 'src/tomserver/little_things/server_exception.dart';
export 'src/tomserver/messaging/delivery_report.dart';
export 'src/tomserver/messaging/delivery_report_endpoint.dart';
export 'src/tomserver/messaging/delivery_report_sql.dart';
export 'src/tomserver/messaging/email_service.dart';
export 'src/tomserver/messaging/message.dart';
export 'src/tomserver/messaging/message_transport.dart';
export 'src/tomserver/messaging/mime_encoder.dart';
export 'src/tomserver/messaging/outbox.dart';
export 'src/tomserver/messaging/push_service.dart';
export 'src/tomserver/messaging/push_transport.dart';
export 'src/tomserver/messaging/sms_service.dart';
export 'src/tomserver/messaging/sms_transport.dart';
export 'src/tomserver/messaging/smtp_transport.dart';
export 'src/tomserver/messaging/sql_delivery_report_store.dart';
export 'src/tomserver/messaging/templated_message_service.dart';
export 'src/tomserver/messaging/vendor_mapping.dart';
export 'src/tomserver/messaging/webhook_transport.dart';
export 'src/tomserver/object_persistence/annotation_analyzer.dart';
export 'src/tomserver/object_persistence/blob_migration.dart';
export 'src/tomserver/object_persistence/column_authorization.dart';
export 'src/tomserver/object_persistence/composite_key.dart';
export 'src/tomserver/object_persistence/crud_repository.dart';
export 'src/tomserver/object_persistence/data_scope.dart';
export 'src/tomserver/object_persistence/file_reference.dart';
export 'src/tomserver/object_persistence/grouped_query.dart';
export 'src/tomserver/object_persistence/mariadb_repository.dart';
export 'src/tomserver/object_persistence/operators_expressions.dart';
export 'src/tomserver/object_persistence/paging.dart';
export 'src/tomserver/object_persistence/persistence_annotations.dart';
export 'src/tomserver/object_persistence/query_builder.dart';
export 'src/tomserver/object_persistence/query_sentence_compiler.dart';
export 'src/tomserver/preferences/user_preference.dart';
export 'src/tomserver/preferences/user_preferences_endpoints.dart';
export 'src/tomserver/preferences/user_preferences_service.dart';
export 'src/tomserver/resources/localized_text_resources.dart';
export 'src/tomserver/scheduling/sql_job_store.dart';
export 'src/tomserver/scheduling/sql_lease_lock.dart';
export 'src/tomserver/scheduling/sql_scheduler_nodes.dart';
export 'src/tomserver/scheduling/sql_scheduling_sql.dart';
export 'src/tomserver/server/server.dart';
export 'src/tomserver/transactions/transaction_manager.dart';
export 'package:mysql_client/mysql_client.dart';
// The driver's own barrel omits its exception taxonomy, but
// [classifySqlFailure] states its contract in terms of `MySQLServerException`
// ("the server answered, so the failure is definite"). A caller that has to
// reason about that answer must be able to name the type.
export 'package:mysql_client/exception.dart';
export 'package:tom_core_kernel/tom_core_kernel.dart';
export 'package:tom_basics_console/tom_basics_console.dart';
