// D4rt Bridge - Generated file, do not edit
// Sources: 38 files
// Generated: 2026-03-12T17:01:52.835520

// ignore_for_file: unused_import, deprecated_member_use, prefer_function_declarations_over_variables, implementation_imports, sort_child_properties_last, non_constant_identifier_names, avoid_function_literals_in_foreach_calls

import 'package:tom_d4rt/d4rt.dart';
import 'package:tom_d4rt/tom_d4rt.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:console_markdown/console_markdown.dart' as $console_markdown_1;
import 'package:http/src/client.dart' as $http_1;
import 'package:mysql_client/src/mysql_client/connection.dart' as $mysql_client_1;
import 'package:mysql_client/src/mysql_protocol/mysql_column_type.dart' as $mysql_client_2;
import 'package:mysql_client/src/mysql_protocol/packet/packet_ok.dart' as $mysql_client_3;
import 'package:shelf/src/handler.dart' as $shelf_1;
import 'package:shelf/src/middleware.dart' as $shelf_2;
import 'package:shelf/src/request.dart' as $shelf_3;
import 'package:shelf/src/response.dart' as $shelf_4;
import 'package:shelf_router/src/router.dart' as $shelf_router_1;
import 'package:stream_channel/stream_channel.dart' as $stream_channel_1;
import 'package:tom_basics/src/logging/logging.dart' as $tom_basics_1;
import 'package:tom_basics/src/runtime/platform_environment_runtime.dart' as $tom_basics_2;
import 'package:tom_basics/src/runtime/platform_neutral.dart' as $tom_basics_3;
import 'package:tom_core_kernel/src/tombase/http_connection/endpoints_apis.dart' as $tom_core_kernel_1;
import 'package:tom_core_kernel/src/tombase/http_connection/httpmethods.dart' as $tom_core_kernel_2;
import 'package:tom_core_kernel/src/tombase/http_connection/mimetypes.dart' as $tom_core_kernel_3;
import 'package:tom_core_kernel/src/tombase/http_connection/server_connection.dart' as $tom_core_kernel_4;
import 'package:tom_core_kernel/src/tombase/observable/tom_observable.dart' as $tom_core_kernel_5;
import 'package:tom_core_kernel/src/tombase/observable/tom_observable_objects.dart' as $tom_core_kernel_6;
import 'package:tom_core_kernel/src/tombase/security/access_controls.dart' as $tom_core_kernel_7;
import 'package:tom_core_kernel/src/tombase/security/authentication_authorization.dart' as $tom_core_kernel_8;
import 'package:tom_core_kernel/src/tombase/security/user_principal_aci.dart' as $tom_core_kernel_9;
import 'package:tom_core_kernel/src/tombase/timezoned/date_timestamp.dart' as $tom_core_kernel_10;
import 'package:tom_core_server/src/tomserver/authentication/authentication_server.dart' as $tom_core_server_1;
import 'package:tom_core_server/src/tomserver/cache/server_cache.dart' as $tom_core_server_2;
import 'package:tom_core_server/src/tomserver/configuration/base_server_configuration.dart' as $tom_core_server_3;
import 'package:tom_core_server/src/tomserver/datasources/datasource_initialization.dart' as $tom_core_server_4;
import 'package:tom_core_server/src/tomserver/datasources/mariadb_datasource.dart' as $tom_core_server_5;
import 'package:tom_core_server/src/tomserver/datasources/queries.dart' as $tom_core_server_6;
import 'package:tom_core_server/src/tomserver/datasources/sql_dialects.dart' as $tom_core_server_7;
import 'package:tom_core_server/src/tomserver/datasources/types_operator.dart' as $tom_core_server_8;
import 'package:tom_core_server/src/tomserver/db_migration/mariadb_migration_adapter.dart' as $tom_core_server_9;
import 'package:tom_core_server/src/tomserver/endpoints/endpoint_annotation.dart' as $tom_core_server_10;
import 'package:tom_core_server/src/tomserver/endpoints/endpoint_pipeline.dart' as $tom_core_server_11;
import 'package:tom_core_server/src/tomserver/healthcheck/health_check.dart' as $tom_core_server_12;
import 'package:tom_core_server/src/tomserver/object_persistence/crud_repository.dart' as $tom_core_server_13;
import 'package:tom_core_server/src/tomserver/object_persistence/operators_expressions.dart' as $tom_core_server_14;
import 'package:tom_core_server/src/tomserver/object_persistence/persistence_annotations.dart' as $tom_core_server_15;
import 'package:tom_core_server/src/tomserver/transactions/transaction_manager.dart' as $tom_core_server_16;
import 'package:tom_crypto/src/jwt_token.dart' as $tom_crypto_1;
import 'package:tom_reflection/src/reflection/mirrors.dart' as $tom_reflection_1;
import 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\sql_dialects.dart' as $aux_aux;
import 'package:shelf/src/message.dart' as $aux_shelf;
import 'package:tom_core_kernel/src/tombase/isolate_pooling/tom_worker.dart' as $aux_tom_core_kernel_2;
import 'package:tom_core_kernel/src/tombase/little_things/exception_base.dart' as $aux_tom_core_kernel;
import 'package:tom_core_server/src/tomserver/configuration/tom_config.dart' as $aux_tom_core_server_2;
import 'package:tom_core_server/src/tomserver/little_things/server_exception.dart' as $aux_tom_core_server;

/// Bridge class for tom_core_server module.
class TomCoreServerBridge {
  /// Returns all bridge class definitions.
  static List<BridgedClass> bridgeClasses() {
    return [
      _createTomAuthenticationAdaptorBridge(),
      _createTom2FAAdaptorBridge(),
      _createLoginExceptionBridge(),
      _createTomAuthenticationDataBridge(),
      _createTomAuthenticationServiceBridge(),
      _createTom2FAServiceBridge(),
      _createTomAuthenticationInfoBridge(),
      _createTomDummyAuthenticationServiceBridge(),
      _createTomAuthenticationServerBridge(),
      _createTomAuthorizationCacheExceptionBridge(),
      _createTomAuthorizationCacheEntryBridge(),
      _createTomAuthorizationCacheBridge(),
      _createTomAuthorizationCacheStoreMessageBridge(),
      _createTomAuthorizationCacheRetrieveMessageBridge(),
      _createTomAuthorizationCacheExecutorBridge(),
      _createTomArgsBridge(),
      _createTomEnvFileBridge(),
      _createTomServerConfigResourceProviderBridge(),
      _createTomBaseServerConfigurationBridge(),
      _createTomConfigBridge(),
      _createTomStringConfigBridge(),
      _createTomIntConfigBridge(),
      _createTomDoubleConfigBridge(),
      _createTomBoolConfigBridge(),
      _createTomYamlBridge(),
      _createTomCacheExceptionBridge(),
      _createTomCacheEntryBridge(),
      _createTomCacheManagerBridge(),
      _createTomCacheBridge(),
      _createTomCacheStoreMessageBridge(),
      _createTomCacheRemoveMessageBridge(),
      _createTomCacheRetrieveMessageBridge(),
      _createTomDatasourceInitExceptionBridge(),
      _createTomDatasourceDriverBridge(),
      _createTomPreparedStatementBridge(),
      _createTomDataSourceBridge(),
      _createTomDataSourceInfoBridge(),
      _createMariadbDatasourceExceptionBridge(),
      _createMariadbPreparedStatementExceptionBridge(),
      _createMariadbPreparedStatementBridge(),
      _createMariaDbDatasourceBridge(),
      _createMariaDbXADatasourceBridge(),
      _createMariadbSqlDialectBridge(),
      _createTomTypePersistenceInfoBridge(),
      _createTomTypedPersistenceBaseBridge(),
      _createTomQueryBridge(),
      _createTomGeneratedQueryBridge(),
      _createTomSelectBridge(),
      _createTomLiteralSelectBridge(),
      _createTomCountBridge(),
      _createTomDeleteBridge(),
      _createTomStandardSqlDialectBridge(),
      _createTomSqlDialectBridge(),
      _createTomDbTypeBridge(),
      _createTomDbIntBridge(),
      _createTomDbDoubleBridge(),
      _createTomDbStringBridge(),
      _createTomDbDateTimeBridge(),
      _createTomDbDateBridge(),
      _createTomDbTimeBridge(),
      _createTomDbBoolBridge(),
      _createTomOperatorBridge(),
      _createTomDbMigrationExceptionBridge(),
      _createTomDbMigrationAdaptorBridge(),
      _createTomDbMigratorBridge(),
      _createTomDbMigrationsBridge(),
      _createMariadbMigrationExceptionBridge(),
      _createMariadbMigrationAdaptorBridge(),
      _createTomDbVersionBridge(),
      _createTomErrorHandlerBridge(),
      _createTomDefaultErrorHandlerBridge(),
      _createTomServiceBridge(),
      _createTomApiImplementationBridge(),
      _createTomEndpointBaseBridge(),
      _createTomApiEndpointImplementationBridge(),
      _createTomEndpointBridge(),
      _createTomComponentReferenceBridge(),
      _createTomTransactionalBridge(),
      _createTomEndpointHandlerExceptionBridge(),
      _createTomEndpointPipelineExceptionBridge(),
      _createTomEndpointHandlerBridge(),
      _createTomEndpointRoutingInfoBridge(),
      _createTomEndpointRoutingBridge(),
      _createTomMethodMetadataBridge(),
      _createTomClassScanResultBridge(),
      _createHealthAnalyzerBridge(),
      _createDefaultHealthAnalyzerBridge(),
      _createTomHealthServiceBridge(),
      _createTomHealthServerBridge(),
      _createTomServerExceptionBridge(),
      _createTomAnnotationAnalyzerExceptionBridge(),
      _createTomAnnotationAnalyzerSyntaxExceptionBridge(),
      _createTomAnnotationAnalyzerBridge(),
      _createTomCountResultBridge(),
      _createTomRepositoryBridge(),
      _createTomSqlDatasourceRepositoryBridge(),
      _createTomRepositoryTypeBridge(),
      _createMariadbRepositoryBridge(),
      _createTomQuerySyntaxExceptionBridge(),
      _createTomUnaryOperatorBridge(),
      _createParameterBridge(),
      _createDbColBridge(),
      _createIntColBridge(),
      _createStringColBridge(),
      _createDoubleColBridge(),
      _createBoolColBridge(),
      _createDateTimeColBridge(),
      _createDateColBridge(),
      _createStringLiteralBridge(),
      _createIntegerLiteralBridge(),
      _createDoubleLiteralBridge(),
      _createBoolLiteralBridge(),
      _createDateTimeLiteralBridge(),
      _createDateLiteralBridge(),
      _createNotBridge(),
      _createIsNullBridge(),
      _createIsNotNullBridge(),
      _createTomBinaryOperatorBridge(),
      _createAndBridge(),
      _createOrBridge(),
      _createEqBridge(),
      _createNeqBridge(),
      _createLtBridge(),
      _createGtBridge(),
      _createLteBridge(),
      _createGteBridge(),
      _createLikeBridge(),
      _createNotLikeBridge(),
      _createInBridge(),
      _createGroupBridge(),
      _createBetweenBridge(),
      _createRegexpBridge(),
      _createTomDartTypeBridge(),
      _createTomDbTableBridge(),
      _createTomDbColumnBridge(),
      _createTomEntityIdBridge(),
      _createTomJoinTableBridge(),
      _createTomReferenceBridge(),
      _createTomPersistenceEventHandlerBridge(),
      _createTomColumnInformationBridge(),
      _createTomQueryBuilderBridge(),
      _createTomQuerySentenceCompilerBridge(),
      _createTomRequestIdBridge(),
      _createTomRequestLogInfoBridge(),
      _createTomServerBridge(),
      _createTomTransactionExceptionBridge(),
      _createTomTransactionParticipantBridge(),
      _createTomTransactionBridge(),
      _createTomTransactionManagerBridge(),
      _createMySQLConnectionBridge(),
      _createIResultSetBridge(),
      _createResultSetBridge(),
      _createIterableResultSetBridge(),
      _createPreparedStmtResultSetBridge(),
      _createIterablePreparedStmtResultSetBridge(),
      _createEmptyResultSetBridge(),
      _createResultSetRowBridge(),
      _createResultSetColumnBridge(),
      _createPreparedStmtBridge(),
      _createMySQLConnectionPoolBridge(),
      _createTomStandalonePlatformUtilsBridge(),
      _createTomBaseExceptionBridge(),
      _createTomLogLevelBridge(),
      _createTomLoggerBridge(),
      _createTomLoggableBridge(),
      _createTomLogOutputBridge(),
      _createTomConsoleLogOutputBridge(),
      _createTomPlatformUtilsBridge(),
      _createTomFallbackPlatformUtilsBridge(),
      _createTomEnvironmentBridge(),
      _createTomPlatformBridge(),
      _createTomRuntimeBridge(),
      _createRequestBridge(),
    ];
  }

  /// Returns a map of class names to their canonical source URIs.
  ///
  /// Used for deduplication when the same class is exported through
  /// multiple barrels (e.g., tom_core_kernel and tom_core_server).
  static Map<String, String> classSourceUris() {
    return {
      'TomAuthenticationAdaptor': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\authentication\authentication_server.dart',
      'Tom2FAAdaptor': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\authentication\authentication_server.dart',
      'LoginException': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\authentication\authentication_server.dart',
      'TomAuthenticationData': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\authentication\authentication_server.dart',
      'TomAuthenticationService': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\authentication\authentication_server.dart',
      'Tom2FAService': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\authentication\authentication_server.dart',
      'TomAuthenticationInfo': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\authentication\authentication_server.dart',
      'TomDummyAuthenticationService': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\authentication\authentication_server.dart',
      'TomAuthenticationServer': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\authentication\authentication_server.dart',
      'TomAuthorizationCacheException': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\authorization\authorization_cache.dart',
      'TomAuthorizationCacheEntry': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\authorization\authorization_cache.dart',
      'TomAuthorizationCache': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\authorization\authorization_cache.dart',
      'TomAuthorizationCacheStoreMessage': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\authorization\authorization_cache.dart',
      'TomAuthorizationCacheRetrieveMessage': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\authorization\authorization_cache.dart',
      'TomAuthorizationCacheExecutor': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\authorization\authorization_cache.dart',
      'TomArgs': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\cmdline\args.dart',
      'TomEnvFile': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\cmdline\env_file.dart',
      'TomServerConfigResourceProvider': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\configuration\base_server_configuration.dart',
      'TomBaseServerConfiguration': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\configuration\base_server_configuration.dart',
      'TomConfig': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\configuration\tom_config.dart',
      'TomStringConfig': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\configuration\tom_config.dart',
      'TomIntConfig': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\configuration\tom_config.dart',
      'TomDoubleConfig': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\configuration\tom_config.dart',
      'TomBoolConfig': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\configuration\tom_config.dart',
      'TomYaml': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\configuration\yaml_resources.dart',
      'TomCacheException': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\cache\server_cache.dart',
      'TomCacheEntry': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\cache\server_cache.dart',
      'TomCacheManager': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\cache\server_cache.dart',
      'TomCache': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\cache\server_cache.dart',
      'TomCacheStoreMessage': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\cache\server_cache.dart',
      'TomCacheRemoveMessage': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\cache\server_cache.dart',
      'TomCacheRetrieveMessage': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\cache\server_cache.dart',
      'TomDatasourceInitException': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\datasource_initialization.dart',
      'TomDatasourceDriver': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\datasource_initialization.dart',
      'TomPreparedStatement': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\datasource_initialization.dart',
      'TomDataSource': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\datasource_initialization.dart',
      'TomDataSourceInfo': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\datasource_initialization.dart',
      'MariadbDatasourceException': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\mariadb_datasource.dart',
      'MariadbPreparedStatementException': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\mariadb_datasource.dart',
      'MariadbPreparedStatement': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\mariadb_datasource.dart',
      'MariaDbDatasource': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\mariadb_datasource.dart',
      'MariaDbXADatasource': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\mariadb_datasource.dart',
      'MariadbSqlDialect': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\mariadb_sql_dialect.dart',
      'TomTypePersistenceInfo': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\queries.dart',
      'TomTypedPersistenceBase': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\queries.dart',
      'TomQuery': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\queries.dart',
      'TomGeneratedQuery': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\queries.dart',
      'TomSelect': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\queries.dart',
      'TomLiteralSelect': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\queries.dart',
      'TomCount': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\queries.dart',
      'TomDelete': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\queries.dart',
      'TomStandardSqlDialect': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\sql_dialects.dart',
      'TomSqlDialect': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\sql_dialects.dart',
      'TomDbType': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\types_operator.dart',
      'TomDbInt': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\types_operator.dart',
      'TomDbDouble': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\types_operator.dart',
      'TomDbString': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\types_operator.dart',
      'TomDbDateTime': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\types_operator.dart',
      'TomDbDate': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\types_operator.dart',
      'TomDbTime': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\types_operator.dart',
      'TomDbBool': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\types_operator.dart',
      'TomOperator': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\types_operator.dart',
      'TomDbMigrationException': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\db_migration\db_migration.dart',
      'TomDbMigrationAdaptor': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\db_migration\db_migration.dart',
      'TomDbMigrator': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\db_migration\db_migration.dart',
      'TomDbMigrations': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\db_migration\db_migration.dart',
      'MariadbMigrationException': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\db_migration\mariadb_migration_adapter.dart',
      'MariadbMigrationAdaptor': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\db_migration\mariadb_migration_adapter.dart',
      'TomDbVersion': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\db_migration\mariadb_migration_adapter.dart',
      'TomErrorHandler': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\endpoints\endpoint_annotation.dart',
      'TomDefaultErrorHandler': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\endpoints\endpoint_annotation.dart',
      'TomService': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\endpoints\endpoint_annotation.dart',
      'TomApiImplementation': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\endpoints\endpoint_annotation.dart',
      'TomEndpointBase': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\endpoints\endpoint_annotation.dart',
      'TomApiEndpointImplementation': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\endpoints\endpoint_annotation.dart',
      'TomEndpoint': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\endpoints\endpoint_annotation.dart',
      'TomComponentReference': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\endpoints\endpoint_annotation.dart',
      'TomTransactional': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\endpoints\endpoint_annotation.dart',
      'TomEndpointHandlerException': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\endpoints\endpoint_pipeline.dart',
      'TomEndpointPipelineException': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\endpoints\endpoint_pipeline.dart',
      'TomEndpointHandler': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\endpoints\endpoint_pipeline.dart',
      'TomEndpointRoutingInfo': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\endpoints\endpoint_pipeline.dart',
      'TomEndpointRouting': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\endpoints\endpoint_pipeline.dart',
      'TomMethodMetadata': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\endpoints\endpoint_pipeline.dart',
      'TomClassScanResult': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\endpoints\endpoint_pipeline.dart',
      'HealthAnalyzer': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\healthcheck\health_check.dart',
      'DefaultHealthAnalyzer': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\healthcheck\health_check.dart',
      'TomHealthService': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\healthcheck\health_check.dart',
      'TomHealthServer': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\healthcheck\health_check.dart',
      'TomServerException': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\little_things\server_exception.dart',
      'TomAnnotationAnalyzerException': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\annotation_analyzer.dart',
      'TomAnnotationAnalyzerSyntaxException': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\annotation_analyzer.dart',
      'TomAnnotationAnalyzer': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\annotation_analyzer.dart',
      'TomCountResult': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\crud_repository.dart',
      'TomRepository': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\crud_repository.dart',
      'TomSqlDatasourceRepository': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\crud_repository.dart',
      'TomRepositoryType': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\crud_repository.dart',
      'MariadbRepository': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\mariadb_repository.dart',
      'TomQuerySyntaxException': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\operators_expressions.dart',
      'TomUnaryOperator': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\operators_expressions.dart',
      'Parameter': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\operators_expressions.dart',
      'DbCol': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\operators_expressions.dart',
      'IntCol': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\operators_expressions.dart',
      'StringCol': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\operators_expressions.dart',
      'DoubleCol': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\operators_expressions.dart',
      'BoolCol': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\operators_expressions.dart',
      'DateTimeCol': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\operators_expressions.dart',
      'DateCol': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\operators_expressions.dart',
      'StringLiteral': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\operators_expressions.dart',
      'IntegerLiteral': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\operators_expressions.dart',
      'DoubleLiteral': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\operators_expressions.dart',
      'BoolLiteral': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\operators_expressions.dart',
      'DateTimeLiteral': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\operators_expressions.dart',
      'DateLiteral': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\operators_expressions.dart',
      'Not': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\operators_expressions.dart',
      'IsNull': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\operators_expressions.dart',
      'IsNotNull': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\operators_expressions.dart',
      'TomBinaryOperator': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\operators_expressions.dart',
      'And': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\operators_expressions.dart',
      'Or': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\operators_expressions.dart',
      'Eq': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\operators_expressions.dart',
      'Neq': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\operators_expressions.dart',
      'Lt': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\operators_expressions.dart',
      'Gt': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\operators_expressions.dart',
      'Lte': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\operators_expressions.dart',
      'Gte': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\operators_expressions.dart',
      'Like': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\operators_expressions.dart',
      'NotLike': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\operators_expressions.dart',
      'In': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\operators_expressions.dart',
      'Group': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\operators_expressions.dart',
      'Between': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\operators_expressions.dart',
      'Regexp': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\operators_expressions.dart',
      'TomDartType': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\persistence_annotations.dart',
      'TomDbTable': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\persistence_annotations.dart',
      'TomDbColumn': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\persistence_annotations.dart',
      'TomEntityId': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\persistence_annotations.dart',
      'TomJoinTable': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\persistence_annotations.dart',
      'TomReference': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\persistence_annotations.dart',
      'TomPersistenceEventHandler': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\persistence_annotations.dart',
      'TomColumnInformation': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\persistence_annotations.dart',
      'TomQueryBuilder': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\query_builder.dart',
      'TomQuerySentenceCompiler': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\query_sentence_compiler.dart',
      'TomRequestId': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\server\server.dart',
      'TomRequestLogInfo': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\server\server.dart',
      'TomServer': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\server\server.dart',
      'TomTransactionException': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\transactions\transaction_manager.dart',
      'TomTransactionParticipant': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\transactions\transaction_manager.dart',
      'TomTransaction': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\transactions\transaction_manager.dart',
      'TomTransactionManager': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\transactions\transaction_manager.dart',
      'MySQLConnection': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\mysql_client-0.0.27\lib\src\mysql_client\connection.dart',
      'IResultSet': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\mysql_client-0.0.27\lib\src\mysql_client\connection.dart',
      'ResultSet': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\mysql_client-0.0.27\lib\src\mysql_client\connection.dart',
      'IterableResultSet': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\mysql_client-0.0.27\lib\src\mysql_client\connection.dart',
      'PreparedStmtResultSet': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\mysql_client-0.0.27\lib\src\mysql_client\connection.dart',
      'IterablePreparedStmtResultSet': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\mysql_client-0.0.27\lib\src\mysql_client\connection.dart',
      'EmptyResultSet': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\mysql_client-0.0.27\lib\src\mysql_client\connection.dart',
      'ResultSetRow': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\mysql_client-0.0.27\lib\src\mysql_client\connection.dart',
      'ResultSetColumn': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\mysql_client-0.0.27\lib\src\mysql_client\connection.dart',
      'PreparedStmt': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\mysql_client-0.0.27\lib\src\mysql_client\connection.dart',
      'MySQLConnectionPool': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\mysql_client-0.0.27\lib\src\mysql_client\pool.dart',
      'TomStandalonePlatformUtils': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_basics_console-1.0.0\lib\src\runtime\platform_detection_standalone.dart',
      'TomBaseException': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_basics-1.0.0\lib\src\exception_base.dart',
      'TomLogLevel': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_basics-1.0.0\lib\src\logging\logging.dart',
      'TomLogger': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_basics-1.0.0\lib\src\logging\logging.dart',
      'TomLoggable': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_basics-1.0.0\lib\src\logging\logging.dart',
      'TomLogOutput': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_basics-1.0.0\lib\src\logging\logging.dart',
      'TomConsoleLogOutput': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_basics-1.0.0\lib\src\logging\logging.dart',
      'TomPlatformUtils': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_basics-1.0.0\lib\src\runtime\platform_neutral.dart',
      'TomFallbackPlatformUtils': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_basics-1.0.0\lib\src\runtime\platform_neutral.dart',
      'TomEnvironment': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_basics-1.0.0\lib\src\runtime\platform_environment_runtime.dart',
      'TomPlatform': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_basics-1.0.0\lib\src\runtime\platform_environment_runtime.dart',
      'TomRuntime': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_basics-1.0.0\lib\src\runtime\platform_environment_runtime.dart',
      'Request': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\shelf-1.4.2\lib\src\request.dart',
    };
  }

  /// Returns a map of type alias names to their target class names.
  ///
  /// Type aliases like `typedef MaterialStateProperty<T> = WidgetStateProperty<T>`
  /// are registered so that code using the alias name can resolve to the
  /// bridged class under its canonical name.
  static Map<String, String> classAliases() {
    return {
      'SqlString': 'String',
    };
  }

  /// Returns the list of function typedef names declared in this library.
  ///
  /// Function typedefs like `typedef VoidCallback = void Function()` are
  /// registered so that they can be used as type arguments in D4rt scripts.
  static List<String> functionTypedefs() {
    return [
      'Middleware',
      'Handler',
    ];
  }

  /// Returns all bridged enum definitions.
  static List<BridgedEnumDefinition> bridgedEnums() {
    return [
    ];
  }

  /// Returns a map of enum names to their canonical source URIs.
  ///
  /// Used for deduplication when the same enum is exported through
  /// multiple barrels (e.g., tom_core_kernel and tom_core_server).
  static Map<String, String> enumSourceUris() {
    return {
    };
  }

  /// Returns all bridged extension definitions.
  static List<BridgedExtensionDefinition> bridgedExtensions() {
    return [
      BridgedExtensionDefinition(
        name: 'ConsoleMarkdownString',
        onTypeName: 'String',
        methods: {
          'toConsole': (visitor, target, positional, named, typeArgs) {
            final t = target as String;
            return Function.apply(t.toConsole, positional, named.map((k, v) => MapEntry(Symbol(k), v)));
          },
          'toStrictConsole': (visitor, target, positional, named, typeArgs) {
            final t = target as String;
            return Function.apply(t.toStrictConsole, positional, named.map((k, v) => MapEntry(Symbol(k), v)));
          },
        },
      ),
    ];
  }

  /// Returns a map of extension identifiers to their canonical source URIs.
  static Map<String, String> extensionSourceUris() {
    return {
      'ConsoleMarkdownString': 'package:console_markdown/console_markdown.dart',
    };
  }

  /// Registers all bridges with an interpreter.
  ///
  /// [importPath] is the package import path that D4rt scripts will use
  /// to access these classes (e.g., 'package:tom_build/tom.dart').
  static void registerBridges(D4rt interpreter, String importPath) {
    // Register bridged classes with source URIs for deduplication
    final classes = bridgeClasses();
    final classSources = classSourceUris();
    for (final bridge in classes) {
      interpreter.registerBridgedClass(bridge, importPath, sourceUri: classSources[bridge.name]);
    }

    // Register global variables
    registerGlobalVariables(interpreter, importPath);

    // Register global functions with source URIs for deduplication
    final funcs = globalFunctions();
    final funcSources = globalFunctionSourceUris();
    final funcSigs = globalFunctionSignatures();
    for (final entry in funcs.entries) {
      interpreter.registertopLevelFunction(entry.key, entry.value, importPath, sourceUri: funcSources[entry.key], signature: funcSigs[entry.key]);
    }

    // Register bridged extensions with source URIs for deduplication
    final extensions = bridgedExtensions();
    final extSources = extensionSourceUris();
    for (final extDef in extensions) {
      final extKey = extDef.name ?? '<unnamed>@${extDef.onTypeName}';
      interpreter.registerBridgedExtension(extDef, importPath, sourceUri: extSources[extKey]);
    }

    // Register class aliases (typedef type aliases)
    final aliases = classAliases();
    for (final entry in aliases.entries) {
      interpreter.registerClassAlias(entry.key, entry.value, importPath);
    }

    // Register function typedefs for type resolution
    final typedefs = functionTypedefs();
    for (final name in typedefs) {
      interpreter.registerFunctionTypedef(name, importPath);
    }
  }

  /// Registers all global variables with the interpreter.
  ///
  /// [importPath] is the package import path for library-scoped registration.
  /// Collects all registration errors and throws a single exception
  /// with all error details if any registrations fail.
  static void registerGlobalVariables(D4rt interpreter, String importPath) {
    final errors = <String>[];

    try {
      interpreter.registerGlobalVariable('tomAppId', tomAppId, importPath, sourceUri: 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\configuration\base_server_configuration.dart');
    } catch (e) {
      errors.add('Failed to register variable "tomAppId": $e');
    }
    try {
      interpreter.registerGlobalVariable('tomService', tomService, importPath, sourceUri: 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\endpoints\endpoint_annotation.dart');
    } catch (e) {
      errors.add('Failed to register variable "tomService": $e');
    }
    try {
      interpreter.registerGlobalVariable('tomLog', tomLog, importPath, sourceUri: 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_basics-1.0.0\lib\src\logging\logging.dart');
    } catch (e) {
      errors.add('Failed to register variable "tomLog": $e');
    }
    try {
      interpreter.registerGlobalVariable('platformWeb', platformWeb, importPath, sourceUri: 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_basics-1.0.0\lib\src\runtime\platform_environment_runtime.dart');
    } catch (e) {
      errors.add('Failed to register variable "platformWeb": $e');
    }
    try {
      interpreter.registerGlobalVariable('platformMacos', platformMacos, importPath, sourceUri: 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_basics-1.0.0\lib\src\runtime\platform_environment_runtime.dart');
    } catch (e) {
      errors.add('Failed to register variable "platformMacos": $e');
    }
    try {
      interpreter.registerGlobalVariable('platformWindows', platformWindows, importPath, sourceUri: 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_basics-1.0.0\lib\src\runtime\platform_environment_runtime.dart');
    } catch (e) {
      errors.add('Failed to register variable "platformWindows": $e');
    }
    try {
      interpreter.registerGlobalVariable('platformAndroid', platformAndroid, importPath, sourceUri: 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_basics-1.0.0\lib\src\runtime\platform_environment_runtime.dart');
    } catch (e) {
      errors.add('Failed to register variable "platformAndroid": $e');
    }
    try {
      interpreter.registerGlobalVariable('platformIos', platformIos, importPath, sourceUri: 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_basics-1.0.0\lib\src\runtime\platform_environment_runtime.dart');
    } catch (e) {
      errors.add('Failed to register variable "platformIos": $e');
    }
    try {
      interpreter.registerGlobalVariable('platformLinux', platformLinux, importPath, sourceUri: 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_basics-1.0.0\lib\src\runtime\platform_environment_runtime.dart');
    } catch (e) {
      errors.add('Failed to register variable "platformLinux": $e');
    }
    try {
      interpreter.registerGlobalVariable('platformFuchsia', platformFuchsia, importPath, sourceUri: 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_basics-1.0.0\lib\src\runtime\platform_environment_runtime.dart');
    } catch (e) {
      errors.add('Failed to register variable "platformFuchsia": $e');
    }
    try {
      interpreter.registerGlobalVariable('defaultTomEnvironment', defaultTomEnvironment, importPath, sourceUri: 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_basics-1.0.0\lib\src\runtime\platform_environment_runtime.dart');
    } catch (e) {
      errors.add('Failed to register variable "defaultTomEnvironment": $e');
    }
    try {
      interpreter.registerGlobalVariable('noTomEnvironment', noTomEnvironment, importPath, sourceUri: 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_basics-1.0.0\lib\src\runtime\platform_environment_runtime.dart');
    } catch (e) {
      errors.add('Failed to register variable "noTomEnvironment": $e');
    }
    try {
      interpreter.registerGlobalVariable('noTomPlatform', noTomPlatform, importPath, sourceUri: 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_basics-1.0.0\lib\src\runtime\platform_environment_runtime.dart');
    } catch (e) {
      errors.add('Failed to register variable "noTomPlatform": $e');
    }
    interpreter.registerGlobalGetter('standalonePlatformUtils', () => standalonePlatformUtils, importPath, sourceUri: 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_basics_console-1.0.0\lib\src\runtime\platform_detection_standalone.dart');

    if (errors.isNotEmpty) {
      throw StateError('Bridge registration errors (tom_core_server):\n${errors.join("\n")}');
    }
  }

  /// Returns a map of global function names to their native implementations.
  static Map<String, NativeFunctionImpl> globalFunctions() {
    return {
      'main': (visitor, positional, named, typeArgs) {
        return main();
      },
      'contextSetupMiddleware': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'contextSetupMiddleware');
        final id = D4.getRequiredArg<String>(positional, 0, 'id', 'contextSetupMiddleware');
        final context = positional.length > 1 ? positional[1] as Map<String, Object>? : null;
        return contextSetupMiddleware(id, context);
      },
      'extractAuthentication': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'extractAuthentication');
        final req = D4.getRequiredArg<$shelf_3.Request>(positional, 0, 'req', 'extractAuthentication');
        final $result = extractAuthentication(req);
        return InterpretedRecord([$result.$1, $result.$2], {});
      },
      'tomDefaultAuthenticationMiddleware': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'tomDefaultAuthenticationMiddleware');
        final id = D4.getRequiredArg<String>(positional, 0, 'id', 'tomDefaultAuthenticationMiddleware');
        final context = positional.length > 1 ? positional[1] as Map<String, Object>? : null;
        return tomDefaultAuthenticationMiddleware(id, context);
      },
      'tomLoggingMiddleware': (visitor, positional, named, typeArgs) {
        return tomLoggingMiddleware();
      },
      'noopHandler': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'noopHandler');
        final id = D4.getRequiredArg<String>(positional, 0, 'id', 'noopHandler');
        final statusCode = D4.getRequiredArg<int>(positional, 1, 'statusCode', 'noopHandler');
        return noopHandler(id, statusCode);
      },
      'limited': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'limited');
        final o = D4.getRequiredArg<Object?>(positional, 0, 'o', 'limited');
        final maxLength = D4.getRequiredArg<dynamic>(positional, 1, 'maxLength', 'limited');
        return limited(o, maxLength);
      },
    };
  }

  /// Returns a map of global function names to their canonical source URIs.
  ///
  /// Used for deduplication when the same function is exported through
  /// multiple barrels (e.g., tom_core_kernel and tom_core_server).
  static Map<String, String> globalFunctionSourceUris() {
    return {
      'main': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\cache\server_cache.dart',
      'contextSetupMiddleware': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\server\server.dart',
      'extractAuthentication': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\server\server.dart',
      'tomDefaultAuthenticationMiddleware': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\server\server.dart',
      'tomLoggingMiddleware': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\server\server.dart',
      'noopHandler': 'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\server\server.dart',
      'limited': 'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_basics-1.0.0\lib\src\logging\logging.dart',
    };
  }

  /// Returns a map of global function names to their display signatures.
  static Map<String, String> globalFunctionSignatures() {
    return {
      'main': 'void main()',
      'contextSetupMiddleware': 'Middleware contextSetupMiddleware(String id, [Map<String, Object>? context])',
      'extractAuthentication': '(TomPrincipal?, TomClientJwtToken?) extractAuthentication(Request req)',
      'tomDefaultAuthenticationMiddleware': 'Middleware tomDefaultAuthenticationMiddleware(String id, [Map<String, Object>? context])',
      'tomLoggingMiddleware': 'Middleware tomLoggingMiddleware()',
      'noopHandler': 'Handler noopHandler(String id, int statusCode)',
      'limited': 'String limited(Object? o, dynamic maxLength)',
    };
  }

  /// Returns the list of canonical source library URIs.
  ///
  /// These are the actual source locations of all elements in this bridge,
  /// used for deduplication when the same libraries are exported through
  /// multiple barrels.
  static List<String> sourceLibraries() {
    return [
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\authentication\authentication_server.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\authorization\authorization_cache.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\cache\server_cache.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\cmdline\args.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\cmdline\env_file.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\configuration\base_server_configuration.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\configuration\tom_config.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\configuration\yaml_resources.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\datasource_initialization.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\mariadb_datasource.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\mariadb_sql_dialect.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\queries.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\sql_dialects.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\datasources\types_operator.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\db_migration\db_migration.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\db_migration\mariadb_migration_adapter.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\endpoints\endpoint_annotation.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\endpoints\endpoint_pipeline.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\healthcheck\health_check.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\little_things\server_exception.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\annotation_analyzer.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\crud_repository.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\mariadb_repository.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\operators_expressions.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\persistence_annotations.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\query_builder.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\object_persistence\query_sentence_compiler.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\server\server.dart',
      'C:\Code\al_the_bear\inhouse\second_wind\enterprise_flutter\tom_agent_container\tom_ai\core\tom_core_server\lib\src\tomserver\transactions\transaction_manager.dart',
      'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\mysql_client-0.0.27\lib\src\mysql_client\connection.dart',
      'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\mysql_client-0.0.27\lib\src\mysql_client\pool.dart',
      'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\shelf-1.4.2\lib\src\request.dart',
      'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_basics-1.0.0\lib\src\exception_base.dart',
      'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_basics-1.0.0\lib\src\logging\logging.dart',
      'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_basics-1.0.0\lib\src\runtime\platform_environment_runtime.dart',
      'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_basics-1.0.0\lib\src\runtime\platform_neutral.dart',
      'C:\Users\alexi\AppData\Local\Pub\Cache\hosted\pub.dev\tom_basics_console-1.0.0\lib\src\runtime\platform_detection_standalone.dart',
    ];
  }

  /// Returns the import statement needed for D4rt scripts.
  ///
  /// Use this in your D4rt initialization script to make all
  /// bridged classes available to scripts.
  static String getImportBlock() {
    final imports = StringBuffer();
    imports.writeln("import 'package:tom_core_server/tom_core_server.dart';");
    imports.writeln("import 'package:console_markdown/console_markdown.dart';");
    return imports.toString();
  }

  /// Returns barrel import URIs for sub-packages discovered through re-exports.
  ///
  /// When a module follows re-exports into sub-packages (e.g., dcli re-exports
  /// dcli_core), D4rt scripts may import those sub-packages directly.
  /// These barrels need to be registered with the interpreter separately
  /// so that module resolution finds content for those URIs.
  static List<String> subPackageBarrels() {
    return [
      'package:console_markdown/console_markdown.dart',
    ];
  }

}

// =============================================================================
// TomAuthenticationAdaptor Bridge
// =============================================================================

BridgedClass _createTomAuthenticationAdaptorBridge() {
  return BridgedClass(
    nativeType: TomAuthenticationAdaptor,
    name: 'TomAuthenticationAdaptor',
    isAssignable: (v) => v is TomAuthenticationAdaptor,
    constructors: {
      '': (visitor, positional, named) {
        final guestOnly = D4.getNamedArgWithDefault<bool>(named, 'guestOnly', false);
        final userOnly = D4.getNamedArgWithDefault<bool>(named, 'userOnly', false);
        return TomAuthenticationAdaptor(guestOnly: guestOnly, userOnly: userOnly);
      },
    },
    getters: {
      'guestOnly': (visitor, target) => D4.validateTarget<TomAuthenticationAdaptor>(target, 'TomAuthenticationAdaptor').guestOnly,
      'userOnly': (visitor, target) => D4.validateTarget<TomAuthenticationAdaptor>(target, 'TomAuthenticationAdaptor').userOnly,
    },
    constructorSignatures: {
      '': 'TomAuthenticationAdaptor({bool guestOnly = false, bool userOnly = false})',
    },
    getterSignatures: {
      'guestOnly': 'bool get guestOnly',
      'userOnly': 'bool get userOnly',
    },
  );
}

// =============================================================================
// Tom2FAAdaptor Bridge
// =============================================================================

BridgedClass _createTom2FAAdaptorBridge() {
  return BridgedClass(
    nativeType: Tom2FAAdaptor,
    name: 'Tom2FAAdaptor',
    isAssignable: (v) => v is Tom2FAAdaptor,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'Tom2FAAdaptor');
        final type = D4.getRequiredArg<String>(positional, 0, 'type', 'Tom2FAAdaptor');
        return Tom2FAAdaptor(type);
      },
    },
    getters: {
      'type': (visitor, target) => D4.validateTarget<Tom2FAAdaptor>(target, 'Tom2FAAdaptor').type,
    },
    constructorSignatures: {
      '': 'const Tom2FAAdaptor(String type)',
    },
    getterSignatures: {
      'type': 'String get type',
    },
  );
}

// =============================================================================
// LoginException Bridge
// =============================================================================

BridgedClass _createLoginExceptionBridge() {
  return BridgedClass(
    nativeType: LoginException,
    name: 'LoginException',
    isAssignable: (v) => v is LoginException,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'LoginException');
        final key = D4.getRequiredArg<String>(positional, 0, 'key', 'LoginException');
        final userMessage = D4.getRequiredArg<String>(positional, 1, 'userMessage', 'LoginException');
        final parameters = D4.coerceMapOrNull<String, Object?>(named['parameters'], 'parameters');
        final stack = D4.getOptionalNamedArg<Object?>(named, 'stack');
        final rootException = D4.getOptionalNamedArg<Object?>(named, 'rootException');
        final autoLog = D4.getNamedArgWithDefault<bool>(named, 'autoLog', false);
        return LoginException(key, userMessage, parameters: parameters, stack: stack, rootException: rootException, autoLog: autoLog);
      },
    },
    getters: {
      'isolateName': (visitor, target) => D4.validateTarget<LoginException>(target, 'LoginException').isolateName,
      'clientThrow': (visitor, target) => D4.validateTarget<LoginException>(target, 'LoginException').clientThrow,
      'autoLog': (visitor, target) => D4.validateTarget<LoginException>(target, 'LoginException').autoLog,
      'serverCallError': (visitor, target) => D4.validateTarget<LoginException>(target, 'LoginException').serverCallError,
      'newField': (visitor, target) => D4.validateTarget<LoginException>(target, 'LoginException').newField,
      'logRepresentation': (visitor, target) => D4.validateTarget<LoginException>(target, 'LoginException').logRepresentation,
      'uuid': (visitor, target) => D4.validateTarget<LoginException>(target, 'LoginException').uuid,
      'requestUuid': (visitor, target) => D4.validateTarget<LoginException>(target, 'LoginException').requestUuid,
      'timeStamp': (visitor, target) => D4.validateTarget<LoginException>(target, 'LoginException').timeStamp,
      'key': (visitor, target) => D4.validateTarget<LoginException>(target, 'LoginException').key,
      'defaultUserMessage': (visitor, target) => D4.validateTarget<LoginException>(target, 'LoginException').defaultUserMessage,
      'parameters': (visitor, target) => D4.validateTarget<LoginException>(target, 'LoginException').parameters,
      'stack': (visitor, target) => D4.validateTarget<LoginException>(target, 'LoginException').stack,
      'rootException': (visitor, target) => D4.validateTarget<LoginException>(target, 'LoginException').rootException,
      'stackTrace': (visitor, target) => D4.validateTarget<LoginException>(target, 'LoginException').stackTrace,
    },
    setters: {
      'isolateName': (visitor, target, value) => 
        D4.validateTarget<LoginException>(target, 'LoginException').isolateName = D4.extractBridgedArg<String>(value, 'isolateName'),
      'clientThrow': (visitor, target, value) => 
        D4.validateTarget<LoginException>(target, 'LoginException').clientThrow = D4.extractBridgedArg<bool>(value, 'clientThrow'),
      'autoLog': (visitor, target, value) => 
        D4.validateTarget<LoginException>(target, 'LoginException').autoLog = D4.extractBridgedArg<bool>(value, 'autoLog'),
      'serverCallError': (visitor, target, value) => 
        D4.validateTarget<LoginException>(target, 'LoginException').serverCallError = D4.extractBridgedArgOrNull<$tom_core_kernel_4.TomServerCallError>(value, 'serverCallError'),
      'newField': (visitor, target, value) => 
        D4.validateTarget<LoginException>(target, 'LoginException').newField = D4.extractBridgedArgOrNull<String>(value, 'newField'),
      'uuid': (visitor, target, value) => 
        D4.validateTarget<LoginException>(target, 'LoginException').uuid = D4.extractBridgedArg<String>(value, 'uuid'),
      'requestUuid': (visitor, target, value) => 
        D4.validateTarget<LoginException>(target, 'LoginException').requestUuid = D4.extractBridgedArgOrNull<String>(value, 'requestUuid'),
      'timeStamp': (visitor, target, value) => 
        D4.validateTarget<LoginException>(target, 'LoginException').timeStamp = D4.extractBridgedArg<DateTime>(value, 'timeStamp'),
      'key': (visitor, target, value) => 
        D4.validateTarget<LoginException>(target, 'LoginException').key = D4.extractBridgedArg<String>(value, 'key'),
      'defaultUserMessage': (visitor, target, value) => 
        D4.validateTarget<LoginException>(target, 'LoginException').defaultUserMessage = D4.extractBridgedArg<String>(value, 'defaultUserMessage'),
      'stack': (visitor, target, value) => 
        D4.validateTarget<LoginException>(target, 'LoginException').stack = D4.extractBridgedArgOrNull<Object>(value, 'stack'),
      'rootException': (visitor, target, value) => 
        D4.validateTarget<LoginException>(target, 'LoginException').rootException = D4.extractBridgedArgOrNull<Object>(value, 'rootException'),
      'stackTrace': (visitor, target, value) => 
        D4.validateTarget<LoginException>(target, 'LoginException').stackTrace = D4.extractBridgedArg<String>(value, 'stackTrace'),
    },
    methods: {
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<LoginException>(target, 'LoginException');
        return t.toString();
      },
      'printStackTrace': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<LoginException>(target, 'LoginException');
        final depth = D4.getOptionalArgWithDefault<int>(positional, 0, 'depth', -1);
        t.printStackTrace(depth);
        return null;
      },
    },
    constructorSignatures: {
      '': 'LoginException(String key, String userMessage, {Map<String, Object?>? parameters, Object? stack, Object? rootException, bool autoLog = false})',
    },
    methodSignatures: {
      'toString': 'String toString()',
      'printStackTrace': 'void printStackTrace([int depth = -1])',
    },
    getterSignatures: {
      'isolateName': 'String get isolateName',
      'clientThrow': 'bool get clientThrow',
      'autoLog': 'bool get autoLog',
      'serverCallError': 'TomServerCallError? get serverCallError',
      'newField': 'String? get newField',
      'logRepresentation': 'String get logRepresentation',
      'uuid': 'String get uuid',
      'requestUuid': 'String? get requestUuid',
      'timeStamp': 'DateTime get timeStamp',
      'key': 'String get key',
      'defaultUserMessage': 'String get defaultUserMessage',
      'parameters': 'Map<String, Object?>? get parameters',
      'stack': 'Object? get stack',
      'rootException': 'Object? get rootException',
      'stackTrace': 'String get stackTrace',
    },
    setterSignatures: {
      'isolateName': 'set isolateName(String value)',
      'clientThrow': 'set clientThrow(bool value)',
      'autoLog': 'set autoLog(bool value)',
      'serverCallError': 'set serverCallError(TomServerCallError? value)',
      'newField': 'set newField(String? value)',
      'uuid': 'set uuid(String value)',
      'requestUuid': 'set requestUuid(String? value)',
      'timeStamp': 'set timeStamp(DateTime value)',
      'key': 'set key(String value)',
      'defaultUserMessage': 'set defaultUserMessage(String value)',
      'parameters': 'set parameters(Map<String, Object?>? value)',
      'stack': 'set stack(Object? value)',
      'rootException': 'set rootException(Object? value)',
      'stackTrace': 'set stackTrace(String value)',
    },
  );
}

// =============================================================================
// TomAuthenticationData Bridge
// =============================================================================

BridgedClass _createTomAuthenticationDataBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_1.TomAuthenticationData,
    name: 'TomAuthenticationData',
    isAssignable: (v) => v is $tom_core_server_1.TomAuthenticationData,
    constructors: {
      '': (visitor, positional, named) {
        final username = D4.getRequiredNamedArg<String>(named, 'username', 'TomAuthenticationData');
        final key = D4.getOptionalNamedArg<Object?>(named, 'key');
        final organization = D4.getRequiredNamedArg<String>(named, 'organization', 'TomAuthenticationData');
        final application = D4.getRequiredNamedArg<String>(named, 'application', 'TomAuthenticationData');
        final process = D4.getRequiredNamedArg<String>(named, 'process', 'TomAuthenticationData');
        final language = D4.getRequiredNamedArg<String>(named, 'language', 'TomAuthenticationData');
        final country = D4.getRequiredNamedArg<String>(named, 'country', 'TomAuthenticationData');
        final timezone = D4.getRequiredNamedArg<String>(named, 'timezone', 'TomAuthenticationData');
        final client = D4.getRequiredNamedArg<String>(named, 'client', 'TomAuthenticationData');
        return $tom_core_server_1.TomAuthenticationData(username: username, key: key, organization: organization, application: application, process: process, language: language, country: country, timezone: timezone, client: client);
      },
    },
    getters: {
      'organization': (visitor, target) => D4.validateTarget<$tom_core_server_1.TomAuthenticationData>(target, 'TomAuthenticationData').organization,
      'application': (visitor, target) => D4.validateTarget<$tom_core_server_1.TomAuthenticationData>(target, 'TomAuthenticationData').application,
      'process': (visitor, target) => D4.validateTarget<$tom_core_server_1.TomAuthenticationData>(target, 'TomAuthenticationData').process,
      'language': (visitor, target) => D4.validateTarget<$tom_core_server_1.TomAuthenticationData>(target, 'TomAuthenticationData').language,
      'country': (visitor, target) => D4.validateTarget<$tom_core_server_1.TomAuthenticationData>(target, 'TomAuthenticationData').country,
      'timezone': (visitor, target) => D4.validateTarget<$tom_core_server_1.TomAuthenticationData>(target, 'TomAuthenticationData').timezone,
      'client': (visitor, target) => D4.validateTarget<$tom_core_server_1.TomAuthenticationData>(target, 'TomAuthenticationData').client,
      'username': (visitor, target) => D4.validateTarget<$tom_core_server_1.TomAuthenticationData>(target, 'TomAuthenticationData').username,
      'key': (visitor, target) => D4.validateTarget<$tom_core_server_1.TomAuthenticationData>(target, 'TomAuthenticationData').key,
    },
    setters: {
      'organization': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_1.TomAuthenticationData>(target, 'TomAuthenticationData').organization = D4.extractBridgedArg<String>(value, 'organization'),
      'application': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_1.TomAuthenticationData>(target, 'TomAuthenticationData').application = D4.extractBridgedArg<String>(value, 'application'),
      'process': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_1.TomAuthenticationData>(target, 'TomAuthenticationData').process = D4.extractBridgedArg<String>(value, 'process'),
      'language': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_1.TomAuthenticationData>(target, 'TomAuthenticationData').language = D4.extractBridgedArg<String>(value, 'language'),
      'country': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_1.TomAuthenticationData>(target, 'TomAuthenticationData').country = D4.extractBridgedArg<String>(value, 'country'),
      'timezone': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_1.TomAuthenticationData>(target, 'TomAuthenticationData').timezone = D4.extractBridgedArg<String>(value, 'timezone'),
      'client': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_1.TomAuthenticationData>(target, 'TomAuthenticationData').client = D4.extractBridgedArg<String>(value, 'client'),
      'username': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_1.TomAuthenticationData>(target, 'TomAuthenticationData').username = D4.extractBridgedArg<String>(value, 'username'),
      'key': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_1.TomAuthenticationData>(target, 'TomAuthenticationData').key = D4.extractBridgedArgOrNull<Object>(value, 'key'),
    },
    constructorSignatures: {
      '': 'TomAuthenticationData({required String username, Object? key, required String organization, required String application, required String process, required String language, required String country, required String timezone, required String client})',
    },
    getterSignatures: {
      'organization': 'String get organization',
      'application': 'String get application',
      'process': 'String get process',
      'language': 'String get language',
      'country': 'String get country',
      'timezone': 'String get timezone',
      'client': 'String get client',
      'username': 'String get username',
      'key': 'Object? get key',
    },
    setterSignatures: {
      'organization': 'set organization(dynamic value)',
      'application': 'set application(dynamic value)',
      'process': 'set process(dynamic value)',
      'language': 'set language(dynamic value)',
      'country': 'set country(dynamic value)',
      'timezone': 'set timezone(dynamic value)',
      'client': 'set client(dynamic value)',
      'username': 'set username(dynamic value)',
      'key': 'set key(dynamic value)',
    },
  );
}

// =============================================================================
// TomAuthenticationService Bridge
// =============================================================================

BridgedClass _createTomAuthenticationServiceBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_1.TomAuthenticationService,
    name: 'TomAuthenticationService',
    isAssignable: (v) => v is $tom_core_server_1.TomAuthenticationService,
    constructors: {
    },
    methods: {
      'authenticateUser': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_1.TomAuthenticationService>(target, 'TomAuthenticationService');
        D4.requireMinArgs(positional, 1, 'authenticateUser');
        final authData = D4.getRequiredArg<$tom_core_server_1.TomAuthenticationData>(positional, 0, 'authData', 'authenticateUser');
        return t.authenticateUser(authData);
      },
    },
    methodSignatures: {
      'authenticateUser': 'Future<TomAuthenticationInfo> authenticateUser(TomAuthenticationData authData)',
    },
  );
}

// =============================================================================
// Tom2FAService Bridge
// =============================================================================

BridgedClass _createTom2FAServiceBridge() {
  return BridgedClass(
    nativeType: Tom2FAService,
    name: 'Tom2FAService',
    isAssignable: (v) => v is Tom2FAService,
    constructors: {
    },
  );
}

// =============================================================================
// TomAuthenticationInfo Bridge
// =============================================================================

BridgedClass _createTomAuthenticationInfoBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_1.TomAuthenticationInfo,
    name: 'TomAuthenticationInfo',
    isAssignable: (v) => v is $tom_core_server_1.TomAuthenticationInfo,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'TomAuthenticationInfo');
        final principal = D4.getRequiredArg<$tom_core_kernel_9.TomPrincipal>(positional, 0, 'principal', 'TomAuthenticationInfo');
        final acd = D4.getRequiredArg<$tom_core_kernel_9.TomAccessControlDefinition>(positional, 1, 'acd', 'TomAuthenticationInfo');
        return $tom_core_server_1.TomAuthenticationInfo(principal, acd);
      },
    },
    getters: {
      'principal': (visitor, target) => D4.validateTarget<$tom_core_server_1.TomAuthenticationInfo>(target, 'TomAuthenticationInfo').principal,
      'acd': (visitor, target) => D4.validateTarget<$tom_core_server_1.TomAuthenticationInfo>(target, 'TomAuthenticationInfo').acd,
    },
    setters: {
      'principal': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_1.TomAuthenticationInfo>(target, 'TomAuthenticationInfo').principal = D4.extractBridgedArg<$tom_core_kernel_9.TomPrincipal>(value, 'principal'),
      'acd': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_1.TomAuthenticationInfo>(target, 'TomAuthenticationInfo').acd = D4.extractBridgedArg<$tom_core_kernel_9.TomAccessControlDefinition>(value, 'acd'),
    },
    constructorSignatures: {
      '': 'TomAuthenticationInfo(TomPrincipal principal, TomAccessControlDefinition acd)',
    },
    getterSignatures: {
      'principal': 'TomPrincipal get principal',
      'acd': 'TomAccessControlDefinition get acd',
    },
    setterSignatures: {
      'principal': 'set principal(dynamic value)',
      'acd': 'set acd(dynamic value)',
    },
  );
}

// =============================================================================
// TomDummyAuthenticationService Bridge
// =============================================================================

BridgedClass _createTomDummyAuthenticationServiceBridge() {
  return BridgedClass(
    nativeType: TomDummyAuthenticationService,
    name: 'TomDummyAuthenticationService',
    isAssignable: (v) => v is TomDummyAuthenticationService,
    constructors: {
      '': (visitor, positional, named) {
        return TomDummyAuthenticationService();
      },
    },
    getters: {
      'showErrorMessage': (visitor, target) => D4.validateTarget<TomDummyAuthenticationService>(target, 'TomDummyAuthenticationService').showErrorMessage,
    },
    setters: {
      'showErrorMessage': (visitor, target, value) => 
        D4.validateTarget<TomDummyAuthenticationService>(target, 'TomDummyAuthenticationService').showErrorMessage = D4.extractBridgedArg<bool>(value, 'showErrorMessage'),
    },
    methods: {
      'authenticateUser': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomDummyAuthenticationService>(target, 'TomDummyAuthenticationService');
        D4.requireMinArgs(positional, 1, 'authenticateUser');
        final authData = D4.getRequiredArg<$tom_core_server_1.TomAuthenticationData>(positional, 0, 'authData', 'authenticateUser');
        return t.authenticateUser(authData);
      },
    },
    constructorSignatures: {
      '': 'TomDummyAuthenticationService()',
    },
    methodSignatures: {
      'authenticateUser': 'Future<TomAuthenticationInfo> authenticateUser(TomAuthenticationData authData)',
    },
    getterSignatures: {
      'showErrorMessage': 'bool get showErrorMessage',
    },
    setterSignatures: {
      'showErrorMessage': 'set showErrorMessage(dynamic value)',
    },
  );
}

// =============================================================================
// TomAuthenticationServer Bridge
// =============================================================================

BridgedClass _createTomAuthenticationServerBridge() {
  return BridgedClass(
    nativeType: TomAuthenticationServer,
    name: 'TomAuthenticationServer',
    isAssignable: (v) => v is TomAuthenticationServer,
    constructors: {
      '': (visitor, positional, named) {
        return TomAuthenticationServer();
      },
    },
    methods: {
      'authenticateGuest': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomAuthenticationServer>(target, 'TomAuthenticationServer');
        D4.requireMinArgs(positional, 1, 'authenticateGuest');
        final m = D4.getRequiredArg<$tom_core_kernel_8.TomAuthenticationMessage>(positional, 0, 'm', 'authenticateGuest');
        return t.authenticateGuest(m);
      },
      'authenticatePass1': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomAuthenticationServer>(target, 'TomAuthenticationServer');
        D4.requireMinArgs(positional, 1, 'authenticatePass1');
        final m = D4.getRequiredArg<$tom_core_kernel_8.TomAuthenticationMessage>(positional, 0, 'm', 'authenticatePass1');
        return t.authenticatePass1(m);
      },
      'authenticatePass2': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomAuthenticationServer>(target, 'TomAuthenticationServer');
        D4.requireMinArgs(positional, 1, 'authenticatePass2');
        final m = D4.getRequiredArg<$tom_core_kernel_8.TomAuthenticationMessage>(positional, 0, 'm', 'authenticatePass2');
        return t.authenticatePass2(m);
      },
      'authenticateUser': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomAuthenticationServer>(target, 'TomAuthenticationServer');
        D4.requireMinArgs(positional, 2, 'authenticateUser');
        final m = D4.getRequiredArg<$tom_core_kernel_8.TomAuthenticationMessage>(positional, 0, 'm', 'authenticateUser');
        final guestLogin = D4.getRequiredArg<bool>(positional, 1, 'guestLogin', 'authenticateUser');
        return t.authenticateUser(m, guestLogin);
      },
    },
    staticGetters: {
      'globalSettingUserAuthenticationService': (visitor) => TomAuthenticationServer.globalSettingUserAuthenticationService,
      'globalSettingGuestAuthenticationService': (visitor) => TomAuthenticationServer.globalSettingGuestAuthenticationService,
      'globalSettingJwtOrganization': (visitor) => TomAuthenticationServer.globalSettingJwtOrganization,
    },
    staticSetters: {
      'globalSettingUserAuthenticationService': (visitor, value) => 
        TomAuthenticationServer.globalSettingUserAuthenticationService = D4.extractBridgedArg<$tom_core_server_1.TomAuthenticationService>(value, 'globalSettingUserAuthenticationService'),
      'globalSettingGuestAuthenticationService': (visitor, value) => 
        TomAuthenticationServer.globalSettingGuestAuthenticationService = D4.extractBridgedArg<$tom_core_server_1.TomAuthenticationService>(value, 'globalSettingGuestAuthenticationService'),
      'globalSettingJwtOrganization': (visitor, value) => 
        TomAuthenticationServer.globalSettingJwtOrganization = D4.extractBridgedArg<String>(value, 'globalSettingJwtOrganization'),
    },
    constructorSignatures: {
      '': 'TomAuthenticationServer()',
    },
    methodSignatures: {
      'authenticateGuest': 'Future<TomAuthenticationResult> authenticateGuest(TomAuthenticationMessage m)',
      'authenticatePass1': 'Future<TomAuthenticationResult> authenticatePass1(TomAuthenticationMessage m)',
      'authenticatePass2': 'Future<TomAuthenticationResult> authenticatePass2(TomAuthenticationMessage m)',
      'authenticateUser': 'Future<TomAuthenticationResult> authenticateUser(TomAuthenticationMessage m, bool guestLogin)',
    },
    staticGetterSignatures: {
      'globalSettingUserAuthenticationService': 'TomAuthenticationService get globalSettingUserAuthenticationService',
      'globalSettingGuestAuthenticationService': 'TomAuthenticationService get globalSettingGuestAuthenticationService',
      'globalSettingJwtOrganization': 'String get globalSettingJwtOrganization',
    },
    staticSetterSignatures: {
      'globalSettingUserAuthenticationService': 'set globalSettingUserAuthenticationService(dynamic value)',
      'globalSettingGuestAuthenticationService': 'set globalSettingGuestAuthenticationService(dynamic value)',
      'globalSettingJwtOrganization': 'set globalSettingJwtOrganization(dynamic value)',
    },
  );
}

// =============================================================================
// TomAuthorizationCacheException Bridge
// =============================================================================

BridgedClass _createTomAuthorizationCacheExceptionBridge() {
  return BridgedClass(
    nativeType: TomAuthorizationCacheException,
    name: 'TomAuthorizationCacheException',
    isAssignable: (v) => v is TomAuthorizationCacheException,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'TomAuthorizationCacheException');
        final key = D4.getRequiredArg<String>(positional, 0, 'key', 'TomAuthorizationCacheException');
        final defaultUserMessage = D4.getRequiredArg<String>(positional, 1, 'defaultUserMessage', 'TomAuthorizationCacheException');
        final parameters = D4.coerceMapOrNull<String, Object?>(named['parameters'], 'parameters');
        final stack = D4.getOptionalNamedArg<Object?>(named, 'stack');
        final rootException = D4.getOptionalNamedArg<Object?>(named, 'rootException');
        final autoLog = D4.getNamedArgWithDefault<bool>(named, 'autoLog', false);
        final uuid = D4.getOptionalNamedArg<String?>(named, 'uuid');
        final serverCallError = D4.getOptionalNamedArg<$tom_core_kernel_4.TomServerCallError?>(named, 'serverCallError');
        return TomAuthorizationCacheException(key, defaultUserMessage, parameters: parameters, stack: stack, rootException: rootException, autoLog: autoLog, uuid: uuid, serverCallError: serverCallError);
      },
    },
    getters: {
      'autoLog': (visitor, target) => D4.validateTarget<TomAuthorizationCacheException>(target, 'TomAuthorizationCacheException').autoLog,
      'serverCallError': (visitor, target) => D4.validateTarget<TomAuthorizationCacheException>(target, 'TomAuthorizationCacheException').serverCallError,
      'newField': (visitor, target) => D4.validateTarget<TomAuthorizationCacheException>(target, 'TomAuthorizationCacheException').newField,
      'logRepresentation': (visitor, target) => D4.validateTarget<TomAuthorizationCacheException>(target, 'TomAuthorizationCacheException').logRepresentation,
      'uuid': (visitor, target) => D4.validateTarget<TomAuthorizationCacheException>(target, 'TomAuthorizationCacheException').uuid,
      'requestUuid': (visitor, target) => D4.validateTarget<TomAuthorizationCacheException>(target, 'TomAuthorizationCacheException').requestUuid,
      'timeStamp': (visitor, target) => D4.validateTarget<TomAuthorizationCacheException>(target, 'TomAuthorizationCacheException').timeStamp,
      'key': (visitor, target) => D4.validateTarget<TomAuthorizationCacheException>(target, 'TomAuthorizationCacheException').key,
      'defaultUserMessage': (visitor, target) => D4.validateTarget<TomAuthorizationCacheException>(target, 'TomAuthorizationCacheException').defaultUserMessage,
      'parameters': (visitor, target) => D4.validateTarget<TomAuthorizationCacheException>(target, 'TomAuthorizationCacheException').parameters,
      'stack': (visitor, target) => D4.validateTarget<TomAuthorizationCacheException>(target, 'TomAuthorizationCacheException').stack,
      'rootException': (visitor, target) => D4.validateTarget<TomAuthorizationCacheException>(target, 'TomAuthorizationCacheException').rootException,
      'stackTrace': (visitor, target) => D4.validateTarget<TomAuthorizationCacheException>(target, 'TomAuthorizationCacheException').stackTrace,
    },
    setters: {
      'autoLog': (visitor, target, value) => 
        D4.validateTarget<TomAuthorizationCacheException>(target, 'TomAuthorizationCacheException').autoLog = D4.extractBridgedArg<bool>(value, 'autoLog'),
      'serverCallError': (visitor, target, value) => 
        D4.validateTarget<TomAuthorizationCacheException>(target, 'TomAuthorizationCacheException').serverCallError = D4.extractBridgedArgOrNull<$tom_core_kernel_4.TomServerCallError>(value, 'serverCallError'),
      'newField': (visitor, target, value) => 
        D4.validateTarget<TomAuthorizationCacheException>(target, 'TomAuthorizationCacheException').newField = D4.extractBridgedArgOrNull<String>(value, 'newField'),
      'uuid': (visitor, target, value) => 
        D4.validateTarget<TomAuthorizationCacheException>(target, 'TomAuthorizationCacheException').uuid = D4.extractBridgedArg<String>(value, 'uuid'),
      'requestUuid': (visitor, target, value) => 
        D4.validateTarget<TomAuthorizationCacheException>(target, 'TomAuthorizationCacheException').requestUuid = D4.extractBridgedArgOrNull<String>(value, 'requestUuid'),
      'timeStamp': (visitor, target, value) => 
        D4.validateTarget<TomAuthorizationCacheException>(target, 'TomAuthorizationCacheException').timeStamp = D4.extractBridgedArg<DateTime>(value, 'timeStamp'),
      'key': (visitor, target, value) => 
        D4.validateTarget<TomAuthorizationCacheException>(target, 'TomAuthorizationCacheException').key = D4.extractBridgedArg<String>(value, 'key'),
      'defaultUserMessage': (visitor, target, value) => 
        D4.validateTarget<TomAuthorizationCacheException>(target, 'TomAuthorizationCacheException').defaultUserMessage = D4.extractBridgedArg<String>(value, 'defaultUserMessage'),
      'stack': (visitor, target, value) => 
        D4.validateTarget<TomAuthorizationCacheException>(target, 'TomAuthorizationCacheException').stack = D4.extractBridgedArgOrNull<Object>(value, 'stack'),
      'rootException': (visitor, target, value) => 
        D4.validateTarget<TomAuthorizationCacheException>(target, 'TomAuthorizationCacheException').rootException = D4.extractBridgedArgOrNull<Object>(value, 'rootException'),
      'stackTrace': (visitor, target, value) => 
        D4.validateTarget<TomAuthorizationCacheException>(target, 'TomAuthorizationCacheException').stackTrace = D4.extractBridgedArg<String>(value, 'stackTrace'),
    },
    methods: {
      'printStackTrace': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomAuthorizationCacheException>(target, 'TomAuthorizationCacheException');
        final depth = D4.getOptionalArgWithDefault<int>(positional, 0, 'depth', -1);
        t.printStackTrace(depth);
        return null;
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomAuthorizationCacheException>(target, 'TomAuthorizationCacheException');
        return t.toString();
      },
    },
    constructorSignatures: {
      '': 'TomAuthorizationCacheException(String key, String defaultUserMessage, {Map<String, Object?>? parameters, Object? stack, Object? rootException, bool autoLog = false, String? uuid, TomServerCallError? serverCallError})',
    },
    methodSignatures: {
      'printStackTrace': 'void printStackTrace([int depth = -1])',
      'toString': 'String toString()',
    },
    getterSignatures: {
      'autoLog': 'bool get autoLog',
      'serverCallError': 'TomServerCallError? get serverCallError',
      'newField': 'String? get newField',
      'logRepresentation': 'String get logRepresentation',
      'uuid': 'String get uuid',
      'requestUuid': 'String? get requestUuid',
      'timeStamp': 'DateTime get timeStamp',
      'key': 'String get key',
      'defaultUserMessage': 'String get defaultUserMessage',
      'parameters': 'Map<String, Object?>? get parameters',
      'stack': 'Object? get stack',
      'rootException': 'Object? get rootException',
      'stackTrace': 'String get stackTrace',
    },
    setterSignatures: {
      'autoLog': 'set autoLog(bool value)',
      'serverCallError': 'set serverCallError(TomServerCallError? value)',
      'newField': 'set newField(String? value)',
      'uuid': 'set uuid(String value)',
      'requestUuid': 'set requestUuid(String? value)',
      'timeStamp': 'set timeStamp(DateTime value)',
      'key': 'set key(String value)',
      'defaultUserMessage': 'set defaultUserMessage(String value)',
      'parameters': 'set parameters(Map<String, Object?>? value)',
      'stack': 'set stack(Object? value)',
      'rootException': 'set rootException(Object? value)',
      'stackTrace': 'set stackTrace(String value)',
    },
  );
}

// =============================================================================
// TomAuthorizationCacheEntry Bridge
// =============================================================================

BridgedClass _createTomAuthorizationCacheEntryBridge() {
  return BridgedClass(
    nativeType: TomAuthorizationCacheEntry,
    name: 'TomAuthorizationCacheEntry',
    isAssignable: (v) => v is TomAuthorizationCacheEntry,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomAuthorizationCacheEntry');
        final authorizedPrincipal = D4.getRequiredArg<$tom_core_kernel_9.TomPrincipal>(positional, 0, 'authorizedPrincipal', 'TomAuthorizationCacheEntry');
        final deletionTime = D4.getOptionalArg<DateTime?>(positional, 1, 'deletionTime');
        return TomAuthorizationCacheEntry(authorizedPrincipal, deletionTime);
      },
    },
    getters: {
      'deletionTime': (visitor, target) => D4.validateTarget<TomAuthorizationCacheEntry>(target, 'TomAuthorizationCacheEntry').deletionTime,
      'authorizedPrincipal': (visitor, target) => D4.validateTarget<TomAuthorizationCacheEntry>(target, 'TomAuthorizationCacheEntry').authorizedPrincipal,
    },
    setters: {
      'deletionTime': (visitor, target, value) => 
        D4.validateTarget<TomAuthorizationCacheEntry>(target, 'TomAuthorizationCacheEntry').deletionTime = D4.extractBridgedArg<DateTime>(value, 'deletionTime'),
      'authorizedPrincipal': (visitor, target, value) => 
        D4.validateTarget<TomAuthorizationCacheEntry>(target, 'TomAuthorizationCacheEntry').authorizedPrincipal = D4.extractBridgedArg<$tom_core_kernel_9.TomPrincipal>(value, 'authorizedPrincipal'),
    },
    constructorSignatures: {
      '': 'TomAuthorizationCacheEntry(TomPrincipal authorizedPrincipal, [DateTime? deletionTime])',
    },
    getterSignatures: {
      'deletionTime': 'DateTime get deletionTime',
      'authorizedPrincipal': 'TomPrincipal get authorizedPrincipal',
    },
    setterSignatures: {
      'deletionTime': 'set deletionTime(dynamic value)',
      'authorizedPrincipal': 'set authorizedPrincipal(dynamic value)',
    },
  );
}

// =============================================================================
// TomAuthorizationCache Bridge
// =============================================================================

BridgedClass _createTomAuthorizationCacheBridge() {
  return BridgedClass(
    nativeType: TomAuthorizationCache,
    name: 'TomAuthorizationCache',
    isAssignable: (v) => v is TomAuthorizationCache,
    constructors: {
      '': (visitor, positional, named) {
        return TomAuthorizationCache();
      },
    },
    staticMethods: {
      'getPrincipal': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'getPrincipal');
        final authenticationToken = D4.getRequiredArg<$tom_crypto_1.TomClientJwtToken>(positional, 0, 'authenticationToken', 'getPrincipal');
        return TomAuthorizationCache.getPrincipal(authenticationToken);
      },
      'storePrincipal': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'storePrincipal');
        final authenticationToken = D4.getRequiredArg<$tom_crypto_1.TomClientJwtToken>(positional, 0, 'authenticationToken', 'storePrincipal');
        final authorizedPrincipal = D4.getRequiredArg<$tom_core_kernel_9.TomPrincipal>(positional, 1, 'authorizedPrincipal', 'storePrincipal');
        return TomAuthorizationCache.storePrincipal(authenticationToken, authorizedPrincipal);
      },
    },
    constructorSignatures: {
      '': 'TomAuthorizationCache()',
    },
    staticMethodSignatures: {
      'getPrincipal': 'Future<TomPrincipal?> getPrincipal(TomClientJwtToken authenticationToken)',
      'storePrincipal': 'Future<int> storePrincipal(TomClientJwtToken authenticationToken, TomPrincipal authorizedPrincipal)',
    },
  );
}

// =============================================================================
// TomAuthorizationCacheStoreMessage Bridge
// =============================================================================

BridgedClass _createTomAuthorizationCacheStoreMessageBridge() {
  return BridgedClass(
    nativeType: TomAuthorizationCacheStoreMessage,
    name: 'TomAuthorizationCacheStoreMessage',
    isAssignable: (v) => v is TomAuthorizationCacheStoreMessage,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'TomAuthorizationCacheStoreMessage');
        final authenticationToken = D4.getRequiredArg<$tom_crypto_1.TomClientJwtToken>(positional, 0, 'authenticationToken', 'TomAuthorizationCacheStoreMessage');
        final authorizedPrincipal = D4.getRequiredArg<$tom_core_kernel_9.TomPrincipal>(positional, 1, 'authorizedPrincipal', 'TomAuthorizationCacheStoreMessage');
        return TomAuthorizationCacheStoreMessage(authenticationToken, authorizedPrincipal);
      },
    },
    getters: {
      'authenticationToken': (visitor, target) => D4.validateTarget<TomAuthorizationCacheStoreMessage>(target, 'TomAuthorizationCacheStoreMessage').authenticationToken,
      'authorizedPrincipal': (visitor, target) => D4.validateTarget<TomAuthorizationCacheStoreMessage>(target, 'TomAuthorizationCacheStoreMessage').authorizedPrincipal,
    },
    setters: {
      'authenticationToken': (visitor, target, value) => 
        D4.validateTarget<TomAuthorizationCacheStoreMessage>(target, 'TomAuthorizationCacheStoreMessage').authenticationToken = D4.extractBridgedArg<$tom_crypto_1.TomClientJwtToken>(value, 'authenticationToken'),
      'authorizedPrincipal': (visitor, target, value) => 
        D4.validateTarget<TomAuthorizationCacheStoreMessage>(target, 'TomAuthorizationCacheStoreMessage').authorizedPrincipal = D4.extractBridgedArg<$tom_core_kernel_9.TomPrincipal>(value, 'authorizedPrincipal'),
    },
    constructorSignatures: {
      '': 'TomAuthorizationCacheStoreMessage(TomClientJwtToken authenticationToken, TomPrincipal authorizedPrincipal)',
    },
    getterSignatures: {
      'authenticationToken': 'TomClientJwtToken get authenticationToken',
      'authorizedPrincipal': 'TomPrincipal get authorizedPrincipal',
    },
    setterSignatures: {
      'authenticationToken': 'set authenticationToken(dynamic value)',
      'authorizedPrincipal': 'set authorizedPrincipal(dynamic value)',
    },
  );
}

// =============================================================================
// TomAuthorizationCacheRetrieveMessage Bridge
// =============================================================================

BridgedClass _createTomAuthorizationCacheRetrieveMessageBridge() {
  return BridgedClass(
    nativeType: TomAuthorizationCacheRetrieveMessage,
    name: 'TomAuthorizationCacheRetrieveMessage',
    isAssignable: (v) => v is TomAuthorizationCacheRetrieveMessage,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomAuthorizationCacheRetrieveMessage');
        final authenticationToken = D4.getRequiredArg<$tom_crypto_1.TomClientJwtToken>(positional, 0, 'authenticationToken', 'TomAuthorizationCacheRetrieveMessage');
        return TomAuthorizationCacheRetrieveMessage(authenticationToken);
      },
    },
    getters: {
      'authenticationToken': (visitor, target) => D4.validateTarget<TomAuthorizationCacheRetrieveMessage>(target, 'TomAuthorizationCacheRetrieveMessage').authenticationToken,
    },
    setters: {
      'authenticationToken': (visitor, target, value) => 
        D4.validateTarget<TomAuthorizationCacheRetrieveMessage>(target, 'TomAuthorizationCacheRetrieveMessage').authenticationToken = D4.extractBridgedArg<$tom_crypto_1.TomClientJwtToken>(value, 'authenticationToken'),
    },
    constructorSignatures: {
      '': 'TomAuthorizationCacheRetrieveMessage(TomClientJwtToken authenticationToken)',
    },
    getterSignatures: {
      'authenticationToken': 'TomClientJwtToken get authenticationToken',
    },
    setterSignatures: {
      'authenticationToken': 'set authenticationToken(dynamic value)',
    },
  );
}

// =============================================================================
// TomAuthorizationCacheExecutor Bridge
// =============================================================================

BridgedClass _createTomAuthorizationCacheExecutorBridge() {
  return BridgedClass(
    nativeType: TomAuthorizationCacheExecutor,
    name: 'TomAuthorizationCacheExecutor',
    isAssignable: (v) => v is TomAuthorizationCacheExecutor,
    constructors: {
      '': (visitor, positional, named) {
        return TomAuthorizationCacheExecutor();
      },
    },
    methods: {
      'execute': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomAuthorizationCacheExecutor>(target, 'TomAuthorizationCacheExecutor');
        D4.requireMinArgs(positional, 1, 'execute');
        final command = D4.getRequiredArg<Object>(positional, 0, 'command', 'execute');
        return t.execute(command);
      },
    },
    constructorSignatures: {
      '': 'TomAuthorizationCacheExecutor()',
    },
    methodSignatures: {
      'execute': 'Object execute(Object command)',
    },
  );
}

// =============================================================================
// TomArgs Bridge
// =============================================================================

BridgedClass _createTomArgsBridge() {
  return BridgedClass(
    nativeType: TomArgs,
    name: 'TomArgs',
    isAssignable: (v) => v is TomArgs,
    constructors: {
      '': (visitor, positional, named) {
        return TomArgs();
      },
    },
    staticGetters: {
      'intPattern': (visitor) => TomArgs.intPattern,
      'doublePattern': (visitor) => TomArgs.doublePattern,
    },
    staticMethods: {
      'fillFromArgs': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'fillFromArgs');
        if (positional.isEmpty) {
          throw ArgumentError('fillFromArgs: Missing required argument "args" at position 0');
        }
        final args = D4.coerceList<String>(positional[0], 'args');
        final fillIn = D4.getRequiredArg<Object>(positional, 1, 'fillIn', 'fillFromArgs');
        return TomArgs.fillFromArgs(args, fillIn);
      },
      'parseArgsToMap': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'parseArgsToMap');
        if (positional.isEmpty) {
          throw ArgumentError('parseArgsToMap: Missing required argument "args" at position 0');
        }
        final args = D4.coerceList<String>(positional[0], 'args');
        return TomArgs.parseArgsToMap(args);
      },
      'convertToObjectMap': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'convertToObjectMap');
        if (positional.isEmpty) {
          throw ArgumentError('convertToObjectMap: Missing required argument "map" at position 0');
        }
        final map = D4.coerceMap<String, String>(positional[0], 'map');
        return TomArgs.convertToObjectMap(map);
      },
    },
    constructorSignatures: {
      '': 'TomArgs()',
    },
    staticMethodSignatures: {
      'fillFromArgs': 'T fillFromArgs(List<String> args, T fillIn)',
      'parseArgsToMap': 'Map<String, dynamic> parseArgsToMap(List<String> args)',
      'convertToObjectMap': 'Map<String, dynamic> convertToObjectMap(Map<String, String> map)',
    },
    staticGetterSignatures: {
      'intPattern': 'RegExp get intPattern',
      'doublePattern': 'RegExp get doublePattern',
    },
  );
}

// =============================================================================
// TomEnvFile Bridge
// =============================================================================

BridgedClass _createTomEnvFileBridge() {
  return BridgedClass(
    nativeType: TomEnvFile,
    name: 'TomEnvFile',
    isAssignable: (v) => v is TomEnvFile,
    constructors: {
      '': (visitor, positional, named) {
        return TomEnvFile();
      },
    },
    staticMethods: {
      'read': (visitor, positional, named, typeArgs) {
        final path = D4.getOptionalArgWithDefault<String>(positional, 0, 'path', '.env');
        return TomEnvFile.read(path);
      },
      'readAsync': (visitor, positional, named, typeArgs) {
        final path = D4.getOptionalArgWithDefault<String>(positional, 0, 'path', '.env');
        return TomEnvFile.readAsync(path);
      },
      'parse': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'parse');
        if (positional.isEmpty) {
          throw ArgumentError('parse: Missing required argument "lines" at position 0');
        }
        final lines = D4.coerceList<String>(positional[0], 'lines');
        return TomEnvFile.parse(lines);
      },
      'merge': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'merge');
        if (positional.isEmpty) {
          throw ArgumentError('merge: Missing required argument "sources" at position 0');
        }
        final sources = D4.coerceList<Map<String, Object?>>(positional[0], 'sources');
        return TomEnvFile.merge(sources);
      },
      'load': (visitor, positional, named, typeArgs) {
        final path = D4.getOptionalArgWithDefault<String>(positional, 0, 'path', '.env');
        return TomEnvFile.load(path);
      },
    },
    constructorSignatures: {
      '': 'TomEnvFile()',
    },
    staticMethodSignatures: {
      'read': 'Map<String, Object?> read([String path = \'.env\'])',
      'readAsync': 'Future<Map<String, Object?>> readAsync([String path = \'.env\'])',
      'parse': 'Map<String, Object?> parse(List<String> lines)',
      'merge': 'Map<String, Object?> merge(List<Map<String, Object?>> sources)',
      'load': 'Map<String, Object?> load([String path = \'.env\'])',
    },
  );
}

// =============================================================================
// TomServerConfigResourceProvider Bridge
// =============================================================================

BridgedClass _createTomServerConfigResourceProviderBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_3.TomServerConfigResourceProvider,
    name: 'TomServerConfigResourceProvider',
    isAssignable: (v) => v is $tom_core_server_3.TomServerConfigResourceProvider,
    constructors: {
      '': (visitor, positional, named) {
        return $tom_core_server_3.TomServerConfigResourceProvider();
      },
      'load': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomServerConfigResourceProvider');
        if (positional.isEmpty) {
          throw ArgumentError('TomServerConfigResourceProvider: Missing required argument "loader" at position 0');
        }
        final loaderRaw = positional[0];
        return $tom_core_server_3.TomServerConfigResourceProvider.load(() { return D4.callInterpreterCallback(visitor!, loaderRaw, []) as Map<String, dynamic>; });
      },
      'from': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomServerConfigResourceProvider');
        if (positional.isEmpty) {
          throw ArgumentError('TomServerConfigResourceProvider: Missing required argument "resources" at position 0');
        }
        final resources = D4.coerceMap<String, dynamic>(positional[0], 'resources');
        return $tom_core_server_3.TomServerConfigResourceProvider.from(resources);
      },
    },
    getters: {
      'resources': (visitor, target) => D4.validateTarget<$tom_core_server_3.TomServerConfigResourceProvider>(target, 'TomServerConfigResourceProvider').resources,
    },
    setters: {
    },
    methods: {
      'exists': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_3.TomServerConfigResourceProvider>(target, 'TomServerConfigResourceProvider');
        D4.requireMinArgs(positional, 1, 'exists');
        final s = D4.getRequiredArg<String>(positional, 0, 's', 'exists');
        return t.exists(s);
      },
      'get': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_3.TomServerConfigResourceProvider>(target, 'TomServerConfigResourceProvider');
        D4.requireMinArgs(positional, 1, 'get');
        final s = D4.getRequiredArg<String>(positional, 0, 's', 'get');
        return t.get(s);
      },
    },
    staticGetters: {
      'loader': (visitor) => $tom_core_server_3.TomServerConfigResourceProvider.loader,
    },
    staticMethods: {
      'setServerConfigProvider': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'setServerConfigProvider');
        final provider = D4.getRequiredArg<$tom_core_server_3.TomServerConfigResourceProvider>(positional, 0, 'provider', 'setServerConfigProvider');
        return $tom_core_server_3.TomServerConfigResourceProvider.setServerConfigProvider(provider);
      },
      'getServerConfig': (visitor, positional, named, typeArgs) {
        return $tom_core_server_3.TomServerConfigResourceProvider.getServerConfig();
      },
    },
    staticSetters: {
      'loader': (visitor, value) {
        final loaderRaw = D4.extractBridgedArgOrNull<dynamic>(value, 'loader');
        $tom_core_server_3.TomServerConfigResourceProvider.loader = loaderRaw == null ? null : () { return D4.callInterpreterCallback(visitor!, loaderRaw, []) as Map<String, dynamic>; };
      },
    },
    constructorSignatures: {
      '': 'TomServerConfigResourceProvider()',
      'load': 'TomServerConfigResourceProvider.load(Map<String, dynamic> Function() loader)',
      'from': 'TomServerConfigResourceProvider.from(Map<String, dynamic> resources)',
    },
    methodSignatures: {
      'exists': 'bool exists(String s)',
      'get': 'Object get(String s)',
    },
    getterSignatures: {
      'resources': 'Map<String, dynamic> get resources',
    },
    setterSignatures: {
      'resources': 'set resources(dynamic value)',
    },
    staticMethodSignatures: {
      'setServerConfigProvider': 'void setServerConfigProvider(TomServerConfigResourceProvider provider)',
      'getServerConfig': 'TomServerConfigResourceProvider getServerConfig()',
    },
    staticGetterSignatures: {
      'loader': 'Map<String, dynamic> Function()? get loader',
    },
    staticSetterSignatures: {
      'loader': 'set loader(dynamic value)',
    },
  );
}

// =============================================================================
// TomBaseServerConfiguration Bridge
// =============================================================================

BridgedClass _createTomBaseServerConfigurationBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_3.TomBaseServerConfiguration,
    name: 'TomBaseServerConfiguration',
    isAssignable: (v) => v is $tom_core_server_3.TomBaseServerConfiguration,
    constructors: {
    },
    getters: {
      'appId': (visitor, target) => D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').appId,
      'args': (visitor, target) => D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').args,
      'serverHeader': (visitor, target) => D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').serverHeader,
      'autoCompress': (visitor, target) => D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').autoCompress,
      'poweredByHeader': (visitor, target) => D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').poweredByHeader,
      'noSsl': (visitor, target) => D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').noSsl,
      'listenToAnyIP': (visitor, target) => D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').listenToAnyIP,
      'port': (visitor, target) => D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').port,
      'certificateChain': (visitor, target) => D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').certificateChain,
      'privateKey': (visitor, target) => D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').privateKey,
      'jwtRsaPubKey': (visitor, target) => D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').jwtRsaPubKey,
      'jwtRsaPrivKey': (visitor, target) => D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').jwtRsaPrivKey,
      'jwtSharedSecretKey': (visitor, target) => D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').jwtSharedSecretKey,
      'host': (visitor, target) => D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').host,
      'isolateCount': (visitor, target) => D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').isolateCount,
      'authenticationMiddleware': (visitor, target) => D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').authenticationMiddleware,
      'errorHandler': (visitor, target) => D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').errorHandler,
      'authenticationErrorHandler': (visitor, target) => D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').authenticationErrorHandler,
      'preExecutionHandler': (visitor, target) => D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').preExecutionHandler,
      'postExecutionHandler': (visitor, target) => D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').postExecutionHandler,
      'loggingMiddleware': (visitor, target) => D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').loggingMiddleware,
      'isolateLogging': (visitor, target) => D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').isolateLogging,
      'logLevelExceptions': (visitor, target) => D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').logLevelExceptions,
      'logLevel': (visitor, target) => D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').logLevel,
      'databaseMigrationsDirectory': (visitor, target) => D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').databaseMigrationsDirectory,
    },
    setters: {
      'appId': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').appId = D4.extractBridgedArg<String>(value, 'appId'),
      'args': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').args = (value as List).cast<String>().toList(),
      'serverHeader': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').serverHeader = D4.extractBridgedArg<String>(value, 'serverHeader'),
      'autoCompress': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').autoCompress = D4.extractBridgedArg<bool>(value, 'autoCompress'),
      'poweredByHeader': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').poweredByHeader = D4.extractBridgedArg<String>(value, 'poweredByHeader'),
      'noSsl': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').noSsl = D4.extractBridgedArg<bool>(value, 'noSsl'),
      'listenToAnyIP': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').listenToAnyIP = D4.extractBridgedArg<bool>(value, 'listenToAnyIP'),
      'port': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').port = D4.extractBridgedArg<int>(value, 'port'),
      'certificateChain': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').certificateChain = D4.extractBridgedArg<String>(value, 'certificateChain'),
      'privateKey': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').privateKey = D4.extractBridgedArg<String>(value, 'privateKey'),
      'jwtRsaPubKey': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').jwtRsaPubKey = D4.extractBridgedArgOrNull<String>(value, 'jwtRsaPubKey'),
      'jwtRsaPrivKey': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').jwtRsaPrivKey = D4.extractBridgedArgOrNull<String>(value, 'jwtRsaPrivKey'),
      'jwtSharedSecretKey': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').jwtSharedSecretKey = D4.extractBridgedArgOrNull<String>(value, 'jwtSharedSecretKey'),
      'host': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').host = D4.extractBridgedArg<String>(value, 'host'),
      'isolateCount': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').isolateCount = D4.extractBridgedArg<int>(value, 'isolateCount'),
      'authenticationMiddleware': (visitor, target, value) {
        final authenticationMiddlewareRaw = D4.extractBridgedArgOrNull<dynamic>(value, 'authenticationMiddleware');
        D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').authenticationMiddleware = authenticationMiddlewareRaw == null ? null : (FutureOr<$shelf_4.Response> Function($shelf_3.Request) p0) { return D4.callInterpreterCallback(visitor!, authenticationMiddlewareRaw, [p0]) as FutureOr<$shelf_4.Response> Function($shelf_3.Request); };
      },
      'errorHandler': (visitor, target, value) {
        final errorHandlerRaw = D4.extractBridgedArgOrNull<dynamic>(value, 'errorHandler');
        D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').errorHandler = errorHandlerRaw == null ? null : ($shelf_3.Request p0, Object p1, StackTrace p2) { return D4.callInterpreterCallback(visitor!, errorHandlerRaw, [p0, p1, p2]) as $shelf_4.Response?; };
      },
      'authenticationErrorHandler': (visitor, target, value) {
        final authenticationErrorHandlerRaw = D4.extractBridgedArgOrNull<dynamic>(value, 'authenticationErrorHandler');
        D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').authenticationErrorHandler = authenticationErrorHandlerRaw == null ? null : ($shelf_3.Request p0, Object p1, StackTrace p2) { return D4.callInterpreterCallback(visitor!, authenticationErrorHandlerRaw, [p0, p1, p2]) as $shelf_4.Response?; };
      },
      'preExecutionHandler': (visitor, target, value) {
        final preExecutionHandlerRaw = D4.extractBridgedArgOrNull<dynamic>(value, 'preExecutionHandler');
        D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').preExecutionHandler = preExecutionHandlerRaw == null ? null : ($shelf_3.Request p0) { return D4.callInterpreterCallback(visitor!, preExecutionHandlerRaw, [p0]) as FutureOr<$shelf_4.Response>; };
      },
      'postExecutionHandler': (visitor, target, value) {
        final postExecutionHandlerRaw = D4.extractBridgedArgOrNull<dynamic>(value, 'postExecutionHandler');
        D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').postExecutionHandler = postExecutionHandlerRaw == null ? null : ($shelf_3.Request p0) { return D4.callInterpreterCallback(visitor!, postExecutionHandlerRaw, [p0]) as FutureOr<$shelf_4.Response>; };
      },
      'loggingMiddleware': (visitor, target, value) {
        final loggingMiddlewareRaw = D4.extractBridgedArgOrNull<dynamic>(value, 'loggingMiddleware');
        D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').loggingMiddleware = (FutureOr<$shelf_4.Response> Function($shelf_3.Request) p0) { return D4.callInterpreterCallback(visitor!, loggingMiddlewareRaw, [p0]) as FutureOr<$shelf_4.Response> Function($shelf_3.Request); };
      },
      'isolateLogging': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').isolateLogging = D4.extractBridgedArg<bool>(value, 'isolateLogging'),
      'logLevelExceptions': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').logLevelExceptions = D4.extractBridgedArg<String>(value, 'logLevelExceptions'),
      'logLevel': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').logLevel = D4.extractBridgedArg<String>(value, 'logLevel'),
      'databaseMigrationsDirectory': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration').databaseMigrationsDirectory = D4.extractBridgedArg<String>(value, 'databaseMigrationsDirectory'),
    },
    methods: {
      'setValues': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_3.TomBaseServerConfiguration>(target, 'TomBaseServerConfiguration');
        D4.requireMinArgs(positional, 1, 'setValues');
        if (positional.isEmpty) {
          throw ArgumentError('setValues: Missing required argument "values" at position 0');
        }
        final values = D4.coerceMap<String, Object?>(positional[0], 'values');
        t.setValues(values);
        return null;
      },
    },
    staticMethods: {
      'getDefaultValues': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'getDefaultValues');
        if (positional.isEmpty) {
          throw ArgumentError('getDefaultValues: Missing required argument "args" at position 0');
        }
        final args = D4.coerceList<String>(positional[0], 'args');
        return $tom_core_server_3.TomBaseServerConfiguration.getDefaultValues(args);
      },
    },
    methodSignatures: {
      'setValues': 'void setValues(Map<String, Object?> values)',
    },
    getterSignatures: {
      'appId': 'String get appId',
      'args': 'List<String> get args',
      'serverHeader': 'String get serverHeader',
      'autoCompress': 'bool get autoCompress',
      'poweredByHeader': 'String get poweredByHeader',
      'noSsl': 'bool get noSsl',
      'listenToAnyIP': 'bool get listenToAnyIP',
      'port': 'int get port',
      'certificateChain': 'String get certificateChain',
      'privateKey': 'String get privateKey',
      'jwtRsaPubKey': 'String? get jwtRsaPubKey',
      'jwtRsaPrivKey': 'String? get jwtRsaPrivKey',
      'jwtSharedSecretKey': 'String? get jwtSharedSecretKey',
      'host': 'String get host',
      'isolateCount': 'int get isolateCount',
      'authenticationMiddleware': 'Middleware? get authenticationMiddleware',
      'errorHandler': 'Response? Function(Request, Object, StackTrace)? get errorHandler',
      'authenticationErrorHandler': 'Response? Function(Request, Object, StackTrace)? get authenticationErrorHandler',
      'preExecutionHandler': 'Handler? get preExecutionHandler',
      'postExecutionHandler': 'Handler? get postExecutionHandler',
      'loggingMiddleware': 'Middleware get loggingMiddleware',
      'isolateLogging': 'bool get isolateLogging',
      'logLevelExceptions': 'String get logLevelExceptions',
      'logLevel': 'String get logLevel',
      'databaseMigrationsDirectory': 'String get databaseMigrationsDirectory',
    },
    setterSignatures: {
      'appId': 'set appId(dynamic value)',
      'args': 'set args(dynamic value)',
      'serverHeader': 'set serverHeader(dynamic value)',
      'autoCompress': 'set autoCompress(dynamic value)',
      'poweredByHeader': 'set poweredByHeader(dynamic value)',
      'noSsl': 'set noSsl(dynamic value)',
      'listenToAnyIP': 'set listenToAnyIP(dynamic value)',
      'port': 'set port(dynamic value)',
      'certificateChain': 'set certificateChain(dynamic value)',
      'privateKey': 'set privateKey(dynamic value)',
      'jwtRsaPubKey': 'set jwtRsaPubKey(dynamic value)',
      'jwtRsaPrivKey': 'set jwtRsaPrivKey(dynamic value)',
      'jwtSharedSecretKey': 'set jwtSharedSecretKey(dynamic value)',
      'host': 'set host(dynamic value)',
      'isolateCount': 'set isolateCount(dynamic value)',
      'authenticationMiddleware': 'set authenticationMiddleware(dynamic value)',
      'errorHandler': 'set errorHandler(dynamic value)',
      'authenticationErrorHandler': 'set authenticationErrorHandler(dynamic value)',
      'preExecutionHandler': 'set preExecutionHandler(dynamic value)',
      'postExecutionHandler': 'set postExecutionHandler(dynamic value)',
      'loggingMiddleware': 'set loggingMiddleware(dynamic value)',
      'isolateLogging': 'set isolateLogging(dynamic value)',
      'logLevelExceptions': 'set logLevelExceptions(dynamic value)',
      'logLevel': 'set logLevel(dynamic value)',
      'databaseMigrationsDirectory': 'set databaseMigrationsDirectory(dynamic value)',
    },
    staticMethodSignatures: {
      'getDefaultValues': 'Map<String, Object?> getDefaultValues(List<String> args)',
    },
  );
}

// =============================================================================
// TomConfig Bridge
// =============================================================================

BridgedClass _createTomConfigBridge() {
  return BridgedClass(
    nativeType: TomConfig,
    name: 'TomConfig',
    isAssignable: (v) => v is TomConfig,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomConfig');
        final key = D4.getRequiredArg<String>(positional, 0, 'key', 'TomConfig');
        return TomConfig(key);
      },
      'withDefault': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'TomConfig');
        final key = D4.getRequiredArg<String>(positional, 0, 'key', 'TomConfig');
        final value = D4.getRequiredArg<dynamic>(positional, 1, 'value', 'TomConfig');
        // GEN-075: Preserve generic type parameter from runtime value
        switch (value) {
          case double _: return TomConfig<double>.withDefault(key, value);
          case int _: return TomConfig<int>.withDefault(key, value);
          case String _: return TomConfig<String>.withDefault(key, value);
          case bool _: return TomConfig<bool>.withDefault(key, value);
          case TomAuthenticationAdaptor _: return TomConfig<TomAuthenticationAdaptor>.withDefault(key, value);
          case Tom2FAAdaptor _: return TomConfig<Tom2FAAdaptor>.withDefault(key, value);
          case LoginException _: return TomConfig<LoginException>.withDefault(key, value);
          case $tom_core_server_1.TomAuthenticationData _: return TomConfig<$tom_core_server_1.TomAuthenticationData>.withDefault(key, value);
          case $tom_core_server_1.TomAuthenticationService _: return TomConfig<$tom_core_server_1.TomAuthenticationService>.withDefault(key, value);
          case Tom2FAService _: return TomConfig<Tom2FAService>.withDefault(key, value);
          case $tom_core_server_1.TomAuthenticationInfo _: return TomConfig<$tom_core_server_1.TomAuthenticationInfo>.withDefault(key, value);
          case TomDummyAuthenticationService _: return TomConfig<TomDummyAuthenticationService>.withDefault(key, value);
          case TomAuthenticationServer _: return TomConfig<TomAuthenticationServer>.withDefault(key, value);
          case TomAuthorizationCacheException _: return TomConfig<TomAuthorizationCacheException>.withDefault(key, value);
          case TomAuthorizationCacheEntry _: return TomConfig<TomAuthorizationCacheEntry>.withDefault(key, value);
          case TomAuthorizationCache _: return TomConfig<TomAuthorizationCache>.withDefault(key, value);
          case TomAuthorizationCacheStoreMessage _: return TomConfig<TomAuthorizationCacheStoreMessage>.withDefault(key, value);
          case TomAuthorizationCacheRetrieveMessage _: return TomConfig<TomAuthorizationCacheRetrieveMessage>.withDefault(key, value);
          case TomAuthorizationCacheExecutor _: return TomConfig<TomAuthorizationCacheExecutor>.withDefault(key, value);
          case TomArgs _: return TomConfig<TomArgs>.withDefault(key, value);
          case TomEnvFile _: return TomConfig<TomEnvFile>.withDefault(key, value);
          case $tom_core_server_3.TomServerConfigResourceProvider _: return TomConfig<$tom_core_server_3.TomServerConfigResourceProvider>.withDefault(key, value);
          case $tom_core_server_3.TomBaseServerConfiguration _: return TomConfig<$tom_core_server_3.TomBaseServerConfiguration>.withDefault(key, value);
          case TomStringConfig _: return TomConfig<TomStringConfig>.withDefault(key, value);
          case TomIntConfig _: return TomConfig<TomIntConfig>.withDefault(key, value);
          case TomDoubleConfig _: return TomConfig<TomDoubleConfig>.withDefault(key, value);
          case TomBoolConfig _: return TomConfig<TomBoolConfig>.withDefault(key, value);
          case TomYaml _: return TomConfig<TomYaml>.withDefault(key, value);
          case TomCacheException _: return TomConfig<TomCacheException>.withDefault(key, value);
          case $tom_core_server_2.TomCacheEntry _: return TomConfig<$tom_core_server_2.TomCacheEntry>.withDefault(key, value);
          case $tom_core_server_2.TomCacheManager _: return TomConfig<$tom_core_server_2.TomCacheManager>.withDefault(key, value);
          case $tom_core_server_2.TomCache _: return TomConfig<$tom_core_server_2.TomCache>.withDefault(key, value);
          case TomCacheStoreMessage _: return TomConfig<TomCacheStoreMessage>.withDefault(key, value);
          case TomCacheRemoveMessage _: return TomConfig<TomCacheRemoveMessage>.withDefault(key, value);
          case TomCacheRetrieveMessage _: return TomConfig<TomCacheRetrieveMessage>.withDefault(key, value);
          case TomDatasourceInitException _: return TomConfig<TomDatasourceInitException>.withDefault(key, value);
          case TomDatasourceDriver _: return TomConfig<TomDatasourceDriver>.withDefault(key, value);
          case $tom_core_server_4.TomPreparedStatement _: return TomConfig<$tom_core_server_4.TomPreparedStatement>.withDefault(key, value);
          case $tom_core_server_4.TomDataSource _: return TomConfig<$tom_core_server_4.TomDataSource>.withDefault(key, value);
          case $tom_core_server_4.TomDataSourceInfo _: return TomConfig<$tom_core_server_4.TomDataSourceInfo>.withDefault(key, value);
          case MariadbDatasourceException _: return TomConfig<MariadbDatasourceException>.withDefault(key, value);
          case MariadbPreparedStatementException _: return TomConfig<MariadbPreparedStatementException>.withDefault(key, value);
          case MariadbPreparedStatement _: return TomConfig<MariadbPreparedStatement>.withDefault(key, value);
          case $tom_core_server_5.MariaDbDatasource _: return TomConfig<$tom_core_server_5.MariaDbDatasource>.withDefault(key, value);
          case MariaDbXADatasource _: return TomConfig<MariaDbXADatasource>.withDefault(key, value);
          case MariadbSqlDialect _: return TomConfig<MariadbSqlDialect>.withDefault(key, value);
          case $tom_core_server_6.TomTypePersistenceInfo _: return TomConfig<$tom_core_server_6.TomTypePersistenceInfo>.withDefault(key, value);
          case TomTypedPersistenceBase _: return TomConfig<TomTypedPersistenceBase>.withDefault(key, value);
          case $tom_core_server_6.TomQuery _: return TomConfig<$tom_core_server_6.TomQuery>.withDefault(key, value);
          case TomGeneratedQuery _: return TomConfig<TomGeneratedQuery>.withDefault(key, value);
          case $tom_core_server_6.TomSelect _: return TomConfig<$tom_core_server_6.TomSelect>.withDefault(key, value);
          case TomLiteralSelect _: return TomConfig<TomLiteralSelect>.withDefault(key, value);
          case $tom_core_server_6.TomCount _: return TomConfig<$tom_core_server_6.TomCount>.withDefault(key, value);
          case $tom_core_server_6.TomDelete _: return TomConfig<$tom_core_server_6.TomDelete>.withDefault(key, value);
          case $aux_aux.TomStandardSqlDialect _: return TomConfig<$aux_aux.TomStandardSqlDialect>.withDefault(key, value);
          case $aux_aux.TomSqlDialect _: return TomConfig<$aux_aux.TomSqlDialect>.withDefault(key, value);
          case $tom_core_server_8.TomDbType _: return TomConfig<$tom_core_server_8.TomDbType>.withDefault(key, value);
          case $tom_core_server_8.TomDbInt _: return TomConfig<$tom_core_server_8.TomDbInt>.withDefault(key, value);
          case $tom_core_server_8.TomDbDouble _: return TomConfig<$tom_core_server_8.TomDbDouble>.withDefault(key, value);
          case $tom_core_server_8.TomDbString _: return TomConfig<$tom_core_server_8.TomDbString>.withDefault(key, value);
          case $tom_core_server_8.TomDbDateTime _: return TomConfig<$tom_core_server_8.TomDbDateTime>.withDefault(key, value);
          case $tom_core_server_8.TomDbDate _: return TomConfig<$tom_core_server_8.TomDbDate>.withDefault(key, value);
          case $tom_core_server_8.TomDbTime _: return TomConfig<$tom_core_server_8.TomDbTime>.withDefault(key, value);
          case $tom_core_server_8.TomDbBool _: return TomConfig<$tom_core_server_8.TomDbBool>.withDefault(key, value);
          case $tom_core_server_8.TomOperator _: return TomConfig<$tom_core_server_8.TomOperator>.withDefault(key, value);
          case TomDbMigrationException _: return TomConfig<TomDbMigrationException>.withDefault(key, value);
          case TomDbMigrationAdaptor _: return TomConfig<TomDbMigrationAdaptor>.withDefault(key, value);
          case TomDbMigrator _: return TomConfig<TomDbMigrator>.withDefault(key, value);
          case TomDbMigrations _: return TomConfig<TomDbMigrations>.withDefault(key, value);
          case MariadbMigrationException _: return TomConfig<MariadbMigrationException>.withDefault(key, value);
          case MariadbMigrationAdaptor _: return TomConfig<MariadbMigrationAdaptor>.withDefault(key, value);
          case $tom_core_server_9.TomDbVersion _: return TomConfig<$tom_core_server_9.TomDbVersion>.withDefault(key, value);
          case $tom_core_server_10.TomErrorHandler _: return TomConfig<$tom_core_server_10.TomErrorHandler>.withDefault(key, value);
          case TomDefaultErrorHandler _: return TomConfig<TomDefaultErrorHandler>.withDefault(key, value);
          case TomService _: return TomConfig<TomService>.withDefault(key, value);
          case $tom_core_server_10.TomApiImplementation _: return TomConfig<$tom_core_server_10.TomApiImplementation>.withDefault(key, value);
          case TomEndpointBase _: return TomConfig<TomEndpointBase>.withDefault(key, value);
          case $tom_core_server_10.TomApiEndpointImplementation _: return TomConfig<$tom_core_server_10.TomApiEndpointImplementation>.withDefault(key, value);
          case $tom_core_server_10.TomEndpoint _: return TomConfig<$tom_core_server_10.TomEndpoint>.withDefault(key, value);
          case TomComponentReference _: return TomConfig<TomComponentReference>.withDefault(key, value);
          case $tom_core_server_10.TomTransactional _: return TomConfig<$tom_core_server_10.TomTransactional>.withDefault(key, value);
          case TomEndpointHandlerException _: return TomConfig<TomEndpointHandlerException>.withDefault(key, value);
          case TomEndpointPipelineException _: return TomConfig<TomEndpointPipelineException>.withDefault(key, value);
          case $tom_core_server_11.TomEndpointHandler _: return TomConfig<$tom_core_server_11.TomEndpointHandler>.withDefault(key, value);
          case $tom_core_server_11.TomEndpointRoutingInfo _: return TomConfig<$tom_core_server_11.TomEndpointRoutingInfo>.withDefault(key, value);
          case TomEndpointRouting _: return TomConfig<TomEndpointRouting>.withDefault(key, value);
          case $tom_core_server_11.TomMethodMetadata _: return TomConfig<$tom_core_server_11.TomMethodMetadata>.withDefault(key, value);
          case $tom_core_server_11.TomClassScanResult _: return TomConfig<$tom_core_server_11.TomClassScanResult>.withDefault(key, value);
          case $tom_core_server_12.HealthAnalyzer _: return TomConfig<$tom_core_server_12.HealthAnalyzer>.withDefault(key, value);
          case DefaultHealthAnalyzer _: return TomConfig<DefaultHealthAnalyzer>.withDefault(key, value);
          case TomHealthService _: return TomConfig<TomHealthService>.withDefault(key, value);
          case TomHealthServer _: return TomConfig<TomHealthServer>.withDefault(key, value);
          case TomServerException _: return TomConfig<TomServerException>.withDefault(key, value);
          case TomAnnotationAnalyzerException _: return TomConfig<TomAnnotationAnalyzerException>.withDefault(key, value);
          case TomAnnotationAnalyzerSyntaxException _: return TomConfig<TomAnnotationAnalyzerSyntaxException>.withDefault(key, value);
          case TomAnnotationAnalyzer _: return TomConfig<TomAnnotationAnalyzer>.withDefault(key, value);
          case $tom_core_server_13.TomCountResult _: return TomConfig<$tom_core_server_13.TomCountResult>.withDefault(key, value);
          case $tom_core_server_13.TomRepository _: return TomConfig<$tom_core_server_13.TomRepository>.withDefault(key, value);
          case TomSqlDatasourceRepository _: return TomConfig<TomSqlDatasourceRepository>.withDefault(key, value);
          case TomRepositoryType _: return TomConfig<TomRepositoryType>.withDefault(key, value);
          case MariadbRepository _: return TomConfig<MariadbRepository>.withDefault(key, value);
          case TomQuerySyntaxException _: return TomConfig<TomQuerySyntaxException>.withDefault(key, value);
          case TomUnaryOperator _: return TomConfig<TomUnaryOperator>.withDefault(key, value);
          case Parameter _: return TomConfig<Parameter>.withDefault(key, value);
          case $tom_core_server_14.DbCol _: return TomConfig<$tom_core_server_14.DbCol>.withDefault(key, value);
          case IntCol _: return TomConfig<IntCol>.withDefault(key, value);
          case StringCol _: return TomConfig<StringCol>.withDefault(key, value);
          case DoubleCol _: return TomConfig<DoubleCol>.withDefault(key, value);
          case BoolCol _: return TomConfig<BoolCol>.withDefault(key, value);
          case DateTimeCol _: return TomConfig<DateTimeCol>.withDefault(key, value);
          case DateCol _: return TomConfig<DateCol>.withDefault(key, value);
          case StringLiteral _: return TomConfig<StringLiteral>.withDefault(key, value);
          case IntegerLiteral _: return TomConfig<IntegerLiteral>.withDefault(key, value);
          case DoubleLiteral _: return TomConfig<DoubleLiteral>.withDefault(key, value);
          case BoolLiteral _: return TomConfig<BoolLiteral>.withDefault(key, value);
          case DateTimeLiteral _: return TomConfig<DateTimeLiteral>.withDefault(key, value);
          case DateLiteral _: return TomConfig<DateLiteral>.withDefault(key, value);
          case Not _: return TomConfig<Not>.withDefault(key, value);
          case IsNull _: return TomConfig<IsNull>.withDefault(key, value);
          case IsNotNull _: return TomConfig<IsNotNull>.withDefault(key, value);
          case TomBinaryOperator _: return TomConfig<TomBinaryOperator>.withDefault(key, value);
          case And _: return TomConfig<And>.withDefault(key, value);
          case Or _: return TomConfig<Or>.withDefault(key, value);
          case Eq _: return TomConfig<Eq>.withDefault(key, value);
          case Neq _: return TomConfig<Neq>.withDefault(key, value);
          case Lt _: return TomConfig<Lt>.withDefault(key, value);
          case Gt _: return TomConfig<Gt>.withDefault(key, value);
          case Lte _: return TomConfig<Lte>.withDefault(key, value);
          case Gte _: return TomConfig<Gte>.withDefault(key, value);
          case Like _: return TomConfig<Like>.withDefault(key, value);
          case NotLike _: return TomConfig<NotLike>.withDefault(key, value);
          case In _: return TomConfig<In>.withDefault(key, value);
          case Group _: return TomConfig<Group>.withDefault(key, value);
          case Between _: return TomConfig<Between>.withDefault(key, value);
          case Regexp _: return TomConfig<Regexp>.withDefault(key, value);
          case TomDartType _: return TomConfig<TomDartType>.withDefault(key, value);
          case $tom_core_server_15.TomDbTable _: return TomConfig<$tom_core_server_15.TomDbTable>.withDefault(key, value);
          case $tom_core_server_15.TomDbColumn _: return TomConfig<$tom_core_server_15.TomDbColumn>.withDefault(key, value);
          case $tom_core_server_15.TomEntityId _: return TomConfig<$tom_core_server_15.TomEntityId>.withDefault(key, value);
          case TomJoinTable _: return TomConfig<TomJoinTable>.withDefault(key, value);
          case $tom_core_server_15.TomReference _: return TomConfig<$tom_core_server_15.TomReference>.withDefault(key, value);
          case $tom_core_server_15.TomPersistenceEventHandler _: return TomConfig<$tom_core_server_15.TomPersistenceEventHandler>.withDefault(key, value);
          case $tom_core_server_15.TomColumnInformation _: return TomConfig<$tom_core_server_15.TomColumnInformation>.withDefault(key, value);
          case TomQueryBuilder _: return TomConfig<TomQueryBuilder>.withDefault(key, value);
          case TomQuerySentenceCompiler _: return TomConfig<TomQuerySentenceCompiler>.withDefault(key, value);
          case TomRequestId _: return TomConfig<TomRequestId>.withDefault(key, value);
          case TomRequestLogInfo _: return TomConfig<TomRequestLogInfo>.withDefault(key, value);
          case TomServer _: return TomConfig<TomServer>.withDefault(key, value);
          case TomTransactionException _: return TomConfig<TomTransactionException>.withDefault(key, value);
          case $tom_core_server_16.TomTransactionParticipant _: return TomConfig<$tom_core_server_16.TomTransactionParticipant>.withDefault(key, value);
          case $tom_core_server_16.TomTransaction _: return TomConfig<$tom_core_server_16.TomTransaction>.withDefault(key, value);
          case TomTransactionManager _: return TomConfig<TomTransactionManager>.withDefault(key, value);
          case $mysql_client_1.MySQLConnection _: return TomConfig<$mysql_client_1.MySQLConnection>.withDefault(key, value);
          case $mysql_client_1.IResultSet _: return TomConfig<$mysql_client_1.IResultSet>.withDefault(key, value);
          case ResultSet _: return TomConfig<ResultSet>.withDefault(key, value);
          case IterableResultSet _: return TomConfig<IterableResultSet>.withDefault(key, value);
          case PreparedStmtResultSet _: return TomConfig<PreparedStmtResultSet>.withDefault(key, value);
          case IterablePreparedStmtResultSet _: return TomConfig<IterablePreparedStmtResultSet>.withDefault(key, value);
          case EmptyResultSet _: return TomConfig<EmptyResultSet>.withDefault(key, value);
          case $mysql_client_1.ResultSetRow _: return TomConfig<$mysql_client_1.ResultSetRow>.withDefault(key, value);
          case $mysql_client_1.ResultSetColumn _: return TomConfig<$mysql_client_1.ResultSetColumn>.withDefault(key, value);
          case $mysql_client_1.PreparedStmt _: return TomConfig<$mysql_client_1.PreparedStmt>.withDefault(key, value);
          case MySQLConnectionPool _: return TomConfig<MySQLConnectionPool>.withDefault(key, value);
          case TomStandalonePlatformUtils _: return TomConfig<TomStandalonePlatformUtils>.withDefault(key, value);
          case TomBaseException _: return TomConfig<TomBaseException>.withDefault(key, value);
          case $tom_basics_1.TomLogLevel _: return TomConfig<$tom_basics_1.TomLogLevel>.withDefault(key, value);
          case $tom_basics_1.TomLogger _: return TomConfig<$tom_basics_1.TomLogger>.withDefault(key, value);
          case TomLoggable _: return TomConfig<TomLoggable>.withDefault(key, value);
          case $tom_basics_1.TomLogOutput _: return TomConfig<$tom_basics_1.TomLogOutput>.withDefault(key, value);
          case TomConsoleLogOutput _: return TomConfig<TomConsoleLogOutput>.withDefault(key, value);
          case $tom_basics_3.TomPlatformUtils _: return TomConfig<$tom_basics_3.TomPlatformUtils>.withDefault(key, value);
          case TomFallbackPlatformUtils _: return TomConfig<TomFallbackPlatformUtils>.withDefault(key, value);
          case $tom_basics_2.TomEnvironment _: return TomConfig<$tom_basics_2.TomEnvironment>.withDefault(key, value);
          case $tom_basics_2.TomPlatform _: return TomConfig<$tom_basics_2.TomPlatform>.withDefault(key, value);
          case TomRuntime _: return TomConfig<TomRuntime>.withDefault(key, value);
          case $shelf_3.Request _: return TomConfig<$shelf_3.Request>.withDefault(key, value);
          default: return TomConfig.withDefault(key, value);
        }
      },
    },
    methods: {
      'get': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomConfig>(target, 'TomConfig');
        return t.get();
      },
      '~': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomConfig>(target, 'TomConfig');
        return ~t;
      },
    },
    constructorSignatures: {
      '': 'TomConfig(String key)',
      'withDefault': 'TomConfig.withDefault(String key, T value)',
    },
    methodSignatures: {
      'get': 'T? get()',
    },
  );
}

// =============================================================================
// TomStringConfig Bridge
// =============================================================================

BridgedClass _createTomStringConfigBridge() {
  return BridgedClass(
    nativeType: TomStringConfig,
    name: 'TomStringConfig',
    isAssignable: (v) => v is TomStringConfig,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomStringConfig');
        final key = D4.getRequiredArg<String>(positional, 0, 'key', 'TomStringConfig');
        return TomStringConfig(key);
      },
      'withDefault': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'TomStringConfig');
        final key = D4.getRequiredArg<String>(positional, 0, 'key', 'TomStringConfig');
        final value = D4.getRequiredArg<String>(positional, 1, 'value', 'TomStringConfig');
        return TomStringConfig.withDefault(key, value);
      },
    },
    methods: {
      'get': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomStringConfig>(target, 'TomStringConfig');
        return t.get();
      },
      '~': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomStringConfig>(target, 'TomStringConfig');
        return ~t;
      },
    },
    constructorSignatures: {
      '': 'TomStringConfig(String key)',
      'withDefault': 'TomStringConfig.withDefault(String key, String value)',
    },
    methodSignatures: {
      'get': 'String? get()',
    },
  );
}

// =============================================================================
// TomIntConfig Bridge
// =============================================================================

BridgedClass _createTomIntConfigBridge() {
  return BridgedClass(
    nativeType: TomIntConfig,
    name: 'TomIntConfig',
    isAssignable: (v) => v is TomIntConfig,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomIntConfig');
        final key = D4.getRequiredArg<String>(positional, 0, 'key', 'TomIntConfig');
        return TomIntConfig(key);
      },
      'withDefault': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'TomIntConfig');
        final key = D4.getRequiredArg<String>(positional, 0, 'key', 'TomIntConfig');
        final value = D4.getRequiredArg<int>(positional, 1, 'value', 'TomIntConfig');
        return TomIntConfig.withDefault(key, value);
      },
    },
    methods: {
      'get': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomIntConfig>(target, 'TomIntConfig');
        return t.get();
      },
      '~': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomIntConfig>(target, 'TomIntConfig');
        return ~t;
      },
    },
    constructorSignatures: {
      '': 'TomIntConfig(String key)',
      'withDefault': 'TomIntConfig.withDefault(String key, int value)',
    },
    methodSignatures: {
      'get': 'int? get()',
    },
  );
}

// =============================================================================
// TomDoubleConfig Bridge
// =============================================================================

BridgedClass _createTomDoubleConfigBridge() {
  return BridgedClass(
    nativeType: TomDoubleConfig,
    name: 'TomDoubleConfig',
    isAssignable: (v) => v is TomDoubleConfig,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomDoubleConfig');
        final key = D4.getRequiredArg<String>(positional, 0, 'key', 'TomDoubleConfig');
        return TomDoubleConfig(key);
      },
      'withDefault': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'TomDoubleConfig');
        final key = D4.getRequiredArg<String>(positional, 0, 'key', 'TomDoubleConfig');
        final value = D4.getRequiredArg<double>(positional, 1, 'value', 'TomDoubleConfig');
        return TomDoubleConfig.withDefault(key, value);
      },
    },
    methods: {
      'get': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomDoubleConfig>(target, 'TomDoubleConfig');
        return t.get();
      },
      '~': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomDoubleConfig>(target, 'TomDoubleConfig');
        return ~t;
      },
    },
    constructorSignatures: {
      '': 'TomDoubleConfig(String key)',
      'withDefault': 'TomDoubleConfig.withDefault(String key, double value)',
    },
    methodSignatures: {
      'get': 'double? get()',
    },
  );
}

// =============================================================================
// TomBoolConfig Bridge
// =============================================================================

BridgedClass _createTomBoolConfigBridge() {
  return BridgedClass(
    nativeType: TomBoolConfig,
    name: 'TomBoolConfig',
    isAssignable: (v) => v is TomBoolConfig,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomBoolConfig');
        final key = D4.getRequiredArg<String>(positional, 0, 'key', 'TomBoolConfig');
        return TomBoolConfig(key);
      },
      'withDefault': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'TomBoolConfig');
        final key = D4.getRequiredArg<String>(positional, 0, 'key', 'TomBoolConfig');
        final value = D4.getRequiredArg<bool>(positional, 1, 'value', 'TomBoolConfig');
        return TomBoolConfig.withDefault(key, value);
      },
    },
    methods: {
      'get': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomBoolConfig>(target, 'TomBoolConfig');
        return t.get();
      },
      '~': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomBoolConfig>(target, 'TomBoolConfig');
        return ~t;
      },
    },
    constructorSignatures: {
      '': 'TomBoolConfig(String key)',
      'withDefault': 'TomBoolConfig.withDefault(String key, bool value)',
    },
    methodSignatures: {
      'get': 'bool? get()',
    },
  );
}

// =============================================================================
// TomYaml Bridge
// =============================================================================

BridgedClass _createTomYamlBridge() {
  return BridgedClass(
    nativeType: TomYaml,
    name: 'TomYaml',
    isAssignable: (v) => v is TomYaml,
    constructors: {
      '': (visitor, positional, named) {
        return TomYaml();
      },
    },
    staticMethods: {
      'mergeInYamlFile': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'mergeInYamlFile');
        if (positional.isEmpty) {
          throw ArgumentError('mergeInYamlFile: Missing required argument "result" at position 0');
        }
        final result = D4.coerceMap<String, Object?>(positional[0], 'result');
        final filename = D4.getRequiredArg<String>(positional, 1, 'filename', 'mergeInYamlFile');
        return TomYaml.mergeInYamlFile(result, filename);
      },
      'loadYamlFile': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'loadYamlFile');
        final filename = D4.getRequiredArg<String>(positional, 0, 'filename', 'loadYamlFile');
        return TomYaml.loadYamlFile(filename);
      },
    },
    constructorSignatures: {
      '': 'TomYaml()',
    },
    staticMethodSignatures: {
      'mergeInYamlFile': 'void mergeInYamlFile(Map<String, Object?> result, String filename)',
      'loadYamlFile': 'Map<String, Object?> loadYamlFile(String filename)',
    },
  );
}

// =============================================================================
// TomCacheException Bridge
// =============================================================================

BridgedClass _createTomCacheExceptionBridge() {
  return BridgedClass(
    nativeType: TomCacheException,
    name: 'TomCacheException',
    isAssignable: (v) => v is TomCacheException,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'TomCacheException');
        final key = D4.getRequiredArg<String>(positional, 0, 'key', 'TomCacheException');
        final userMessage = D4.getRequiredArg<String>(positional, 1, 'userMessage', 'TomCacheException');
        final parameters = D4.coerceMapOrNull<String, Object?>(named['parameters'], 'parameters');
        final stack = D4.getOptionalNamedArg<Object?>(named, 'stack');
        final rootException = D4.getOptionalNamedArg<Object?>(named, 'rootException');
        final autoLog = D4.getNamedArgWithDefault<bool>(named, 'autoLog', false);
        return TomCacheException(key, userMessage, parameters: parameters, stack: stack, rootException: rootException, autoLog: autoLog);
      },
    },
    getters: {
      'isolateName': (visitor, target) => D4.validateTarget<TomCacheException>(target, 'TomCacheException').isolateName,
      'clientThrow': (visitor, target) => D4.validateTarget<TomCacheException>(target, 'TomCacheException').clientThrow,
      'autoLog': (visitor, target) => D4.validateTarget<TomCacheException>(target, 'TomCacheException').autoLog,
      'serverCallError': (visitor, target) => D4.validateTarget<TomCacheException>(target, 'TomCacheException').serverCallError,
      'newField': (visitor, target) => D4.validateTarget<TomCacheException>(target, 'TomCacheException').newField,
      'logRepresentation': (visitor, target) => D4.validateTarget<TomCacheException>(target, 'TomCacheException').logRepresentation,
      'uuid': (visitor, target) => D4.validateTarget<TomCacheException>(target, 'TomCacheException').uuid,
      'requestUuid': (visitor, target) => D4.validateTarget<TomCacheException>(target, 'TomCacheException').requestUuid,
      'timeStamp': (visitor, target) => D4.validateTarget<TomCacheException>(target, 'TomCacheException').timeStamp,
      'key': (visitor, target) => D4.validateTarget<TomCacheException>(target, 'TomCacheException').key,
      'defaultUserMessage': (visitor, target) => D4.validateTarget<TomCacheException>(target, 'TomCacheException').defaultUserMessage,
      'parameters': (visitor, target) => D4.validateTarget<TomCacheException>(target, 'TomCacheException').parameters,
      'stack': (visitor, target) => D4.validateTarget<TomCacheException>(target, 'TomCacheException').stack,
      'rootException': (visitor, target) => D4.validateTarget<TomCacheException>(target, 'TomCacheException').rootException,
      'stackTrace': (visitor, target) => D4.validateTarget<TomCacheException>(target, 'TomCacheException').stackTrace,
    },
    setters: {
      'isolateName': (visitor, target, value) => 
        D4.validateTarget<TomCacheException>(target, 'TomCacheException').isolateName = D4.extractBridgedArg<String>(value, 'isolateName'),
      'clientThrow': (visitor, target, value) => 
        D4.validateTarget<TomCacheException>(target, 'TomCacheException').clientThrow = D4.extractBridgedArg<bool>(value, 'clientThrow'),
      'autoLog': (visitor, target, value) => 
        D4.validateTarget<TomCacheException>(target, 'TomCacheException').autoLog = D4.extractBridgedArg<bool>(value, 'autoLog'),
      'serverCallError': (visitor, target, value) => 
        D4.validateTarget<TomCacheException>(target, 'TomCacheException').serverCallError = D4.extractBridgedArgOrNull<$tom_core_kernel_4.TomServerCallError>(value, 'serverCallError'),
      'newField': (visitor, target, value) => 
        D4.validateTarget<TomCacheException>(target, 'TomCacheException').newField = D4.extractBridgedArgOrNull<String>(value, 'newField'),
      'uuid': (visitor, target, value) => 
        D4.validateTarget<TomCacheException>(target, 'TomCacheException').uuid = D4.extractBridgedArg<String>(value, 'uuid'),
      'requestUuid': (visitor, target, value) => 
        D4.validateTarget<TomCacheException>(target, 'TomCacheException').requestUuid = D4.extractBridgedArgOrNull<String>(value, 'requestUuid'),
      'timeStamp': (visitor, target, value) => 
        D4.validateTarget<TomCacheException>(target, 'TomCacheException').timeStamp = D4.extractBridgedArg<DateTime>(value, 'timeStamp'),
      'key': (visitor, target, value) => 
        D4.validateTarget<TomCacheException>(target, 'TomCacheException').key = D4.extractBridgedArg<String>(value, 'key'),
      'defaultUserMessage': (visitor, target, value) => 
        D4.validateTarget<TomCacheException>(target, 'TomCacheException').defaultUserMessage = D4.extractBridgedArg<String>(value, 'defaultUserMessage'),
      'stack': (visitor, target, value) => 
        D4.validateTarget<TomCacheException>(target, 'TomCacheException').stack = D4.extractBridgedArgOrNull<Object>(value, 'stack'),
      'rootException': (visitor, target, value) => 
        D4.validateTarget<TomCacheException>(target, 'TomCacheException').rootException = D4.extractBridgedArgOrNull<Object>(value, 'rootException'),
      'stackTrace': (visitor, target, value) => 
        D4.validateTarget<TomCacheException>(target, 'TomCacheException').stackTrace = D4.extractBridgedArg<String>(value, 'stackTrace'),
    },
    methods: {
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomCacheException>(target, 'TomCacheException');
        return t.toString();
      },
      'printStackTrace': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomCacheException>(target, 'TomCacheException');
        final depth = D4.getOptionalArgWithDefault<int>(positional, 0, 'depth', -1);
        t.printStackTrace(depth);
        return null;
      },
    },
    constructorSignatures: {
      '': 'TomCacheException(String key, String userMessage, {Map<String, Object?>? parameters, Object? stack, Object? rootException, bool autoLog = false})',
    },
    methodSignatures: {
      'toString': 'String toString()',
      'printStackTrace': 'void printStackTrace([int depth = -1])',
    },
    getterSignatures: {
      'isolateName': 'String get isolateName',
      'clientThrow': 'bool get clientThrow',
      'autoLog': 'bool get autoLog',
      'serverCallError': 'TomServerCallError? get serverCallError',
      'newField': 'String? get newField',
      'logRepresentation': 'String get logRepresentation',
      'uuid': 'String get uuid',
      'requestUuid': 'String? get requestUuid',
      'timeStamp': 'DateTime get timeStamp',
      'key': 'String get key',
      'defaultUserMessage': 'String get defaultUserMessage',
      'parameters': 'Map<String, Object?>? get parameters',
      'stack': 'Object? get stack',
      'rootException': 'Object? get rootException',
      'stackTrace': 'String get stackTrace',
    },
    setterSignatures: {
      'isolateName': 'set isolateName(String value)',
      'clientThrow': 'set clientThrow(bool value)',
      'autoLog': 'set autoLog(bool value)',
      'serverCallError': 'set serverCallError(TomServerCallError? value)',
      'newField': 'set newField(String? value)',
      'uuid': 'set uuid(String value)',
      'requestUuid': 'set requestUuid(String? value)',
      'timeStamp': 'set timeStamp(DateTime value)',
      'key': 'set key(String value)',
      'defaultUserMessage': 'set defaultUserMessage(String value)',
      'parameters': 'set parameters(Map<String, Object?>? value)',
      'stack': 'set stack(Object? value)',
      'rootException': 'set rootException(Object? value)',
      'stackTrace': 'set stackTrace(String value)',
    },
  );
}

// =============================================================================
// TomCacheEntry Bridge
// =============================================================================

BridgedClass _createTomCacheEntryBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_2.TomCacheEntry,
    name: 'TomCacheEntry',
    isAssignable: (v) => v is $tom_core_server_2.TomCacheEntry,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomCacheEntry');
        final value = D4.getRequiredArg<Object?>(positional, 0, 'value', 'TomCacheEntry');
        final deletionTime = D4.getOptionalArg<DateTime?>(positional, 1, 'deletionTime');
        return $tom_core_server_2.TomCacheEntry(value, deletionTime);
      },
    },
    getters: {
      'deletionTime': (visitor, target) => D4.validateTarget<$tom_core_server_2.TomCacheEntry>(target, 'TomCacheEntry').deletionTime,
      'value': (visitor, target) => D4.validateTarget<$tom_core_server_2.TomCacheEntry>(target, 'TomCacheEntry').value,
    },
    setters: {
      'deletionTime': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_2.TomCacheEntry>(target, 'TomCacheEntry').deletionTime = D4.extractBridgedArgOrNull<DateTime>(value, 'deletionTime'),
      'value': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_2.TomCacheEntry>(target, 'TomCacheEntry').value = D4.extractBridgedArgOrNull<Object>(value, 'value'),
    },
    constructorSignatures: {
      '': 'TomCacheEntry(Object? value, [DateTime? deletionTime])',
    },
    getterSignatures: {
      'deletionTime': 'DateTime? get deletionTime',
      'value': 'Object? get value',
    },
    setterSignatures: {
      'deletionTime': 'set deletionTime(dynamic value)',
      'value': 'set value(dynamic value)',
    },
  );
}

// =============================================================================
// TomCacheManager Bridge
// =============================================================================

BridgedClass _createTomCacheManagerBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_2.TomCacheManager,
    name: 'TomCacheManager',
    isAssignable: (v) => v is $tom_core_server_2.TomCacheManager,
    constructors: {
      '': (visitor, positional, named) {
        final useInThisIsolate = D4.getOptionalArgWithDefault<bool>(positional, 0, 'useInThisIsolate', false);
        return $tom_core_server_2.TomCacheManager(useInThisIsolate);
      },
    },
    getters: {
      'useInThisIsolate': (visitor, target) => D4.validateTarget<$tom_core_server_2.TomCacheManager>(target, 'TomCacheManager').useInThisIsolate,
    },
    setters: {
      'useInThisIsolate': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_2.TomCacheManager>(target, 'TomCacheManager').useInThisIsolate = D4.extractBridgedArg<bool>(value, 'useInThisIsolate'),
    },
    staticMethods: {
      'setCurrent': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'setCurrent');
        final manager = D4.getRequiredArg<$tom_core_server_2.TomCacheManager>(positional, 0, 'manager', 'setCurrent');
        return $tom_core_server_2.TomCacheManager.setCurrent(manager);
      },
      'getCache': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'getCache');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'getCache');
        return $tom_core_server_2.TomCacheManager.getCache(name);
      },
      'addCache': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'addCache');
        final cache = D4.getRequiredArg<$tom_core_server_2.TomCache>(positional, 0, 'cache', 'addCache');
        return $tom_core_server_2.TomCacheManager.addCache(cache);
      },
    },
    constructorSignatures: {
      '': 'TomCacheManager([bool useInThisIsolate = false])',
    },
    getterSignatures: {
      'useInThisIsolate': 'bool get useInThisIsolate',
    },
    setterSignatures: {
      'useInThisIsolate': 'set useInThisIsolate(dynamic value)',
    },
    staticMethodSignatures: {
      'setCurrent': 'TomCacheManager setCurrent(TomCacheManager manager)',
      'getCache': 'TomCache? getCache(String name)',
      'addCache': 'void addCache(TomCache cache)',
    },
  );
}

// =============================================================================
// TomCache Bridge
// =============================================================================

BridgedClass _createTomCacheBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_2.TomCache,
    name: 'TomCache',
    isAssignable: (v) => v is $tom_core_server_2.TomCache,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomCache');
        final cacheName = D4.getRequiredArg<String>(positional, 0, 'cacheName', 'TomCache');
        final deleteEntriesAfterSeconds = D4.getOptionalNamedArg<int?>(named, 'deleteEntriesAfterSeconds');
        final deletionIntervalSeconds = D4.getNamedArgWithDefault<int?>(named, 'deletionIntervalSeconds', 3600);
        final maximumEntries = D4.getOptionalNamedArg<int?>(named, 'maximumEntries');
        final clearIntervalSeconds = D4.getOptionalNamedArg<int?>(named, 'clearIntervalSeconds');
        return $tom_core_server_2.TomCache(cacheName, deleteEntriesAfterSeconds: deleteEntriesAfterSeconds, deletionIntervalSeconds: deletionIntervalSeconds, maximumEntries: maximumEntries, clearIntervalSeconds: clearIntervalSeconds);
      },
      'forType': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomCache');
        final type = D4.getRequiredArg<Type>(positional, 0, 'type', 'TomCache');
        final deleteEntriesAfterSeconds = D4.getOptionalNamedArg<int?>(named, 'deleteEntriesAfterSeconds');
        final deletionIntervalSeconds = D4.getNamedArgWithDefault<int?>(named, 'deletionIntervalSeconds', 3600);
        final maximumEntries = D4.getOptionalNamedArg<int?>(named, 'maximumEntries');
        final clearIntervalSeconds = D4.getOptionalNamedArg<int?>(named, 'clearIntervalSeconds');
        return $tom_core_server_2.TomCache.forType(type, deleteEntriesAfterSeconds: deleteEntriesAfterSeconds, deletionIntervalSeconds: deletionIntervalSeconds, maximumEntries: maximumEntries, clearIntervalSeconds: clearIntervalSeconds);
      },
    },
    getters: {
      'cacheName': (visitor, target) => D4.validateTarget<$tom_core_server_2.TomCache>(target, 'TomCache').cacheName,
      'deletionIntervalSeconds': (visitor, target) => D4.validateTarget<$tom_core_server_2.TomCache>(target, 'TomCache').deletionIntervalSeconds,
      'deleteEntriesAfterSeconds': (visitor, target) => D4.validateTarget<$tom_core_server_2.TomCache>(target, 'TomCache').deleteEntriesAfterSeconds,
      'clearIntervalSeconds': (visitor, target) => D4.validateTarget<$tom_core_server_2.TomCache>(target, 'TomCache').clearIntervalSeconds,
      'maximumEntries': (visitor, target) => D4.validateTarget<$tom_core_server_2.TomCache>(target, 'TomCache').maximumEntries,
      'deletionTimer': (visitor, target) => D4.validateTarget<$tom_core_server_2.TomCache>(target, 'TomCache').deletionTimer,
      'clearanceTimer': (visitor, target) => D4.validateTarget<$tom_core_server_2.TomCache>(target, 'TomCache').clearanceTimer,
    },
    setters: {
      'deletionTimer': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_2.TomCache>(target, 'TomCache').deletionTimer = D4.extractBridgedArgOrNull<Timer>(value, 'deletionTimer'),
      'clearanceTimer': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_2.TomCache>(target, 'TomCache').clearanceTimer = D4.extractBridgedArgOrNull<Timer>(value, 'clearanceTimer'),
    },
    methods: {
      'removeEntry': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_2.TomCache>(target, 'TomCache');
        D4.requireMinArgs(positional, 1, 'removeEntry');
        final key = D4.getRequiredArg<String>(positional, 0, 'key', 'removeEntry');
        t.removeEntry(key);
        return null;
      },
      'getEntry': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_2.TomCache>(target, 'TomCache');
        D4.requireMinArgs(positional, 1, 'getEntry');
        final key = D4.getRequiredArg<String>(positional, 0, 'key', 'getEntry');
        return t.getEntry(key);
      },
      'putEntry': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_2.TomCache>(target, 'TomCache');
        D4.requireMinArgs(positional, 2, 'putEntry');
        final key = D4.getRequiredArg<String>(positional, 0, 'key', 'putEntry');
        final entry = D4.getRequiredArg<$tom_core_server_2.TomCacheEntry>(positional, 1, 'entry', 'putEntry');
        t.putEntry(key, entry);
        return null;
      },
      'createTimers': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_2.TomCache>(target, 'TomCache');
        t.createTimers();
        return null;
      },
      'stopTimers': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_2.TomCache>(target, 'TomCache');
        t.stopTimers();
        return null;
      },
      'createDeletionTimer': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_2.TomCache>(target, 'TomCache');
        return t.createDeletionTimer();
      },
      'createClearanceTimer': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_2.TomCache>(target, 'TomCache');
        return t.createClearanceTimer();
      },
    },
    staticMethods: {
      'fromTypeCache': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'fromTypeCache');
        final key = D4.getRequiredArg<String>(positional, 0, 'key', 'fromTypeCache');
        return $tom_core_server_2.TomCache.fromTypeCache(key);
      },
      'fromNameCache': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'fromNameCache');
        final cacheName = D4.getRequiredArg<String>(positional, 0, 'cacheName', 'fromNameCache');
        final key = D4.getRequiredArg<String>(positional, 1, 'key', 'fromNameCache');
        return $tom_core_server_2.TomCache.fromNameCache(cacheName, key);
      },
      'toTypeCache': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'toTypeCache');
        final key = D4.getRequiredArg<String>(positional, 0, 'key', 'toTypeCache');
        final value = D4.getRequiredArg<Object?>(positional, 1, 'value', 'toTypeCache');
        return $tom_core_server_2.TomCache.toTypeCache(key, value);
      },
      'toNameCache': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 3, 'toNameCache');
        final cacheName = D4.getRequiredArg<String>(positional, 0, 'cacheName', 'toNameCache');
        final key = D4.getRequiredArg<String>(positional, 1, 'key', 'toNameCache');
        final value = D4.getRequiredArg<Object?>(positional, 2, 'value', 'toNameCache');
        final deletionTime = D4.getOptionalArg<DateTime?>(positional, 3, 'deletionTime');
        return $tom_core_server_2.TomCache.toNameCache(cacheName, key, value, deletionTime);
      },
      'removeFromTypeCache': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'removeFromTypeCache');
        final key = D4.getRequiredArg<String>(positional, 0, 'key', 'removeFromTypeCache');
        return $tom_core_server_2.TomCache.removeFromTypeCache(key);
      },
      'removeFromNameCache': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'removeFromNameCache');
        final cacheName = D4.getRequiredArg<String>(positional, 0, 'cacheName', 'removeFromNameCache');
        final key = D4.getRequiredArg<String>(positional, 1, 'key', 'removeFromNameCache');
        return $tom_core_server_2.TomCache.removeFromNameCache(cacheName, key);
      },
    },
    constructorSignatures: {
      '': 'TomCache(String cacheName, {int? deleteEntriesAfterSeconds, int? deletionIntervalSeconds = 3600, int? maximumEntries, int? clearIntervalSeconds})',
      'forType': 'factory TomCache.forType(Type type, {int? deleteEntriesAfterSeconds, int? deletionIntervalSeconds = 3600, int? maximumEntries, int? clearIntervalSeconds})',
    },
    methodSignatures: {
      'removeEntry': 'void removeEntry(String key)',
      'getEntry': 'TomCacheEntry? getEntry(String key)',
      'putEntry': 'void putEntry(String key, TomCacheEntry entry)',
      'createTimers': 'void createTimers()',
      'stopTimers': 'void stopTimers()',
      'createDeletionTimer': 'Timer createDeletionTimer()',
      'createClearanceTimer': 'Timer createClearanceTimer()',
    },
    getterSignatures: {
      'cacheName': 'String get cacheName',
      'deletionIntervalSeconds': 'int? get deletionIntervalSeconds',
      'deleteEntriesAfterSeconds': 'int? get deleteEntriesAfterSeconds',
      'clearIntervalSeconds': 'int? get clearIntervalSeconds',
      'maximumEntries': 'int? get maximumEntries',
      'deletionTimer': 'Timer? get deletionTimer',
      'clearanceTimer': 'Timer? get clearanceTimer',
    },
    setterSignatures: {
      'deletionTimer': 'set deletionTimer(dynamic value)',
      'clearanceTimer': 'set clearanceTimer(dynamic value)',
    },
    staticMethodSignatures: {
      'fromTypeCache': 'Future<T?> fromTypeCache(String key)',
      'fromNameCache': 'Future<T?> fromNameCache(String cacheName, String key)',
      'toTypeCache': 'Future<int> toTypeCache(String key, Object? value)',
      'toNameCache': 'Future<int> toNameCache(String cacheName, String key, Object? value, [DateTime? deletionTime])',
      'removeFromTypeCache': 'Future<int> removeFromTypeCache(String key)',
      'removeFromNameCache': 'Future<int> removeFromNameCache(String cacheName, String key)',
    },
  );
}

// =============================================================================
// TomCacheStoreMessage Bridge
// =============================================================================

BridgedClass _createTomCacheStoreMessageBridge() {
  return BridgedClass(
    nativeType: TomCacheStoreMessage,
    name: 'TomCacheStoreMessage',
    isAssignable: (v) => v is TomCacheStoreMessage,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 4, 'TomCacheStoreMessage');
        final cacheName = D4.getRequiredArg<String>(positional, 0, 'cacheName', 'TomCacheStoreMessage');
        final key = D4.getRequiredArg<String>(positional, 1, 'key', 'TomCacheStoreMessage');
        final value = D4.getRequiredArg<Object?>(positional, 2, 'value', 'TomCacheStoreMessage');
        final deletionTime = D4.getRequiredArg<DateTime?>(positional, 3, 'deletionTime', 'TomCacheStoreMessage');
        return TomCacheStoreMessage(cacheName, key, value, deletionTime);
      },
    },
    getters: {
      'cacheName': (visitor, target) => D4.validateTarget<TomCacheStoreMessage>(target, 'TomCacheStoreMessage').cacheName,
      'key': (visitor, target) => D4.validateTarget<TomCacheStoreMessage>(target, 'TomCacheStoreMessage').key,
      'value': (visitor, target) => D4.validateTarget<TomCacheStoreMessage>(target, 'TomCacheStoreMessage').value,
      'deletionTime': (visitor, target) => D4.validateTarget<TomCacheStoreMessage>(target, 'TomCacheStoreMessage').deletionTime,
    },
    setters: {
      'cacheName': (visitor, target, value) => 
        D4.validateTarget<TomCacheStoreMessage>(target, 'TomCacheStoreMessage').cacheName = D4.extractBridgedArg<String>(value, 'cacheName'),
      'key': (visitor, target, value) => 
        D4.validateTarget<TomCacheStoreMessage>(target, 'TomCacheStoreMessage').key = D4.extractBridgedArg<String>(value, 'key'),
      'value': (visitor, target, value) => 
        D4.validateTarget<TomCacheStoreMessage>(target, 'TomCacheStoreMessage').value = D4.extractBridgedArgOrNull<Object>(value, 'value'),
      'deletionTime': (visitor, target, value) => 
        D4.validateTarget<TomCacheStoreMessage>(target, 'TomCacheStoreMessage').deletionTime = D4.extractBridgedArgOrNull<DateTime>(value, 'deletionTime'),
    },
    methods: {
      'execute': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomCacheStoreMessage>(target, 'TomCacheStoreMessage');
        return t.execute();
      },
    },
    constructorSignatures: {
      '': 'TomCacheStoreMessage(String cacheName, String key, Object? value, DateTime? deletionTime)',
    },
    methodSignatures: {
      'execute': 'Future<bool> execute()',
    },
    getterSignatures: {
      'cacheName': 'String get cacheName',
      'key': 'String get key',
      'value': 'Object? get value',
      'deletionTime': 'DateTime? get deletionTime',
    },
    setterSignatures: {
      'cacheName': 'set cacheName(dynamic value)',
      'key': 'set key(dynamic value)',
      'value': 'set value(dynamic value)',
      'deletionTime': 'set deletionTime(dynamic value)',
    },
  );
}

// =============================================================================
// TomCacheRemoveMessage Bridge
// =============================================================================

BridgedClass _createTomCacheRemoveMessageBridge() {
  return BridgedClass(
    nativeType: TomCacheRemoveMessage,
    name: 'TomCacheRemoveMessage',
    isAssignable: (v) => v is TomCacheRemoveMessage,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'TomCacheRemoveMessage');
        final cacheName = D4.getRequiredArg<String>(positional, 0, 'cacheName', 'TomCacheRemoveMessage');
        final key = D4.getRequiredArg<String>(positional, 1, 'key', 'TomCacheRemoveMessage');
        return TomCacheRemoveMessage(cacheName, key);
      },
    },
    getters: {
      'cacheName': (visitor, target) => D4.validateTarget<TomCacheRemoveMessage>(target, 'TomCacheRemoveMessage').cacheName,
      'key': (visitor, target) => D4.validateTarget<TomCacheRemoveMessage>(target, 'TomCacheRemoveMessage').key,
    },
    setters: {
      'cacheName': (visitor, target, value) => 
        D4.validateTarget<TomCacheRemoveMessage>(target, 'TomCacheRemoveMessage').cacheName = D4.extractBridgedArg<String>(value, 'cacheName'),
      'key': (visitor, target, value) => 
        D4.validateTarget<TomCacheRemoveMessage>(target, 'TomCacheRemoveMessage').key = D4.extractBridgedArg<String>(value, 'key'),
    },
    methods: {
      'execute': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomCacheRemoveMessage>(target, 'TomCacheRemoveMessage');
        return t.execute();
      },
    },
    constructorSignatures: {
      '': 'TomCacheRemoveMessage(String cacheName, String key)',
    },
    methodSignatures: {
      'execute': 'Future<bool> execute()',
    },
    getterSignatures: {
      'cacheName': 'String get cacheName',
      'key': 'String get key',
    },
    setterSignatures: {
      'cacheName': 'set cacheName(dynamic value)',
      'key': 'set key(dynamic value)',
    },
  );
}

// =============================================================================
// TomCacheRetrieveMessage Bridge
// =============================================================================

BridgedClass _createTomCacheRetrieveMessageBridge() {
  return BridgedClass(
    nativeType: TomCacheRetrieveMessage,
    name: 'TomCacheRetrieveMessage',
    isAssignable: (v) => v is TomCacheRetrieveMessage,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'TomCacheRetrieveMessage');
        final cacheName = D4.getRequiredArg<String>(positional, 0, 'cacheName', 'TomCacheRetrieveMessage');
        final key = D4.getRequiredArg<String>(positional, 1, 'key', 'TomCacheRetrieveMessage');
        return TomCacheRetrieveMessage(cacheName, key);
      },
    },
    getters: {
      'cacheName': (visitor, target) => D4.validateTarget<TomCacheRetrieveMessage>(target, 'TomCacheRetrieveMessage').cacheName,
      'key': (visitor, target) => D4.validateTarget<TomCacheRetrieveMessage>(target, 'TomCacheRetrieveMessage').key,
    },
    setters: {
      'cacheName': (visitor, target, value) => 
        D4.validateTarget<TomCacheRetrieveMessage>(target, 'TomCacheRetrieveMessage').cacheName = D4.extractBridgedArg<String>(value, 'cacheName'),
      'key': (visitor, target, value) => 
        D4.validateTarget<TomCacheRetrieveMessage>(target, 'TomCacheRetrieveMessage').key = D4.extractBridgedArg<String>(value, 'key'),
    },
    methods: {
      'execute': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomCacheRetrieveMessage>(target, 'TomCacheRetrieveMessage');
        return t.execute();
      },
    },
    constructorSignatures: {
      '': 'TomCacheRetrieveMessage(String cacheName, String key)',
    },
    methodSignatures: {
      'execute': 'Future<Object?> execute()',
    },
    getterSignatures: {
      'cacheName': 'String get cacheName',
      'key': 'String get key',
    },
    setterSignatures: {
      'cacheName': 'set cacheName(dynamic value)',
      'key': 'set key(dynamic value)',
    },
  );
}

// =============================================================================
// TomDatasourceInitException Bridge
// =============================================================================

BridgedClass _createTomDatasourceInitExceptionBridge() {
  return BridgedClass(
    nativeType: TomDatasourceInitException,
    name: 'TomDatasourceInitException',
    isAssignable: (v) => v is TomDatasourceInitException,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'TomDatasourceInitException');
        final key = D4.getRequiredArg<String>(positional, 0, 'key', 'TomDatasourceInitException');
        final defaultUserMessage = D4.getRequiredArg<String>(positional, 1, 'defaultUserMessage', 'TomDatasourceInitException');
        final parameters = D4.coerceMapOrNull<String, Object?>(named['parameters'], 'parameters');
        final stack = D4.getOptionalNamedArg<Object?>(named, 'stack');
        final rootException = D4.getOptionalNamedArg<Object?>(named, 'rootException');
        final autoLog = D4.getNamedArgWithDefault<bool>(named, 'autoLog', false);
        final uuid = D4.getOptionalNamedArg<String?>(named, 'uuid');
        final serverCallError = D4.getOptionalNamedArg<$tom_core_kernel_4.TomServerCallError?>(named, 'serverCallError');
        return TomDatasourceInitException(key, defaultUserMessage, parameters: parameters, stack: stack, rootException: rootException, autoLog: autoLog, uuid: uuid, serverCallError: serverCallError);
      },
    },
    getters: {
      'autoLog': (visitor, target) => D4.validateTarget<TomDatasourceInitException>(target, 'TomDatasourceInitException').autoLog,
      'serverCallError': (visitor, target) => D4.validateTarget<TomDatasourceInitException>(target, 'TomDatasourceInitException').serverCallError,
      'newField': (visitor, target) => D4.validateTarget<TomDatasourceInitException>(target, 'TomDatasourceInitException').newField,
      'logRepresentation': (visitor, target) => D4.validateTarget<TomDatasourceInitException>(target, 'TomDatasourceInitException').logRepresentation,
      'uuid': (visitor, target) => D4.validateTarget<TomDatasourceInitException>(target, 'TomDatasourceInitException').uuid,
      'requestUuid': (visitor, target) => D4.validateTarget<TomDatasourceInitException>(target, 'TomDatasourceInitException').requestUuid,
      'timeStamp': (visitor, target) => D4.validateTarget<TomDatasourceInitException>(target, 'TomDatasourceInitException').timeStamp,
      'key': (visitor, target) => D4.validateTarget<TomDatasourceInitException>(target, 'TomDatasourceInitException').key,
      'defaultUserMessage': (visitor, target) => D4.validateTarget<TomDatasourceInitException>(target, 'TomDatasourceInitException').defaultUserMessage,
      'parameters': (visitor, target) => D4.validateTarget<TomDatasourceInitException>(target, 'TomDatasourceInitException').parameters,
      'stack': (visitor, target) => D4.validateTarget<TomDatasourceInitException>(target, 'TomDatasourceInitException').stack,
      'rootException': (visitor, target) => D4.validateTarget<TomDatasourceInitException>(target, 'TomDatasourceInitException').rootException,
      'stackTrace': (visitor, target) => D4.validateTarget<TomDatasourceInitException>(target, 'TomDatasourceInitException').stackTrace,
    },
    setters: {
      'autoLog': (visitor, target, value) => 
        D4.validateTarget<TomDatasourceInitException>(target, 'TomDatasourceInitException').autoLog = D4.extractBridgedArg<bool>(value, 'autoLog'),
      'serverCallError': (visitor, target, value) => 
        D4.validateTarget<TomDatasourceInitException>(target, 'TomDatasourceInitException').serverCallError = D4.extractBridgedArgOrNull<$tom_core_kernel_4.TomServerCallError>(value, 'serverCallError'),
      'newField': (visitor, target, value) => 
        D4.validateTarget<TomDatasourceInitException>(target, 'TomDatasourceInitException').newField = D4.extractBridgedArgOrNull<String>(value, 'newField'),
      'uuid': (visitor, target, value) => 
        D4.validateTarget<TomDatasourceInitException>(target, 'TomDatasourceInitException').uuid = D4.extractBridgedArg<String>(value, 'uuid'),
      'requestUuid': (visitor, target, value) => 
        D4.validateTarget<TomDatasourceInitException>(target, 'TomDatasourceInitException').requestUuid = D4.extractBridgedArgOrNull<String>(value, 'requestUuid'),
      'timeStamp': (visitor, target, value) => 
        D4.validateTarget<TomDatasourceInitException>(target, 'TomDatasourceInitException').timeStamp = D4.extractBridgedArg<DateTime>(value, 'timeStamp'),
      'key': (visitor, target, value) => 
        D4.validateTarget<TomDatasourceInitException>(target, 'TomDatasourceInitException').key = D4.extractBridgedArg<String>(value, 'key'),
      'defaultUserMessage': (visitor, target, value) => 
        D4.validateTarget<TomDatasourceInitException>(target, 'TomDatasourceInitException').defaultUserMessage = D4.extractBridgedArg<String>(value, 'defaultUserMessage'),
      'stack': (visitor, target, value) => 
        D4.validateTarget<TomDatasourceInitException>(target, 'TomDatasourceInitException').stack = D4.extractBridgedArgOrNull<Object>(value, 'stack'),
      'rootException': (visitor, target, value) => 
        D4.validateTarget<TomDatasourceInitException>(target, 'TomDatasourceInitException').rootException = D4.extractBridgedArgOrNull<Object>(value, 'rootException'),
      'stackTrace': (visitor, target, value) => 
        D4.validateTarget<TomDatasourceInitException>(target, 'TomDatasourceInitException').stackTrace = D4.extractBridgedArg<String>(value, 'stackTrace'),
    },
    methods: {
      'printStackTrace': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomDatasourceInitException>(target, 'TomDatasourceInitException');
        final depth = D4.getOptionalArgWithDefault<int>(positional, 0, 'depth', -1);
        t.printStackTrace(depth);
        return null;
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomDatasourceInitException>(target, 'TomDatasourceInitException');
        return t.toString();
      },
    },
    constructorSignatures: {
      '': 'TomDatasourceInitException(String key, String defaultUserMessage, {Map<String, Object?>? parameters, Object? stack, Object? rootException, bool autoLog = false, String? uuid, TomServerCallError? serverCallError})',
    },
    methodSignatures: {
      'printStackTrace': 'void printStackTrace([int depth = -1])',
      'toString': 'String toString()',
    },
    getterSignatures: {
      'autoLog': 'bool get autoLog',
      'serverCallError': 'TomServerCallError? get serverCallError',
      'newField': 'String? get newField',
      'logRepresentation': 'String get logRepresentation',
      'uuid': 'String get uuid',
      'requestUuid': 'String? get requestUuid',
      'timeStamp': 'DateTime get timeStamp',
      'key': 'String get key',
      'defaultUserMessage': 'String get defaultUserMessage',
      'parameters': 'Map<String, Object?>? get parameters',
      'stack': 'Object? get stack',
      'rootException': 'Object? get rootException',
      'stackTrace': 'String get stackTrace',
    },
    setterSignatures: {
      'autoLog': 'set autoLog(bool value)',
      'serverCallError': 'set serverCallError(TomServerCallError? value)',
      'newField': 'set newField(String? value)',
      'uuid': 'set uuid(String value)',
      'requestUuid': 'set requestUuid(String? value)',
      'timeStamp': 'set timeStamp(DateTime value)',
      'key': 'set key(String value)',
      'defaultUserMessage': 'set defaultUserMessage(String value)',
      'parameters': 'set parameters(Map<String, Object?>? value)',
      'stack': 'set stack(Object? value)',
      'rootException': 'set rootException(Object? value)',
      'stackTrace': 'set stackTrace(String value)',
    },
  );
}

// =============================================================================
// TomDatasourceDriver Bridge
// =============================================================================

BridgedClass _createTomDatasourceDriverBridge() {
  return BridgedClass(
    nativeType: TomDatasourceDriver,
    name: 'TomDatasourceDriver',
    isAssignable: (v) => v is TomDatasourceDriver,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomDatasourceDriver');
        final type = D4.getRequiredArg<String>(positional, 0, 'type', 'TomDatasourceDriver');
        return TomDatasourceDriver(type);
      },
    },
    getters: {
      'type': (visitor, target) => D4.validateTarget<TomDatasourceDriver>(target, 'TomDatasourceDriver').type,
    },
    constructorSignatures: {
      '': 'const TomDatasourceDriver(String type)',
    },
    getterSignatures: {
      'type': 'String get type',
    },
  );
}

// =============================================================================
// TomPreparedStatement Bridge
// =============================================================================

BridgedClass _createTomPreparedStatementBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_4.TomPreparedStatement,
    name: 'TomPreparedStatement',
    isAssignable: (v) => v is $tom_core_server_4.TomPreparedStatement,
    constructors: {
    },
    methods: {
      'execute': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_4.TomPreparedStatement>(target, 'TomPreparedStatement');
        final params = positional.isNotEmpty
            ? D4.coerceMapOrNull<String, Object?>(positional[0], 'params')
            : null;
        return t.execute(params);
      },
      'deallocate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_4.TomPreparedStatement>(target, 'TomPreparedStatement');
        return t.deallocate();
      },
    },
    methodSignatures: {
      'execute': 'Future<List<T>> execute([Map<String, Object?>? params])',
      'deallocate': 'Future<void> deallocate()',
    },
  );
}

// =============================================================================
// TomDataSource Bridge
// =============================================================================

BridgedClass _createTomDataSourceBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_4.TomDataSource,
    name: 'TomDataSource',
    isAssignable: (v) => v is $tom_core_server_4.TomDataSource,
    constructors: {
    },
    getters: {
      'sqlDialect': (visitor, target) => D4.validateTarget<$tom_core_server_4.TomDataSource>(target, 'TomDataSource').sqlDialect,
    },
    methods: {
      'initialize': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_4.TomDataSource>(target, 'TomDataSource');
        D4.requireMinArgs(positional, 1, 'initialize');
        if (positional.isEmpty) {
          throw ArgumentError('initialize: Missing required argument "settings" at position 0');
        }
        final settings = D4.coerceMap<String, dynamic>(positional[0], 'settings');
        return t.initialize(settings);
      },
      'close': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_4.TomDataSource>(target, 'TomDataSource');
        return t.close();
      },
      'isOperational': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_4.TomDataSource>(target, 'TomDataSource');
        return t.isOperational();
      },
      'prepareStatement': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_4.TomDataSource>(target, 'TomDataSource');
        D4.requireMinArgs(positional, 1, 'prepareStatement');
        final query = D4.getRequiredArg<$tom_core_server_6.TomQuery>(positional, 0, 'query', 'prepareStatement');
        final resultType = D4.getOptionalArg<Type?>(positional, 1, 'resultType');
        return t.prepareStatement(query, resultType);
      },
      'executeCommand': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_4.TomDataSource>(target, 'TomDataSource');
        D4.requireMinArgs(positional, 1, 'executeCommand');
        final command = D4.getRequiredArg<String>(positional, 0, 'command', 'executeCommand');
        final params = positional.length > 1
            ? D4.coerceMapOrNull<String, dynamic>(positional[1], 'params')
            : null;
        return t.executeCommand(command, params);
      },
      'executeQuery': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_4.TomDataSource>(target, 'TomDataSource');
        D4.requireMinArgs(positional, 1, 'executeQuery');
        final command = D4.getRequiredArg<String>(positional, 0, 'command', 'executeQuery');
        final params = positional.length > 1
            ? D4.coerceMapOrNull<String, dynamic>(positional[1], 'params')
            : null;
        final resultType = D4.getOptionalArg<Type?>(positional, 2, 'resultType');
        return t.executeQuery(command, params, resultType);
      },
      'getParticipantId': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_4.TomDataSource>(target, 'TomDataSource');
        return t.getParticipantId();
      },
      'startTransaction': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_4.TomDataSource>(target, 'TomDataSource');
        return t.startTransaction();
      },
      'endTransaction': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_4.TomDataSource>(target, 'TomDataSource');
        return t.endTransaction();
      },
      'commit': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_4.TomDataSource>(target, 'TomDataSource');
        return t.commit();
      },
      'rollback': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_4.TomDataSource>(target, 'TomDataSource');
        return t.rollback();
      },
    },
    staticMethods: {
      'createDatasourceOf': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'createDatasourceOf');
        final type = D4.getRequiredArg<String>(positional, 0, 'type', 'createDatasourceOf');
        return $tom_core_server_4.TomDataSource.createDatasourceOf(type);
      },
    },
    methodSignatures: {
      'initialize': 'Future<void> initialize(Map<String, dynamic> settings)',
      'close': 'Future<void> close()',
      'isOperational': 'bool isOperational()',
      'prepareStatement': 'Future<TomPreparedStatement<T>> prepareStatement(TomQuery query, [Type? resultType])',
      'executeCommand': 'Future<BigInt> executeCommand(String command, [Map<String, dynamic>? params])',
      'executeQuery': 'Future<List<T>> executeQuery(String command, [Map<String, dynamic>? params, Type? resultType])',
      'getParticipantId': 'String getParticipantId()',
      'startTransaction': 'Future<bool> startTransaction()',
      'endTransaction': 'Future<bool> endTransaction()',
      'commit': 'Future<bool> commit()',
      'rollback': 'Future<void> rollback()',
    },
    getterSignatures: {
      'sqlDialect': 'TomStandardSqlDialect get sqlDialect',
    },
    staticMethodSignatures: {
      'createDatasourceOf': 'TomDataSource? createDatasourceOf(String type)',
    },
  );
}

// =============================================================================
// TomDataSourceInfo Bridge
// =============================================================================

BridgedClass _createTomDataSourceInfoBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_4.TomDataSourceInfo,
    name: 'TomDataSourceInfo',
    isAssignable: (v) => v is $tom_core_server_4.TomDataSourceInfo,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'TomDataSourceInfo');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'TomDataSourceInfo');
        if (positional.length <= 1) {
          throw ArgumentError('TomDataSourceInfo: Missing required argument "settings" at position 1');
        }
        final settings = D4.coerceMap<String, dynamic>(positional[1], 'settings');
        return $tom_core_server_4.TomDataSourceInfo(name, settings);
      },
    },
    getters: {
      'name': (visitor, target) => D4.validateTarget<$tom_core_server_4.TomDataSourceInfo>(target, 'TomDataSourceInfo').name,
      'type': (visitor, target) => D4.validateTarget<$tom_core_server_4.TomDataSourceInfo>(target, 'TomDataSourceInfo').type,
      'settings': (visitor, target) => D4.validateTarget<$tom_core_server_4.TomDataSourceInfo>(target, 'TomDataSourceInfo').settings,
      'isOperational': (visitor, target) => D4.validateTarget<$tom_core_server_4.TomDataSourceInfo>(target, 'TomDataSourceInfo').isOperational,
      'datasource': (visitor, target) => D4.validateTarget<$tom_core_server_4.TomDataSourceInfo>(target, 'TomDataSourceInfo').datasource,
    },
    setters: {
      'name': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_4.TomDataSourceInfo>(target, 'TomDataSourceInfo').name = D4.extractBridgedArg<String>(value, 'name'),
      'type': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_4.TomDataSourceInfo>(target, 'TomDataSourceInfo').type = D4.extractBridgedArg<String>(value, 'type'),
    },
    methods: {
      'initialize': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_4.TomDataSourceInfo>(target, 'TomDataSourceInfo');
        return t.initialize();
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_4.TomDataSourceInfo>(target, 'TomDataSourceInfo');
        return t.toString();
      },
    },
    staticGetters: {
      'datasources': (visitor) => $tom_core_server_4.TomDataSourceInfo.datasources,
    },
    staticMethods: {
      'getDataSourceInfo': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'getDataSourceInfo');
        final dsName = D4.getRequiredArg<String>(positional, 0, 'dsName', 'getDataSourceInfo');
        return $tom_core_server_4.TomDataSourceInfo.getDataSourceInfo(dsName);
      },
      'initializeDatasourceInfo': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'initializeDatasourceInfo');
        if (positional.isEmpty) {
          throw ArgumentError('initializeDatasourceInfo: Missing required argument "datasourceConfiguration" at position 0');
        }
        final datasourceConfiguration = D4.coerceMap<String, dynamic>(positional[0], 'datasourceConfiguration');
        return $tom_core_server_4.TomDataSourceInfo.initializeDatasourceInfo(datasourceConfiguration);
      },
      'closeAll': (visitor, positional, named, typeArgs) {
        return $tom_core_server_4.TomDataSourceInfo.closeAll();
      },
    },
    staticSetters: {
      'datasources': (visitor, value) => 
        $tom_core_server_4.TomDataSourceInfo.datasources = (value as Map).cast<String, $tom_core_server_4.TomDataSourceInfo>(),
    },
    constructorSignatures: {
      '': 'TomDataSourceInfo(String name, Map<String, dynamic> settings)',
    },
    methodSignatures: {
      'initialize': 'Future<void> initialize()',
      'toString': 'String toString()',
    },
    getterSignatures: {
      'name': 'String get name',
      'type': 'String get type',
      'settings': 'Map<String, dynamic> get settings',
      'isOperational': 'bool get isOperational',
      'datasource': 'TomDataSource get datasource',
    },
    setterSignatures: {
      'name': 'set name(dynamic value)',
      'type': 'set type(dynamic value)',
      'settings': 'set settings(dynamic value)',
    },
    staticMethodSignatures: {
      'getDataSourceInfo': 'TomDataSourceInfo? getDataSourceInfo(String dsName)',
      'initializeDatasourceInfo': 'Future<int> initializeDatasourceInfo(Map<String, dynamic> datasourceConfiguration)',
      'closeAll': 'Future<void> closeAll()',
    },
    staticGetterSignatures: {
      'datasources': 'Map<String, TomDataSourceInfo> get datasources',
    },
    staticSetterSignatures: {
      'datasources': 'set datasources(dynamic value)',
    },
  );
}

// =============================================================================
// MariadbDatasourceException Bridge
// =============================================================================

BridgedClass _createMariadbDatasourceExceptionBridge() {
  return BridgedClass(
    nativeType: MariadbDatasourceException,
    name: 'MariadbDatasourceException',
    isAssignable: (v) => v is MariadbDatasourceException,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'MariadbDatasourceException');
        final key = D4.getRequiredArg<String>(positional, 0, 'key', 'MariadbDatasourceException');
        final defaultUserMessage = D4.getRequiredArg<String>(positional, 1, 'defaultUserMessage', 'MariadbDatasourceException');
        final parameters = D4.coerceMapOrNull<String, Object?>(named['parameters'], 'parameters');
        final stack = D4.getOptionalNamedArg<Object?>(named, 'stack');
        final rootException = D4.getOptionalNamedArg<Object?>(named, 'rootException');
        final autoLog = D4.getNamedArgWithDefault<bool>(named, 'autoLog', false);
        return MariadbDatasourceException(key, defaultUserMessage, parameters: parameters, stack: stack, rootException: rootException, autoLog: autoLog);
      },
    },
    getters: {
      'isolateName': (visitor, target) => D4.validateTarget<MariadbDatasourceException>(target, 'MariadbDatasourceException').isolateName,
      'clientThrow': (visitor, target) => D4.validateTarget<MariadbDatasourceException>(target, 'MariadbDatasourceException').clientThrow,
      'autoLog': (visitor, target) => D4.validateTarget<MariadbDatasourceException>(target, 'MariadbDatasourceException').autoLog,
      'serverCallError': (visitor, target) => D4.validateTarget<MariadbDatasourceException>(target, 'MariadbDatasourceException').serverCallError,
      'newField': (visitor, target) => D4.validateTarget<MariadbDatasourceException>(target, 'MariadbDatasourceException').newField,
      'logRepresentation': (visitor, target) => D4.validateTarget<MariadbDatasourceException>(target, 'MariadbDatasourceException').logRepresentation,
      'uuid': (visitor, target) => D4.validateTarget<MariadbDatasourceException>(target, 'MariadbDatasourceException').uuid,
      'requestUuid': (visitor, target) => D4.validateTarget<MariadbDatasourceException>(target, 'MariadbDatasourceException').requestUuid,
      'timeStamp': (visitor, target) => D4.validateTarget<MariadbDatasourceException>(target, 'MariadbDatasourceException').timeStamp,
      'key': (visitor, target) => D4.validateTarget<MariadbDatasourceException>(target, 'MariadbDatasourceException').key,
      'defaultUserMessage': (visitor, target) => D4.validateTarget<MariadbDatasourceException>(target, 'MariadbDatasourceException').defaultUserMessage,
      'parameters': (visitor, target) => D4.validateTarget<MariadbDatasourceException>(target, 'MariadbDatasourceException').parameters,
      'stack': (visitor, target) => D4.validateTarget<MariadbDatasourceException>(target, 'MariadbDatasourceException').stack,
      'rootException': (visitor, target) => D4.validateTarget<MariadbDatasourceException>(target, 'MariadbDatasourceException').rootException,
      'stackTrace': (visitor, target) => D4.validateTarget<MariadbDatasourceException>(target, 'MariadbDatasourceException').stackTrace,
    },
    setters: {
      'isolateName': (visitor, target, value) => 
        D4.validateTarget<MariadbDatasourceException>(target, 'MariadbDatasourceException').isolateName = D4.extractBridgedArg<String>(value, 'isolateName'),
      'clientThrow': (visitor, target, value) => 
        D4.validateTarget<MariadbDatasourceException>(target, 'MariadbDatasourceException').clientThrow = D4.extractBridgedArg<bool>(value, 'clientThrow'),
      'autoLog': (visitor, target, value) => 
        D4.validateTarget<MariadbDatasourceException>(target, 'MariadbDatasourceException').autoLog = D4.extractBridgedArg<bool>(value, 'autoLog'),
      'serverCallError': (visitor, target, value) => 
        D4.validateTarget<MariadbDatasourceException>(target, 'MariadbDatasourceException').serverCallError = D4.extractBridgedArgOrNull<$tom_core_kernel_4.TomServerCallError>(value, 'serverCallError'),
      'newField': (visitor, target, value) => 
        D4.validateTarget<MariadbDatasourceException>(target, 'MariadbDatasourceException').newField = D4.extractBridgedArgOrNull<String>(value, 'newField'),
      'uuid': (visitor, target, value) => 
        D4.validateTarget<MariadbDatasourceException>(target, 'MariadbDatasourceException').uuid = D4.extractBridgedArg<String>(value, 'uuid'),
      'requestUuid': (visitor, target, value) => 
        D4.validateTarget<MariadbDatasourceException>(target, 'MariadbDatasourceException').requestUuid = D4.extractBridgedArgOrNull<String>(value, 'requestUuid'),
      'timeStamp': (visitor, target, value) => 
        D4.validateTarget<MariadbDatasourceException>(target, 'MariadbDatasourceException').timeStamp = D4.extractBridgedArg<DateTime>(value, 'timeStamp'),
      'key': (visitor, target, value) => 
        D4.validateTarget<MariadbDatasourceException>(target, 'MariadbDatasourceException').key = D4.extractBridgedArg<String>(value, 'key'),
      'defaultUserMessage': (visitor, target, value) => 
        D4.validateTarget<MariadbDatasourceException>(target, 'MariadbDatasourceException').defaultUserMessage = D4.extractBridgedArg<String>(value, 'defaultUserMessage'),
      'stack': (visitor, target, value) => 
        D4.validateTarget<MariadbDatasourceException>(target, 'MariadbDatasourceException').stack = D4.extractBridgedArgOrNull<Object>(value, 'stack'),
      'rootException': (visitor, target, value) => 
        D4.validateTarget<MariadbDatasourceException>(target, 'MariadbDatasourceException').rootException = D4.extractBridgedArgOrNull<Object>(value, 'rootException'),
      'stackTrace': (visitor, target, value) => 
        D4.validateTarget<MariadbDatasourceException>(target, 'MariadbDatasourceException').stackTrace = D4.extractBridgedArg<String>(value, 'stackTrace'),
    },
    methods: {
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbDatasourceException>(target, 'MariadbDatasourceException');
        return t.toString();
      },
      'printStackTrace': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbDatasourceException>(target, 'MariadbDatasourceException');
        final depth = D4.getOptionalArgWithDefault<int>(positional, 0, 'depth', -1);
        t.printStackTrace(depth);
        return null;
      },
    },
    constructorSignatures: {
      '': 'MariadbDatasourceException(String key, String defaultUserMessage, {Map<String, Object?>? parameters, Object? stack, Object? rootException, bool autoLog = false})',
    },
    methodSignatures: {
      'toString': 'String toString()',
      'printStackTrace': 'void printStackTrace([int depth = -1])',
    },
    getterSignatures: {
      'isolateName': 'String get isolateName',
      'clientThrow': 'bool get clientThrow',
      'autoLog': 'bool get autoLog',
      'serverCallError': 'TomServerCallError? get serverCallError',
      'newField': 'String? get newField',
      'logRepresentation': 'String get logRepresentation',
      'uuid': 'String get uuid',
      'requestUuid': 'String? get requestUuid',
      'timeStamp': 'DateTime get timeStamp',
      'key': 'String get key',
      'defaultUserMessage': 'String get defaultUserMessage',
      'parameters': 'Map<String, Object?>? get parameters',
      'stack': 'Object? get stack',
      'rootException': 'Object? get rootException',
      'stackTrace': 'String get stackTrace',
    },
    setterSignatures: {
      'isolateName': 'set isolateName(String value)',
      'clientThrow': 'set clientThrow(bool value)',
      'autoLog': 'set autoLog(bool value)',
      'serverCallError': 'set serverCallError(TomServerCallError? value)',
      'newField': 'set newField(String? value)',
      'uuid': 'set uuid(String value)',
      'requestUuid': 'set requestUuid(String? value)',
      'timeStamp': 'set timeStamp(DateTime value)',
      'key': 'set key(String value)',
      'defaultUserMessage': 'set defaultUserMessage(String value)',
      'parameters': 'set parameters(Map<String, Object?>? value)',
      'stack': 'set stack(Object? value)',
      'rootException': 'set rootException(Object? value)',
      'stackTrace': 'set stackTrace(String value)',
    },
  );
}

// =============================================================================
// MariadbPreparedStatementException Bridge
// =============================================================================

BridgedClass _createMariadbPreparedStatementExceptionBridge() {
  return BridgedClass(
    nativeType: MariadbPreparedStatementException,
    name: 'MariadbPreparedStatementException',
    isAssignable: (v) => v is MariadbPreparedStatementException,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'MariadbPreparedStatementException');
        final key = D4.getRequiredArg<String>(positional, 0, 'key', 'MariadbPreparedStatementException');
        final defaultUserMessage = D4.getRequiredArg<String>(positional, 1, 'defaultUserMessage', 'MariadbPreparedStatementException');
        final parameters = D4.coerceMapOrNull<String, Object?>(named['parameters'], 'parameters');
        final stack = D4.getOptionalNamedArg<Object?>(named, 'stack');
        final rootException = D4.getOptionalNamedArg<Object?>(named, 'rootException');
        final autoLog = D4.getNamedArgWithDefault<bool>(named, 'autoLog', false);
        return MariadbPreparedStatementException(key, defaultUserMessage, parameters: parameters, stack: stack, rootException: rootException, autoLog: autoLog);
      },
    },
    getters: {
      'isolateName': (visitor, target) => D4.validateTarget<MariadbPreparedStatementException>(target, 'MariadbPreparedStatementException').isolateName,
      'clientThrow': (visitor, target) => D4.validateTarget<MariadbPreparedStatementException>(target, 'MariadbPreparedStatementException').clientThrow,
      'autoLog': (visitor, target) => D4.validateTarget<MariadbPreparedStatementException>(target, 'MariadbPreparedStatementException').autoLog,
      'serverCallError': (visitor, target) => D4.validateTarget<MariadbPreparedStatementException>(target, 'MariadbPreparedStatementException').serverCallError,
      'newField': (visitor, target) => D4.validateTarget<MariadbPreparedStatementException>(target, 'MariadbPreparedStatementException').newField,
      'logRepresentation': (visitor, target) => D4.validateTarget<MariadbPreparedStatementException>(target, 'MariadbPreparedStatementException').logRepresentation,
      'uuid': (visitor, target) => D4.validateTarget<MariadbPreparedStatementException>(target, 'MariadbPreparedStatementException').uuid,
      'requestUuid': (visitor, target) => D4.validateTarget<MariadbPreparedStatementException>(target, 'MariadbPreparedStatementException').requestUuid,
      'timeStamp': (visitor, target) => D4.validateTarget<MariadbPreparedStatementException>(target, 'MariadbPreparedStatementException').timeStamp,
      'key': (visitor, target) => D4.validateTarget<MariadbPreparedStatementException>(target, 'MariadbPreparedStatementException').key,
      'defaultUserMessage': (visitor, target) => D4.validateTarget<MariadbPreparedStatementException>(target, 'MariadbPreparedStatementException').defaultUserMessage,
      'parameters': (visitor, target) => D4.validateTarget<MariadbPreparedStatementException>(target, 'MariadbPreparedStatementException').parameters,
      'stack': (visitor, target) => D4.validateTarget<MariadbPreparedStatementException>(target, 'MariadbPreparedStatementException').stack,
      'rootException': (visitor, target) => D4.validateTarget<MariadbPreparedStatementException>(target, 'MariadbPreparedStatementException').rootException,
      'stackTrace': (visitor, target) => D4.validateTarget<MariadbPreparedStatementException>(target, 'MariadbPreparedStatementException').stackTrace,
    },
    setters: {
      'isolateName': (visitor, target, value) => 
        D4.validateTarget<MariadbPreparedStatementException>(target, 'MariadbPreparedStatementException').isolateName = D4.extractBridgedArg<String>(value, 'isolateName'),
      'clientThrow': (visitor, target, value) => 
        D4.validateTarget<MariadbPreparedStatementException>(target, 'MariadbPreparedStatementException').clientThrow = D4.extractBridgedArg<bool>(value, 'clientThrow'),
      'autoLog': (visitor, target, value) => 
        D4.validateTarget<MariadbPreparedStatementException>(target, 'MariadbPreparedStatementException').autoLog = D4.extractBridgedArg<bool>(value, 'autoLog'),
      'serverCallError': (visitor, target, value) => 
        D4.validateTarget<MariadbPreparedStatementException>(target, 'MariadbPreparedStatementException').serverCallError = D4.extractBridgedArgOrNull<$tom_core_kernel_4.TomServerCallError>(value, 'serverCallError'),
      'newField': (visitor, target, value) => 
        D4.validateTarget<MariadbPreparedStatementException>(target, 'MariadbPreparedStatementException').newField = D4.extractBridgedArgOrNull<String>(value, 'newField'),
      'uuid': (visitor, target, value) => 
        D4.validateTarget<MariadbPreparedStatementException>(target, 'MariadbPreparedStatementException').uuid = D4.extractBridgedArg<String>(value, 'uuid'),
      'requestUuid': (visitor, target, value) => 
        D4.validateTarget<MariadbPreparedStatementException>(target, 'MariadbPreparedStatementException').requestUuid = D4.extractBridgedArgOrNull<String>(value, 'requestUuid'),
      'timeStamp': (visitor, target, value) => 
        D4.validateTarget<MariadbPreparedStatementException>(target, 'MariadbPreparedStatementException').timeStamp = D4.extractBridgedArg<DateTime>(value, 'timeStamp'),
      'key': (visitor, target, value) => 
        D4.validateTarget<MariadbPreparedStatementException>(target, 'MariadbPreparedStatementException').key = D4.extractBridgedArg<String>(value, 'key'),
      'defaultUserMessage': (visitor, target, value) => 
        D4.validateTarget<MariadbPreparedStatementException>(target, 'MariadbPreparedStatementException').defaultUserMessage = D4.extractBridgedArg<String>(value, 'defaultUserMessage'),
      'stack': (visitor, target, value) => 
        D4.validateTarget<MariadbPreparedStatementException>(target, 'MariadbPreparedStatementException').stack = D4.extractBridgedArgOrNull<Object>(value, 'stack'),
      'rootException': (visitor, target, value) => 
        D4.validateTarget<MariadbPreparedStatementException>(target, 'MariadbPreparedStatementException').rootException = D4.extractBridgedArgOrNull<Object>(value, 'rootException'),
      'stackTrace': (visitor, target, value) => 
        D4.validateTarget<MariadbPreparedStatementException>(target, 'MariadbPreparedStatementException').stackTrace = D4.extractBridgedArg<String>(value, 'stackTrace'),
    },
    methods: {
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbPreparedStatementException>(target, 'MariadbPreparedStatementException');
        return t.toString();
      },
      'printStackTrace': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbPreparedStatementException>(target, 'MariadbPreparedStatementException');
        final depth = D4.getOptionalArgWithDefault<int>(positional, 0, 'depth', -1);
        t.printStackTrace(depth);
        return null;
      },
    },
    constructorSignatures: {
      '': 'MariadbPreparedStatementException(String key, String defaultUserMessage, {Map<String, Object?>? parameters, Object? stack, Object? rootException, bool autoLog = false})',
    },
    methodSignatures: {
      'toString': 'String toString()',
      'printStackTrace': 'void printStackTrace([int depth = -1])',
    },
    getterSignatures: {
      'isolateName': 'String get isolateName',
      'clientThrow': 'bool get clientThrow',
      'autoLog': 'bool get autoLog',
      'serverCallError': 'TomServerCallError? get serverCallError',
      'newField': 'String? get newField',
      'logRepresentation': 'String get logRepresentation',
      'uuid': 'String get uuid',
      'requestUuid': 'String? get requestUuid',
      'timeStamp': 'DateTime get timeStamp',
      'key': 'String get key',
      'defaultUserMessage': 'String get defaultUserMessage',
      'parameters': 'Map<String, Object?>? get parameters',
      'stack': 'Object? get stack',
      'rootException': 'Object? get rootException',
      'stackTrace': 'String get stackTrace',
    },
    setterSignatures: {
      'isolateName': 'set isolateName(String value)',
      'clientThrow': 'set clientThrow(bool value)',
      'autoLog': 'set autoLog(bool value)',
      'serverCallError': 'set serverCallError(TomServerCallError? value)',
      'newField': 'set newField(String? value)',
      'uuid': 'set uuid(String value)',
      'requestUuid': 'set requestUuid(String? value)',
      'timeStamp': 'set timeStamp(DateTime value)',
      'key': 'set key(String value)',
      'defaultUserMessage': 'set defaultUserMessage(String value)',
      'parameters': 'set parameters(Map<String, Object?>? value)',
      'stack': 'set stack(Object? value)',
      'rootException': 'set rootException(Object? value)',
      'stackTrace': 'set stackTrace(String value)',
    },
  );
}

// =============================================================================
// MariadbPreparedStatement Bridge
// =============================================================================

BridgedClass _createMariadbPreparedStatementBridge() {
  return BridgedClass(
    nativeType: MariadbPreparedStatement,
    name: 'MariadbPreparedStatement',
    isAssignable: (v) => v is MariadbPreparedStatement,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 5, 'MariadbPreparedStatement');
        final preparedStmt = D4.getRequiredArg<$mysql_client_1.PreparedStmt>(positional, 0, 'preparedStmt', 'MariadbPreparedStatement');
        if (positional.length <= 1) {
          throw ArgumentError('MariadbPreparedStatement: Missing required argument "parameterList" at position 1');
        }
        final parameterList = D4.coerceList<String>(positional[1], 'parameterList');
        final datasource = D4.getRequiredArg<$tom_core_server_5.MariaDbDatasource>(positional, 2, 'datasource', 'MariadbPreparedStatement');
        final resultType = D4.getRequiredArg<Type?>(positional, 3, 'resultType', 'MariadbPreparedStatement');
        final command = D4.getRequiredArg<String>(positional, 4, 'command', 'MariadbPreparedStatement');
        return MariadbPreparedStatement(preparedStmt, parameterList, datasource, resultType, command);
      },
    },
    getters: {
      'datasource': (visitor, target) => D4.validateTarget<MariadbPreparedStatement>(target, 'MariadbPreparedStatement').datasource,
      'preparedStmt': (visitor, target) => D4.validateTarget<MariadbPreparedStatement>(target, 'MariadbPreparedStatement').preparedStmt,
      'parameterList': (visitor, target) => D4.validateTarget<MariadbPreparedStatement>(target, 'MariadbPreparedStatement').parameterList,
      'resultType': (visitor, target) => D4.validateTarget<MariadbPreparedStatement>(target, 'MariadbPreparedStatement').resultType,
      'command': (visitor, target) => D4.validateTarget<MariadbPreparedStatement>(target, 'MariadbPreparedStatement').command,
    },
    setters: {
      'preparedStmt': (visitor, target, value) => 
        D4.validateTarget<MariadbPreparedStatement>(target, 'MariadbPreparedStatement').preparedStmt = D4.extractBridgedArg<$mysql_client_1.PreparedStmt>(value, 'preparedStmt'),
    },
    methods: {
      'execute': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbPreparedStatement>(target, 'MariadbPreparedStatement');
        final params = positional.isNotEmpty
            ? D4.coerceMapOrNull<String, Object?>(positional[0], 'params')
            : null;
        return t.execute(params);
      },
      'deallocate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbPreparedStatement>(target, 'MariadbPreparedStatement');
        return t.deallocate();
      },
    },
    constructorSignatures: {
      '': 'MariadbPreparedStatement(PreparedStmt preparedStmt, List<String> parameterList, MariaDbDatasource datasource, Type? resultType, String command)',
    },
    methodSignatures: {
      'execute': 'Future<List<T>> execute([Map<String, Object?>? params])',
      'deallocate': 'Future<void> deallocate()',
    },
    getterSignatures: {
      'datasource': 'MariaDbDatasource get datasource',
      'preparedStmt': 'PreparedStmt get preparedStmt',
      'parameterList': 'List<String> get parameterList',
      'resultType': 'Type? get resultType',
      'command': 'String get command',
    },
    setterSignatures: {
      'preparedStmt': 'set preparedStmt(dynamic value)',
    },
  );
}

// =============================================================================
// MariaDbDatasource Bridge
// =============================================================================

BridgedClass _createMariaDbDatasourceBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_5.MariaDbDatasource,
    name: 'MariaDbDatasource',
    isAssignable: (v) => v is $tom_core_server_5.MariaDbDatasource,
    constructors: {
      '': (visitor, positional, named) {
        return $tom_core_server_5.MariaDbDatasource();
      },
    },
    getters: {
      'sqlDialect': (visitor, target) => D4.validateTarget<$tom_core_server_5.MariaDbDatasource>(target, 'MariaDbDatasource').sqlDialect,
      'username': (visitor, target) => D4.validateTarget<$tom_core_server_5.MariaDbDatasource>(target, 'MariaDbDatasource').username,
      'password': (visitor, target) => D4.validateTarget<$tom_core_server_5.MariaDbDatasource>(target, 'MariaDbDatasource').password,
      'host': (visitor, target) => D4.validateTarget<$tom_core_server_5.MariaDbDatasource>(target, 'MariaDbDatasource').host,
      'port': (visitor, target) => D4.validateTarget<$tom_core_server_5.MariaDbDatasource>(target, 'MariaDbDatasource').port,
      'databaseName': (visitor, target) => D4.validateTarget<$tom_core_server_5.MariaDbDatasource>(target, 'MariaDbDatasource').databaseName,
      'timeOut': (visitor, target) => D4.validateTarget<$tom_core_server_5.MariaDbDatasource>(target, 'MariaDbDatasource').timeOut,
      'connection': (visitor, target) => D4.validateTarget<$tom_core_server_5.MariaDbDatasource>(target, 'MariaDbDatasource').connection,
      'connected': (visitor, target) => D4.validateTarget<$tom_core_server_5.MariaDbDatasource>(target, 'MariaDbDatasource').connected,
    },
    setters: {
      'username': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_5.MariaDbDatasource>(target, 'MariaDbDatasource').username = D4.extractBridgedArg<String>(value, 'username'),
      'password': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_5.MariaDbDatasource>(target, 'MariaDbDatasource').password = D4.extractBridgedArg<String>(value, 'password'),
      'host': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_5.MariaDbDatasource>(target, 'MariaDbDatasource').host = D4.extractBridgedArg<String>(value, 'host'),
      'port': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_5.MariaDbDatasource>(target, 'MariaDbDatasource').port = D4.extractBridgedArg<int>(value, 'port'),
      'databaseName': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_5.MariaDbDatasource>(target, 'MariaDbDatasource').databaseName = D4.extractBridgedArg<String>(value, 'databaseName'),
      'timeOut': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_5.MariaDbDatasource>(target, 'MariaDbDatasource').timeOut = D4.extractBridgedArg<int>(value, 'timeOut'),
      'connection': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_5.MariaDbDatasource>(target, 'MariaDbDatasource').connection = D4.extractBridgedArgOrNull<$mysql_client_1.MySQLConnection>(value, 'connection'),
    },
    methods: {
      'connect': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_5.MariaDbDatasource>(target, 'MariaDbDatasource');
        return t.connect();
      },
      'prepareStatement': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_5.MariaDbDatasource>(target, 'MariaDbDatasource');
        D4.requireMinArgs(positional, 1, 'prepareStatement');
        final query = D4.getRequiredArg<$tom_core_server_6.TomQuery>(positional, 0, 'query', 'prepareStatement');
        final resultType = D4.getOptionalArg<Type?>(positional, 1, 'resultType');
        return t.prepareStatement(query, resultType);
      },
      'executeQuery': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_5.MariaDbDatasource>(target, 'MariaDbDatasource');
        D4.requireMinArgs(positional, 1, 'executeQuery');
        final command = D4.getRequiredArg<String>(positional, 0, 'command', 'executeQuery');
        final params = positional.length > 1
            ? D4.coerceMapOrNull<String, dynamic>(positional[1], 'params')
            : null;
        final resultType = D4.getOptionalArg<Type?>(positional, 2, 'resultType');
        return t.executeQuery(command, params, resultType);
      },
      'initialize': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_5.MariaDbDatasource>(target, 'MariaDbDatasource');
        D4.requireMinArgs(positional, 1, 'initialize');
        if (positional.isEmpty) {
          throw ArgumentError('initialize: Missing required argument "settings" at position 0');
        }
        final settings = D4.coerceMap<String, dynamic>(positional[0], 'settings');
        return t.initialize(settings);
      },
      'isOperational': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_5.MariaDbDatasource>(target, 'MariaDbDatasource');
        return t.isOperational();
      },
      'executeCommand': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_5.MariaDbDatasource>(target, 'MariaDbDatasource');
        D4.requireMinArgs(positional, 1, 'executeCommand');
        final command = D4.getRequiredArg<String>(positional, 0, 'command', 'executeCommand');
        final params = positional.length > 1
            ? D4.coerceMapOrNull<String, dynamic>(positional[1], 'params')
            : null;
        return t.executeCommand(command, params);
      },
      'close': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_5.MariaDbDatasource>(target, 'MariaDbDatasource');
        return t.close();
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_5.MariaDbDatasource>(target, 'MariaDbDatasource');
        return t.toString();
      },
      'getParticipantId': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_5.MariaDbDatasource>(target, 'MariaDbDatasource');
        return t.getParticipantId();
      },
      'startTransaction': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_5.MariaDbDatasource>(target, 'MariaDbDatasource');
        return t.startTransaction();
      },
      'endTransaction': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_5.MariaDbDatasource>(target, 'MariaDbDatasource');
        return t.endTransaction();
      },
      'commit': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_5.MariaDbDatasource>(target, 'MariaDbDatasource');
        return t.commit();
      },
      'rollback': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_5.MariaDbDatasource>(target, 'MariaDbDatasource');
        return t.rollback();
      },
    },
    constructorSignatures: {
      '': 'MariaDbDatasource()',
    },
    methodSignatures: {
      'connect': 'Future<void> connect()',
      'prepareStatement': 'Future<TomPreparedStatement<T>> prepareStatement(TomQuery query, [Type? resultType])',
      'executeQuery': 'Future<List<T>> executeQuery(String command, [Map<String, dynamic>? params, Type? resultType])',
      'initialize': 'Future<void> initialize(Map<String, dynamic> settings)',
      'isOperational': 'bool isOperational()',
      'executeCommand': 'Future<BigInt> executeCommand(String command, [Map<String, dynamic>? params])',
      'close': 'Future<void> close()',
      'toString': 'String toString()',
      'getParticipantId': 'String getParticipantId()',
      'startTransaction': 'Future<bool> startTransaction()',
      'endTransaction': 'Future<bool> endTransaction()',
      'commit': 'Future<bool> commit()',
      'rollback': 'Future<void> rollback()',
    },
    getterSignatures: {
      'sqlDialect': 'TomStandardSqlDialect get sqlDialect',
      'username': 'String get username',
      'password': 'String get password',
      'host': 'String get host',
      'port': 'int get port',
      'databaseName': 'String get databaseName',
      'timeOut': 'int get timeOut',
      'connection': 'MySQLConnection? get connection',
      'connected': 'bool get connected',
    },
    setterSignatures: {
      'username': 'set username(dynamic value)',
      'password': 'set password(dynamic value)',
      'host': 'set host(dynamic value)',
      'port': 'set port(dynamic value)',
      'databaseName': 'set databaseName(dynamic value)',
      'timeOut': 'set timeOut(dynamic value)',
      'connection': 'set connection(dynamic value)',
    },
  );
}

// =============================================================================
// MariaDbXADatasource Bridge
// =============================================================================

BridgedClass _createMariaDbXADatasourceBridge() {
  return BridgedClass(
    nativeType: MariaDbXADatasource,
    name: 'MariaDbXADatasource',
    isAssignable: (v) => v is MariaDbXADatasource,
    constructors: {
      '': (visitor, positional, named) {
        return MariaDbXADatasource();
      },
    },
    getters: {
      'sqlDialect': (visitor, target) => D4.validateTarget<MariaDbXADatasource>(target, 'MariaDbXADatasource').sqlDialect,
      'username': (visitor, target) => D4.validateTarget<MariaDbXADatasource>(target, 'MariaDbXADatasource').username,
      'password': (visitor, target) => D4.validateTarget<MariaDbXADatasource>(target, 'MariaDbXADatasource').password,
      'host': (visitor, target) => D4.validateTarget<MariaDbXADatasource>(target, 'MariaDbXADatasource').host,
      'port': (visitor, target) => D4.validateTarget<MariaDbXADatasource>(target, 'MariaDbXADatasource').port,
      'databaseName': (visitor, target) => D4.validateTarget<MariaDbXADatasource>(target, 'MariaDbXADatasource').databaseName,
      'timeOut': (visitor, target) => D4.validateTarget<MariaDbXADatasource>(target, 'MariaDbXADatasource').timeOut,
      'connection': (visitor, target) => D4.validateTarget<MariaDbXADatasource>(target, 'MariaDbXADatasource').connection,
      'connected': (visitor, target) => D4.validateTarget<MariaDbXADatasource>(target, 'MariaDbXADatasource').connected,
    },
    setters: {
      'username': (visitor, target, value) => 
        D4.validateTarget<MariaDbXADatasource>(target, 'MariaDbXADatasource').username = D4.extractBridgedArg<String>(value, 'username'),
      'password': (visitor, target, value) => 
        D4.validateTarget<MariaDbXADatasource>(target, 'MariaDbXADatasource').password = D4.extractBridgedArg<String>(value, 'password'),
      'host': (visitor, target, value) => 
        D4.validateTarget<MariaDbXADatasource>(target, 'MariaDbXADatasource').host = D4.extractBridgedArg<String>(value, 'host'),
      'port': (visitor, target, value) => 
        D4.validateTarget<MariaDbXADatasource>(target, 'MariaDbXADatasource').port = D4.extractBridgedArg<int>(value, 'port'),
      'databaseName': (visitor, target, value) => 
        D4.validateTarget<MariaDbXADatasource>(target, 'MariaDbXADatasource').databaseName = D4.extractBridgedArg<String>(value, 'databaseName'),
      'timeOut': (visitor, target, value) => 
        D4.validateTarget<MariaDbXADatasource>(target, 'MariaDbXADatasource').timeOut = D4.extractBridgedArg<int>(value, 'timeOut'),
      'connection': (visitor, target, value) => 
        D4.validateTarget<MariaDbXADatasource>(target, 'MariaDbXADatasource').connection = D4.extractBridgedArgOrNull<$mysql_client_1.MySQLConnection>(value, 'connection'),
    },
    methods: {
      'connect': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariaDbXADatasource>(target, 'MariaDbXADatasource');
        return t.connect();
      },
      'prepareStatement': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariaDbXADatasource>(target, 'MariaDbXADatasource');
        D4.requireMinArgs(positional, 1, 'prepareStatement');
        final query = D4.getRequiredArg<$tom_core_server_6.TomQuery>(positional, 0, 'query', 'prepareStatement');
        final resultType = D4.getOptionalArg<Type?>(positional, 1, 'resultType');
        return t.prepareStatement(query, resultType);
      },
      'executeQuery': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariaDbXADatasource>(target, 'MariaDbXADatasource');
        D4.requireMinArgs(positional, 1, 'executeQuery');
        final command = D4.getRequiredArg<String>(positional, 0, 'command', 'executeQuery');
        final params = positional.length > 1
            ? D4.coerceMapOrNull<String, dynamic>(positional[1], 'params')
            : null;
        final resultType = D4.getOptionalArg<Type?>(positional, 2, 'resultType');
        return t.executeQuery(command, params, resultType);
      },
      'initialize': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariaDbXADatasource>(target, 'MariaDbXADatasource');
        D4.requireMinArgs(positional, 1, 'initialize');
        if (positional.isEmpty) {
          throw ArgumentError('initialize: Missing required argument "settings" at position 0');
        }
        final settings = D4.coerceMap<String, dynamic>(positional[0], 'settings');
        return t.initialize(settings);
      },
      'isOperational': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariaDbXADatasource>(target, 'MariaDbXADatasource');
        return t.isOperational();
      },
      'executeCommand': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariaDbXADatasource>(target, 'MariaDbXADatasource');
        D4.requireMinArgs(positional, 1, 'executeCommand');
        final command = D4.getRequiredArg<String>(positional, 0, 'command', 'executeCommand');
        final params = positional.length > 1
            ? D4.coerceMapOrNull<String, dynamic>(positional[1], 'params')
            : null;
        return t.executeCommand(command, params);
      },
      'close': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariaDbXADatasource>(target, 'MariaDbXADatasource');
        return t.close();
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariaDbXADatasource>(target, 'MariaDbXADatasource');
        return t.toString();
      },
      'getParticipantId': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariaDbXADatasource>(target, 'MariaDbXADatasource');
        return t.getParticipantId();
      },
      'startTransaction': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariaDbXADatasource>(target, 'MariaDbXADatasource');
        return t.startTransaction();
      },
      'endTransaction': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariaDbXADatasource>(target, 'MariaDbXADatasource');
        return t.endTransaction();
      },
      'commit': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariaDbXADatasource>(target, 'MariaDbXADatasource');
        return t.commit();
      },
      'rollback': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariaDbXADatasource>(target, 'MariaDbXADatasource');
        return t.rollback();
      },
    },
    constructorSignatures: {
      '': 'MariaDbXADatasource()',
    },
    methodSignatures: {
      'connect': 'Future<void> connect()',
      'prepareStatement': 'Future<TomPreparedStatement<T>> prepareStatement(TomQuery query, [Type? resultType])',
      'executeQuery': 'Future<List<T>> executeQuery(String command, [Map<String, dynamic>? params, Type? resultType])',
      'initialize': 'Future<void> initialize(Map<String, dynamic> settings)',
      'isOperational': 'bool isOperational()',
      'executeCommand': 'Future<BigInt> executeCommand(String command, [Map<String, dynamic>? params])',
      'close': 'Future<void> close()',
      'toString': 'String toString()',
      'getParticipantId': 'String getParticipantId()',
      'startTransaction': 'Future<bool> startTransaction()',
      'endTransaction': 'Future<bool> endTransaction()',
      'commit': 'Future<bool> commit()',
      'rollback': 'Future<void> rollback()',
    },
    getterSignatures: {
      'sqlDialect': 'TomStandardSqlDialect get sqlDialect',
      'username': 'String get username',
      'password': 'String get password',
      'host': 'String get host',
      'port': 'int get port',
      'databaseName': 'String get databaseName',
      'timeOut': 'int get timeOut',
      'connection': 'MySQLConnection? get connection',
      'connected': 'bool get connected',
    },
    setterSignatures: {
      'username': 'set username(String value)',
      'password': 'set password(String value)',
      'host': 'set host(String value)',
      'port': 'set port(int value)',
      'databaseName': 'set databaseName(String value)',
      'timeOut': 'set timeOut(int value)',
      'connection': 'set connection(MySQLConnection? value)',
    },
  );
}

// =============================================================================
// MariadbSqlDialect Bridge
// =============================================================================

BridgedClass _createMariadbSqlDialectBridge() {
  return BridgedClass(
    nativeType: MariadbSqlDialect,
    name: 'MariadbSqlDialect',
    isAssignable: (v) => v is MariadbSqlDialect,
    constructors: {
      '': (visitor, positional, named) {
        return MariadbSqlDialect();
      },
    },
    methods: {
      'isNull': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbSqlDialect>(target, 'MariadbSqlDialect');
        D4.requireMinArgs(positional, 1, 'isNull');
        final what = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'what', 'isNull');
        return t.isNull(what);
      },
      'isNotNull': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbSqlDialect>(target, 'MariadbSqlDialect');
        D4.requireMinArgs(positional, 1, 'isNotNull');
        final what = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'what', 'isNotNull');
        return t.isNotNull(what);
      },
      'isin': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbSqlDialect>(target, 'MariadbSqlDialect');
        D4.requireMinArgs(positional, 2, 'isin');
        final what = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'what', 'isin');
        if (positional.length <= 1) {
          throw ArgumentError('isin: Missing required argument "choices" at position 1');
        }
        final choices = D4.coerceList<$tom_core_server_8.TomOperator<dynamic>>(positional[1], 'choices');
        return t.isin(what, choices);
      },
      'between': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbSqlDialect>(target, 'MariadbSqlDialect');
        D4.requireMinArgs(positional, 2, 'between');
        final what = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'what', 'between');
        if (positional.length <= 1) {
          throw ArgumentError('between: Missing required argument "betweenLimits" at position 1');
        }
        final betweenLimits = D4.coerceList<$tom_core_server_8.TomOperator<dynamic>>(positional[1], 'betweenLimits');
        return t.between(what, betweenLimits);
      },
      'like': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbSqlDialect>(target, 'MariadbSqlDialect');
        D4.requireMinArgs(positional, 2, 'like');
        final text = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 0, 'text', 'like');
        final test = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 1, 'test', 'like');
        return t.like(text, test);
      },
      'notLike': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbSqlDialect>(target, 'MariadbSqlDialect');
        D4.requireMinArgs(positional, 2, 'notLike');
        final text = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 0, 'text', 'notLike');
        final test = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 1, 'test', 'notLike');
        return t.notLike(text, test);
      },
      'regexp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbSqlDialect>(target, 'MariadbSqlDialect');
        D4.requireMinArgs(positional, 2, 'regexp');
        final text = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 0, 'text', 'regexp');
        final test = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 1, 'test', 'regexp');
        return t.regexp(text, test);
      },
      'group': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbSqlDialect>(target, 'MariadbSqlDialect');
        D4.requireMinArgs(positional, 1, 'group');
        final operant = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant', 'group');
        return t.group(operant);
      },
      'eq': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbSqlDialect>(target, 'MariadbSqlDialect');
        D4.requireMinArgs(positional, 2, 'eq');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'eq');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'eq');
        return t.eq(operant1, operant2);
      },
      'neq': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbSqlDialect>(target, 'MariadbSqlDialect');
        D4.requireMinArgs(positional, 2, 'neq');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'neq');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'neq');
        return t.neq(operant1, operant2);
      },
      'lt': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbSqlDialect>(target, 'MariadbSqlDialect');
        D4.requireMinArgs(positional, 2, 'lt');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'lt');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'lt');
        return t.lt(operant1, operant2);
      },
      'lte': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbSqlDialect>(target, 'MariadbSqlDialect');
        D4.requireMinArgs(positional, 2, 'lte');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'lte');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'lte');
        return t.lte(operant1, operant2);
      },
      'gt': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbSqlDialect>(target, 'MariadbSqlDialect');
        D4.requireMinArgs(positional, 2, 'gt');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'gt');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'gt');
        return t.gt(operant1, operant2);
      },
      'gte': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbSqlDialect>(target, 'MariadbSqlDialect');
        D4.requireMinArgs(positional, 2, 'gte');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'gte');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'gte');
        return t.gte(operant1, operant2);
      },
      'not': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbSqlDialect>(target, 'MariadbSqlDialect');
        D4.requireMinArgs(positional, 1, 'not');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbBool>>(positional, 0, 'operant1', 'not');
        return t.not(operant1);
      },
      'and': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbSqlDialect>(target, 'MariadbSqlDialect');
        D4.requireMinArgs(positional, 1, 'and');
        if (positional.isEmpty) {
          throw ArgumentError('and: Missing required argument "operant1" at position 0');
        }
        final operant1 = D4.coerceList<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbBool>>(positional[0], 'operant1');
        return t.and(operant1);
      },
      'or': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbSqlDialect>(target, 'MariadbSqlDialect');
        D4.requireMinArgs(positional, 1, 'or');
        if (positional.isEmpty) {
          throw ArgumentError('or: Missing required argument "operant1" at position 0');
        }
        final operant1 = D4.coerceList<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbBool>>(positional[0], 'operant1');
        return t.or(operant1);
      },
      'text': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbSqlDialect>(target, 'MariadbSqlDialect');
        D4.requireMinArgs(positional, 1, 'text');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'text');
        return t.text(text);
      },
      'intOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbSqlDialect>(target, 'MariadbSqlDialect');
        D4.requireMinArgs(positional, 1, 'intOp');
        final value = D4.getRequiredArg<int>(positional, 0, 'value', 'intOp');
        return t.intOp(value);
      },
      'doubleOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbSqlDialect>(target, 'MariadbSqlDialect');
        D4.requireMinArgs(positional, 1, 'doubleOp');
        final value = D4.getRequiredArg<double>(positional, 0, 'value', 'doubleOp');
        return t.doubleOp(value);
      },
      'boolOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbSqlDialect>(target, 'MariadbSqlDialect');
        D4.requireMinArgs(positional, 1, 'boolOp');
        final value = D4.getRequiredArg<bool>(positional, 0, 'value', 'boolOp');
        return t.boolOp(value);
      },
      'dateTimeOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbSqlDialect>(target, 'MariadbSqlDialect');
        D4.requireMinArgs(positional, 1, 'dateTimeOp');
        final value = D4.getRequiredArg<DateTime>(positional, 0, 'value', 'dateTimeOp');
        return t.dateTimeOp(value);
      },
      'dateOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbSqlDialect>(target, 'MariadbSqlDialect');
        D4.requireMinArgs(positional, 1, 'dateOp');
        final value = D4.getRequiredArg<DateTime>(positional, 0, 'value', 'dateOp');
        return t.dateOp(value);
      },
      'iterableOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbSqlDialect>(target, 'MariadbSqlDialect');
        D4.requireMinArgs(positional, 1, 'iterableOp');
        if (positional.isEmpty) {
          throw ArgumentError('iterableOp: Missing required argument "values" at position 0');
        }
        final values = D4.coerceList<dynamic>(positional[0], 'values');
        return t.iterableOp(values);
      },
      'nullOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbSqlDialect>(target, 'MariadbSqlDialect');
        return t.nullOp();
      },
      'objectOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbSqlDialect>(target, 'MariadbSqlDialect');
        D4.requireMinArgs(positional, 1, 'objectOp');
        final o = D4.getRequiredArg<Object?>(positional, 0, 'o', 'objectOp');
        return t.objectOp(o);
      },
      'p': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbSqlDialect>(target, 'MariadbSqlDialect');
        D4.requireMinArgs(positional, 1, 'p');
        final parameterName = D4.getRequiredArg<String>(positional, 0, 'parameterName', 'p');
        return t.p(parameterName);
      },
      'textF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbSqlDialect>(target, 'MariadbSqlDialect');
        D4.requireMinArgs(positional, 3, 'textF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'textF');
        final column = D4.getRequiredArg<$tom_core_server_14.DbCol<dynamic>>(positional, 1, 'column', 'textF');
        final dbType = D4.getRequiredArg<Type>(positional, 2, 'dbType', 'textF');
        return t.textF(fieldName, column, dbType);
      },
      'intF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbSqlDialect>(target, 'MariadbSqlDialect');
        D4.requireMinArgs(positional, 3, 'intF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'intF');
        final column = D4.getRequiredArg<$tom_core_server_14.DbCol<dynamic>>(positional, 1, 'column', 'intF');
        final dbType = D4.getRequiredArg<Type>(positional, 2, 'dbType', 'intF');
        return t.intF(fieldName, column, dbType);
      },
      'doubleF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbSqlDialect>(target, 'MariadbSqlDialect');
        D4.requireMinArgs(positional, 3, 'doubleF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'doubleF');
        final column = D4.getRequiredArg<$tom_core_server_14.DbCol<dynamic>>(positional, 1, 'column', 'doubleF');
        final dbType = D4.getRequiredArg<Type>(positional, 2, 'dbType', 'doubleF');
        return t.doubleF(fieldName, column, dbType);
      },
      'boolF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbSqlDialect>(target, 'MariadbSqlDialect');
        D4.requireMinArgs(positional, 3, 'boolF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'boolF');
        final column = D4.getRequiredArg<$tom_core_server_14.DbCol<dynamic>>(positional, 1, 'column', 'boolF');
        final dbType = D4.getRequiredArg<Type>(positional, 2, 'dbType', 'boolF');
        return t.boolF(fieldName, column, dbType);
      },
      'dateTimeF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbSqlDialect>(target, 'MariadbSqlDialect');
        D4.requireMinArgs(positional, 3, 'dateTimeF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'dateTimeF');
        final column = D4.getRequiredArg<$tom_core_server_14.DbCol<dynamic>>(positional, 1, 'column', 'dateTimeF');
        final dbType = D4.getRequiredArg<Type>(positional, 2, 'dbType', 'dateTimeF');
        return t.dateTimeF(fieldName, column, dbType);
      },
      'dateF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbSqlDialect>(target, 'MariadbSqlDialect');
        D4.requireMinArgs(positional, 3, 'dateF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'dateF');
        final column = D4.getRequiredArg<$tom_core_server_14.DbCol<dynamic>>(positional, 1, 'column', 'dateF');
        final dbType = D4.getRequiredArg<Type>(positional, 2, 'dbType', 'dateF');
        return t.dateF(fieldName, column, dbType);
      },
    },
    constructorSignatures: {
      '': 'MariadbSqlDialect()',
    },
    methodSignatures: {
      'isNull': 'String isNull(TomOperator<T> what)',
      'isNotNull': 'String isNotNull(TomOperator<T> what)',
      'isin': 'String isin(TomOperator<T> what, List<TomOperator<T>> choices)',
      'between': 'String between(TomOperator<T> what, List<TomOperator<T>> betweenLimits)',
      'like': 'String like(TomOperator<TomDbString> text, TomOperator<TomDbString> test)',
      'notLike': 'String notLike(TomOperator<TomDbString> text, TomOperator<TomDbString> test)',
      'regexp': 'String regexp(TomOperator<TomDbString> text, TomOperator<TomDbString> test)',
      'group': 'String group(TomOperator<T> operant)',
      'eq': 'String eq(TomOperator<T> operant1, TomOperator<T> operant2)',
      'neq': 'String neq(TomOperator<T> operant1, TomOperator<T> operant2)',
      'lt': 'String lt(TomOperator<T> operant1, TomOperator<T> operant2)',
      'lte': 'String lte(TomOperator<T> operant1, TomOperator<T> operant2)',
      'gt': 'String gt(TomOperator<T> operant1, TomOperator<T> operant2)',
      'gte': 'String gte(TomOperator<T> operant1, TomOperator<T> operant2)',
      'not': 'String not(TomOperator<TomDbBool> operant1)',
      'and': 'String and(List<TomOperator<TomDbBool>> operant1)',
      'or': 'String or(List<TomOperator<TomDbBool>> operant1)',
      'text': 'String text(String text)',
      'intOp': 'String intOp(int value)',
      'doubleOp': 'String doubleOp(double value)',
      'boolOp': 'String boolOp(bool value)',
      'dateTimeOp': 'String dateTimeOp(DateTime value)',
      'dateOp': 'String dateOp(DateTime value)',
      'iterableOp': 'String iterableOp(Iterable<dynamic> values)',
      'nullOp': 'String nullOp()',
      'objectOp': 'String objectOp(Object? o)',
      'p': 'String p(String parameterName)',
      'textF': 'String textF(String fieldName, DbCol<dynamic> column, Type dbType)',
      'intF': 'String intF(String fieldName, DbCol<dynamic> column, Type dbType)',
      'doubleF': 'String doubleF(String fieldName, DbCol<dynamic> column, Type dbType)',
      'boolF': 'String boolF(String fieldName, DbCol<dynamic> column, Type dbType)',
      'dateTimeF': 'String dateTimeF(String fieldName, DbCol<dynamic> column, Type dbType)',
      'dateF': 'String dateF(String fieldName, DbCol<dynamic> column, Type dbType)',
    },
  );
}

// =============================================================================
// TomTypePersistenceInfo Bridge
// =============================================================================

BridgedClass _createTomTypePersistenceInfoBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_6.TomTypePersistenceInfo,
    name: 'TomTypePersistenceInfo',
    isAssignable: (v) => v is $tom_core_server_6.TomTypePersistenceInfo,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 3, 'TomTypePersistenceInfo');
        final classMirror = D4.getRequiredArg<$tom_reflection_1.ClassMirror<dynamic>>(positional, 0, 'classMirror', 'TomTypePersistenceInfo');
        final table = D4.getRequiredArg<$tom_core_server_15.TomDbTable>(positional, 1, 'table', 'TomTypePersistenceInfo');
        if (positional.length <= 2) {
          throw ArgumentError('TomTypePersistenceInfo: Missing required argument "columnInfo" at position 2');
        }
        final columnInfo = D4.coerceList<$tom_core_server_15.TomColumnInformation>(positional[2], 'columnInfo');
        return $tom_core_server_6.TomTypePersistenceInfo(classMirror, table, columnInfo);
      },
    },
    getters: {
      'classMirror': (visitor, target) => D4.validateTarget<$tom_core_server_6.TomTypePersistenceInfo>(target, 'TomTypePersistenceInfo').classMirror,
      'table': (visitor, target) => D4.validateTarget<$tom_core_server_6.TomTypePersistenceInfo>(target, 'TomTypePersistenceInfo').table,
      'columnInfo': (visitor, target) => D4.validateTarget<$tom_core_server_6.TomTypePersistenceInfo>(target, 'TomTypePersistenceInfo').columnInfo,
    },
    setters: {
      'classMirror': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_6.TomTypePersistenceInfo>(target, 'TomTypePersistenceInfo').classMirror = D4.extractBridgedArg<$tom_reflection_1.ClassMirror>(value, 'classMirror'),
      'table': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_6.TomTypePersistenceInfo>(target, 'TomTypePersistenceInfo').table = D4.extractBridgedArg<$tom_core_server_15.TomDbTable>(value, 'table'),
      'columnInfo': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_6.TomTypePersistenceInfo>(target, 'TomTypePersistenceInfo').columnInfo = (value as List).cast<$tom_core_server_15.TomColumnInformation>().toList(),
    },
    constructorSignatures: {
      '': 'TomTypePersistenceInfo(ClassMirror<dynamic> classMirror, TomDbTable table, List<TomColumnInformation> columnInfo)',
    },
    getterSignatures: {
      'classMirror': 'ClassMirror get classMirror',
      'table': 'TomDbTable get table',
      'columnInfo': 'List<TomColumnInformation> get columnInfo',
    },
    setterSignatures: {
      'classMirror': 'set classMirror(dynamic value)',
      'table': 'set table(dynamic value)',
      'columnInfo': 'set columnInfo(dynamic value)',
    },
  );
}

// =============================================================================
// TomTypedPersistenceBase Bridge
// =============================================================================

BridgedClass _createTomTypedPersistenceBaseBridge() {
  return BridgedClass(
    nativeType: TomTypedPersistenceBase,
    name: 'TomTypedPersistenceBase',
    isAssignable: (v) => v is TomTypedPersistenceBase,
    constructors: {
    },
    getters: {
      'types': (visitor, target) => D4.validateTarget<TomTypedPersistenceBase>(target, 'TomTypedPersistenceBase').types,
      'persistenceInfo': (visitor, target) => D4.validateTarget<TomTypedPersistenceBase>(target, 'TomTypedPersistenceBase').persistenceInfo,
    },
    setters: {
      'types': (visitor, target, value) => 
        D4.validateTarget<TomTypedPersistenceBase>(target, 'TomTypedPersistenceBase').types = (value as List).cast<Type>().toList(),
    },
    methods: {
      'getColumnInformation': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomTypedPersistenceBase>(target, 'TomTypedPersistenceBase');
        return t.getColumnInformation();
      },
      'determineColumn': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomTypedPersistenceBase>(target, 'TomTypedPersistenceBase');
        D4.requireMinArgs(positional, 1, 'determineColumn');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'determineColumn');
        return t.determineColumn(name);
      },
    },
    methodSignatures: {
      'getColumnInformation': 'List<TomColumnInformation> getColumnInformation()',
      'determineColumn': 'TomColumnInformation determineColumn(String name)',
    },
    getterSignatures: {
      'types': 'List<Type> get types',
      'persistenceInfo': 'List<TomTypePersistenceInfo> get persistenceInfo',
    },
    setterSignatures: {
      'types': 'set types(dynamic value)',
    },
  );
}

// =============================================================================
// TomQuery Bridge
// =============================================================================

BridgedClass _createTomQueryBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_6.TomQuery,
    name: 'TomQuery',
    isAssignable: (v) => v is $tom_core_server_6.TomQuery,
    constructors: {
    },
    getters: {
      'types': (visitor, target) => D4.validateTarget<$tom_core_server_6.TomQuery>(target, 'TomQuery').types,
      'persistenceInfo': (visitor, target) => D4.validateTarget<$tom_core_server_6.TomQuery>(target, 'TomQuery').persistenceInfo,
    },
    setters: {
      'types': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_6.TomQuery>(target, 'TomQuery').types = (value as List).cast<Type>().toList(),
    },
    methods: {
      'getColumnInformation': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_6.TomQuery>(target, 'TomQuery');
        return t.getColumnInformation();
      },
      'determineColumn': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_6.TomQuery>(target, 'TomQuery');
        D4.requireMinArgs(positional, 1, 'determineColumn');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'determineColumn');
        return t.determineColumn(name);
      },
      'generateQuery': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_6.TomQuery>(target, 'TomQuery');
        D4.requireMinArgs(positional, 1, 'generateQuery');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generateQuery');
        return t.generateQuery(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_6.TomQuery>(target, 'TomQuery');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_6.TomQuery>(target, 'TomQuery');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
    },
    methodSignatures: {
      'getColumnInformation': 'List<TomColumnInformation> getColumnInformation()',
      'determineColumn': 'TomColumnInformation determineColumn(String name)',
      'generateQuery': 'String generateQuery(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
    },
    getterSignatures: {
      'types': 'List<Type> get types',
      'persistenceInfo': 'List<TomTypePersistenceInfo> get persistenceInfo',
    },
    setterSignatures: {
      'types': 'set types(List<Type> value)',
    },
  );
}

// =============================================================================
// TomGeneratedQuery Bridge
// =============================================================================

BridgedClass _createTomGeneratedQueryBridge() {
  return BridgedClass(
    nativeType: TomGeneratedQuery,
    name: 'TomGeneratedQuery',
    isAssignable: (v) => v is TomGeneratedQuery,
    constructors: {
    },
    getters: {
      'types': (visitor, target) => D4.validateTarget<TomGeneratedQuery>(target, 'TomGeneratedQuery').types,
      'persistenceInfo': (visitor, target) => D4.validateTarget<TomGeneratedQuery>(target, 'TomGeneratedQuery').persistenceInfo,
      'query': (visitor, target) => D4.validateTarget<TomGeneratedQuery>(target, 'TomGeneratedQuery').query,
      'ignoreFields': (visitor, target) => D4.validateTarget<TomGeneratedQuery>(target, 'TomGeneratedQuery').ignoreFields,
      'distinct': (visitor, target) => D4.validateTarget<TomGeneratedQuery>(target, 'TomGeneratedQuery').distinct,
      'orderBy': (visitor, target) => D4.validateTarget<TomGeneratedQuery>(target, 'TomGeneratedQuery').orderBy,
      'ascending': (visitor, target) => D4.validateTarget<TomGeneratedQuery>(target, 'TomGeneratedQuery').ascending,
      'top': (visitor, target) => D4.validateTarget<TomGeneratedQuery>(target, 'TomGeneratedQuery').top,
    },
    setters: {
      'types': (visitor, target, value) => 
        D4.validateTarget<TomGeneratedQuery>(target, 'TomGeneratedQuery').types = (value as List).cast<Type>().toList(),
    },
    methods: {
      'getColumnInformation': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomGeneratedQuery>(target, 'TomGeneratedQuery');
        return t.getColumnInformation();
      },
      'determineColumn': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomGeneratedQuery>(target, 'TomGeneratedQuery');
        D4.requireMinArgs(positional, 1, 'determineColumn');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'determineColumn');
        return t.determineColumn(name);
      },
      'generateQuery': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomGeneratedQuery>(target, 'TomGeneratedQuery');
        D4.requireMinArgs(positional, 1, 'generateQuery');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generateQuery');
        return t.generateQuery(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomGeneratedQuery>(target, 'TomGeneratedQuery');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomGeneratedQuery>(target, 'TomGeneratedQuery');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomGeneratedQuery>(target, 'TomGeneratedQuery');
        return t.toString();
      },
    },
    methodSignatures: {
      'getColumnInformation': 'List<TomColumnInformation> getColumnInformation()',
      'determineColumn': 'TomColumnInformation determineColumn(String name)',
      'generateQuery': 'String generateQuery(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
    },
    getterSignatures: {
      'types': 'List<Type> get types',
      'persistenceInfo': 'List<TomTypePersistenceInfo> get persistenceInfo',
      'query': 'TomOperator<TomDbBool> get query',
      'ignoreFields': 'List<String> get ignoreFields',
      'distinct': 'bool get distinct',
      'orderBy': 'List<String> get orderBy',
      'ascending': 'bool get ascending',
      'top': 'int get top',
    },
    setterSignatures: {
      'types': 'set types(List<Type> value)',
    },
  );
}

// =============================================================================
// TomSelect Bridge
// =============================================================================

BridgedClass _createTomSelectBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_6.TomSelect,
    name: 'TomSelect',
    isAssignable: (v) => v is $tom_core_server_6.TomSelect,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomSelect');
        if (positional.isEmpty) {
          throw ArgumentError('TomSelect: Missing required argument "types" at position 0');
        }
        final types = D4.coerceList<Type>(positional[0], 'types');
        final query = D4.getRequiredNamedArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbBool>>(named, 'query', 'TomSelect');
        final distinct = D4.getNamedArgWithDefault<bool>(named, 'distinct', false);
        final orderBy = named.containsKey('orderBy') && named['orderBy'] != null
            ? D4.coerceList<String>(named['orderBy'], 'orderBy')
            : const <String>[];
        final ascending = D4.getNamedArgWithDefault<bool>(named, 'ascending', true);
        final top = D4.getNamedArgWithDefault<int>(named, 'top', 0);
        final ignoreFields = named.containsKey('ignoreFields') && named['ignoreFields'] != null
            ? D4.coerceList<String>(named['ignoreFields'], 'ignoreFields')
            : const <String>[];
        return $tom_core_server_6.TomSelect(types, query: query, distinct: distinct, orderBy: orderBy, ascending: ascending, top: top, ignoreFields: ignoreFields);
      },
    },
    getters: {
      'types': (visitor, target) => D4.validateTarget<$tom_core_server_6.TomSelect>(target, 'TomSelect').types,
      'persistenceInfo': (visitor, target) => D4.validateTarget<$tom_core_server_6.TomSelect>(target, 'TomSelect').persistenceInfo,
      'query': (visitor, target) => D4.validateTarget<$tom_core_server_6.TomSelect>(target, 'TomSelect').query,
      'ignoreFields': (visitor, target) => D4.validateTarget<$tom_core_server_6.TomSelect>(target, 'TomSelect').ignoreFields,
      'distinct': (visitor, target) => D4.validateTarget<$tom_core_server_6.TomSelect>(target, 'TomSelect').distinct,
      'orderBy': (visitor, target) => D4.validateTarget<$tom_core_server_6.TomSelect>(target, 'TomSelect').orderBy,
      'ascending': (visitor, target) => D4.validateTarget<$tom_core_server_6.TomSelect>(target, 'TomSelect').ascending,
      'top': (visitor, target) => D4.validateTarget<$tom_core_server_6.TomSelect>(target, 'TomSelect').top,
    },
    setters: {
      'types': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_6.TomSelect>(target, 'TomSelect').types = (value as List).cast<Type>().toList(),
    },
    methods: {
      'getColumnInformation': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_6.TomSelect>(target, 'TomSelect');
        return t.getColumnInformation();
      },
      'determineColumn': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_6.TomSelect>(target, 'TomSelect');
        D4.requireMinArgs(positional, 1, 'determineColumn');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'determineColumn');
        return t.determineColumn(name);
      },
      'generateQuery': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_6.TomSelect>(target, 'TomSelect');
        D4.requireMinArgs(positional, 1, 'generateQuery');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generateQuery');
        return t.generateQuery(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_6.TomSelect>(target, 'TomSelect');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_6.TomSelect>(target, 'TomSelect');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_6.TomSelect>(target, 'TomSelect');
        return t.toString();
      },
    },
    constructorSignatures: {
      '': 'TomSelect(List<Type> types, {required TomOperator<TomDbBool> query, bool distinct = false, List<String> orderBy = const [], bool ascending = true, int top = 0, List<String> ignoreFields = const []})',
    },
    methodSignatures: {
      'getColumnInformation': 'List<TomColumnInformation> getColumnInformation()',
      'determineColumn': 'TomColumnInformation determineColumn(String name)',
      'generateQuery': 'String generateQuery(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
    },
    getterSignatures: {
      'types': 'List<Type> get types',
      'persistenceInfo': 'List<TomTypePersistenceInfo> get persistenceInfo',
      'query': 'TomOperator<TomDbBool> get query',
      'ignoreFields': 'List<String> get ignoreFields',
      'distinct': 'bool get distinct',
      'orderBy': 'List<String> get orderBy',
      'ascending': 'bool get ascending',
      'top': 'int get top',
    },
    setterSignatures: {
      'types': 'set types(List<Type> value)',
    },
  );
}

// =============================================================================
// TomLiteralSelect Bridge
// =============================================================================

BridgedClass _createTomLiteralSelectBridge() {
  return BridgedClass(
    nativeType: TomLiteralSelect,
    name: 'TomLiteralSelect',
    isAssignable: (v) => v is TomLiteralSelect,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomLiteralSelect');
        if (positional.isEmpty) {
          throw ArgumentError('TomLiteralSelect: Missing required argument "types" at position 0');
        }
        final types = D4.coerceList<Type>(positional[0], 'types');
        final query = D4.getRequiredNamedArg<String>(named, 'query', 'TomLiteralSelect');
        final parameters = named.containsKey('parameters') && named['parameters'] != null
            ? D4.coerceList<String>(named['parameters'], 'parameters')
            : const <String>[];
        return TomLiteralSelect(types, query: query, parameters: parameters);
      },
    },
    getters: {
      'types': (visitor, target) => D4.validateTarget<TomLiteralSelect>(target, 'TomLiteralSelect').types,
      'persistenceInfo': (visitor, target) => D4.validateTarget<TomLiteralSelect>(target, 'TomLiteralSelect').persistenceInfo,
      'query': (visitor, target) => D4.validateTarget<TomLiteralSelect>(target, 'TomLiteralSelect').query,
      'parameters': (visitor, target) => D4.validateTarget<TomLiteralSelect>(target, 'TomLiteralSelect').parameters,
    },
    setters: {
      'types': (visitor, target, value) => 
        D4.validateTarget<TomLiteralSelect>(target, 'TomLiteralSelect').types = (value as List).cast<Type>().toList(),
    },
    methods: {
      'getColumnInformation': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomLiteralSelect>(target, 'TomLiteralSelect');
        return t.getColumnInformation();
      },
      'determineColumn': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomLiteralSelect>(target, 'TomLiteralSelect');
        D4.requireMinArgs(positional, 1, 'determineColumn');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'determineColumn');
        return t.determineColumn(name);
      },
      'generateQuery': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomLiteralSelect>(target, 'TomLiteralSelect');
        D4.requireMinArgs(positional, 1, 'generateQuery');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generateQuery');
        return t.generateQuery(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomLiteralSelect>(target, 'TomLiteralSelect');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomLiteralSelect>(target, 'TomLiteralSelect');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomLiteralSelect>(target, 'TomLiteralSelect');
        return t.toString();
      },
    },
    constructorSignatures: {
      '': 'TomLiteralSelect(List<Type> types, {required String query, List<String> parameters = const []})',
    },
    methodSignatures: {
      'getColumnInformation': 'List<TomColumnInformation> getColumnInformation()',
      'determineColumn': 'TomColumnInformation determineColumn(String name)',
      'generateQuery': 'String generateQuery(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
    },
    getterSignatures: {
      'types': 'List<Type> get types',
      'persistenceInfo': 'List<TomTypePersistenceInfo> get persistenceInfo',
      'query': 'String get query',
      'parameters': 'List<String> get parameters',
    },
    setterSignatures: {
      'types': 'set types(List<Type> value)',
    },
  );
}

// =============================================================================
// TomCount Bridge
// =============================================================================

BridgedClass _createTomCountBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_6.TomCount,
    name: 'TomCount',
    isAssignable: (v) => v is $tom_core_server_6.TomCount,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomCount');
        if (positional.isEmpty) {
          throw ArgumentError('TomCount: Missing required argument "types" at position 0');
        }
        final types = D4.coerceList<Type>(positional[0], 'types');
        final query = D4.getRequiredNamedArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbBool>>(named, 'query', 'TomCount');
        final distinct = D4.getNamedArgWithDefault<bool>(named, 'distinct', false);
        final orderBy = named.containsKey('orderBy') && named['orderBy'] != null
            ? D4.coerceList<String>(named['orderBy'], 'orderBy')
            : const <String>[];
        final ascending = D4.getNamedArgWithDefault<bool>(named, 'ascending', true);
        final top = D4.getNamedArgWithDefault<int>(named, 'top', 0);
        final ignoreFields = named.containsKey('ignoreFields') && named['ignoreFields'] != null
            ? D4.coerceList<String>(named['ignoreFields'], 'ignoreFields')
            : const <String>[];
        return $tom_core_server_6.TomCount(types, query: query, distinct: distinct, orderBy: orderBy, ascending: ascending, top: top, ignoreFields: ignoreFields);
      },
    },
    getters: {
      'types': (visitor, target) => D4.validateTarget<$tom_core_server_6.TomCount>(target, 'TomCount').types,
      'persistenceInfo': (visitor, target) => D4.validateTarget<$tom_core_server_6.TomCount>(target, 'TomCount').persistenceInfo,
      'query': (visitor, target) => D4.validateTarget<$tom_core_server_6.TomCount>(target, 'TomCount').query,
      'ignoreFields': (visitor, target) => D4.validateTarget<$tom_core_server_6.TomCount>(target, 'TomCount').ignoreFields,
      'distinct': (visitor, target) => D4.validateTarget<$tom_core_server_6.TomCount>(target, 'TomCount').distinct,
      'orderBy': (visitor, target) => D4.validateTarget<$tom_core_server_6.TomCount>(target, 'TomCount').orderBy,
      'ascending': (visitor, target) => D4.validateTarget<$tom_core_server_6.TomCount>(target, 'TomCount').ascending,
      'top': (visitor, target) => D4.validateTarget<$tom_core_server_6.TomCount>(target, 'TomCount').top,
    },
    setters: {
      'types': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_6.TomCount>(target, 'TomCount').types = (value as List).cast<Type>().toList(),
    },
    methods: {
      'getColumnInformation': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_6.TomCount>(target, 'TomCount');
        return t.getColumnInformation();
      },
      'determineColumn': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_6.TomCount>(target, 'TomCount');
        D4.requireMinArgs(positional, 1, 'determineColumn');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'determineColumn');
        return t.determineColumn(name);
      },
      'generateQuery': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_6.TomCount>(target, 'TomCount');
        D4.requireMinArgs(positional, 1, 'generateQuery');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generateQuery');
        return t.generateQuery(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_6.TomCount>(target, 'TomCount');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_6.TomCount>(target, 'TomCount');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_6.TomCount>(target, 'TomCount');
        return t.toString();
      },
    },
    constructorSignatures: {
      '': 'TomCount(List<Type> types, {required TomOperator<TomDbBool> query, bool distinct = false, List<String> orderBy = const [], bool ascending = true, int top = 0, List<String> ignoreFields = const []})',
    },
    methodSignatures: {
      'getColumnInformation': 'List<TomColumnInformation> getColumnInformation()',
      'determineColumn': 'TomColumnInformation determineColumn(String name)',
      'generateQuery': 'String generateQuery(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
    },
    getterSignatures: {
      'types': 'List<Type> get types',
      'persistenceInfo': 'List<TomTypePersistenceInfo> get persistenceInfo',
      'query': 'TomOperator<TomDbBool> get query',
      'ignoreFields': 'List<String> get ignoreFields',
      'distinct': 'bool get distinct',
      'orderBy': 'List<String> get orderBy',
      'ascending': 'bool get ascending',
      'top': 'int get top',
    },
    setterSignatures: {
      'types': 'set types(List<Type> value)',
    },
  );
}

// =============================================================================
// TomDelete Bridge
// =============================================================================

BridgedClass _createTomDeleteBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_6.TomDelete,
    name: 'TomDelete',
    isAssignable: (v) => v is $tom_core_server_6.TomDelete,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomDelete');
        if (positional.isEmpty) {
          throw ArgumentError('TomDelete: Missing required argument "types" at position 0');
        }
        final types = D4.coerceList<Type>(positional[0], 'types');
        final query = D4.getRequiredNamedArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbBool>>(named, 'query', 'TomDelete');
        final distinct = D4.getNamedArgWithDefault<bool>(named, 'distinct', false);
        final orderBy = named.containsKey('orderBy') && named['orderBy'] != null
            ? D4.coerceList<String>(named['orderBy'], 'orderBy')
            : const <String>[];
        final ascending = D4.getNamedArgWithDefault<bool>(named, 'ascending', true);
        final top = D4.getNamedArgWithDefault<int>(named, 'top', 0);
        final ignoreFields = named.containsKey('ignoreFields') && named['ignoreFields'] != null
            ? D4.coerceList<String>(named['ignoreFields'], 'ignoreFields')
            : const <String>[];
        return $tom_core_server_6.TomDelete(types, query: query, distinct: distinct, orderBy: orderBy, ascending: ascending, top: top, ignoreFields: ignoreFields);
      },
    },
    getters: {
      'types': (visitor, target) => D4.validateTarget<$tom_core_server_6.TomDelete>(target, 'TomDelete').types,
      'persistenceInfo': (visitor, target) => D4.validateTarget<$tom_core_server_6.TomDelete>(target, 'TomDelete').persistenceInfo,
      'query': (visitor, target) => D4.validateTarget<$tom_core_server_6.TomDelete>(target, 'TomDelete').query,
      'ignoreFields': (visitor, target) => D4.validateTarget<$tom_core_server_6.TomDelete>(target, 'TomDelete').ignoreFields,
      'distinct': (visitor, target) => D4.validateTarget<$tom_core_server_6.TomDelete>(target, 'TomDelete').distinct,
      'orderBy': (visitor, target) => D4.validateTarget<$tom_core_server_6.TomDelete>(target, 'TomDelete').orderBy,
      'ascending': (visitor, target) => D4.validateTarget<$tom_core_server_6.TomDelete>(target, 'TomDelete').ascending,
      'top': (visitor, target) => D4.validateTarget<$tom_core_server_6.TomDelete>(target, 'TomDelete').top,
    },
    setters: {
      'types': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_6.TomDelete>(target, 'TomDelete').types = (value as List).cast<Type>().toList(),
    },
    methods: {
      'getColumnInformation': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_6.TomDelete>(target, 'TomDelete');
        return t.getColumnInformation();
      },
      'determineColumn': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_6.TomDelete>(target, 'TomDelete');
        D4.requireMinArgs(positional, 1, 'determineColumn');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'determineColumn');
        return t.determineColumn(name);
      },
      'generateQuery': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_6.TomDelete>(target, 'TomDelete');
        D4.requireMinArgs(positional, 1, 'generateQuery');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generateQuery');
        return t.generateQuery(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_6.TomDelete>(target, 'TomDelete');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_6.TomDelete>(target, 'TomDelete');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_6.TomDelete>(target, 'TomDelete');
        return t.toString();
      },
    },
    constructorSignatures: {
      '': 'TomDelete(List<Type> types, {required TomOperator<TomDbBool> query, bool distinct = false, List<String> orderBy = const [], bool ascending = true, int top = 0, List<String> ignoreFields = const []})',
    },
    methodSignatures: {
      'getColumnInformation': 'List<TomColumnInformation> getColumnInformation()',
      'determineColumn': 'TomColumnInformation determineColumn(String name)',
      'generateQuery': 'String generateQuery(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
    },
    getterSignatures: {
      'types': 'List<Type> get types',
      'persistenceInfo': 'List<TomTypePersistenceInfo> get persistenceInfo',
      'query': 'TomOperator<TomDbBool> get query',
      'ignoreFields': 'List<String> get ignoreFields',
      'distinct': 'bool get distinct',
      'orderBy': 'List<String> get orderBy',
      'ascending': 'bool get ascending',
      'top': 'int get top',
    },
    setterSignatures: {
      'types': 'set types(List<Type> value)',
    },
  );
}

// =============================================================================
// TomStandardSqlDialect Bridge
// =============================================================================

BridgedClass _createTomStandardSqlDialectBridge() {
  return BridgedClass(
    nativeType: $aux_aux.TomStandardSqlDialect,
    name: 'TomStandardSqlDialect',
    isAssignable: (v) => v is $aux_aux.TomStandardSqlDialect,
    constructors: {
      '': (visitor, positional, named) {
        return $aux_aux.TomStandardSqlDialect();
      },
    },
    methods: {
      'isNull': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$aux_aux.TomStandardSqlDialect>(target, 'TomStandardSqlDialect');
        D4.requireMinArgs(positional, 1, 'isNull');
        final what = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'what', 'isNull');
        return t.isNull(what);
      },
      'isNotNull': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$aux_aux.TomStandardSqlDialect>(target, 'TomStandardSqlDialect');
        D4.requireMinArgs(positional, 1, 'isNotNull');
        final what = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'what', 'isNotNull');
        return t.isNotNull(what);
      },
      'isin': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$aux_aux.TomStandardSqlDialect>(target, 'TomStandardSqlDialect');
        D4.requireMinArgs(positional, 2, 'isin');
        final what = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'what', 'isin');
        if (positional.length <= 1) {
          throw ArgumentError('isin: Missing required argument "choices" at position 1');
        }
        final choices = D4.coerceList<$tom_core_server_8.TomOperator<dynamic>>(positional[1], 'choices');
        return t.isin(what, choices);
      },
      'between': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$aux_aux.TomStandardSqlDialect>(target, 'TomStandardSqlDialect');
        D4.requireMinArgs(positional, 2, 'between');
        final what = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'what', 'between');
        if (positional.length <= 1) {
          throw ArgumentError('between: Missing required argument "betweenLimits" at position 1');
        }
        final betweenLimits = D4.coerceList<$tom_core_server_8.TomOperator<dynamic>>(positional[1], 'betweenLimits');
        return t.between(what, betweenLimits);
      },
      'like': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$aux_aux.TomStandardSqlDialect>(target, 'TomStandardSqlDialect');
        D4.requireMinArgs(positional, 2, 'like');
        final text = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 0, 'text', 'like');
        final test = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 1, 'test', 'like');
        return t.like(text, test);
      },
      'notLike': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$aux_aux.TomStandardSqlDialect>(target, 'TomStandardSqlDialect');
        D4.requireMinArgs(positional, 2, 'notLike');
        final text = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 0, 'text', 'notLike');
        final test = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 1, 'test', 'notLike');
        return t.notLike(text, test);
      },
      'regexp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$aux_aux.TomStandardSqlDialect>(target, 'TomStandardSqlDialect');
        D4.requireMinArgs(positional, 2, 'regexp');
        final text = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 0, 'text', 'regexp');
        final test = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 1, 'test', 'regexp');
        return t.regexp(text, test);
      },
      'group': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$aux_aux.TomStandardSqlDialect>(target, 'TomStandardSqlDialect');
        D4.requireMinArgs(positional, 1, 'group');
        final operant = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant', 'group');
        return t.group(operant);
      },
      'eq': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$aux_aux.TomStandardSqlDialect>(target, 'TomStandardSqlDialect');
        D4.requireMinArgs(positional, 2, 'eq');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'eq');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'eq');
        return t.eq(operant1, operant2);
      },
      'neq': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$aux_aux.TomStandardSqlDialect>(target, 'TomStandardSqlDialect');
        D4.requireMinArgs(positional, 2, 'neq');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'neq');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'neq');
        return t.neq(operant1, operant2);
      },
      'lt': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$aux_aux.TomStandardSqlDialect>(target, 'TomStandardSqlDialect');
        D4.requireMinArgs(positional, 2, 'lt');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'lt');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'lt');
        return t.lt(operant1, operant2);
      },
      'lte': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$aux_aux.TomStandardSqlDialect>(target, 'TomStandardSqlDialect');
        D4.requireMinArgs(positional, 2, 'lte');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'lte');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'lte');
        return t.lte(operant1, operant2);
      },
      'gt': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$aux_aux.TomStandardSqlDialect>(target, 'TomStandardSqlDialect');
        D4.requireMinArgs(positional, 2, 'gt');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'gt');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'gt');
        return t.gt(operant1, operant2);
      },
      'gte': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$aux_aux.TomStandardSqlDialect>(target, 'TomStandardSqlDialect');
        D4.requireMinArgs(positional, 2, 'gte');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'gte');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'gte');
        return t.gte(operant1, operant2);
      },
      'not': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$aux_aux.TomStandardSqlDialect>(target, 'TomStandardSqlDialect');
        D4.requireMinArgs(positional, 1, 'not');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbBool>>(positional, 0, 'operant1', 'not');
        return t.not(operant1);
      },
      'and': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$aux_aux.TomStandardSqlDialect>(target, 'TomStandardSqlDialect');
        D4.requireMinArgs(positional, 1, 'and');
        if (positional.isEmpty) {
          throw ArgumentError('and: Missing required argument "operant1" at position 0');
        }
        final operant1 = D4.coerceList<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbBool>>(positional[0], 'operant1');
        return t.and(operant1);
      },
      'or': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$aux_aux.TomStandardSqlDialect>(target, 'TomStandardSqlDialect');
        D4.requireMinArgs(positional, 1, 'or');
        if (positional.isEmpty) {
          throw ArgumentError('or: Missing required argument "operant1" at position 0');
        }
        final operant1 = D4.coerceList<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbBool>>(positional[0], 'operant1');
        return t.or(operant1);
      },
      'text': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$aux_aux.TomStandardSqlDialect>(target, 'TomStandardSqlDialect');
        D4.requireMinArgs(positional, 1, 'text');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'text');
        return t.text(text);
      },
      'intOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$aux_aux.TomStandardSqlDialect>(target, 'TomStandardSqlDialect');
        D4.requireMinArgs(positional, 1, 'intOp');
        final value = D4.getRequiredArg<int>(positional, 0, 'value', 'intOp');
        return t.intOp(value);
      },
      'doubleOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$aux_aux.TomStandardSqlDialect>(target, 'TomStandardSqlDialect');
        D4.requireMinArgs(positional, 1, 'doubleOp');
        final value = D4.getRequiredArg<double>(positional, 0, 'value', 'doubleOp');
        return t.doubleOp(value);
      },
      'boolOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$aux_aux.TomStandardSqlDialect>(target, 'TomStandardSqlDialect');
        D4.requireMinArgs(positional, 1, 'boolOp');
        final value = D4.getRequiredArg<bool>(positional, 0, 'value', 'boolOp');
        return t.boolOp(value);
      },
      'dateTimeOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$aux_aux.TomStandardSqlDialect>(target, 'TomStandardSqlDialect');
        D4.requireMinArgs(positional, 1, 'dateTimeOp');
        final value = D4.getRequiredArg<DateTime>(positional, 0, 'value', 'dateTimeOp');
        return t.dateTimeOp(value);
      },
      'dateOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$aux_aux.TomStandardSqlDialect>(target, 'TomStandardSqlDialect');
        D4.requireMinArgs(positional, 1, 'dateOp');
        final value = D4.getRequiredArg<DateTime>(positional, 0, 'value', 'dateOp');
        return t.dateOp(value);
      },
      'iterableOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$aux_aux.TomStandardSqlDialect>(target, 'TomStandardSqlDialect');
        D4.requireMinArgs(positional, 1, 'iterableOp');
        final values = D4.getRequiredArg<Iterable>(positional, 0, 'values', 'iterableOp');
        return t.iterableOp(values);
      },
      'nullOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$aux_aux.TomStandardSqlDialect>(target, 'TomStandardSqlDialect');
        return t.nullOp();
      },
      'objectOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$aux_aux.TomStandardSqlDialect>(target, 'TomStandardSqlDialect');
        D4.requireMinArgs(positional, 1, 'objectOp');
        final o = D4.getRequiredArg<Object?>(positional, 0, 'o', 'objectOp');
        return t.objectOp(o);
      },
      'p': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$aux_aux.TomStandardSqlDialect>(target, 'TomStandardSqlDialect');
        D4.requireMinArgs(positional, 1, 'p');
        final parameterName = D4.getRequiredArg<String>(positional, 0, 'parameterName', 'p');
        return t.p(parameterName);
      },
      'textF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$aux_aux.TomStandardSqlDialect>(target, 'TomStandardSqlDialect');
        D4.requireMinArgs(positional, 3, 'textF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'textF');
        final column = D4.getRequiredArg<$tom_core_server_14.DbCol>(positional, 1, 'column', 'textF');
        final dbType = D4.getRequiredArg<Type>(positional, 2, 'dbType', 'textF');
        return t.textF(fieldName, column, dbType);
      },
      'intF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$aux_aux.TomStandardSqlDialect>(target, 'TomStandardSqlDialect');
        D4.requireMinArgs(positional, 3, 'intF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'intF');
        final column = D4.getRequiredArg<$tom_core_server_14.DbCol>(positional, 1, 'column', 'intF');
        final dbType = D4.getRequiredArg<Type>(positional, 2, 'dbType', 'intF');
        return t.intF(fieldName, column, dbType);
      },
      'doubleF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$aux_aux.TomStandardSqlDialect>(target, 'TomStandardSqlDialect');
        D4.requireMinArgs(positional, 3, 'doubleF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'doubleF');
        final column = D4.getRequiredArg<$tom_core_server_14.DbCol>(positional, 1, 'column', 'doubleF');
        final dbType = D4.getRequiredArg<Type>(positional, 2, 'dbType', 'doubleF');
        return t.doubleF(fieldName, column, dbType);
      },
      'boolF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$aux_aux.TomStandardSqlDialect>(target, 'TomStandardSqlDialect');
        D4.requireMinArgs(positional, 3, 'boolF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'boolF');
        final column = D4.getRequiredArg<$tom_core_server_14.DbCol>(positional, 1, 'column', 'boolF');
        final dbType = D4.getRequiredArg<Type>(positional, 2, 'dbType', 'boolF');
        return t.boolF(fieldName, column, dbType);
      },
      'dateTimeF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$aux_aux.TomStandardSqlDialect>(target, 'TomStandardSqlDialect');
        D4.requireMinArgs(positional, 3, 'dateTimeF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'dateTimeF');
        final column = D4.getRequiredArg<$tom_core_server_14.DbCol>(positional, 1, 'column', 'dateTimeF');
        final dbType = D4.getRequiredArg<Type>(positional, 2, 'dbType', 'dateTimeF');
        return t.dateTimeF(fieldName, column, dbType);
      },
      'dateF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$aux_aux.TomStandardSqlDialect>(target, 'TomStandardSqlDialect');
        D4.requireMinArgs(positional, 3, 'dateF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'dateF');
        final column = D4.getRequiredArg<$tom_core_server_14.DbCol>(positional, 1, 'column', 'dateF');
        final dbType = D4.getRequiredArg<Type>(positional, 2, 'dbType', 'dateF');
        return t.dateF(fieldName, column, dbType);
      },
    },
    constructorSignatures: {
      '': 'TomStandardSqlDialect()',
    },
    methodSignatures: {
      'isNull': 'SqlString isNull(TomOperator<T> what)',
      'isNotNull': 'SqlString isNotNull(TomOperator<T> what)',
      'isin': 'SqlString isin(TomOperator<T> what, List<TomOperator<T>> choices)',
      'between': 'SqlString between(TomOperator<T> what, List<TomOperator<T>> betweenLimits)',
      'like': 'SqlString like(TomOperator<TomDbString> text, TomOperator<TomDbString> test)',
      'notLike': 'SqlString notLike(TomOperator<TomDbString> text, TomOperator<TomDbString> test)',
      'regexp': 'SqlString regexp(TomOperator<TomDbString> text, TomOperator<TomDbString> test)',
      'group': 'SqlString group(TomOperator<T> operant)',
      'eq': 'SqlString eq(TomOperator<T> operant1, TomOperator<T> operant2)',
      'neq': 'SqlString neq(TomOperator<T> operant1, TomOperator<T> operant2)',
      'lt': 'SqlString lt(TomOperator<T> operant1, TomOperator<T> operant2)',
      'lte': 'SqlString lte(TomOperator<T> operant1, TomOperator<T> operant2)',
      'gt': 'SqlString gt(TomOperator<T> operant1, TomOperator<T> operant2)',
      'gte': 'SqlString gte(TomOperator<T> operant1, TomOperator<T> operant2)',
      'not': 'SqlString not(TomOperator<TomDbBool> operant1)',
      'and': 'SqlString and(List<TomOperator<TomDbBool>> operant1)',
      'or': 'SqlString or(List<TomOperator<TomDbBool>> operant1)',
      'text': 'SqlString text(String text)',
      'intOp': 'SqlString intOp(int value)',
      'doubleOp': 'SqlString doubleOp(double value)',
      'boolOp': 'SqlString boolOp(bool value)',
      'dateTimeOp': 'SqlString dateTimeOp(DateTime value)',
      'dateOp': 'SqlString dateOp(DateTime value)',
      'iterableOp': 'SqlString iterableOp(Iterable values)',
      'nullOp': 'SqlString nullOp()',
      'objectOp': 'SqlString objectOp(Object? o)',
      'p': 'SqlString p(String parameterName)',
      'textF': 'SqlString textF(String fieldName, DbCol column, Type dbType)',
      'intF': 'SqlString intF(String fieldName, DbCol column, Type dbType)',
      'doubleF': 'SqlString doubleF(String fieldName, DbCol column, Type dbType)',
      'boolF': 'SqlString boolF(String fieldName, DbCol column, Type dbType)',
      'dateTimeF': 'SqlString dateTimeF(String fieldName, DbCol column, Type dbType)',
      'dateF': 'SqlString dateF(String fieldName, DbCol column, Type dbType)',
    },
  );
}

// =============================================================================
// TomSqlDialect Bridge
// =============================================================================

BridgedClass _createTomSqlDialectBridge() {
  return BridgedClass(
    nativeType: $aux_aux.TomSqlDialect,
    name: 'TomSqlDialect',
    isAssignable: (v) => v is $aux_aux.TomSqlDialect,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomSqlDialect');
        final dataSourceType = D4.getRequiredArg<String>(positional, 0, 'dataSourceType', 'TomSqlDialect');
        return $aux_aux.TomSqlDialect(dataSourceType);
      },
    },
    getters: {
      'dataSourceType': (visitor, target) => D4.validateTarget<$aux_aux.TomSqlDialect>(target, 'TomSqlDialect').dataSourceType,
    },
    constructorSignatures: {
      '': 'const TomSqlDialect(String dataSourceType)',
    },
    getterSignatures: {
      'dataSourceType': 'String get dataSourceType',
    },
  );
}

// =============================================================================
// TomDbType Bridge
// =============================================================================

BridgedClass _createTomDbTypeBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_8.TomDbType,
    name: 'TomDbType',
    isAssignable: (v) => v is $tom_core_server_8.TomDbType,
    constructors: {
    },
    getters: {
      'isNull': (visitor, target) => D4.validateTarget<$tom_core_server_8.TomDbType>(target, 'TomDbType').isNull,
      'isMuted': (visitor, target) => D4.validateTarget<$tom_core_server_8.TomDbType>(target, 'TomDbType').isMuted,
    },
    methods: {
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbType>(target, 'TomDbType');
        return t.toString();
      },
      'getType': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbType>(target, 'TomDbType');
        return t.getType();
      },
      'get': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbType>(target, 'TomDbType');
        return t.get();
      },
      'set': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbType>(target, 'TomDbType');
        D4.requireMinArgs(positional, 1, 'set');
        final value = D4.getRequiredArg<dynamic>(positional, 0, 'value', 'set');
        return t.set(value);
      },
      'getOrNull': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbType>(target, 'TomDbType');
        return t.getOrNull();
      },
      'call': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbType>(target, 'TomDbType');
        return t.call();
      },
      'mute': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbType>(target, 'TomDbType');
        t.mute();
        return null;
      },
      'unmute': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbType>(target, 'TomDbType');
        t.unmute();
        return null;
      },
      'addObserver': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbType>(target, 'TomDbType');
        D4.requireMinArgs(positional, 1, 'addObserver');
        final observer = D4.getRequiredArg<$tom_core_kernel_5.TomObserver<$tom_core_kernel_5.TomObservable>>(positional, 0, 'observer', 'addObserver');
        t.addObserver(observer);
        return null;
      },
      'removeObserver': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbType>(target, 'TomDbType');
        D4.requireMinArgs(positional, 1, 'removeObserver');
        final observer = D4.getRequiredArg<$tom_core_kernel_5.TomObserver<$tom_core_kernel_5.TomObservable>>(positional, 0, 'observer', 'removeObserver');
        t.removeObserver(observer);
        return null;
      },
      'notifyObservers': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbType>(target, 'TomDbType');
        final message = D4.getOptionalArg<dynamic>(positional, 0, 'message');
        t.notifyObservers(message);
        return null;
      },
      '~': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbType>(target, 'TomDbType');
        return ~t;
      },
      '|': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbType>(target, 'TomDbType');
        final other = D4.getRequiredArg<dynamic>(positional, 0, 'other', 'operator|');
        return t | other;
      },
      '<<': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbType>(target, 'TomDbType');
        final other = D4.getRequiredArg<dynamic>(positional, 0, 'other', 'operator<<');
        return t << other;
      },
      '>>': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbType>(target, 'TomDbType');
        final other = D4.getRequiredArg<void Function($tom_core_kernel_5.TomObservable)>(positional, 0, 'other', 'operator>>');
        return t >> other;
      },
    },
    methodSignatures: {
      'toString': 'String toString()',
      'getType': 'Type getType()',
      'get': 'T get()',
      'set': 'T set(T value)',
      'getOrNull': 'T? getOrNull()',
      'call': 'T call()',
      'mute': 'void mute()',
      'unmute': 'void unmute()',
      'addObserver': 'void addObserver(TomObserver<TomObservable> observer)',
      'removeObserver': 'void removeObserver(TomObserver<TomObservable> observer)',
      'notifyObservers': 'void notifyObservers([dynamic message])',
    },
    getterSignatures: {
      'isNull': 'bool get isNull',
      'isMuted': 'bool get isMuted',
    },
  );
}

// =============================================================================
// TomDbInt Bridge
// =============================================================================

BridgedClass _createTomDbIntBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_8.TomDbInt,
    name: 'TomDbInt',
    isAssignable: (v) => v is $tom_core_server_8.TomDbInt,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomDbInt');
        final value = D4.getRequiredArg<int?>(positional, 0, 'value', 'TomDbInt');
        return $tom_core_server_8.TomDbInt(value);
      },
    },
    getters: {
      'isNull': (visitor, target) => D4.validateTarget<$tom_core_server_8.TomDbInt>(target, 'TomDbInt').isNull,
      'isMuted': (visitor, target) => D4.validateTarget<$tom_core_server_8.TomDbInt>(target, 'TomDbInt').isMuted,
    },
    methods: {
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbInt>(target, 'TomDbInt');
        return t.toString();
      },
      'getType': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbInt>(target, 'TomDbInt');
        return t.getType();
      },
      'get': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbInt>(target, 'TomDbInt');
        return t.get();
      },
      'set': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbInt>(target, 'TomDbInt');
        D4.requireMinArgs(positional, 1, 'set');
        final value = D4.getRequiredArg<int?>(positional, 0, 'value', 'set');
        return t.set(value);
      },
      'getOrNull': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbInt>(target, 'TomDbInt');
        return t.getOrNull();
      },
      'call': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbInt>(target, 'TomDbInt');
        return t.call();
      },
      'mute': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbInt>(target, 'TomDbInt');
        t.mute();
        return null;
      },
      'unmute': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbInt>(target, 'TomDbInt');
        t.unmute();
        return null;
      },
      'addObserver': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbInt>(target, 'TomDbInt');
        D4.requireMinArgs(positional, 1, 'addObserver');
        final observer = D4.getRequiredArg<$tom_core_kernel_5.TomObserver<$tom_core_kernel_5.TomObservable>>(positional, 0, 'observer', 'addObserver');
        t.addObserver(observer);
        return null;
      },
      'removeObserver': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbInt>(target, 'TomDbInt');
        D4.requireMinArgs(positional, 1, 'removeObserver');
        final observer = D4.getRequiredArg<$tom_core_kernel_5.TomObserver<$tom_core_kernel_5.TomObservable>>(positional, 0, 'observer', 'removeObserver');
        t.removeObserver(observer);
        return null;
      },
      'notifyObservers': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbInt>(target, 'TomDbInt');
        final message = D4.getOptionalArg<dynamic>(positional, 0, 'message');
        t.notifyObservers(message);
        return null;
      },
      '~': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbInt>(target, 'TomDbInt');
        return ~t;
      },
      '|': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbInt>(target, 'TomDbInt');
        final other = D4.getRequiredArg<int?>(positional, 0, 'other', 'operator|');
        return t | other;
      },
      '<<': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbInt>(target, 'TomDbInt');
        final other = D4.getRequiredArg<int?>(positional, 0, 'other', 'operator<<');
        return t << other;
      },
      '>>': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbInt>(target, 'TomDbInt');
        final other = D4.getRequiredArg<void Function($tom_core_kernel_5.TomObservable)>(positional, 0, 'other', 'operator>>');
        return t >> other;
      },
    },
    staticMethods: {
      'of': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'of');
        final s = D4.getRequiredArg<String?>(positional, 0, 's', 'of');
        return $tom_core_server_8.TomDbInt.of(s);
      },
    },
    constructorSignatures: {
      '': 'TomDbInt(int? value)',
    },
    methodSignatures: {
      'toString': 'String toString()',
      'getType': 'Type getType()',
      'get': 'int? get()',
      'set': 'int? set(int? value)',
      'getOrNull': 'int? getOrNull()',
      'call': 'int? call()',
      'mute': 'void mute()',
      'unmute': 'void unmute()',
      'addObserver': 'void addObserver(TomObserver<TomObservable> observer)',
      'removeObserver': 'void removeObserver(TomObserver<TomObservable> observer)',
      'notifyObservers': 'void notifyObservers([dynamic message])',
    },
    getterSignatures: {
      'isNull': 'bool get isNull',
      'isMuted': 'bool get isMuted',
    },
    staticMethodSignatures: {
      'of': 'TomDbInt of(String? s)',
    },
  );
}

// =============================================================================
// TomDbDouble Bridge
// =============================================================================

BridgedClass _createTomDbDoubleBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_8.TomDbDouble,
    name: 'TomDbDouble',
    isAssignable: (v) => v is $tom_core_server_8.TomDbDouble,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomDbDouble');
        final value = D4.getRequiredArg<double?>(positional, 0, 'value', 'TomDbDouble');
        return $tom_core_server_8.TomDbDouble(value);
      },
    },
    getters: {
      'isNull': (visitor, target) => D4.validateTarget<$tom_core_server_8.TomDbDouble>(target, 'TomDbDouble').isNull,
      'isMuted': (visitor, target) => D4.validateTarget<$tom_core_server_8.TomDbDouble>(target, 'TomDbDouble').isMuted,
    },
    methods: {
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDouble>(target, 'TomDbDouble');
        return t.toString();
      },
      'getType': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDouble>(target, 'TomDbDouble');
        return t.getType();
      },
      'get': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDouble>(target, 'TomDbDouble');
        return t.get();
      },
      'set': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDouble>(target, 'TomDbDouble');
        D4.requireMinArgs(positional, 1, 'set');
        final value = D4.getRequiredArg<double?>(positional, 0, 'value', 'set');
        return t.set(value);
      },
      'getOrNull': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDouble>(target, 'TomDbDouble');
        return t.getOrNull();
      },
      'call': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDouble>(target, 'TomDbDouble');
        return t.call();
      },
      'mute': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDouble>(target, 'TomDbDouble');
        t.mute();
        return null;
      },
      'unmute': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDouble>(target, 'TomDbDouble');
        t.unmute();
        return null;
      },
      'addObserver': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDouble>(target, 'TomDbDouble');
        D4.requireMinArgs(positional, 1, 'addObserver');
        final observer = D4.getRequiredArg<$tom_core_kernel_5.TomObserver<$tom_core_kernel_5.TomObservable>>(positional, 0, 'observer', 'addObserver');
        t.addObserver(observer);
        return null;
      },
      'removeObserver': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDouble>(target, 'TomDbDouble');
        D4.requireMinArgs(positional, 1, 'removeObserver');
        final observer = D4.getRequiredArg<$tom_core_kernel_5.TomObserver<$tom_core_kernel_5.TomObservable>>(positional, 0, 'observer', 'removeObserver');
        t.removeObserver(observer);
        return null;
      },
      'notifyObservers': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDouble>(target, 'TomDbDouble');
        final message = D4.getOptionalArg<dynamic>(positional, 0, 'message');
        t.notifyObservers(message);
        return null;
      },
      '~': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDouble>(target, 'TomDbDouble');
        return ~t;
      },
      '|': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDouble>(target, 'TomDbDouble');
        final other = D4.getRequiredArg<double?>(positional, 0, 'other', 'operator|');
        return t | other;
      },
      '<<': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDouble>(target, 'TomDbDouble');
        final other = D4.getRequiredArg<double?>(positional, 0, 'other', 'operator<<');
        return t << other;
      },
      '>>': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDouble>(target, 'TomDbDouble');
        final other = D4.getRequiredArg<void Function($tom_core_kernel_5.TomObservable)>(positional, 0, 'other', 'operator>>');
        return t >> other;
      },
    },
    staticMethods: {
      'of': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'of');
        final s = D4.getRequiredArg<String?>(positional, 0, 's', 'of');
        return $tom_core_server_8.TomDbDouble.of(s);
      },
    },
    constructorSignatures: {
      '': 'TomDbDouble(double? value)',
    },
    methodSignatures: {
      'toString': 'String toString()',
      'getType': 'Type getType()',
      'get': 'double? get()',
      'set': 'double? set(double? value)',
      'getOrNull': 'double? getOrNull()',
      'call': 'double? call()',
      'mute': 'void mute()',
      'unmute': 'void unmute()',
      'addObserver': 'void addObserver(TomObserver<TomObservable> observer)',
      'removeObserver': 'void removeObserver(TomObserver<TomObservable> observer)',
      'notifyObservers': 'void notifyObservers([dynamic message])',
    },
    getterSignatures: {
      'isNull': 'bool get isNull',
      'isMuted': 'bool get isMuted',
    },
    staticMethodSignatures: {
      'of': 'TomDbDouble of(String? s)',
    },
  );
}

// =============================================================================
// TomDbString Bridge
// =============================================================================

BridgedClass _createTomDbStringBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_8.TomDbString,
    name: 'TomDbString',
    isAssignable: (v) => v is $tom_core_server_8.TomDbString,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomDbString');
        final value = D4.getRequiredArg<String?>(positional, 0, 'value', 'TomDbString');
        return $tom_core_server_8.TomDbString(value);
      },
    },
    getters: {
      'isNull': (visitor, target) => D4.validateTarget<$tom_core_server_8.TomDbString>(target, 'TomDbString').isNull,
      'isMuted': (visitor, target) => D4.validateTarget<$tom_core_server_8.TomDbString>(target, 'TomDbString').isMuted,
    },
    methods: {
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbString>(target, 'TomDbString');
        return t.toString();
      },
      'getType': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbString>(target, 'TomDbString');
        return t.getType();
      },
      'get': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbString>(target, 'TomDbString');
        return t.get();
      },
      'set': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbString>(target, 'TomDbString');
        D4.requireMinArgs(positional, 1, 'set');
        final value = D4.getRequiredArg<String?>(positional, 0, 'value', 'set');
        return t.set(value);
      },
      'getOrNull': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbString>(target, 'TomDbString');
        return t.getOrNull();
      },
      'call': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbString>(target, 'TomDbString');
        return t.call();
      },
      'mute': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbString>(target, 'TomDbString');
        t.mute();
        return null;
      },
      'unmute': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbString>(target, 'TomDbString');
        t.unmute();
        return null;
      },
      'addObserver': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbString>(target, 'TomDbString');
        D4.requireMinArgs(positional, 1, 'addObserver');
        final observer = D4.getRequiredArg<$tom_core_kernel_5.TomObserver<$tom_core_kernel_5.TomObservable>>(positional, 0, 'observer', 'addObserver');
        t.addObserver(observer);
        return null;
      },
      'removeObserver': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbString>(target, 'TomDbString');
        D4.requireMinArgs(positional, 1, 'removeObserver');
        final observer = D4.getRequiredArg<$tom_core_kernel_5.TomObserver<$tom_core_kernel_5.TomObservable>>(positional, 0, 'observer', 'removeObserver');
        t.removeObserver(observer);
        return null;
      },
      'notifyObservers': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbString>(target, 'TomDbString');
        final message = D4.getOptionalArg<dynamic>(positional, 0, 'message');
        t.notifyObservers(message);
        return null;
      },
      '~': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbString>(target, 'TomDbString');
        return ~t;
      },
      '|': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbString>(target, 'TomDbString');
        final other = D4.getRequiredArg<String?>(positional, 0, 'other', 'operator|');
        return t | other;
      },
      '<<': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbString>(target, 'TomDbString');
        final other = D4.getRequiredArg<String?>(positional, 0, 'other', 'operator<<');
        return t << other;
      },
      '>>': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbString>(target, 'TomDbString');
        final other = D4.getRequiredArg<void Function($tom_core_kernel_5.TomObservable)>(positional, 0, 'other', 'operator>>');
        return t >> other;
      },
    },
    staticMethods: {
      'of': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'of');
        final s = D4.getRequiredArg<String?>(positional, 0, 's', 'of');
        return $tom_core_server_8.TomDbString.of(s);
      },
    },
    constructorSignatures: {
      '': 'TomDbString(String? value)',
    },
    methodSignatures: {
      'toString': 'String toString()',
      'getType': 'Type getType()',
      'get': 'String? get()',
      'set': 'String? set(String? value)',
      'getOrNull': 'String? getOrNull()',
      'call': 'String? call()',
      'mute': 'void mute()',
      'unmute': 'void unmute()',
      'addObserver': 'void addObserver(TomObserver<TomObservable> observer)',
      'removeObserver': 'void removeObserver(TomObserver<TomObservable> observer)',
      'notifyObservers': 'void notifyObservers([dynamic message])',
    },
    getterSignatures: {
      'isNull': 'bool get isNull',
      'isMuted': 'bool get isMuted',
    },
    staticMethodSignatures: {
      'of': 'TomDbString of(String? s)',
    },
  );
}

// =============================================================================
// TomDbDateTime Bridge
// =============================================================================

BridgedClass _createTomDbDateTimeBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_8.TomDbDateTime,
    name: 'TomDbDateTime',
    isAssignable: (v) => v is $tom_core_server_8.TomDbDateTime,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomDbDateTime');
        final value = D4.getRequiredArg<DateTime?>(positional, 0, 'value', 'TomDbDateTime');
        return $tom_core_server_8.TomDbDateTime(value);
      },
    },
    getters: {
      'isNull': (visitor, target) => D4.validateTarget<$tom_core_server_8.TomDbDateTime>(target, 'TomDbDateTime').isNull,
      'isMuted': (visitor, target) => D4.validateTarget<$tom_core_server_8.TomDbDateTime>(target, 'TomDbDateTime').isMuted,
    },
    methods: {
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDateTime>(target, 'TomDbDateTime');
        return t.toString();
      },
      'getType': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDateTime>(target, 'TomDbDateTime');
        return t.getType();
      },
      'get': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDateTime>(target, 'TomDbDateTime');
        return t.get();
      },
      'set': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDateTime>(target, 'TomDbDateTime');
        D4.requireMinArgs(positional, 1, 'set');
        final value = D4.getRequiredArg<DateTime?>(positional, 0, 'value', 'set');
        return t.set(value);
      },
      'getOrNull': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDateTime>(target, 'TomDbDateTime');
        return t.getOrNull();
      },
      'call': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDateTime>(target, 'TomDbDateTime');
        return t.call();
      },
      'mute': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDateTime>(target, 'TomDbDateTime');
        t.mute();
        return null;
      },
      'unmute': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDateTime>(target, 'TomDbDateTime');
        t.unmute();
        return null;
      },
      'addObserver': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDateTime>(target, 'TomDbDateTime');
        D4.requireMinArgs(positional, 1, 'addObserver');
        final observer = D4.getRequiredArg<$tom_core_kernel_5.TomObserver<$tom_core_kernel_5.TomObservable>>(positional, 0, 'observer', 'addObserver');
        t.addObserver(observer);
        return null;
      },
      'removeObserver': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDateTime>(target, 'TomDbDateTime');
        D4.requireMinArgs(positional, 1, 'removeObserver');
        final observer = D4.getRequiredArg<$tom_core_kernel_5.TomObserver<$tom_core_kernel_5.TomObservable>>(positional, 0, 'observer', 'removeObserver');
        t.removeObserver(observer);
        return null;
      },
      'notifyObservers': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDateTime>(target, 'TomDbDateTime');
        final message = D4.getOptionalArg<dynamic>(positional, 0, 'message');
        t.notifyObservers(message);
        return null;
      },
      '~': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDateTime>(target, 'TomDbDateTime');
        return ~t;
      },
      '|': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDateTime>(target, 'TomDbDateTime');
        final other = D4.getRequiredArg<DateTime?>(positional, 0, 'other', 'operator|');
        return t | other;
      },
      '<<': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDateTime>(target, 'TomDbDateTime');
        final other = D4.getRequiredArg<DateTime?>(positional, 0, 'other', 'operator<<');
        return t << other;
      },
      '>>': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDateTime>(target, 'TomDbDateTime');
        final other = D4.getRequiredArg<void Function($tom_core_kernel_5.TomObservable)>(positional, 0, 'other', 'operator>>');
        return t >> other;
      },
    },
    staticMethods: {
      'of': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'of');
        final s = D4.getRequiredArg<String?>(positional, 0, 's', 'of');
        return $tom_core_server_8.TomDbDateTime.of(s);
      },
    },
    constructorSignatures: {
      '': 'TomDbDateTime(DateTime? value)',
    },
    methodSignatures: {
      'toString': 'String toString()',
      'getType': 'Type getType()',
      'get': 'DateTime? get()',
      'set': 'DateTime? set(DateTime? value)',
      'getOrNull': 'DateTime? getOrNull()',
      'call': 'DateTime? call()',
      'mute': 'void mute()',
      'unmute': 'void unmute()',
      'addObserver': 'void addObserver(TomObserver<TomObservable> observer)',
      'removeObserver': 'void removeObserver(TomObserver<TomObservable> observer)',
      'notifyObservers': 'void notifyObservers([dynamic message])',
    },
    getterSignatures: {
      'isNull': 'bool get isNull',
      'isMuted': 'bool get isMuted',
    },
    staticMethodSignatures: {
      'of': 'TomDbDateTime of(String? s)',
    },
  );
}

// =============================================================================
// TomDbDate Bridge
// =============================================================================

BridgedClass _createTomDbDateBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_8.TomDbDate,
    name: 'TomDbDate',
    isAssignable: (v) => v is $tom_core_server_8.TomDbDate,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomDbDate');
        final value = D4.getRequiredArg<$tom_core_kernel_10.TomZonedDate?>(positional, 0, 'value', 'TomDbDate');
        return $tom_core_server_8.TomDbDate(value);
      },
    },
    getters: {
      'isNull': (visitor, target) => D4.validateTarget<$tom_core_server_8.TomDbDate>(target, 'TomDbDate').isNull,
      'isMuted': (visitor, target) => D4.validateTarget<$tom_core_server_8.TomDbDate>(target, 'TomDbDate').isMuted,
    },
    methods: {
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDate>(target, 'TomDbDate');
        return t.toString();
      },
      'getType': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDate>(target, 'TomDbDate');
        return t.getType();
      },
      'get': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDate>(target, 'TomDbDate');
        return t.get();
      },
      'set': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDate>(target, 'TomDbDate');
        D4.requireMinArgs(positional, 1, 'set');
        final value = D4.getRequiredArg<$tom_core_kernel_10.TomZonedDate?>(positional, 0, 'value', 'set');
        return t.set(value);
      },
      'getOrNull': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDate>(target, 'TomDbDate');
        return t.getOrNull();
      },
      'call': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDate>(target, 'TomDbDate');
        return t.call();
      },
      'mute': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDate>(target, 'TomDbDate');
        t.mute();
        return null;
      },
      'unmute': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDate>(target, 'TomDbDate');
        t.unmute();
        return null;
      },
      'addObserver': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDate>(target, 'TomDbDate');
        D4.requireMinArgs(positional, 1, 'addObserver');
        final observer = D4.getRequiredArg<$tom_core_kernel_5.TomObserver<$tom_core_kernel_5.TomObservable>>(positional, 0, 'observer', 'addObserver');
        t.addObserver(observer);
        return null;
      },
      'removeObserver': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDate>(target, 'TomDbDate');
        D4.requireMinArgs(positional, 1, 'removeObserver');
        final observer = D4.getRequiredArg<$tom_core_kernel_5.TomObserver<$tom_core_kernel_5.TomObservable>>(positional, 0, 'observer', 'removeObserver');
        t.removeObserver(observer);
        return null;
      },
      'notifyObservers': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDate>(target, 'TomDbDate');
        final message = D4.getOptionalArg<dynamic>(positional, 0, 'message');
        t.notifyObservers(message);
        return null;
      },
      '~': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDate>(target, 'TomDbDate');
        return ~t;
      },
      '|': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDate>(target, 'TomDbDate');
        final other = D4.getRequiredArg<$tom_core_kernel_10.TomZonedDate?>(positional, 0, 'other', 'operator|');
        return t | other;
      },
      '<<': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDate>(target, 'TomDbDate');
        final other = D4.getRequiredArg<$tom_core_kernel_10.TomZonedDate?>(positional, 0, 'other', 'operator<<');
        return t << other;
      },
      '>>': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbDate>(target, 'TomDbDate');
        final other = D4.getRequiredArg<void Function($tom_core_kernel_5.TomObservable)>(positional, 0, 'other', 'operator>>');
        return t >> other;
      },
    },
    staticMethods: {
      'of': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'of');
        final s = D4.getRequiredArg<String?>(positional, 0, 's', 'of');
        return $tom_core_server_8.TomDbDate.of(s);
      },
    },
    constructorSignatures: {
      '': 'TomDbDate(TomZonedDate? value)',
    },
    methodSignatures: {
      'toString': 'String toString()',
      'getType': 'Type getType()',
      'get': 'TomZonedDate? get()',
      'set': 'TomZonedDate? set(TomZonedDate? value)',
      'getOrNull': 'TomZonedDate? getOrNull()',
      'call': 'TomZonedDate? call()',
      'mute': 'void mute()',
      'unmute': 'void unmute()',
      'addObserver': 'void addObserver(TomObserver<TomObservable> observer)',
      'removeObserver': 'void removeObserver(TomObserver<TomObservable> observer)',
      'notifyObservers': 'void notifyObservers([dynamic message])',
    },
    getterSignatures: {
      'isNull': 'bool get isNull',
      'isMuted': 'bool get isMuted',
    },
    staticMethodSignatures: {
      'of': 'TomDbDate of(String? s)',
    },
  );
}

// =============================================================================
// TomDbTime Bridge
// =============================================================================

BridgedClass _createTomDbTimeBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_8.TomDbTime,
    name: 'TomDbTime',
    isAssignable: (v) => v is $tom_core_server_8.TomDbTime,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomDbTime');
        final value = D4.getRequiredArg<$tom_core_kernel_10.TomZonedTime?>(positional, 0, 'value', 'TomDbTime');
        return $tom_core_server_8.TomDbTime(value);
      },
    },
    getters: {
      'isNull': (visitor, target) => D4.validateTarget<$tom_core_server_8.TomDbTime>(target, 'TomDbTime').isNull,
      'isMuted': (visitor, target) => D4.validateTarget<$tom_core_server_8.TomDbTime>(target, 'TomDbTime').isMuted,
    },
    methods: {
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbTime>(target, 'TomDbTime');
        return t.toString();
      },
      'getType': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbTime>(target, 'TomDbTime');
        return t.getType();
      },
      'get': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbTime>(target, 'TomDbTime');
        return t.get();
      },
      'set': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbTime>(target, 'TomDbTime');
        D4.requireMinArgs(positional, 1, 'set');
        final value = D4.getRequiredArg<$tom_core_kernel_10.TomZonedTime?>(positional, 0, 'value', 'set');
        return t.set(value);
      },
      'getOrNull': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbTime>(target, 'TomDbTime');
        return t.getOrNull();
      },
      'call': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbTime>(target, 'TomDbTime');
        return t.call();
      },
      'mute': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbTime>(target, 'TomDbTime');
        t.mute();
        return null;
      },
      'unmute': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbTime>(target, 'TomDbTime');
        t.unmute();
        return null;
      },
      'addObserver': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbTime>(target, 'TomDbTime');
        D4.requireMinArgs(positional, 1, 'addObserver');
        final observer = D4.getRequiredArg<$tom_core_kernel_5.TomObserver<$tom_core_kernel_5.TomObservable>>(positional, 0, 'observer', 'addObserver');
        t.addObserver(observer);
        return null;
      },
      'removeObserver': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbTime>(target, 'TomDbTime');
        D4.requireMinArgs(positional, 1, 'removeObserver');
        final observer = D4.getRequiredArg<$tom_core_kernel_5.TomObserver<$tom_core_kernel_5.TomObservable>>(positional, 0, 'observer', 'removeObserver');
        t.removeObserver(observer);
        return null;
      },
      'notifyObservers': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbTime>(target, 'TomDbTime');
        final message = D4.getOptionalArg<dynamic>(positional, 0, 'message');
        t.notifyObservers(message);
        return null;
      },
      '~': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbTime>(target, 'TomDbTime');
        return ~t;
      },
      '|': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbTime>(target, 'TomDbTime');
        final other = D4.getRequiredArg<$tom_core_kernel_10.TomZonedTime?>(positional, 0, 'other', 'operator|');
        return t | other;
      },
      '<<': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbTime>(target, 'TomDbTime');
        final other = D4.getRequiredArg<$tom_core_kernel_10.TomZonedTime?>(positional, 0, 'other', 'operator<<');
        return t << other;
      },
      '>>': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbTime>(target, 'TomDbTime');
        final other = D4.getRequiredArg<void Function($tom_core_kernel_5.TomObservable)>(positional, 0, 'other', 'operator>>');
        return t >> other;
      },
    },
    staticMethods: {
      'of': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'of');
        final s = D4.getRequiredArg<String?>(positional, 0, 's', 'of');
        return $tom_core_server_8.TomDbTime.of(s);
      },
    },
    constructorSignatures: {
      '': 'TomDbTime(TomZonedTime? value)',
    },
    methodSignatures: {
      'toString': 'String toString()',
      'getType': 'Type getType()',
      'get': 'TomZonedTime? get()',
      'set': 'TomZonedTime? set(TomZonedTime? value)',
      'getOrNull': 'TomZonedTime? getOrNull()',
      'call': 'TomZonedTime? call()',
      'mute': 'void mute()',
      'unmute': 'void unmute()',
      'addObserver': 'void addObserver(TomObserver<TomObservable> observer)',
      'removeObserver': 'void removeObserver(TomObserver<TomObservable> observer)',
      'notifyObservers': 'void notifyObservers([dynamic message])',
    },
    getterSignatures: {
      'isNull': 'bool get isNull',
      'isMuted': 'bool get isMuted',
    },
    staticMethodSignatures: {
      'of': 'TomDbTime of(String? s)',
    },
  );
}

// =============================================================================
// TomDbBool Bridge
// =============================================================================

BridgedClass _createTomDbBoolBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_8.TomDbBool,
    name: 'TomDbBool',
    isAssignable: (v) => v is $tom_core_server_8.TomDbBool,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomDbBool');
        final value = D4.getRequiredArg<bool?>(positional, 0, 'value', 'TomDbBool');
        return $tom_core_server_8.TomDbBool(value);
      },
    },
    getters: {
      'isNull': (visitor, target) => D4.validateTarget<$tom_core_server_8.TomDbBool>(target, 'TomDbBool').isNull,
      'isMuted': (visitor, target) => D4.validateTarget<$tom_core_server_8.TomDbBool>(target, 'TomDbBool').isMuted,
    },
    methods: {
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbBool>(target, 'TomDbBool');
        return t.toString();
      },
      'getType': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbBool>(target, 'TomDbBool');
        return t.getType();
      },
      'get': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbBool>(target, 'TomDbBool');
        return t.get();
      },
      'set': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbBool>(target, 'TomDbBool');
        D4.requireMinArgs(positional, 1, 'set');
        final value = D4.getRequiredArg<bool?>(positional, 0, 'value', 'set');
        return t.set(value);
      },
      'getOrNull': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbBool>(target, 'TomDbBool');
        return t.getOrNull();
      },
      'call': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbBool>(target, 'TomDbBool');
        return t.call();
      },
      'mute': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbBool>(target, 'TomDbBool');
        t.mute();
        return null;
      },
      'unmute': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbBool>(target, 'TomDbBool');
        t.unmute();
        return null;
      },
      'addObserver': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbBool>(target, 'TomDbBool');
        D4.requireMinArgs(positional, 1, 'addObserver');
        final observer = D4.getRequiredArg<$tom_core_kernel_5.TomObserver<$tom_core_kernel_5.TomObservable>>(positional, 0, 'observer', 'addObserver');
        t.addObserver(observer);
        return null;
      },
      'removeObserver': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbBool>(target, 'TomDbBool');
        D4.requireMinArgs(positional, 1, 'removeObserver');
        final observer = D4.getRequiredArg<$tom_core_kernel_5.TomObserver<$tom_core_kernel_5.TomObservable>>(positional, 0, 'observer', 'removeObserver');
        t.removeObserver(observer);
        return null;
      },
      'notifyObservers': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbBool>(target, 'TomDbBool');
        final message = D4.getOptionalArg<dynamic>(positional, 0, 'message');
        t.notifyObservers(message);
        return null;
      },
      '~': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbBool>(target, 'TomDbBool');
        return ~t;
      },
      '|': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbBool>(target, 'TomDbBool');
        final other = D4.getRequiredArg<bool?>(positional, 0, 'other', 'operator|');
        return t | other;
      },
      '<<': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbBool>(target, 'TomDbBool');
        final other = D4.getRequiredArg<bool?>(positional, 0, 'other', 'operator<<');
        return t << other;
      },
      '>>': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomDbBool>(target, 'TomDbBool');
        final other = D4.getRequiredArg<void Function($tom_core_kernel_5.TomObservable)>(positional, 0, 'other', 'operator>>');
        return t >> other;
      },
    },
    staticMethods: {
      'of': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'of');
        final s = D4.getRequiredArg<String?>(positional, 0, 's', 'of');
        return $tom_core_server_8.TomDbBool.of(s);
      },
    },
    constructorSignatures: {
      '': 'TomDbBool(bool? value)',
    },
    methodSignatures: {
      'toString': 'String toString()',
      'getType': 'Type getType()',
      'get': 'bool? get()',
      'set': 'bool? set(bool? value)',
      'getOrNull': 'bool? getOrNull()',
      'call': 'bool? call()',
      'mute': 'void mute()',
      'unmute': 'void unmute()',
      'addObserver': 'void addObserver(TomObserver<TomObservable> observer)',
      'removeObserver': 'void removeObserver(TomObserver<TomObservable> observer)',
      'notifyObservers': 'void notifyObservers([dynamic message])',
    },
    getterSignatures: {
      'isNull': 'bool get isNull',
      'isMuted': 'bool get isMuted',
    },
    staticMethodSignatures: {
      'of': 'TomDbBool of(String? s)',
    },
  );
}

// =============================================================================
// TomOperator Bridge
// =============================================================================

BridgedClass _createTomOperatorBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_8.TomOperator,
    name: 'TomOperator',
    isAssignable: (v) => v is $tom_core_server_8.TomOperator,
    constructors: {
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<$tom_core_server_8.TomOperator>(target, 'TomOperator').returnType,
    },
    setters: {
      'returnType': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_8.TomOperator>(target, 'TomOperator').returnType = D4.extractBridgedArg<Type>(value, 'returnType'),
    },
    methods: {
      'generate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomOperator>(target, 'TomOperator');
        D4.requireMinArgs(positional, 1, 'generate');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generate');
        return t.generate(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomOperator>(target, 'TomOperator');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomOperator>(target, 'TomOperator');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomOperator>(target, 'TomOperator');
        return t.toString();
      },
      'indent': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomOperator>(target, 'TomOperator');
        D4.requireMinArgs(positional, 1, 'indent');
        final i = D4.getRequiredArg<int>(positional, 0, 'i', 'indent');
        return t.indent(i);
      },
      'analyze': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_8.TomOperator>(target, 'TomOperator');
        D4.requireMinArgs(positional, 1, 'analyze');
        final l = D4.getRequiredArg<int>(positional, 0, 'l', 'analyze');
        return t.analyze(l);
      },
    },
    staticGetters: {
      'defaultDialect': (visitor) => $tom_core_server_8.TomOperator.defaultDialect,
    },
    staticSetters: {
      'defaultDialect': (visitor, value) => 
        $tom_core_server_8.TomOperator.defaultDialect = D4.extractBridgedArg<$tom_core_server_7.TomStandardSqlDialect>(value, 'defaultDialect'),
    },
    methodSignatures: {
      'generate': 'SqlString generate(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
      'indent': 'String indent(int i)',
      'analyze': 'String analyze(int l)',
    },
    getterSignatures: {
      'returnType': 'Type get returnType',
    },
    setterSignatures: {
      'returnType': 'set returnType(dynamic value)',
    },
    staticGetterSignatures: {
      'defaultDialect': 'TomStandardSqlDialect get defaultDialect',
    },
    staticSetterSignatures: {
      'defaultDialect': 'set defaultDialect(dynamic value)',
    },
  );
}

// =============================================================================
// TomDbMigrationException Bridge
// =============================================================================

BridgedClass _createTomDbMigrationExceptionBridge() {
  return BridgedClass(
    nativeType: TomDbMigrationException,
    name: 'TomDbMigrationException',
    isAssignable: (v) => v is TomDbMigrationException,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'TomDbMigrationException');
        final key = D4.getRequiredArg<String>(positional, 0, 'key', 'TomDbMigrationException');
        final defaultUserMessage = D4.getRequiredArg<String>(positional, 1, 'defaultUserMessage', 'TomDbMigrationException');
        final parameters = D4.coerceMapOrNull<String, Object?>(named['parameters'], 'parameters');
        final stack = D4.getOptionalNamedArg<Object?>(named, 'stack');
        final rootException = D4.getOptionalNamedArg<Object?>(named, 'rootException');
        final autoLog = D4.getNamedArgWithDefault<bool>(named, 'autoLog', false);
        return TomDbMigrationException(key, defaultUserMessage, parameters: parameters, stack: stack, rootException: rootException, autoLog: autoLog);
      },
    },
    getters: {
      'isolateName': (visitor, target) => D4.validateTarget<TomDbMigrationException>(target, 'TomDbMigrationException').isolateName,
      'clientThrow': (visitor, target) => D4.validateTarget<TomDbMigrationException>(target, 'TomDbMigrationException').clientThrow,
      'autoLog': (visitor, target) => D4.validateTarget<TomDbMigrationException>(target, 'TomDbMigrationException').autoLog,
      'serverCallError': (visitor, target) => D4.validateTarget<TomDbMigrationException>(target, 'TomDbMigrationException').serverCallError,
      'newField': (visitor, target) => D4.validateTarget<TomDbMigrationException>(target, 'TomDbMigrationException').newField,
      'logRepresentation': (visitor, target) => D4.validateTarget<TomDbMigrationException>(target, 'TomDbMigrationException').logRepresentation,
      'uuid': (visitor, target) => D4.validateTarget<TomDbMigrationException>(target, 'TomDbMigrationException').uuid,
      'requestUuid': (visitor, target) => D4.validateTarget<TomDbMigrationException>(target, 'TomDbMigrationException').requestUuid,
      'timeStamp': (visitor, target) => D4.validateTarget<TomDbMigrationException>(target, 'TomDbMigrationException').timeStamp,
      'key': (visitor, target) => D4.validateTarget<TomDbMigrationException>(target, 'TomDbMigrationException').key,
      'defaultUserMessage': (visitor, target) => D4.validateTarget<TomDbMigrationException>(target, 'TomDbMigrationException').defaultUserMessage,
      'parameters': (visitor, target) => D4.validateTarget<TomDbMigrationException>(target, 'TomDbMigrationException').parameters,
      'stack': (visitor, target) => D4.validateTarget<TomDbMigrationException>(target, 'TomDbMigrationException').stack,
      'rootException': (visitor, target) => D4.validateTarget<TomDbMigrationException>(target, 'TomDbMigrationException').rootException,
      'stackTrace': (visitor, target) => D4.validateTarget<TomDbMigrationException>(target, 'TomDbMigrationException').stackTrace,
    },
    setters: {
      'isolateName': (visitor, target, value) => 
        D4.validateTarget<TomDbMigrationException>(target, 'TomDbMigrationException').isolateName = D4.extractBridgedArg<String>(value, 'isolateName'),
      'clientThrow': (visitor, target, value) => 
        D4.validateTarget<TomDbMigrationException>(target, 'TomDbMigrationException').clientThrow = D4.extractBridgedArg<bool>(value, 'clientThrow'),
      'autoLog': (visitor, target, value) => 
        D4.validateTarget<TomDbMigrationException>(target, 'TomDbMigrationException').autoLog = D4.extractBridgedArg<bool>(value, 'autoLog'),
      'serverCallError': (visitor, target, value) => 
        D4.validateTarget<TomDbMigrationException>(target, 'TomDbMigrationException').serverCallError = D4.extractBridgedArgOrNull<$tom_core_kernel_4.TomServerCallError>(value, 'serverCallError'),
      'newField': (visitor, target, value) => 
        D4.validateTarget<TomDbMigrationException>(target, 'TomDbMigrationException').newField = D4.extractBridgedArgOrNull<String>(value, 'newField'),
      'uuid': (visitor, target, value) => 
        D4.validateTarget<TomDbMigrationException>(target, 'TomDbMigrationException').uuid = D4.extractBridgedArg<String>(value, 'uuid'),
      'requestUuid': (visitor, target, value) => 
        D4.validateTarget<TomDbMigrationException>(target, 'TomDbMigrationException').requestUuid = D4.extractBridgedArgOrNull<String>(value, 'requestUuid'),
      'timeStamp': (visitor, target, value) => 
        D4.validateTarget<TomDbMigrationException>(target, 'TomDbMigrationException').timeStamp = D4.extractBridgedArg<DateTime>(value, 'timeStamp'),
      'key': (visitor, target, value) => 
        D4.validateTarget<TomDbMigrationException>(target, 'TomDbMigrationException').key = D4.extractBridgedArg<String>(value, 'key'),
      'defaultUserMessage': (visitor, target, value) => 
        D4.validateTarget<TomDbMigrationException>(target, 'TomDbMigrationException').defaultUserMessage = D4.extractBridgedArg<String>(value, 'defaultUserMessage'),
      'stack': (visitor, target, value) => 
        D4.validateTarget<TomDbMigrationException>(target, 'TomDbMigrationException').stack = D4.extractBridgedArgOrNull<Object>(value, 'stack'),
      'rootException': (visitor, target, value) => 
        D4.validateTarget<TomDbMigrationException>(target, 'TomDbMigrationException').rootException = D4.extractBridgedArgOrNull<Object>(value, 'rootException'),
      'stackTrace': (visitor, target, value) => 
        D4.validateTarget<TomDbMigrationException>(target, 'TomDbMigrationException').stackTrace = D4.extractBridgedArg<String>(value, 'stackTrace'),
    },
    methods: {
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomDbMigrationException>(target, 'TomDbMigrationException');
        return t.toString();
      },
      'printStackTrace': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomDbMigrationException>(target, 'TomDbMigrationException');
        final depth = D4.getOptionalArgWithDefault<int>(positional, 0, 'depth', -1);
        t.printStackTrace(depth);
        return null;
      },
    },
    constructorSignatures: {
      '': 'TomDbMigrationException(String key, String defaultUserMessage, {Map<String, Object?>? parameters, Object? stack, Object? rootException, bool autoLog = false})',
    },
    methodSignatures: {
      'toString': 'String toString()',
      'printStackTrace': 'void printStackTrace([int depth = -1])',
    },
    getterSignatures: {
      'isolateName': 'String get isolateName',
      'clientThrow': 'bool get clientThrow',
      'autoLog': 'bool get autoLog',
      'serverCallError': 'TomServerCallError? get serverCallError',
      'newField': 'String? get newField',
      'logRepresentation': 'String get logRepresentation',
      'uuid': 'String get uuid',
      'requestUuid': 'String? get requestUuid',
      'timeStamp': 'DateTime get timeStamp',
      'key': 'String get key',
      'defaultUserMessage': 'String get defaultUserMessage',
      'parameters': 'Map<String, Object?>? get parameters',
      'stack': 'Object? get stack',
      'rootException': 'Object? get rootException',
      'stackTrace': 'String get stackTrace',
    },
    setterSignatures: {
      'isolateName': 'set isolateName(String value)',
      'clientThrow': 'set clientThrow(bool value)',
      'autoLog': 'set autoLog(bool value)',
      'serverCallError': 'set serverCallError(TomServerCallError? value)',
      'newField': 'set newField(String? value)',
      'uuid': 'set uuid(String value)',
      'requestUuid': 'set requestUuid(String? value)',
      'timeStamp': 'set timeStamp(DateTime value)',
      'key': 'set key(String value)',
      'defaultUserMessage': 'set defaultUserMessage(String value)',
      'parameters': 'set parameters(Map<String, Object?>? value)',
      'stack': 'set stack(Object? value)',
      'rootException': 'set rootException(Object? value)',
      'stackTrace': 'set stackTrace(String value)',
    },
  );
}

// =============================================================================
// TomDbMigrationAdaptor Bridge
// =============================================================================

BridgedClass _createTomDbMigrationAdaptorBridge() {
  return BridgedClass(
    nativeType: TomDbMigrationAdaptor,
    name: 'TomDbMigrationAdaptor',
    isAssignable: (v) => v is TomDbMigrationAdaptor,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomDbMigrationAdaptor');
        final type = D4.getRequiredArg<String>(positional, 0, 'type', 'TomDbMigrationAdaptor');
        return TomDbMigrationAdaptor(type);
      },
    },
    getters: {
      'type': (visitor, target) => D4.validateTarget<TomDbMigrationAdaptor>(target, 'TomDbMigrationAdaptor').type,
    },
    constructorSignatures: {
      '': 'const TomDbMigrationAdaptor(String type)',
    },
    getterSignatures: {
      'type': 'String get type',
    },
  );
}

// =============================================================================
// TomDbMigrator Bridge
// =============================================================================

BridgedClass _createTomDbMigratorBridge() {
  return BridgedClass(
    nativeType: TomDbMigrator,
    name: 'TomDbMigrator',
    isAssignable: (v) => v is TomDbMigrator,
    constructors: {
    },
    methods: {
      'initializeMigration': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomDbMigrator>(target, 'TomDbMigrator');
        D4.requireMinArgs(positional, 2, 'initializeMigration');
        final dsi = D4.getRequiredArg<$tom_core_server_4.TomDataSourceInfo>(positional, 0, 'dsi', 'initializeMigration');
        final schemaName = D4.getRequiredArg<String>(positional, 1, 'schemaName', 'initializeMigration');
        return t.initializeMigration(dsi, schemaName);
      },
      'applyMigration': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomDbMigrator>(target, 'TomDbMigrator');
        D4.requireMinArgs(positional, 5, 'applyMigration');
        final dsi = D4.getRequiredArg<$tom_core_server_4.TomDataSourceInfo>(positional, 0, 'dsi', 'applyMigration');
        final schemaName = D4.getRequiredArg<String>(positional, 1, 'schemaName', 'applyMigration');
        final version = D4.getRequiredArg<int>(positional, 2, 'version', 'applyMigration');
        final description = D4.getRequiredArg<String>(positional, 3, 'description', 'applyMigration');
        final sql = D4.getRequiredArg<String>(positional, 4, 'sql', 'applyMigration');
        return t.applyMigration(dsi, schemaName, version, description, sql);
      },
      'reset': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomDbMigrator>(target, 'TomDbMigrator');
        t.reset();
        return null;
      },
    },
    methodSignatures: {
      'initializeMigration': 'Future<int> initializeMigration(TomDataSourceInfo dsi, String schemaName)',
      'applyMigration': 'Future<void> applyMigration(TomDataSourceInfo dsi, String schemaName, int version, String description, String sql)',
      'reset': 'void reset()',
    },
  );
}

// =============================================================================
// TomDbMigrations Bridge
// =============================================================================

BridgedClass _createTomDbMigrationsBridge() {
  return BridgedClass(
    nativeType: TomDbMigrations,
    name: 'TomDbMigrations',
    isAssignable: (v) => v is TomDbMigrations,
    constructors: {
      '': (visitor, positional, named) {
        return TomDbMigrations();
      },
    },
    staticMethods: {
      'migrateDatabases': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'migrateDatabases');
        final directory = D4.getRequiredArg<String>(positional, 0, 'directory', 'migrateDatabases');
        return TomDbMigrations.migrateDatabases(directory);
      },
    },
    constructorSignatures: {
      '': 'TomDbMigrations()',
    },
    staticMethodSignatures: {
      'migrateDatabases': 'Future<void> migrateDatabases(String directory)',
    },
  );
}

// =============================================================================
// MariadbMigrationException Bridge
// =============================================================================

BridgedClass _createMariadbMigrationExceptionBridge() {
  return BridgedClass(
    nativeType: MariadbMigrationException,
    name: 'MariadbMigrationException',
    isAssignable: (v) => v is MariadbMigrationException,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'MariadbMigrationException');
        final key = D4.getRequiredArg<String>(positional, 0, 'key', 'MariadbMigrationException');
        final defaultUserMessage = D4.getRequiredArg<String>(positional, 1, 'defaultUserMessage', 'MariadbMigrationException');
        final parameters = D4.coerceMapOrNull<String, Object?>(named['parameters'], 'parameters');
        final stack = D4.getOptionalNamedArg<Object?>(named, 'stack');
        final rootException = D4.getOptionalNamedArg<Object?>(named, 'rootException');
        final autoLog = D4.getNamedArgWithDefault<bool>(named, 'autoLog', false);
        return MariadbMigrationException(key, defaultUserMessage, parameters: parameters, stack: stack, rootException: rootException, autoLog: autoLog);
      },
    },
    getters: {
      'isolateName': (visitor, target) => D4.validateTarget<MariadbMigrationException>(target, 'MariadbMigrationException').isolateName,
      'clientThrow': (visitor, target) => D4.validateTarget<MariadbMigrationException>(target, 'MariadbMigrationException').clientThrow,
      'autoLog': (visitor, target) => D4.validateTarget<MariadbMigrationException>(target, 'MariadbMigrationException').autoLog,
      'serverCallError': (visitor, target) => D4.validateTarget<MariadbMigrationException>(target, 'MariadbMigrationException').serverCallError,
      'newField': (visitor, target) => D4.validateTarget<MariadbMigrationException>(target, 'MariadbMigrationException').newField,
      'logRepresentation': (visitor, target) => D4.validateTarget<MariadbMigrationException>(target, 'MariadbMigrationException').logRepresentation,
      'uuid': (visitor, target) => D4.validateTarget<MariadbMigrationException>(target, 'MariadbMigrationException').uuid,
      'requestUuid': (visitor, target) => D4.validateTarget<MariadbMigrationException>(target, 'MariadbMigrationException').requestUuid,
      'timeStamp': (visitor, target) => D4.validateTarget<MariadbMigrationException>(target, 'MariadbMigrationException').timeStamp,
      'key': (visitor, target) => D4.validateTarget<MariadbMigrationException>(target, 'MariadbMigrationException').key,
      'defaultUserMessage': (visitor, target) => D4.validateTarget<MariadbMigrationException>(target, 'MariadbMigrationException').defaultUserMessage,
      'parameters': (visitor, target) => D4.validateTarget<MariadbMigrationException>(target, 'MariadbMigrationException').parameters,
      'stack': (visitor, target) => D4.validateTarget<MariadbMigrationException>(target, 'MariadbMigrationException').stack,
      'rootException': (visitor, target) => D4.validateTarget<MariadbMigrationException>(target, 'MariadbMigrationException').rootException,
      'stackTrace': (visitor, target) => D4.validateTarget<MariadbMigrationException>(target, 'MariadbMigrationException').stackTrace,
    },
    setters: {
      'isolateName': (visitor, target, value) => 
        D4.validateTarget<MariadbMigrationException>(target, 'MariadbMigrationException').isolateName = D4.extractBridgedArg<String>(value, 'isolateName'),
      'clientThrow': (visitor, target, value) => 
        D4.validateTarget<MariadbMigrationException>(target, 'MariadbMigrationException').clientThrow = D4.extractBridgedArg<bool>(value, 'clientThrow'),
      'autoLog': (visitor, target, value) => 
        D4.validateTarget<MariadbMigrationException>(target, 'MariadbMigrationException').autoLog = D4.extractBridgedArg<bool>(value, 'autoLog'),
      'serverCallError': (visitor, target, value) => 
        D4.validateTarget<MariadbMigrationException>(target, 'MariadbMigrationException').serverCallError = D4.extractBridgedArgOrNull<$tom_core_kernel_4.TomServerCallError>(value, 'serverCallError'),
      'newField': (visitor, target, value) => 
        D4.validateTarget<MariadbMigrationException>(target, 'MariadbMigrationException').newField = D4.extractBridgedArgOrNull<String>(value, 'newField'),
      'uuid': (visitor, target, value) => 
        D4.validateTarget<MariadbMigrationException>(target, 'MariadbMigrationException').uuid = D4.extractBridgedArg<String>(value, 'uuid'),
      'requestUuid': (visitor, target, value) => 
        D4.validateTarget<MariadbMigrationException>(target, 'MariadbMigrationException').requestUuid = D4.extractBridgedArgOrNull<String>(value, 'requestUuid'),
      'timeStamp': (visitor, target, value) => 
        D4.validateTarget<MariadbMigrationException>(target, 'MariadbMigrationException').timeStamp = D4.extractBridgedArg<DateTime>(value, 'timeStamp'),
      'key': (visitor, target, value) => 
        D4.validateTarget<MariadbMigrationException>(target, 'MariadbMigrationException').key = D4.extractBridgedArg<String>(value, 'key'),
      'defaultUserMessage': (visitor, target, value) => 
        D4.validateTarget<MariadbMigrationException>(target, 'MariadbMigrationException').defaultUserMessage = D4.extractBridgedArg<String>(value, 'defaultUserMessage'),
      'stack': (visitor, target, value) => 
        D4.validateTarget<MariadbMigrationException>(target, 'MariadbMigrationException').stack = D4.extractBridgedArgOrNull<Object>(value, 'stack'),
      'rootException': (visitor, target, value) => 
        D4.validateTarget<MariadbMigrationException>(target, 'MariadbMigrationException').rootException = D4.extractBridgedArgOrNull<Object>(value, 'rootException'),
      'stackTrace': (visitor, target, value) => 
        D4.validateTarget<MariadbMigrationException>(target, 'MariadbMigrationException').stackTrace = D4.extractBridgedArg<String>(value, 'stackTrace'),
    },
    methods: {
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbMigrationException>(target, 'MariadbMigrationException');
        return t.toString();
      },
      'printStackTrace': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbMigrationException>(target, 'MariadbMigrationException');
        final depth = D4.getOptionalArgWithDefault<int>(positional, 0, 'depth', -1);
        t.printStackTrace(depth);
        return null;
      },
    },
    constructorSignatures: {
      '': 'MariadbMigrationException(String key, String defaultUserMessage, {Map<String, Object?>? parameters, Object? stack, Object? rootException, bool autoLog = false})',
    },
    methodSignatures: {
      'toString': 'String toString()',
      'printStackTrace': 'void printStackTrace([int depth = -1])',
    },
    getterSignatures: {
      'isolateName': 'String get isolateName',
      'clientThrow': 'bool get clientThrow',
      'autoLog': 'bool get autoLog',
      'serverCallError': 'TomServerCallError? get serverCallError',
      'newField': 'String? get newField',
      'logRepresentation': 'String get logRepresentation',
      'uuid': 'String get uuid',
      'requestUuid': 'String? get requestUuid',
      'timeStamp': 'DateTime get timeStamp',
      'key': 'String get key',
      'defaultUserMessage': 'String get defaultUserMessage',
      'parameters': 'Map<String, Object?>? get parameters',
      'stack': 'Object? get stack',
      'rootException': 'Object? get rootException',
      'stackTrace': 'String get stackTrace',
    },
    setterSignatures: {
      'isolateName': 'set isolateName(String value)',
      'clientThrow': 'set clientThrow(bool value)',
      'autoLog': 'set autoLog(bool value)',
      'serverCallError': 'set serverCallError(TomServerCallError? value)',
      'newField': 'set newField(String? value)',
      'uuid': 'set uuid(String value)',
      'requestUuid': 'set requestUuid(String? value)',
      'timeStamp': 'set timeStamp(DateTime value)',
      'key': 'set key(String value)',
      'defaultUserMessage': 'set defaultUserMessage(String value)',
      'parameters': 'set parameters(Map<String, Object?>? value)',
      'stack': 'set stack(Object? value)',
      'rootException': 'set rootException(Object? value)',
      'stackTrace': 'set stackTrace(String value)',
    },
  );
}

// =============================================================================
// MariadbMigrationAdaptor Bridge
// =============================================================================

BridgedClass _createMariadbMigrationAdaptorBridge() {
  return BridgedClass(
    nativeType: MariadbMigrationAdaptor,
    name: 'MariadbMigrationAdaptor',
    isAssignable: (v) => v is MariadbMigrationAdaptor,
    constructors: {
      '': (visitor, positional, named) {
        return MariadbMigrationAdaptor();
      },
    },
    getters: {
      'versions': (visitor, target) => D4.validateTarget<MariadbMigrationAdaptor>(target, 'MariadbMigrationAdaptor').versions,
    },
    setters: {
      'versions': (visitor, target, value) => 
        D4.validateTarget<MariadbMigrationAdaptor>(target, 'MariadbMigrationAdaptor').versions = (value as List).cast<$tom_core_server_9.TomDbVersion>().toList(),
    },
    methods: {
      'reset': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbMigrationAdaptor>(target, 'MariadbMigrationAdaptor');
        t.reset();
        return null;
      },
      'applyMigration': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbMigrationAdaptor>(target, 'MariadbMigrationAdaptor');
        D4.requireMinArgs(positional, 5, 'applyMigration');
        final dsi = D4.getRequiredArg<$tom_core_server_4.TomDataSourceInfo>(positional, 0, 'dsi', 'applyMigration');
        final schemaName = D4.getRequiredArg<String>(positional, 1, 'schemaName', 'applyMigration');
        final version = D4.getRequiredArg<int>(positional, 2, 'version', 'applyMigration');
        final description = D4.getRequiredArg<String>(positional, 3, 'description', 'applyMigration');
        final sql = D4.getRequiredArg<String>(positional, 4, 'sql', 'applyMigration');
        return t.applyMigration(dsi, schemaName, version, description, sql);
      },
      'initializeMigration': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbMigrationAdaptor>(target, 'MariadbMigrationAdaptor');
        D4.requireMinArgs(positional, 2, 'initializeMigration');
        final dsi = D4.getRequiredArg<$tom_core_server_4.TomDataSourceInfo>(positional, 0, 'dsi', 'initializeMigration');
        final schemaName = D4.getRequiredArg<String>(positional, 1, 'schemaName', 'initializeMigration');
        return t.initializeMigration(dsi, schemaName);
      },
    },
    constructorSignatures: {
      '': 'MariadbMigrationAdaptor()',
    },
    methodSignatures: {
      'reset': 'void reset()',
      'applyMigration': 'Future<void> applyMigration(TomDataSourceInfo dsi, String schemaName, int version, String description, String sql)',
      'initializeMigration': 'Future<int> initializeMigration(TomDataSourceInfo dsi, String schemaName)',
    },
    getterSignatures: {
      'versions': 'List<TomDbVersion> get versions',
    },
    setterSignatures: {
      'versions': 'set versions(dynamic value)',
    },
  );
}

// =============================================================================
// TomDbVersion Bridge
// =============================================================================

BridgedClass _createTomDbVersionBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_9.TomDbVersion,
    name: 'TomDbVersion',
    isAssignable: (v) => v is $tom_core_server_9.TomDbVersion,
    constructors: {
      '': (visitor, positional, named) {
        return $tom_core_server_9.TomDbVersion();
      },
    },
    getters: {
      'installedRank': (visitor, target) => D4.validateTarget<$tom_core_server_9.TomDbVersion>(target, 'TomDbVersion').installedRank,
      'version': (visitor, target) => D4.validateTarget<$tom_core_server_9.TomDbVersion>(target, 'TomDbVersion').version,
      'description': (visitor, target) => D4.validateTarget<$tom_core_server_9.TomDbVersion>(target, 'TomDbVersion').description,
      'script': (visitor, target) => D4.validateTarget<$tom_core_server_9.TomDbVersion>(target, 'TomDbVersion').script,
      'checksum': (visitor, target) => D4.validateTarget<$tom_core_server_9.TomDbVersion>(target, 'TomDbVersion').checksum,
      'installedBy': (visitor, target) => D4.validateTarget<$tom_core_server_9.TomDbVersion>(target, 'TomDbVersion').installedBy,
      'installedOn': (visitor, target) => D4.validateTarget<$tom_core_server_9.TomDbVersion>(target, 'TomDbVersion').installedOn,
      'success': (visitor, target) => D4.validateTarget<$tom_core_server_9.TomDbVersion>(target, 'TomDbVersion').success,
    },
    setters: {
      'installedRank': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_9.TomDbVersion>(target, 'TomDbVersion').installedRank = D4.extractBridgedArg<int>(value, 'installedRank'),
      'version': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_9.TomDbVersion>(target, 'TomDbVersion').version = D4.extractBridgedArg<int>(value, 'version'),
      'description': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_9.TomDbVersion>(target, 'TomDbVersion').description = D4.extractBridgedArg<String>(value, 'description'),
      'script': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_9.TomDbVersion>(target, 'TomDbVersion').script = D4.extractBridgedArg<String>(value, 'script'),
      'checksum': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_9.TomDbVersion>(target, 'TomDbVersion').checksum = D4.extractBridgedArg<String>(value, 'checksum'),
      'installedBy': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_9.TomDbVersion>(target, 'TomDbVersion').installedBy = D4.extractBridgedArg<String>(value, 'installedBy'),
      'installedOn': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_9.TomDbVersion>(target, 'TomDbVersion').installedOn = D4.extractBridgedArg<DateTime>(value, 'installedOn'),
      'success': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_9.TomDbVersion>(target, 'TomDbVersion').success = D4.extractBridgedArg<int>(value, 'success'),
    },
    constructorSignatures: {
      '': 'TomDbVersion()',
    },
    getterSignatures: {
      'installedRank': 'int get installedRank',
      'version': 'int get version',
      'description': 'String get description',
      'script': 'String get script',
      'checksum': 'String get checksum',
      'installedBy': 'String get installedBy',
      'installedOn': 'DateTime get installedOn',
      'success': 'int get success',
    },
    setterSignatures: {
      'installedRank': 'set installedRank(dynamic value)',
      'version': 'set version(dynamic value)',
      'description': 'set description(dynamic value)',
      'script': 'set script(dynamic value)',
      'checksum': 'set checksum(dynamic value)',
      'installedBy': 'set installedBy(dynamic value)',
      'installedOn': 'set installedOn(dynamic value)',
      'success': 'set success(dynamic value)',
    },
  );
}

// =============================================================================
// TomErrorHandler Bridge
// =============================================================================

BridgedClass _createTomErrorHandlerBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_10.TomErrorHandler,
    name: 'TomErrorHandler',
    isAssignable: (v) => v is $tom_core_server_10.TomErrorHandler,
    constructors: {
    },
    methods: {
      'handleInvocationError': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_10.TomErrorHandler>(target, 'TomErrorHandler');
        D4.requireMinArgs(positional, 3, 'handleInvocationError');
        final error = D4.getRequiredArg<Object>(positional, 0, 'error', 'handleInvocationError');
        final stacktrace = D4.getRequiredArg<Object>(positional, 1, 'stacktrace', 'handleInvocationError');
        final r = D4.getRequiredArg<$shelf_3.Request>(positional, 2, 'r', 'handleInvocationError');
        return t.handleInvocationError(error, stacktrace, r);
      },
      'handleConversionError': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_10.TomErrorHandler>(target, 'TomErrorHandler');
        D4.requireMinArgs(positional, 4, 'handleConversionError');
        final error = D4.getRequiredArg<Object>(positional, 0, 'error', 'handleConversionError');
        final stacktrace = D4.getRequiredArg<Object>(positional, 1, 'stacktrace', 'handleConversionError');
        final r = D4.getRequiredArg<$shelf_3.Request>(positional, 2, 'r', 'handleConversionError');
        final result = D4.getRequiredArg<Object?>(positional, 3, 'result', 'handleConversionError');
        return t.handleConversionError(error, stacktrace, r, result);
      },
      'handleUnknowResultTypeError': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_10.TomErrorHandler>(target, 'TomErrorHandler');
        D4.requireMinArgs(positional, 4, 'handleUnknowResultTypeError');
        final error = D4.getRequiredArg<Object>(positional, 0, 'error', 'handleUnknowResultTypeError');
        final stacktrace = D4.getRequiredArg<Object>(positional, 1, 'stacktrace', 'handleUnknowResultTypeError');
        final r = D4.getRequiredArg<$shelf_3.Request>(positional, 2, 'r', 'handleUnknowResultTypeError');
        final result = D4.getRequiredArg<Object?>(positional, 3, 'result', 'handleUnknowResultTypeError');
        return t.handleUnknowResultTypeError(error, stacktrace, r, result);
      },
      'handleErrorDefault': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_10.TomErrorHandler>(target, 'TomErrorHandler');
        D4.requireMinArgs(positional, 4, 'handleErrorDefault');
        final error = D4.getRequiredArg<Object>(positional, 0, 'error', 'handleErrorDefault');
        final stacktrace = D4.getRequiredArg<Object>(positional, 1, 'stacktrace', 'handleErrorDefault');
        final r = D4.getRequiredArg<$shelf_3.Request>(positional, 2, 'r', 'handleErrorDefault');
        final result = D4.getRequiredArg<Object?>(positional, 3, 'result', 'handleErrorDefault');
        return t.handleErrorDefault(error, stacktrace, r, result);
      },
    },
    methodSignatures: {
      'handleInvocationError': 'Response handleInvocationError(Object error, Object stacktrace, Request r)',
      'handleConversionError': 'Response handleConversionError(Object error, Object stacktrace, Request r, Object? result)',
      'handleUnknowResultTypeError': 'Response handleUnknowResultTypeError(Object error, Object stacktrace, Request r, Object? result)',
      'handleErrorDefault': 'Response handleErrorDefault(Object error, Object stacktrace, Request r, Object? result)',
    },
  );
}

// =============================================================================
// TomDefaultErrorHandler Bridge
// =============================================================================

BridgedClass _createTomDefaultErrorHandlerBridge() {
  return BridgedClass(
    nativeType: TomDefaultErrorHandler,
    name: 'TomDefaultErrorHandler',
    isAssignable: (v) => v is TomDefaultErrorHandler,
    constructors: {
      '': (visitor, positional, named) {
        return TomDefaultErrorHandler();
      },
    },
    methods: {
      'handleInvocationError': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomDefaultErrorHandler>(target, 'TomDefaultErrorHandler');
        D4.requireMinArgs(positional, 3, 'handleInvocationError');
        final error = D4.getRequiredArg<Object>(positional, 0, 'error', 'handleInvocationError');
        final stacktrace = D4.getRequiredArg<Object>(positional, 1, 'stacktrace', 'handleInvocationError');
        final r = D4.getRequiredArg<$shelf_3.Request>(positional, 2, 'r', 'handleInvocationError');
        return t.handleInvocationError(error, stacktrace, r);
      },
      'handleConversionError': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomDefaultErrorHandler>(target, 'TomDefaultErrorHandler');
        D4.requireMinArgs(positional, 4, 'handleConversionError');
        final error = D4.getRequiredArg<Object>(positional, 0, 'error', 'handleConversionError');
        final stacktrace = D4.getRequiredArg<Object>(positional, 1, 'stacktrace', 'handleConversionError');
        final r = D4.getRequiredArg<$shelf_3.Request>(positional, 2, 'r', 'handleConversionError');
        final result = D4.getRequiredArg<Object?>(positional, 3, 'result', 'handleConversionError');
        return t.handleConversionError(error, stacktrace, r, result);
      },
      'handleUnknowResultTypeError': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomDefaultErrorHandler>(target, 'TomDefaultErrorHandler');
        D4.requireMinArgs(positional, 4, 'handleUnknowResultTypeError');
        final error = D4.getRequiredArg<Object>(positional, 0, 'error', 'handleUnknowResultTypeError');
        final stacktrace = D4.getRequiredArg<Object>(positional, 1, 'stacktrace', 'handleUnknowResultTypeError');
        final r = D4.getRequiredArg<$shelf_3.Request>(positional, 2, 'r', 'handleUnknowResultTypeError');
        final result = D4.getRequiredArg<Object?>(positional, 3, 'result', 'handleUnknowResultTypeError');
        return t.handleUnknowResultTypeError(error, stacktrace, r, result);
      },
      'handleErrorDefault': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomDefaultErrorHandler>(target, 'TomDefaultErrorHandler');
        D4.requireMinArgs(positional, 4, 'handleErrorDefault');
        final error = D4.getRequiredArg<Object>(positional, 0, 'error', 'handleErrorDefault');
        final stacktrace = D4.getRequiredArg<Object>(positional, 1, 'stacktrace', 'handleErrorDefault');
        final r = D4.getRequiredArg<$shelf_3.Request>(positional, 2, 'r', 'handleErrorDefault');
        final result = D4.getRequiredArg<Object?>(positional, 3, 'result', 'handleErrorDefault');
        return t.handleErrorDefault(error, stacktrace, r, result);
      },
    },
    constructorSignatures: {
      '': 'const TomDefaultErrorHandler()',
    },
    methodSignatures: {
      'handleInvocationError': 'Response handleInvocationError(Object error, Object stacktrace, Request r)',
      'handleConversionError': 'Response handleConversionError(Object error, Object stacktrace, Request r, Object? result)',
      'handleUnknowResultTypeError': 'Response handleUnknowResultTypeError(Object error, Object stacktrace, Request r, Object? result)',
      'handleErrorDefault': 'Response handleErrorDefault(Object error, Object stacktrace, Request r, Object? result)',
    },
  );
}

// =============================================================================
// TomService Bridge
// =============================================================================

BridgedClass _createTomServiceBridge() {
  return BridgedClass(
    nativeType: TomService,
    name: 'TomService',
    isAssignable: (v) => v is TomService,
    constructors: {
      '': (visitor, positional, named) {
        return TomService();
      },
    },
    constructorSignatures: {
      '': 'const TomService()',
    },
  );
}

// =============================================================================
// TomApiImplementation Bridge
// =============================================================================

BridgedClass _createTomApiImplementationBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_10.TomApiImplementation,
    name: 'TomApiImplementation',
    isAssignable: (v) => v is $tom_core_server_10.TomApiImplementation,
    constructors: {
      '': (visitor, positional, named) {
        final apiId = D4.getRequiredNamedArg<String>(named, 'apiId', 'TomApiImplementation');
        final errorHandler = D4.getOptionalNamedArg<$tom_core_server_10.TomErrorHandler?>(named, 'errorHandler');
        final logRequestsDefault = D4.getNamedArgWithDefault<bool>(named, 'logRequestsDefault', true);
        return $tom_core_server_10.TomApiImplementation(apiId: apiId, errorHandler: errorHandler, logRequestsDefault: logRequestsDefault);
      },
    },
    getters: {
      'apiId': (visitor, target) => D4.validateTarget<$tom_core_server_10.TomApiImplementation>(target, 'TomApiImplementation').apiId,
      'errorHandler': (visitor, target) => D4.validateTarget<$tom_core_server_10.TomApiImplementation>(target, 'TomApiImplementation').errorHandler,
      'logRequestsDefault': (visitor, target) => D4.validateTarget<$tom_core_server_10.TomApiImplementation>(target, 'TomApiImplementation').logRequestsDefault,
    },
    constructorSignatures: {
      '': 'const TomApiImplementation({required String apiId, TomErrorHandler? errorHandler, bool logRequestsDefault = true})',
    },
    getterSignatures: {
      'apiId': 'String get apiId',
      'errorHandler': 'TomErrorHandler? get errorHandler',
      'logRequestsDefault': 'bool get logRequestsDefault',
    },
  );
}

// =============================================================================
// TomEndpointBase Bridge
// =============================================================================

BridgedClass _createTomEndpointBaseBridge() {
  return BridgedClass(
    nativeType: TomEndpointBase,
    name: 'TomEndpointBase',
    isAssignable: (v) => v is TomEndpointBase,
    constructors: {
    },
    methods: {
      'convertToTomEndpoint': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomEndpointBase>(target, 'TomEndpointBase');
        return t.convertToTomEndpoint();
      },
    },
    methodSignatures: {
      'convertToTomEndpoint': 'TomEndpoint<requestType, resultType> convertToTomEndpoint()',
    },
  );
}

// =============================================================================
// TomApiEndpointImplementation Bridge
// =============================================================================

BridgedClass _createTomApiEndpointImplementationBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_10.TomApiEndpointImplementation,
    name: 'TomApiEndpointImplementation',
    isAssignable: (v) => v is $tom_core_server_10.TomApiEndpointImplementation,
    constructors: {
      '': (visitor, positional, named) {
        final apiId = D4.getRequiredNamedArg<String>(named, 'apiId', 'TomApiEndpointImplementation');
        final endpointId = D4.getRequiredNamedArg<String>(named, 'endpointId', 'TomApiEndpointImplementation');
        final errorHandler = D4.getOptionalNamedArg<$tom_core_server_10.TomErrorHandler?>(named, 'errorHandler');
        final logRequests = D4.getOptionalNamedArg<bool?>(named, 'logRequests');
        final corsAllowedOrigins = D4.getOptionalNamedArg<String?>(named, 'corsAllowedOrigins');
        final corsAllowedMethods = D4.getOptionalNamedArg<String?>(named, 'corsAllowedMethods');
        final corsAllowedHeaders = D4.getOptionalNamedArg<String?>(named, 'corsAllowedHeaders');
        return $tom_core_server_10.TomApiEndpointImplementation(apiId: apiId, endpointId: endpointId, errorHandler: errorHandler, logRequests: logRequests, corsAllowedOrigins: corsAllowedOrigins, corsAllowedMethods: corsAllowedMethods, corsAllowedHeaders: corsAllowedHeaders);
      },
    },
    getters: {
      'apiId': (visitor, target) => D4.validateTarget<$tom_core_server_10.TomApiEndpointImplementation>(target, 'TomApiEndpointImplementation').apiId,
      'endpointId': (visitor, target) => D4.validateTarget<$tom_core_server_10.TomApiEndpointImplementation>(target, 'TomApiEndpointImplementation').endpointId,
      'errorHandler': (visitor, target) => D4.validateTarget<$tom_core_server_10.TomApiEndpointImplementation>(target, 'TomApiEndpointImplementation').errorHandler,
      'logRequests': (visitor, target) => D4.validateTarget<$tom_core_server_10.TomApiEndpointImplementation>(target, 'TomApiEndpointImplementation').logRequests,
      'corsAllowedOrigins': (visitor, target) => D4.validateTarget<$tom_core_server_10.TomApiEndpointImplementation>(target, 'TomApiEndpointImplementation').corsAllowedOrigins,
      'corsAllowedMethods': (visitor, target) => D4.validateTarget<$tom_core_server_10.TomApiEndpointImplementation>(target, 'TomApiEndpointImplementation').corsAllowedMethods,
      'corsAllowedHeaders': (visitor, target) => D4.validateTarget<$tom_core_server_10.TomApiEndpointImplementation>(target, 'TomApiEndpointImplementation').corsAllowedHeaders,
    },
    methods: {
      'convertToTomEndpoint': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_10.TomApiEndpointImplementation>(target, 'TomApiEndpointImplementation');
        return t.convertToTomEndpoint();
      },
    },
    constructorSignatures: {
      '': 'const TomApiEndpointImplementation({required String apiId, required String endpointId, TomErrorHandler? errorHandler, bool? logRequests, String? corsAllowedOrigins, String? corsAllowedMethods, String? corsAllowedHeaders})',
    },
    methodSignatures: {
      'convertToTomEndpoint': 'TomEndpoint<requestType, resultType> convertToTomEndpoint()',
    },
    getterSignatures: {
      'apiId': 'String get apiId',
      'endpointId': 'String get endpointId',
      'errorHandler': 'TomErrorHandler? get errorHandler',
      'logRequests': 'bool? get logRequests',
      'corsAllowedOrigins': 'String? get corsAllowedOrigins',
      'corsAllowedMethods': 'String? get corsAllowedMethods',
      'corsAllowedHeaders': 'String? get corsAllowedHeaders',
    },
  );
}

// =============================================================================
// TomEndpoint Bridge
// =============================================================================

BridgedClass _createTomEndpointBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_10.TomEndpoint,
    name: 'TomEndpoint',
    isAssignable: (v) => v is $tom_core_server_10.TomEndpoint,
    constructors: {
      '': (visitor, positional, named) {
        final formFields = named.containsKey('formFields') && named['formFields'] != null
            ? D4.coerceList<String>(named['formFields'], 'formFields')
            : const <String>[];
        final uri = D4.getNamedArgWithDefault<String>(named, 'uri', "");
        final consumes = D4.getNamedArgWithDefault<$tom_core_kernel_3.TomMimeType>(named, 'consumes', $tom_core_kernel_3.TomMimeType.json);
        final produces = D4.getNamedArgWithDefault<$tom_core_kernel_3.TomMimeType>(named, 'produces', $tom_core_kernel_3.TomMimeType.json);
        final contentDisposition = D4.getOptionalNamedArg<String?>(named, 'contentDisposition');
        final logRequests = D4.getOptionalNamedArg<bool?>(named, 'logRequests');
        final headers = named.containsKey('headers') && named['headers'] != null
            ? D4.coerceMap<String, String>(named['headers'], 'headers')
            : const <String, String>{};
        final corsAllowedOrigins = D4.getOptionalNamedArg<String?>(named, 'corsAllowedOrigins');
        final corsAllowedMethods = D4.getOptionalNamedArg<String?>(named, 'corsAllowedMethods');
        final corsAllowedHeaders = D4.getOptionalNamedArg<String?>(named, 'corsAllowedHeaders');
        if (!named.containsKey('methods') && !named.containsKey('errorHandler')) {
          return $tom_core_server_10.TomEndpoint(formFields: formFields, uri: uri, consumes: consumes, produces: produces, contentDisposition: contentDisposition, logRequests: logRequests, headers: headers, corsAllowedOrigins: corsAllowedOrigins, corsAllowedMethods: corsAllowedMethods, corsAllowedHeaders: corsAllowedHeaders);
        }
        if (named.containsKey('methods') && !named.containsKey('errorHandler')) {
          final methods = D4.coerceList<$tom_core_kernel_2.TomHttpMethod>(named['methods'], 'methods');
          return $tom_core_server_10.TomEndpoint(formFields: formFields, uri: uri, consumes: consumes, produces: produces, contentDisposition: contentDisposition, logRequests: logRequests, headers: headers, corsAllowedOrigins: corsAllowedOrigins, corsAllowedMethods: corsAllowedMethods, corsAllowedHeaders: corsAllowedHeaders, methods: methods);
        }
        if (!named.containsKey('methods') && named.containsKey('errorHandler')) {
          final errorHandler = D4.getRequiredNamedArg<$tom_core_server_10.TomErrorHandler?>(named, 'errorHandler', 'TomEndpoint');
          return $tom_core_server_10.TomEndpoint(formFields: formFields, uri: uri, consumes: consumes, produces: produces, contentDisposition: contentDisposition, logRequests: logRequests, headers: headers, corsAllowedOrigins: corsAllowedOrigins, corsAllowedMethods: corsAllowedMethods, corsAllowedHeaders: corsAllowedHeaders, errorHandler: errorHandler);
        }
        if (named.containsKey('methods') && named.containsKey('errorHandler')) {
          final methods = D4.coerceList<$tom_core_kernel_2.TomHttpMethod>(named['methods'], 'methods');
          final errorHandler = D4.getRequiredNamedArg<$tom_core_server_10.TomErrorHandler?>(named, 'errorHandler', 'TomEndpoint');
          return $tom_core_server_10.TomEndpoint(formFields: formFields, uri: uri, consumes: consumes, produces: produces, contentDisposition: contentDisposition, logRequests: logRequests, headers: headers, corsAllowedOrigins: corsAllowedOrigins, corsAllowedMethods: corsAllowedMethods, corsAllowedHeaders: corsAllowedHeaders, methods: methods, errorHandler: errorHandler);
        }
        throw StateError('Unreachable: all named parameter combinations should be covered');
      },
    },
    getters: {
      'methods': (visitor, target) => D4.validateTarget<$tom_core_server_10.TomEndpoint>(target, 'TomEndpoint').methods,
      'formFields': (visitor, target) => D4.validateTarget<$tom_core_server_10.TomEndpoint>(target, 'TomEndpoint').formFields,
      'uri': (visitor, target) => D4.validateTarget<$tom_core_server_10.TomEndpoint>(target, 'TomEndpoint').uri,
      'consumes': (visitor, target) => D4.validateTarget<$tom_core_server_10.TomEndpoint>(target, 'TomEndpoint').consumes,
      'produces': (visitor, target) => D4.validateTarget<$tom_core_server_10.TomEndpoint>(target, 'TomEndpoint').produces,
      'contentDisposition': (visitor, target) => D4.validateTarget<$tom_core_server_10.TomEndpoint>(target, 'TomEndpoint').contentDisposition,
      'errorHandler': (visitor, target) => D4.validateTarget<$tom_core_server_10.TomEndpoint>(target, 'TomEndpoint').errorHandler,
      'logRequests': (visitor, target) => D4.validateTarget<$tom_core_server_10.TomEndpoint>(target, 'TomEndpoint').logRequests,
      'headers': (visitor, target) => D4.validateTarget<$tom_core_server_10.TomEndpoint>(target, 'TomEndpoint').headers,
      'corsAllowedOrigins': (visitor, target) => D4.validateTarget<$tom_core_server_10.TomEndpoint>(target, 'TomEndpoint').corsAllowedOrigins,
      'corsAllowedMethods': (visitor, target) => D4.validateTarget<$tom_core_server_10.TomEndpoint>(target, 'TomEndpoint').corsAllowedMethods,
      'corsAllowedHeaders': (visitor, target) => D4.validateTarget<$tom_core_server_10.TomEndpoint>(target, 'TomEndpoint').corsAllowedHeaders,
    },
    methods: {
      'convertToTomEndpoint': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_10.TomEndpoint>(target, 'TomEndpoint');
        return t.convertToTomEndpoint();
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_10.TomEndpoint>(target, 'TomEndpoint');
        return t.toString();
      },
    },
    constructorSignatures: {
      '': 'const TomEndpoint({List<TomHttpMethod> methods = const [TomHttpMethod.get], List<String> formFields = const [], String uri = "", TomMimeType consumes = TomMimeType.json, TomMimeType produces = TomMimeType.json, String? contentDisposition, TomErrorHandler? errorHandler = _tomDefaultErrorHandler, bool? logRequests, Map<String, String> headers = const {}, String? corsAllowedOrigins, String? corsAllowedMethods, String? corsAllowedHeaders})',
    },
    methodSignatures: {
      'convertToTomEndpoint': 'TomEndpoint<requestType, resultType> convertToTomEndpoint()',
      'toString': 'String toString()',
    },
    getterSignatures: {
      'methods': 'List<TomHttpMethod> get methods',
      'formFields': 'List<String> get formFields',
      'uri': 'String get uri',
      'consumes': 'TomMimeType get consumes',
      'produces': 'TomMimeType get produces',
      'contentDisposition': 'String? get contentDisposition',
      'errorHandler': 'TomErrorHandler? get errorHandler',
      'logRequests': 'bool? get logRequests',
      'headers': 'Map<String, String> get headers',
      'corsAllowedOrigins': 'String? get corsAllowedOrigins',
      'corsAllowedMethods': 'String? get corsAllowedMethods',
      'corsAllowedHeaders': 'String? get corsAllowedHeaders',
    },
  );
}

// =============================================================================
// TomComponentReference Bridge
// =============================================================================

BridgedClass _createTomComponentReferenceBridge() {
  return BridgedClass(
    nativeType: TomComponentReference,
    name: 'TomComponentReference',
    isAssignable: (v) => v is TomComponentReference,
    constructors: {
      '': (visitor, positional, named) {
        final componentName = D4.getOptionalNamedArg<String?>(named, 'componentName');
        final referencedType = D4.getOptionalNamedArg<Type?>(named, 'referencedType');
        return TomComponentReference(componentName: componentName, referencedType: referencedType);
      },
    },
    getters: {
      'componentName': (visitor, target) => D4.validateTarget<TomComponentReference>(target, 'TomComponentReference').componentName,
      'referencedType': (visitor, target) => D4.validateTarget<TomComponentReference>(target, 'TomComponentReference').referencedType,
    },
    constructorSignatures: {
      '': 'const TomComponentReference({String? componentName, Type? referencedType})',
    },
    getterSignatures: {
      'componentName': 'String? get componentName',
      'referencedType': 'Type? get referencedType',
    },
  );
}

// =============================================================================
// TomTransactional Bridge
// =============================================================================

BridgedClass _createTomTransactionalBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_10.TomTransactional,
    name: 'TomTransactional',
    isAssignable: (v) => v is $tom_core_server_10.TomTransactional,
    constructors: {
      '': (visitor, positional, named) {
        final isReadOnly = D4.getNamedArgWithDefault<bool>(named, 'isReadOnly', false);
        final isTransactional = D4.getNamedArgWithDefault<bool>(named, 'isTransactional', true);
        return $tom_core_server_10.TomTransactional(isReadOnly: isReadOnly, isTransactional: isTransactional);
      },
    },
    getters: {
      'isTransactional': (visitor, target) => D4.validateTarget<$tom_core_server_10.TomTransactional>(target, 'TomTransactional').isTransactional,
      'isReadOnly': (visitor, target) => D4.validateTarget<$tom_core_server_10.TomTransactional>(target, 'TomTransactional').isReadOnly,
    },
    constructorSignatures: {
      '': 'const TomTransactional({bool isReadOnly = false, bool isTransactional = true})',
    },
    getterSignatures: {
      'isTransactional': 'bool get isTransactional',
      'isReadOnly': 'bool get isReadOnly',
    },
  );
}

// =============================================================================
// TomEndpointHandlerException Bridge
// =============================================================================

BridgedClass _createTomEndpointHandlerExceptionBridge() {
  return BridgedClass(
    nativeType: TomEndpointHandlerException,
    name: 'TomEndpointHandlerException',
    isAssignable: (v) => v is TomEndpointHandlerException,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'TomEndpointHandlerException');
        final key = D4.getRequiredArg<String>(positional, 0, 'key', 'TomEndpointHandlerException');
        final defaultUserMessage = D4.getRequiredArg<String>(positional, 1, 'defaultUserMessage', 'TomEndpointHandlerException');
        final parameters = D4.coerceMapOrNull<String, Object?>(named['parameters'], 'parameters');
        final stack = D4.getOptionalNamedArg<Object?>(named, 'stack');
        final rootException = D4.getOptionalNamedArg<Object?>(named, 'rootException');
        final autoLog = D4.getNamedArgWithDefault<bool>(named, 'autoLog', false);
        return TomEndpointHandlerException(key, defaultUserMessage, parameters: parameters, stack: stack, rootException: rootException, autoLog: autoLog);
      },
    },
    getters: {
      'isolateName': (visitor, target) => D4.validateTarget<TomEndpointHandlerException>(target, 'TomEndpointHandlerException').isolateName,
      'clientThrow': (visitor, target) => D4.validateTarget<TomEndpointHandlerException>(target, 'TomEndpointHandlerException').clientThrow,
      'autoLog': (visitor, target) => D4.validateTarget<TomEndpointHandlerException>(target, 'TomEndpointHandlerException').autoLog,
      'serverCallError': (visitor, target) => D4.validateTarget<TomEndpointHandlerException>(target, 'TomEndpointHandlerException').serverCallError,
      'newField': (visitor, target) => D4.validateTarget<TomEndpointHandlerException>(target, 'TomEndpointHandlerException').newField,
      'logRepresentation': (visitor, target) => D4.validateTarget<TomEndpointHandlerException>(target, 'TomEndpointHandlerException').logRepresentation,
      'uuid': (visitor, target) => D4.validateTarget<TomEndpointHandlerException>(target, 'TomEndpointHandlerException').uuid,
      'requestUuid': (visitor, target) => D4.validateTarget<TomEndpointHandlerException>(target, 'TomEndpointHandlerException').requestUuid,
      'timeStamp': (visitor, target) => D4.validateTarget<TomEndpointHandlerException>(target, 'TomEndpointHandlerException').timeStamp,
      'key': (visitor, target) => D4.validateTarget<TomEndpointHandlerException>(target, 'TomEndpointHandlerException').key,
      'defaultUserMessage': (visitor, target) => D4.validateTarget<TomEndpointHandlerException>(target, 'TomEndpointHandlerException').defaultUserMessage,
      'parameters': (visitor, target) => D4.validateTarget<TomEndpointHandlerException>(target, 'TomEndpointHandlerException').parameters,
      'stack': (visitor, target) => D4.validateTarget<TomEndpointHandlerException>(target, 'TomEndpointHandlerException').stack,
      'rootException': (visitor, target) => D4.validateTarget<TomEndpointHandlerException>(target, 'TomEndpointHandlerException').rootException,
      'stackTrace': (visitor, target) => D4.validateTarget<TomEndpointHandlerException>(target, 'TomEndpointHandlerException').stackTrace,
    },
    setters: {
      'isolateName': (visitor, target, value) => 
        D4.validateTarget<TomEndpointHandlerException>(target, 'TomEndpointHandlerException').isolateName = D4.extractBridgedArg<String>(value, 'isolateName'),
      'clientThrow': (visitor, target, value) => 
        D4.validateTarget<TomEndpointHandlerException>(target, 'TomEndpointHandlerException').clientThrow = D4.extractBridgedArg<bool>(value, 'clientThrow'),
      'autoLog': (visitor, target, value) => 
        D4.validateTarget<TomEndpointHandlerException>(target, 'TomEndpointHandlerException').autoLog = D4.extractBridgedArg<bool>(value, 'autoLog'),
      'serverCallError': (visitor, target, value) => 
        D4.validateTarget<TomEndpointHandlerException>(target, 'TomEndpointHandlerException').serverCallError = D4.extractBridgedArgOrNull<$tom_core_kernel_4.TomServerCallError>(value, 'serverCallError'),
      'newField': (visitor, target, value) => 
        D4.validateTarget<TomEndpointHandlerException>(target, 'TomEndpointHandlerException').newField = D4.extractBridgedArgOrNull<String>(value, 'newField'),
      'uuid': (visitor, target, value) => 
        D4.validateTarget<TomEndpointHandlerException>(target, 'TomEndpointHandlerException').uuid = D4.extractBridgedArg<String>(value, 'uuid'),
      'requestUuid': (visitor, target, value) => 
        D4.validateTarget<TomEndpointHandlerException>(target, 'TomEndpointHandlerException').requestUuid = D4.extractBridgedArgOrNull<String>(value, 'requestUuid'),
      'timeStamp': (visitor, target, value) => 
        D4.validateTarget<TomEndpointHandlerException>(target, 'TomEndpointHandlerException').timeStamp = D4.extractBridgedArg<DateTime>(value, 'timeStamp'),
      'key': (visitor, target, value) => 
        D4.validateTarget<TomEndpointHandlerException>(target, 'TomEndpointHandlerException').key = D4.extractBridgedArg<String>(value, 'key'),
      'defaultUserMessage': (visitor, target, value) => 
        D4.validateTarget<TomEndpointHandlerException>(target, 'TomEndpointHandlerException').defaultUserMessage = D4.extractBridgedArg<String>(value, 'defaultUserMessage'),
      'stack': (visitor, target, value) => 
        D4.validateTarget<TomEndpointHandlerException>(target, 'TomEndpointHandlerException').stack = D4.extractBridgedArgOrNull<Object>(value, 'stack'),
      'rootException': (visitor, target, value) => 
        D4.validateTarget<TomEndpointHandlerException>(target, 'TomEndpointHandlerException').rootException = D4.extractBridgedArgOrNull<Object>(value, 'rootException'),
      'stackTrace': (visitor, target, value) => 
        D4.validateTarget<TomEndpointHandlerException>(target, 'TomEndpointHandlerException').stackTrace = D4.extractBridgedArg<String>(value, 'stackTrace'),
    },
    methods: {
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomEndpointHandlerException>(target, 'TomEndpointHandlerException');
        return t.toString();
      },
      'printStackTrace': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomEndpointHandlerException>(target, 'TomEndpointHandlerException');
        final depth = D4.getOptionalArgWithDefault<int>(positional, 0, 'depth', -1);
        t.printStackTrace(depth);
        return null;
      },
    },
    constructorSignatures: {
      '': 'TomEndpointHandlerException(String key, String defaultUserMessage, {Map<String, Object?>? parameters, Object? stack, Object? rootException, bool autoLog = false})',
    },
    methodSignatures: {
      'toString': 'String toString()',
      'printStackTrace': 'void printStackTrace([int depth = -1])',
    },
    getterSignatures: {
      'isolateName': 'String get isolateName',
      'clientThrow': 'bool get clientThrow',
      'autoLog': 'bool get autoLog',
      'serverCallError': 'TomServerCallError? get serverCallError',
      'newField': 'String? get newField',
      'logRepresentation': 'String get logRepresentation',
      'uuid': 'String get uuid',
      'requestUuid': 'String? get requestUuid',
      'timeStamp': 'DateTime get timeStamp',
      'key': 'String get key',
      'defaultUserMessage': 'String get defaultUserMessage',
      'parameters': 'Map<String, Object?>? get parameters',
      'stack': 'Object? get stack',
      'rootException': 'Object? get rootException',
      'stackTrace': 'String get stackTrace',
    },
    setterSignatures: {
      'isolateName': 'set isolateName(String value)',
      'clientThrow': 'set clientThrow(bool value)',
      'autoLog': 'set autoLog(bool value)',
      'serverCallError': 'set serverCallError(TomServerCallError? value)',
      'newField': 'set newField(String? value)',
      'uuid': 'set uuid(String value)',
      'requestUuid': 'set requestUuid(String? value)',
      'timeStamp': 'set timeStamp(DateTime value)',
      'key': 'set key(String value)',
      'defaultUserMessage': 'set defaultUserMessage(String value)',
      'parameters': 'set parameters(Map<String, Object?>? value)',
      'stack': 'set stack(Object? value)',
      'rootException': 'set rootException(Object? value)',
      'stackTrace': 'set stackTrace(String value)',
    },
  );
}

// =============================================================================
// TomEndpointPipelineException Bridge
// =============================================================================

BridgedClass _createTomEndpointPipelineExceptionBridge() {
  return BridgedClass(
    nativeType: TomEndpointPipelineException,
    name: 'TomEndpointPipelineException',
    isAssignable: (v) => v is TomEndpointPipelineException,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'TomEndpointPipelineException');
        final key = D4.getRequiredArg<String>(positional, 0, 'key', 'TomEndpointPipelineException');
        final defaultUserMessage = D4.getRequiredArg<String>(positional, 1, 'defaultUserMessage', 'TomEndpointPipelineException');
        final parameters = D4.coerceMapOrNull<String, Object?>(named['parameters'], 'parameters');
        final stack = D4.getOptionalNamedArg<Object?>(named, 'stack');
        final rootException = D4.getOptionalNamedArg<Object?>(named, 'rootException');
        final autoLog = D4.getNamedArgWithDefault<bool>(named, 'autoLog', false);
        return TomEndpointPipelineException(key, defaultUserMessage, parameters: parameters, stack: stack, rootException: rootException, autoLog: autoLog);
      },
    },
    getters: {
      'isolateName': (visitor, target) => D4.validateTarget<TomEndpointPipelineException>(target, 'TomEndpointPipelineException').isolateName,
      'clientThrow': (visitor, target) => D4.validateTarget<TomEndpointPipelineException>(target, 'TomEndpointPipelineException').clientThrow,
      'autoLog': (visitor, target) => D4.validateTarget<TomEndpointPipelineException>(target, 'TomEndpointPipelineException').autoLog,
      'serverCallError': (visitor, target) => D4.validateTarget<TomEndpointPipelineException>(target, 'TomEndpointPipelineException').serverCallError,
      'newField': (visitor, target) => D4.validateTarget<TomEndpointPipelineException>(target, 'TomEndpointPipelineException').newField,
      'logRepresentation': (visitor, target) => D4.validateTarget<TomEndpointPipelineException>(target, 'TomEndpointPipelineException').logRepresentation,
      'uuid': (visitor, target) => D4.validateTarget<TomEndpointPipelineException>(target, 'TomEndpointPipelineException').uuid,
      'requestUuid': (visitor, target) => D4.validateTarget<TomEndpointPipelineException>(target, 'TomEndpointPipelineException').requestUuid,
      'timeStamp': (visitor, target) => D4.validateTarget<TomEndpointPipelineException>(target, 'TomEndpointPipelineException').timeStamp,
      'key': (visitor, target) => D4.validateTarget<TomEndpointPipelineException>(target, 'TomEndpointPipelineException').key,
      'defaultUserMessage': (visitor, target) => D4.validateTarget<TomEndpointPipelineException>(target, 'TomEndpointPipelineException').defaultUserMessage,
      'parameters': (visitor, target) => D4.validateTarget<TomEndpointPipelineException>(target, 'TomEndpointPipelineException').parameters,
      'stack': (visitor, target) => D4.validateTarget<TomEndpointPipelineException>(target, 'TomEndpointPipelineException').stack,
      'rootException': (visitor, target) => D4.validateTarget<TomEndpointPipelineException>(target, 'TomEndpointPipelineException').rootException,
      'stackTrace': (visitor, target) => D4.validateTarget<TomEndpointPipelineException>(target, 'TomEndpointPipelineException').stackTrace,
    },
    setters: {
      'isolateName': (visitor, target, value) => 
        D4.validateTarget<TomEndpointPipelineException>(target, 'TomEndpointPipelineException').isolateName = D4.extractBridgedArg<String>(value, 'isolateName'),
      'clientThrow': (visitor, target, value) => 
        D4.validateTarget<TomEndpointPipelineException>(target, 'TomEndpointPipelineException').clientThrow = D4.extractBridgedArg<bool>(value, 'clientThrow'),
      'autoLog': (visitor, target, value) => 
        D4.validateTarget<TomEndpointPipelineException>(target, 'TomEndpointPipelineException').autoLog = D4.extractBridgedArg<bool>(value, 'autoLog'),
      'serverCallError': (visitor, target, value) => 
        D4.validateTarget<TomEndpointPipelineException>(target, 'TomEndpointPipelineException').serverCallError = D4.extractBridgedArgOrNull<$tom_core_kernel_4.TomServerCallError>(value, 'serverCallError'),
      'newField': (visitor, target, value) => 
        D4.validateTarget<TomEndpointPipelineException>(target, 'TomEndpointPipelineException').newField = D4.extractBridgedArgOrNull<String>(value, 'newField'),
      'uuid': (visitor, target, value) => 
        D4.validateTarget<TomEndpointPipelineException>(target, 'TomEndpointPipelineException').uuid = D4.extractBridgedArg<String>(value, 'uuid'),
      'requestUuid': (visitor, target, value) => 
        D4.validateTarget<TomEndpointPipelineException>(target, 'TomEndpointPipelineException').requestUuid = D4.extractBridgedArgOrNull<String>(value, 'requestUuid'),
      'timeStamp': (visitor, target, value) => 
        D4.validateTarget<TomEndpointPipelineException>(target, 'TomEndpointPipelineException').timeStamp = D4.extractBridgedArg<DateTime>(value, 'timeStamp'),
      'key': (visitor, target, value) => 
        D4.validateTarget<TomEndpointPipelineException>(target, 'TomEndpointPipelineException').key = D4.extractBridgedArg<String>(value, 'key'),
      'defaultUserMessage': (visitor, target, value) => 
        D4.validateTarget<TomEndpointPipelineException>(target, 'TomEndpointPipelineException').defaultUserMessage = D4.extractBridgedArg<String>(value, 'defaultUserMessage'),
      'stack': (visitor, target, value) => 
        D4.validateTarget<TomEndpointPipelineException>(target, 'TomEndpointPipelineException').stack = D4.extractBridgedArgOrNull<Object>(value, 'stack'),
      'rootException': (visitor, target, value) => 
        D4.validateTarget<TomEndpointPipelineException>(target, 'TomEndpointPipelineException').rootException = D4.extractBridgedArgOrNull<Object>(value, 'rootException'),
      'stackTrace': (visitor, target, value) => 
        D4.validateTarget<TomEndpointPipelineException>(target, 'TomEndpointPipelineException').stackTrace = D4.extractBridgedArg<String>(value, 'stackTrace'),
    },
    methods: {
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomEndpointPipelineException>(target, 'TomEndpointPipelineException');
        return t.toString();
      },
      'printStackTrace': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomEndpointPipelineException>(target, 'TomEndpointPipelineException');
        final depth = D4.getOptionalArgWithDefault<int>(positional, 0, 'depth', -1);
        t.printStackTrace(depth);
        return null;
      },
    },
    constructorSignatures: {
      '': 'TomEndpointPipelineException(String key, String defaultUserMessage, {Map<String, Object?>? parameters, Object? stack, Object? rootException, bool autoLog = false})',
    },
    methodSignatures: {
      'toString': 'String toString()',
      'printStackTrace': 'void printStackTrace([int depth = -1])',
    },
    getterSignatures: {
      'isolateName': 'String get isolateName',
      'clientThrow': 'bool get clientThrow',
      'autoLog': 'bool get autoLog',
      'serverCallError': 'TomServerCallError? get serverCallError',
      'newField': 'String? get newField',
      'logRepresentation': 'String get logRepresentation',
      'uuid': 'String get uuid',
      'requestUuid': 'String? get requestUuid',
      'timeStamp': 'DateTime get timeStamp',
      'key': 'String get key',
      'defaultUserMessage': 'String get defaultUserMessage',
      'parameters': 'Map<String, Object?>? get parameters',
      'stack': 'Object? get stack',
      'rootException': 'Object? get rootException',
      'stackTrace': 'String get stackTrace',
    },
    setterSignatures: {
      'isolateName': 'set isolateName(String value)',
      'clientThrow': 'set clientThrow(bool value)',
      'autoLog': 'set autoLog(bool value)',
      'serverCallError': 'set serverCallError(TomServerCallError? value)',
      'newField': 'set newField(String? value)',
      'uuid': 'set uuid(String value)',
      'requestUuid': 'set requestUuid(String? value)',
      'timeStamp': 'set timeStamp(DateTime value)',
      'key': 'set key(String value)',
      'defaultUserMessage': 'set defaultUserMessage(String value)',
      'parameters': 'set parameters(Map<String, Object?>? value)',
      'stack': 'set stack(Object? value)',
      'rootException': 'set rootException(Object? value)',
      'stackTrace': 'set stackTrace(String value)',
    },
  );
}

// =============================================================================
// TomEndpointHandler Bridge
// =============================================================================

BridgedClass _createTomEndpointHandlerBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_11.TomEndpointHandler,
    name: 'TomEndpointHandler',
    isAssignable: (v) => v is $tom_core_server_11.TomEndpointHandler,
    constructors: {
      '': (visitor, positional, named) {
        final name = D4.getRequiredNamedArg<String>(named, 'name', 'TomEndpointHandler');
        final instance = D4.getRequiredNamedArg<$tom_reflection_1.InstanceMirror>(named, 'instance', 'TomEndpointHandler');
        final method = D4.getRequiredNamedArg<$tom_reflection_1.MethodMirror>(named, 'method', 'TomEndpointHandler');
        final interface = D4.getOptionalNamedArg<$tom_reflection_1.ClassMirror<dynamic>?>(named, 'interface');
        final implementation = D4.getRequiredNamedArg<$tom_reflection_1.ClassMirror<dynamic>>(named, 'implementation', 'TomEndpointHandler');
        final methodName = D4.getRequiredNamedArg<String>(named, 'methodName', 'TomEndpointHandler');
        final metadata = D4.getRequiredNamedArg<$tom_core_server_11.TomMethodMetadata>(named, 'metadata', 'TomEndpointHandler');
        return $tom_core_server_11.TomEndpointHandler(name: name, instance: instance, method: method, interface: interface, implementation: implementation, methodName: methodName, metadata: metadata);
      },
    },
    getters: {
      'name': (visitor, target) => D4.validateTarget<$tom_core_server_11.TomEndpointHandler>(target, 'TomEndpointHandler').name,
      'instance': (visitor, target) => D4.validateTarget<$tom_core_server_11.TomEndpointHandler>(target, 'TomEndpointHandler').instance,
      'method': (visitor, target) => D4.validateTarget<$tom_core_server_11.TomEndpointHandler>(target, 'TomEndpointHandler').method,
      'interface': (visitor, target) => D4.validateTarget<$tom_core_server_11.TomEndpointHandler>(target, 'TomEndpointHandler').interface,
      'implementation': (visitor, target) => D4.validateTarget<$tom_core_server_11.TomEndpointHandler>(target, 'TomEndpointHandler').implementation,
      'methodName': (visitor, target) => D4.validateTarget<$tom_core_server_11.TomEndpointHandler>(target, 'TomEndpointHandler').methodName,
      'metadata': (visitor, target) => D4.validateTarget<$tom_core_server_11.TomEndpointHandler>(target, 'TomEndpointHandler').metadata,
    },
    setters: {
      'name': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_11.TomEndpointHandler>(target, 'TomEndpointHandler').name = D4.extractBridgedArg<String>(value, 'name'),
      'instance': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_11.TomEndpointHandler>(target, 'TomEndpointHandler').instance = D4.extractBridgedArg<$tom_reflection_1.InstanceMirror>(value, 'instance'),
      'method': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_11.TomEndpointHandler>(target, 'TomEndpointHandler').method = D4.extractBridgedArg<$tom_reflection_1.MethodMirror>(value, 'method'),
      'interface': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_11.TomEndpointHandler>(target, 'TomEndpointHandler').interface = D4.extractBridgedArgOrNull<$tom_reflection_1.ClassMirror>(value, 'interface'),
      'implementation': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_11.TomEndpointHandler>(target, 'TomEndpointHandler').implementation = D4.extractBridgedArg<$tom_reflection_1.ClassMirror>(value, 'implementation'),
      'methodName': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_11.TomEndpointHandler>(target, 'TomEndpointHandler').methodName = D4.extractBridgedArg<String>(value, 'methodName'),
      'metadata': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_11.TomEndpointHandler>(target, 'TomEndpointHandler').metadata = D4.extractBridgedArg<$tom_core_server_11.TomMethodMetadata>(value, 'metadata'),
    },
    methods: {
      'handlePreflight': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_11.TomEndpointHandler>(target, 'TomEndpointHandler');
        D4.requireMinArgs(positional, 1, 'handlePreflight');
        final req = D4.getRequiredArg<$shelf_3.Request>(positional, 0, 'req', 'handlePreflight');
        return t.handlePreflight(req);
      },
      'handleMethodCall': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_11.TomEndpointHandler>(target, 'TomEndpointHandler');
        D4.requireMinArgs(positional, 1, 'handleMethodCall');
        final req = D4.getRequiredArg<$shelf_3.Request>(positional, 0, 'req', 'handleMethodCall');
        return t.handleMethodCall(req);
      },
      'checkAccess': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_11.TomEndpointHandler>(target, 'TomEndpointHandler');
        D4.requireMinArgs(positional, 1, 'checkAccess');
        final principal = D4.getRequiredArg<$tom_core_kernel_9.TomPrincipal?>(positional, 0, 'principal', 'checkAccess');
        return t.checkAccess(principal);
      },
      'checkAutomaticAccess': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_11.TomEndpointHandler>(target, 'TomEndpointHandler');
        D4.requireMinArgs(positional, 1, 'checkAutomaticAccess');
        final accessCheck = D4.getRequiredArg<bool>(positional, 0, 'accessCheck', 'checkAutomaticAccess');
        return t.checkAutomaticAccess(accessCheck);
      },
    },
    staticGetters: {
      'globalSettingLogRequestsDefault': (visitor) => $tom_core_server_11.TomEndpointHandler.globalSettingLogRequestsDefault,
      'globalSettingCorsAllowedOriginsDefault': (visitor) => $tom_core_server_11.TomEndpointHandler.globalSettingCorsAllowedOriginsDefault,
      'globalSettingCorsAllowedMethodsDefault': (visitor) => $tom_core_server_11.TomEndpointHandler.globalSettingCorsAllowedMethodsDefault,
      'globalSettingCorsAllowedHeadersDefault': (visitor) => $tom_core_server_11.TomEndpointHandler.globalSettingCorsAllowedHeadersDefault,
      'debugPrintContext': (visitor) => $tom_core_server_11.TomEndpointHandler.debugPrintContext,
      'debugPrintAuthentication': (visitor) => $tom_core_server_11.TomEndpointHandler.debugPrintAuthentication,
    },
    staticSetters: {
      'globalSettingLogRequestsDefault': (visitor, value) => 
        $tom_core_server_11.TomEndpointHandler.globalSettingLogRequestsDefault = D4.extractBridgedArg<bool>(value, 'globalSettingLogRequestsDefault'),
      'globalSettingCorsAllowedOriginsDefault': (visitor, value) => 
        $tom_core_server_11.TomEndpointHandler.globalSettingCorsAllowedOriginsDefault = D4.extractBridgedArg<String>(value, 'globalSettingCorsAllowedOriginsDefault'),
      'globalSettingCorsAllowedMethodsDefault': (visitor, value) => 
        $tom_core_server_11.TomEndpointHandler.globalSettingCorsAllowedMethodsDefault = D4.extractBridgedArg<String>(value, 'globalSettingCorsAllowedMethodsDefault'),
      'globalSettingCorsAllowedHeadersDefault': (visitor, value) => 
        $tom_core_server_11.TomEndpointHandler.globalSettingCorsAllowedHeadersDefault = D4.extractBridgedArg<String>(value, 'globalSettingCorsAllowedHeadersDefault'),
      'debugPrintContext': (visitor, value) => 
        $tom_core_server_11.TomEndpointHandler.debugPrintContext = D4.extractBridgedArg<bool>(value, 'debugPrintContext'),
      'debugPrintAuthentication': (visitor, value) => 
        $tom_core_server_11.TomEndpointHandler.debugPrintAuthentication = D4.extractBridgedArg<bool>(value, 'debugPrintAuthentication'),
    },
    constructorSignatures: {
      '': 'TomEndpointHandler({required String name, required InstanceMirror instance, required MethodMirror method, ClassMirror<dynamic>? interface, required ClassMirror<dynamic> implementation, required String methodName, required TomMethodMetadata metadata})',
    },
    methodSignatures: {
      'handlePreflight': 'Response handlePreflight(Request req)',
      'handleMethodCall': 'Future<Response> handleMethodCall(Request req)',
      'checkAccess': 'bool checkAccess(TomPrincipal? principal)',
      'checkAutomaticAccess': 'bool checkAutomaticAccess(bool accessCheck)',
    },
    getterSignatures: {
      'name': 'String get name',
      'instance': 'InstanceMirror get instance',
      'method': 'MethodMirror get method',
      'interface': 'ClassMirror? get interface',
      'implementation': 'ClassMirror get implementation',
      'methodName': 'String get methodName',
      'metadata': 'TomMethodMetadata get metadata',
    },
    setterSignatures: {
      'name': 'set name(dynamic value)',
      'instance': 'set instance(dynamic value)',
      'method': 'set method(dynamic value)',
      'interface': 'set interface(dynamic value)',
      'implementation': 'set implementation(dynamic value)',
      'methodName': 'set methodName(dynamic value)',
      'metadata': 'set metadata(dynamic value)',
    },
    staticGetterSignatures: {
      'globalSettingLogRequestsDefault': 'bool get globalSettingLogRequestsDefault',
      'globalSettingCorsAllowedOriginsDefault': 'String get globalSettingCorsAllowedOriginsDefault',
      'globalSettingCorsAllowedMethodsDefault': 'String get globalSettingCorsAllowedMethodsDefault',
      'globalSettingCorsAllowedHeadersDefault': 'String get globalSettingCorsAllowedHeadersDefault',
      'debugPrintContext': 'bool get debugPrintContext',
      'debugPrintAuthentication': 'bool get debugPrintAuthentication',
    },
    staticSetterSignatures: {
      'globalSettingLogRequestsDefault': 'set globalSettingLogRequestsDefault(dynamic value)',
      'globalSettingCorsAllowedOriginsDefault': 'set globalSettingCorsAllowedOriginsDefault(dynamic value)',
      'globalSettingCorsAllowedMethodsDefault': 'set globalSettingCorsAllowedMethodsDefault(dynamic value)',
      'globalSettingCorsAllowedHeadersDefault': 'set globalSettingCorsAllowedHeadersDefault(dynamic value)',
      'debugPrintContext': 'set debugPrintContext(dynamic value)',
      'debugPrintAuthentication': 'set debugPrintAuthentication(dynamic value)',
    },
  );
}

// =============================================================================
// TomEndpointRoutingInfo Bridge
// =============================================================================

BridgedClass _createTomEndpointRoutingInfoBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_11.TomEndpointRoutingInfo,
    name: 'TomEndpointRoutingInfo',
    isAssignable: (v) => v is $tom_core_server_11.TomEndpointRoutingInfo,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'TomEndpointRoutingInfo');
        final handler = D4.getRequiredArg<$tom_core_server_11.TomEndpointHandler>(positional, 0, 'handler', 'TomEndpointRoutingInfo');
        final endpoint = D4.getRequiredArg<$tom_core_server_10.TomEndpoint<Object, Object>>(positional, 1, 'endpoint', 'TomEndpointRoutingInfo');
        return $tom_core_server_11.TomEndpointRoutingInfo(handler, endpoint);
      },
    },
    getters: {
      'handler': (visitor, target) => D4.validateTarget<$tom_core_server_11.TomEndpointRoutingInfo>(target, 'TomEndpointRoutingInfo').handler,
      'endpoint': (visitor, target) => D4.validateTarget<$tom_core_server_11.TomEndpointRoutingInfo>(target, 'TomEndpointRoutingInfo').endpoint,
    },
    setters: {
      'handler': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_11.TomEndpointRoutingInfo>(target, 'TomEndpointRoutingInfo').handler = D4.extractBridgedArg<$tom_core_server_11.TomEndpointHandler>(value, 'handler'),
      'endpoint': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_11.TomEndpointRoutingInfo>(target, 'TomEndpointRoutingInfo').endpoint = D4.extractBridgedArg<$tom_core_server_10.TomEndpoint>(value, 'endpoint'),
    },
    constructorSignatures: {
      '': 'TomEndpointRoutingInfo(TomEndpointHandler handler, TomEndpoint<Object, Object> endpoint)',
    },
    getterSignatures: {
      'handler': 'TomEndpointHandler get handler',
      'endpoint': 'TomEndpoint get endpoint',
    },
    setterSignatures: {
      'handler': 'set handler(dynamic value)',
      'endpoint': 'set endpoint(dynamic value)',
    },
  );
}

// =============================================================================
// TomEndpointRouting Bridge
// =============================================================================

BridgedClass _createTomEndpointRoutingBridge() {
  return BridgedClass(
    nativeType: TomEndpointRouting,
    name: 'TomEndpointRouting',
    isAssignable: (v) => v is TomEndpointRouting,
    constructors: {
      '': (visitor, positional, named) {
        return TomEndpointRouting();
      },
    },
    methods: {
      'scanClasses': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomEndpointRouting>(target, 'TomEndpointRouting');
        return t.scanClasses();
      },
      'initializeRouter': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomEndpointRouting>(target, 'TomEndpointRouting');
        return t.initializeRouter();
      },
      'createRoutesForClassMirror': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomEndpointRouting>(target, 'TomEndpointRouting');
        D4.requireMinArgs(positional, 3, 'createRoutesForClassMirror');
        final serviceType = D4.getRequiredArg<$tom_reflection_1.ClassMirror>(positional, 0, 'serviceType', 'createRoutesForClassMirror');
        final serviceInstance = D4.getRequiredArg<Object?>(positional, 1, 'serviceInstance', 'createRoutesForClassMirror');
        final router = D4.getRequiredArg<$shelf_router_1.Router>(positional, 2, 'router', 'createRoutesForClassMirror');
        t.createRoutesForClassMirror(serviceType, serviceInstance, router);
        return null;
      },
      'getReferencedComponent': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomEndpointRouting>(target, 'TomEndpointRouting');
        D4.requireMinArgs(positional, 1, 'getReferencedComponent');
        final serviceType = D4.getRequiredArg<$tom_reflection_1.ClassMirror>(positional, 0, 'serviceType', 'getReferencedComponent');
        return t.getReferencedComponent(serviceType);
      },
      'createRoutesForEndpoint': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomEndpointRouting>(target, 'TomEndpointRouting');
        D4.requireMinArgs(positional, 5, 'createRoutesForEndpoint');
        final tep = D4.getRequiredArg<$tom_core_server_10.TomEndpoint<Object, Object>>(positional, 0, 'tep', 'createRoutesForEndpoint');
        final router = D4.getRequiredArg<$shelf_router_1.Router>(positional, 1, 'router', 'createRoutesForEndpoint');
        final teph = D4.getRequiredArg<$tom_core_server_11.TomEndpointHandler>(positional, 2, 'teph', 'createRoutesForEndpoint');
        final mmd = D4.getRequiredArg<$tom_core_server_11.TomMethodMetadata>(positional, 3, 'mmd', 'createRoutesForEndpoint');
        final instanceClassMirror = D4.getRequiredArg<$tom_reflection_1.ClassMirror>(positional, 4, 'instanceClassMirror', 'createRoutesForEndpoint');
        t.createRoutesForEndpoint(tep, router, teph, mmd, instanceClassMirror);
        return null;
      },
      'getClassMethodMetadata': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomEndpointRouting>(target, 'TomEndpointRouting');
        D4.requireMinArgs(positional, 1, 'getClassMethodMetadata');
        final classMirror = D4.getRequiredArg<$tom_reflection_1.ClassMirror>(positional, 0, 'classMirror', 'getClassMethodMetadata');
        return t.getClassMethodMetadata(classMirror);
      },
      'findServiceInstance': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomEndpointRouting>(target, 'TomEndpointRouting');
        D4.requireMinArgs(positional, 3, 'findServiceInstance');
        if (positional.isEmpty) {
          throw ArgumentError('findServiceInstance: Missing required argument "componentClasses" at position 0');
        }
        final componentClasses = D4.coerceList<$tom_reflection_1.ClassMirror>(positional[0], 'componentClasses');
        final serviceType = D4.getRequiredArg<$tom_reflection_1.ClassMirror>(positional, 1, 'serviceType', 'findServiceInstance');
        final serviceInstance = D4.getRequiredArg<Object?>(positional, 2, 'serviceInstance', 'findServiceInstance');
        return t.findServiceInstance(componentClasses, serviceType, serviceInstance);
      },
    },
    staticGetters: {
      'handlers': (visitor) => TomEndpointRouting.handlers,
      'routingInfo': (visitor) => TomEndpointRouting.routingInfo,
    },
    staticSetters: {
      'handlers': (visitor, value) => 
        TomEndpointRouting.handlers = (value as List).cast<$tom_core_server_11.TomEndpointHandler>().toList(),
      'routingInfo': (visitor, value) => 
        TomEndpointRouting.routingInfo = (value as Map).cast<String, $tom_core_server_11.TomEndpointRoutingInfo>(),
    },
    constructorSignatures: {
      '': 'TomEndpointRouting()',
    },
    methodSignatures: {
      'scanClasses': 'TomClassScanResult scanClasses()',
      'initializeRouter': 'Router initializeRouter()',
      'createRoutesForClassMirror': 'void createRoutesForClassMirror(ClassMirror serviceType, Object? serviceInstance, Router router)',
      'getReferencedComponent': 'Object? getReferencedComponent(ClassMirror serviceType)',
      'createRoutesForEndpoint': 'void createRoutesForEndpoint(TomEndpoint<Object, Object> tep, Router router, TomEndpointHandler teph, TomMethodMetadata mmd, ClassMirror instanceClassMirror)',
      'getClassMethodMetadata': 'List<TomMethodMetadata> getClassMethodMetadata(ClassMirror classMirror)',
      'findServiceInstance': 'Object? findServiceInstance(List<ClassMirror> componentClasses, ClassMirror serviceType, Object? serviceInstance)',
    },
    staticGetterSignatures: {
      'handlers': 'List<TomEndpointHandler> get handlers',
      'routingInfo': 'Map<String, TomEndpointRoutingInfo> get routingInfo',
    },
    staticSetterSignatures: {
      'handlers': 'set handlers(dynamic value)',
      'routingInfo': 'set routingInfo(dynamic value)',
    },
  );
}

// =============================================================================
// TomMethodMetadata Bridge
// =============================================================================

BridgedClass _createTomMethodMetadataBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_11.TomMethodMetadata,
    name: 'TomMethodMetadata',
    isAssignable: (v) => v is $tom_core_server_11.TomMethodMetadata,
    constructors: {
      '': (visitor, positional, named) {
        final endpoint = D4.getRequiredNamedArg<$tom_core_server_10.TomEndpoint<Object, Object>>(named, 'endpoint', 'TomMethodMetadata');
        final methodMirror = D4.getRequiredNamedArg<$tom_reflection_1.MethodMirror>(named, 'methodMirror', 'TomMethodMetadata');
        final access = D4.getOptionalNamedArg<$tom_core_kernel_7.TomAccessControl?>(named, 'access');
        final transactionInfo = D4.getOptionalNamedArg<$tom_core_server_10.TomTransactional?>(named, 'transactionInfo');
        final apiEndpointImplementation = D4.getOptionalNamedArg<$tom_core_server_10.TomApiEndpointImplementation<Object, Object>?>(named, 'apiEndpointImplementation');
        final apiImplementation = D4.getOptionalNamedArg<$tom_core_server_10.TomApiImplementation?>(named, 'apiImplementation');
        final api = D4.getOptionalNamedArg<$tom_core_kernel_1.TomApi?>(named, 'api');
        final apiEndpoint = D4.getOptionalNamedArg<$tom_core_kernel_1.TomApiEndpoint<dynamic, dynamic>?>(named, 'apiEndpoint');
        return $tom_core_server_11.TomMethodMetadata(endpoint: endpoint, methodMirror: methodMirror, access: access, transactionInfo: transactionInfo, apiEndpointImplementation: apiEndpointImplementation, apiImplementation: apiImplementation, api: api, apiEndpoint: apiEndpoint);
      },
    },
    getters: {
      'methodMirror': (visitor, target) => D4.validateTarget<$tom_core_server_11.TomMethodMetadata>(target, 'TomMethodMetadata').methodMirror,
      'endpoint': (visitor, target) => D4.validateTarget<$tom_core_server_11.TomMethodMetadata>(target, 'TomMethodMetadata').endpoint,
      'access': (visitor, target) => D4.validateTarget<$tom_core_server_11.TomMethodMetadata>(target, 'TomMethodMetadata').access,
      'transactionInfo': (visitor, target) => D4.validateTarget<$tom_core_server_11.TomMethodMetadata>(target, 'TomMethodMetadata').transactionInfo,
      'apiEndpointImplementation': (visitor, target) => D4.validateTarget<$tom_core_server_11.TomMethodMetadata>(target, 'TomMethodMetadata').apiEndpointImplementation,
      'apiImplementation': (visitor, target) => D4.validateTarget<$tom_core_server_11.TomMethodMetadata>(target, 'TomMethodMetadata').apiImplementation,
      'api': (visitor, target) => D4.validateTarget<$tom_core_server_11.TomMethodMetadata>(target, 'TomMethodMetadata').api,
      'apiEndpoint': (visitor, target) => D4.validateTarget<$tom_core_server_11.TomMethodMetadata>(target, 'TomMethodMetadata').apiEndpoint,
    },
    setters: {
      'methodMirror': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_11.TomMethodMetadata>(target, 'TomMethodMetadata').methodMirror = D4.extractBridgedArg<$tom_reflection_1.MethodMirror>(value, 'methodMirror'),
      'endpoint': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_11.TomMethodMetadata>(target, 'TomMethodMetadata').endpoint = D4.extractBridgedArg<$tom_core_server_10.TomEndpoint>(value, 'endpoint'),
      'access': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_11.TomMethodMetadata>(target, 'TomMethodMetadata').access = D4.extractBridgedArgOrNull<$tom_core_kernel_7.TomAccessControl>(value, 'access'),
      'transactionInfo': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_11.TomMethodMetadata>(target, 'TomMethodMetadata').transactionInfo = D4.extractBridgedArgOrNull<$tom_core_server_10.TomTransactional>(value, 'transactionInfo'),
      'apiEndpointImplementation': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_11.TomMethodMetadata>(target, 'TomMethodMetadata').apiEndpointImplementation = D4.extractBridgedArgOrNull<$tom_core_server_10.TomApiEndpointImplementation>(value, 'apiEndpointImplementation'),
      'apiImplementation': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_11.TomMethodMetadata>(target, 'TomMethodMetadata').apiImplementation = D4.extractBridgedArgOrNull<$tom_core_server_10.TomApiImplementation>(value, 'apiImplementation'),
      'api': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_11.TomMethodMetadata>(target, 'TomMethodMetadata').api = D4.extractBridgedArgOrNull<$tom_core_kernel_1.TomApi>(value, 'api'),
      'apiEndpoint': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_11.TomMethodMetadata>(target, 'TomMethodMetadata').apiEndpoint = D4.extractBridgedArgOrNull<$tom_core_kernel_1.TomApiEndpoint>(value, 'apiEndpoint'),
    },
    constructorSignatures: {
      '': 'TomMethodMetadata({required TomEndpoint<Object, Object> endpoint, required MethodMirror methodMirror, TomAccessControl? access, TomTransactional? transactionInfo, TomApiEndpointImplementation<Object, Object>? apiEndpointImplementation, TomApiImplementation? apiImplementation, TomApi? api, TomApiEndpoint<dynamic, dynamic>? apiEndpoint})',
    },
    getterSignatures: {
      'methodMirror': 'MethodMirror get methodMirror',
      'endpoint': 'TomEndpoint get endpoint',
      'access': 'TomAccessControl? get access',
      'transactionInfo': 'TomTransactional? get transactionInfo',
      'apiEndpointImplementation': 'TomApiEndpointImplementation? get apiEndpointImplementation',
      'apiImplementation': 'TomApiImplementation? get apiImplementation',
      'api': 'TomApi? get api',
      'apiEndpoint': 'TomApiEndpoint? get apiEndpoint',
    },
    setterSignatures: {
      'methodMirror': 'set methodMirror(dynamic value)',
      'endpoint': 'set endpoint(dynamic value)',
      'access': 'set access(dynamic value)',
      'transactionInfo': 'set transactionInfo(dynamic value)',
      'apiEndpointImplementation': 'set apiEndpointImplementation(dynamic value)',
      'apiImplementation': 'set apiImplementation(dynamic value)',
      'api': 'set api(dynamic value)',
      'apiEndpoint': 'set apiEndpoint(dynamic value)',
    },
  );
}

// =============================================================================
// TomClassScanResult Bridge
// =============================================================================

BridgedClass _createTomClassScanResultBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_11.TomClassScanResult,
    name: 'TomClassScanResult',
    isAssignable: (v) => v is $tom_core_server_11.TomClassScanResult,
    constructors: {
      '': (visitor, positional, named) {
        final serviceInterfaces = named.containsKey('serviceInterfaces') && named['serviceInterfaces'] != null
            ? D4.coerceList<$tom_reflection_1.ClassMirror<dynamic>>(named['serviceInterfaces'], 'serviceInterfaces')
            : const <$tom_reflection_1.ClassMirror<dynamic>>[];
        final apiImplementations = named.containsKey('apiImplementations') && named['apiImplementations'] != null
            ? D4.coerceList<$tom_reflection_1.ClassMirror<dynamic>>(named['apiImplementations'], 'apiImplementations')
            : const <$tom_reflection_1.ClassMirror<dynamic>>[];
        final componentClasses = named.containsKey('componentClasses') && named['componentClasses'] != null
            ? D4.coerceList<$tom_reflection_1.ClassMirror<dynamic>>(named['componentClasses'], 'componentClasses')
            : const <$tom_reflection_1.ClassMirror<dynamic>>[];
        return $tom_core_server_11.TomClassScanResult(serviceInterfaces: serviceInterfaces, apiImplementations: apiImplementations, componentClasses: componentClasses);
      },
    },
    getters: {
      'serviceInterfaces': (visitor, target) => D4.validateTarget<$tom_core_server_11.TomClassScanResult>(target, 'TomClassScanResult').serviceInterfaces,
      'apiImplementations': (visitor, target) => D4.validateTarget<$tom_core_server_11.TomClassScanResult>(target, 'TomClassScanResult').apiImplementations,
      'componentClasses': (visitor, target) => D4.validateTarget<$tom_core_server_11.TomClassScanResult>(target, 'TomClassScanResult').componentClasses,
    },
    setters: {
      'serviceInterfaces': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_11.TomClassScanResult>(target, 'TomClassScanResult').serviceInterfaces = (value as List).cast<$tom_reflection_1.ClassMirror>().toList(),
      'apiImplementations': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_11.TomClassScanResult>(target, 'TomClassScanResult').apiImplementations = (value as List).cast<$tom_reflection_1.ClassMirror>().toList(),
      'componentClasses': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_11.TomClassScanResult>(target, 'TomClassScanResult').componentClasses = (value as List).cast<$tom_reflection_1.ClassMirror>().toList(),
    },
    constructorSignatures: {
      '': 'TomClassScanResult({List<ClassMirror<dynamic>> serviceInterfaces = const [], List<ClassMirror<dynamic>> apiImplementations = const [], List<ClassMirror<dynamic>> componentClasses = const []})',
    },
    getterSignatures: {
      'serviceInterfaces': 'List<ClassMirror> get serviceInterfaces',
      'apiImplementations': 'List<ClassMirror> get apiImplementations',
      'componentClasses': 'List<ClassMirror> get componentClasses',
    },
    setterSignatures: {
      'serviceInterfaces': 'set serviceInterfaces(dynamic value)',
      'apiImplementations': 'set apiImplementations(dynamic value)',
      'componentClasses': 'set componentClasses(dynamic value)',
    },
  );
}

// =============================================================================
// HealthAnalyzer Bridge
// =============================================================================

BridgedClass _createHealthAnalyzerBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_12.HealthAnalyzer,
    name: 'HealthAnalyzer',
    isAssignable: (v) => v is $tom_core_server_12.HealthAnalyzer,
    constructors: {
    },
    methods: {
      'analyzeHealth': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_12.HealthAnalyzer>(target, 'HealthAnalyzer');
        return t.analyzeHealth();
      },
    },
    methodSignatures: {
      'analyzeHealth': 'Future<String> analyzeHealth()',
    },
  );
}

// =============================================================================
// DefaultHealthAnalyzer Bridge
// =============================================================================

BridgedClass _createDefaultHealthAnalyzerBridge() {
  return BridgedClass(
    nativeType: DefaultHealthAnalyzer,
    name: 'DefaultHealthAnalyzer',
    isAssignable: (v) => v is DefaultHealthAnalyzer,
    constructors: {
      '': (visitor, positional, named) {
        return DefaultHealthAnalyzer();
      },
    },
    methods: {
      'analyzeHealth': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DefaultHealthAnalyzer>(target, 'DefaultHealthAnalyzer');
        return t.analyzeHealth();
      },
    },
    constructorSignatures: {
      '': 'DefaultHealthAnalyzer()',
    },
    methodSignatures: {
      'analyzeHealth': 'Future<String> analyzeHealth()',
    },
  );
}

// =============================================================================
// TomHealthService Bridge
// =============================================================================

BridgedClass _createTomHealthServiceBridge() {
  return BridgedClass(
    nativeType: TomHealthService,
    name: 'TomHealthService',
    isAssignable: (v) => v is TomHealthService,
    constructors: {
    },
    methods: {
      'health': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomHealthService>(target, 'TomHealthService');
        return t.health();
      },
    },
    methodSignatures: {
      'health': 'Future<String> health()',
    },
  );
}

// =============================================================================
// TomHealthServer Bridge
// =============================================================================

BridgedClass _createTomHealthServerBridge() {
  return BridgedClass(
    nativeType: TomHealthServer,
    name: 'TomHealthServer',
    isAssignable: (v) => v is TomHealthServer,
    constructors: {
      '': (visitor, positional, named) {
        return TomHealthServer();
      },
    },
    methods: {
      'health': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomHealthServer>(target, 'TomHealthServer');
        return t.health();
      },
    },
    staticGetters: {
      'globalSettingsHealthAnalyzer': (visitor) => TomHealthServer.globalSettingsHealthAnalyzer,
    },
    staticSetters: {
      'globalSettingsHealthAnalyzer': (visitor, value) => 
        TomHealthServer.globalSettingsHealthAnalyzer = D4.extractBridgedArg<$tom_core_server_12.HealthAnalyzer>(value, 'globalSettingsHealthAnalyzer'),
    },
    constructorSignatures: {
      '': 'TomHealthServer()',
    },
    methodSignatures: {
      'health': 'Future<String> health()',
    },
    staticGetterSignatures: {
      'globalSettingsHealthAnalyzer': 'HealthAnalyzer get globalSettingsHealthAnalyzer',
    },
    staticSetterSignatures: {
      'globalSettingsHealthAnalyzer': 'set globalSettingsHealthAnalyzer(dynamic value)',
    },
  );
}

// =============================================================================
// TomServerException Bridge
// =============================================================================

BridgedClass _createTomServerExceptionBridge() {
  return BridgedClass(
    nativeType: TomServerException,
    name: 'TomServerException',
    isAssignable: (v) => v is TomServerException,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'TomServerException');
        final key = D4.getRequiredArg<String>(positional, 0, 'key', 'TomServerException');
        final defaultUserMessage = D4.getRequiredArg<String>(positional, 1, 'defaultUserMessage', 'TomServerException');
        final parameters = D4.coerceMapOrNull<String, Object?>(named['parameters'], 'parameters');
        final stack = D4.getOptionalNamedArg<Object?>(named, 'stack');
        final rootException = D4.getOptionalNamedArg<Object?>(named, 'rootException');
        final autoLog = D4.getNamedArgWithDefault<bool>(named, 'autoLog', false);
        final clientThrow = D4.getNamedArgWithDefault<bool>(named, 'clientThrow', true);
        return TomServerException(key, defaultUserMessage, parameters: parameters, stack: stack, rootException: rootException, autoLog: autoLog, clientThrow: clientThrow);
      },
    },
    getters: {
      'isolateName': (visitor, target) => D4.validateTarget<TomServerException>(target, 'TomServerException').isolateName,
      'clientThrow': (visitor, target) => D4.validateTarget<TomServerException>(target, 'TomServerException').clientThrow,
      'autoLog': (visitor, target) => D4.validateTarget<TomServerException>(target, 'TomServerException').autoLog,
      'serverCallError': (visitor, target) => D4.validateTarget<TomServerException>(target, 'TomServerException').serverCallError,
      'newField': (visitor, target) => D4.validateTarget<TomServerException>(target, 'TomServerException').newField,
      'logRepresentation': (visitor, target) => D4.validateTarget<TomServerException>(target, 'TomServerException').logRepresentation,
      'uuid': (visitor, target) => D4.validateTarget<TomServerException>(target, 'TomServerException').uuid,
      'requestUuid': (visitor, target) => D4.validateTarget<TomServerException>(target, 'TomServerException').requestUuid,
      'timeStamp': (visitor, target) => D4.validateTarget<TomServerException>(target, 'TomServerException').timeStamp,
      'key': (visitor, target) => D4.validateTarget<TomServerException>(target, 'TomServerException').key,
      'defaultUserMessage': (visitor, target) => D4.validateTarget<TomServerException>(target, 'TomServerException').defaultUserMessage,
      'parameters': (visitor, target) => D4.validateTarget<TomServerException>(target, 'TomServerException').parameters,
      'stack': (visitor, target) => D4.validateTarget<TomServerException>(target, 'TomServerException').stack,
      'rootException': (visitor, target) => D4.validateTarget<TomServerException>(target, 'TomServerException').rootException,
      'stackTrace': (visitor, target) => D4.validateTarget<TomServerException>(target, 'TomServerException').stackTrace,
    },
    setters: {
      'isolateName': (visitor, target, value) => 
        D4.validateTarget<TomServerException>(target, 'TomServerException').isolateName = D4.extractBridgedArg<String>(value, 'isolateName'),
      'clientThrow': (visitor, target, value) => 
        D4.validateTarget<TomServerException>(target, 'TomServerException').clientThrow = D4.extractBridgedArg<bool>(value, 'clientThrow'),
      'autoLog': (visitor, target, value) => 
        D4.validateTarget<TomServerException>(target, 'TomServerException').autoLog = D4.extractBridgedArg<bool>(value, 'autoLog'),
      'serverCallError': (visitor, target, value) => 
        D4.validateTarget<TomServerException>(target, 'TomServerException').serverCallError = D4.extractBridgedArgOrNull<$tom_core_kernel_4.TomServerCallError>(value, 'serverCallError'),
      'newField': (visitor, target, value) => 
        D4.validateTarget<TomServerException>(target, 'TomServerException').newField = D4.extractBridgedArgOrNull<String>(value, 'newField'),
      'uuid': (visitor, target, value) => 
        D4.validateTarget<TomServerException>(target, 'TomServerException').uuid = D4.extractBridgedArg<String>(value, 'uuid'),
      'requestUuid': (visitor, target, value) => 
        D4.validateTarget<TomServerException>(target, 'TomServerException').requestUuid = D4.extractBridgedArgOrNull<String>(value, 'requestUuid'),
      'timeStamp': (visitor, target, value) => 
        D4.validateTarget<TomServerException>(target, 'TomServerException').timeStamp = D4.extractBridgedArg<DateTime>(value, 'timeStamp'),
      'key': (visitor, target, value) => 
        D4.validateTarget<TomServerException>(target, 'TomServerException').key = D4.extractBridgedArg<String>(value, 'key'),
      'defaultUserMessage': (visitor, target, value) => 
        D4.validateTarget<TomServerException>(target, 'TomServerException').defaultUserMessage = D4.extractBridgedArg<String>(value, 'defaultUserMessage'),
      'stack': (visitor, target, value) => 
        D4.validateTarget<TomServerException>(target, 'TomServerException').stack = D4.extractBridgedArgOrNull<Object>(value, 'stack'),
      'rootException': (visitor, target, value) => 
        D4.validateTarget<TomServerException>(target, 'TomServerException').rootException = D4.extractBridgedArgOrNull<Object>(value, 'rootException'),
      'stackTrace': (visitor, target, value) => 
        D4.validateTarget<TomServerException>(target, 'TomServerException').stackTrace = D4.extractBridgedArg<String>(value, 'stackTrace'),
    },
    methods: {
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomServerException>(target, 'TomServerException');
        return t.toString();
      },
      'printStackTrace': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomServerException>(target, 'TomServerException');
        final depth = D4.getOptionalArgWithDefault<int>(positional, 0, 'depth', -1);
        t.printStackTrace(depth);
        return null;
      },
    },
    constructorSignatures: {
      '': 'TomServerException(String key, String defaultUserMessage, {Map<String, Object?>? parameters, Object? stack, Object? rootException, bool autoLog = false, bool clientThrow = true})',
    },
    methodSignatures: {
      'toString': 'String toString()',
      'printStackTrace': 'void printStackTrace([int depth = -1])',
    },
    getterSignatures: {
      'isolateName': 'String get isolateName',
      'clientThrow': 'bool get clientThrow',
      'autoLog': 'bool get autoLog',
      'serverCallError': 'TomServerCallError? get serverCallError',
      'newField': 'String? get newField',
      'logRepresentation': 'String get logRepresentation',
      'uuid': 'String get uuid',
      'requestUuid': 'String? get requestUuid',
      'timeStamp': 'DateTime get timeStamp',
      'key': 'String get key',
      'defaultUserMessage': 'String get defaultUserMessage',
      'parameters': 'Map<String, Object?>? get parameters',
      'stack': 'Object? get stack',
      'rootException': 'Object? get rootException',
      'stackTrace': 'String get stackTrace',
    },
    setterSignatures: {
      'isolateName': 'set isolateName(dynamic value)',
      'clientThrow': 'set clientThrow(dynamic value)',
      'autoLog': 'set autoLog(bool value)',
      'serverCallError': 'set serverCallError(TomServerCallError? value)',
      'newField': 'set newField(String? value)',
      'uuid': 'set uuid(String value)',
      'requestUuid': 'set requestUuid(String? value)',
      'timeStamp': 'set timeStamp(DateTime value)',
      'key': 'set key(String value)',
      'defaultUserMessage': 'set defaultUserMessage(String value)',
      'parameters': 'set parameters(Map<String, Object?>? value)',
      'stack': 'set stack(Object? value)',
      'rootException': 'set rootException(Object? value)',
      'stackTrace': 'set stackTrace(String value)',
    },
  );
}

// =============================================================================
// TomAnnotationAnalyzerException Bridge
// =============================================================================

BridgedClass _createTomAnnotationAnalyzerExceptionBridge() {
  return BridgedClass(
    nativeType: TomAnnotationAnalyzerException,
    name: 'TomAnnotationAnalyzerException',
    isAssignable: (v) => v is TomAnnotationAnalyzerException,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'TomAnnotationAnalyzerException');
        final key = D4.getRequiredArg<String>(positional, 0, 'key', 'TomAnnotationAnalyzerException');
        final defaultUserMessage = D4.getRequiredArg<String>(positional, 1, 'defaultUserMessage', 'TomAnnotationAnalyzerException');
        final parameters = D4.coerceMapOrNull<String, Object?>(named['parameters'], 'parameters');
        final stack = D4.getOptionalNamedArg<Object?>(named, 'stack');
        final rootException = D4.getOptionalNamedArg<Object?>(named, 'rootException');
        final autoLog = D4.getNamedArgWithDefault<bool>(named, 'autoLog', false);
        return TomAnnotationAnalyzerException(key, defaultUserMessage, parameters: parameters, stack: stack, rootException: rootException, autoLog: autoLog);
      },
    },
    getters: {
      'isolateName': (visitor, target) => D4.validateTarget<TomAnnotationAnalyzerException>(target, 'TomAnnotationAnalyzerException').isolateName,
      'clientThrow': (visitor, target) => D4.validateTarget<TomAnnotationAnalyzerException>(target, 'TomAnnotationAnalyzerException').clientThrow,
      'autoLog': (visitor, target) => D4.validateTarget<TomAnnotationAnalyzerException>(target, 'TomAnnotationAnalyzerException').autoLog,
      'serverCallError': (visitor, target) => D4.validateTarget<TomAnnotationAnalyzerException>(target, 'TomAnnotationAnalyzerException').serverCallError,
      'newField': (visitor, target) => D4.validateTarget<TomAnnotationAnalyzerException>(target, 'TomAnnotationAnalyzerException').newField,
      'logRepresentation': (visitor, target) => D4.validateTarget<TomAnnotationAnalyzerException>(target, 'TomAnnotationAnalyzerException').logRepresentation,
      'uuid': (visitor, target) => D4.validateTarget<TomAnnotationAnalyzerException>(target, 'TomAnnotationAnalyzerException').uuid,
      'requestUuid': (visitor, target) => D4.validateTarget<TomAnnotationAnalyzerException>(target, 'TomAnnotationAnalyzerException').requestUuid,
      'timeStamp': (visitor, target) => D4.validateTarget<TomAnnotationAnalyzerException>(target, 'TomAnnotationAnalyzerException').timeStamp,
      'key': (visitor, target) => D4.validateTarget<TomAnnotationAnalyzerException>(target, 'TomAnnotationAnalyzerException').key,
      'defaultUserMessage': (visitor, target) => D4.validateTarget<TomAnnotationAnalyzerException>(target, 'TomAnnotationAnalyzerException').defaultUserMessage,
      'parameters': (visitor, target) => D4.validateTarget<TomAnnotationAnalyzerException>(target, 'TomAnnotationAnalyzerException').parameters,
      'stack': (visitor, target) => D4.validateTarget<TomAnnotationAnalyzerException>(target, 'TomAnnotationAnalyzerException').stack,
      'rootException': (visitor, target) => D4.validateTarget<TomAnnotationAnalyzerException>(target, 'TomAnnotationAnalyzerException').rootException,
      'stackTrace': (visitor, target) => D4.validateTarget<TomAnnotationAnalyzerException>(target, 'TomAnnotationAnalyzerException').stackTrace,
    },
    setters: {
      'isolateName': (visitor, target, value) => 
        D4.validateTarget<TomAnnotationAnalyzerException>(target, 'TomAnnotationAnalyzerException').isolateName = D4.extractBridgedArg<String>(value, 'isolateName'),
      'clientThrow': (visitor, target, value) => 
        D4.validateTarget<TomAnnotationAnalyzerException>(target, 'TomAnnotationAnalyzerException').clientThrow = D4.extractBridgedArg<bool>(value, 'clientThrow'),
      'autoLog': (visitor, target, value) => 
        D4.validateTarget<TomAnnotationAnalyzerException>(target, 'TomAnnotationAnalyzerException').autoLog = D4.extractBridgedArg<bool>(value, 'autoLog'),
      'serverCallError': (visitor, target, value) => 
        D4.validateTarget<TomAnnotationAnalyzerException>(target, 'TomAnnotationAnalyzerException').serverCallError = D4.extractBridgedArgOrNull<$tom_core_kernel_4.TomServerCallError>(value, 'serverCallError'),
      'newField': (visitor, target, value) => 
        D4.validateTarget<TomAnnotationAnalyzerException>(target, 'TomAnnotationAnalyzerException').newField = D4.extractBridgedArgOrNull<String>(value, 'newField'),
      'uuid': (visitor, target, value) => 
        D4.validateTarget<TomAnnotationAnalyzerException>(target, 'TomAnnotationAnalyzerException').uuid = D4.extractBridgedArg<String>(value, 'uuid'),
      'requestUuid': (visitor, target, value) => 
        D4.validateTarget<TomAnnotationAnalyzerException>(target, 'TomAnnotationAnalyzerException').requestUuid = D4.extractBridgedArgOrNull<String>(value, 'requestUuid'),
      'timeStamp': (visitor, target, value) => 
        D4.validateTarget<TomAnnotationAnalyzerException>(target, 'TomAnnotationAnalyzerException').timeStamp = D4.extractBridgedArg<DateTime>(value, 'timeStamp'),
      'key': (visitor, target, value) => 
        D4.validateTarget<TomAnnotationAnalyzerException>(target, 'TomAnnotationAnalyzerException').key = D4.extractBridgedArg<String>(value, 'key'),
      'defaultUserMessage': (visitor, target, value) => 
        D4.validateTarget<TomAnnotationAnalyzerException>(target, 'TomAnnotationAnalyzerException').defaultUserMessage = D4.extractBridgedArg<String>(value, 'defaultUserMessage'),
      'stack': (visitor, target, value) => 
        D4.validateTarget<TomAnnotationAnalyzerException>(target, 'TomAnnotationAnalyzerException').stack = D4.extractBridgedArgOrNull<Object>(value, 'stack'),
      'rootException': (visitor, target, value) => 
        D4.validateTarget<TomAnnotationAnalyzerException>(target, 'TomAnnotationAnalyzerException').rootException = D4.extractBridgedArgOrNull<Object>(value, 'rootException'),
      'stackTrace': (visitor, target, value) => 
        D4.validateTarget<TomAnnotationAnalyzerException>(target, 'TomAnnotationAnalyzerException').stackTrace = D4.extractBridgedArg<String>(value, 'stackTrace'),
    },
    methods: {
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomAnnotationAnalyzerException>(target, 'TomAnnotationAnalyzerException');
        return t.toString();
      },
      'printStackTrace': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomAnnotationAnalyzerException>(target, 'TomAnnotationAnalyzerException');
        final depth = D4.getOptionalArgWithDefault<int>(positional, 0, 'depth', -1);
        t.printStackTrace(depth);
        return null;
      },
    },
    constructorSignatures: {
      '': 'TomAnnotationAnalyzerException(String key, String defaultUserMessage, {Map<String, Object?>? parameters, Object? stack, Object? rootException, bool autoLog = false})',
    },
    methodSignatures: {
      'toString': 'String toString()',
      'printStackTrace': 'void printStackTrace([int depth = -1])',
    },
    getterSignatures: {
      'isolateName': 'String get isolateName',
      'clientThrow': 'bool get clientThrow',
      'autoLog': 'bool get autoLog',
      'serverCallError': 'TomServerCallError? get serverCallError',
      'newField': 'String? get newField',
      'logRepresentation': 'String get logRepresentation',
      'uuid': 'String get uuid',
      'requestUuid': 'String? get requestUuid',
      'timeStamp': 'DateTime get timeStamp',
      'key': 'String get key',
      'defaultUserMessage': 'String get defaultUserMessage',
      'parameters': 'Map<String, Object?>? get parameters',
      'stack': 'Object? get stack',
      'rootException': 'Object? get rootException',
      'stackTrace': 'String get stackTrace',
    },
    setterSignatures: {
      'isolateName': 'set isolateName(String value)',
      'clientThrow': 'set clientThrow(bool value)',
      'autoLog': 'set autoLog(bool value)',
      'serverCallError': 'set serverCallError(TomServerCallError? value)',
      'newField': 'set newField(String? value)',
      'uuid': 'set uuid(String value)',
      'requestUuid': 'set requestUuid(String? value)',
      'timeStamp': 'set timeStamp(DateTime value)',
      'key': 'set key(String value)',
      'defaultUserMessage': 'set defaultUserMessage(String value)',
      'parameters': 'set parameters(Map<String, Object?>? value)',
      'stack': 'set stack(Object? value)',
      'rootException': 'set rootException(Object? value)',
      'stackTrace': 'set stackTrace(String value)',
    },
  );
}

// =============================================================================
// TomAnnotationAnalyzerSyntaxException Bridge
// =============================================================================

BridgedClass _createTomAnnotationAnalyzerSyntaxExceptionBridge() {
  return BridgedClass(
    nativeType: TomAnnotationAnalyzerSyntaxException,
    name: 'TomAnnotationAnalyzerSyntaxException',
    isAssignable: (v) => v is TomAnnotationAnalyzerSyntaxException,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'TomAnnotationAnalyzerSyntaxException');
        final key = D4.getRequiredArg<String>(positional, 0, 'key', 'TomAnnotationAnalyzerSyntaxException');
        final defaultUserMessage = D4.getRequiredArg<String>(positional, 1, 'defaultUserMessage', 'TomAnnotationAnalyzerSyntaxException');
        final parameters = D4.coerceMapOrNull<String, Object?>(named['parameters'], 'parameters');
        final stack = D4.getOptionalNamedArg<Object?>(named, 'stack');
        final rootException = D4.getOptionalNamedArg<Object?>(named, 'rootException');
        final autoLog = D4.getNamedArgWithDefault<bool>(named, 'autoLog', false);
        return TomAnnotationAnalyzerSyntaxException(key, defaultUserMessage, parameters: parameters, stack: stack, rootException: rootException, autoLog: autoLog);
      },
    },
    getters: {
      'isolateName': (visitor, target) => D4.validateTarget<TomAnnotationAnalyzerSyntaxException>(target, 'TomAnnotationAnalyzerSyntaxException').isolateName,
      'clientThrow': (visitor, target) => D4.validateTarget<TomAnnotationAnalyzerSyntaxException>(target, 'TomAnnotationAnalyzerSyntaxException').clientThrow,
      'autoLog': (visitor, target) => D4.validateTarget<TomAnnotationAnalyzerSyntaxException>(target, 'TomAnnotationAnalyzerSyntaxException').autoLog,
      'serverCallError': (visitor, target) => D4.validateTarget<TomAnnotationAnalyzerSyntaxException>(target, 'TomAnnotationAnalyzerSyntaxException').serverCallError,
      'newField': (visitor, target) => D4.validateTarget<TomAnnotationAnalyzerSyntaxException>(target, 'TomAnnotationAnalyzerSyntaxException').newField,
      'logRepresentation': (visitor, target) => D4.validateTarget<TomAnnotationAnalyzerSyntaxException>(target, 'TomAnnotationAnalyzerSyntaxException').logRepresentation,
      'uuid': (visitor, target) => D4.validateTarget<TomAnnotationAnalyzerSyntaxException>(target, 'TomAnnotationAnalyzerSyntaxException').uuid,
      'requestUuid': (visitor, target) => D4.validateTarget<TomAnnotationAnalyzerSyntaxException>(target, 'TomAnnotationAnalyzerSyntaxException').requestUuid,
      'timeStamp': (visitor, target) => D4.validateTarget<TomAnnotationAnalyzerSyntaxException>(target, 'TomAnnotationAnalyzerSyntaxException').timeStamp,
      'key': (visitor, target) => D4.validateTarget<TomAnnotationAnalyzerSyntaxException>(target, 'TomAnnotationAnalyzerSyntaxException').key,
      'defaultUserMessage': (visitor, target) => D4.validateTarget<TomAnnotationAnalyzerSyntaxException>(target, 'TomAnnotationAnalyzerSyntaxException').defaultUserMessage,
      'parameters': (visitor, target) => D4.validateTarget<TomAnnotationAnalyzerSyntaxException>(target, 'TomAnnotationAnalyzerSyntaxException').parameters,
      'stack': (visitor, target) => D4.validateTarget<TomAnnotationAnalyzerSyntaxException>(target, 'TomAnnotationAnalyzerSyntaxException').stack,
      'rootException': (visitor, target) => D4.validateTarget<TomAnnotationAnalyzerSyntaxException>(target, 'TomAnnotationAnalyzerSyntaxException').rootException,
      'stackTrace': (visitor, target) => D4.validateTarget<TomAnnotationAnalyzerSyntaxException>(target, 'TomAnnotationAnalyzerSyntaxException').stackTrace,
    },
    setters: {
      'isolateName': (visitor, target, value) => 
        D4.validateTarget<TomAnnotationAnalyzerSyntaxException>(target, 'TomAnnotationAnalyzerSyntaxException').isolateName = D4.extractBridgedArg<String>(value, 'isolateName'),
      'clientThrow': (visitor, target, value) => 
        D4.validateTarget<TomAnnotationAnalyzerSyntaxException>(target, 'TomAnnotationAnalyzerSyntaxException').clientThrow = D4.extractBridgedArg<bool>(value, 'clientThrow'),
      'autoLog': (visitor, target, value) => 
        D4.validateTarget<TomAnnotationAnalyzerSyntaxException>(target, 'TomAnnotationAnalyzerSyntaxException').autoLog = D4.extractBridgedArg<bool>(value, 'autoLog'),
      'serverCallError': (visitor, target, value) => 
        D4.validateTarget<TomAnnotationAnalyzerSyntaxException>(target, 'TomAnnotationAnalyzerSyntaxException').serverCallError = D4.extractBridgedArgOrNull<$tom_core_kernel_4.TomServerCallError>(value, 'serverCallError'),
      'newField': (visitor, target, value) => 
        D4.validateTarget<TomAnnotationAnalyzerSyntaxException>(target, 'TomAnnotationAnalyzerSyntaxException').newField = D4.extractBridgedArgOrNull<String>(value, 'newField'),
      'uuid': (visitor, target, value) => 
        D4.validateTarget<TomAnnotationAnalyzerSyntaxException>(target, 'TomAnnotationAnalyzerSyntaxException').uuid = D4.extractBridgedArg<String>(value, 'uuid'),
      'requestUuid': (visitor, target, value) => 
        D4.validateTarget<TomAnnotationAnalyzerSyntaxException>(target, 'TomAnnotationAnalyzerSyntaxException').requestUuid = D4.extractBridgedArgOrNull<String>(value, 'requestUuid'),
      'timeStamp': (visitor, target, value) => 
        D4.validateTarget<TomAnnotationAnalyzerSyntaxException>(target, 'TomAnnotationAnalyzerSyntaxException').timeStamp = D4.extractBridgedArg<DateTime>(value, 'timeStamp'),
      'key': (visitor, target, value) => 
        D4.validateTarget<TomAnnotationAnalyzerSyntaxException>(target, 'TomAnnotationAnalyzerSyntaxException').key = D4.extractBridgedArg<String>(value, 'key'),
      'defaultUserMessage': (visitor, target, value) => 
        D4.validateTarget<TomAnnotationAnalyzerSyntaxException>(target, 'TomAnnotationAnalyzerSyntaxException').defaultUserMessage = D4.extractBridgedArg<String>(value, 'defaultUserMessage'),
      'stack': (visitor, target, value) => 
        D4.validateTarget<TomAnnotationAnalyzerSyntaxException>(target, 'TomAnnotationAnalyzerSyntaxException').stack = D4.extractBridgedArgOrNull<Object>(value, 'stack'),
      'rootException': (visitor, target, value) => 
        D4.validateTarget<TomAnnotationAnalyzerSyntaxException>(target, 'TomAnnotationAnalyzerSyntaxException').rootException = D4.extractBridgedArgOrNull<Object>(value, 'rootException'),
      'stackTrace': (visitor, target, value) => 
        D4.validateTarget<TomAnnotationAnalyzerSyntaxException>(target, 'TomAnnotationAnalyzerSyntaxException').stackTrace = D4.extractBridgedArg<String>(value, 'stackTrace'),
    },
    methods: {
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomAnnotationAnalyzerSyntaxException>(target, 'TomAnnotationAnalyzerSyntaxException');
        return t.toString();
      },
      'printStackTrace': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomAnnotationAnalyzerSyntaxException>(target, 'TomAnnotationAnalyzerSyntaxException');
        final depth = D4.getOptionalArgWithDefault<int>(positional, 0, 'depth', -1);
        t.printStackTrace(depth);
        return null;
      },
    },
    constructorSignatures: {
      '': 'TomAnnotationAnalyzerSyntaxException(String key, String defaultUserMessage, {Map<String, Object?>? parameters, Object? stack, Object? rootException, bool autoLog = false})',
    },
    methodSignatures: {
      'toString': 'String toString()',
      'printStackTrace': 'void printStackTrace([int depth = -1])',
    },
    getterSignatures: {
      'isolateName': 'String get isolateName',
      'clientThrow': 'bool get clientThrow',
      'autoLog': 'bool get autoLog',
      'serverCallError': 'TomServerCallError? get serverCallError',
      'newField': 'String? get newField',
      'logRepresentation': 'String get logRepresentation',
      'uuid': 'String get uuid',
      'requestUuid': 'String? get requestUuid',
      'timeStamp': 'DateTime get timeStamp',
      'key': 'String get key',
      'defaultUserMessage': 'String get defaultUserMessage',
      'parameters': 'Map<String, Object?>? get parameters',
      'stack': 'Object? get stack',
      'rootException': 'Object? get rootException',
      'stackTrace': 'String get stackTrace',
    },
    setterSignatures: {
      'isolateName': 'set isolateName(String value)',
      'clientThrow': 'set clientThrow(bool value)',
      'autoLog': 'set autoLog(bool value)',
      'serverCallError': 'set serverCallError(TomServerCallError? value)',
      'newField': 'set newField(String? value)',
      'uuid': 'set uuid(String value)',
      'requestUuid': 'set requestUuid(String? value)',
      'timeStamp': 'set timeStamp(DateTime value)',
      'key': 'set key(String value)',
      'defaultUserMessage': 'set defaultUserMessage(String value)',
      'parameters': 'set parameters(Map<String, Object?>? value)',
      'stack': 'set stack(Object? value)',
      'rootException': 'set rootException(Object? value)',
      'stackTrace': 'set stackTrace(String value)',
    },
  );
}

// =============================================================================
// TomAnnotationAnalyzer Bridge
// =============================================================================

BridgedClass _createTomAnnotationAnalyzerBridge() {
  return BridgedClass(
    nativeType: TomAnnotationAnalyzer,
    name: 'TomAnnotationAnalyzer',
    isAssignable: (v) => v is TomAnnotationAnalyzer,
    constructors: {
    },
    staticGetters: {
      'mirrorCache': (visitor) => TomAnnotationAnalyzer.mirrorCache,
      'tableCache': (visitor) => TomAnnotationAnalyzer.tableCache,
      'columnInfoCache': (visitor) => TomAnnotationAnalyzer.columnInfoCache,
    },
    staticMethods: {
      'analysePersistentType': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'analysePersistentType');
        final T = D4.getRequiredArg<Type>(positional, 0, 'T', 'analysePersistentType');
        return TomAnnotationAnalyzer.analysePersistentType(T);
      },
      'findMirror': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'findMirror');
        final dbType = D4.getRequiredArg<Type>(positional, 0, 'dbType', 'findMirror');
        return TomAnnotationAnalyzer.findMirror(dbType);
      },
      'findTable': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'findTable');
        final dbType = D4.getRequiredArg<Type>(positional, 0, 'dbType', 'findTable');
        return TomAnnotationAnalyzer.findTable(dbType);
      },
      'getPersistentColumns': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'getPersistentColumns');
        final dbType = D4.getRequiredArg<Type>(positional, 0, 'dbType', 'getPersistentColumns');
        return TomAnnotationAnalyzer.getPersistentColumns(dbType);
      },
      'determineColumn': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 2, 'determineColumn');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'determineColumn');
        if (positional.length <= 1) {
          throw ArgumentError('determineColumn: Missing required argument "persistenceInfo" at position 1');
        }
        final persistenceInfo = D4.coerceList<$tom_core_server_6.TomTypePersistenceInfo>(positional[1], 'persistenceInfo');
        return TomAnnotationAnalyzer.determineColumn(name, persistenceInfo);
      },
    },
    staticMethodSignatures: {
      'analysePersistentType': 'TomTypePersistenceInfo analysePersistentType(Type T)',
      'findMirror': 'ClassMirror? findMirror(Type dbType)',
      'findTable': 'TomDbTable? findTable(Type dbType)',
      'getPersistentColumns': 'List<TomColumnInformation>? getPersistentColumns(Type dbType)',
      'determineColumn': 'TomColumnInformation determineColumn(String name, List<TomTypePersistenceInfo> persistenceInfo)',
    },
    staticGetterSignatures: {
      'mirrorCache': 'dynamic get mirrorCache',
      'tableCache': 'dynamic get tableCache',
      'columnInfoCache': 'dynamic get columnInfoCache',
    },
  );
}

// =============================================================================
// TomCountResult Bridge
// =============================================================================

BridgedClass _createTomCountResultBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_13.TomCountResult,
    name: 'TomCountResult',
    isAssignable: (v) => v is $tom_core_server_13.TomCountResult,
    constructors: {
      '': (visitor, positional, named) {
        return $tom_core_server_13.TomCountResult();
      },
    },
    getters: {
      'count': (visitor, target) => D4.validateTarget<$tom_core_server_13.TomCountResult>(target, 'TomCountResult').count,
    },
    setters: {
      'count': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_13.TomCountResult>(target, 'TomCountResult').count = D4.extractBridgedArg<int>(value, 'count'),
    },
    constructorSignatures: {
      '': 'TomCountResult()',
    },
    getterSignatures: {
      'count': 'int get count',
    },
    setterSignatures: {
      'count': 'set count(dynamic value)',
    },
  );
}

// =============================================================================
// TomRepository Bridge
// =============================================================================

BridgedClass _createTomRepositoryBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_13.TomRepository,
    name: 'TomRepository',
    isAssignable: (v) => v is $tom_core_server_13.TomRepository,
    constructors: {
    },
    methods: {
      'delete': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_13.TomRepository>(target, 'TomRepository');
        D4.requireMinArgs(positional, 1, 'delete');
        final entity = D4.getRequiredArg<Object>(positional, 0, 'entity', 'delete');
        return t.delete(entity);
      },
      'deleteAllById': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_13.TomRepository>(target, 'TomRepository');
        D4.requireMinArgs(positional, 1, 'deleteAllById');
        if (positional.isEmpty) {
          throw ArgumentError('deleteAllById: Missing required argument "ids" at position 0');
        }
        final ids = D4.coerceList<dynamic>(positional[0], 'ids');
        return t.deleteAllById(ids);
      },
      'deleteById': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_13.TomRepository>(target, 'TomRepository');
        D4.requireMinArgs(positional, 1, 'deleteById');
        final id = D4.getRequiredArg<dynamic>(positional, 0, 'id', 'deleteById');
        return t.deleteById(id);
      },
      'existsById': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_13.TomRepository>(target, 'TomRepository');
        D4.requireMinArgs(positional, 1, 'existsById');
        if (positional.isEmpty) {
          throw ArgumentError('existsById: Missing required argument "ids" at position 0');
        }
        final ids = D4.coerceList<dynamic>(positional[0], 'ids');
        return t.existsById(ids);
      },
      'findAll': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_13.TomRepository>(target, 'TomRepository');
        return t.findAll();
      },
      'findAllById': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_13.TomRepository>(target, 'TomRepository');
        D4.requireMinArgs(positional, 1, 'findAllById');
        if (positional.isEmpty) {
          throw ArgumentError('findAllById: Missing required argument "ids" at position 0');
        }
        final ids = D4.coerceList<dynamic>(positional[0], 'ids');
        return t.findAllById(ids);
      },
      'findById': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_13.TomRepository>(target, 'TomRepository');
        D4.requireMinArgs(positional, 1, 'findById');
        final id = D4.getRequiredArg<dynamic>(positional, 0, 'id', 'findById');
        return t.findById(id);
      },
      'count': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_13.TomRepository>(target, 'TomRepository');
        return t.count();
      },
      'save': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_13.TomRepository>(target, 'TomRepository');
        D4.requireMinArgs(positional, 1, 'save');
        final toSave = D4.getRequiredArg<Object>(positional, 0, 'toSave', 'save');
        return t.save(toSave);
      },
      'saveAll': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_13.TomRepository>(target, 'TomRepository');
        D4.requireMinArgs(positional, 1, 'saveAll');
        if (positional.isEmpty) {
          throw ArgumentError('saveAll: Missing required argument "entities" at position 0');
        }
        final entities = D4.coerceList<Object>(positional[0], 'entities');
        return t.saveAll(entities);
      },
      'findByQuerySentence': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_13.TomRepository>(target, 'TomRepository');
        D4.requireMinArgs(positional, 2, 'findByQuerySentence');
        final querySentence = D4.getRequiredArg<String>(positional, 0, 'querySentence', 'findByQuerySentence');
        if (positional.length <= 1) {
          throw ArgumentError('findByQuerySentence: Missing required argument "params" at position 1');
        }
        final params = D4.coerceMap<String, Object?>(positional[1], 'params');
        final resultType = D4.getOptionalArg<Type?>(positional, 2, 'resultType');
        return t.findByQuerySentence(querySentence, params, resultType);
      },
      'deleteByQuerySentence': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_13.TomRepository>(target, 'TomRepository');
        D4.requireMinArgs(positional, 2, 'deleteByQuerySentence');
        final querySentence = D4.getRequiredArg<String>(positional, 0, 'querySentence', 'deleteByQuerySentence');
        if (positional.length <= 1) {
          throw ArgumentError('deleteByQuerySentence: Missing required argument "params" at position 1');
        }
        final params = D4.coerceMap<String, Object?>(positional[1], 'params');
        return t.deleteByQuerySentence(querySentence, params);
      },
      'countByQuerySentence': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_13.TomRepository>(target, 'TomRepository');
        D4.requireMinArgs(positional, 2, 'countByQuerySentence');
        final querySentence = D4.getRequiredArg<String>(positional, 0, 'querySentence', 'countByQuerySentence');
        if (positional.length <= 1) {
          throw ArgumentError('countByQuerySentence: Missing required argument "params" at position 1');
        }
        final params = D4.coerceMap<String, Object?>(positional[1], 'params');
        return t.countByQuerySentence(querySentence, params);
      },
      'findByQuery': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_13.TomRepository>(target, 'TomRepository');
        D4.requireMinArgs(positional, 2, 'findByQuery');
        final query = D4.getRequiredArg<$tom_core_server_6.TomSelect>(positional, 0, 'query', 'findByQuery');
        if (positional.length <= 1) {
          throw ArgumentError('findByQuery: Missing required argument "params" at position 1');
        }
        final params = D4.coerceMap<String, Object?>(positional[1], 'params');
        return t.findByQuery(query, params);
      },
      'deleteByQuery': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_13.TomRepository>(target, 'TomRepository');
        D4.requireMinArgs(positional, 2, 'deleteByQuery');
        final query = D4.getRequiredArg<$tom_core_server_6.TomDelete>(positional, 0, 'query', 'deleteByQuery');
        if (positional.length <= 1) {
          throw ArgumentError('deleteByQuery: Missing required argument "params" at position 1');
        }
        final params = D4.coerceMap<String, Object?>(positional[1], 'params');
        return t.deleteByQuery(query, params);
      },
      'countByQuery': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_13.TomRepository>(target, 'TomRepository');
        D4.requireMinArgs(positional, 2, 'countByQuery');
        final query = D4.getRequiredArg<$tom_core_server_6.TomCount>(positional, 0, 'query', 'countByQuery');
        if (positional.length <= 1) {
          throw ArgumentError('countByQuery: Missing required argument "params" at position 1');
        }
        final params = D4.coerceMap<String, Object?>(positional[1], 'params');
        return t.countByQuery(query, params);
      },
      'executeQueryString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_13.TomRepository>(target, 'TomRepository');
        D4.requireMinArgs(positional, 2, 'executeQueryString');
        final dbQuery = D4.getRequiredArg<String>(positional, 0, 'dbQuery', 'executeQueryString');
        if (positional.length <= 1) {
          throw ArgumentError('executeQueryString: Missing required argument "params" at position 1');
        }
        final params = D4.coerceMap<String, Object?>(positional[1], 'params');
        return t.executeQueryString(dbQuery, params);
      },
    },
    methodSignatures: {
      'delete': 'Future<void> delete(T entity)',
      'deleteAllById': 'Future<void> deleteAllById(Iterable<K> ids)',
      'deleteById': 'Future<void> deleteById(K id)',
      'existsById': 'Future<bool> existsById(Iterable<K> ids)',
      'findAll': 'Future<List<T>> findAll()',
      'findAllById': 'Future<List<T>> findAllById(Iterable<K> ids)',
      'findById': 'Future<T?> findById(K id)',
      'count': 'Future<TomDbInt> count()',
      'save': 'Future<T> save(T toSave)',
      'saveAll': 'Future<Iterable<T>> saveAll(Iterable<T> entities)',
      'findByQuerySentence': 'Future<Iterable<T>> findByQuerySentence(String querySentence, Map<String, Object?> params, [Type? resultType])',
      'deleteByQuerySentence': 'Future<void> deleteByQuerySentence(String querySentence, Map<String, Object?> params)',
      'countByQuerySentence': 'Future<TomDbInt> countByQuerySentence(String querySentence, Map<String, Object?> params)',
      'findByQuery': 'Future<Iterable<T>> findByQuery(TomSelect query, Map<String, Object?> params)',
      'deleteByQuery': 'Future<void> deleteByQuery(TomDelete query, Map<String, Object?> params)',
      'countByQuery': 'Future<TomDbInt> countByQuery(TomCount query, Map<String, Object?> params)',
      'executeQueryString': 'Future<Iterable<T>> executeQueryString(String dbQuery, Map<String, Object?> params)',
    },
  );
}

// =============================================================================
// TomSqlDatasourceRepository Bridge
// =============================================================================

BridgedClass _createTomSqlDatasourceRepositoryBridge() {
  return BridgedClass(
    nativeType: TomSqlDatasourceRepository,
    name: 'TomSqlDatasourceRepository',
    isAssignable: (v) => v is TomSqlDatasourceRepository,
    constructors: {
    },
    getters: {
      'primaryKeyColumnInfo': (visitor, target) => D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository').primaryKeyColumnInfo,
      'datasourceInfo': (visitor, target) => D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository').datasourceInfo,
      'persistenceInfo': (visitor, target) => D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository').persistenceInfo,
      'dbTable': (visitor, target) => D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository').dbTable,
      'sqlDialect': (visitor, target) => D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository').sqlDialect,
      'queryTypes': (visitor, target) => D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository').queryTypes,
      'resultType': (visitor, target) => D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository').resultType,
    },
    setters: {
      'primaryKeyColumnInfo': (visitor, target, value) => 
        D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository').primaryKeyColumnInfo = D4.extractBridgedArg<$tom_core_server_15.TomColumnInformation>(value, 'primaryKeyColumnInfo'),
      'datasourceInfo': (visitor, target, value) => 
        D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository').datasourceInfo = D4.extractBridgedArg<$tom_core_server_4.TomDataSourceInfo>(value, 'datasourceInfo'),
      'persistenceInfo': (visitor, target, value) => 
        D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository').persistenceInfo = D4.extractBridgedArg<$tom_core_server_6.TomTypePersistenceInfo>(value, 'persistenceInfo'),
      'dbTable': (visitor, target, value) => 
        D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository').dbTable = D4.extractBridgedArg<$tom_core_server_15.TomDbTable>(value, 'dbTable'),
      'queryTypes': (visitor, target, value) => 
        D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository').queryTypes = (value as List).cast<Type>().toList(),
      'resultType': (visitor, target, value) => 
        D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository').resultType = D4.extractBridgedArg<Type>(value, 'resultType'),
    },
    methods: {
      'delete': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 1, 'delete');
        final entity = D4.getRequiredArg<Object>(positional, 0, 'entity', 'delete');
        return t.delete(entity);
      },
      'deleteAllById': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 1, 'deleteAllById');
        if (positional.isEmpty) {
          throw ArgumentError('deleteAllById: Missing required argument "ids" at position 0');
        }
        final ids = D4.coerceList<dynamic>(positional[0], 'ids');
        return t.deleteAllById(ids);
      },
      'deleteById': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 1, 'deleteById');
        final id = D4.getRequiredArg<dynamic>(positional, 0, 'id', 'deleteById');
        return t.deleteById(id);
      },
      'existsById': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 1, 'existsById');
        if (positional.isEmpty) {
          throw ArgumentError('existsById: Missing required argument "ids" at position 0');
        }
        final ids = D4.coerceList<dynamic>(positional[0], 'ids');
        return t.existsById(ids);
      },
      'findAll': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        return t.findAll();
      },
      'findAllById': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 1, 'findAllById');
        if (positional.isEmpty) {
          throw ArgumentError('findAllById: Missing required argument "ids" at position 0');
        }
        final ids = D4.coerceList<dynamic>(positional[0], 'ids');
        return t.findAllById(ids);
      },
      'findById': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 1, 'findById');
        final id = D4.getRequiredArg<dynamic>(positional, 0, 'id', 'findById');
        return t.findById(id);
      },
      'count': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        return t.count();
      },
      'save': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 1, 'save');
        final toSave = D4.getRequiredArg<Object>(positional, 0, 'toSave', 'save');
        return t.save(toSave);
      },
      'saveAll': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 1, 'saveAll');
        if (positional.isEmpty) {
          throw ArgumentError('saveAll: Missing required argument "entities" at position 0');
        }
        final entities = D4.coerceList<Object>(positional[0], 'entities');
        return t.saveAll(entities);
      },
      'findByQuerySentence': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 2, 'findByQuerySentence');
        final querySentence = D4.getRequiredArg<String>(positional, 0, 'querySentence', 'findByQuerySentence');
        if (positional.length <= 1) {
          throw ArgumentError('findByQuerySentence: Missing required argument "params" at position 1');
        }
        final params = D4.coerceMap<String, Object?>(positional[1], 'params');
        final resultType = D4.getOptionalArg<Type?>(positional, 2, 'resultType');
        return t.findByQuerySentence(querySentence, params, resultType);
      },
      'deleteByQuerySentence': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 2, 'deleteByQuerySentence');
        final querySentence = D4.getRequiredArg<String>(positional, 0, 'querySentence', 'deleteByQuerySentence');
        if (positional.length <= 1) {
          throw ArgumentError('deleteByQuerySentence: Missing required argument "params" at position 1');
        }
        final params = D4.coerceMap<String, Object?>(positional[1], 'params');
        return t.deleteByQuerySentence(querySentence, params);
      },
      'countByQuerySentence': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 2, 'countByQuerySentence');
        final querySentence = D4.getRequiredArg<String>(positional, 0, 'querySentence', 'countByQuerySentence');
        if (positional.length <= 1) {
          throw ArgumentError('countByQuerySentence: Missing required argument "params" at position 1');
        }
        final params = D4.coerceMap<String, Object?>(positional[1], 'params');
        return t.countByQuerySentence(querySentence, params);
      },
      'findByQuery': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 2, 'findByQuery');
        final query = D4.getRequiredArg<$tom_core_server_6.TomSelect>(positional, 0, 'query', 'findByQuery');
        if (positional.length <= 1) {
          throw ArgumentError('findByQuery: Missing required argument "params" at position 1');
        }
        final params = D4.coerceMap<String, Object?>(positional[1], 'params');
        return t.findByQuery(query, params);
      },
      'deleteByQuery': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 2, 'deleteByQuery');
        final query = D4.getRequiredArg<$tom_core_server_6.TomDelete>(positional, 0, 'query', 'deleteByQuery');
        if (positional.length <= 1) {
          throw ArgumentError('deleteByQuery: Missing required argument "params" at position 1');
        }
        final params = D4.coerceMap<String, Object?>(positional[1], 'params');
        return t.deleteByQuery(query, params);
      },
      'countByQuery': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 2, 'countByQuery');
        final query = D4.getRequiredArg<$tom_core_server_6.TomCount>(positional, 0, 'query', 'countByQuery');
        if (positional.length <= 1) {
          throw ArgumentError('countByQuery: Missing required argument "params" at position 1');
        }
        final params = D4.coerceMap<String, Object?>(positional[1], 'params');
        return t.countByQuery(query, params);
      },
      'executeQueryString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 2, 'executeQueryString');
        final dbQuery = D4.getRequiredArg<String>(positional, 0, 'dbQuery', 'executeQueryString');
        if (positional.length <= 1) {
          throw ArgumentError('executeQueryString: Missing required argument "params" at position 1');
        }
        final params = D4.coerceMap<String, Object?>(positional[1], 'params');
        return t.executeQueryString(dbQuery, params);
      },
      'isNull': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 1, 'isNull');
        final what = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'what', 'isNull');
        return t.isNull(what);
      },
      'isNotNull': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 1, 'isNotNull');
        final what = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'what', 'isNotNull');
        return t.isNotNull(what);
      },
      'isIn': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 2, 'isIn');
        final what = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'what', 'isIn');
        if (positional.length <= 1) {
          throw ArgumentError('isIn: Missing required argument "choices" at position 1');
        }
        final choices = D4.coerceList<$tom_core_server_8.TomOperator<dynamic>>(positional[1], 'choices');
        return t.isIn(what, choices);
      },
      'between': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 2, 'between');
        final what = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'what', 'between');
        if (positional.length <= 1) {
          throw ArgumentError('between: Missing required argument "betweenLimits" at position 1');
        }
        final betweenLimits = D4.coerceList<$tom_core_server_8.TomOperator<dynamic>>(positional[1], 'betweenLimits');
        return t.between(what, betweenLimits);
      },
      'like': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 2, 'like');
        final text = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 0, 'text', 'like');
        final test = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 1, 'test', 'like');
        return t.like(text, test);
      },
      'notLike': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 2, 'notLike');
        final text = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 0, 'text', 'notLike');
        final test = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 1, 'test', 'notLike');
        return t.notLike(text, test);
      },
      'regexp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 2, 'regexp');
        final text = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 0, 'text', 'regexp');
        final test = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 1, 'test', 'regexp');
        return t.regexp(text, test);
      },
      'group': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 1, 'group');
        final operant = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant', 'group');
        return t.group(operant);
      },
      'eq': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 2, 'eq');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'eq');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'eq');
        return t.eq(operant1, operant2);
      },
      'neq': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 2, 'neq');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'neq');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'neq');
        return t.neq(operant1, operant2);
      },
      'lt': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 2, 'lt');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'lt');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'lt');
        return t.lt(operant1, operant2);
      },
      'lte': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 2, 'lte');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'lte');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'lte');
        return t.lte(operant1, operant2);
      },
      'gt': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 2, 'gt');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'gt');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'gt');
        return t.gt(operant1, operant2);
      },
      'gte': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 2, 'gte');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'gte');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'gte');
        return t.gte(operant1, operant2);
      },
      'not': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 1, 'not');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbBool>>(positional, 0, 'operant1', 'not');
        return t.not(operant1);
      },
      'and': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 1, 'and');
        if (positional.isEmpty) {
          throw ArgumentError('and: Missing required argument "operant1" at position 0');
        }
        final operant1 = D4.coerceList<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbBool>>(positional[0], 'operant1');
        return t.and(operant1);
      },
      'or': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 1, 'or');
        if (positional.isEmpty) {
          throw ArgumentError('or: Missing required argument "operant1" at position 0');
        }
        final operant1 = D4.coerceList<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbBool>>(positional[0], 'operant1');
        return t.or(operant1);
      },
      'text': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 1, 'text');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'text');
        return t.text(text);
      },
      'intOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 1, 'intOp');
        final value = D4.getRequiredArg<int>(positional, 0, 'value', 'intOp');
        return t.intOp(value);
      },
      'doubleOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 1, 'doubleOp');
        final value = D4.getRequiredArg<double>(positional, 0, 'value', 'doubleOp');
        return t.doubleOp(value);
      },
      'boolOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 1, 'boolOp');
        final value = D4.getRequiredArg<bool>(positional, 0, 'value', 'boolOp');
        return t.boolOp(value);
      },
      'dateTimeOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 1, 'dateTimeOp');
        final value = D4.getRequiredArg<DateTime>(positional, 0, 'value', 'dateTimeOp');
        return t.dateTimeOp(value);
      },
      'dateOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 1, 'dateOp');
        final value = D4.getRequiredArg<DateTime>(positional, 0, 'value', 'dateOp');
        return t.dateOp(value);
      },
      'p': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 1, 'p');
        final parameterName = D4.getRequiredArg<String>(positional, 0, 'parameterName', 'p');
        return t.p(parameterName);
      },
      'textF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 2, 'textF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'textF');
        final columnInformation = D4.getRequiredArg<$tom_core_server_15.TomColumnInformation>(positional, 1, 'columnInformation', 'textF');
        return t.textF(fieldName, columnInformation);
      },
      'intF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 2, 'intF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'intF');
        final columnInformation = D4.getRequiredArg<$tom_core_server_15.TomColumnInformation>(positional, 1, 'columnInformation', 'intF');
        return t.intF(fieldName, columnInformation);
      },
      'doubleF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 2, 'doubleF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'doubleF');
        final columnInformation = D4.getRequiredArg<$tom_core_server_15.TomColumnInformation>(positional, 1, 'columnInformation', 'doubleF');
        return t.doubleF(fieldName, columnInformation);
      },
      'boolF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 2, 'boolF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'boolF');
        final columnInformation = D4.getRequiredArg<$tom_core_server_15.TomColumnInformation>(positional, 1, 'columnInformation', 'boolF');
        return t.boolF(fieldName, columnInformation);
      },
      'dateTimeF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 2, 'dateTimeF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'dateTimeF');
        final columnInformation = D4.getRequiredArg<$tom_core_server_15.TomColumnInformation>(positional, 1, 'columnInformation', 'dateTimeF');
        return t.dateTimeF(fieldName, columnInformation);
      },
      'dateF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomSqlDatasourceRepository>(target, 'TomSqlDatasourceRepository');
        D4.requireMinArgs(positional, 2, 'dateF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'dateF');
        final columnInformation = D4.getRequiredArg<$tom_core_server_15.TomColumnInformation>(positional, 1, 'columnInformation', 'dateF');
        return t.dateF(fieldName, columnInformation);
      },
    },
    methodSignatures: {
      'delete': 'Future<void> delete(T entity)',
      'deleteAllById': 'Future<void> deleteAllById(Iterable<K> ids)',
      'deleteById': 'Future<int> deleteById(K id)',
      'existsById': 'Future<bool> existsById(Iterable<K> ids)',
      'findAll': 'Future<List<T>> findAll()',
      'findAllById': 'Future<List<T>> findAllById(Iterable<K> ids)',
      'findById': 'Future<T?> findById(K id)',
      'count': 'Future<TomDbInt> count()',
      'save': 'Future<T> save(T toSave)',
      'saveAll': 'Future<Iterable<T>> saveAll(Iterable<T> entities)',
      'findByQuerySentence': 'Future<Iterable<T>> findByQuerySentence(String querySentence, Map<String, Object?> params, [Type? resultType])',
      'deleteByQuerySentence': 'Future<int> deleteByQuerySentence(String querySentence, Map<String, Object?> params)',
      'countByQuerySentence': 'Future<TomDbInt> countByQuerySentence(String querySentence, Map<String, Object?> params)',
      'findByQuery': 'Future<Iterable<T>> findByQuery(TomSelect query, Map<String, Object?> params)',
      'deleteByQuery': 'Future<int> deleteByQuery(TomDelete query, Map<String, Object?> params)',
      'countByQuery': 'Future<TomDbInt> countByQuery(TomCount query, Map<String, Object?> params)',
      'executeQueryString': 'Future<Iterable<T>> executeQueryString(String dbQuery, Map<String, Object?> params)',
      'isNull': 'TomOperator<TomDbBool> isNull(TomOperator<T> what)',
      'isNotNull': 'TomOperator<TomDbBool> isNotNull(TomOperator<T> what)',
      'isIn': 'TomOperator<TomDbBool> isIn(TomOperator<T> what, List<TomOperator<T>> choices)',
      'between': 'TomOperator<TomDbBool> between(TomOperator<T> what, List<TomOperator<T>> betweenLimits)',
      'like': 'TomOperator<TomDbBool> like(TomOperator<TomDbString> text, TomOperator<TomDbString> test)',
      'notLike': 'TomOperator<TomDbBool> notLike(TomOperator<TomDbString> text, TomOperator<TomDbString> test)',
      'regexp': 'TomOperator<TomDbBool> regexp(TomOperator<TomDbString> text, TomOperator<TomDbString> test)',
      'group': 'TomOperator<T> group(TomOperator<T> operant)',
      'eq': 'TomOperator<TomDbBool> eq(TomOperator<T> operant1, TomOperator<T> operant2)',
      'neq': 'TomOperator<TomDbBool> neq(TomOperator<T> operant1, TomOperator<T> operant2)',
      'lt': 'TomOperator<TomDbBool> lt(TomOperator<T> operant1, TomOperator<T> operant2)',
      'lte': 'TomOperator<TomDbBool> lte(TomOperator<T> operant1, TomOperator<T> operant2)',
      'gt': 'TomOperator<TomDbBool> gt(TomOperator<T> operant1, TomOperator<T> operant2)',
      'gte': 'TomOperator<TomDbBool> gte(TomOperator<T> operant1, TomOperator<T> operant2)',
      'not': 'TomOperator<TomDbBool> not(TomOperator<TomDbBool> operant1)',
      'and': 'TomOperator<TomDbBool> and(List<TomOperator<TomDbBool>> operant1)',
      'or': 'TomOperator<TomDbBool> or(List<TomOperator<TomDbBool>> operant1)',
      'text': 'TomOperator<TomDbString> text(String text)',
      'intOp': 'TomOperator<TomDbInt> intOp(int value)',
      'doubleOp': 'TomOperator<TomDbDouble> doubleOp(double value)',
      'boolOp': 'TomOperator<TomDbBool> boolOp(bool value)',
      'dateTimeOp': 'TomOperator<TomDbDateTime> dateTimeOp(DateTime value)',
      'dateOp': 'TomOperator<TomDbDate> dateOp(DateTime value)',
      'p': 'TomOperator<T> p(String parameterName)',
      'textF': 'TomOperator<TomDbString> textF(String fieldName, TomColumnInformation columnInformation)',
      'intF': 'TomOperator<TomDbInt> intF(String fieldName, TomColumnInformation columnInformation)',
      'doubleF': 'TomOperator<TomDbDouble> doubleF(String fieldName, TomColumnInformation columnInformation)',
      'boolF': 'TomOperator<TomDbBool> boolF(String fieldName, TomColumnInformation columnInformation)',
      'dateTimeF': 'TomOperator<TomDbDateTime> dateTimeF(String fieldName, TomColumnInformation columnInformation)',
      'dateF': 'TomOperator<TomDbDate> dateF(String fieldName, TomColumnInformation columnInformation)',
    },
    getterSignatures: {
      'primaryKeyColumnInfo': 'TomColumnInformation get primaryKeyColumnInfo',
      'datasourceInfo': 'TomDataSourceInfo get datasourceInfo',
      'persistenceInfo': 'TomTypePersistenceInfo get persistenceInfo',
      'dbTable': 'TomDbTable get dbTable',
      'sqlDialect': 'TomStandardSqlDialect get sqlDialect',
      'queryTypes': 'List<Type> get queryTypes',
      'resultType': 'Type get resultType',
    },
    setterSignatures: {
      'primaryKeyColumnInfo': 'set primaryKeyColumnInfo(dynamic value)',
      'datasourceInfo': 'set datasourceInfo(dynamic value)',
      'persistenceInfo': 'set persistenceInfo(dynamic value)',
      'dbTable': 'set dbTable(dynamic value)',
      'queryTypes': 'set queryTypes(dynamic value)',
      'resultType': 'set resultType(dynamic value)',
    },
  );
}

// =============================================================================
// TomRepositoryType Bridge
// =============================================================================

BridgedClass _createTomRepositoryTypeBridge() {
  return BridgedClass(
    nativeType: TomRepositoryType,
    name: 'TomRepositoryType',
    isAssignable: (v) => v is TomRepositoryType,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomRepositoryType');
        final datasourceType = D4.getRequiredArg<String>(positional, 0, 'datasourceType', 'TomRepositoryType');
        return TomRepositoryType(datasourceType);
      },
    },
    getters: {
      'datasourceType': (visitor, target) => D4.validateTarget<TomRepositoryType>(target, 'TomRepositoryType').datasourceType,
    },
    constructorSignatures: {
      '': 'const TomRepositoryType(String datasourceType)',
    },
    getterSignatures: {
      'datasourceType': 'String get datasourceType',
    },
  );
}

// =============================================================================
// MariadbRepository Bridge
// =============================================================================

BridgedClass _createMariadbRepositoryBridge() {
  return BridgedClass(
    nativeType: MariadbRepository,
    name: 'MariadbRepository',
    isAssignable: (v) => v is MariadbRepository,
    constructors: {
      '': (visitor, positional, named) {
        final queryTypes = positional.isNotEmpty
            ? D4.coerceListOrNull<Type>(positional[0], 'queryTypes')
            : null;
        final resultType = D4.getOptionalArg<Type?>(positional, 1, 'resultType');
        return MariadbRepository(queryTypes, resultType);
      },
    },
    getters: {
      'primaryKeyColumnInfo': (visitor, target) => D4.validateTarget<MariadbRepository>(target, 'MariadbRepository').primaryKeyColumnInfo,
      'datasourceInfo': (visitor, target) => D4.validateTarget<MariadbRepository>(target, 'MariadbRepository').datasourceInfo,
      'persistenceInfo': (visitor, target) => D4.validateTarget<MariadbRepository>(target, 'MariadbRepository').persistenceInfo,
      'dbTable': (visitor, target) => D4.validateTarget<MariadbRepository>(target, 'MariadbRepository').dbTable,
      'sqlDialect': (visitor, target) => D4.validateTarget<MariadbRepository>(target, 'MariadbRepository').sqlDialect,
      'queryTypes': (visitor, target) => D4.validateTarget<MariadbRepository>(target, 'MariadbRepository').queryTypes,
      'resultType': (visitor, target) => D4.validateTarget<MariadbRepository>(target, 'MariadbRepository').resultType,
    },
    setters: {
      'primaryKeyColumnInfo': (visitor, target, value) => 
        D4.validateTarget<MariadbRepository>(target, 'MariadbRepository').primaryKeyColumnInfo = D4.extractBridgedArg<$tom_core_server_15.TomColumnInformation>(value, 'primaryKeyColumnInfo'),
      'datasourceInfo': (visitor, target, value) => 
        D4.validateTarget<MariadbRepository>(target, 'MariadbRepository').datasourceInfo = D4.extractBridgedArg<$tom_core_server_4.TomDataSourceInfo>(value, 'datasourceInfo'),
      'persistenceInfo': (visitor, target, value) => 
        D4.validateTarget<MariadbRepository>(target, 'MariadbRepository').persistenceInfo = D4.extractBridgedArg<$tom_core_server_6.TomTypePersistenceInfo>(value, 'persistenceInfo'),
      'dbTable': (visitor, target, value) => 
        D4.validateTarget<MariadbRepository>(target, 'MariadbRepository').dbTable = D4.extractBridgedArg<$tom_core_server_15.TomDbTable>(value, 'dbTable'),
      'queryTypes': (visitor, target, value) => 
        D4.validateTarget<MariadbRepository>(target, 'MariadbRepository').queryTypes = (value as List).cast<Type>().toList(),
      'resultType': (visitor, target, value) => 
        D4.validateTarget<MariadbRepository>(target, 'MariadbRepository').resultType = D4.extractBridgedArg<Type>(value, 'resultType'),
    },
    methods: {
      'delete': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 1, 'delete');
        final entity = D4.getRequiredArg<Object>(positional, 0, 'entity', 'delete');
        return t.delete(entity);
      },
      'deleteAllById': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 1, 'deleteAllById');
        if (positional.isEmpty) {
          throw ArgumentError('deleteAllById: Missing required argument "ids" at position 0');
        }
        final ids = D4.coerceList<dynamic>(positional[0], 'ids');
        return t.deleteAllById(ids);
      },
      'deleteById': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 1, 'deleteById');
        final id = D4.getRequiredArg<dynamic>(positional, 0, 'id', 'deleteById');
        return t.deleteById(id);
      },
      'existsById': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 1, 'existsById');
        if (positional.isEmpty) {
          throw ArgumentError('existsById: Missing required argument "ids" at position 0');
        }
        final ids = D4.coerceList<dynamic>(positional[0], 'ids');
        return t.existsById(ids);
      },
      'findAll': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        return t.findAll();
      },
      'findAllById': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 1, 'findAllById');
        if (positional.isEmpty) {
          throw ArgumentError('findAllById: Missing required argument "ids" at position 0');
        }
        final ids = D4.coerceList<dynamic>(positional[0], 'ids');
        return t.findAllById(ids);
      },
      'findById': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 1, 'findById');
        final id = D4.getRequiredArg<dynamic>(positional, 0, 'id', 'findById');
        return t.findById(id);
      },
      'count': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        return t.count();
      },
      'save': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 1, 'save');
        final toSave = D4.getRequiredArg<Object>(positional, 0, 'toSave', 'save');
        return t.save(toSave);
      },
      'saveAll': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 1, 'saveAll');
        if (positional.isEmpty) {
          throw ArgumentError('saveAll: Missing required argument "entities" at position 0');
        }
        final entities = D4.coerceList<Object>(positional[0], 'entities');
        return t.saveAll(entities);
      },
      'findByQuerySentence': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 2, 'findByQuerySentence');
        final querySentence = D4.getRequiredArg<String>(positional, 0, 'querySentence', 'findByQuerySentence');
        if (positional.length <= 1) {
          throw ArgumentError('findByQuerySentence: Missing required argument "params" at position 1');
        }
        final params = D4.coerceMap<String, Object?>(positional[1], 'params');
        final resultType = D4.getOptionalArg<Type?>(positional, 2, 'resultType');
        return t.findByQuerySentence(querySentence, params, resultType);
      },
      'deleteByQuerySentence': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 2, 'deleteByQuerySentence');
        final querySentence = D4.getRequiredArg<String>(positional, 0, 'querySentence', 'deleteByQuerySentence');
        if (positional.length <= 1) {
          throw ArgumentError('deleteByQuerySentence: Missing required argument "params" at position 1');
        }
        final params = D4.coerceMap<String, Object?>(positional[1], 'params');
        return t.deleteByQuerySentence(querySentence, params);
      },
      'countByQuerySentence': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 2, 'countByQuerySentence');
        final querySentence = D4.getRequiredArg<String>(positional, 0, 'querySentence', 'countByQuerySentence');
        if (positional.length <= 1) {
          throw ArgumentError('countByQuerySentence: Missing required argument "params" at position 1');
        }
        final params = D4.coerceMap<String, Object?>(positional[1], 'params');
        return t.countByQuerySentence(querySentence, params);
      },
      'findByQuery': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 2, 'findByQuery');
        final query = D4.getRequiredArg<$tom_core_server_6.TomSelect>(positional, 0, 'query', 'findByQuery');
        if (positional.length <= 1) {
          throw ArgumentError('findByQuery: Missing required argument "params" at position 1');
        }
        final params = D4.coerceMap<String, Object?>(positional[1], 'params');
        return t.findByQuery(query, params);
      },
      'deleteByQuery': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 2, 'deleteByQuery');
        final query = D4.getRequiredArg<$tom_core_server_6.TomDelete>(positional, 0, 'query', 'deleteByQuery');
        if (positional.length <= 1) {
          throw ArgumentError('deleteByQuery: Missing required argument "params" at position 1');
        }
        final params = D4.coerceMap<String, Object?>(positional[1], 'params');
        return t.deleteByQuery(query, params);
      },
      'countByQuery': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 2, 'countByQuery');
        final query = D4.getRequiredArg<$tom_core_server_6.TomCount>(positional, 0, 'query', 'countByQuery');
        if (positional.length <= 1) {
          throw ArgumentError('countByQuery: Missing required argument "params" at position 1');
        }
        final params = D4.coerceMap<String, Object?>(positional[1], 'params');
        return t.countByQuery(query, params);
      },
      'executeQueryString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 2, 'executeQueryString');
        final dbQuery = D4.getRequiredArg<String>(positional, 0, 'dbQuery', 'executeQueryString');
        if (positional.length <= 1) {
          throw ArgumentError('executeQueryString: Missing required argument "params" at position 1');
        }
        final params = D4.coerceMap<String, Object?>(positional[1], 'params');
        return t.executeQueryString(dbQuery, params);
      },
      'isNull': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 1, 'isNull');
        final what = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'what', 'isNull');
        return t.isNull(what);
      },
      'isNotNull': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 1, 'isNotNull');
        final what = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'what', 'isNotNull');
        return t.isNotNull(what);
      },
      'isIn': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 2, 'isIn');
        final what = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'what', 'isIn');
        if (positional.length <= 1) {
          throw ArgumentError('isIn: Missing required argument "choices" at position 1');
        }
        final choices = D4.coerceList<$tom_core_server_8.TomOperator<dynamic>>(positional[1], 'choices');
        return t.isIn(what, choices);
      },
      'between': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 2, 'between');
        final what = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'what', 'between');
        if (positional.length <= 1) {
          throw ArgumentError('between: Missing required argument "betweenLimits" at position 1');
        }
        final betweenLimits = D4.coerceList<$tom_core_server_8.TomOperator<dynamic>>(positional[1], 'betweenLimits');
        return t.between(what, betweenLimits);
      },
      'like': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 2, 'like');
        final text = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 0, 'text', 'like');
        final test = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 1, 'test', 'like');
        return t.like(text, test);
      },
      'notLike': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 2, 'notLike');
        final text = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 0, 'text', 'notLike');
        final test = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 1, 'test', 'notLike');
        return t.notLike(text, test);
      },
      'regexp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 2, 'regexp');
        final text = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 0, 'text', 'regexp');
        final test = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 1, 'test', 'regexp');
        return t.regexp(text, test);
      },
      'group': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 1, 'group');
        final operant = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant', 'group');
        return t.group(operant);
      },
      'eq': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 2, 'eq');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'eq');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'eq');
        return t.eq(operant1, operant2);
      },
      'neq': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 2, 'neq');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'neq');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'neq');
        return t.neq(operant1, operant2);
      },
      'lt': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 2, 'lt');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'lt');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'lt');
        return t.lt(operant1, operant2);
      },
      'lte': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 2, 'lte');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'lte');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'lte');
        return t.lte(operant1, operant2);
      },
      'gt': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 2, 'gt');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'gt');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'gt');
        return t.gt(operant1, operant2);
      },
      'gte': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 2, 'gte');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'gte');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'gte');
        return t.gte(operant1, operant2);
      },
      'not': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 1, 'not');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbBool>>(positional, 0, 'operant1', 'not');
        return t.not(operant1);
      },
      'and': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 1, 'and');
        if (positional.isEmpty) {
          throw ArgumentError('and: Missing required argument "operant1" at position 0');
        }
        final operant1 = D4.coerceList<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbBool>>(positional[0], 'operant1');
        return t.and(operant1);
      },
      'or': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 1, 'or');
        if (positional.isEmpty) {
          throw ArgumentError('or: Missing required argument "operant1" at position 0');
        }
        final operant1 = D4.coerceList<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbBool>>(positional[0], 'operant1');
        return t.or(operant1);
      },
      'text': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 1, 'text');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'text');
        return t.text(text);
      },
      'intOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 1, 'intOp');
        final value = D4.getRequiredArg<int>(positional, 0, 'value', 'intOp');
        return t.intOp(value);
      },
      'doubleOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 1, 'doubleOp');
        final value = D4.getRequiredArg<double>(positional, 0, 'value', 'doubleOp');
        return t.doubleOp(value);
      },
      'boolOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 1, 'boolOp');
        final value = D4.getRequiredArg<bool>(positional, 0, 'value', 'boolOp');
        return t.boolOp(value);
      },
      'dateTimeOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 1, 'dateTimeOp');
        final value = D4.getRequiredArg<DateTime>(positional, 0, 'value', 'dateTimeOp');
        return t.dateTimeOp(value);
      },
      'dateOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 1, 'dateOp');
        final value = D4.getRequiredArg<DateTime>(positional, 0, 'value', 'dateOp');
        return t.dateOp(value);
      },
      'p': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 1, 'p');
        final parameterName = D4.getRequiredArg<String>(positional, 0, 'parameterName', 'p');
        return t.p(parameterName);
      },
      'textF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 2, 'textF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'textF');
        final columnInformation = D4.getRequiredArg<$tom_core_server_15.TomColumnInformation>(positional, 1, 'columnInformation', 'textF');
        return t.textF(fieldName, columnInformation);
      },
      'intF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 2, 'intF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'intF');
        final columnInformation = D4.getRequiredArg<$tom_core_server_15.TomColumnInformation>(positional, 1, 'columnInformation', 'intF');
        return t.intF(fieldName, columnInformation);
      },
      'doubleF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 2, 'doubleF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'doubleF');
        final columnInformation = D4.getRequiredArg<$tom_core_server_15.TomColumnInformation>(positional, 1, 'columnInformation', 'doubleF');
        return t.doubleF(fieldName, columnInformation);
      },
      'boolF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 2, 'boolF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'boolF');
        final columnInformation = D4.getRequiredArg<$tom_core_server_15.TomColumnInformation>(positional, 1, 'columnInformation', 'boolF');
        return t.boolF(fieldName, columnInformation);
      },
      'dateTimeF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 2, 'dateTimeF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'dateTimeF');
        final columnInformation = D4.getRequiredArg<$tom_core_server_15.TomColumnInformation>(positional, 1, 'columnInformation', 'dateTimeF');
        return t.dateTimeF(fieldName, columnInformation);
      },
      'dateF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MariadbRepository>(target, 'MariadbRepository');
        D4.requireMinArgs(positional, 2, 'dateF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'dateF');
        final columnInformation = D4.getRequiredArg<$tom_core_server_15.TomColumnInformation>(positional, 1, 'columnInformation', 'dateF');
        return t.dateF(fieldName, columnInformation);
      },
    },
    constructorSignatures: {
      '': 'MariadbRepository([List<Type>? queryTypes, Type? resultType])',
    },
    methodSignatures: {
      'delete': 'Future<void> delete(T entity)',
      'deleteAllById': 'Future<void> deleteAllById(Iterable<K> ids)',
      'deleteById': 'Future<int> deleteById(K id)',
      'existsById': 'Future<bool> existsById(Iterable<K> ids)',
      'findAll': 'Future<List<T>> findAll()',
      'findAllById': 'Future<List<T>> findAllById(Iterable<K> ids)',
      'findById': 'Future<T?> findById(K id)',
      'count': 'Future<TomDbInt> count()',
      'save': 'Future<T> save(T toSave)',
      'saveAll': 'Future<Iterable<T>> saveAll(Iterable<T> entities)',
      'findByQuerySentence': 'Future<Iterable<T>> findByQuerySentence(String querySentence, Map<String, Object?> params, [Type? resultType])',
      'deleteByQuerySentence': 'Future<int> deleteByQuerySentence(String querySentence, Map<String, Object?> params)',
      'countByQuerySentence': 'Future<TomDbInt> countByQuerySentence(String querySentence, Map<String, Object?> params)',
      'findByQuery': 'Future<Iterable<T>> findByQuery(TomSelect query, Map<String, Object?> params)',
      'deleteByQuery': 'Future<int> deleteByQuery(TomDelete query, Map<String, Object?> params)',
      'countByQuery': 'Future<TomDbInt> countByQuery(TomCount query, Map<String, Object?> params)',
      'executeQueryString': 'Future<Iterable<T>> executeQueryString(String dbQuery, Map<String, Object?> params)',
      'isNull': 'TomOperator<TomDbBool> isNull(TomOperator<T> what)',
      'isNotNull': 'TomOperator<TomDbBool> isNotNull(TomOperator<T> what)',
      'isIn': 'TomOperator<TomDbBool> isIn(TomOperator<T> what, List<TomOperator<T>> choices)',
      'between': 'TomOperator<TomDbBool> between(TomOperator<T> what, List<TomOperator<T>> betweenLimits)',
      'like': 'TomOperator<TomDbBool> like(TomOperator<TomDbString> text, TomOperator<TomDbString> test)',
      'notLike': 'TomOperator<TomDbBool> notLike(TomOperator<TomDbString> text, TomOperator<TomDbString> test)',
      'regexp': 'TomOperator<TomDbBool> regexp(TomOperator<TomDbString> text, TomOperator<TomDbString> test)',
      'group': 'TomOperator<T> group(TomOperator<T> operant)',
      'eq': 'TomOperator<TomDbBool> eq(TomOperator<T> operant1, TomOperator<T> operant2)',
      'neq': 'TomOperator<TomDbBool> neq(TomOperator<T> operant1, TomOperator<T> operant2)',
      'lt': 'TomOperator<TomDbBool> lt(TomOperator<T> operant1, TomOperator<T> operant2)',
      'lte': 'TomOperator<TomDbBool> lte(TomOperator<T> operant1, TomOperator<T> operant2)',
      'gt': 'TomOperator<TomDbBool> gt(TomOperator<T> operant1, TomOperator<T> operant2)',
      'gte': 'TomOperator<TomDbBool> gte(TomOperator<T> operant1, TomOperator<T> operant2)',
      'not': 'TomOperator<TomDbBool> not(TomOperator<TomDbBool> operant1)',
      'and': 'TomOperator<TomDbBool> and(List<TomOperator<TomDbBool>> operant1)',
      'or': 'TomOperator<TomDbBool> or(List<TomOperator<TomDbBool>> operant1)',
      'text': 'TomOperator<TomDbString> text(String text)',
      'intOp': 'TomOperator<TomDbInt> intOp(int value)',
      'doubleOp': 'TomOperator<TomDbDouble> doubleOp(double value)',
      'boolOp': 'TomOperator<TomDbBool> boolOp(bool value)',
      'dateTimeOp': 'TomOperator<TomDbDateTime> dateTimeOp(DateTime value)',
      'dateOp': 'TomOperator<TomDbDate> dateOp(DateTime value)',
      'p': 'TomOperator<T> p(String parameterName)',
      'textF': 'TomOperator<TomDbString> textF(String fieldName, TomColumnInformation columnInformation)',
      'intF': 'TomOperator<TomDbInt> intF(String fieldName, TomColumnInformation columnInformation)',
      'doubleF': 'TomOperator<TomDbDouble> doubleF(String fieldName, TomColumnInformation columnInformation)',
      'boolF': 'TomOperator<TomDbBool> boolF(String fieldName, TomColumnInformation columnInformation)',
      'dateTimeF': 'TomOperator<TomDbDateTime> dateTimeF(String fieldName, TomColumnInformation columnInformation)',
      'dateF': 'TomOperator<TomDbDate> dateF(String fieldName, TomColumnInformation columnInformation)',
    },
    getterSignatures: {
      'primaryKeyColumnInfo': 'TomColumnInformation get primaryKeyColumnInfo',
      'datasourceInfo': 'TomDataSourceInfo get datasourceInfo',
      'persistenceInfo': 'TomTypePersistenceInfo get persistenceInfo',
      'dbTable': 'TomDbTable get dbTable',
      'sqlDialect': 'TomStandardSqlDialect get sqlDialect',
      'queryTypes': 'List<Type> get queryTypes',
      'resultType': 'Type get resultType',
    },
    setterSignatures: {
      'primaryKeyColumnInfo': 'set primaryKeyColumnInfo(TomColumnInformation value)',
      'datasourceInfo': 'set datasourceInfo(TomDataSourceInfo value)',
      'persistenceInfo': 'set persistenceInfo(TomTypePersistenceInfo value)',
      'dbTable': 'set dbTable(TomDbTable value)',
      'queryTypes': 'set queryTypes(List<Type> value)',
      'resultType': 'set resultType(Type value)',
    },
  );
}

// =============================================================================
// TomQuerySyntaxException Bridge
// =============================================================================

BridgedClass _createTomQuerySyntaxExceptionBridge() {
  return BridgedClass(
    nativeType: TomQuerySyntaxException,
    name: 'TomQuerySyntaxException',
    isAssignable: (v) => v is TomQuerySyntaxException,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'TomQuerySyntaxException');
        final key = D4.getRequiredArg<String>(positional, 0, 'key', 'TomQuerySyntaxException');
        final defaultUserMessage = D4.getRequiredArg<String>(positional, 1, 'defaultUserMessage', 'TomQuerySyntaxException');
        final parameters = D4.coerceMapOrNull<String, Object?>(named['parameters'], 'parameters');
        final stack = D4.getOptionalNamedArg<Object?>(named, 'stack');
        final rootException = D4.getOptionalNamedArg<Object?>(named, 'rootException');
        final autoLog = D4.getNamedArgWithDefault<bool>(named, 'autoLog', false);
        return TomQuerySyntaxException(key, defaultUserMessage, parameters: parameters, stack: stack, rootException: rootException, autoLog: autoLog);
      },
    },
    getters: {
      'isolateName': (visitor, target) => D4.validateTarget<TomQuerySyntaxException>(target, 'TomQuerySyntaxException').isolateName,
      'clientThrow': (visitor, target) => D4.validateTarget<TomQuerySyntaxException>(target, 'TomQuerySyntaxException').clientThrow,
      'autoLog': (visitor, target) => D4.validateTarget<TomQuerySyntaxException>(target, 'TomQuerySyntaxException').autoLog,
      'serverCallError': (visitor, target) => D4.validateTarget<TomQuerySyntaxException>(target, 'TomQuerySyntaxException').serverCallError,
      'newField': (visitor, target) => D4.validateTarget<TomQuerySyntaxException>(target, 'TomQuerySyntaxException').newField,
      'logRepresentation': (visitor, target) => D4.validateTarget<TomQuerySyntaxException>(target, 'TomQuerySyntaxException').logRepresentation,
      'uuid': (visitor, target) => D4.validateTarget<TomQuerySyntaxException>(target, 'TomQuerySyntaxException').uuid,
      'requestUuid': (visitor, target) => D4.validateTarget<TomQuerySyntaxException>(target, 'TomQuerySyntaxException').requestUuid,
      'timeStamp': (visitor, target) => D4.validateTarget<TomQuerySyntaxException>(target, 'TomQuerySyntaxException').timeStamp,
      'key': (visitor, target) => D4.validateTarget<TomQuerySyntaxException>(target, 'TomQuerySyntaxException').key,
      'defaultUserMessage': (visitor, target) => D4.validateTarget<TomQuerySyntaxException>(target, 'TomQuerySyntaxException').defaultUserMessage,
      'parameters': (visitor, target) => D4.validateTarget<TomQuerySyntaxException>(target, 'TomQuerySyntaxException').parameters,
      'stack': (visitor, target) => D4.validateTarget<TomQuerySyntaxException>(target, 'TomQuerySyntaxException').stack,
      'rootException': (visitor, target) => D4.validateTarget<TomQuerySyntaxException>(target, 'TomQuerySyntaxException').rootException,
      'stackTrace': (visitor, target) => D4.validateTarget<TomQuerySyntaxException>(target, 'TomQuerySyntaxException').stackTrace,
    },
    setters: {
      'isolateName': (visitor, target, value) => 
        D4.validateTarget<TomQuerySyntaxException>(target, 'TomQuerySyntaxException').isolateName = D4.extractBridgedArg<String>(value, 'isolateName'),
      'clientThrow': (visitor, target, value) => 
        D4.validateTarget<TomQuerySyntaxException>(target, 'TomQuerySyntaxException').clientThrow = D4.extractBridgedArg<bool>(value, 'clientThrow'),
      'autoLog': (visitor, target, value) => 
        D4.validateTarget<TomQuerySyntaxException>(target, 'TomQuerySyntaxException').autoLog = D4.extractBridgedArg<bool>(value, 'autoLog'),
      'serverCallError': (visitor, target, value) => 
        D4.validateTarget<TomQuerySyntaxException>(target, 'TomQuerySyntaxException').serverCallError = D4.extractBridgedArgOrNull<$tom_core_kernel_4.TomServerCallError>(value, 'serverCallError'),
      'newField': (visitor, target, value) => 
        D4.validateTarget<TomQuerySyntaxException>(target, 'TomQuerySyntaxException').newField = D4.extractBridgedArgOrNull<String>(value, 'newField'),
      'uuid': (visitor, target, value) => 
        D4.validateTarget<TomQuerySyntaxException>(target, 'TomQuerySyntaxException').uuid = D4.extractBridgedArg<String>(value, 'uuid'),
      'requestUuid': (visitor, target, value) => 
        D4.validateTarget<TomQuerySyntaxException>(target, 'TomQuerySyntaxException').requestUuid = D4.extractBridgedArgOrNull<String>(value, 'requestUuid'),
      'timeStamp': (visitor, target, value) => 
        D4.validateTarget<TomQuerySyntaxException>(target, 'TomQuerySyntaxException').timeStamp = D4.extractBridgedArg<DateTime>(value, 'timeStamp'),
      'key': (visitor, target, value) => 
        D4.validateTarget<TomQuerySyntaxException>(target, 'TomQuerySyntaxException').key = D4.extractBridgedArg<String>(value, 'key'),
      'defaultUserMessage': (visitor, target, value) => 
        D4.validateTarget<TomQuerySyntaxException>(target, 'TomQuerySyntaxException').defaultUserMessage = D4.extractBridgedArg<String>(value, 'defaultUserMessage'),
      'stack': (visitor, target, value) => 
        D4.validateTarget<TomQuerySyntaxException>(target, 'TomQuerySyntaxException').stack = D4.extractBridgedArgOrNull<Object>(value, 'stack'),
      'rootException': (visitor, target, value) => 
        D4.validateTarget<TomQuerySyntaxException>(target, 'TomQuerySyntaxException').rootException = D4.extractBridgedArgOrNull<Object>(value, 'rootException'),
      'stackTrace': (visitor, target, value) => 
        D4.validateTarget<TomQuerySyntaxException>(target, 'TomQuerySyntaxException').stackTrace = D4.extractBridgedArg<String>(value, 'stackTrace'),
    },
    methods: {
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQuerySyntaxException>(target, 'TomQuerySyntaxException');
        return t.toString();
      },
      'printStackTrace': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQuerySyntaxException>(target, 'TomQuerySyntaxException');
        final depth = D4.getOptionalArgWithDefault<int>(positional, 0, 'depth', -1);
        t.printStackTrace(depth);
        return null;
      },
    },
    constructorSignatures: {
      '': 'TomQuerySyntaxException(String key, String defaultUserMessage, {Map<String, Object?>? parameters, Object? stack, Object? rootException, bool autoLog = false})',
    },
    methodSignatures: {
      'toString': 'String toString()',
      'printStackTrace': 'void printStackTrace([int depth = -1])',
    },
    getterSignatures: {
      'isolateName': 'String get isolateName',
      'clientThrow': 'bool get clientThrow',
      'autoLog': 'bool get autoLog',
      'serverCallError': 'TomServerCallError? get serverCallError',
      'newField': 'String? get newField',
      'logRepresentation': 'String get logRepresentation',
      'uuid': 'String get uuid',
      'requestUuid': 'String? get requestUuid',
      'timeStamp': 'DateTime get timeStamp',
      'key': 'String get key',
      'defaultUserMessage': 'String get defaultUserMessage',
      'parameters': 'Map<String, Object?>? get parameters',
      'stack': 'Object? get stack',
      'rootException': 'Object? get rootException',
      'stackTrace': 'String get stackTrace',
    },
    setterSignatures: {
      'isolateName': 'set isolateName(String value)',
      'clientThrow': 'set clientThrow(bool value)',
      'autoLog': 'set autoLog(bool value)',
      'serverCallError': 'set serverCallError(TomServerCallError? value)',
      'newField': 'set newField(String? value)',
      'uuid': 'set uuid(String value)',
      'requestUuid': 'set requestUuid(String? value)',
      'timeStamp': 'set timeStamp(DateTime value)',
      'key': 'set key(String value)',
      'defaultUserMessage': 'set defaultUserMessage(String value)',
      'parameters': 'set parameters(Map<String, Object?>? value)',
      'stack': 'set stack(Object? value)',
      'rootException': 'set rootException(Object? value)',
      'stackTrace': 'set stackTrace(String value)',
    },
  );
}

// =============================================================================
// TomUnaryOperator Bridge
// =============================================================================

BridgedClass _createTomUnaryOperatorBridge() {
  return BridgedClass(
    nativeType: TomUnaryOperator,
    name: 'TomUnaryOperator',
    isAssignable: (v) => v is TomUnaryOperator,
    constructors: {
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<TomUnaryOperator>(target, 'TomUnaryOperator').returnType,
      'operant1': (visitor, target) => D4.validateTarget<TomUnaryOperator>(target, 'TomUnaryOperator').operant1,
    },
    setters: {
      'returnType': (visitor, target, value) => 
        D4.validateTarget<TomUnaryOperator>(target, 'TomUnaryOperator').returnType = D4.extractBridgedArg<Type>(value, 'returnType'),
      'operant1': (visitor, target, value) => 
        D4.validateTarget<TomUnaryOperator>(target, 'TomUnaryOperator').operant1 = value as dynamic,
    },
    methods: {
      'generate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomUnaryOperator>(target, 'TomUnaryOperator');
        D4.requireMinArgs(positional, 1, 'generate');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generate');
        return t.generate(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomUnaryOperator>(target, 'TomUnaryOperator');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomUnaryOperator>(target, 'TomUnaryOperator');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomUnaryOperator>(target, 'TomUnaryOperator');
        return t.toString();
      },
      'indent': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomUnaryOperator>(target, 'TomUnaryOperator');
        D4.requireMinArgs(positional, 1, 'indent');
        final i = D4.getRequiredArg<int>(positional, 0, 'i', 'indent');
        return t.indent(i);
      },
      'analyze': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomUnaryOperator>(target, 'TomUnaryOperator');
        D4.requireMinArgs(positional, 1, 'analyze');
        final l = D4.getRequiredArg<int>(positional, 0, 'l', 'analyze');
        return t.analyze(l);
      },
    },
    methodSignatures: {
      'generate': 'String generate(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
      'indent': 'String indent(int i)',
      'analyze': 'String analyze(int l)',
    },
    getterSignatures: {
      'returnType': 'Type get returnType',
      'operant1': 'T get operant1',
    },
    setterSignatures: {
      'returnType': 'set returnType(Type value)',
      'operant1': 'set operant1(dynamic value)',
    },
  );
}

// =============================================================================
// Parameter Bridge
// =============================================================================

BridgedClass _createParameterBridge() {
  return BridgedClass(
    nativeType: Parameter,
    name: 'Parameter',
    isAssignable: (v) => v is Parameter,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'Parameter');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'Parameter');
        return Parameter(name);
      },
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<Parameter>(target, 'Parameter').returnType,
      'name': (visitor, target) => D4.validateTarget<Parameter>(target, 'Parameter').name,
    },
    setters: {
      'returnType': (visitor, target, value) => 
        D4.validateTarget<Parameter>(target, 'Parameter').returnType = D4.extractBridgedArg<Type>(value, 'returnType'),
      'name': (visitor, target, value) => 
        D4.validateTarget<Parameter>(target, 'Parameter').name = D4.extractBridgedArg<String>(value, 'name'),
    },
    methods: {
      'generate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Parameter>(target, 'Parameter');
        D4.requireMinArgs(positional, 1, 'generate');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generate');
        return t.generate(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Parameter>(target, 'Parameter');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Parameter>(target, 'Parameter');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Parameter>(target, 'Parameter');
        return t.toString();
      },
      'indent': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Parameter>(target, 'Parameter');
        D4.requireMinArgs(positional, 1, 'indent');
        final i = D4.getRequiredArg<int>(positional, 0, 'i', 'indent');
        return t.indent(i);
      },
      'analyze': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Parameter>(target, 'Parameter');
        D4.requireMinArgs(positional, 1, 'analyze');
        final l = D4.getRequiredArg<int>(positional, 0, 'l', 'analyze');
        return t.analyze(l);
      },
    },
    constructorSignatures: {
      '': 'Parameter(String name)',
    },
    methodSignatures: {
      'generate': 'SqlString generate(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
      'indent': 'String indent(int i)',
      'analyze': 'String analyze(int l)',
    },
    getterSignatures: {
      'returnType': 'Type get returnType',
      'name': 'String get name',
    },
    setterSignatures: {
      'returnType': 'set returnType(Type value)',
      'name': 'set name(dynamic value)',
    },
  );
}

// =============================================================================
// DbCol Bridge
// =============================================================================

BridgedClass _createDbColBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_14.DbCol,
    name: 'DbCol',
    isAssignable: (v) => v is $tom_core_server_14.DbCol,
    constructors: {
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<$tom_core_server_14.DbCol>(target, 'DbCol').returnType,
      'operant1': (visitor, target) => D4.validateTarget<$tom_core_server_14.DbCol>(target, 'DbCol').operant1,
      'columnInformation': (visitor, target) => D4.validateTarget<$tom_core_server_14.DbCol>(target, 'DbCol').columnInformation,
      'tableType': (visitor, target) => D4.validateTarget<$tom_core_server_14.DbCol>(target, 'DbCol').tableType,
    },
    setters: {
      'returnType': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_14.DbCol>(target, 'DbCol').returnType = D4.extractBridgedArg<Type>(value, 'returnType'),
      'operant1': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_14.DbCol>(target, 'DbCol').operant1 = D4.extractBridgedArg<String>(value, 'operant1'),
      'columnInformation': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_14.DbCol>(target, 'DbCol').columnInformation = D4.extractBridgedArg<$tom_core_server_15.TomColumnInformation>(value, 'columnInformation'),
      'tableType': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_14.DbCol>(target, 'DbCol').tableType = D4.extractBridgedArg<Type>(value, 'tableType'),
    },
    methods: {
      'generate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_14.DbCol>(target, 'DbCol');
        D4.requireMinArgs(positional, 1, 'generate');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generate');
        return t.generate(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_14.DbCol>(target, 'DbCol');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_14.DbCol>(target, 'DbCol');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_14.DbCol>(target, 'DbCol');
        return t.toString();
      },
      'indent': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_14.DbCol>(target, 'DbCol');
        D4.requireMinArgs(positional, 1, 'indent');
        final i = D4.getRequiredArg<int>(positional, 0, 'i', 'indent');
        return t.indent(i);
      },
      'analyze': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_14.DbCol>(target, 'DbCol');
        D4.requireMinArgs(positional, 1, 'analyze');
        final l = D4.getRequiredArg<int>(positional, 0, 'l', 'analyze');
        return t.analyze(l);
      },
    },
    methodSignatures: {
      'generate': 'String generate(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
      'indent': 'String indent(int i)',
      'analyze': 'String analyze(int l)',
    },
    getterSignatures: {
      'returnType': 'Type get returnType',
      'operant1': 'String get operant1',
      'columnInformation': 'TomColumnInformation get columnInformation',
      'tableType': 'Type get tableType',
    },
    setterSignatures: {
      'returnType': 'set returnType(Type value)',
      'operant1': 'set operant1(String value)',
      'columnInformation': 'set columnInformation(dynamic value)',
      'tableType': 'set tableType(dynamic value)',
    },
  );
}

// =============================================================================
// IntCol Bridge
// =============================================================================

BridgedClass _createIntColBridge() {
  return BridgedClass(
    nativeType: IntCol,
    name: 'IntCol',
    isAssignable: (v) => v is IntCol,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 3, 'IntCol');
        final tableType = D4.getRequiredArg<Type>(positional, 0, 'tableType', 'IntCol');
        final operant1 = D4.getRequiredArg<String>(positional, 1, 'operant1', 'IntCol');
        final columnInformation = D4.getRequiredArg<$tom_core_server_15.TomColumnInformation>(positional, 2, 'columnInformation', 'IntCol');
        return IntCol(tableType, operant1, columnInformation);
      },
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<IntCol>(target, 'IntCol').returnType,
      'operant1': (visitor, target) => D4.validateTarget<IntCol>(target, 'IntCol').operant1,
      'columnInformation': (visitor, target) => D4.validateTarget<IntCol>(target, 'IntCol').columnInformation,
      'tableType': (visitor, target) => D4.validateTarget<IntCol>(target, 'IntCol').tableType,
    },
    setters: {
      'returnType': (visitor, target, value) => 
        D4.validateTarget<IntCol>(target, 'IntCol').returnType = D4.extractBridgedArg<Type>(value, 'returnType'),
      'operant1': (visitor, target, value) => 
        D4.validateTarget<IntCol>(target, 'IntCol').operant1 = D4.extractBridgedArg<String>(value, 'operant1'),
      'columnInformation': (visitor, target, value) => 
        D4.validateTarget<IntCol>(target, 'IntCol').columnInformation = D4.extractBridgedArg<$tom_core_server_15.TomColumnInformation>(value, 'columnInformation'),
      'tableType': (visitor, target, value) => 
        D4.validateTarget<IntCol>(target, 'IntCol').tableType = D4.extractBridgedArg<Type>(value, 'tableType'),
    },
    methods: {
      'generate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IntCol>(target, 'IntCol');
        D4.requireMinArgs(positional, 1, 'generate');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generate');
        return t.generate(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IntCol>(target, 'IntCol');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IntCol>(target, 'IntCol');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IntCol>(target, 'IntCol');
        return t.toString();
      },
      'indent': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IntCol>(target, 'IntCol');
        D4.requireMinArgs(positional, 1, 'indent');
        final i = D4.getRequiredArg<int>(positional, 0, 'i', 'indent');
        return t.indent(i);
      },
      'analyze': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IntCol>(target, 'IntCol');
        D4.requireMinArgs(positional, 1, 'analyze');
        final l = D4.getRequiredArg<int>(positional, 0, 'l', 'analyze');
        return t.analyze(l);
      },
    },
    constructorSignatures: {
      '': 'IntCol(Type tableType, String operant1, TomColumnInformation columnInformation)',
    },
    methodSignatures: {
      'generate': 'SqlString generate(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
      'indent': 'String indent(int i)',
      'analyze': 'String analyze(int l)',
    },
    getterSignatures: {
      'returnType': 'Type get returnType',
      'operant1': 'String get operant1',
      'columnInformation': 'TomColumnInformation get columnInformation',
      'tableType': 'Type get tableType',
    },
    setterSignatures: {
      'returnType': 'set returnType(Type value)',
      'operant1': 'set operant1(String value)',
      'columnInformation': 'set columnInformation(TomColumnInformation value)',
      'tableType': 'set tableType(Type value)',
    },
  );
}

// =============================================================================
// StringCol Bridge
// =============================================================================

BridgedClass _createStringColBridge() {
  return BridgedClass(
    nativeType: StringCol,
    name: 'StringCol',
    isAssignable: (v) => v is StringCol,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 3, 'StringCol');
        final tableType = D4.getRequiredArg<Type>(positional, 0, 'tableType', 'StringCol');
        final operant1 = D4.getRequiredArg<String>(positional, 1, 'operant1', 'StringCol');
        final columnInformation = D4.getRequiredArg<$tom_core_server_15.TomColumnInformation>(positional, 2, 'columnInformation', 'StringCol');
        return StringCol(tableType, operant1, columnInformation);
      },
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<StringCol>(target, 'StringCol').returnType,
      'operant1': (visitor, target) => D4.validateTarget<StringCol>(target, 'StringCol').operant1,
      'columnInformation': (visitor, target) => D4.validateTarget<StringCol>(target, 'StringCol').columnInformation,
      'tableType': (visitor, target) => D4.validateTarget<StringCol>(target, 'StringCol').tableType,
    },
    setters: {
      'returnType': (visitor, target, value) => 
        D4.validateTarget<StringCol>(target, 'StringCol').returnType = D4.extractBridgedArg<Type>(value, 'returnType'),
      'operant1': (visitor, target, value) => 
        D4.validateTarget<StringCol>(target, 'StringCol').operant1 = D4.extractBridgedArg<String>(value, 'operant1'),
      'columnInformation': (visitor, target, value) => 
        D4.validateTarget<StringCol>(target, 'StringCol').columnInformation = D4.extractBridgedArg<$tom_core_server_15.TomColumnInformation>(value, 'columnInformation'),
      'tableType': (visitor, target, value) => 
        D4.validateTarget<StringCol>(target, 'StringCol').tableType = D4.extractBridgedArg<Type>(value, 'tableType'),
    },
    methods: {
      'generate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<StringCol>(target, 'StringCol');
        D4.requireMinArgs(positional, 1, 'generate');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generate');
        return t.generate(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<StringCol>(target, 'StringCol');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<StringCol>(target, 'StringCol');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<StringCol>(target, 'StringCol');
        return t.toString();
      },
      'indent': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<StringCol>(target, 'StringCol');
        D4.requireMinArgs(positional, 1, 'indent');
        final i = D4.getRequiredArg<int>(positional, 0, 'i', 'indent');
        return t.indent(i);
      },
      'analyze': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<StringCol>(target, 'StringCol');
        D4.requireMinArgs(positional, 1, 'analyze');
        final l = D4.getRequiredArg<int>(positional, 0, 'l', 'analyze');
        return t.analyze(l);
      },
    },
    constructorSignatures: {
      '': 'StringCol(Type tableType, String operant1, TomColumnInformation columnInformation)',
    },
    methodSignatures: {
      'generate': 'SqlString generate(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
      'indent': 'String indent(int i)',
      'analyze': 'String analyze(int l)',
    },
    getterSignatures: {
      'returnType': 'Type get returnType',
      'operant1': 'String get operant1',
      'columnInformation': 'TomColumnInformation get columnInformation',
      'tableType': 'Type get tableType',
    },
    setterSignatures: {
      'returnType': 'set returnType(Type value)',
      'operant1': 'set operant1(String value)',
      'columnInformation': 'set columnInformation(TomColumnInformation value)',
      'tableType': 'set tableType(Type value)',
    },
  );
}

// =============================================================================
// DoubleCol Bridge
// =============================================================================

BridgedClass _createDoubleColBridge() {
  return BridgedClass(
    nativeType: DoubleCol,
    name: 'DoubleCol',
    isAssignable: (v) => v is DoubleCol,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 3, 'DoubleCol');
        final tableType = D4.getRequiredArg<Type>(positional, 0, 'tableType', 'DoubleCol');
        final operant1 = D4.getRequiredArg<String>(positional, 1, 'operant1', 'DoubleCol');
        final columnInformation = D4.getRequiredArg<$tom_core_server_15.TomColumnInformation>(positional, 2, 'columnInformation', 'DoubleCol');
        return DoubleCol(tableType, operant1, columnInformation);
      },
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<DoubleCol>(target, 'DoubleCol').returnType,
      'operant1': (visitor, target) => D4.validateTarget<DoubleCol>(target, 'DoubleCol').operant1,
      'columnInformation': (visitor, target) => D4.validateTarget<DoubleCol>(target, 'DoubleCol').columnInformation,
      'tableType': (visitor, target) => D4.validateTarget<DoubleCol>(target, 'DoubleCol').tableType,
    },
    setters: {
      'returnType': (visitor, target, value) => 
        D4.validateTarget<DoubleCol>(target, 'DoubleCol').returnType = D4.extractBridgedArg<Type>(value, 'returnType'),
      'operant1': (visitor, target, value) => 
        D4.validateTarget<DoubleCol>(target, 'DoubleCol').operant1 = D4.extractBridgedArg<String>(value, 'operant1'),
      'columnInformation': (visitor, target, value) => 
        D4.validateTarget<DoubleCol>(target, 'DoubleCol').columnInformation = D4.extractBridgedArg<$tom_core_server_15.TomColumnInformation>(value, 'columnInformation'),
      'tableType': (visitor, target, value) => 
        D4.validateTarget<DoubleCol>(target, 'DoubleCol').tableType = D4.extractBridgedArg<Type>(value, 'tableType'),
    },
    methods: {
      'generate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DoubleCol>(target, 'DoubleCol');
        D4.requireMinArgs(positional, 1, 'generate');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generate');
        return t.generate(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DoubleCol>(target, 'DoubleCol');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DoubleCol>(target, 'DoubleCol');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DoubleCol>(target, 'DoubleCol');
        return t.toString();
      },
      'indent': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DoubleCol>(target, 'DoubleCol');
        D4.requireMinArgs(positional, 1, 'indent');
        final i = D4.getRequiredArg<int>(positional, 0, 'i', 'indent');
        return t.indent(i);
      },
      'analyze': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DoubleCol>(target, 'DoubleCol');
        D4.requireMinArgs(positional, 1, 'analyze');
        final l = D4.getRequiredArg<int>(positional, 0, 'l', 'analyze');
        return t.analyze(l);
      },
    },
    constructorSignatures: {
      '': 'DoubleCol(Type tableType, String operant1, TomColumnInformation columnInformation)',
    },
    methodSignatures: {
      'generate': 'SqlString generate(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
      'indent': 'String indent(int i)',
      'analyze': 'String analyze(int l)',
    },
    getterSignatures: {
      'returnType': 'Type get returnType',
      'operant1': 'String get operant1',
      'columnInformation': 'TomColumnInformation get columnInformation',
      'tableType': 'Type get tableType',
    },
    setterSignatures: {
      'returnType': 'set returnType(Type value)',
      'operant1': 'set operant1(String value)',
      'columnInformation': 'set columnInformation(TomColumnInformation value)',
      'tableType': 'set tableType(Type value)',
    },
  );
}

// =============================================================================
// BoolCol Bridge
// =============================================================================

BridgedClass _createBoolColBridge() {
  return BridgedClass(
    nativeType: BoolCol,
    name: 'BoolCol',
    isAssignable: (v) => v is BoolCol,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 3, 'BoolCol');
        final tableType = D4.getRequiredArg<Type>(positional, 0, 'tableType', 'BoolCol');
        final operant1 = D4.getRequiredArg<String>(positional, 1, 'operant1', 'BoolCol');
        final columnInformation = D4.getRequiredArg<$tom_core_server_15.TomColumnInformation>(positional, 2, 'columnInformation', 'BoolCol');
        return BoolCol(tableType, operant1, columnInformation);
      },
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<BoolCol>(target, 'BoolCol').returnType,
      'operant1': (visitor, target) => D4.validateTarget<BoolCol>(target, 'BoolCol').operant1,
      'columnInformation': (visitor, target) => D4.validateTarget<BoolCol>(target, 'BoolCol').columnInformation,
      'tableType': (visitor, target) => D4.validateTarget<BoolCol>(target, 'BoolCol').tableType,
    },
    setters: {
      'returnType': (visitor, target, value) => 
        D4.validateTarget<BoolCol>(target, 'BoolCol').returnType = D4.extractBridgedArg<Type>(value, 'returnType'),
      'operant1': (visitor, target, value) => 
        D4.validateTarget<BoolCol>(target, 'BoolCol').operant1 = D4.extractBridgedArg<String>(value, 'operant1'),
      'columnInformation': (visitor, target, value) => 
        D4.validateTarget<BoolCol>(target, 'BoolCol').columnInformation = D4.extractBridgedArg<$tom_core_server_15.TomColumnInformation>(value, 'columnInformation'),
      'tableType': (visitor, target, value) => 
        D4.validateTarget<BoolCol>(target, 'BoolCol').tableType = D4.extractBridgedArg<Type>(value, 'tableType'),
    },
    methods: {
      'generate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<BoolCol>(target, 'BoolCol');
        D4.requireMinArgs(positional, 1, 'generate');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generate');
        return t.generate(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<BoolCol>(target, 'BoolCol');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<BoolCol>(target, 'BoolCol');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<BoolCol>(target, 'BoolCol');
        return t.toString();
      },
      'indent': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<BoolCol>(target, 'BoolCol');
        D4.requireMinArgs(positional, 1, 'indent');
        final i = D4.getRequiredArg<int>(positional, 0, 'i', 'indent');
        return t.indent(i);
      },
      'analyze': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<BoolCol>(target, 'BoolCol');
        D4.requireMinArgs(positional, 1, 'analyze');
        final l = D4.getRequiredArg<int>(positional, 0, 'l', 'analyze');
        return t.analyze(l);
      },
    },
    constructorSignatures: {
      '': 'BoolCol(Type tableType, String operant1, TomColumnInformation columnInformation)',
    },
    methodSignatures: {
      'generate': 'SqlString generate(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
      'indent': 'String indent(int i)',
      'analyze': 'String analyze(int l)',
    },
    getterSignatures: {
      'returnType': 'Type get returnType',
      'operant1': 'String get operant1',
      'columnInformation': 'TomColumnInformation get columnInformation',
      'tableType': 'Type get tableType',
    },
    setterSignatures: {
      'returnType': 'set returnType(Type value)',
      'operant1': 'set operant1(String value)',
      'columnInformation': 'set columnInformation(TomColumnInformation value)',
      'tableType': 'set tableType(Type value)',
    },
  );
}

// =============================================================================
// DateTimeCol Bridge
// =============================================================================

BridgedClass _createDateTimeColBridge() {
  return BridgedClass(
    nativeType: DateTimeCol,
    name: 'DateTimeCol',
    isAssignable: (v) => v is DateTimeCol,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 3, 'DateTimeCol');
        final tableType = D4.getRequiredArg<Type>(positional, 0, 'tableType', 'DateTimeCol');
        final operant1 = D4.getRequiredArg<String>(positional, 1, 'operant1', 'DateTimeCol');
        final columnInformation = D4.getRequiredArg<$tom_core_server_15.TomColumnInformation>(positional, 2, 'columnInformation', 'DateTimeCol');
        return DateTimeCol(tableType, operant1, columnInformation);
      },
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<DateTimeCol>(target, 'DateTimeCol').returnType,
      'operant1': (visitor, target) => D4.validateTarget<DateTimeCol>(target, 'DateTimeCol').operant1,
      'columnInformation': (visitor, target) => D4.validateTarget<DateTimeCol>(target, 'DateTimeCol').columnInformation,
      'tableType': (visitor, target) => D4.validateTarget<DateTimeCol>(target, 'DateTimeCol').tableType,
    },
    setters: {
      'returnType': (visitor, target, value) => 
        D4.validateTarget<DateTimeCol>(target, 'DateTimeCol').returnType = D4.extractBridgedArg<Type>(value, 'returnType'),
      'operant1': (visitor, target, value) => 
        D4.validateTarget<DateTimeCol>(target, 'DateTimeCol').operant1 = D4.extractBridgedArg<String>(value, 'operant1'),
      'columnInformation': (visitor, target, value) => 
        D4.validateTarget<DateTimeCol>(target, 'DateTimeCol').columnInformation = D4.extractBridgedArg<$tom_core_server_15.TomColumnInformation>(value, 'columnInformation'),
      'tableType': (visitor, target, value) => 
        D4.validateTarget<DateTimeCol>(target, 'DateTimeCol').tableType = D4.extractBridgedArg<Type>(value, 'tableType'),
    },
    methods: {
      'generate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DateTimeCol>(target, 'DateTimeCol');
        D4.requireMinArgs(positional, 1, 'generate');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generate');
        return t.generate(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DateTimeCol>(target, 'DateTimeCol');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DateTimeCol>(target, 'DateTimeCol');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DateTimeCol>(target, 'DateTimeCol');
        return t.toString();
      },
      'indent': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DateTimeCol>(target, 'DateTimeCol');
        D4.requireMinArgs(positional, 1, 'indent');
        final i = D4.getRequiredArg<int>(positional, 0, 'i', 'indent');
        return t.indent(i);
      },
      'analyze': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DateTimeCol>(target, 'DateTimeCol');
        D4.requireMinArgs(positional, 1, 'analyze');
        final l = D4.getRequiredArg<int>(positional, 0, 'l', 'analyze');
        return t.analyze(l);
      },
    },
    constructorSignatures: {
      '': 'DateTimeCol(Type tableType, String operant1, TomColumnInformation columnInformation)',
    },
    methodSignatures: {
      'generate': 'SqlString generate(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
      'indent': 'String indent(int i)',
      'analyze': 'String analyze(int l)',
    },
    getterSignatures: {
      'returnType': 'Type get returnType',
      'operant1': 'String get operant1',
      'columnInformation': 'TomColumnInformation get columnInformation',
      'tableType': 'Type get tableType',
    },
    setterSignatures: {
      'returnType': 'set returnType(Type value)',
      'operant1': 'set operant1(String value)',
      'columnInformation': 'set columnInformation(TomColumnInformation value)',
      'tableType': 'set tableType(Type value)',
    },
  );
}

// =============================================================================
// DateCol Bridge
// =============================================================================

BridgedClass _createDateColBridge() {
  return BridgedClass(
    nativeType: DateCol,
    name: 'DateCol',
    isAssignable: (v) => v is DateCol,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 3, 'DateCol');
        final tableType = D4.getRequiredArg<Type>(positional, 0, 'tableType', 'DateCol');
        final operant1 = D4.getRequiredArg<String>(positional, 1, 'operant1', 'DateCol');
        final columnInformation = D4.getRequiredArg<$tom_core_server_15.TomColumnInformation>(positional, 2, 'columnInformation', 'DateCol');
        return DateCol(tableType, operant1, columnInformation);
      },
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<DateCol>(target, 'DateCol').returnType,
      'operant1': (visitor, target) => D4.validateTarget<DateCol>(target, 'DateCol').operant1,
      'columnInformation': (visitor, target) => D4.validateTarget<DateCol>(target, 'DateCol').columnInformation,
      'tableType': (visitor, target) => D4.validateTarget<DateCol>(target, 'DateCol').tableType,
    },
    setters: {
      'returnType': (visitor, target, value) => 
        D4.validateTarget<DateCol>(target, 'DateCol').returnType = D4.extractBridgedArg<Type>(value, 'returnType'),
      'operant1': (visitor, target, value) => 
        D4.validateTarget<DateCol>(target, 'DateCol').operant1 = D4.extractBridgedArg<String>(value, 'operant1'),
      'columnInformation': (visitor, target, value) => 
        D4.validateTarget<DateCol>(target, 'DateCol').columnInformation = D4.extractBridgedArg<$tom_core_server_15.TomColumnInformation>(value, 'columnInformation'),
      'tableType': (visitor, target, value) => 
        D4.validateTarget<DateCol>(target, 'DateCol').tableType = D4.extractBridgedArg<Type>(value, 'tableType'),
    },
    methods: {
      'generate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DateCol>(target, 'DateCol');
        D4.requireMinArgs(positional, 1, 'generate');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generate');
        return t.generate(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DateCol>(target, 'DateCol');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DateCol>(target, 'DateCol');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DateCol>(target, 'DateCol');
        return t.toString();
      },
      'indent': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DateCol>(target, 'DateCol');
        D4.requireMinArgs(positional, 1, 'indent');
        final i = D4.getRequiredArg<int>(positional, 0, 'i', 'indent');
        return t.indent(i);
      },
      'analyze': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DateCol>(target, 'DateCol');
        D4.requireMinArgs(positional, 1, 'analyze');
        final l = D4.getRequiredArg<int>(positional, 0, 'l', 'analyze');
        return t.analyze(l);
      },
    },
    constructorSignatures: {
      '': 'DateCol(Type tableType, String operant1, TomColumnInformation columnInformation)',
    },
    methodSignatures: {
      'generate': 'SqlString generate(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
      'indent': 'String indent(int i)',
      'analyze': 'String analyze(int l)',
    },
    getterSignatures: {
      'returnType': 'Type get returnType',
      'operant1': 'String get operant1',
      'columnInformation': 'TomColumnInformation get columnInformation',
      'tableType': 'Type get tableType',
    },
    setterSignatures: {
      'returnType': 'set returnType(Type value)',
      'operant1': 'set operant1(String value)',
      'columnInformation': 'set columnInformation(TomColumnInformation value)',
      'tableType': 'set tableType(Type value)',
    },
  );
}

// =============================================================================
// StringLiteral Bridge
// =============================================================================

BridgedClass _createStringLiteralBridge() {
  return BridgedClass(
    nativeType: StringLiteral,
    name: 'StringLiteral',
    isAssignable: (v) => v is StringLiteral,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'StringLiteral');
        final operant1 = D4.getRequiredArg<String>(positional, 0, 'operant1', 'StringLiteral');
        return StringLiteral(operant1);
      },
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<StringLiteral>(target, 'StringLiteral').returnType,
      'operant1': (visitor, target) => D4.validateTarget<StringLiteral>(target, 'StringLiteral').operant1,
    },
    setters: {
      'returnType': (visitor, target, value) => 
        D4.validateTarget<StringLiteral>(target, 'StringLiteral').returnType = D4.extractBridgedArg<Type>(value, 'returnType'),
      'operant1': (visitor, target, value) => 
        D4.validateTarget<StringLiteral>(target, 'StringLiteral').operant1 = D4.extractBridgedArg<String>(value, 'operant1'),
    },
    methods: {
      'generate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<StringLiteral>(target, 'StringLiteral');
        D4.requireMinArgs(positional, 1, 'generate');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generate');
        return t.generate(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<StringLiteral>(target, 'StringLiteral');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<StringLiteral>(target, 'StringLiteral');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<StringLiteral>(target, 'StringLiteral');
        return t.toString();
      },
      'indent': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<StringLiteral>(target, 'StringLiteral');
        D4.requireMinArgs(positional, 1, 'indent');
        final i = D4.getRequiredArg<int>(positional, 0, 'i', 'indent');
        return t.indent(i);
      },
      'analyze': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<StringLiteral>(target, 'StringLiteral');
        D4.requireMinArgs(positional, 1, 'analyze');
        final l = D4.getRequiredArg<int>(positional, 0, 'l', 'analyze');
        return t.analyze(l);
      },
    },
    constructorSignatures: {
      '': 'StringLiteral(String operant1)',
    },
    methodSignatures: {
      'generate': 'SqlString generate(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
      'indent': 'String indent(int i)',
      'analyze': 'String analyze(int l)',
    },
    getterSignatures: {
      'returnType': 'Type get returnType',
      'operant1': 'String get operant1',
    },
    setterSignatures: {
      'returnType': 'set returnType(Type value)',
      'operant1': 'set operant1(String value)',
    },
  );
}

// =============================================================================
// IntegerLiteral Bridge
// =============================================================================

BridgedClass _createIntegerLiteralBridge() {
  return BridgedClass(
    nativeType: IntegerLiteral,
    name: 'IntegerLiteral',
    isAssignable: (v) => v is IntegerLiteral,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'IntegerLiteral');
        final operant1 = D4.getRequiredArg<int>(positional, 0, 'operant1', 'IntegerLiteral');
        return IntegerLiteral(operant1);
      },
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<IntegerLiteral>(target, 'IntegerLiteral').returnType,
      'operant1': (visitor, target) => D4.validateTarget<IntegerLiteral>(target, 'IntegerLiteral').operant1,
    },
    setters: {
      'returnType': (visitor, target, value) => 
        D4.validateTarget<IntegerLiteral>(target, 'IntegerLiteral').returnType = D4.extractBridgedArg<Type>(value, 'returnType'),
      'operant1': (visitor, target, value) => 
        D4.validateTarget<IntegerLiteral>(target, 'IntegerLiteral').operant1 = D4.extractBridgedArg<int>(value, 'operant1'),
    },
    methods: {
      'generate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IntegerLiteral>(target, 'IntegerLiteral');
        D4.requireMinArgs(positional, 1, 'generate');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generate');
        return t.generate(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IntegerLiteral>(target, 'IntegerLiteral');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IntegerLiteral>(target, 'IntegerLiteral');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IntegerLiteral>(target, 'IntegerLiteral');
        return t.toString();
      },
      'indent': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IntegerLiteral>(target, 'IntegerLiteral');
        D4.requireMinArgs(positional, 1, 'indent');
        final i = D4.getRequiredArg<int>(positional, 0, 'i', 'indent');
        return t.indent(i);
      },
      'analyze': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IntegerLiteral>(target, 'IntegerLiteral');
        D4.requireMinArgs(positional, 1, 'analyze');
        final l = D4.getRequiredArg<int>(positional, 0, 'l', 'analyze');
        return t.analyze(l);
      },
    },
    constructorSignatures: {
      '': 'IntegerLiteral(int operant1)',
    },
    methodSignatures: {
      'generate': 'SqlString generate(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
      'indent': 'String indent(int i)',
      'analyze': 'String analyze(int l)',
    },
    getterSignatures: {
      'returnType': 'Type get returnType',
      'operant1': 'int get operant1',
    },
    setterSignatures: {
      'returnType': 'set returnType(Type value)',
      'operant1': 'set operant1(int value)',
    },
  );
}

// =============================================================================
// DoubleLiteral Bridge
// =============================================================================

BridgedClass _createDoubleLiteralBridge() {
  return BridgedClass(
    nativeType: DoubleLiteral,
    name: 'DoubleLiteral',
    isAssignable: (v) => v is DoubleLiteral,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'DoubleLiteral');
        final operant1 = D4.getRequiredArg<double>(positional, 0, 'operant1', 'DoubleLiteral');
        return DoubleLiteral(operant1);
      },
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<DoubleLiteral>(target, 'DoubleLiteral').returnType,
      'operant1': (visitor, target) => D4.validateTarget<DoubleLiteral>(target, 'DoubleLiteral').operant1,
    },
    setters: {
      'returnType': (visitor, target, value) => 
        D4.validateTarget<DoubleLiteral>(target, 'DoubleLiteral').returnType = D4.extractBridgedArg<Type>(value, 'returnType'),
      'operant1': (visitor, target, value) => 
        D4.validateTarget<DoubleLiteral>(target, 'DoubleLiteral').operant1 = D4.extractBridgedArg<double>(value, 'operant1'),
    },
    methods: {
      'generate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DoubleLiteral>(target, 'DoubleLiteral');
        D4.requireMinArgs(positional, 1, 'generate');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generate');
        return t.generate(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DoubleLiteral>(target, 'DoubleLiteral');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DoubleLiteral>(target, 'DoubleLiteral');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DoubleLiteral>(target, 'DoubleLiteral');
        return t.toString();
      },
      'indent': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DoubleLiteral>(target, 'DoubleLiteral');
        D4.requireMinArgs(positional, 1, 'indent');
        final i = D4.getRequiredArg<int>(positional, 0, 'i', 'indent');
        return t.indent(i);
      },
      'analyze': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DoubleLiteral>(target, 'DoubleLiteral');
        D4.requireMinArgs(positional, 1, 'analyze');
        final l = D4.getRequiredArg<int>(positional, 0, 'l', 'analyze');
        return t.analyze(l);
      },
    },
    constructorSignatures: {
      '': 'DoubleLiteral(double operant1)',
    },
    methodSignatures: {
      'generate': 'SqlString generate(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
      'indent': 'String indent(int i)',
      'analyze': 'String analyze(int l)',
    },
    getterSignatures: {
      'returnType': 'Type get returnType',
      'operant1': 'double get operant1',
    },
    setterSignatures: {
      'returnType': 'set returnType(Type value)',
      'operant1': 'set operant1(double value)',
    },
  );
}

// =============================================================================
// BoolLiteral Bridge
// =============================================================================

BridgedClass _createBoolLiteralBridge() {
  return BridgedClass(
    nativeType: BoolLiteral,
    name: 'BoolLiteral',
    isAssignable: (v) => v is BoolLiteral,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'BoolLiteral');
        final operant1 = D4.getRequiredArg<bool>(positional, 0, 'operant1', 'BoolLiteral');
        return BoolLiteral(operant1);
      },
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<BoolLiteral>(target, 'BoolLiteral').returnType,
      'operant1': (visitor, target) => D4.validateTarget<BoolLiteral>(target, 'BoolLiteral').operant1,
    },
    setters: {
      'returnType': (visitor, target, value) => 
        D4.validateTarget<BoolLiteral>(target, 'BoolLiteral').returnType = D4.extractBridgedArg<Type>(value, 'returnType'),
      'operant1': (visitor, target, value) => 
        D4.validateTarget<BoolLiteral>(target, 'BoolLiteral').operant1 = D4.extractBridgedArg<bool>(value, 'operant1'),
    },
    methods: {
      'generate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<BoolLiteral>(target, 'BoolLiteral');
        D4.requireMinArgs(positional, 1, 'generate');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generate');
        return t.generate(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<BoolLiteral>(target, 'BoolLiteral');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<BoolLiteral>(target, 'BoolLiteral');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<BoolLiteral>(target, 'BoolLiteral');
        return t.toString();
      },
      'indent': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<BoolLiteral>(target, 'BoolLiteral');
        D4.requireMinArgs(positional, 1, 'indent');
        final i = D4.getRequiredArg<int>(positional, 0, 'i', 'indent');
        return t.indent(i);
      },
      'analyze': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<BoolLiteral>(target, 'BoolLiteral');
        D4.requireMinArgs(positional, 1, 'analyze');
        final l = D4.getRequiredArg<int>(positional, 0, 'l', 'analyze');
        return t.analyze(l);
      },
    },
    constructorSignatures: {
      '': 'BoolLiteral(bool operant1)',
    },
    methodSignatures: {
      'generate': 'SqlString generate(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
      'indent': 'String indent(int i)',
      'analyze': 'String analyze(int l)',
    },
    getterSignatures: {
      'returnType': 'Type get returnType',
      'operant1': 'bool get operant1',
    },
    setterSignatures: {
      'returnType': 'set returnType(Type value)',
      'operant1': 'set operant1(bool value)',
    },
  );
}

// =============================================================================
// DateTimeLiteral Bridge
// =============================================================================

BridgedClass _createDateTimeLiteralBridge() {
  return BridgedClass(
    nativeType: DateTimeLiteral,
    name: 'DateTimeLiteral',
    isAssignable: (v) => v is DateTimeLiteral,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'DateTimeLiteral');
        final operant1 = D4.getRequiredArg<DateTime>(positional, 0, 'operant1', 'DateTimeLiteral');
        return DateTimeLiteral(operant1);
      },
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<DateTimeLiteral>(target, 'DateTimeLiteral').returnType,
      'operant1': (visitor, target) => D4.validateTarget<DateTimeLiteral>(target, 'DateTimeLiteral').operant1,
    },
    setters: {
      'returnType': (visitor, target, value) => 
        D4.validateTarget<DateTimeLiteral>(target, 'DateTimeLiteral').returnType = D4.extractBridgedArg<Type>(value, 'returnType'),
      'operant1': (visitor, target, value) => 
        D4.validateTarget<DateTimeLiteral>(target, 'DateTimeLiteral').operant1 = D4.extractBridgedArg<DateTime>(value, 'operant1'),
    },
    methods: {
      'generate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DateTimeLiteral>(target, 'DateTimeLiteral');
        D4.requireMinArgs(positional, 1, 'generate');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generate');
        return t.generate(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DateTimeLiteral>(target, 'DateTimeLiteral');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DateTimeLiteral>(target, 'DateTimeLiteral');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DateTimeLiteral>(target, 'DateTimeLiteral');
        return t.toString();
      },
      'indent': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DateTimeLiteral>(target, 'DateTimeLiteral');
        D4.requireMinArgs(positional, 1, 'indent');
        final i = D4.getRequiredArg<int>(positional, 0, 'i', 'indent');
        return t.indent(i);
      },
      'analyze': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DateTimeLiteral>(target, 'DateTimeLiteral');
        D4.requireMinArgs(positional, 1, 'analyze');
        final l = D4.getRequiredArg<int>(positional, 0, 'l', 'analyze');
        return t.analyze(l);
      },
    },
    constructorSignatures: {
      '': 'DateTimeLiteral(DateTime operant1)',
    },
    methodSignatures: {
      'generate': 'SqlString generate(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
      'indent': 'String indent(int i)',
      'analyze': 'String analyze(int l)',
    },
    getterSignatures: {
      'returnType': 'Type get returnType',
      'operant1': 'DateTime get operant1',
    },
    setterSignatures: {
      'returnType': 'set returnType(Type value)',
      'operant1': 'set operant1(DateTime value)',
    },
  );
}

// =============================================================================
// DateLiteral Bridge
// =============================================================================

BridgedClass _createDateLiteralBridge() {
  return BridgedClass(
    nativeType: DateLiteral,
    name: 'DateLiteral',
    isAssignable: (v) => v is DateLiteral,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'DateLiteral');
        final operant1 = D4.getRequiredArg<DateTime>(positional, 0, 'operant1', 'DateLiteral');
        return DateLiteral(operant1);
      },
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<DateLiteral>(target, 'DateLiteral').returnType,
      'operant1': (visitor, target) => D4.validateTarget<DateLiteral>(target, 'DateLiteral').operant1,
    },
    setters: {
      'returnType': (visitor, target, value) => 
        D4.validateTarget<DateLiteral>(target, 'DateLiteral').returnType = D4.extractBridgedArg<Type>(value, 'returnType'),
      'operant1': (visitor, target, value) => 
        D4.validateTarget<DateLiteral>(target, 'DateLiteral').operant1 = D4.extractBridgedArg<DateTime>(value, 'operant1'),
    },
    methods: {
      'generate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DateLiteral>(target, 'DateLiteral');
        D4.requireMinArgs(positional, 1, 'generate');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generate');
        return t.generate(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DateLiteral>(target, 'DateLiteral');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DateLiteral>(target, 'DateLiteral');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DateLiteral>(target, 'DateLiteral');
        return t.toString();
      },
      'indent': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DateLiteral>(target, 'DateLiteral');
        D4.requireMinArgs(positional, 1, 'indent');
        final i = D4.getRequiredArg<int>(positional, 0, 'i', 'indent');
        return t.indent(i);
      },
      'analyze': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<DateLiteral>(target, 'DateLiteral');
        D4.requireMinArgs(positional, 1, 'analyze');
        final l = D4.getRequiredArg<int>(positional, 0, 'l', 'analyze');
        return t.analyze(l);
      },
    },
    constructorSignatures: {
      '': 'DateLiteral(DateTime operant1)',
    },
    methodSignatures: {
      'generate': 'SqlString generate(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
      'indent': 'String indent(int i)',
      'analyze': 'String analyze(int l)',
    },
    getterSignatures: {
      'returnType': 'Type get returnType',
      'operant1': 'DateTime get operant1',
    },
    setterSignatures: {
      'returnType': 'set returnType(Type value)',
      'operant1': 'set operant1(DateTime value)',
    },
  );
}

// =============================================================================
// Not Bridge
// =============================================================================

BridgedClass _createNotBridge() {
  return BridgedClass(
    nativeType: Not,
    name: 'Not',
    isAssignable: (v) => v is Not,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'Not');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbBool>>(positional, 0, 'operant1', 'Not');
        return Not(operant1);
      },
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<Not>(target, 'Not').returnType,
      'operant1': (visitor, target) => D4.validateTarget<Not>(target, 'Not').operant1,
    },
    setters: {
      'returnType': (visitor, target, value) => 
        D4.validateTarget<Not>(target, 'Not').returnType = D4.extractBridgedArg<Type>(value, 'returnType'),
      'operant1': (visitor, target, value) => 
        D4.validateTarget<Not>(target, 'Not').operant1 = D4.extractBridgedArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbBool>>(value, 'operant1'),
    },
    methods: {
      'generate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Not>(target, 'Not');
        D4.requireMinArgs(positional, 1, 'generate');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generate');
        return t.generate(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Not>(target, 'Not');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Not>(target, 'Not');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Not>(target, 'Not');
        return t.toString();
      },
      'indent': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Not>(target, 'Not');
        D4.requireMinArgs(positional, 1, 'indent');
        final i = D4.getRequiredArg<int>(positional, 0, 'i', 'indent');
        return t.indent(i);
      },
      'analyze': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Not>(target, 'Not');
        D4.requireMinArgs(positional, 1, 'analyze');
        final l = D4.getRequiredArg<int>(positional, 0, 'l', 'analyze');
        return t.analyze(l);
      },
    },
    constructorSignatures: {
      '': 'Not(TomOperator<TomDbBool> operant1)',
    },
    methodSignatures: {
      'generate': 'SqlString generate(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
      'indent': 'String indent(int i)',
      'analyze': 'String analyze(int l)',
    },
    getterSignatures: {
      'returnType': 'Type get returnType',
      'operant1': 'TomOperator<TomDbBool> get operant1',
    },
    setterSignatures: {
      'returnType': 'set returnType(Type value)',
      'operant1': 'set operant1(TomOperator<TomDbBool> value)',
    },
  );
}

// =============================================================================
// IsNull Bridge
// =============================================================================

BridgedClass _createIsNullBridge() {
  return BridgedClass(
    nativeType: IsNull,
    name: 'IsNull',
    isAssignable: (v) => v is IsNull,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'IsNull');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'IsNull');
        return IsNull(operant1);
      },
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<IsNull>(target, 'IsNull').returnType,
      'operant1': (visitor, target) => D4.validateTarget<IsNull>(target, 'IsNull').operant1,
    },
    setters: {
      'returnType': (visitor, target, value) => 
        D4.validateTarget<IsNull>(target, 'IsNull').returnType = D4.extractBridgedArg<Type>(value, 'returnType'),
      'operant1': (visitor, target, value) => 
        D4.validateTarget<IsNull>(target, 'IsNull').operant1 = D4.extractBridgedArg<$tom_core_server_8.TomOperator<dynamic>>(value, 'operant1'),
    },
    methods: {
      'generate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IsNull>(target, 'IsNull');
        D4.requireMinArgs(positional, 1, 'generate');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generate');
        return t.generate(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IsNull>(target, 'IsNull');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IsNull>(target, 'IsNull');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IsNull>(target, 'IsNull');
        return t.toString();
      },
      'indent': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IsNull>(target, 'IsNull');
        D4.requireMinArgs(positional, 1, 'indent');
        final i = D4.getRequiredArg<int>(positional, 0, 'i', 'indent');
        return t.indent(i);
      },
      'analyze': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IsNull>(target, 'IsNull');
        D4.requireMinArgs(positional, 1, 'analyze');
        final l = D4.getRequiredArg<int>(positional, 0, 'l', 'analyze');
        return t.analyze(l);
      },
    },
    constructorSignatures: {
      '': 'IsNull(TomOperator<T> operant1)',
    },
    methodSignatures: {
      'generate': 'SqlString generate(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
      'indent': 'String indent(int i)',
      'analyze': 'String analyze(int l)',
    },
    getterSignatures: {
      'returnType': 'Type get returnType',
      'operant1': 'TomOperator<T> get operant1',
    },
    setterSignatures: {
      'returnType': 'set returnType(Type value)',
      'operant1': 'set operant1(TomOperator<T> value)',
    },
  );
}

// =============================================================================
// IsNotNull Bridge
// =============================================================================

BridgedClass _createIsNotNullBridge() {
  return BridgedClass(
    nativeType: IsNotNull,
    name: 'IsNotNull',
    isAssignable: (v) => v is IsNotNull,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'IsNotNull');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'IsNotNull');
        return IsNotNull(operant1);
      },
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<IsNotNull>(target, 'IsNotNull').returnType,
      'operant1': (visitor, target) => D4.validateTarget<IsNotNull>(target, 'IsNotNull').operant1,
    },
    setters: {
      'returnType': (visitor, target, value) => 
        D4.validateTarget<IsNotNull>(target, 'IsNotNull').returnType = D4.extractBridgedArg<Type>(value, 'returnType'),
      'operant1': (visitor, target, value) => 
        D4.validateTarget<IsNotNull>(target, 'IsNotNull').operant1 = D4.extractBridgedArg<$tom_core_server_8.TomOperator<dynamic>>(value, 'operant1'),
    },
    methods: {
      'generate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IsNotNull>(target, 'IsNotNull');
        D4.requireMinArgs(positional, 1, 'generate');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generate');
        return t.generate(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IsNotNull>(target, 'IsNotNull');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IsNotNull>(target, 'IsNotNull');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IsNotNull>(target, 'IsNotNull');
        return t.toString();
      },
      'indent': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IsNotNull>(target, 'IsNotNull');
        D4.requireMinArgs(positional, 1, 'indent');
        final i = D4.getRequiredArg<int>(positional, 0, 'i', 'indent');
        return t.indent(i);
      },
      'analyze': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IsNotNull>(target, 'IsNotNull');
        D4.requireMinArgs(positional, 1, 'analyze');
        final l = D4.getRequiredArg<int>(positional, 0, 'l', 'analyze');
        return t.analyze(l);
      },
    },
    constructorSignatures: {
      '': 'IsNotNull(TomOperator<T> operant1)',
    },
    methodSignatures: {
      'generate': 'SqlString generate(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
      'indent': 'String indent(int i)',
      'analyze': 'String analyze(int l)',
    },
    getterSignatures: {
      'returnType': 'Type get returnType',
      'operant1': 'TomOperator<T> get operant1',
    },
    setterSignatures: {
      'returnType': 'set returnType(Type value)',
      'operant1': 'set operant1(TomOperator<T> value)',
    },
  );
}

// =============================================================================
// TomBinaryOperator Bridge
// =============================================================================

BridgedClass _createTomBinaryOperatorBridge() {
  return BridgedClass(
    nativeType: TomBinaryOperator,
    name: 'TomBinaryOperator',
    isAssignable: (v) => v is TomBinaryOperator,
    constructors: {
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<TomBinaryOperator>(target, 'TomBinaryOperator').returnType,
      'operant1': (visitor, target) => D4.validateTarget<TomBinaryOperator>(target, 'TomBinaryOperator').operant1,
      'operant2': (visitor, target) => D4.validateTarget<TomBinaryOperator>(target, 'TomBinaryOperator').operant2,
    },
    setters: {
      'returnType': (visitor, target, value) => 
        D4.validateTarget<TomBinaryOperator>(target, 'TomBinaryOperator').returnType = D4.extractBridgedArg<Type>(value, 'returnType'),
      'operant1': (visitor, target, value) => 
        D4.validateTarget<TomBinaryOperator>(target, 'TomBinaryOperator').operant1 = value as dynamic,
      'operant2': (visitor, target, value) => 
        D4.validateTarget<TomBinaryOperator>(target, 'TomBinaryOperator').operant2 = value as dynamic,
    },
    methods: {
      'generate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomBinaryOperator>(target, 'TomBinaryOperator');
        D4.requireMinArgs(positional, 1, 'generate');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generate');
        return t.generate(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomBinaryOperator>(target, 'TomBinaryOperator');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomBinaryOperator>(target, 'TomBinaryOperator');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomBinaryOperator>(target, 'TomBinaryOperator');
        return t.toString();
      },
      'indent': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomBinaryOperator>(target, 'TomBinaryOperator');
        D4.requireMinArgs(positional, 1, 'indent');
        final i = D4.getRequiredArg<int>(positional, 0, 'i', 'indent');
        return t.indent(i);
      },
      'analyze': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomBinaryOperator>(target, 'TomBinaryOperator');
        D4.requireMinArgs(positional, 1, 'analyze');
        final l = D4.getRequiredArg<int>(positional, 0, 'l', 'analyze');
        return t.analyze(l);
      },
    },
    methodSignatures: {
      'generate': 'String generate(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
      'indent': 'String indent(int i)',
      'analyze': 'String analyze(int l)',
    },
    getterSignatures: {
      'returnType': 'Type get returnType',
      'operant1': 'T1 get operant1',
      'operant2': 'T2 get operant2',
    },
    setterSignatures: {
      'returnType': 'set returnType(Type value)',
      'operant1': 'set operant1(dynamic value)',
      'operant2': 'set operant2(dynamic value)',
    },
  );
}

// =============================================================================
// And Bridge
// =============================================================================

BridgedClass _createAndBridge() {
  return BridgedClass(
    nativeType: And,
    name: 'And',
    isAssignable: (v) => v is And,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'And');
        if (positional.isEmpty) {
          throw ArgumentError('And: Missing required argument "operant1" at position 0');
        }
        final operant1 = D4.coerceList<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbBool>>(positional[0], 'operant1');
        return And(operant1);
      },
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<And>(target, 'And').returnType,
      'operant1': (visitor, target) => D4.validateTarget<And>(target, 'And').operant1,
    },
    setters: {
      'returnType': (visitor, target, value) => 
        D4.validateTarget<And>(target, 'And').returnType = D4.extractBridgedArg<Type>(value, 'returnType'),
      'operant1': (visitor, target, value) => 
        D4.validateTarget<And>(target, 'And').operant1 = (value as List).cast<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbBool>>().toList(),
    },
    methods: {
      'generate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<And>(target, 'And');
        D4.requireMinArgs(positional, 1, 'generate');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generate');
        return t.generate(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<And>(target, 'And');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<And>(target, 'And');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<And>(target, 'And');
        return t.toString();
      },
      'indent': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<And>(target, 'And');
        D4.requireMinArgs(positional, 1, 'indent');
        final i = D4.getRequiredArg<int>(positional, 0, 'i', 'indent');
        return t.indent(i);
      },
      'analyze': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<And>(target, 'And');
        D4.requireMinArgs(positional, 1, 'analyze');
        final l = D4.getRequiredArg<int>(positional, 0, 'l', 'analyze');
        return t.analyze(l);
      },
    },
    constructorSignatures: {
      '': 'And(List<TomOperator<TomDbBool>> operant1)',
    },
    methodSignatures: {
      'generate': 'SqlString generate(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
      'indent': 'String indent(int i)',
      'analyze': 'String analyze(int l)',
    },
    getterSignatures: {
      'returnType': 'Type get returnType',
      'operant1': 'List<TomOperator<TomDbBool>> get operant1',
    },
    setterSignatures: {
      'returnType': 'set returnType(Type value)',
      'operant1': 'set operant1(List<TomOperator<TomDbBool>> value)',
    },
  );
}

// =============================================================================
// Or Bridge
// =============================================================================

BridgedClass _createOrBridge() {
  return BridgedClass(
    nativeType: Or,
    name: 'Or',
    isAssignable: (v) => v is Or,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'Or');
        if (positional.isEmpty) {
          throw ArgumentError('Or: Missing required argument "operant1" at position 0');
        }
        final operant1 = D4.coerceList<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbBool>>(positional[0], 'operant1');
        return Or(operant1);
      },
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<Or>(target, 'Or').returnType,
      'operant1': (visitor, target) => D4.validateTarget<Or>(target, 'Or').operant1,
    },
    setters: {
      'returnType': (visitor, target, value) => 
        D4.validateTarget<Or>(target, 'Or').returnType = D4.extractBridgedArg<Type>(value, 'returnType'),
      'operant1': (visitor, target, value) => 
        D4.validateTarget<Or>(target, 'Or').operant1 = (value as List).cast<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbBool>>().toList(),
    },
    methods: {
      'generate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Or>(target, 'Or');
        D4.requireMinArgs(positional, 1, 'generate');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generate');
        return t.generate(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Or>(target, 'Or');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Or>(target, 'Or');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Or>(target, 'Or');
        return t.toString();
      },
      'indent': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Or>(target, 'Or');
        D4.requireMinArgs(positional, 1, 'indent');
        final i = D4.getRequiredArg<int>(positional, 0, 'i', 'indent');
        return t.indent(i);
      },
      'analyze': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Or>(target, 'Or');
        D4.requireMinArgs(positional, 1, 'analyze');
        final l = D4.getRequiredArg<int>(positional, 0, 'l', 'analyze');
        return t.analyze(l);
      },
    },
    constructorSignatures: {
      '': 'Or(List<TomOperator<TomDbBool>> operant1)',
    },
    methodSignatures: {
      'generate': 'SqlString generate(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
      'indent': 'String indent(int i)',
      'analyze': 'String analyze(int l)',
    },
    getterSignatures: {
      'returnType': 'Type get returnType',
      'operant1': 'List<TomOperator<TomDbBool>> get operant1',
    },
    setterSignatures: {
      'returnType': 'set returnType(Type value)',
      'operant1': 'set operant1(List<TomOperator<TomDbBool>> value)',
    },
  );
}

// =============================================================================
// Eq Bridge
// =============================================================================

BridgedClass _createEqBridge() {
  return BridgedClass(
    nativeType: Eq,
    name: 'Eq',
    isAssignable: (v) => v is Eq,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'Eq');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'Eq');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'Eq');
        return Eq(operant1, operant2);
      },
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<Eq>(target, 'Eq').returnType,
      'operant1': (visitor, target) => D4.validateTarget<Eq>(target, 'Eq').operant1,
      'operant2': (visitor, target) => D4.validateTarget<Eq>(target, 'Eq').operant2,
    },
    setters: {
      'returnType': (visitor, target, value) => 
        D4.validateTarget<Eq>(target, 'Eq').returnType = D4.extractBridgedArg<Type>(value, 'returnType'),
      'operant1': (visitor, target, value) => 
        D4.validateTarget<Eq>(target, 'Eq').operant1 = D4.extractBridgedArg<$tom_core_server_8.TomOperator<dynamic>>(value, 'operant1'),
      'operant2': (visitor, target, value) => 
        D4.validateTarget<Eq>(target, 'Eq').operant2 = D4.extractBridgedArg<$tom_core_server_8.TomOperator<dynamic>>(value, 'operant2'),
    },
    methods: {
      'generate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Eq>(target, 'Eq');
        D4.requireMinArgs(positional, 1, 'generate');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generate');
        return t.generate(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Eq>(target, 'Eq');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Eq>(target, 'Eq');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Eq>(target, 'Eq');
        return t.toString();
      },
      'indent': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Eq>(target, 'Eq');
        D4.requireMinArgs(positional, 1, 'indent');
        final i = D4.getRequiredArg<int>(positional, 0, 'i', 'indent');
        return t.indent(i);
      },
      'analyze': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Eq>(target, 'Eq');
        D4.requireMinArgs(positional, 1, 'analyze');
        final l = D4.getRequiredArg<int>(positional, 0, 'l', 'analyze');
        return t.analyze(l);
      },
    },
    constructorSignatures: {
      '': 'Eq(TomOperator<T> operant1, TomOperator<T> operant2)',
    },
    methodSignatures: {
      'generate': 'SqlString generate(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
      'indent': 'String indent(int i)',
      'analyze': 'String analyze(int l)',
    },
    getterSignatures: {
      'returnType': 'Type get returnType',
      'operant1': 'TomOperator<T> get operant1',
      'operant2': 'TomOperator<T> get operant2',
    },
    setterSignatures: {
      'returnType': 'set returnType(Type value)',
      'operant1': 'set operant1(TomOperator<T> value)',
      'operant2': 'set operant2(TomOperator<T> value)',
    },
  );
}

// =============================================================================
// Neq Bridge
// =============================================================================

BridgedClass _createNeqBridge() {
  return BridgedClass(
    nativeType: Neq,
    name: 'Neq',
    isAssignable: (v) => v is Neq,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'Neq');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'Neq');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'Neq');
        return Neq(operant1, operant2);
      },
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<Neq>(target, 'Neq').returnType,
      'operant1': (visitor, target) => D4.validateTarget<Neq>(target, 'Neq').operant1,
      'operant2': (visitor, target) => D4.validateTarget<Neq>(target, 'Neq').operant2,
    },
    setters: {
      'returnType': (visitor, target, value) => 
        D4.validateTarget<Neq>(target, 'Neq').returnType = D4.extractBridgedArg<Type>(value, 'returnType'),
      'operant1': (visitor, target, value) => 
        D4.validateTarget<Neq>(target, 'Neq').operant1 = D4.extractBridgedArg<$tom_core_server_8.TomOperator<dynamic>>(value, 'operant1'),
      'operant2': (visitor, target, value) => 
        D4.validateTarget<Neq>(target, 'Neq').operant2 = D4.extractBridgedArg<$tom_core_server_8.TomOperator<dynamic>>(value, 'operant2'),
    },
    methods: {
      'generate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Neq>(target, 'Neq');
        D4.requireMinArgs(positional, 1, 'generate');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generate');
        return t.generate(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Neq>(target, 'Neq');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Neq>(target, 'Neq');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Neq>(target, 'Neq');
        return t.toString();
      },
      'indent': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Neq>(target, 'Neq');
        D4.requireMinArgs(positional, 1, 'indent');
        final i = D4.getRequiredArg<int>(positional, 0, 'i', 'indent');
        return t.indent(i);
      },
      'analyze': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Neq>(target, 'Neq');
        D4.requireMinArgs(positional, 1, 'analyze');
        final l = D4.getRequiredArg<int>(positional, 0, 'l', 'analyze');
        return t.analyze(l);
      },
    },
    constructorSignatures: {
      '': 'Neq(TomOperator<T> operant1, TomOperator<T> operant2)',
    },
    methodSignatures: {
      'generate': 'SqlString generate(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
      'indent': 'String indent(int i)',
      'analyze': 'String analyze(int l)',
    },
    getterSignatures: {
      'returnType': 'Type get returnType',
      'operant1': 'TomOperator<T> get operant1',
      'operant2': 'TomOperator<T> get operant2',
    },
    setterSignatures: {
      'returnType': 'set returnType(Type value)',
      'operant1': 'set operant1(TomOperator<T> value)',
      'operant2': 'set operant2(TomOperator<T> value)',
    },
  );
}

// =============================================================================
// Lt Bridge
// =============================================================================

BridgedClass _createLtBridge() {
  return BridgedClass(
    nativeType: Lt,
    name: 'Lt',
    isAssignable: (v) => v is Lt,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'Lt');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'Lt');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'Lt');
        return Lt(operant1, operant2);
      },
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<Lt>(target, 'Lt').returnType,
      'operant1': (visitor, target) => D4.validateTarget<Lt>(target, 'Lt').operant1,
      'operant2': (visitor, target) => D4.validateTarget<Lt>(target, 'Lt').operant2,
    },
    setters: {
      'returnType': (visitor, target, value) => 
        D4.validateTarget<Lt>(target, 'Lt').returnType = D4.extractBridgedArg<Type>(value, 'returnType'),
      'operant1': (visitor, target, value) => 
        D4.validateTarget<Lt>(target, 'Lt').operant1 = D4.extractBridgedArg<$tom_core_server_8.TomOperator<dynamic>>(value, 'operant1'),
      'operant2': (visitor, target, value) => 
        D4.validateTarget<Lt>(target, 'Lt').operant2 = D4.extractBridgedArg<$tom_core_server_8.TomOperator<dynamic>>(value, 'operant2'),
    },
    methods: {
      'generate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Lt>(target, 'Lt');
        D4.requireMinArgs(positional, 1, 'generate');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generate');
        return t.generate(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Lt>(target, 'Lt');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Lt>(target, 'Lt');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Lt>(target, 'Lt');
        return t.toString();
      },
      'indent': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Lt>(target, 'Lt');
        D4.requireMinArgs(positional, 1, 'indent');
        final i = D4.getRequiredArg<int>(positional, 0, 'i', 'indent');
        return t.indent(i);
      },
      'analyze': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Lt>(target, 'Lt');
        D4.requireMinArgs(positional, 1, 'analyze');
        final l = D4.getRequiredArg<int>(positional, 0, 'l', 'analyze');
        return t.analyze(l);
      },
    },
    constructorSignatures: {
      '': 'Lt(TomOperator<T> operant1, TomOperator<T> operant2)',
    },
    methodSignatures: {
      'generate': 'SqlString generate(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
      'indent': 'String indent(int i)',
      'analyze': 'String analyze(int l)',
    },
    getterSignatures: {
      'returnType': 'Type get returnType',
      'operant1': 'TomOperator<T> get operant1',
      'operant2': 'TomOperator<T> get operant2',
    },
    setterSignatures: {
      'returnType': 'set returnType(Type value)',
      'operant1': 'set operant1(TomOperator<T> value)',
      'operant2': 'set operant2(TomOperator<T> value)',
    },
  );
}

// =============================================================================
// Gt Bridge
// =============================================================================

BridgedClass _createGtBridge() {
  return BridgedClass(
    nativeType: Gt,
    name: 'Gt',
    isAssignable: (v) => v is Gt,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'Gt');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'Gt');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'Gt');
        return Gt(operant1, operant2);
      },
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<Gt>(target, 'Gt').returnType,
      'operant1': (visitor, target) => D4.validateTarget<Gt>(target, 'Gt').operant1,
      'operant2': (visitor, target) => D4.validateTarget<Gt>(target, 'Gt').operant2,
    },
    setters: {
      'returnType': (visitor, target, value) => 
        D4.validateTarget<Gt>(target, 'Gt').returnType = D4.extractBridgedArg<Type>(value, 'returnType'),
      'operant1': (visitor, target, value) => 
        D4.validateTarget<Gt>(target, 'Gt').operant1 = D4.extractBridgedArg<$tom_core_server_8.TomOperator<dynamic>>(value, 'operant1'),
      'operant2': (visitor, target, value) => 
        D4.validateTarget<Gt>(target, 'Gt').operant2 = D4.extractBridgedArg<$tom_core_server_8.TomOperator<dynamic>>(value, 'operant2'),
    },
    methods: {
      'generate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Gt>(target, 'Gt');
        D4.requireMinArgs(positional, 1, 'generate');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generate');
        return t.generate(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Gt>(target, 'Gt');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Gt>(target, 'Gt');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Gt>(target, 'Gt');
        return t.toString();
      },
      'indent': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Gt>(target, 'Gt');
        D4.requireMinArgs(positional, 1, 'indent');
        final i = D4.getRequiredArg<int>(positional, 0, 'i', 'indent');
        return t.indent(i);
      },
      'analyze': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Gt>(target, 'Gt');
        D4.requireMinArgs(positional, 1, 'analyze');
        final l = D4.getRequiredArg<int>(positional, 0, 'l', 'analyze');
        return t.analyze(l);
      },
    },
    constructorSignatures: {
      '': 'Gt(TomOperator<T> operant1, TomOperator<T> operant2)',
    },
    methodSignatures: {
      'generate': 'SqlString generate(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
      'indent': 'String indent(int i)',
      'analyze': 'String analyze(int l)',
    },
    getterSignatures: {
      'returnType': 'Type get returnType',
      'operant1': 'TomOperator<T> get operant1',
      'operant2': 'TomOperator<T> get operant2',
    },
    setterSignatures: {
      'returnType': 'set returnType(Type value)',
      'operant1': 'set operant1(TomOperator<T> value)',
      'operant2': 'set operant2(TomOperator<T> value)',
    },
  );
}

// =============================================================================
// Lte Bridge
// =============================================================================

BridgedClass _createLteBridge() {
  return BridgedClass(
    nativeType: Lte,
    name: 'Lte',
    isAssignable: (v) => v is Lte,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'Lte');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'Lte');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'Lte');
        return Lte(operant1, operant2);
      },
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<Lte>(target, 'Lte').returnType,
      'operant1': (visitor, target) => D4.validateTarget<Lte>(target, 'Lte').operant1,
      'operant2': (visitor, target) => D4.validateTarget<Lte>(target, 'Lte').operant2,
    },
    setters: {
      'returnType': (visitor, target, value) => 
        D4.validateTarget<Lte>(target, 'Lte').returnType = D4.extractBridgedArg<Type>(value, 'returnType'),
      'operant1': (visitor, target, value) => 
        D4.validateTarget<Lte>(target, 'Lte').operant1 = D4.extractBridgedArg<$tom_core_server_8.TomOperator<dynamic>>(value, 'operant1'),
      'operant2': (visitor, target, value) => 
        D4.validateTarget<Lte>(target, 'Lte').operant2 = D4.extractBridgedArg<$tom_core_server_8.TomOperator<dynamic>>(value, 'operant2'),
    },
    methods: {
      'generate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Lte>(target, 'Lte');
        D4.requireMinArgs(positional, 1, 'generate');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generate');
        return t.generate(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Lte>(target, 'Lte');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Lte>(target, 'Lte');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Lte>(target, 'Lte');
        return t.toString();
      },
      'indent': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Lte>(target, 'Lte');
        D4.requireMinArgs(positional, 1, 'indent');
        final i = D4.getRequiredArg<int>(positional, 0, 'i', 'indent');
        return t.indent(i);
      },
      'analyze': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Lte>(target, 'Lte');
        D4.requireMinArgs(positional, 1, 'analyze');
        final l = D4.getRequiredArg<int>(positional, 0, 'l', 'analyze');
        return t.analyze(l);
      },
    },
    constructorSignatures: {
      '': 'Lte(TomOperator<T> operant1, TomOperator<T> operant2)',
    },
    methodSignatures: {
      'generate': 'SqlString generate(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
      'indent': 'String indent(int i)',
      'analyze': 'String analyze(int l)',
    },
    getterSignatures: {
      'returnType': 'Type get returnType',
      'operant1': 'TomOperator<T> get operant1',
      'operant2': 'TomOperator<T> get operant2',
    },
    setterSignatures: {
      'returnType': 'set returnType(Type value)',
      'operant1': 'set operant1(TomOperator<T> value)',
      'operant2': 'set operant2(TomOperator<T> value)',
    },
  );
}

// =============================================================================
// Gte Bridge
// =============================================================================

BridgedClass _createGteBridge() {
  return BridgedClass(
    nativeType: Gte,
    name: 'Gte',
    isAssignable: (v) => v is Gte,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'Gte');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'Gte');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'Gte');
        return Gte(operant1, operant2);
      },
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<Gte>(target, 'Gte').returnType,
      'operant1': (visitor, target) => D4.validateTarget<Gte>(target, 'Gte').operant1,
      'operant2': (visitor, target) => D4.validateTarget<Gte>(target, 'Gte').operant2,
    },
    setters: {
      'returnType': (visitor, target, value) => 
        D4.validateTarget<Gte>(target, 'Gte').returnType = D4.extractBridgedArg<Type>(value, 'returnType'),
      'operant1': (visitor, target, value) => 
        D4.validateTarget<Gte>(target, 'Gte').operant1 = D4.extractBridgedArg<$tom_core_server_8.TomOperator<dynamic>>(value, 'operant1'),
      'operant2': (visitor, target, value) => 
        D4.validateTarget<Gte>(target, 'Gte').operant2 = D4.extractBridgedArg<$tom_core_server_8.TomOperator<dynamic>>(value, 'operant2'),
    },
    methods: {
      'generate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Gte>(target, 'Gte');
        D4.requireMinArgs(positional, 1, 'generate');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generate');
        return t.generate(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Gte>(target, 'Gte');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Gte>(target, 'Gte');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Gte>(target, 'Gte');
        return t.toString();
      },
      'indent': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Gte>(target, 'Gte');
        D4.requireMinArgs(positional, 1, 'indent');
        final i = D4.getRequiredArg<int>(positional, 0, 'i', 'indent');
        return t.indent(i);
      },
      'analyze': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Gte>(target, 'Gte');
        D4.requireMinArgs(positional, 1, 'analyze');
        final l = D4.getRequiredArg<int>(positional, 0, 'l', 'analyze');
        return t.analyze(l);
      },
    },
    constructorSignatures: {
      '': 'Gte(TomOperator<T> operant1, TomOperator<T> operant2)',
    },
    methodSignatures: {
      'generate': 'SqlString generate(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
      'indent': 'String indent(int i)',
      'analyze': 'String analyze(int l)',
    },
    getterSignatures: {
      'returnType': 'Type get returnType',
      'operant1': 'TomOperator<T> get operant1',
      'operant2': 'TomOperator<T> get operant2',
    },
    setterSignatures: {
      'returnType': 'set returnType(Type value)',
      'operant1': 'set operant1(TomOperator<T> value)',
      'operant2': 'set operant2(TomOperator<T> value)',
    },
  );
}

// =============================================================================
// Like Bridge
// =============================================================================

BridgedClass _createLikeBridge() {
  return BridgedClass(
    nativeType: Like,
    name: 'Like',
    isAssignable: (v) => v is Like,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'Like');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 0, 'operant1', 'Like');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 1, 'operant2', 'Like');
        return Like(operant1, operant2);
      },
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<Like>(target, 'Like').returnType,
      'operant1': (visitor, target) => D4.validateTarget<Like>(target, 'Like').operant1,
      'operant2': (visitor, target) => D4.validateTarget<Like>(target, 'Like').operant2,
    },
    setters: {
      'returnType': (visitor, target, value) => 
        D4.validateTarget<Like>(target, 'Like').returnType = D4.extractBridgedArg<Type>(value, 'returnType'),
      'operant1': (visitor, target, value) => 
        D4.validateTarget<Like>(target, 'Like').operant1 = D4.extractBridgedArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(value, 'operant1'),
      'operant2': (visitor, target, value) => 
        D4.validateTarget<Like>(target, 'Like').operant2 = D4.extractBridgedArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(value, 'operant2'),
    },
    methods: {
      'generate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Like>(target, 'Like');
        D4.requireMinArgs(positional, 1, 'generate');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generate');
        return t.generate(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Like>(target, 'Like');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Like>(target, 'Like');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Like>(target, 'Like');
        return t.toString();
      },
      'indent': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Like>(target, 'Like');
        D4.requireMinArgs(positional, 1, 'indent');
        final i = D4.getRequiredArg<int>(positional, 0, 'i', 'indent');
        return t.indent(i);
      },
      'analyze': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Like>(target, 'Like');
        D4.requireMinArgs(positional, 1, 'analyze');
        final l = D4.getRequiredArg<int>(positional, 0, 'l', 'analyze');
        return t.analyze(l);
      },
    },
    constructorSignatures: {
      '': 'Like(TomOperator<TomDbString> operant1, TomOperator<TomDbString> operant2)',
    },
    methodSignatures: {
      'generate': 'SqlString generate(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
      'indent': 'String indent(int i)',
      'analyze': 'String analyze(int l)',
    },
    getterSignatures: {
      'returnType': 'Type get returnType',
      'operant1': 'TomOperator<TomDbString> get operant1',
      'operant2': 'TomOperator<TomDbString> get operant2',
    },
    setterSignatures: {
      'returnType': 'set returnType(Type value)',
      'operant1': 'set operant1(TomOperator<TomDbString> value)',
      'operant2': 'set operant2(TomOperator<TomDbString> value)',
    },
  );
}

// =============================================================================
// NotLike Bridge
// =============================================================================

BridgedClass _createNotLikeBridge() {
  return BridgedClass(
    nativeType: NotLike,
    name: 'NotLike',
    isAssignable: (v) => v is NotLike,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'NotLike');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 0, 'operant1', 'NotLike');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 1, 'operant2', 'NotLike');
        return NotLike(operant1, operant2);
      },
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<NotLike>(target, 'NotLike').returnType,
      'operant1': (visitor, target) => D4.validateTarget<NotLike>(target, 'NotLike').operant1,
      'operant2': (visitor, target) => D4.validateTarget<NotLike>(target, 'NotLike').operant2,
    },
    setters: {
      'returnType': (visitor, target, value) => 
        D4.validateTarget<NotLike>(target, 'NotLike').returnType = D4.extractBridgedArg<Type>(value, 'returnType'),
      'operant1': (visitor, target, value) => 
        D4.validateTarget<NotLike>(target, 'NotLike').operant1 = D4.extractBridgedArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(value, 'operant1'),
      'operant2': (visitor, target, value) => 
        D4.validateTarget<NotLike>(target, 'NotLike').operant2 = D4.extractBridgedArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(value, 'operant2'),
    },
    methods: {
      'generate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<NotLike>(target, 'NotLike');
        D4.requireMinArgs(positional, 1, 'generate');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generate');
        return t.generate(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<NotLike>(target, 'NotLike');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<NotLike>(target, 'NotLike');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<NotLike>(target, 'NotLike');
        return t.toString();
      },
      'indent': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<NotLike>(target, 'NotLike');
        D4.requireMinArgs(positional, 1, 'indent');
        final i = D4.getRequiredArg<int>(positional, 0, 'i', 'indent');
        return t.indent(i);
      },
      'analyze': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<NotLike>(target, 'NotLike');
        D4.requireMinArgs(positional, 1, 'analyze');
        final l = D4.getRequiredArg<int>(positional, 0, 'l', 'analyze');
        return t.analyze(l);
      },
    },
    constructorSignatures: {
      '': 'NotLike(TomOperator<TomDbString> operant1, TomOperator<TomDbString> operant2)',
    },
    methodSignatures: {
      'generate': 'SqlString generate(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
      'indent': 'String indent(int i)',
      'analyze': 'String analyze(int l)',
    },
    getterSignatures: {
      'returnType': 'Type get returnType',
      'operant1': 'TomOperator<TomDbString> get operant1',
      'operant2': 'TomOperator<TomDbString> get operant2',
    },
    setterSignatures: {
      'returnType': 'set returnType(Type value)',
      'operant1': 'set operant1(TomOperator<TomDbString> value)',
      'operant2': 'set operant2(TomOperator<TomDbString> value)',
    },
  );
}

// =============================================================================
// In Bridge
// =============================================================================

BridgedClass _createInBridge() {
  return BridgedClass(
    nativeType: In,
    name: 'In',
    isAssignable: (v) => v is In,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'In');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'In');
        if (positional.length <= 1) {
          throw ArgumentError('In: Missing required argument "operant2" at position 1');
        }
        final operant2 = D4.coerceList<$tom_core_server_8.TomOperator<dynamic>>(positional[1], 'operant2');
        return In(operant1, operant2);
      },
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<In>(target, 'In').returnType,
      'operant1': (visitor, target) => D4.validateTarget<In>(target, 'In').operant1,
      'operant2': (visitor, target) => D4.validateTarget<In>(target, 'In').operant2,
    },
    setters: {
      'returnType': (visitor, target, value) => 
        D4.validateTarget<In>(target, 'In').returnType = D4.extractBridgedArg<Type>(value, 'returnType'),
      'operant1': (visitor, target, value) => 
        D4.validateTarget<In>(target, 'In').operant1 = D4.extractBridgedArg<$tom_core_server_8.TomOperator<dynamic>>(value, 'operant1'),
      'operant2': (visitor, target, value) => 
        D4.validateTarget<In>(target, 'In').operant2 = (value as List).cast<$tom_core_server_8.TomOperator<dynamic>>().toList(),
    },
    methods: {
      'generate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<In>(target, 'In');
        D4.requireMinArgs(positional, 1, 'generate');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generate');
        return t.generate(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<In>(target, 'In');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<In>(target, 'In');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<In>(target, 'In');
        return t.toString();
      },
      'indent': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<In>(target, 'In');
        D4.requireMinArgs(positional, 1, 'indent');
        final i = D4.getRequiredArg<int>(positional, 0, 'i', 'indent');
        return t.indent(i);
      },
      'analyze': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<In>(target, 'In');
        D4.requireMinArgs(positional, 1, 'analyze');
        final l = D4.getRequiredArg<int>(positional, 0, 'l', 'analyze');
        return t.analyze(l);
      },
    },
    constructorSignatures: {
      '': 'In(TomOperator<T> operant1, List<TomOperator<T>> operant2)',
    },
    methodSignatures: {
      'generate': 'SqlString generate(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
      'indent': 'String indent(int i)',
      'analyze': 'String analyze(int l)',
    },
    getterSignatures: {
      'returnType': 'Type get returnType',
      'operant1': 'TomOperator<T> get operant1',
      'operant2': 'List<TomOperator<T>> get operant2',
    },
    setterSignatures: {
      'returnType': 'set returnType(Type value)',
      'operant1': 'set operant1(TomOperator<T> value)',
      'operant2': 'set operant2(List<TomOperator<T>> value)',
    },
  );
}

// =============================================================================
// Group Bridge
// =============================================================================

BridgedClass _createGroupBridge() {
  return BridgedClass(
    nativeType: Group,
    name: 'Group',
    isAssignable: (v) => v is Group,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'Group');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'Group');
        return Group(operant1);
      },
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<Group>(target, 'Group').returnType,
      'operant1': (visitor, target) => D4.validateTarget<Group>(target, 'Group').operant1,
    },
    setters: {
      'returnType': (visitor, target, value) => 
        D4.validateTarget<Group>(target, 'Group').returnType = D4.extractBridgedArg<Type>(value, 'returnType'),
      'operant1': (visitor, target, value) => 
        D4.validateTarget<Group>(target, 'Group').operant1 = D4.extractBridgedArg<$tom_core_server_8.TomOperator<dynamic>>(value, 'operant1'),
    },
    methods: {
      'generate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Group>(target, 'Group');
        D4.requireMinArgs(positional, 1, 'generate');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generate');
        return t.generate(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Group>(target, 'Group');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Group>(target, 'Group');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Group>(target, 'Group');
        return t.toString();
      },
      'indent': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Group>(target, 'Group');
        D4.requireMinArgs(positional, 1, 'indent');
        final i = D4.getRequiredArg<int>(positional, 0, 'i', 'indent');
        return t.indent(i);
      },
      'analyze': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Group>(target, 'Group');
        D4.requireMinArgs(positional, 1, 'analyze');
        final l = D4.getRequiredArg<int>(positional, 0, 'l', 'analyze');
        return t.analyze(l);
      },
    },
    constructorSignatures: {
      '': 'Group(TomOperator<T> operant1)',
    },
    methodSignatures: {
      'generate': 'SqlString generate(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
      'indent': 'String indent(int i)',
      'analyze': 'String analyze(int l)',
    },
    getterSignatures: {
      'returnType': 'Type get returnType',
      'operant1': 'TomOperator<T> get operant1',
    },
    setterSignatures: {
      'returnType': 'set returnType(Type value)',
      'operant1': 'set operant1(TomOperator<T> value)',
    },
  );
}

// =============================================================================
// Between Bridge
// =============================================================================

BridgedClass _createBetweenBridge() {
  return BridgedClass(
    nativeType: Between,
    name: 'Between',
    isAssignable: (v) => v is Between,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'Between');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'Between');
        if (positional.length <= 1) {
          throw ArgumentError('Between: Missing required argument "operant2" at position 1');
        }
        final operant2 = D4.coerceList<$tom_core_server_8.TomOperator<dynamic>>(positional[1], 'operant2');
        return Between(operant1, operant2);
      },
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<Between>(target, 'Between').returnType,
      'operant1': (visitor, target) => D4.validateTarget<Between>(target, 'Between').operant1,
      'operant2': (visitor, target) => D4.validateTarget<Between>(target, 'Between').operant2,
    },
    setters: {
      'returnType': (visitor, target, value) => 
        D4.validateTarget<Between>(target, 'Between').returnType = D4.extractBridgedArg<Type>(value, 'returnType'),
      'operant1': (visitor, target, value) => 
        D4.validateTarget<Between>(target, 'Between').operant1 = D4.extractBridgedArg<$tom_core_server_8.TomOperator<dynamic>>(value, 'operant1'),
      'operant2': (visitor, target, value) => 
        D4.validateTarget<Between>(target, 'Between').operant2 = (value as List).cast<$tom_core_server_8.TomOperator<dynamic>>().toList(),
    },
    methods: {
      'generate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Between>(target, 'Between');
        D4.requireMinArgs(positional, 1, 'generate');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generate');
        return t.generate(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Between>(target, 'Between');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Between>(target, 'Between');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Between>(target, 'Between');
        return t.toString();
      },
      'indent': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Between>(target, 'Between');
        D4.requireMinArgs(positional, 1, 'indent');
        final i = D4.getRequiredArg<int>(positional, 0, 'i', 'indent');
        return t.indent(i);
      },
      'analyze': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Between>(target, 'Between');
        D4.requireMinArgs(positional, 1, 'analyze');
        final l = D4.getRequiredArg<int>(positional, 0, 'l', 'analyze');
        return t.analyze(l);
      },
    },
    constructorSignatures: {
      '': 'Between(TomOperator<T> operant1, List<TomOperator<T>> operant2)',
    },
    methodSignatures: {
      'generate': 'SqlString generate(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
      'indent': 'String indent(int i)',
      'analyze': 'String analyze(int l)',
    },
    getterSignatures: {
      'returnType': 'Type get returnType',
      'operant1': 'TomOperator<T> get operant1',
      'operant2': 'List<TomOperator<T>> get operant2',
    },
    setterSignatures: {
      'returnType': 'set returnType(Type value)',
      'operant1': 'set operant1(TomOperator<T> value)',
      'operant2': 'set operant2(List<TomOperator<T>> value)',
    },
  );
}

// =============================================================================
// Regexp Bridge
// =============================================================================

BridgedClass _createRegexpBridge() {
  return BridgedClass(
    nativeType: Regexp,
    name: 'Regexp',
    isAssignable: (v) => v is Regexp,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'Regexp');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 0, 'operant1', 'Regexp');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 1, 'operant2', 'Regexp');
        return Regexp(operant1, operant2);
      },
    },
    getters: {
      'returnType': (visitor, target) => D4.validateTarget<Regexp>(target, 'Regexp').returnType,
      'operant1': (visitor, target) => D4.validateTarget<Regexp>(target, 'Regexp').operant1,
      'operant2': (visitor, target) => D4.validateTarget<Regexp>(target, 'Regexp').operant2,
    },
    setters: {
      'returnType': (visitor, target, value) => 
        D4.validateTarget<Regexp>(target, 'Regexp').returnType = D4.extractBridgedArg<Type>(value, 'returnType'),
      'operant1': (visitor, target, value) => 
        D4.validateTarget<Regexp>(target, 'Regexp').operant1 = D4.extractBridgedArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(value, 'operant1'),
      'operant2': (visitor, target, value) => 
        D4.validateTarget<Regexp>(target, 'Regexp').operant2 = D4.extractBridgedArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(value, 'operant2'),
    },
    methods: {
      'generate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Regexp>(target, 'Regexp');
        D4.requireMinArgs(positional, 1, 'generate');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'generate');
        return t.generate(t_);
      },
      'getParameters': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Regexp>(target, 'Regexp');
        D4.requireMinArgs(positional, 1, 'getParameters');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getParameters');
        return t.getParameters(t_);
      },
      'getFields': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Regexp>(target, 'Regexp');
        D4.requireMinArgs(positional, 1, 'getFields');
        final t_ = D4.getRequiredArg<$tom_core_server_7.TomStandardSqlDialect>(positional, 0, 't', 'getFields');
        return t.getFields(t_);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Regexp>(target, 'Regexp');
        return t.toString();
      },
      'indent': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Regexp>(target, 'Regexp');
        D4.requireMinArgs(positional, 1, 'indent');
        final i = D4.getRequiredArg<int>(positional, 0, 'i', 'indent');
        return t.indent(i);
      },
      'analyze': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<Regexp>(target, 'Regexp');
        D4.requireMinArgs(positional, 1, 'analyze');
        final l = D4.getRequiredArg<int>(positional, 0, 'l', 'analyze');
        return t.analyze(l);
      },
    },
    constructorSignatures: {
      '': 'Regexp(TomOperator<TomDbString> operant1, TomOperator<TomDbString> operant2)',
    },
    methodSignatures: {
      'generate': 'SqlString generate(TomStandardSqlDialect t)',
      'getParameters': 'List<String> getParameters(TomStandardSqlDialect t)',
      'getFields': 'Set<String> getFields(TomStandardSqlDialect t)',
      'toString': 'String toString()',
      'indent': 'String indent(int i)',
      'analyze': 'String analyze(int l)',
    },
    getterSignatures: {
      'returnType': 'Type get returnType',
      'operant1': 'TomOperator<TomDbString> get operant1',
      'operant2': 'TomOperator<TomDbString> get operant2',
    },
    setterSignatures: {
      'returnType': 'set returnType(Type value)',
      'operant1': 'set operant1(TomOperator<TomDbString> value)',
      'operant2': 'set operant2(TomOperator<TomDbString> value)',
    },
  );
}

// =============================================================================
// TomDartType Bridge
// =============================================================================

BridgedClass _createTomDartTypeBridge() {
  return BridgedClass(
    nativeType: TomDartType,
    name: 'TomDartType',
    isAssignable: (v) => v is TomDartType,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomDartType');
        final type = D4.getRequiredArg<Type>(positional, 0, 'type', 'TomDartType');
        return TomDartType(type);
      },
    },
    getters: {
      'type': (visitor, target) => D4.validateTarget<TomDartType>(target, 'TomDartType').type,
    },
    constructorSignatures: {
      '': 'TomDartType(Type type)',
    },
    getterSignatures: {
      'type': 'Type get type',
    },
  );
}

// =============================================================================
// TomDbTable Bridge
// =============================================================================

BridgedClass _createTomDbTableBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_15.TomDbTable,
    name: 'TomDbTable',
    isAssignable: (v) => v is $tom_core_server_15.TomDbTable,
    constructors: {
      '': (visitor, positional, named) {
        final datasource = D4.getRequiredNamedArg<String>(named, 'datasource', 'TomDbTable');
        final table = D4.getRequiredNamedArg<String>(named, 'table', 'TomDbTable');
        final primaryKeyField = D4.getRequiredNamedArg<String>(named, 'primaryKeyField', 'TomDbTable');
        final idColumn = D4.getOptionalNamedArg<String?>(named, 'idColumn');
        final schema = D4.getOptionalNamedArg<String?>(named, 'schema');
        return $tom_core_server_15.TomDbTable(datasource: datasource, table: table, primaryKeyField: primaryKeyField, idColumn: idColumn, schema: schema);
      },
    },
    getters: {
      'datasource': (visitor, target) => D4.validateTarget<$tom_core_server_15.TomDbTable>(target, 'TomDbTable').datasource,
      'table': (visitor, target) => D4.validateTarget<$tom_core_server_15.TomDbTable>(target, 'TomDbTable').table,
      'schema': (visitor, target) => D4.validateTarget<$tom_core_server_15.TomDbTable>(target, 'TomDbTable').schema,
      'primaryKeyField': (visitor, target) => D4.validateTarget<$tom_core_server_15.TomDbTable>(target, 'TomDbTable').primaryKeyField,
      'idColumn': (visitor, target) => D4.validateTarget<$tom_core_server_15.TomDbTable>(target, 'TomDbTable').idColumn,
    },
    constructorSignatures: {
      '': 'const TomDbTable({required String datasource, required String table, required String primaryKeyField, String? idColumn, String? schema})',
    },
    getterSignatures: {
      'datasource': 'String get datasource',
      'table': 'String get table',
      'schema': 'String? get schema',
      'primaryKeyField': 'String get primaryKeyField',
      'idColumn': 'String? get idColumn',
    },
  );
}

// =============================================================================
// TomDbColumn Bridge
// =============================================================================

BridgedClass _createTomDbColumnBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_15.TomDbColumn,
    name: 'TomDbColumn',
    isAssignable: (v) => v is $tom_core_server_15.TomDbColumn,
    constructors: {
      '': (visitor, positional, named) {
        final columnName = D4.getRequiredNamedArg<String?>(named, 'columnName', 'TomDbColumn');
        final isReadOnly = D4.getNamedArgWithDefault<bool>(named, 'isReadOnly', false);
        final noLoad = D4.getNamedArgWithDefault<bool>(named, 'noLoad', false);
        final isJson = D4.getNamedArgWithDefault<bool>(named, 'isJson', false);
        final dartType = D4.getOptionalNamedArg<Type?>(named, 'dartType');
        final fromDbConverterRaw = named['fromDbConverter'];
        final toDbConverterRaw = named['toDbConverter'];
        final columnType = D4.getOptionalNamedArg<Type?>(named, 'columnType');
        return $tom_core_server_15.TomDbColumn(columnName: columnName, isReadOnly: isReadOnly, noLoad: noLoad, isJson: isJson, dartType: dartType, fromDbConverter: fromDbConverterRaw == null ? null : ($aux_aux_2.TomDbType<dynamic> p0) { return D4.castCallbackResult<dynamic>(D4.callInterpreterCallback(visitor!, fromDbConverterRaw, [p0])); }, toDbConverter: toDbConverterRaw == null ? null : (dynamic p0) { return D4.callInterpreterCallback(visitor!, toDbConverterRaw, [p0]) as $aux_aux_2.TomDbType<dynamic>; }, columnType: columnType);
      },
    },
    getters: {
      'columnName': (visitor, target) => D4.validateTarget<$tom_core_server_15.TomDbColumn>(target, 'TomDbColumn').columnName,
      'isReadOnly': (visitor, target) => D4.validateTarget<$tom_core_server_15.TomDbColumn>(target, 'TomDbColumn').isReadOnly,
      'noLoad': (visitor, target) => D4.validateTarget<$tom_core_server_15.TomDbColumn>(target, 'TomDbColumn').noLoad,
      'isJson': (visitor, target) => D4.validateTarget<$tom_core_server_15.TomDbColumn>(target, 'TomDbColumn').isJson,
      'dartType': (visitor, target) => D4.validateTarget<$tom_core_server_15.TomDbColumn>(target, 'TomDbColumn').dartType,
      'columnType': (visitor, target) => D4.validateTarget<$tom_core_server_15.TomDbColumn>(target, 'TomDbColumn').columnType,
      'fromDbConverter': (visitor, target) => D4.validateTarget<$tom_core_server_15.TomDbColumn>(target, 'TomDbColumn').fromDbConverter,
      'toDbConverter': (visitor, target) => D4.validateTarget<$tom_core_server_15.TomDbColumn>(target, 'TomDbColumn').toDbConverter,
    },
    methods: {
      'declaredDartType': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_15.TomDbColumn>(target, 'TomDbColumn');
        return t.declaredDartType();
      },
      'declaredColumnType': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_15.TomDbColumn>(target, 'TomDbColumn');
        return t.declaredColumnType();
      },
    },
    constructorSignatures: {
      '': 'const TomDbColumn({required String? columnName, bool isReadOnly = false, bool noLoad = false, bool isJson = false, Type? dartType, DART_TYPE Function(COL_TYPE)? fromDbConverter, COL_TYPE Function(DART_TYPE)? toDbConverter, Type? columnType})',
    },
    methodSignatures: {
      'declaredDartType': 'Type? declaredDartType()',
      'declaredColumnType': 'Type? declaredColumnType()',
    },
    getterSignatures: {
      'columnName': 'String? get columnName',
      'isReadOnly': 'bool get isReadOnly',
      'noLoad': 'bool get noLoad',
      'isJson': 'bool get isJson',
      'dartType': 'Type? get dartType',
      'columnType': 'Type? get columnType',
      'fromDbConverter': 'DART_TYPE Function(COL_TYPE)? get fromDbConverter',
      'toDbConverter': 'COL_TYPE Function(DART_TYPE)? get toDbConverter',
    },
  );
}

// =============================================================================
// TomEntityId Bridge
// =============================================================================

BridgedClass _createTomEntityIdBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_15.TomEntityId,
    name: 'TomEntityId',
    isAssignable: (v) => v is $tom_core_server_15.TomEntityId,
    constructors: {
      '': (visitor, positional, named) {
        return $tom_core_server_15.TomEntityId();
      },
    },
    constructorSignatures: {
      '': 'const TomEntityId()',
    },
  );
}

// =============================================================================
// TomJoinTable Bridge
// =============================================================================

BridgedClass _createTomJoinTableBridge() {
  return BridgedClass(
    nativeType: TomJoinTable,
    name: 'TomJoinTable',
    isAssignable: (v) => v is TomJoinTable,
    constructors: {
      '': (visitor, positional, named) {
        final targetEntity = D4.getRequiredNamedArg<Type>(named, 'targetEntity', 'TomJoinTable');
        final repositoryType = D4.getRequiredNamedArg<Type>(named, 'repositoryType', 'TomJoinTable');
        final keyType = D4.getRequiredNamedArg<Type>(named, 'keyType', 'TomJoinTable');
        final originEntity = D4.getRequiredNamedArg<Type>(named, 'originEntity', 'TomJoinTable');
        if (!named.containsKey('leftSideColumns') || named['leftSideColumns'] == null) {
          throw ArgumentError('TomJoinTable: Missing required named argument "leftSideColumns"');
        }
        final leftSideColumns = D4.coerceList<String>(named['leftSideColumns'], 'leftSideColumns');
        if (!named.containsKey('rightSideColumns') || named['rightSideColumns'] == null) {
          throw ArgumentError('TomJoinTable: Missing required named argument "rightSideColumns"');
        }
        final rightSideColumns = D4.coerceList<String>(named['rightSideColumns'], 'rightSideColumns');
        final contextColumns = named.containsKey('contextColumns') && named['contextColumns'] != null
            ? D4.coerceList<String>(named['contextColumns'], 'contextColumns')
            : const <String>[];
        return TomJoinTable(targetEntity: targetEntity, repositoryType: repositoryType, keyType: keyType, originEntity: originEntity, leftSideColumns: leftSideColumns, rightSideColumns: rightSideColumns, contextColumns: contextColumns);
      },
    },
    getters: {
      'targetEntity': (visitor, target) => D4.validateTarget<TomJoinTable>(target, 'TomJoinTable').targetEntity,
      'repositoryType': (visitor, target) => D4.validateTarget<TomJoinTable>(target, 'TomJoinTable').repositoryType,
      'originEntity': (visitor, target) => D4.validateTarget<TomJoinTable>(target, 'TomJoinTable').originEntity,
      'keyType': (visitor, target) => D4.validateTarget<TomJoinTable>(target, 'TomJoinTable').keyType,
      'leftSideColumns': (visitor, target) => D4.validateTarget<TomJoinTable>(target, 'TomJoinTable').leftSideColumns,
      'rightSideColumns': (visitor, target) => D4.validateTarget<TomJoinTable>(target, 'TomJoinTable').rightSideColumns,
      'contextColumns': (visitor, target) => D4.validateTarget<TomJoinTable>(target, 'TomJoinTable').contextColumns,
    },
    constructorSignatures: {
      '': 'const TomJoinTable({required Type targetEntity, required Type repositoryType, required Type keyType, required Type originEntity, required List<String> leftSideColumns, required List<String> rightSideColumns, List<String> contextColumns = const []})',
    },
    getterSignatures: {
      'targetEntity': 'Type get targetEntity',
      'repositoryType': 'Type get repositoryType',
      'originEntity': 'Type get originEntity',
      'keyType': 'Type get keyType',
      'leftSideColumns': 'List<String> get leftSideColumns',
      'rightSideColumns': 'List<String> get rightSideColumns',
      'contextColumns': 'List<String> get contextColumns',
    },
  );
}

// =============================================================================
// TomReference Bridge
// =============================================================================

BridgedClass _createTomReferenceBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_15.TomReference,
    name: 'TomReference',
    isAssignable: (v) => v is $tom_core_server_15.TomReference,
    constructors: {
      '': (visitor, positional, named) {
        final targetEntity = D4.getRequiredNamedArg<Type>(named, 'targetEntity', 'TomReference');
        final repositoryType = D4.getRequiredNamedArg<Type>(named, 'repositoryType', 'TomReference');
        final keyType = D4.getRequiredNamedArg<Type>(named, 'keyType', 'TomReference');
        final joinEntity = D4.getRequiredNamedArg<Type>(named, 'joinEntity', 'TomReference');
        if (!named.containsKey('leftSideColumns') || named['leftSideColumns'] == null) {
          throw ArgumentError('TomReference: Missing required named argument "leftSideColumns"');
        }
        final leftSideColumns = D4.coerceList<String>(named['leftSideColumns'], 'leftSideColumns');
        if (!named.containsKey('rightSideColumns') || named['rightSideColumns'] == null) {
          throw ArgumentError('TomReference: Missing required named argument "rightSideColumns"');
        }
        final rightSideColumns = D4.coerceList<String>(named['rightSideColumns'], 'rightSideColumns');
        final contextColumns = named.containsKey('contextColumns') && named['contextColumns'] != null
            ? D4.coerceList<String>(named['contextColumns'], 'contextColumns')
            : const <String>[];
        final isOneToOne = D4.getNamedArgWithDefault<bool>(named, 'isOneToOne', false);
        return $tom_core_server_15.TomReference(targetEntity: targetEntity, repositoryType: repositoryType, keyType: keyType, joinEntity: joinEntity, leftSideColumns: leftSideColumns, rightSideColumns: rightSideColumns, contextColumns: contextColumns, isOneToOne: isOneToOne);
      },
    },
    getters: {
      'targetEntity': (visitor, target) => D4.validateTarget<$tom_core_server_15.TomReference>(target, 'TomReference').targetEntity,
      'repositoryType': (visitor, target) => D4.validateTarget<$tom_core_server_15.TomReference>(target, 'TomReference').repositoryType,
      'joinEntity': (visitor, target) => D4.validateTarget<$tom_core_server_15.TomReference>(target, 'TomReference').joinEntity,
      'keyType': (visitor, target) => D4.validateTarget<$tom_core_server_15.TomReference>(target, 'TomReference').keyType,
      'leftSideColumns': (visitor, target) => D4.validateTarget<$tom_core_server_15.TomReference>(target, 'TomReference').leftSideColumns,
      'rightSideColumns': (visitor, target) => D4.validateTarget<$tom_core_server_15.TomReference>(target, 'TomReference').rightSideColumns,
      'contextColumns': (visitor, target) => D4.validateTarget<$tom_core_server_15.TomReference>(target, 'TomReference').contextColumns,
      'isOneToOne': (visitor, target) => D4.validateTarget<$tom_core_server_15.TomReference>(target, 'TomReference').isOneToOne,
    },
    methods: {
      'getReferencedType': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_15.TomReference>(target, 'TomReference');
        return t.getReferencedType();
      },
      'getRepositoryType': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_15.TomReference>(target, 'TomReference');
        return t.getRepositoryType();
      },
      'getKeyType': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_15.TomReference>(target, 'TomReference');
        return t.getKeyType();
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_15.TomReference>(target, 'TomReference');
        return t.toString();
      },
    },
    constructorSignatures: {
      '': 'const TomReference({required Type targetEntity, required Type repositoryType, required Type keyType, required Type joinEntity, required List<String> leftSideColumns, required List<String> rightSideColumns, List<String> contextColumns = const [], bool isOneToOne = false})',
    },
    methodSignatures: {
      'getReferencedType': 'Type getReferencedType()',
      'getRepositoryType': 'Type getRepositoryType()',
      'getKeyType': 'Type getKeyType()',
      'toString': 'String toString()',
    },
    getterSignatures: {
      'targetEntity': 'Type get targetEntity',
      'repositoryType': 'Type get repositoryType',
      'joinEntity': 'Type get joinEntity',
      'keyType': 'Type get keyType',
      'leftSideColumns': 'List<String> get leftSideColumns',
      'rightSideColumns': 'List<String> get rightSideColumns',
      'contextColumns': 'List<String> get contextColumns',
      'isOneToOne': 'bool get isOneToOne',
    },
  );
}

// =============================================================================
// TomPersistenceEventHandler Bridge
// =============================================================================

BridgedClass _createTomPersistenceEventHandlerBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_15.TomPersistenceEventHandler,
    name: 'TomPersistenceEventHandler',
    isAssignable: (v) => v is $tom_core_server_15.TomPersistenceEventHandler,
    constructors: {
      '': (visitor, positional, named) {
        final postPersistRaw = named['postPersist'];
        final postLoadRaw = named['postLoad'];
        final preLoadRaw = named['preLoad'];
        final prePersistRaw = named['prePersist'];
        return $tom_core_server_15.TomPersistenceEventHandler(postPersist: postPersistRaw == null ? null : (dynamic p0) { D4.callInterpreterCallback(visitor!, postPersistRaw, [p0]); }, postLoad: postLoadRaw == null ? null : (dynamic p0) { D4.callInterpreterCallback(visitor!, postLoadRaw, [p0]); }, preLoad: preLoadRaw == null ? null : (dynamic p0) { D4.callInterpreterCallback(visitor!, preLoadRaw, [p0]); }, prePersist: prePersistRaw == null ? null : (dynamic p0) { D4.callInterpreterCallback(visitor!, prePersistRaw, [p0]); });
      },
    },
    getters: {
      'postPersist': (visitor, target) => D4.validateTarget<$tom_core_server_15.TomPersistenceEventHandler>(target, 'TomPersistenceEventHandler').postPersist,
      'postLoad': (visitor, target) => D4.validateTarget<$tom_core_server_15.TomPersistenceEventHandler>(target, 'TomPersistenceEventHandler').postLoad,
      'prePersist': (visitor, target) => D4.validateTarget<$tom_core_server_15.TomPersistenceEventHandler>(target, 'TomPersistenceEventHandler').prePersist,
      'preLoad': (visitor, target) => D4.validateTarget<$tom_core_server_15.TomPersistenceEventHandler>(target, 'TomPersistenceEventHandler').preLoad,
    },
    constructorSignatures: {
      '': 'TomPersistenceEventHandler({void Function(DBTYPE)? postPersist, void Function(DBTYPE)? postLoad, void Function(DBTYPE)? preLoad, void Function(DBTYPE)? prePersist})',
    },
    getterSignatures: {
      'postPersist': 'void Function(DBTYPE)? get postPersist',
      'postLoad': 'void Function(DBTYPE)? get postLoad',
      'prePersist': 'void Function(DBTYPE)? get prePersist',
      'preLoad': 'void Function(DBTYPE)? get preLoad',
    },
  );
}

// =============================================================================
// TomColumnInformation Bridge
// =============================================================================

BridgedClass _createTomColumnInformationBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_15.TomColumnInformation,
    name: 'TomColumnInformation',
    isAssignable: (v) => v is $tom_core_server_15.TomColumnInformation,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 9, 'TomColumnInformation');
        final table = D4.getRequiredArg<$tom_core_server_15.TomDbTable>(positional, 0, 'table', 'TomColumnInformation');
        final tableType = D4.getRequiredArg<Type>(positional, 1, 'tableType', 'TomColumnInformation');
        final column = D4.getRequiredArg<$tom_core_server_15.TomDbColumn<dynamic, $tom_core_server_8.TomDbType<dynamic>>?>(positional, 2, 'column', 'TomColumnInformation');
        final entityId = D4.getRequiredArg<$tom_core_server_15.TomEntityId?>(positional, 3, 'entityId', 'TomColumnInformation');
        final reference = D4.getRequiredArg<$tom_core_server_15.TomReference<Object, dynamic, $tom_core_server_13.TomRepository<Object, dynamic>>?>(positional, 4, 'reference', 'TomColumnInformation');
        final eventHandler = D4.getRequiredArg<$tom_core_server_15.TomPersistenceEventHandler<dynamic>?>(positional, 5, 'eventHandler', 'TomColumnInformation');
        final declaredType = D4.getRequiredArg<Type>(positional, 6, 'declaredType', 'TomColumnInformation');
        final declaredName = D4.getRequiredArg<String>(positional, 7, 'declaredName', 'TomColumnInformation');
        final field = D4.getRequiredArg<String>(positional, 8, 'field', 'TomColumnInformation');
        return $tom_core_server_15.TomColumnInformation(table, tableType, column, entityId, reference, eventHandler, declaredType, declaredName, field);
      },
    },
    getters: {
      'tableType': (visitor, target) => D4.validateTarget<$tom_core_server_15.TomColumnInformation>(target, 'TomColumnInformation').tableType,
      'table': (visitor, target) => D4.validateTarget<$tom_core_server_15.TomColumnInformation>(target, 'TomColumnInformation').table,
      'column': (visitor, target) => D4.validateTarget<$tom_core_server_15.TomColumnInformation>(target, 'TomColumnInformation').column,
      'entityId': (visitor, target) => D4.validateTarget<$tom_core_server_15.TomColumnInformation>(target, 'TomColumnInformation').entityId,
      'reference': (visitor, target) => D4.validateTarget<$tom_core_server_15.TomColumnInformation>(target, 'TomColumnInformation').reference,
      'eventHandler': (visitor, target) => D4.validateTarget<$tom_core_server_15.TomColumnInformation>(target, 'TomColumnInformation').eventHandler,
      'declaredType': (visitor, target) => D4.validateTarget<$tom_core_server_15.TomColumnInformation>(target, 'TomColumnInformation').declaredType,
      'declaredName': (visitor, target) => D4.validateTarget<$tom_core_server_15.TomColumnInformation>(target, 'TomColumnInformation').declaredName,
      'field': (visitor, target) => D4.validateTarget<$tom_core_server_15.TomColumnInformation>(target, 'TomColumnInformation').field,
    },
    setters: {
      'tableType': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_15.TomColumnInformation>(target, 'TomColumnInformation').tableType = D4.extractBridgedArg<Type>(value, 'tableType'),
      'table': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_15.TomColumnInformation>(target, 'TomColumnInformation').table = D4.extractBridgedArg<$tom_core_server_15.TomDbTable>(value, 'table'),
      'column': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_15.TomColumnInformation>(target, 'TomColumnInformation').column = D4.extractBridgedArgOrNull<$tom_core_server_15.TomDbColumn>(value, 'column'),
      'entityId': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_15.TomColumnInformation>(target, 'TomColumnInformation').entityId = D4.extractBridgedArgOrNull<$tom_core_server_15.TomEntityId>(value, 'entityId'),
      'reference': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_15.TomColumnInformation>(target, 'TomColumnInformation').reference = D4.extractBridgedArgOrNull<$tom_core_server_15.TomReference>(value, 'reference'),
      'eventHandler': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_15.TomColumnInformation>(target, 'TomColumnInformation').eventHandler = D4.extractBridgedArgOrNull<$tom_core_server_15.TomPersistenceEventHandler>(value, 'eventHandler'),
      'declaredType': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_15.TomColumnInformation>(target, 'TomColumnInformation').declaredType = D4.extractBridgedArg<Type>(value, 'declaredType'),
      'declaredName': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_15.TomColumnInformation>(target, 'TomColumnInformation').declaredName = D4.extractBridgedArg<String>(value, 'declaredName'),
      'field': (visitor, target, value) => 
        D4.validateTarget<$tom_core_server_15.TomColumnInformation>(target, 'TomColumnInformation').field = D4.extractBridgedArg<String>(value, 'field'),
    },
    methods: {
      'getDatabaseType': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_15.TomColumnInformation>(target, 'TomColumnInformation');
        return t.getDatabaseType();
      },
      'getQueryFieldName': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_15.TomColumnInformation>(target, 'TomColumnInformation');
        return t.getQueryFieldName();
      },
      'getVariableValue': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_15.TomColumnInformation>(target, 'TomColumnInformation');
        D4.requireMinArgs(positional, 1, 'getVariableValue');
        final instance = D4.getRequiredArg<Object>(positional, 0, 'instance', 'getVariableValue');
        return t.getVariableValue(instance);
      },
      'setVariableValue': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_15.TomColumnInformation>(target, 'TomColumnInformation');
        D4.requireMinArgs(positional, 2, 'setVariableValue');
        final instance = D4.getRequiredArg<Object>(positional, 0, 'instance', 'setVariableValue');
        final value = D4.getRequiredArg<Object?>(positional, 1, 'value', 'setVariableValue');
        return t.setVariableValue(instance, value);
      },
    },
    constructorSignatures: {
      '': 'TomColumnInformation(TomDbTable table, Type tableType, TomDbColumn<dynamic, TomDbType<dynamic>>? column, TomEntityId? entityId, TomReference<Object, dynamic, TomRepository<Object, dynamic>>? reference, TomPersistenceEventHandler<dynamic>? eventHandler, Type declaredType, String declaredName, String field)',
    },
    methodSignatures: {
      'getDatabaseType': 'Type getDatabaseType()',
      'getQueryFieldName': 'String getQueryFieldName()',
      'getVariableValue': 'Object? getVariableValue(Object instance)',
      'setVariableValue': 'Object? setVariableValue(Object instance, Object? value)',
    },
    getterSignatures: {
      'tableType': 'Type get tableType',
      'table': 'TomDbTable get table',
      'column': 'TomDbColumn? get column',
      'entityId': 'TomEntityId? get entityId',
      'reference': 'TomReference? get reference',
      'eventHandler': 'TomPersistenceEventHandler? get eventHandler',
      'declaredType': 'Type get declaredType',
      'declaredName': 'String get declaredName',
      'field': 'String get field',
    },
    setterSignatures: {
      'tableType': 'set tableType(dynamic value)',
      'table': 'set table(dynamic value)',
      'column': 'set column(dynamic value)',
      'entityId': 'set entityId(dynamic value)',
      'reference': 'set reference(dynamic value)',
      'eventHandler': 'set eventHandler(dynamic value)',
      'declaredType': 'set declaredType(dynamic value)',
      'declaredName': 'set declaredName(dynamic value)',
      'field': 'set field(dynamic value)',
    },
  );
}

// =============================================================================
// TomQueryBuilder Bridge
// =============================================================================

BridgedClass _createTomQueryBuilderBridge() {
  return BridgedClass(
    nativeType: TomQueryBuilder,
    name: 'TomQueryBuilder',
    isAssignable: (v) => v is TomQueryBuilder,
    constructors: {
    },
    methods: {
      'isNull': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQueryBuilder>(target, 'TomQueryBuilder');
        D4.requireMinArgs(positional, 1, 'isNull');
        final what = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'what', 'isNull');
        return t.isNull(what);
      },
      'isNotNull': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQueryBuilder>(target, 'TomQueryBuilder');
        D4.requireMinArgs(positional, 1, 'isNotNull');
        final what = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'what', 'isNotNull');
        return t.isNotNull(what);
      },
      'isIn': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQueryBuilder>(target, 'TomQueryBuilder');
        D4.requireMinArgs(positional, 2, 'isIn');
        final what = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'what', 'isIn');
        if (positional.length <= 1) {
          throw ArgumentError('isIn: Missing required argument "choices" at position 1');
        }
        final choices = D4.coerceList<$tom_core_server_8.TomOperator<dynamic>>(positional[1], 'choices');
        return t.isIn(what, choices);
      },
      'between': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQueryBuilder>(target, 'TomQueryBuilder');
        D4.requireMinArgs(positional, 2, 'between');
        final what = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'what', 'between');
        if (positional.length <= 1) {
          throw ArgumentError('between: Missing required argument "betweenLimits" at position 1');
        }
        final betweenLimits = D4.coerceList<$tom_core_server_8.TomOperator<dynamic>>(positional[1], 'betweenLimits');
        return t.between(what, betweenLimits);
      },
      'like': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQueryBuilder>(target, 'TomQueryBuilder');
        D4.requireMinArgs(positional, 2, 'like');
        final text = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 0, 'text', 'like');
        final test = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 1, 'test', 'like');
        return t.like(text, test);
      },
      'notLike': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQueryBuilder>(target, 'TomQueryBuilder');
        D4.requireMinArgs(positional, 2, 'notLike');
        final text = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 0, 'text', 'notLike');
        final test = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 1, 'test', 'notLike');
        return t.notLike(text, test);
      },
      'regexp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQueryBuilder>(target, 'TomQueryBuilder');
        D4.requireMinArgs(positional, 2, 'regexp');
        final text = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 0, 'text', 'regexp');
        final test = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 1, 'test', 'regexp');
        return t.regexp(text, test);
      },
      'group': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQueryBuilder>(target, 'TomQueryBuilder');
        D4.requireMinArgs(positional, 1, 'group');
        final operant = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant', 'group');
        return t.group(operant);
      },
      'eq': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQueryBuilder>(target, 'TomQueryBuilder');
        D4.requireMinArgs(positional, 2, 'eq');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'eq');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'eq');
        return t.eq(operant1, operant2);
      },
      'neq': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQueryBuilder>(target, 'TomQueryBuilder');
        D4.requireMinArgs(positional, 2, 'neq');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'neq');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'neq');
        return t.neq(operant1, operant2);
      },
      'lt': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQueryBuilder>(target, 'TomQueryBuilder');
        D4.requireMinArgs(positional, 2, 'lt');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'lt');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'lt');
        return t.lt(operant1, operant2);
      },
      'lte': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQueryBuilder>(target, 'TomQueryBuilder');
        D4.requireMinArgs(positional, 2, 'lte');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'lte');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'lte');
        return t.lte(operant1, operant2);
      },
      'gt': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQueryBuilder>(target, 'TomQueryBuilder');
        D4.requireMinArgs(positional, 2, 'gt');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'gt');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'gt');
        return t.gt(operant1, operant2);
      },
      'gte': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQueryBuilder>(target, 'TomQueryBuilder');
        D4.requireMinArgs(positional, 2, 'gte');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'gte');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'gte');
        return t.gte(operant1, operant2);
      },
      'not': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQueryBuilder>(target, 'TomQueryBuilder');
        D4.requireMinArgs(positional, 1, 'not');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbBool>>(positional, 0, 'operant1', 'not');
        return t.not(operant1);
      },
      'and': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQueryBuilder>(target, 'TomQueryBuilder');
        D4.requireMinArgs(positional, 1, 'and');
        if (positional.isEmpty) {
          throw ArgumentError('and: Missing required argument "operant1" at position 0');
        }
        final operant1 = D4.coerceList<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbBool>>(positional[0], 'operant1');
        return t.and(operant1);
      },
      'or': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQueryBuilder>(target, 'TomQueryBuilder');
        D4.requireMinArgs(positional, 1, 'or');
        if (positional.isEmpty) {
          throw ArgumentError('or: Missing required argument "operant1" at position 0');
        }
        final operant1 = D4.coerceList<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbBool>>(positional[0], 'operant1');
        return t.or(operant1);
      },
      'text': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQueryBuilder>(target, 'TomQueryBuilder');
        D4.requireMinArgs(positional, 1, 'text');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'text');
        return t.text(text);
      },
      'intOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQueryBuilder>(target, 'TomQueryBuilder');
        D4.requireMinArgs(positional, 1, 'intOp');
        final value = D4.getRequiredArg<int>(positional, 0, 'value', 'intOp');
        return t.intOp(value);
      },
      'doubleOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQueryBuilder>(target, 'TomQueryBuilder');
        D4.requireMinArgs(positional, 1, 'doubleOp');
        final value = D4.getRequiredArg<double>(positional, 0, 'value', 'doubleOp');
        return t.doubleOp(value);
      },
      'boolOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQueryBuilder>(target, 'TomQueryBuilder');
        D4.requireMinArgs(positional, 1, 'boolOp');
        final value = D4.getRequiredArg<bool>(positional, 0, 'value', 'boolOp');
        return t.boolOp(value);
      },
      'dateTimeOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQueryBuilder>(target, 'TomQueryBuilder');
        D4.requireMinArgs(positional, 1, 'dateTimeOp');
        final value = D4.getRequiredArg<DateTime>(positional, 0, 'value', 'dateTimeOp');
        return t.dateTimeOp(value);
      },
      'dateOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQueryBuilder>(target, 'TomQueryBuilder');
        D4.requireMinArgs(positional, 1, 'dateOp');
        final value = D4.getRequiredArg<DateTime>(positional, 0, 'value', 'dateOp');
        return t.dateOp(value);
      },
      'p': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQueryBuilder>(target, 'TomQueryBuilder');
        D4.requireMinArgs(positional, 1, 'p');
        final parameterName = D4.getRequiredArg<String>(positional, 0, 'parameterName', 'p');
        return t.p(parameterName);
      },
      'textF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQueryBuilder>(target, 'TomQueryBuilder');
        D4.requireMinArgs(positional, 2, 'textF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'textF');
        final columnInformation = D4.getRequiredArg<$tom_core_server_15.TomColumnInformation>(positional, 1, 'columnInformation', 'textF');
        return t.textF(fieldName, columnInformation);
      },
      'intF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQueryBuilder>(target, 'TomQueryBuilder');
        D4.requireMinArgs(positional, 2, 'intF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'intF');
        final columnInformation = D4.getRequiredArg<$tom_core_server_15.TomColumnInformation>(positional, 1, 'columnInformation', 'intF');
        return t.intF(fieldName, columnInformation);
      },
      'doubleF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQueryBuilder>(target, 'TomQueryBuilder');
        D4.requireMinArgs(positional, 2, 'doubleF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'doubleF');
        final columnInformation = D4.getRequiredArg<$tom_core_server_15.TomColumnInformation>(positional, 1, 'columnInformation', 'doubleF');
        return t.doubleF(fieldName, columnInformation);
      },
      'boolF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQueryBuilder>(target, 'TomQueryBuilder');
        D4.requireMinArgs(positional, 2, 'boolF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'boolF');
        final columnInformation = D4.getRequiredArg<$tom_core_server_15.TomColumnInformation>(positional, 1, 'columnInformation', 'boolF');
        return t.boolF(fieldName, columnInformation);
      },
      'dateTimeF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQueryBuilder>(target, 'TomQueryBuilder');
        D4.requireMinArgs(positional, 2, 'dateTimeF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'dateTimeF');
        final columnInformation = D4.getRequiredArg<$tom_core_server_15.TomColumnInformation>(positional, 1, 'columnInformation', 'dateTimeF');
        return t.dateTimeF(fieldName, columnInformation);
      },
      'dateF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQueryBuilder>(target, 'TomQueryBuilder');
        D4.requireMinArgs(positional, 2, 'dateF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'dateF');
        final columnInformation = D4.getRequiredArg<$tom_core_server_15.TomColumnInformation>(positional, 1, 'columnInformation', 'dateF');
        return t.dateF(fieldName, columnInformation);
      },
    },
    methodSignatures: {
      'isNull': 'TomOperator<TomDbBool> isNull(TomOperator<T> what)',
      'isNotNull': 'TomOperator<TomDbBool> isNotNull(TomOperator<T> what)',
      'isIn': 'TomOperator<TomDbBool> isIn(TomOperator<T> what, List<TomOperator<T>> choices)',
      'between': 'TomOperator<TomDbBool> between(TomOperator<T> what, List<TomOperator<T>> betweenLimits)',
      'like': 'TomOperator<TomDbBool> like(TomOperator<TomDbString> text, TomOperator<TomDbString> test)',
      'notLike': 'TomOperator<TomDbBool> notLike(TomOperator<TomDbString> text, TomOperator<TomDbString> test)',
      'regexp': 'TomOperator<TomDbBool> regexp(TomOperator<TomDbString> text, TomOperator<TomDbString> test)',
      'group': 'TomOperator<T> group(TomOperator<T> operant)',
      'eq': 'TomOperator<TomDbBool> eq(TomOperator<T> operant1, TomOperator<T> operant2)',
      'neq': 'TomOperator<TomDbBool> neq(TomOperator<T> operant1, TomOperator<T> operant2)',
      'lt': 'TomOperator<TomDbBool> lt(TomOperator<T> operant1, TomOperator<T> operant2)',
      'lte': 'TomOperator<TomDbBool> lte(TomOperator<T> operant1, TomOperator<T> operant2)',
      'gt': 'TomOperator<TomDbBool> gt(TomOperator<T> operant1, TomOperator<T> operant2)',
      'gte': 'TomOperator<TomDbBool> gte(TomOperator<T> operant1, TomOperator<T> operant2)',
      'not': 'TomOperator<TomDbBool> not(TomOperator<TomDbBool> operant1)',
      'and': 'TomOperator<TomDbBool> and(List<TomOperator<TomDbBool>> operant1)',
      'or': 'TomOperator<TomDbBool> or(List<TomOperator<TomDbBool>> operant1)',
      'text': 'TomOperator<TomDbString> text(String text)',
      'intOp': 'TomOperator<TomDbInt> intOp(int value)',
      'doubleOp': 'TomOperator<TomDbDouble> doubleOp(double value)',
      'boolOp': 'TomOperator<TomDbBool> boolOp(bool value)',
      'dateTimeOp': 'TomOperator<TomDbDateTime> dateTimeOp(DateTime value)',
      'dateOp': 'TomOperator<TomDbDate> dateOp(DateTime value)',
      'p': 'TomOperator<T> p(String parameterName)',
      'textF': 'TomOperator<TomDbString> textF(String fieldName, TomColumnInformation columnInformation)',
      'intF': 'TomOperator<TomDbInt> intF(String fieldName, TomColumnInformation columnInformation)',
      'doubleF': 'TomOperator<TomDbDouble> doubleF(String fieldName, TomColumnInformation columnInformation)',
      'boolF': 'TomOperator<TomDbBool> boolF(String fieldName, TomColumnInformation columnInformation)',
      'dateTimeF': 'TomOperator<TomDbDateTime> dateTimeF(String fieldName, TomColumnInformation columnInformation)',
      'dateF': 'TomOperator<TomDbDate> dateF(String fieldName, TomColumnInformation columnInformation)',
    },
  );
}

// =============================================================================
// TomQuerySentenceCompiler Bridge
// =============================================================================

BridgedClass _createTomQuerySentenceCompilerBridge() {
  return BridgedClass(
    nativeType: TomQuerySentenceCompiler,
    name: 'TomQuerySentenceCompiler',
    isAssignable: (v) => v is TomQuerySentenceCompiler,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomQuerySentenceCompiler');
        if (positional.isEmpty) {
          throw ArgumentError('TomQuerySentenceCompiler: Missing required argument "types" at position 0');
        }
        final types = D4.coerceList<Type>(positional[0], 'types');
        return TomQuerySentenceCompiler(types);
      },
    },
    getters: {
      'types': (visitor, target) => D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler').types,
      'persistenceInfo': (visitor, target) => D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler').persistenceInfo,
    },
    setters: {
      'types': (visitor, target, value) => 
        D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler').types = (value as List).cast<Type>().toList(),
    },
    methods: {
      'getColumnInformation': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler');
        return t.getColumnInformation();
      },
      'determineColumn': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler');
        D4.requireMinArgs(positional, 1, 'determineColumn');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'determineColumn');
        return t.determineColumn(name);
      },
      'compileQuerySentence': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler');
        D4.requireMinArgs(positional, 1, 'compileQuerySentence');
        final qs = D4.getRequiredArg<String>(positional, 0, 'qs', 'compileQuerySentence');
        return t.compileQuerySentence(qs);
      },
      'isNull': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler');
        D4.requireMinArgs(positional, 1, 'isNull');
        final what = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'what', 'isNull');
        return t.isNull(what);
      },
      'isNotNull': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler');
        D4.requireMinArgs(positional, 1, 'isNotNull');
        final what = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'what', 'isNotNull');
        return t.isNotNull(what);
      },
      'isIn': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler');
        D4.requireMinArgs(positional, 2, 'isIn');
        final what = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'what', 'isIn');
        if (positional.length <= 1) {
          throw ArgumentError('isIn: Missing required argument "choices" at position 1');
        }
        final choices = D4.coerceList<$tom_core_server_8.TomOperator<dynamic>>(positional[1], 'choices');
        return t.isIn(what, choices);
      },
      'between': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler');
        D4.requireMinArgs(positional, 2, 'between');
        final what = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'what', 'between');
        if (positional.length <= 1) {
          throw ArgumentError('between: Missing required argument "betweenLimits" at position 1');
        }
        final betweenLimits = D4.coerceList<$tom_core_server_8.TomOperator<dynamic>>(positional[1], 'betweenLimits');
        return t.between(what, betweenLimits);
      },
      'like': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler');
        D4.requireMinArgs(positional, 2, 'like');
        final text = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 0, 'text', 'like');
        final test = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 1, 'test', 'like');
        return t.like(text, test);
      },
      'notLike': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler');
        D4.requireMinArgs(positional, 2, 'notLike');
        final text = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 0, 'text', 'notLike');
        final test = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 1, 'test', 'notLike');
        return t.notLike(text, test);
      },
      'regexp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler');
        D4.requireMinArgs(positional, 2, 'regexp');
        final text = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 0, 'text', 'regexp');
        final test = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbString>>(positional, 1, 'test', 'regexp');
        return t.regexp(text, test);
      },
      'group': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler');
        D4.requireMinArgs(positional, 1, 'group');
        final operant = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant', 'group');
        return t.group(operant);
      },
      'eq': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler');
        D4.requireMinArgs(positional, 2, 'eq');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'eq');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'eq');
        return t.eq(operant1, operant2);
      },
      'neq': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler');
        D4.requireMinArgs(positional, 2, 'neq');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'neq');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'neq');
        return t.neq(operant1, operant2);
      },
      'lt': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler');
        D4.requireMinArgs(positional, 2, 'lt');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'lt');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'lt');
        return t.lt(operant1, operant2);
      },
      'lte': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler');
        D4.requireMinArgs(positional, 2, 'lte');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'lte');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'lte');
        return t.lte(operant1, operant2);
      },
      'gt': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler');
        D4.requireMinArgs(positional, 2, 'gt');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'gt');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'gt');
        return t.gt(operant1, operant2);
      },
      'gte': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler');
        D4.requireMinArgs(positional, 2, 'gte');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 0, 'operant1', 'gte');
        final operant2 = D4.getRequiredArg<$tom_core_server_8.TomOperator<dynamic>>(positional, 1, 'operant2', 'gte');
        return t.gte(operant1, operant2);
      },
      'not': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler');
        D4.requireMinArgs(positional, 1, 'not');
        final operant1 = D4.getRequiredArg<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbBool>>(positional, 0, 'operant1', 'not');
        return t.not(operant1);
      },
      'and': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler');
        D4.requireMinArgs(positional, 1, 'and');
        if (positional.isEmpty) {
          throw ArgumentError('and: Missing required argument "operant1" at position 0');
        }
        final operant1 = D4.coerceList<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbBool>>(positional[0], 'operant1');
        return t.and(operant1);
      },
      'or': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler');
        D4.requireMinArgs(positional, 1, 'or');
        if (positional.isEmpty) {
          throw ArgumentError('or: Missing required argument "operant1" at position 0');
        }
        final operant1 = D4.coerceList<$tom_core_server_8.TomOperator<$tom_core_server_8.TomDbBool>>(positional[0], 'operant1');
        return t.or(operant1);
      },
      'text': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler');
        D4.requireMinArgs(positional, 1, 'text');
        final text = D4.getRequiredArg<String>(positional, 0, 'text', 'text');
        return t.text(text);
      },
      'intOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler');
        D4.requireMinArgs(positional, 1, 'intOp');
        final value = D4.getRequiredArg<int>(positional, 0, 'value', 'intOp');
        return t.intOp(value);
      },
      'doubleOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler');
        D4.requireMinArgs(positional, 1, 'doubleOp');
        final value = D4.getRequiredArg<double>(positional, 0, 'value', 'doubleOp');
        return t.doubleOp(value);
      },
      'boolOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler');
        D4.requireMinArgs(positional, 1, 'boolOp');
        final value = D4.getRequiredArg<bool>(positional, 0, 'value', 'boolOp');
        return t.boolOp(value);
      },
      'dateTimeOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler');
        D4.requireMinArgs(positional, 1, 'dateTimeOp');
        final value = D4.getRequiredArg<DateTime>(positional, 0, 'value', 'dateTimeOp');
        return t.dateTimeOp(value);
      },
      'dateOp': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler');
        D4.requireMinArgs(positional, 1, 'dateOp');
        final value = D4.getRequiredArg<DateTime>(positional, 0, 'value', 'dateOp');
        return t.dateOp(value);
      },
      'p': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler');
        D4.requireMinArgs(positional, 1, 'p');
        final parameterName = D4.getRequiredArg<String>(positional, 0, 'parameterName', 'p');
        return t.p(parameterName);
      },
      'textF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler');
        D4.requireMinArgs(positional, 2, 'textF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'textF');
        final columnInformation = D4.getRequiredArg<$tom_core_server_15.TomColumnInformation>(positional, 1, 'columnInformation', 'textF');
        return t.textF(fieldName, columnInformation);
      },
      'intF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler');
        D4.requireMinArgs(positional, 2, 'intF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'intF');
        final columnInformation = D4.getRequiredArg<$tom_core_server_15.TomColumnInformation>(positional, 1, 'columnInformation', 'intF');
        return t.intF(fieldName, columnInformation);
      },
      'doubleF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler');
        D4.requireMinArgs(positional, 2, 'doubleF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'doubleF');
        final columnInformation = D4.getRequiredArg<$tom_core_server_15.TomColumnInformation>(positional, 1, 'columnInformation', 'doubleF');
        return t.doubleF(fieldName, columnInformation);
      },
      'boolF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler');
        D4.requireMinArgs(positional, 2, 'boolF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'boolF');
        final columnInformation = D4.getRequiredArg<$tom_core_server_15.TomColumnInformation>(positional, 1, 'columnInformation', 'boolF');
        return t.boolF(fieldName, columnInformation);
      },
      'dateTimeF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler');
        D4.requireMinArgs(positional, 2, 'dateTimeF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'dateTimeF');
        final columnInformation = D4.getRequiredArg<$tom_core_server_15.TomColumnInformation>(positional, 1, 'columnInformation', 'dateTimeF');
        return t.dateTimeF(fieldName, columnInformation);
      },
      'dateF': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomQuerySentenceCompiler>(target, 'TomQuerySentenceCompiler');
        D4.requireMinArgs(positional, 2, 'dateF');
        final fieldName = D4.getRequiredArg<String>(positional, 0, 'fieldName', 'dateF');
        final columnInformation = D4.getRequiredArg<$tom_core_server_15.TomColumnInformation>(positional, 1, 'columnInformation', 'dateF');
        return t.dateF(fieldName, columnInformation);
      },
    },
    constructorSignatures: {
      '': 'TomQuerySentenceCompiler(List<Type> types)',
    },
    methodSignatures: {
      'getColumnInformation': 'List<TomColumnInformation> getColumnInformation()',
      'determineColumn': 'TomColumnInformation determineColumn(String name)',
      'compileQuerySentence': 'TomQuery compileQuerySentence(String qs)',
      'isNull': 'TomOperator<TomDbBool> isNull(TomOperator<T> what)',
      'isNotNull': 'TomOperator<TomDbBool> isNotNull(TomOperator<T> what)',
      'isIn': 'TomOperator<TomDbBool> isIn(TomOperator<T> what, List<TomOperator<T>> choices)',
      'between': 'TomOperator<TomDbBool> between(TomOperator<T> what, List<TomOperator<T>> betweenLimits)',
      'like': 'TomOperator<TomDbBool> like(TomOperator<TomDbString> text, TomOperator<TomDbString> test)',
      'notLike': 'TomOperator<TomDbBool> notLike(TomOperator<TomDbString> text, TomOperator<TomDbString> test)',
      'regexp': 'TomOperator<TomDbBool> regexp(TomOperator<TomDbString> text, TomOperator<TomDbString> test)',
      'group': 'TomOperator<T> group(TomOperator<T> operant)',
      'eq': 'TomOperator<TomDbBool> eq(TomOperator<T> operant1, TomOperator<T> operant2)',
      'neq': 'TomOperator<TomDbBool> neq(TomOperator<T> operant1, TomOperator<T> operant2)',
      'lt': 'TomOperator<TomDbBool> lt(TomOperator<T> operant1, TomOperator<T> operant2)',
      'lte': 'TomOperator<TomDbBool> lte(TomOperator<T> operant1, TomOperator<T> operant2)',
      'gt': 'TomOperator<TomDbBool> gt(TomOperator<T> operant1, TomOperator<T> operant2)',
      'gte': 'TomOperator<TomDbBool> gte(TomOperator<T> operant1, TomOperator<T> operant2)',
      'not': 'TomOperator<TomDbBool> not(TomOperator<TomDbBool> operant1)',
      'and': 'TomOperator<TomDbBool> and(List<TomOperator<TomDbBool>> operant1)',
      'or': 'TomOperator<TomDbBool> or(List<TomOperator<TomDbBool>> operant1)',
      'text': 'TomOperator<TomDbString> text(String text)',
      'intOp': 'TomOperator<TomDbInt> intOp(int value)',
      'doubleOp': 'TomOperator<TomDbDouble> doubleOp(double value)',
      'boolOp': 'TomOperator<TomDbBool> boolOp(bool value)',
      'dateTimeOp': 'TomOperator<TomDbDateTime> dateTimeOp(DateTime value)',
      'dateOp': 'TomOperator<TomDbDate> dateOp(DateTime value)',
      'p': 'TomOperator<T> p(String parameterName)',
      'textF': 'TomOperator<TomDbString> textF(String fieldName, TomColumnInformation columnInformation)',
      'intF': 'TomOperator<TomDbInt> intF(String fieldName, TomColumnInformation columnInformation)',
      'doubleF': 'TomOperator<TomDbDouble> doubleF(String fieldName, TomColumnInformation columnInformation)',
      'boolF': 'TomOperator<TomDbBool> boolF(String fieldName, TomColumnInformation columnInformation)',
      'dateTimeF': 'TomOperator<TomDbDateTime> dateTimeF(String fieldName, TomColumnInformation columnInformation)',
      'dateF': 'TomOperator<TomDbDate> dateF(String fieldName, TomColumnInformation columnInformation)',
    },
    getterSignatures: {
      'types': 'List<Type> get types',
      'persistenceInfo': 'List<TomTypePersistenceInfo> get persistenceInfo',
    },
    setterSignatures: {
      'types': 'set types(List<Type> value)',
    },
  );
}

// =============================================================================
// TomRequestId Bridge
// =============================================================================

BridgedClass _createTomRequestIdBridge() {
  return BridgedClass(
    nativeType: TomRequestId,
    name: 'TomRequestId',
    isAssignable: (v) => v is TomRequestId,
    constructors: {
      '': (visitor, positional, named) {
        return TomRequestId();
      },
    },
    getters: {
      'uuid': (visitor, target) => D4.validateTarget<TomRequestId>(target, 'TomRequestId').uuid,
    },
    setters: {
      'uuid': (visitor, target, value) => 
        D4.validateTarget<TomRequestId>(target, 'TomRequestId').uuid = D4.extractBridgedArg<String>(value, 'uuid'),
    },
    methods: {
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomRequestId>(target, 'TomRequestId');
        return t.toString();
      },
    },
    constructorSignatures: {
      '': 'TomRequestId()',
    },
    methodSignatures: {
      'toString': 'String toString()',
    },
    getterSignatures: {
      'uuid': 'String get uuid',
    },
    setterSignatures: {
      'uuid': 'set uuid(dynamic value)',
    },
  );
}

// =============================================================================
// TomRequestLogInfo Bridge
// =============================================================================

BridgedClass _createTomRequestLogInfoBridge() {
  return BridgedClass(
    nativeType: TomRequestLogInfo,
    name: 'TomRequestLogInfo',
    isAssignable: (v) => v is TomRequestLogInfo,
    constructors: {
      '': (visitor, positional, named) {
        return TomRequestLogInfo();
      },
    },
    getters: {
      'hasBeenLogged': (visitor, target) => D4.validateTarget<TomRequestLogInfo>(target, 'TomRequestLogInfo').hasBeenLogged,
      'shouldBeLogged': (visitor, target) => D4.validateTarget<TomRequestLogInfo>(target, 'TomRequestLogInfo').shouldBeLogged,
    },
    setters: {
      'hasBeenLogged': (visitor, target, value) => 
        D4.validateTarget<TomRequestLogInfo>(target, 'TomRequestLogInfo').hasBeenLogged = D4.extractBridgedArg<bool>(value, 'hasBeenLogged'),
      'shouldBeLogged': (visitor, target, value) => 
        D4.validateTarget<TomRequestLogInfo>(target, 'TomRequestLogInfo').shouldBeLogged = D4.extractBridgedArg<bool>(value, 'shouldBeLogged'),
    },
    methods: {
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomRequestLogInfo>(target, 'TomRequestLogInfo');
        return t.toString();
      },
    },
    staticGetters: {
      'contextName': (visitor) => TomRequestLogInfo.contextName,
    },
    constructorSignatures: {
      '': 'TomRequestLogInfo()',
    },
    methodSignatures: {
      'toString': 'String toString()',
    },
    getterSignatures: {
      'hasBeenLogged': 'bool get hasBeenLogged',
      'shouldBeLogged': 'bool get shouldBeLogged',
    },
    setterSignatures: {
      'hasBeenLogged': 'set hasBeenLogged(dynamic value)',
      'shouldBeLogged': 'set shouldBeLogged(dynamic value)',
    },
    staticGetterSignatures: {
      'contextName': 'String get contextName',
    },
  );
}

// =============================================================================
// TomServer Bridge
// =============================================================================

BridgedClass _createTomServerBridge() {
  return BridgedClass(
    nativeType: TomServer,
    name: 'TomServer',
    isAssignable: (v) => v is TomServer,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomServer');
        final configuration = D4.getRequiredArg<$tom_core_server_3.TomBaseServerConfiguration>(positional, 0, 'configuration', 'TomServer');
        return TomServer(configuration);
      },
    },
    getters: {
      'configuration': (visitor, target) => D4.validateTarget<TomServer>(target, 'TomServer').configuration,
      'securityContext': (visitor, target) => D4.validateTarget<TomServer>(target, 'TomServer').securityContext,
      'router': (visitor, target) => D4.validateTarget<TomServer>(target, 'TomServer').router,
      'errorHandler': (visitor, target) => D4.validateTarget<TomServer>(target, 'TomServer').errorHandler,
      'authenticationErrorHandler': (visitor, target) => D4.validateTarget<TomServer>(target, 'TomServer').authenticationErrorHandler,
      'loggingMiddleware': (visitor, target) => D4.validateTarget<TomServer>(target, 'TomServer').loggingMiddleware,
    },
    setters: {
      'configuration': (visitor, target, value) => 
        D4.validateTarget<TomServer>(target, 'TomServer').configuration = D4.extractBridgedArg<$tom_core_server_3.TomBaseServerConfiguration>(value, 'configuration'),
      'securityContext': (visitor, target, value) => 
        D4.validateTarget<TomServer>(target, 'TomServer').securityContext = D4.extractBridgedArgOrNull<SecurityContext>(value, 'securityContext'),
      'router': (visitor, target, value) => 
        D4.validateTarget<TomServer>(target, 'TomServer').router = D4.extractBridgedArgOrNull<$shelf_router_1.Router>(value, 'router'),
      'errorHandler': (visitor, target, value) {
        final errorHandlerRaw = D4.extractBridgedArgOrNull<dynamic>(value, 'errorHandler');
        D4.validateTarget<TomServer>(target, 'TomServer').errorHandler = ($shelf_3.Request p0, Object p1, StackTrace p2) { return D4.callInterpreterCallback(visitor!, errorHandlerRaw, [p0, p1, p2]) as $shelf_4.Response?; };
      },
      'authenticationErrorHandler': (visitor, target, value) {
        final authenticationErrorHandlerRaw = D4.extractBridgedArgOrNull<dynamic>(value, 'authenticationErrorHandler');
        D4.validateTarget<TomServer>(target, 'TomServer').authenticationErrorHandler = authenticationErrorHandlerRaw == null ? null : ($shelf_3.Request p0, Object p1, StackTrace p2) { return D4.callInterpreterCallback(visitor!, authenticationErrorHandlerRaw, [p0, p1, p2]) as $shelf_4.Response?; };
      },
      'loggingMiddleware': (visitor, target, value) {
        final loggingMiddlewareRaw = D4.extractBridgedArgOrNull<dynamic>(value, 'loggingMiddleware');
        D4.validateTarget<TomServer>(target, 'TomServer').loggingMiddleware = (FutureOr<$shelf_4.Response> Function($shelf_3.Request) p0) { return D4.callInterpreterCallback(visitor!, loggingMiddlewareRaw, [p0]) as FutureOr<$shelf_4.Response> Function($shelf_3.Request); };
      },
    },
    methods: {
      'start': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomServer>(target, 'TomServer');
        t.start();
        return null;
      },
    },
    constructorSignatures: {
      '': 'TomServer(TomBaseServerConfiguration configuration)',
    },
    methodSignatures: {
      'start': 'void start()',
    },
    getterSignatures: {
      'configuration': 'TomBaseServerConfiguration get configuration',
      'securityContext': 'SecurityContext? get securityContext',
      'router': 'Router? get router',
      'errorHandler': 'Response? Function(Request, Object, StackTrace) get errorHandler',
      'authenticationErrorHandler': 'Response? Function(Request, Object, StackTrace)? get authenticationErrorHandler',
      'loggingMiddleware': 'Middleware get loggingMiddleware',
    },
    setterSignatures: {
      'configuration': 'set configuration(dynamic value)',
      'securityContext': 'set securityContext(dynamic value)',
      'router': 'set router(dynamic value)',
      'errorHandler': 'set errorHandler(dynamic value)',
      'authenticationErrorHandler': 'set authenticationErrorHandler(dynamic value)',
      'loggingMiddleware': 'set loggingMiddleware(dynamic value)',
    },
  );
}

// =============================================================================
// TomTransactionException Bridge
// =============================================================================

BridgedClass _createTomTransactionExceptionBridge() {
  return BridgedClass(
    nativeType: TomTransactionException,
    name: 'TomTransactionException',
    isAssignable: (v) => v is TomTransactionException,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'TomTransactionException');
        final key = D4.getRequiredArg<String>(positional, 0, 'key', 'TomTransactionException');
        final defaultUserMessage = D4.getRequiredArg<String>(positional, 1, 'defaultUserMessage', 'TomTransactionException');
        final parameters = D4.coerceMapOrNull<String, Object?>(named['parameters'], 'parameters');
        final stack = D4.getOptionalNamedArg<Object?>(named, 'stack');
        final rootException = D4.getOptionalNamedArg<Object?>(named, 'rootException');
        final autoLog = D4.getNamedArgWithDefault<bool>(named, 'autoLog', false);
        return TomTransactionException(key, defaultUserMessage, parameters: parameters, stack: stack, rootException: rootException, autoLog: autoLog);
      },
    },
    getters: {
      'isolateName': (visitor, target) => D4.validateTarget<TomTransactionException>(target, 'TomTransactionException').isolateName,
      'clientThrow': (visitor, target) => D4.validateTarget<TomTransactionException>(target, 'TomTransactionException').clientThrow,
      'autoLog': (visitor, target) => D4.validateTarget<TomTransactionException>(target, 'TomTransactionException').autoLog,
      'serverCallError': (visitor, target) => D4.validateTarget<TomTransactionException>(target, 'TomTransactionException').serverCallError,
      'newField': (visitor, target) => D4.validateTarget<TomTransactionException>(target, 'TomTransactionException').newField,
      'logRepresentation': (visitor, target) => D4.validateTarget<TomTransactionException>(target, 'TomTransactionException').logRepresentation,
      'uuid': (visitor, target) => D4.validateTarget<TomTransactionException>(target, 'TomTransactionException').uuid,
      'requestUuid': (visitor, target) => D4.validateTarget<TomTransactionException>(target, 'TomTransactionException').requestUuid,
      'timeStamp': (visitor, target) => D4.validateTarget<TomTransactionException>(target, 'TomTransactionException').timeStamp,
      'key': (visitor, target) => D4.validateTarget<TomTransactionException>(target, 'TomTransactionException').key,
      'defaultUserMessage': (visitor, target) => D4.validateTarget<TomTransactionException>(target, 'TomTransactionException').defaultUserMessage,
      'parameters': (visitor, target) => D4.validateTarget<TomTransactionException>(target, 'TomTransactionException').parameters,
      'stack': (visitor, target) => D4.validateTarget<TomTransactionException>(target, 'TomTransactionException').stack,
      'rootException': (visitor, target) => D4.validateTarget<TomTransactionException>(target, 'TomTransactionException').rootException,
      'stackTrace': (visitor, target) => D4.validateTarget<TomTransactionException>(target, 'TomTransactionException').stackTrace,
    },
    setters: {
      'isolateName': (visitor, target, value) => 
        D4.validateTarget<TomTransactionException>(target, 'TomTransactionException').isolateName = D4.extractBridgedArg<String>(value, 'isolateName'),
      'clientThrow': (visitor, target, value) => 
        D4.validateTarget<TomTransactionException>(target, 'TomTransactionException').clientThrow = D4.extractBridgedArg<bool>(value, 'clientThrow'),
      'autoLog': (visitor, target, value) => 
        D4.validateTarget<TomTransactionException>(target, 'TomTransactionException').autoLog = D4.extractBridgedArg<bool>(value, 'autoLog'),
      'serverCallError': (visitor, target, value) => 
        D4.validateTarget<TomTransactionException>(target, 'TomTransactionException').serverCallError = D4.extractBridgedArgOrNull<$tom_core_kernel_4.TomServerCallError>(value, 'serverCallError'),
      'newField': (visitor, target, value) => 
        D4.validateTarget<TomTransactionException>(target, 'TomTransactionException').newField = D4.extractBridgedArgOrNull<String>(value, 'newField'),
      'uuid': (visitor, target, value) => 
        D4.validateTarget<TomTransactionException>(target, 'TomTransactionException').uuid = D4.extractBridgedArg<String>(value, 'uuid'),
      'requestUuid': (visitor, target, value) => 
        D4.validateTarget<TomTransactionException>(target, 'TomTransactionException').requestUuid = D4.extractBridgedArgOrNull<String>(value, 'requestUuid'),
      'timeStamp': (visitor, target, value) => 
        D4.validateTarget<TomTransactionException>(target, 'TomTransactionException').timeStamp = D4.extractBridgedArg<DateTime>(value, 'timeStamp'),
      'key': (visitor, target, value) => 
        D4.validateTarget<TomTransactionException>(target, 'TomTransactionException').key = D4.extractBridgedArg<String>(value, 'key'),
      'defaultUserMessage': (visitor, target, value) => 
        D4.validateTarget<TomTransactionException>(target, 'TomTransactionException').defaultUserMessage = D4.extractBridgedArg<String>(value, 'defaultUserMessage'),
      'stack': (visitor, target, value) => 
        D4.validateTarget<TomTransactionException>(target, 'TomTransactionException').stack = D4.extractBridgedArgOrNull<Object>(value, 'stack'),
      'rootException': (visitor, target, value) => 
        D4.validateTarget<TomTransactionException>(target, 'TomTransactionException').rootException = D4.extractBridgedArgOrNull<Object>(value, 'rootException'),
      'stackTrace': (visitor, target, value) => 
        D4.validateTarget<TomTransactionException>(target, 'TomTransactionException').stackTrace = D4.extractBridgedArg<String>(value, 'stackTrace'),
    },
    methods: {
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomTransactionException>(target, 'TomTransactionException');
        return t.toString();
      },
      'printStackTrace': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomTransactionException>(target, 'TomTransactionException');
        final depth = D4.getOptionalArgWithDefault<int>(positional, 0, 'depth', -1);
        t.printStackTrace(depth);
        return null;
      },
    },
    constructorSignatures: {
      '': 'TomTransactionException(String key, String defaultUserMessage, {Map<String, Object?>? parameters, Object? stack, Object? rootException, bool autoLog = false})',
    },
    methodSignatures: {
      'toString': 'String toString()',
      'printStackTrace': 'void printStackTrace([int depth = -1])',
    },
    getterSignatures: {
      'isolateName': 'String get isolateName',
      'clientThrow': 'bool get clientThrow',
      'autoLog': 'bool get autoLog',
      'serverCallError': 'TomServerCallError? get serverCallError',
      'newField': 'String? get newField',
      'logRepresentation': 'String get logRepresentation',
      'uuid': 'String get uuid',
      'requestUuid': 'String? get requestUuid',
      'timeStamp': 'DateTime get timeStamp',
      'key': 'String get key',
      'defaultUserMessage': 'String get defaultUserMessage',
      'parameters': 'Map<String, Object?>? get parameters',
      'stack': 'Object? get stack',
      'rootException': 'Object? get rootException',
      'stackTrace': 'String get stackTrace',
    },
    setterSignatures: {
      'isolateName': 'set isolateName(String value)',
      'clientThrow': 'set clientThrow(bool value)',
      'autoLog': 'set autoLog(bool value)',
      'serverCallError': 'set serverCallError(TomServerCallError? value)',
      'newField': 'set newField(String? value)',
      'uuid': 'set uuid(String value)',
      'requestUuid': 'set requestUuid(String? value)',
      'timeStamp': 'set timeStamp(DateTime value)',
      'key': 'set key(String value)',
      'defaultUserMessage': 'set defaultUserMessage(String value)',
      'parameters': 'set parameters(Map<String, Object?>? value)',
      'stack': 'set stack(Object? value)',
      'rootException': 'set rootException(Object? value)',
      'stackTrace': 'set stackTrace(String value)',
    },
  );
}

// =============================================================================
// TomTransactionParticipant Bridge
// =============================================================================

BridgedClass _createTomTransactionParticipantBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_16.TomTransactionParticipant,
    name: 'TomTransactionParticipant',
    isAssignable: (v) => v is $tom_core_server_16.TomTransactionParticipant,
    constructors: {
    },
    methods: {
      'getParticipantId': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_16.TomTransactionParticipant>(target, 'TomTransactionParticipant');
        return t.getParticipantId();
      },
      'startTransaction': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_16.TomTransactionParticipant>(target, 'TomTransactionParticipant');
        return t.startTransaction();
      },
      'endTransaction': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_16.TomTransactionParticipant>(target, 'TomTransactionParticipant');
        return t.endTransaction();
      },
      'commit': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_16.TomTransactionParticipant>(target, 'TomTransactionParticipant');
        return t.commit();
      },
      'rollback': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_16.TomTransactionParticipant>(target, 'TomTransactionParticipant');
        return t.rollback();
      },
    },
    methodSignatures: {
      'getParticipantId': 'String getParticipantId()',
      'startTransaction': 'Future<bool> startTransaction()',
      'endTransaction': 'Future<bool> endTransaction()',
      'commit': 'Future<bool> commit()',
      'rollback': 'Future<void> rollback()',
    },
  );
}

// =============================================================================
// TomTransaction Bridge
// =============================================================================

BridgedClass _createTomTransactionBridge() {
  return BridgedClass(
    nativeType: $tom_core_server_16.TomTransaction,
    name: 'TomTransaction',
    isAssignable: (v) => v is $tom_core_server_16.TomTransaction,
    constructors: {
    },
    getters: {
      'isReadOnly': (visitor, target) => D4.validateTarget<$tom_core_server_16.TomTransaction>(target, 'TomTransaction').isReadOnly,
      'isRunning': (visitor, target) => D4.validateTarget<$tom_core_server_16.TomTransaction>(target, 'TomTransaction').isRunning,
    },
    methods: {
      'registerParticipant': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_16.TomTransaction>(target, 'TomTransaction');
        D4.requireMinArgs(positional, 1, 'registerParticipant');
        final ttp = D4.getRequiredArg<$tom_core_server_16.TomTransactionParticipant>(positional, 0, 'ttp', 'registerParticipant');
        t.registerParticipant(ttp);
        return null;
      },
      'commitTransaction': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_16.TomTransaction>(target, 'TomTransaction');
        return t.commitTransaction();
      },
      'rollbackTransaction': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_core_server_16.TomTransaction>(target, 'TomTransaction');
        return t.rollbackTransaction();
      },
    },
    methodSignatures: {
      'registerParticipant': 'void registerParticipant(TomTransactionParticipant ttp)',
      'commitTransaction': 'Future<bool> commitTransaction()',
      'rollbackTransaction': 'Future<bool> rollbackTransaction()',
    },
    getterSignatures: {
      'isReadOnly': 'bool get isReadOnly',
      'isRunning': 'bool get isRunning',
    },
  );
}

// =============================================================================
// TomTransactionManager Bridge
// =============================================================================

BridgedClass _createTomTransactionManagerBridge() {
  return BridgedClass(
    nativeType: TomTransactionManager,
    name: 'TomTransactionManager',
    isAssignable: (v) => v is TomTransactionManager,
    constructors: {
    },
    staticGetters: {
      'transactional': (visitor) => TomTransactionManager.transactional,
    },
    staticMethods: {
      'startTransaction': (visitor, positional, named, typeArgs) {
        final isReadOnly = D4.getOptionalArgWithDefault<bool>(positional, 0, 'isReadOnly', false);
        return TomTransactionManager.startTransaction(isReadOnly);
      },
      'getCurrentTransaction': (visitor, positional, named, typeArgs) {
        return TomTransactionManager.getCurrentTransaction();
      },
    },
    staticMethodSignatures: {
      'startTransaction': '(TomTransaction, bool) startTransaction([bool isReadOnly = false])',
      'getCurrentTransaction': 'TomTransaction? getCurrentTransaction()',
    },
    staticGetterSignatures: {
      'transactional': 'bool get transactional',
    },
  );
}

// =============================================================================
// MySQLConnection Bridge
// =============================================================================

BridgedClass _createMySQLConnectionBridge() {
  return BridgedClass(
    nativeType: $mysql_client_1.MySQLConnection,
    name: 'MySQLConnection',
    isAssignable: (v) => v is $mysql_client_1.MySQLConnection,
    constructors: {
    },
    getters: {
      'connected': (visitor, target) => D4.validateTarget<$mysql_client_1.MySQLConnection>(target, 'MySQLConnection').connected,
    },
    methods: {
      'onClose': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.MySQLConnection>(target, 'MySQLConnection');
        D4.requireMinArgs(positional, 1, 'onClose');
        if (positional.isEmpty) {
          throw ArgumentError('onClose: Missing required argument "callback" at position 0');
        }
        final callbackRaw = positional[0];
        t.onClose(() { D4.callInterpreterCallback(visitor!, callbackRaw, []); });
        return null;
      },
      'connect': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.MySQLConnection>(target, 'MySQLConnection');
        final timeoutMs = D4.getNamedArgWithDefault<int>(named, 'timeoutMs', 10000);
        return t.connect(timeoutMs: timeoutMs);
      },
      'execute': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.MySQLConnection>(target, 'MySQLConnection');
        D4.requireMinArgs(positional, 1, 'execute');
        final query = D4.getRequiredArg<String>(positional, 0, 'query', 'execute');
        final params = positional.length > 1
            ? D4.coerceMapOrNull<String, dynamic>(positional[1], 'params')
            : null;
        final iterable = D4.getOptionalArgWithDefault<bool>(positional, 2, 'iterable', false);
        return t.execute(query, params, iterable);
      },
      'transactional': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.MySQLConnection>(target, 'MySQLConnection');
        D4.requireMinArgs(positional, 1, 'transactional');
        if (positional.isEmpty) {
          throw ArgumentError('transactional: Missing required argument "callback" at position 0');
        }
        final callbackRaw = positional[0];
        return t.transactional(($mysql_client_1.MySQLConnection p0) { return D4.callInterpreterCallback(visitor!, callbackRaw, [p0]) as FutureOr<Object>; });
      },
      'prepare': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.MySQLConnection>(target, 'MySQLConnection');
        D4.requireMinArgs(positional, 1, 'prepare');
        final query = D4.getRequiredArg<String>(positional, 0, 'query', 'prepare');
        final iterable = D4.getOptionalArgWithDefault<bool>(positional, 1, 'iterable', false);
        return t.prepare(query, iterable);
      },
      'close': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.MySQLConnection>(target, 'MySQLConnection');
        return t.close();
      },
    },
    staticMethods: {
      'createConnection': (visitor, positional, named, typeArgs) {
        final host = D4.getRequiredNamedArg<dynamic>(named, 'host', 'createConnection');
        final port = D4.getRequiredNamedArg<int>(named, 'port', 'createConnection');
        final userName = D4.getRequiredNamedArg<String>(named, 'userName', 'createConnection');
        final password = D4.getRequiredNamedArg<String>(named, 'password', 'createConnection');
        final secure = D4.getNamedArgWithDefault<bool>(named, 'secure', true);
        final databaseName = D4.getOptionalNamedArg<String?>(named, 'databaseName');
        final collation = D4.getNamedArgWithDefault<String>(named, 'collation', 'utf8mb4_general_ci');
        return $mysql_client_1.MySQLConnection.createConnection(host: host, port: port, userName: userName, password: password, secure: secure, databaseName: databaseName, collation: collation);
      },
    },
    methodSignatures: {
      'onClose': 'void onClose(void Function() callback)',
      'connect': 'Future<void> connect({int timeoutMs = 10000})',
      'execute': 'Future<IResultSet> execute(String query, [Map<String, dynamic>? params, bool iterable = false])',
      'transactional': 'Future<T> transactional(FutureOr<T> Function(MySQLConnection conn) callback)',
      'prepare': 'Future<PreparedStmt> prepare(String query, [bool iterable = false])',
      'close': 'Future<void> close()',
    },
    getterSignatures: {
      'connected': 'bool get connected',
    },
    staticMethodSignatures: {
      'createConnection': 'Future<MySQLConnection> createConnection({required dynamic host, required int port, required String userName, required String password, bool secure = true, String? databaseName, String collation = \'utf8mb4_general_ci\'})',
    },
  );
}

// =============================================================================
// IResultSet Bridge
// =============================================================================

BridgedClass _createIResultSetBridge() {
  return BridgedClass(
    nativeType: $mysql_client_1.IResultSet,
    name: 'IResultSet',
    isAssignable: (v) => v is $mysql_client_1.IResultSet,
    constructors: {
    },
    getters: {
      'numOfColumns': (visitor, target) => D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet').numOfColumns,
      'numOfRows': (visitor, target) => D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet').numOfRows,
      'affectedRows': (visitor, target) => D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet').affectedRows,
      'lastInsertID': (visitor, target) => D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet').lastInsertID,
      'next': (visitor, target) => D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet').next,
      'iterator': (visitor, target) => D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet').iterator,
      'current': (visitor, target) => D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet').current,
      'rows': (visitor, target) => D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet').rows,
      'cols': (visitor, target) => D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet').cols,
      'rowsStream': (visitor, target) => D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet').rowsStream,
      'length': (visitor, target) => D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet').length,
      'isEmpty': (visitor, target) => D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet').isEmpty,
      'isNotEmpty': (visitor, target) => D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet').isNotEmpty,
      'first': (visitor, target) => D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet').first,
      'last': (visitor, target) => D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet').last,
      'single': (visitor, target) => D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet').single,
    },
    setters: {
      'next': (visitor, target, value) => 
        D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet').next = D4.extractBridgedArgOrNull<$mysql_client_1.IResultSet>(value, 'next'),
    },
    methods: {
      'moveNext': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet');
        return t.moveNext();
      },
      'cast': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet');
        return t.cast();
      },
      'followedBy': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet');
        D4.requireMinArgs(positional, 1, 'followedBy');
        if (positional.isEmpty) {
          throw ArgumentError('followedBy: Missing required argument "other" at position 0');
        }
        final other = D4.coerceList<$mysql_client_1.IResultSet>(positional[0], 'other');
        return t.followedBy(other);
      },
      'map': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet');
        D4.requireMinArgs(positional, 1, 'map');
        if (positional.isEmpty) {
          throw ArgumentError('map: Missing required argument "toElement" at position 0');
        }
        final toElementRaw = positional[0];
        return t.map(($mysql_client_1.IResultSet p0) { return D4.castCallbackResult<dynamic>(D4.callInterpreterCallback(visitor!, toElementRaw, [p0])); });
      },
      'where': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet');
        D4.requireMinArgs(positional, 1, 'where');
        if (positional.isEmpty) {
          throw ArgumentError('where: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        return t.where(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; });
      },
      'whereType': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet');
        return t.whereType();
      },
      'expand': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet');
        D4.requireMinArgs(positional, 1, 'expand');
        if (positional.isEmpty) {
          throw ArgumentError('expand: Missing required argument "toElements" at position 0');
        }
        final toElementsRaw = positional[0];
        return t.expand(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, toElementsRaw, [p0]) as Iterable<dynamic>; });
      },
      'contains': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet');
        D4.requireMinArgs(positional, 1, 'contains');
        final element = D4.getRequiredArg<Object?>(positional, 0, 'element', 'contains');
        return t.contains(element);
      },
      'forEach': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet');
        D4.requireMinArgs(positional, 1, 'forEach');
        if (positional.isEmpty) {
          throw ArgumentError('forEach: Missing required argument "action" at position 0');
        }
        final actionRaw = positional[0];
        t.forEach(($mysql_client_1.IResultSet p0) { D4.callInterpreterCallback(visitor!, actionRaw, [p0]); });
        return null;
      },
      'reduce': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet');
        D4.requireMinArgs(positional, 1, 'reduce');
        if (positional.isEmpty) {
          throw ArgumentError('reduce: Missing required argument "combine" at position 0');
        }
        final combineRaw = positional[0];
        return t.reduce(($mysql_client_1.IResultSet p0, $mysql_client_1.IResultSet p1) { return D4.callInterpreterCallback(visitor!, combineRaw, [p0, p1]) as $mysql_client_1.IResultSet; });
      },
      'fold': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet');
        D4.requireMinArgs(positional, 2, 'fold');
        final initialValue = D4.getRequiredArg<dynamic>(positional, 0, 'initialValue', 'fold');
        if (positional.length <= 1) {
          throw ArgumentError('fold: Missing required argument "combine" at position 1');
        }
        final combineRaw = positional[1];
        return t.fold(initialValue, (dynamic p0, $mysql_client_1.IResultSet p1) { return D4.castCallbackResult<dynamic>(D4.callInterpreterCallback(visitor!, combineRaw, [p0, p1])); });
      },
      'every': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet');
        D4.requireMinArgs(positional, 1, 'every');
        if (positional.isEmpty) {
          throw ArgumentError('every: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        return t.every(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; });
      },
      'join': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet');
        final separator = D4.getOptionalArgWithDefault<String>(positional, 0, 'separator', "");
        return t.join(separator);
      },
      'any': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet');
        D4.requireMinArgs(positional, 1, 'any');
        if (positional.isEmpty) {
          throw ArgumentError('any: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        return t.any(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; });
      },
      'toList': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet');
        final growable = D4.getNamedArgWithDefault<bool>(named, 'growable', true);
        return t.toList(growable: growable);
      },
      'toSet': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet');
        return t.toSet();
      },
      'take': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet');
        D4.requireMinArgs(positional, 1, 'take');
        final count = D4.getRequiredArg<int>(positional, 0, 'count', 'take');
        return t.take(count);
      },
      'takeWhile': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet');
        D4.requireMinArgs(positional, 1, 'takeWhile');
        if (positional.isEmpty) {
          throw ArgumentError('takeWhile: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        return t.takeWhile(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; });
      },
      'skip': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet');
        D4.requireMinArgs(positional, 1, 'skip');
        final count = D4.getRequiredArg<int>(positional, 0, 'count', 'skip');
        return t.skip(count);
      },
      'skipWhile': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet');
        D4.requireMinArgs(positional, 1, 'skipWhile');
        if (positional.isEmpty) {
          throw ArgumentError('skipWhile: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        return t.skipWhile(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; });
      },
      'firstWhere': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet');
        D4.requireMinArgs(positional, 1, 'firstWhere');
        if (positional.isEmpty) {
          throw ArgumentError('firstWhere: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        final orElseRaw = named['orElse'];
        return t.firstWhere(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; }, orElse: orElseRaw == null ? null : () { return D4.callInterpreterCallback(visitor!, orElseRaw, []) as $mysql_client_1.IResultSet; });
      },
      'lastWhere': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet');
        D4.requireMinArgs(positional, 1, 'lastWhere');
        if (positional.isEmpty) {
          throw ArgumentError('lastWhere: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        final orElseRaw = named['orElse'];
        return t.lastWhere(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; }, orElse: orElseRaw == null ? null : () { return D4.callInterpreterCallback(visitor!, orElseRaw, []) as $mysql_client_1.IResultSet; });
      },
      'singleWhere': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet');
        D4.requireMinArgs(positional, 1, 'singleWhere');
        if (positional.isEmpty) {
          throw ArgumentError('singleWhere: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        final orElseRaw = named['orElse'];
        return t.singleWhere(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; }, orElse: orElseRaw == null ? null : () { return D4.callInterpreterCallback(visitor!, orElseRaw, []) as $mysql_client_1.IResultSet; });
      },
      'elementAt': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet');
        D4.requireMinArgs(positional, 1, 'elementAt');
        final index = D4.getRequiredArg<int>(positional, 0, 'index', 'elementAt');
        return t.elementAt(index);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.IResultSet>(target, 'IResultSet');
        return t.toString();
      },
    },
    methodSignatures: {
      'moveNext': 'bool moveNext()',
      'cast': 'Iterable<R> cast()',
      'followedBy': 'Iterable<IResultSet> followedBy(Iterable<IResultSet> other)',
      'map': 'Iterable<T> map(T Function(IResultSet) toElement)',
      'where': 'Iterable<IResultSet> where(bool Function(IResultSet) test)',
      'whereType': 'Iterable<T> whereType()',
      'expand': 'Iterable<T> expand(Iterable<T> Function(IResultSet) toElements)',
      'contains': 'bool contains(Object? element)',
      'forEach': 'void forEach(void Function(IResultSet) action)',
      'reduce': 'IResultSet reduce(IResultSet Function(IResultSet, IResultSet) combine)',
      'fold': 'T fold(T initialValue, T Function(T, IResultSet) combine)',
      'every': 'bool every(bool Function(IResultSet) test)',
      'join': 'String join([String separator = ""])',
      'any': 'bool any(bool Function(IResultSet) test)',
      'toList': 'List<IResultSet> toList({bool growable = true})',
      'toSet': 'Set<IResultSet> toSet()',
      'take': 'Iterable<IResultSet> take(int count)',
      'takeWhile': 'Iterable<IResultSet> takeWhile(bool Function(IResultSet) test)',
      'skip': 'Iterable<IResultSet> skip(int count)',
      'skipWhile': 'Iterable<IResultSet> skipWhile(bool Function(IResultSet) test)',
      'firstWhere': 'IResultSet firstWhere(bool Function(IResultSet) test, {IResultSet Function()? orElse})',
      'lastWhere': 'IResultSet lastWhere(bool Function(IResultSet) test, {IResultSet Function()? orElse})',
      'singleWhere': 'IResultSet singleWhere(bool Function(IResultSet) test, {IResultSet Function()? orElse})',
      'elementAt': 'IResultSet elementAt(int index)',
      'toString': 'String toString()',
    },
    getterSignatures: {
      'numOfColumns': 'int get numOfColumns',
      'numOfRows': 'int get numOfRows',
      'affectedRows': 'BigInt get affectedRows',
      'lastInsertID': 'BigInt get lastInsertID',
      'next': 'IResultSet? get next',
      'iterator': 'Iterator<IResultSet> get iterator',
      'current': 'IResultSet get current',
      'rows': 'Iterable<ResultSetRow> get rows',
      'cols': 'Iterable<ResultSetColumn> get cols',
      'rowsStream': 'Stream<ResultSetRow> get rowsStream',
      'length': 'int get length',
      'isEmpty': 'bool get isEmpty',
      'isNotEmpty': 'bool get isNotEmpty',
      'first': 'IResultSet get first',
      'last': 'IResultSet get last',
      'single': 'IResultSet get single',
    },
    setterSignatures: {
      'next': 'set next(dynamic value)',
    },
  );
}

// =============================================================================
// ResultSet Bridge
// =============================================================================

BridgedClass _createResultSetBridge() {
  return BridgedClass(
    nativeType: ResultSet,
    name: 'ResultSet',
    isAssignable: (v) => v is ResultSet,
    constructors: {
    },
    getters: {
      'numOfColumns': (visitor, target) => D4.validateTarget<ResultSet>(target, 'ResultSet').numOfColumns,
      'numOfRows': (visitor, target) => D4.validateTarget<ResultSet>(target, 'ResultSet').numOfRows,
      'affectedRows': (visitor, target) => D4.validateTarget<ResultSet>(target, 'ResultSet').affectedRows,
      'lastInsertID': (visitor, target) => D4.validateTarget<ResultSet>(target, 'ResultSet').lastInsertID,
      'next': (visitor, target) => D4.validateTarget<ResultSet>(target, 'ResultSet').next,
      'iterator': (visitor, target) => D4.validateTarget<ResultSet>(target, 'ResultSet').iterator,
      'current': (visitor, target) => D4.validateTarget<ResultSet>(target, 'ResultSet').current,
      'rows': (visitor, target) => D4.validateTarget<ResultSet>(target, 'ResultSet').rows,
      'cols': (visitor, target) => D4.validateTarget<ResultSet>(target, 'ResultSet').cols,
      'rowsStream': (visitor, target) => D4.validateTarget<ResultSet>(target, 'ResultSet').rowsStream,
      'length': (visitor, target) => D4.validateTarget<ResultSet>(target, 'ResultSet').length,
      'isEmpty': (visitor, target) => D4.validateTarget<ResultSet>(target, 'ResultSet').isEmpty,
      'isNotEmpty': (visitor, target) => D4.validateTarget<ResultSet>(target, 'ResultSet').isNotEmpty,
      'first': (visitor, target) => D4.validateTarget<ResultSet>(target, 'ResultSet').first,
      'last': (visitor, target) => D4.validateTarget<ResultSet>(target, 'ResultSet').last,
      'single': (visitor, target) => D4.validateTarget<ResultSet>(target, 'ResultSet').single,
    },
    setters: {
      'next': (visitor, target, value) => 
        D4.validateTarget<ResultSet>(target, 'ResultSet').next = D4.extractBridgedArgOrNull<$mysql_client_1.IResultSet>(value, 'next'),
    },
    methods: {
      'moveNext': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ResultSet>(target, 'ResultSet');
        return t.moveNext();
      },
      'cast': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ResultSet>(target, 'ResultSet');
        return t.cast();
      },
      'followedBy': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ResultSet>(target, 'ResultSet');
        D4.requireMinArgs(positional, 1, 'followedBy');
        if (positional.isEmpty) {
          throw ArgumentError('followedBy: Missing required argument "other" at position 0');
        }
        final other = D4.coerceList<$mysql_client_1.IResultSet>(positional[0], 'other');
        return t.followedBy(other);
      },
      'map': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ResultSet>(target, 'ResultSet');
        D4.requireMinArgs(positional, 1, 'map');
        if (positional.isEmpty) {
          throw ArgumentError('map: Missing required argument "toElement" at position 0');
        }
        final toElementRaw = positional[0];
        return t.map(($mysql_client_1.IResultSet p0) { return D4.castCallbackResult<dynamic>(D4.callInterpreterCallback(visitor!, toElementRaw, [p0])); });
      },
      'where': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ResultSet>(target, 'ResultSet');
        D4.requireMinArgs(positional, 1, 'where');
        if (positional.isEmpty) {
          throw ArgumentError('where: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        return t.where(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; });
      },
      'whereType': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ResultSet>(target, 'ResultSet');
        return t.whereType();
      },
      'expand': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ResultSet>(target, 'ResultSet');
        D4.requireMinArgs(positional, 1, 'expand');
        if (positional.isEmpty) {
          throw ArgumentError('expand: Missing required argument "toElements" at position 0');
        }
        final toElementsRaw = positional[0];
        return t.expand(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, toElementsRaw, [p0]) as Iterable<dynamic>; });
      },
      'contains': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ResultSet>(target, 'ResultSet');
        D4.requireMinArgs(positional, 1, 'contains');
        final element = D4.getRequiredArg<Object?>(positional, 0, 'element', 'contains');
        return t.contains(element);
      },
      'forEach': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ResultSet>(target, 'ResultSet');
        D4.requireMinArgs(positional, 1, 'forEach');
        if (positional.isEmpty) {
          throw ArgumentError('forEach: Missing required argument "action" at position 0');
        }
        final actionRaw = positional[0];
        t.forEach(($mysql_client_1.IResultSet p0) { D4.callInterpreterCallback(visitor!, actionRaw, [p0]); });
        return null;
      },
      'reduce': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ResultSet>(target, 'ResultSet');
        D4.requireMinArgs(positional, 1, 'reduce');
        if (positional.isEmpty) {
          throw ArgumentError('reduce: Missing required argument "combine" at position 0');
        }
        final combineRaw = positional[0];
        return t.reduce(($mysql_client_1.IResultSet p0, $mysql_client_1.IResultSet p1) { return D4.callInterpreterCallback(visitor!, combineRaw, [p0, p1]) as $mysql_client_1.IResultSet; });
      },
      'fold': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ResultSet>(target, 'ResultSet');
        D4.requireMinArgs(positional, 2, 'fold');
        final initialValue = D4.getRequiredArg<dynamic>(positional, 0, 'initialValue', 'fold');
        if (positional.length <= 1) {
          throw ArgumentError('fold: Missing required argument "combine" at position 1');
        }
        final combineRaw = positional[1];
        return t.fold(initialValue, (dynamic p0, $mysql_client_1.IResultSet p1) { return D4.castCallbackResult<dynamic>(D4.callInterpreterCallback(visitor!, combineRaw, [p0, p1])); });
      },
      'every': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ResultSet>(target, 'ResultSet');
        D4.requireMinArgs(positional, 1, 'every');
        if (positional.isEmpty) {
          throw ArgumentError('every: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        return t.every(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; });
      },
      'join': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ResultSet>(target, 'ResultSet');
        final separator = D4.getOptionalArgWithDefault<String>(positional, 0, 'separator', "");
        return t.join(separator);
      },
      'any': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ResultSet>(target, 'ResultSet');
        D4.requireMinArgs(positional, 1, 'any');
        if (positional.isEmpty) {
          throw ArgumentError('any: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        return t.any(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; });
      },
      'toList': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ResultSet>(target, 'ResultSet');
        final growable = D4.getNamedArgWithDefault<bool>(named, 'growable', true);
        return t.toList(growable: growable);
      },
      'toSet': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ResultSet>(target, 'ResultSet');
        return t.toSet();
      },
      'take': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ResultSet>(target, 'ResultSet');
        D4.requireMinArgs(positional, 1, 'take');
        final count = D4.getRequiredArg<int>(positional, 0, 'count', 'take');
        return t.take(count);
      },
      'takeWhile': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ResultSet>(target, 'ResultSet');
        D4.requireMinArgs(positional, 1, 'takeWhile');
        if (positional.isEmpty) {
          throw ArgumentError('takeWhile: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        return t.takeWhile(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; });
      },
      'skip': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ResultSet>(target, 'ResultSet');
        D4.requireMinArgs(positional, 1, 'skip');
        final count = D4.getRequiredArg<int>(positional, 0, 'count', 'skip');
        return t.skip(count);
      },
      'skipWhile': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ResultSet>(target, 'ResultSet');
        D4.requireMinArgs(positional, 1, 'skipWhile');
        if (positional.isEmpty) {
          throw ArgumentError('skipWhile: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        return t.skipWhile(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; });
      },
      'firstWhere': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ResultSet>(target, 'ResultSet');
        D4.requireMinArgs(positional, 1, 'firstWhere');
        if (positional.isEmpty) {
          throw ArgumentError('firstWhere: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        final orElseRaw = named['orElse'];
        return t.firstWhere(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; }, orElse: orElseRaw == null ? null : () { return D4.callInterpreterCallback(visitor!, orElseRaw, []) as $mysql_client_1.IResultSet; });
      },
      'lastWhere': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ResultSet>(target, 'ResultSet');
        D4.requireMinArgs(positional, 1, 'lastWhere');
        if (positional.isEmpty) {
          throw ArgumentError('lastWhere: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        final orElseRaw = named['orElse'];
        return t.lastWhere(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; }, orElse: orElseRaw == null ? null : () { return D4.callInterpreterCallback(visitor!, orElseRaw, []) as $mysql_client_1.IResultSet; });
      },
      'singleWhere': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ResultSet>(target, 'ResultSet');
        D4.requireMinArgs(positional, 1, 'singleWhere');
        if (positional.isEmpty) {
          throw ArgumentError('singleWhere: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        final orElseRaw = named['orElse'];
        return t.singleWhere(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; }, orElse: orElseRaw == null ? null : () { return D4.callInterpreterCallback(visitor!, orElseRaw, []) as $mysql_client_1.IResultSet; });
      },
      'elementAt': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ResultSet>(target, 'ResultSet');
        D4.requireMinArgs(positional, 1, 'elementAt');
        final index = D4.getRequiredArg<int>(positional, 0, 'index', 'elementAt');
        return t.elementAt(index);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<ResultSet>(target, 'ResultSet');
        return t.toString();
      },
    },
    methodSignatures: {
      'moveNext': 'bool moveNext()',
      'cast': 'Iterable<R> cast()',
      'followedBy': 'Iterable<IResultSet> followedBy(Iterable<IResultSet> other)',
      'map': 'Iterable<T> map(T Function(IResultSet) toElement)',
      'where': 'Iterable<IResultSet> where(bool Function(IResultSet) test)',
      'whereType': 'Iterable<T> whereType()',
      'expand': 'Iterable<T> expand(Iterable<T> Function(IResultSet) toElements)',
      'contains': 'bool contains(Object? element)',
      'forEach': 'void forEach(void Function(IResultSet) action)',
      'reduce': 'IResultSet reduce(IResultSet Function(IResultSet, IResultSet) combine)',
      'fold': 'T fold(T initialValue, T Function(T, IResultSet) combine)',
      'every': 'bool every(bool Function(IResultSet) test)',
      'join': 'String join([String separator = ""])',
      'any': 'bool any(bool Function(IResultSet) test)',
      'toList': 'List<IResultSet> toList({bool growable = true})',
      'toSet': 'Set<IResultSet> toSet()',
      'take': 'Iterable<IResultSet> take(int count)',
      'takeWhile': 'Iterable<IResultSet> takeWhile(bool Function(IResultSet) test)',
      'skip': 'Iterable<IResultSet> skip(int count)',
      'skipWhile': 'Iterable<IResultSet> skipWhile(bool Function(IResultSet) test)',
      'firstWhere': 'IResultSet firstWhere(bool Function(IResultSet) test, {IResultSet Function()? orElse})',
      'lastWhere': 'IResultSet lastWhere(bool Function(IResultSet) test, {IResultSet Function()? orElse})',
      'singleWhere': 'IResultSet singleWhere(bool Function(IResultSet) test, {IResultSet Function()? orElse})',
      'elementAt': 'IResultSet elementAt(int index)',
      'toString': 'String toString()',
    },
    getterSignatures: {
      'numOfColumns': 'int get numOfColumns',
      'numOfRows': 'int get numOfRows',
      'affectedRows': 'BigInt get affectedRows',
      'lastInsertID': 'BigInt get lastInsertID',
      'next': 'IResultSet? get next',
      'iterator': 'Iterator<IResultSet> get iterator',
      'current': 'IResultSet get current',
      'rows': 'Iterable<ResultSetRow> get rows',
      'cols': 'Iterable<ResultSetColumn> get cols',
      'rowsStream': 'Stream<ResultSetRow> get rowsStream',
      'length': 'int get length',
      'isEmpty': 'bool get isEmpty',
      'isNotEmpty': 'bool get isNotEmpty',
      'first': 'IResultSet get first',
      'last': 'IResultSet get last',
      'single': 'IResultSet get single',
    },
    setterSignatures: {
      'next': 'set next(IResultSet? value)',
    },
  );
}

// =============================================================================
// IterableResultSet Bridge
// =============================================================================

BridgedClass _createIterableResultSetBridge() {
  return BridgedClass(
    nativeType: IterableResultSet,
    name: 'IterableResultSet',
    isAssignable: (v) => v is IterableResultSet,
    constructors: {
    },
    getters: {
      'next': (visitor, target) => D4.validateTarget<IterableResultSet>(target, 'IterableResultSet').next,
      'iterator': (visitor, target) => D4.validateTarget<IterableResultSet>(target, 'IterableResultSet').iterator,
      'current': (visitor, target) => D4.validateTarget<IterableResultSet>(target, 'IterableResultSet').current,
      'rowsStream': (visitor, target) => D4.validateTarget<IterableResultSet>(target, 'IterableResultSet').rowsStream,
      'numOfColumns': (visitor, target) => D4.validateTarget<IterableResultSet>(target, 'IterableResultSet').numOfColumns,
      'numOfRows': (visitor, target) => D4.validateTarget<IterableResultSet>(target, 'IterableResultSet').numOfRows,
      'affectedRows': (visitor, target) => D4.validateTarget<IterableResultSet>(target, 'IterableResultSet').affectedRows,
      'lastInsertID': (visitor, target) => D4.validateTarget<IterableResultSet>(target, 'IterableResultSet').lastInsertID,
      'cols': (visitor, target) => D4.validateTarget<IterableResultSet>(target, 'IterableResultSet').cols,
      'rows': (visitor, target) => D4.validateTarget<IterableResultSet>(target, 'IterableResultSet').rows,
      'length': (visitor, target) => D4.validateTarget<IterableResultSet>(target, 'IterableResultSet').length,
      'isEmpty': (visitor, target) => D4.validateTarget<IterableResultSet>(target, 'IterableResultSet').isEmpty,
      'isNotEmpty': (visitor, target) => D4.validateTarget<IterableResultSet>(target, 'IterableResultSet').isNotEmpty,
      'first': (visitor, target) => D4.validateTarget<IterableResultSet>(target, 'IterableResultSet').first,
      'last': (visitor, target) => D4.validateTarget<IterableResultSet>(target, 'IterableResultSet').last,
      'single': (visitor, target) => D4.validateTarget<IterableResultSet>(target, 'IterableResultSet').single,
    },
    setters: {
      'next': (visitor, target, value) => 
        D4.validateTarget<IterableResultSet>(target, 'IterableResultSet').next = value as dynamic,
    },
    methods: {
      'moveNext': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterableResultSet>(target, 'IterableResultSet');
        return t.moveNext();
      },
      'cast': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterableResultSet>(target, 'IterableResultSet');
        return t.cast();
      },
      'followedBy': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterableResultSet>(target, 'IterableResultSet');
        D4.requireMinArgs(positional, 1, 'followedBy');
        if (positional.isEmpty) {
          throw ArgumentError('followedBy: Missing required argument "other" at position 0');
        }
        final other = D4.coerceList<$mysql_client_1.IResultSet>(positional[0], 'other');
        return t.followedBy(other);
      },
      'map': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterableResultSet>(target, 'IterableResultSet');
        D4.requireMinArgs(positional, 1, 'map');
        if (positional.isEmpty) {
          throw ArgumentError('map: Missing required argument "toElement" at position 0');
        }
        final toElementRaw = positional[0];
        return t.map(($mysql_client_1.IResultSet p0) { return D4.castCallbackResult<dynamic>(D4.callInterpreterCallback(visitor!, toElementRaw, [p0])); });
      },
      'where': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterableResultSet>(target, 'IterableResultSet');
        D4.requireMinArgs(positional, 1, 'where');
        if (positional.isEmpty) {
          throw ArgumentError('where: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        return t.where(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; });
      },
      'whereType': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterableResultSet>(target, 'IterableResultSet');
        return t.whereType();
      },
      'expand': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterableResultSet>(target, 'IterableResultSet');
        D4.requireMinArgs(positional, 1, 'expand');
        if (positional.isEmpty) {
          throw ArgumentError('expand: Missing required argument "toElements" at position 0');
        }
        final toElementsRaw = positional[0];
        return t.expand(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, toElementsRaw, [p0]) as Iterable<dynamic>; });
      },
      'contains': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterableResultSet>(target, 'IterableResultSet');
        D4.requireMinArgs(positional, 1, 'contains');
        final element = D4.getRequiredArg<Object?>(positional, 0, 'element', 'contains');
        return t.contains(element);
      },
      'forEach': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterableResultSet>(target, 'IterableResultSet');
        D4.requireMinArgs(positional, 1, 'forEach');
        if (positional.isEmpty) {
          throw ArgumentError('forEach: Missing required argument "action" at position 0');
        }
        final actionRaw = positional[0];
        t.forEach(($mysql_client_1.IResultSet p0) { D4.callInterpreterCallback(visitor!, actionRaw, [p0]); });
        return null;
      },
      'reduce': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterableResultSet>(target, 'IterableResultSet');
        D4.requireMinArgs(positional, 1, 'reduce');
        if (positional.isEmpty) {
          throw ArgumentError('reduce: Missing required argument "combine" at position 0');
        }
        final combineRaw = positional[0];
        return t.reduce(($mysql_client_1.IResultSet p0, $mysql_client_1.IResultSet p1) { return D4.callInterpreterCallback(visitor!, combineRaw, [p0, p1]) as $mysql_client_1.IResultSet; });
      },
      'fold': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterableResultSet>(target, 'IterableResultSet');
        D4.requireMinArgs(positional, 2, 'fold');
        final initialValue = D4.getRequiredArg<dynamic>(positional, 0, 'initialValue', 'fold');
        if (positional.length <= 1) {
          throw ArgumentError('fold: Missing required argument "combine" at position 1');
        }
        final combineRaw = positional[1];
        return t.fold(initialValue, (dynamic p0, $mysql_client_1.IResultSet p1) { return D4.castCallbackResult<dynamic>(D4.callInterpreterCallback(visitor!, combineRaw, [p0, p1])); });
      },
      'every': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterableResultSet>(target, 'IterableResultSet');
        D4.requireMinArgs(positional, 1, 'every');
        if (positional.isEmpty) {
          throw ArgumentError('every: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        return t.every(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; });
      },
      'join': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterableResultSet>(target, 'IterableResultSet');
        final separator = D4.getOptionalArgWithDefault<String>(positional, 0, 'separator', "");
        return t.join(separator);
      },
      'any': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterableResultSet>(target, 'IterableResultSet');
        D4.requireMinArgs(positional, 1, 'any');
        if (positional.isEmpty) {
          throw ArgumentError('any: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        return t.any(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; });
      },
      'toList': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterableResultSet>(target, 'IterableResultSet');
        final growable = D4.getNamedArgWithDefault<bool>(named, 'growable', true);
        return t.toList(growable: growable);
      },
      'toSet': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterableResultSet>(target, 'IterableResultSet');
        return t.toSet();
      },
      'take': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterableResultSet>(target, 'IterableResultSet');
        D4.requireMinArgs(positional, 1, 'take');
        final count = D4.getRequiredArg<int>(positional, 0, 'count', 'take');
        return t.take(count);
      },
      'takeWhile': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterableResultSet>(target, 'IterableResultSet');
        D4.requireMinArgs(positional, 1, 'takeWhile');
        if (positional.isEmpty) {
          throw ArgumentError('takeWhile: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        return t.takeWhile(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; });
      },
      'skip': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterableResultSet>(target, 'IterableResultSet');
        D4.requireMinArgs(positional, 1, 'skip');
        final count = D4.getRequiredArg<int>(positional, 0, 'count', 'skip');
        return t.skip(count);
      },
      'skipWhile': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterableResultSet>(target, 'IterableResultSet');
        D4.requireMinArgs(positional, 1, 'skipWhile');
        if (positional.isEmpty) {
          throw ArgumentError('skipWhile: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        return t.skipWhile(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; });
      },
      'firstWhere': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterableResultSet>(target, 'IterableResultSet');
        D4.requireMinArgs(positional, 1, 'firstWhere');
        if (positional.isEmpty) {
          throw ArgumentError('firstWhere: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        final orElseRaw = named['orElse'];
        return t.firstWhere(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; }, orElse: orElseRaw == null ? null : () { return D4.callInterpreterCallback(visitor!, orElseRaw, []) as $mysql_client_1.IResultSet; });
      },
      'lastWhere': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterableResultSet>(target, 'IterableResultSet');
        D4.requireMinArgs(positional, 1, 'lastWhere');
        if (positional.isEmpty) {
          throw ArgumentError('lastWhere: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        final orElseRaw = named['orElse'];
        return t.lastWhere(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; }, orElse: orElseRaw == null ? null : () { return D4.callInterpreterCallback(visitor!, orElseRaw, []) as $mysql_client_1.IResultSet; });
      },
      'singleWhere': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterableResultSet>(target, 'IterableResultSet');
        D4.requireMinArgs(positional, 1, 'singleWhere');
        if (positional.isEmpty) {
          throw ArgumentError('singleWhere: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        final orElseRaw = named['orElse'];
        return t.singleWhere(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; }, orElse: orElseRaw == null ? null : () { return D4.callInterpreterCallback(visitor!, orElseRaw, []) as $mysql_client_1.IResultSet; });
      },
      'elementAt': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterableResultSet>(target, 'IterableResultSet');
        D4.requireMinArgs(positional, 1, 'elementAt');
        final index = D4.getRequiredArg<int>(positional, 0, 'index', 'elementAt');
        return t.elementAt(index);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterableResultSet>(target, 'IterableResultSet');
        return t.toString();
      },
    },
    methodSignatures: {
      'moveNext': 'bool moveNext()',
      'cast': 'Iterable<R> cast()',
      'followedBy': 'Iterable<IResultSet> followedBy(Iterable<IResultSet> other)',
      'map': 'Iterable<T> map(T Function(IResultSet) toElement)',
      'where': 'Iterable<IResultSet> where(bool Function(IResultSet) test)',
      'whereType': 'Iterable<T> whereType()',
      'expand': 'Iterable<T> expand(Iterable<T> Function(IResultSet) toElements)',
      'contains': 'bool contains(Object? element)',
      'forEach': 'void forEach(void Function(IResultSet) action)',
      'reduce': 'IResultSet reduce(IResultSet Function(IResultSet, IResultSet) combine)',
      'fold': 'T fold(T initialValue, T Function(T, IResultSet) combine)',
      'every': 'bool every(bool Function(IResultSet) test)',
      'join': 'String join([String separator = ""])',
      'any': 'bool any(bool Function(IResultSet) test)',
      'toList': 'List<IResultSet> toList({bool growable = true})',
      'toSet': 'Set<IResultSet> toSet()',
      'take': 'Iterable<IResultSet> take(int count)',
      'takeWhile': 'Iterable<IResultSet> takeWhile(bool Function(IResultSet) test)',
      'skip': 'Iterable<IResultSet> skip(int count)',
      'skipWhile': 'Iterable<IResultSet> skipWhile(bool Function(IResultSet) test)',
      'firstWhere': 'IResultSet firstWhere(bool Function(IResultSet) test, {IResultSet Function()? orElse})',
      'lastWhere': 'IResultSet lastWhere(bool Function(IResultSet) test, {IResultSet Function()? orElse})',
      'singleWhere': 'IResultSet singleWhere(bool Function(IResultSet) test, {IResultSet Function()? orElse})',
      'elementAt': 'IResultSet elementAt(int index)',
      'toString': 'String toString()',
    },
    getterSignatures: {
      'next': 'IResultSet? get next',
      'iterator': 'Iterator<IResultSet> get iterator',
      'current': 'IResultSet get current',
      'rowsStream': 'Stream<ResultSetRow> get rowsStream',
      'numOfColumns': 'int get numOfColumns',
      'numOfRows': 'int get numOfRows',
      'affectedRows': 'BigInt get affectedRows',
      'lastInsertID': 'BigInt get lastInsertID',
      'cols': 'Iterable<ResultSetColumn> get cols',
      'rows': 'Iterable<ResultSetRow> get rows',
      'length': 'int get length',
      'isEmpty': 'bool get isEmpty',
      'isNotEmpty': 'bool get isNotEmpty',
      'first': 'IResultSet get first',
      'last': 'IResultSet get last',
      'single': 'IResultSet get single',
    },
    setterSignatures: {
      'next': 'set next(dynamic value)',
    },
  );
}

// =============================================================================
// PreparedStmtResultSet Bridge
// =============================================================================

BridgedClass _createPreparedStmtResultSetBridge() {
  return BridgedClass(
    nativeType: PreparedStmtResultSet,
    name: 'PreparedStmtResultSet',
    isAssignable: (v) => v is PreparedStmtResultSet,
    constructors: {
    },
    getters: {
      'numOfColumns': (visitor, target) => D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet').numOfColumns,
      'numOfRows': (visitor, target) => D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet').numOfRows,
      'affectedRows': (visitor, target) => D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet').affectedRows,
      'lastInsertID': (visitor, target) => D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet').lastInsertID,
      'next': (visitor, target) => D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet').next,
      'iterator': (visitor, target) => D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet').iterator,
      'current': (visitor, target) => D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet').current,
      'rows': (visitor, target) => D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet').rows,
      'cols': (visitor, target) => D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet').cols,
      'rowsStream': (visitor, target) => D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet').rowsStream,
      'length': (visitor, target) => D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet').length,
      'isEmpty': (visitor, target) => D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet').isEmpty,
      'isNotEmpty': (visitor, target) => D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet').isNotEmpty,
      'first': (visitor, target) => D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet').first,
      'last': (visitor, target) => D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet').last,
      'single': (visitor, target) => D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet').single,
    },
    setters: {
      'next': (visitor, target, value) => 
        D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet').next = D4.extractBridgedArgOrNull<$mysql_client_1.IResultSet>(value, 'next'),
    },
    methods: {
      'moveNext': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet');
        return t.moveNext();
      },
      'cast': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet');
        return t.cast();
      },
      'followedBy': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet');
        D4.requireMinArgs(positional, 1, 'followedBy');
        if (positional.isEmpty) {
          throw ArgumentError('followedBy: Missing required argument "other" at position 0');
        }
        final other = D4.coerceList<$mysql_client_1.IResultSet>(positional[0], 'other');
        return t.followedBy(other);
      },
      'map': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet');
        D4.requireMinArgs(positional, 1, 'map');
        if (positional.isEmpty) {
          throw ArgumentError('map: Missing required argument "toElement" at position 0');
        }
        final toElementRaw = positional[0];
        return t.map(($mysql_client_1.IResultSet p0) { return D4.castCallbackResult<dynamic>(D4.callInterpreterCallback(visitor!, toElementRaw, [p0])); });
      },
      'where': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet');
        D4.requireMinArgs(positional, 1, 'where');
        if (positional.isEmpty) {
          throw ArgumentError('where: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        return t.where(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; });
      },
      'whereType': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet');
        return t.whereType();
      },
      'expand': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet');
        D4.requireMinArgs(positional, 1, 'expand');
        if (positional.isEmpty) {
          throw ArgumentError('expand: Missing required argument "toElements" at position 0');
        }
        final toElementsRaw = positional[0];
        return t.expand(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, toElementsRaw, [p0]) as Iterable<dynamic>; });
      },
      'contains': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet');
        D4.requireMinArgs(positional, 1, 'contains');
        final element = D4.getRequiredArg<Object?>(positional, 0, 'element', 'contains');
        return t.contains(element);
      },
      'forEach': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet');
        D4.requireMinArgs(positional, 1, 'forEach');
        if (positional.isEmpty) {
          throw ArgumentError('forEach: Missing required argument "action" at position 0');
        }
        final actionRaw = positional[0];
        t.forEach(($mysql_client_1.IResultSet p0) { D4.callInterpreterCallback(visitor!, actionRaw, [p0]); });
        return null;
      },
      'reduce': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet');
        D4.requireMinArgs(positional, 1, 'reduce');
        if (positional.isEmpty) {
          throw ArgumentError('reduce: Missing required argument "combine" at position 0');
        }
        final combineRaw = positional[0];
        return t.reduce(($mysql_client_1.IResultSet p0, $mysql_client_1.IResultSet p1) { return D4.callInterpreterCallback(visitor!, combineRaw, [p0, p1]) as $mysql_client_1.IResultSet; });
      },
      'fold': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet');
        D4.requireMinArgs(positional, 2, 'fold');
        final initialValue = D4.getRequiredArg<dynamic>(positional, 0, 'initialValue', 'fold');
        if (positional.length <= 1) {
          throw ArgumentError('fold: Missing required argument "combine" at position 1');
        }
        final combineRaw = positional[1];
        return t.fold(initialValue, (dynamic p0, $mysql_client_1.IResultSet p1) { return D4.castCallbackResult<dynamic>(D4.callInterpreterCallback(visitor!, combineRaw, [p0, p1])); });
      },
      'every': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet');
        D4.requireMinArgs(positional, 1, 'every');
        if (positional.isEmpty) {
          throw ArgumentError('every: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        return t.every(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; });
      },
      'join': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet');
        final separator = D4.getOptionalArgWithDefault<String>(positional, 0, 'separator', "");
        return t.join(separator);
      },
      'any': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet');
        D4.requireMinArgs(positional, 1, 'any');
        if (positional.isEmpty) {
          throw ArgumentError('any: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        return t.any(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; });
      },
      'toList': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet');
        final growable = D4.getNamedArgWithDefault<bool>(named, 'growable', true);
        return t.toList(growable: growable);
      },
      'toSet': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet');
        return t.toSet();
      },
      'take': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet');
        D4.requireMinArgs(positional, 1, 'take');
        final count = D4.getRequiredArg<int>(positional, 0, 'count', 'take');
        return t.take(count);
      },
      'takeWhile': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet');
        D4.requireMinArgs(positional, 1, 'takeWhile');
        if (positional.isEmpty) {
          throw ArgumentError('takeWhile: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        return t.takeWhile(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; });
      },
      'skip': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet');
        D4.requireMinArgs(positional, 1, 'skip');
        final count = D4.getRequiredArg<int>(positional, 0, 'count', 'skip');
        return t.skip(count);
      },
      'skipWhile': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet');
        D4.requireMinArgs(positional, 1, 'skipWhile');
        if (positional.isEmpty) {
          throw ArgumentError('skipWhile: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        return t.skipWhile(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; });
      },
      'firstWhere': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet');
        D4.requireMinArgs(positional, 1, 'firstWhere');
        if (positional.isEmpty) {
          throw ArgumentError('firstWhere: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        final orElseRaw = named['orElse'];
        return t.firstWhere(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; }, orElse: orElseRaw == null ? null : () { return D4.callInterpreterCallback(visitor!, orElseRaw, []) as $mysql_client_1.IResultSet; });
      },
      'lastWhere': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet');
        D4.requireMinArgs(positional, 1, 'lastWhere');
        if (positional.isEmpty) {
          throw ArgumentError('lastWhere: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        final orElseRaw = named['orElse'];
        return t.lastWhere(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; }, orElse: orElseRaw == null ? null : () { return D4.callInterpreterCallback(visitor!, orElseRaw, []) as $mysql_client_1.IResultSet; });
      },
      'singleWhere': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet');
        D4.requireMinArgs(positional, 1, 'singleWhere');
        if (positional.isEmpty) {
          throw ArgumentError('singleWhere: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        final orElseRaw = named['orElse'];
        return t.singleWhere(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; }, orElse: orElseRaw == null ? null : () { return D4.callInterpreterCallback(visitor!, orElseRaw, []) as $mysql_client_1.IResultSet; });
      },
      'elementAt': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet');
        D4.requireMinArgs(positional, 1, 'elementAt');
        final index = D4.getRequiredArg<int>(positional, 0, 'index', 'elementAt');
        return t.elementAt(index);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<PreparedStmtResultSet>(target, 'PreparedStmtResultSet');
        return t.toString();
      },
    },
    methodSignatures: {
      'moveNext': 'bool moveNext()',
      'cast': 'Iterable<R> cast()',
      'followedBy': 'Iterable<IResultSet> followedBy(Iterable<IResultSet> other)',
      'map': 'Iterable<T> map(T Function(IResultSet) toElement)',
      'where': 'Iterable<IResultSet> where(bool Function(IResultSet) test)',
      'whereType': 'Iterable<T> whereType()',
      'expand': 'Iterable<T> expand(Iterable<T> Function(IResultSet) toElements)',
      'contains': 'bool contains(Object? element)',
      'forEach': 'void forEach(void Function(IResultSet) action)',
      'reduce': 'IResultSet reduce(IResultSet Function(IResultSet, IResultSet) combine)',
      'fold': 'T fold(T initialValue, T Function(T, IResultSet) combine)',
      'every': 'bool every(bool Function(IResultSet) test)',
      'join': 'String join([String separator = ""])',
      'any': 'bool any(bool Function(IResultSet) test)',
      'toList': 'List<IResultSet> toList({bool growable = true})',
      'toSet': 'Set<IResultSet> toSet()',
      'take': 'Iterable<IResultSet> take(int count)',
      'takeWhile': 'Iterable<IResultSet> takeWhile(bool Function(IResultSet) test)',
      'skip': 'Iterable<IResultSet> skip(int count)',
      'skipWhile': 'Iterable<IResultSet> skipWhile(bool Function(IResultSet) test)',
      'firstWhere': 'IResultSet firstWhere(bool Function(IResultSet) test, {IResultSet Function()? orElse})',
      'lastWhere': 'IResultSet lastWhere(bool Function(IResultSet) test, {IResultSet Function()? orElse})',
      'singleWhere': 'IResultSet singleWhere(bool Function(IResultSet) test, {IResultSet Function()? orElse})',
      'elementAt': 'IResultSet elementAt(int index)',
      'toString': 'String toString()',
    },
    getterSignatures: {
      'numOfColumns': 'int get numOfColumns',
      'numOfRows': 'int get numOfRows',
      'affectedRows': 'BigInt get affectedRows',
      'lastInsertID': 'BigInt get lastInsertID',
      'next': 'IResultSet? get next',
      'iterator': 'Iterator<IResultSet> get iterator',
      'current': 'IResultSet get current',
      'rows': 'Iterable<ResultSetRow> get rows',
      'cols': 'Iterable<ResultSetColumn> get cols',
      'rowsStream': 'Stream<ResultSetRow> get rowsStream',
      'length': 'int get length',
      'isEmpty': 'bool get isEmpty',
      'isNotEmpty': 'bool get isNotEmpty',
      'first': 'IResultSet get first',
      'last': 'IResultSet get last',
      'single': 'IResultSet get single',
    },
    setterSignatures: {
      'next': 'set next(IResultSet? value)',
    },
  );
}

// =============================================================================
// IterablePreparedStmtResultSet Bridge
// =============================================================================

BridgedClass _createIterablePreparedStmtResultSetBridge() {
  return BridgedClass(
    nativeType: IterablePreparedStmtResultSet,
    name: 'IterablePreparedStmtResultSet',
    isAssignable: (v) => v is IterablePreparedStmtResultSet,
    constructors: {
    },
    getters: {
      'numOfColumns': (visitor, target) => D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet').numOfColumns,
      'numOfRows': (visitor, target) => D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet').numOfRows,
      'affectedRows': (visitor, target) => D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet').affectedRows,
      'lastInsertID': (visitor, target) => D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet').lastInsertID,
      'next': (visitor, target) => D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet').next,
      'iterator': (visitor, target) => D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet').iterator,
      'current': (visitor, target) => D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet').current,
      'rows': (visitor, target) => D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet').rows,
      'cols': (visitor, target) => D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet').cols,
      'rowsStream': (visitor, target) => D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet').rowsStream,
      'length': (visitor, target) => D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet').length,
      'isEmpty': (visitor, target) => D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet').isEmpty,
      'isNotEmpty': (visitor, target) => D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet').isNotEmpty,
      'first': (visitor, target) => D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet').first,
      'last': (visitor, target) => D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet').last,
      'single': (visitor, target) => D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet').single,
    },
    setters: {
      'next': (visitor, target, value) => 
        D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet').next = D4.extractBridgedArgOrNull<$mysql_client_1.IResultSet>(value, 'next'),
    },
    methods: {
      'moveNext': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet');
        return t.moveNext();
      },
      'cast': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet');
        return t.cast();
      },
      'followedBy': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet');
        D4.requireMinArgs(positional, 1, 'followedBy');
        if (positional.isEmpty) {
          throw ArgumentError('followedBy: Missing required argument "other" at position 0');
        }
        final other = D4.coerceList<$mysql_client_1.IResultSet>(positional[0], 'other');
        return t.followedBy(other);
      },
      'map': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet');
        D4.requireMinArgs(positional, 1, 'map');
        if (positional.isEmpty) {
          throw ArgumentError('map: Missing required argument "toElement" at position 0');
        }
        final toElementRaw = positional[0];
        return t.map(($mysql_client_1.IResultSet p0) { return D4.castCallbackResult<dynamic>(D4.callInterpreterCallback(visitor!, toElementRaw, [p0])); });
      },
      'where': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet');
        D4.requireMinArgs(positional, 1, 'where');
        if (positional.isEmpty) {
          throw ArgumentError('where: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        return t.where(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; });
      },
      'whereType': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet');
        return t.whereType();
      },
      'expand': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet');
        D4.requireMinArgs(positional, 1, 'expand');
        if (positional.isEmpty) {
          throw ArgumentError('expand: Missing required argument "toElements" at position 0');
        }
        final toElementsRaw = positional[0];
        return t.expand(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, toElementsRaw, [p0]) as Iterable<dynamic>; });
      },
      'contains': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet');
        D4.requireMinArgs(positional, 1, 'contains');
        final element = D4.getRequiredArg<Object?>(positional, 0, 'element', 'contains');
        return t.contains(element);
      },
      'forEach': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet');
        D4.requireMinArgs(positional, 1, 'forEach');
        if (positional.isEmpty) {
          throw ArgumentError('forEach: Missing required argument "action" at position 0');
        }
        final actionRaw = positional[0];
        t.forEach(($mysql_client_1.IResultSet p0) { D4.callInterpreterCallback(visitor!, actionRaw, [p0]); });
        return null;
      },
      'reduce': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet');
        D4.requireMinArgs(positional, 1, 'reduce');
        if (positional.isEmpty) {
          throw ArgumentError('reduce: Missing required argument "combine" at position 0');
        }
        final combineRaw = positional[0];
        return t.reduce(($mysql_client_1.IResultSet p0, $mysql_client_1.IResultSet p1) { return D4.callInterpreterCallback(visitor!, combineRaw, [p0, p1]) as $mysql_client_1.IResultSet; });
      },
      'fold': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet');
        D4.requireMinArgs(positional, 2, 'fold');
        final initialValue = D4.getRequiredArg<dynamic>(positional, 0, 'initialValue', 'fold');
        if (positional.length <= 1) {
          throw ArgumentError('fold: Missing required argument "combine" at position 1');
        }
        final combineRaw = positional[1];
        return t.fold(initialValue, (dynamic p0, $mysql_client_1.IResultSet p1) { return D4.castCallbackResult<dynamic>(D4.callInterpreterCallback(visitor!, combineRaw, [p0, p1])); });
      },
      'every': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet');
        D4.requireMinArgs(positional, 1, 'every');
        if (positional.isEmpty) {
          throw ArgumentError('every: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        return t.every(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; });
      },
      'join': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet');
        final separator = D4.getOptionalArgWithDefault<String>(positional, 0, 'separator', "");
        return t.join(separator);
      },
      'any': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet');
        D4.requireMinArgs(positional, 1, 'any');
        if (positional.isEmpty) {
          throw ArgumentError('any: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        return t.any(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; });
      },
      'toList': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet');
        final growable = D4.getNamedArgWithDefault<bool>(named, 'growable', true);
        return t.toList(growable: growable);
      },
      'toSet': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet');
        return t.toSet();
      },
      'take': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet');
        D4.requireMinArgs(positional, 1, 'take');
        final count = D4.getRequiredArg<int>(positional, 0, 'count', 'take');
        return t.take(count);
      },
      'takeWhile': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet');
        D4.requireMinArgs(positional, 1, 'takeWhile');
        if (positional.isEmpty) {
          throw ArgumentError('takeWhile: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        return t.takeWhile(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; });
      },
      'skip': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet');
        D4.requireMinArgs(positional, 1, 'skip');
        final count = D4.getRequiredArg<int>(positional, 0, 'count', 'skip');
        return t.skip(count);
      },
      'skipWhile': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet');
        D4.requireMinArgs(positional, 1, 'skipWhile');
        if (positional.isEmpty) {
          throw ArgumentError('skipWhile: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        return t.skipWhile(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; });
      },
      'firstWhere': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet');
        D4.requireMinArgs(positional, 1, 'firstWhere');
        if (positional.isEmpty) {
          throw ArgumentError('firstWhere: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        final orElseRaw = named['orElse'];
        return t.firstWhere(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; }, orElse: orElseRaw == null ? null : () { return D4.callInterpreterCallback(visitor!, orElseRaw, []) as $mysql_client_1.IResultSet; });
      },
      'lastWhere': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet');
        D4.requireMinArgs(positional, 1, 'lastWhere');
        if (positional.isEmpty) {
          throw ArgumentError('lastWhere: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        final orElseRaw = named['orElse'];
        return t.lastWhere(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; }, orElse: orElseRaw == null ? null : () { return D4.callInterpreterCallback(visitor!, orElseRaw, []) as $mysql_client_1.IResultSet; });
      },
      'singleWhere': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet');
        D4.requireMinArgs(positional, 1, 'singleWhere');
        if (positional.isEmpty) {
          throw ArgumentError('singleWhere: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        final orElseRaw = named['orElse'];
        return t.singleWhere(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; }, orElse: orElseRaw == null ? null : () { return D4.callInterpreterCallback(visitor!, orElseRaw, []) as $mysql_client_1.IResultSet; });
      },
      'elementAt': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet');
        D4.requireMinArgs(positional, 1, 'elementAt');
        final index = D4.getRequiredArg<int>(positional, 0, 'index', 'elementAt');
        return t.elementAt(index);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<IterablePreparedStmtResultSet>(target, 'IterablePreparedStmtResultSet');
        return t.toString();
      },
    },
    methodSignatures: {
      'moveNext': 'bool moveNext()',
      'cast': 'Iterable<R> cast()',
      'followedBy': 'Iterable<IResultSet> followedBy(Iterable<IResultSet> other)',
      'map': 'Iterable<T> map(T Function(IResultSet) toElement)',
      'where': 'Iterable<IResultSet> where(bool Function(IResultSet) test)',
      'whereType': 'Iterable<T> whereType()',
      'expand': 'Iterable<T> expand(Iterable<T> Function(IResultSet) toElements)',
      'contains': 'bool contains(Object? element)',
      'forEach': 'void forEach(void Function(IResultSet) action)',
      'reduce': 'IResultSet reduce(IResultSet Function(IResultSet, IResultSet) combine)',
      'fold': 'T fold(T initialValue, T Function(T, IResultSet) combine)',
      'every': 'bool every(bool Function(IResultSet) test)',
      'join': 'String join([String separator = ""])',
      'any': 'bool any(bool Function(IResultSet) test)',
      'toList': 'List<IResultSet> toList({bool growable = true})',
      'toSet': 'Set<IResultSet> toSet()',
      'take': 'Iterable<IResultSet> take(int count)',
      'takeWhile': 'Iterable<IResultSet> takeWhile(bool Function(IResultSet) test)',
      'skip': 'Iterable<IResultSet> skip(int count)',
      'skipWhile': 'Iterable<IResultSet> skipWhile(bool Function(IResultSet) test)',
      'firstWhere': 'IResultSet firstWhere(bool Function(IResultSet) test, {IResultSet Function()? orElse})',
      'lastWhere': 'IResultSet lastWhere(bool Function(IResultSet) test, {IResultSet Function()? orElse})',
      'singleWhere': 'IResultSet singleWhere(bool Function(IResultSet) test, {IResultSet Function()? orElse})',
      'elementAt': 'IResultSet elementAt(int index)',
      'toString': 'String toString()',
    },
    getterSignatures: {
      'numOfColumns': 'int get numOfColumns',
      'numOfRows': 'int get numOfRows',
      'affectedRows': 'BigInt get affectedRows',
      'lastInsertID': 'BigInt get lastInsertID',
      'next': 'IResultSet? get next',
      'iterator': 'Iterator<IResultSet> get iterator',
      'current': 'IResultSet get current',
      'rows': 'Iterable<ResultSetRow> get rows',
      'cols': 'Iterable<ResultSetColumn> get cols',
      'rowsStream': 'Stream<ResultSetRow> get rowsStream',
      'length': 'int get length',
      'isEmpty': 'bool get isEmpty',
      'isNotEmpty': 'bool get isNotEmpty',
      'first': 'IResultSet get first',
      'last': 'IResultSet get last',
      'single': 'IResultSet get single',
    },
    setterSignatures: {
      'next': 'set next(IResultSet? value)',
    },
  );
}

// =============================================================================
// EmptyResultSet Bridge
// =============================================================================

BridgedClass _createEmptyResultSetBridge() {
  return BridgedClass(
    nativeType: EmptyResultSet,
    name: 'EmptyResultSet',
    isAssignable: (v) => v is EmptyResultSet,
    constructors: {
      '': (visitor, positional, named) {
        final okPacket = D4.getRequiredNamedArg<$mysql_client_3.MySQLPacketOK>(named, 'okPacket', 'EmptyResultSet');
        return EmptyResultSet(okPacket: okPacket);
      },
    },
    getters: {
      'numOfColumns': (visitor, target) => D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet').numOfColumns,
      'numOfRows': (visitor, target) => D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet').numOfRows,
      'affectedRows': (visitor, target) => D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet').affectedRows,
      'lastInsertID': (visitor, target) => D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet').lastInsertID,
      'next': (visitor, target) => D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet').next,
      'iterator': (visitor, target) => D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet').iterator,
      'current': (visitor, target) => D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet').current,
      'rows': (visitor, target) => D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet').rows,
      'cols': (visitor, target) => D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet').cols,
      'rowsStream': (visitor, target) => D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet').rowsStream,
      'length': (visitor, target) => D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet').length,
      'isEmpty': (visitor, target) => D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet').isEmpty,
      'isNotEmpty': (visitor, target) => D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet').isNotEmpty,
      'first': (visitor, target) => D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet').first,
      'last': (visitor, target) => D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet').last,
      'single': (visitor, target) => D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet').single,
    },
    setters: {
      'next': (visitor, target, value) => 
        D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet').next = D4.extractBridgedArgOrNull<$mysql_client_1.IResultSet>(value, 'next'),
    },
    methods: {
      'moveNext': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet');
        return t.moveNext();
      },
      'cast': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet');
        return t.cast();
      },
      'followedBy': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet');
        D4.requireMinArgs(positional, 1, 'followedBy');
        if (positional.isEmpty) {
          throw ArgumentError('followedBy: Missing required argument "other" at position 0');
        }
        final other = D4.coerceList<$mysql_client_1.IResultSet>(positional[0], 'other');
        return t.followedBy(other);
      },
      'map': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet');
        D4.requireMinArgs(positional, 1, 'map');
        if (positional.isEmpty) {
          throw ArgumentError('map: Missing required argument "toElement" at position 0');
        }
        final toElementRaw = positional[0];
        return t.map(($mysql_client_1.IResultSet p0) { return D4.castCallbackResult<dynamic>(D4.callInterpreterCallback(visitor!, toElementRaw, [p0])); });
      },
      'where': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet');
        D4.requireMinArgs(positional, 1, 'where');
        if (positional.isEmpty) {
          throw ArgumentError('where: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        return t.where(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; });
      },
      'whereType': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet');
        return t.whereType();
      },
      'expand': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet');
        D4.requireMinArgs(positional, 1, 'expand');
        if (positional.isEmpty) {
          throw ArgumentError('expand: Missing required argument "toElements" at position 0');
        }
        final toElementsRaw = positional[0];
        return t.expand(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, toElementsRaw, [p0]) as Iterable<dynamic>; });
      },
      'contains': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet');
        D4.requireMinArgs(positional, 1, 'contains');
        final element = D4.getRequiredArg<Object?>(positional, 0, 'element', 'contains');
        return t.contains(element);
      },
      'forEach': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet');
        D4.requireMinArgs(positional, 1, 'forEach');
        if (positional.isEmpty) {
          throw ArgumentError('forEach: Missing required argument "action" at position 0');
        }
        final actionRaw = positional[0];
        t.forEach(($mysql_client_1.IResultSet p0) { D4.callInterpreterCallback(visitor!, actionRaw, [p0]); });
        return null;
      },
      'reduce': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet');
        D4.requireMinArgs(positional, 1, 'reduce');
        if (positional.isEmpty) {
          throw ArgumentError('reduce: Missing required argument "combine" at position 0');
        }
        final combineRaw = positional[0];
        return t.reduce(($mysql_client_1.IResultSet p0, $mysql_client_1.IResultSet p1) { return D4.callInterpreterCallback(visitor!, combineRaw, [p0, p1]) as $mysql_client_1.IResultSet; });
      },
      'fold': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet');
        D4.requireMinArgs(positional, 2, 'fold');
        final initialValue = D4.getRequiredArg<dynamic>(positional, 0, 'initialValue', 'fold');
        if (positional.length <= 1) {
          throw ArgumentError('fold: Missing required argument "combine" at position 1');
        }
        final combineRaw = positional[1];
        return t.fold(initialValue, (dynamic p0, $mysql_client_1.IResultSet p1) { return D4.castCallbackResult<dynamic>(D4.callInterpreterCallback(visitor!, combineRaw, [p0, p1])); });
      },
      'every': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet');
        D4.requireMinArgs(positional, 1, 'every');
        if (positional.isEmpty) {
          throw ArgumentError('every: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        return t.every(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; });
      },
      'join': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet');
        final separator = D4.getOptionalArgWithDefault<String>(positional, 0, 'separator', "");
        return t.join(separator);
      },
      'any': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet');
        D4.requireMinArgs(positional, 1, 'any');
        if (positional.isEmpty) {
          throw ArgumentError('any: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        return t.any(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; });
      },
      'toList': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet');
        final growable = D4.getNamedArgWithDefault<bool>(named, 'growable', true);
        return t.toList(growable: growable);
      },
      'toSet': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet');
        return t.toSet();
      },
      'take': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet');
        D4.requireMinArgs(positional, 1, 'take');
        final count = D4.getRequiredArg<int>(positional, 0, 'count', 'take');
        return t.take(count);
      },
      'takeWhile': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet');
        D4.requireMinArgs(positional, 1, 'takeWhile');
        if (positional.isEmpty) {
          throw ArgumentError('takeWhile: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        return t.takeWhile(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; });
      },
      'skip': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet');
        D4.requireMinArgs(positional, 1, 'skip');
        final count = D4.getRequiredArg<int>(positional, 0, 'count', 'skip');
        return t.skip(count);
      },
      'skipWhile': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet');
        D4.requireMinArgs(positional, 1, 'skipWhile');
        if (positional.isEmpty) {
          throw ArgumentError('skipWhile: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        return t.skipWhile(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; });
      },
      'firstWhere': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet');
        D4.requireMinArgs(positional, 1, 'firstWhere');
        if (positional.isEmpty) {
          throw ArgumentError('firstWhere: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        final orElseRaw = named['orElse'];
        return t.firstWhere(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; }, orElse: orElseRaw == null ? null : () { return D4.callInterpreterCallback(visitor!, orElseRaw, []) as $mysql_client_1.IResultSet; });
      },
      'lastWhere': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet');
        D4.requireMinArgs(positional, 1, 'lastWhere');
        if (positional.isEmpty) {
          throw ArgumentError('lastWhere: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        final orElseRaw = named['orElse'];
        return t.lastWhere(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; }, orElse: orElseRaw == null ? null : () { return D4.callInterpreterCallback(visitor!, orElseRaw, []) as $mysql_client_1.IResultSet; });
      },
      'singleWhere': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet');
        D4.requireMinArgs(positional, 1, 'singleWhere');
        if (positional.isEmpty) {
          throw ArgumentError('singleWhere: Missing required argument "test" at position 0');
        }
        final testRaw = positional[0];
        final orElseRaw = named['orElse'];
        return t.singleWhere(($mysql_client_1.IResultSet p0) { return D4.callInterpreterCallback(visitor!, testRaw, [p0]) as bool; }, orElse: orElseRaw == null ? null : () { return D4.callInterpreterCallback(visitor!, orElseRaw, []) as $mysql_client_1.IResultSet; });
      },
      'elementAt': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet');
        D4.requireMinArgs(positional, 1, 'elementAt');
        final index = D4.getRequiredArg<int>(positional, 0, 'index', 'elementAt');
        return t.elementAt(index);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<EmptyResultSet>(target, 'EmptyResultSet');
        return t.toString();
      },
    },
    constructorSignatures: {
      '': 'EmptyResultSet({required MySQLPacketOK okPacket})',
    },
    methodSignatures: {
      'moveNext': 'bool moveNext()',
      'cast': 'Iterable<R> cast()',
      'followedBy': 'Iterable<IResultSet> followedBy(Iterable<IResultSet> other)',
      'map': 'Iterable<T> map(T Function(IResultSet) toElement)',
      'where': 'Iterable<IResultSet> where(bool Function(IResultSet) test)',
      'whereType': 'Iterable<T> whereType()',
      'expand': 'Iterable<T> expand(Iterable<T> Function(IResultSet) toElements)',
      'contains': 'bool contains(Object? element)',
      'forEach': 'void forEach(void Function(IResultSet) action)',
      'reduce': 'IResultSet reduce(IResultSet Function(IResultSet, IResultSet) combine)',
      'fold': 'T fold(T initialValue, T Function(T, IResultSet) combine)',
      'every': 'bool every(bool Function(IResultSet) test)',
      'join': 'String join([String separator = ""])',
      'any': 'bool any(bool Function(IResultSet) test)',
      'toList': 'List<IResultSet> toList({bool growable = true})',
      'toSet': 'Set<IResultSet> toSet()',
      'take': 'Iterable<IResultSet> take(int count)',
      'takeWhile': 'Iterable<IResultSet> takeWhile(bool Function(IResultSet) test)',
      'skip': 'Iterable<IResultSet> skip(int count)',
      'skipWhile': 'Iterable<IResultSet> skipWhile(bool Function(IResultSet) test)',
      'firstWhere': 'IResultSet firstWhere(bool Function(IResultSet) test, {IResultSet Function()? orElse})',
      'lastWhere': 'IResultSet lastWhere(bool Function(IResultSet) test, {IResultSet Function()? orElse})',
      'singleWhere': 'IResultSet singleWhere(bool Function(IResultSet) test, {IResultSet Function()? orElse})',
      'elementAt': 'IResultSet elementAt(int index)',
      'toString': 'String toString()',
    },
    getterSignatures: {
      'numOfColumns': 'int get numOfColumns',
      'numOfRows': 'int get numOfRows',
      'affectedRows': 'BigInt get affectedRows',
      'lastInsertID': 'BigInt get lastInsertID',
      'next': 'IResultSet? get next',
      'iterator': 'Iterator<IResultSet> get iterator',
      'current': 'IResultSet get current',
      'rows': 'Iterable<ResultSetRow> get rows',
      'cols': 'Iterable<ResultSetColumn> get cols',
      'rowsStream': 'Stream<ResultSetRow> get rowsStream',
      'length': 'int get length',
      'isEmpty': 'bool get isEmpty',
      'isNotEmpty': 'bool get isNotEmpty',
      'first': 'IResultSet get first',
      'last': 'IResultSet get last',
      'single': 'IResultSet get single',
    },
    setterSignatures: {
      'next': 'set next(IResultSet? value)',
    },
  );
}

// =============================================================================
// ResultSetRow Bridge
// =============================================================================

BridgedClass _createResultSetRowBridge() {
  return BridgedClass(
    nativeType: $mysql_client_1.ResultSetRow,
    name: 'ResultSetRow',
    isAssignable: (v) => v is $mysql_client_1.ResultSetRow,
    constructors: {
    },
    getters: {
      'numOfColumns': (visitor, target) => D4.validateTarget<$mysql_client_1.ResultSetRow>(target, 'ResultSetRow').numOfColumns,
    },
    methods: {
      'colAt': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.ResultSetRow>(target, 'ResultSetRow');
        D4.requireMinArgs(positional, 1, 'colAt');
        final colIndex = D4.getRequiredArg<int>(positional, 0, 'colIndex', 'colAt');
        return t.colAt(colIndex);
      },
      'typedColAt': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.ResultSetRow>(target, 'ResultSetRow');
        D4.requireMinArgs(positional, 1, 'typedColAt');
        final colIndex = D4.getRequiredArg<int>(positional, 0, 'colIndex', 'typedColAt');
        return t.typedColAt(colIndex);
      },
      'colByName': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.ResultSetRow>(target, 'ResultSetRow');
        D4.requireMinArgs(positional, 1, 'colByName');
        final columnName = D4.getRequiredArg<String>(positional, 0, 'columnName', 'colByName');
        return t.colByName(columnName);
      },
      'typedColByName': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.ResultSetRow>(target, 'ResultSetRow');
        D4.requireMinArgs(positional, 1, 'typedColByName');
        final columnName = D4.getRequiredArg<String>(positional, 0, 'columnName', 'typedColByName');
        return t.typedColByName(columnName);
      },
      'assoc': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.ResultSetRow>(target, 'ResultSetRow');
        return t.assoc();
      },
      'typedAssoc': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.ResultSetRow>(target, 'ResultSetRow');
        return t.typedAssoc();
      },
    },
    methodSignatures: {
      'colAt': 'String? colAt(int colIndex)',
      'typedColAt': 'T? typedColAt(int colIndex)',
      'colByName': 'String? colByName(String columnName)',
      'typedColByName': 'T? typedColByName(String columnName)',
      'assoc': 'Map<String, String?> assoc()',
      'typedAssoc': 'Map<String, dynamic> typedAssoc()',
    },
    getterSignatures: {
      'numOfColumns': 'int get numOfColumns',
    },
  );
}

// =============================================================================
// ResultSetColumn Bridge
// =============================================================================

BridgedClass _createResultSetColumnBridge() {
  return BridgedClass(
    nativeType: $mysql_client_1.ResultSetColumn,
    name: 'ResultSetColumn',
    isAssignable: (v) => v is $mysql_client_1.ResultSetColumn,
    constructors: {
      '': (visitor, positional, named) {
        final name = D4.getRequiredNamedArg<String>(named, 'name', 'ResultSetColumn');
        final type = D4.getRequiredNamedArg<$mysql_client_2.MySQLColumnType>(named, 'type', 'ResultSetColumn');
        final length = D4.getRequiredNamedArg<int>(named, 'length', 'ResultSetColumn');
        return $mysql_client_1.ResultSetColumn(name: name, type: type, length: length);
      },
    },
    getters: {
      'name': (visitor, target) => D4.validateTarget<$mysql_client_1.ResultSetColumn>(target, 'ResultSetColumn').name,
      'type': (visitor, target) => D4.validateTarget<$mysql_client_1.ResultSetColumn>(target, 'ResultSetColumn').type,
      'length': (visitor, target) => D4.validateTarget<$mysql_client_1.ResultSetColumn>(target, 'ResultSetColumn').length,
    },
    setters: {
      'name': (visitor, target, value) => 
        D4.validateTarget<$mysql_client_1.ResultSetColumn>(target, 'ResultSetColumn').name = D4.extractBridgedArg<String>(value, 'name'),
      'type': (visitor, target, value) => 
        D4.validateTarget<$mysql_client_1.ResultSetColumn>(target, 'ResultSetColumn').type = D4.extractBridgedArg<$mysql_client_2.MySQLColumnType>(value, 'type'),
      'length': (visitor, target, value) => 
        D4.validateTarget<$mysql_client_1.ResultSetColumn>(target, 'ResultSetColumn').length = D4.extractBridgedArg<int>(value, 'length'),
    },
    constructorSignatures: {
      '': 'ResultSetColumn({required String name, required MySQLColumnType type, required int length})',
    },
    getterSignatures: {
      'name': 'String get name',
      'type': 'MySQLColumnType get type',
      'length': 'int get length',
    },
    setterSignatures: {
      'name': 'set name(dynamic value)',
      'type': 'set type(dynamic value)',
      'length': 'set length(dynamic value)',
    },
  );
}

// =============================================================================
// PreparedStmt Bridge
// =============================================================================

BridgedClass _createPreparedStmtBridge() {
  return BridgedClass(
    nativeType: $mysql_client_1.PreparedStmt,
    name: 'PreparedStmt',
    isAssignable: (v) => v is $mysql_client_1.PreparedStmt,
    constructors: {
    },
    getters: {
      'numOfParams': (visitor, target) => D4.validateTarget<$mysql_client_1.PreparedStmt>(target, 'PreparedStmt').numOfParams,
    },
    methods: {
      'execute': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.PreparedStmt>(target, 'PreparedStmt');
        D4.requireMinArgs(positional, 1, 'execute');
        if (positional.isEmpty) {
          throw ArgumentError('execute: Missing required argument "params" at position 0');
        }
        final params = D4.coerceList<dynamic>(positional[0], 'params');
        return t.execute(params);
      },
      'deallocate': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$mysql_client_1.PreparedStmt>(target, 'PreparedStmt');
        return t.deallocate();
      },
    },
    methodSignatures: {
      'execute': 'Future<IResultSet> execute(List<dynamic> params)',
      'deallocate': 'Future<void> deallocate()',
    },
    getterSignatures: {
      'numOfParams': 'int get numOfParams',
    },
  );
}

// =============================================================================
// MySQLConnectionPool Bridge
// =============================================================================

BridgedClass _createMySQLConnectionPoolBridge() {
  return BridgedClass(
    nativeType: MySQLConnectionPool,
    name: 'MySQLConnectionPool',
    isAssignable: (v) => v is MySQLConnectionPool,
    constructors: {
      '': (visitor, positional, named) {
        final host = D4.getRequiredNamedArg<String>(named, 'host', 'MySQLConnectionPool');
        final port = D4.getRequiredNamedArg<int>(named, 'port', 'MySQLConnectionPool');
        final userName = D4.getRequiredNamedArg<String>(named, 'userName', 'MySQLConnectionPool');
        final password = D4.getRequiredNamedArg<dynamic>(named, 'password', 'MySQLConnectionPool');
        final maxConnections = D4.getRequiredNamedArg<int>(named, 'maxConnections', 'MySQLConnectionPool');
        final databaseName = D4.getOptionalNamedArg<String?>(named, 'databaseName');
        final secure = D4.getNamedArgWithDefault<bool>(named, 'secure', true);
        final collation = D4.getNamedArgWithDefault<String>(named, 'collation', 'utf8_general_ci');
        final timeoutMs = D4.getNamedArgWithDefault<int>(named, 'timeoutMs', 10000);
        return MySQLConnectionPool(host: host, port: port, userName: userName, password: password, maxConnections: maxConnections, databaseName: databaseName, secure: secure, collation: collation, timeoutMs: timeoutMs);
      },
    },
    getters: {
      'host': (visitor, target) => D4.validateTarget<MySQLConnectionPool>(target, 'MySQLConnectionPool').host,
      'port': (visitor, target) => D4.validateTarget<MySQLConnectionPool>(target, 'MySQLConnectionPool').port,
      'userName': (visitor, target) => D4.validateTarget<MySQLConnectionPool>(target, 'MySQLConnectionPool').userName,
      'maxConnections': (visitor, target) => D4.validateTarget<MySQLConnectionPool>(target, 'MySQLConnectionPool').maxConnections,
      'databaseName': (visitor, target) => D4.validateTarget<MySQLConnectionPool>(target, 'MySQLConnectionPool').databaseName,
      'secure': (visitor, target) => D4.validateTarget<MySQLConnectionPool>(target, 'MySQLConnectionPool').secure,
      'collation': (visitor, target) => D4.validateTarget<MySQLConnectionPool>(target, 'MySQLConnectionPool').collation,
      'timeoutMs': (visitor, target) => D4.validateTarget<MySQLConnectionPool>(target, 'MySQLConnectionPool').timeoutMs,
      'activeConnectionsQty': (visitor, target) => D4.validateTarget<MySQLConnectionPool>(target, 'MySQLConnectionPool').activeConnectionsQty,
      'idleConnectionsQty': (visitor, target) => D4.validateTarget<MySQLConnectionPool>(target, 'MySQLConnectionPool').idleConnectionsQty,
      'allConnectionsQty': (visitor, target) => D4.validateTarget<MySQLConnectionPool>(target, 'MySQLConnectionPool').allConnectionsQty,
    },
    methods: {
      'execute': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MySQLConnectionPool>(target, 'MySQLConnectionPool');
        D4.requireMinArgs(positional, 1, 'execute');
        final query = D4.getRequiredArg<String>(positional, 0, 'query', 'execute');
        final params = positional.length > 1
            ? D4.coerceMapOrNull<String, dynamic>(positional[1], 'params')
            : null;
        final iterable = D4.getOptionalArgWithDefault<bool>(positional, 2, 'iterable', false);
        return t.execute(query, params, iterable);
      },
      'close': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MySQLConnectionPool>(target, 'MySQLConnectionPool');
        return t.close();
      },
      'prepare': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MySQLConnectionPool>(target, 'MySQLConnectionPool');
        D4.requireMinArgs(positional, 1, 'prepare');
        final query = D4.getRequiredArg<String>(positional, 0, 'query', 'prepare');
        final iterable = D4.getOptionalArgWithDefault<bool>(positional, 1, 'iterable', false);
        return t.prepare(query, iterable);
      },
      'withConnection': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MySQLConnectionPool>(target, 'MySQLConnectionPool');
        D4.requireMinArgs(positional, 1, 'withConnection');
        if (positional.isEmpty) {
          throw ArgumentError('withConnection: Missing required argument "callback" at position 0');
        }
        final callbackRaw = positional[0];
        return t.withConnection(($mysql_client_1.MySQLConnection p0) { return D4.callInterpreterCallback(visitor!, callbackRaw, [p0]) as FutureOr<Object>; });
      },
      'transactional': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<MySQLConnectionPool>(target, 'MySQLConnectionPool');
        D4.requireMinArgs(positional, 1, 'transactional');
        if (positional.isEmpty) {
          throw ArgumentError('transactional: Missing required argument "callback" at position 0');
        }
        final callbackRaw = positional[0];
        return t.transactional(($mysql_client_1.MySQLConnection p0) { return D4.callInterpreterCallback(visitor!, callbackRaw, [p0]) as FutureOr<Object>; });
      },
    },
    constructorSignatures: {
      '': 'MySQLConnectionPool({required String host, required int port, required String userName, required dynamic password, required int maxConnections, String? databaseName, bool secure = true, String collation = \'utf8_general_ci\', int timeoutMs = 10000})',
    },
    methodSignatures: {
      'execute': 'Future<IResultSet> execute(String query, [Map<String, dynamic>? params, bool iterable = false])',
      'close': 'Future<void> close()',
      'prepare': 'Future<PreparedStmt> prepare(String query, [bool iterable = false])',
      'withConnection': 'FutureOr<T> withConnection(FutureOr<T> Function(MySQLConnection conn) callback)',
      'transactional': 'Future<T> transactional(FutureOr<T> Function(MySQLConnection conn) callback)',
    },
    getterSignatures: {
      'host': 'String get host',
      'port': 'int get port',
      'userName': 'String get userName',
      'maxConnections': 'int get maxConnections',
      'databaseName': 'String? get databaseName',
      'secure': 'bool get secure',
      'collation': 'String get collation',
      'timeoutMs': 'int get timeoutMs',
      'activeConnectionsQty': 'int get activeConnectionsQty',
      'idleConnectionsQty': 'int get idleConnectionsQty',
      'allConnectionsQty': 'int get allConnectionsQty',
    },
  );
}

// =============================================================================
// TomStandalonePlatformUtils Bridge
// =============================================================================

BridgedClass _createTomStandalonePlatformUtilsBridge() {
  return BridgedClass(
    nativeType: TomStandalonePlatformUtils,
    name: 'TomStandalonePlatformUtils',
    isAssignable: (v) => v is TomStandalonePlatformUtils,
    constructors: {
      '': (visitor, positional, named) {
        return TomStandalonePlatformUtils();
      },
    },
    methods: {
      'isDesktop': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomStandalonePlatformUtils>(target, 'TomStandalonePlatformUtils');
        return t.isDesktop();
      },
      'isMobile': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomStandalonePlatformUtils>(target, 'TomStandalonePlatformUtils');
        return t.isMobile();
      },
      'isWeb': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomStandalonePlatformUtils>(target, 'TomStandalonePlatformUtils');
        return t.isWeb();
      },
      'isWindows': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomStandalonePlatformUtils>(target, 'TomStandalonePlatformUtils');
        return t.isWindows();
      },
      'isLinux': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomStandalonePlatformUtils>(target, 'TomStandalonePlatformUtils');
        return t.isLinux();
      },
      'isMacOs': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomStandalonePlatformUtils>(target, 'TomStandalonePlatformUtils');
        return t.isMacOs();
      },
      'isFuchsia': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomStandalonePlatformUtils>(target, 'TomStandalonePlatformUtils');
        return t.isFuchsia();
      },
      'isAndroid': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomStandalonePlatformUtils>(target, 'TomStandalonePlatformUtils');
        return t.isAndroid();
      },
      'isIos': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomStandalonePlatformUtils>(target, 'TomStandalonePlatformUtils');
        return t.isIos();
      },
      'outError': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomStandalonePlatformUtils>(target, 'TomStandalonePlatformUtils');
        D4.requireMinArgs(positional, 1, 'outError');
        final s = D4.getRequiredArg<String>(positional, 0, 's', 'outError');
        t.outError(s);
        return null;
      },
      'out': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomStandalonePlatformUtils>(target, 'TomStandalonePlatformUtils');
        D4.requireMinArgs(positional, 1, 'out');
        final s = D4.getRequiredArg<String>(positional, 0, 's', 'out');
        t.out(s);
        return null;
      },
      'httpClient': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomStandalonePlatformUtils>(target, 'TomStandalonePlatformUtils');
        return t.httpClient();
      },
      'getTomEnvVars': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomStandalonePlatformUtils>(target, 'TomStandalonePlatformUtils');
        return t.getTomEnvVars();
      },
      'getBrowserLocation': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomStandalonePlatformUtils>(target, 'TomStandalonePlatformUtils');
        return t.getBrowserLocation();
      },
      'getIsolateName': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomStandalonePlatformUtils>(target, 'TomStandalonePlatformUtils');
        return t.getIsolateName();
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomStandalonePlatformUtils>(target, 'TomStandalonePlatformUtils');
        return t.toString();
      },
    },
    constructorSignatures: {
      '': 'TomStandalonePlatformUtils()',
    },
    methodSignatures: {
      'isDesktop': 'bool isDesktop()',
      'isMobile': 'bool isMobile()',
      'isWeb': 'bool isWeb()',
      'isWindows': 'bool isWindows()',
      'isLinux': 'bool isLinux()',
      'isMacOs': 'bool isMacOs()',
      'isFuchsia': 'bool isFuchsia()',
      'isAndroid': 'bool isAndroid()',
      'isIos': 'bool isIos()',
      'outError': 'void outError(String s)',
      'out': 'void out(String s)',
      'httpClient': 'Client httpClient()',
      'getTomEnvVars': 'Map<String, String> getTomEnvVars()',
      'getBrowserLocation': 'String? getBrowserLocation()',
      'getIsolateName': 'String getIsolateName()',
      'toString': 'String toString()',
    },
  );
}

// =============================================================================
// TomBaseException Bridge
// =============================================================================

BridgedClass _createTomBaseExceptionBridge() {
  return BridgedClass(
    nativeType: TomBaseException,
    name: 'TomBaseException',
    isAssignable: (v) => v is TomBaseException,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'TomBaseException');
        final key = D4.getRequiredArg<String>(positional, 0, 'key', 'TomBaseException');
        final defaultUserMessage = D4.getRequiredArg<String>(positional, 1, 'defaultUserMessage', 'TomBaseException');
        final requestUuid = D4.getOptionalNamedArg<String?>(named, 'requestUuid');
        final parameters = D4.coerceMapOrNull<String, Object?>(named['parameters'], 'parameters');
        final rootException = D4.getOptionalNamedArg<Object?>(named, 'rootException');
        final stack = D4.getOptionalNamedArg<Object?>(named, 'stack');
        final uuid = D4.getOptionalNamedArg<String?>(named, 'uuid');
        return TomBaseException(key, defaultUserMessage, requestUuid: requestUuid, parameters: parameters, rootException: rootException, stack: stack, uuid: uuid);
      },
    },
    getters: {
      'uuid': (visitor, target) => D4.validateTarget<TomBaseException>(target, 'TomBaseException').uuid,
      'requestUuid': (visitor, target) => D4.validateTarget<TomBaseException>(target, 'TomBaseException').requestUuid,
      'timeStamp': (visitor, target) => D4.validateTarget<TomBaseException>(target, 'TomBaseException').timeStamp,
      'key': (visitor, target) => D4.validateTarget<TomBaseException>(target, 'TomBaseException').key,
      'defaultUserMessage': (visitor, target) => D4.validateTarget<TomBaseException>(target, 'TomBaseException').defaultUserMessage,
      'parameters': (visitor, target) => D4.validateTarget<TomBaseException>(target, 'TomBaseException').parameters,
      'stack': (visitor, target) => D4.validateTarget<TomBaseException>(target, 'TomBaseException').stack,
      'rootException': (visitor, target) => D4.validateTarget<TomBaseException>(target, 'TomBaseException').rootException,
      'stackTrace': (visitor, target) => D4.validateTarget<TomBaseException>(target, 'TomBaseException').stackTrace,
    },
    setters: {
      'uuid': (visitor, target, value) => 
        D4.validateTarget<TomBaseException>(target, 'TomBaseException').uuid = D4.extractBridgedArg<String>(value, 'uuid'),
      'requestUuid': (visitor, target, value) => 
        D4.validateTarget<TomBaseException>(target, 'TomBaseException').requestUuid = D4.extractBridgedArgOrNull<String>(value, 'requestUuid'),
      'timeStamp': (visitor, target, value) => 
        D4.validateTarget<TomBaseException>(target, 'TomBaseException').timeStamp = D4.extractBridgedArg<DateTime>(value, 'timeStamp'),
      'key': (visitor, target, value) => 
        D4.validateTarget<TomBaseException>(target, 'TomBaseException').key = D4.extractBridgedArg<String>(value, 'key'),
      'defaultUserMessage': (visitor, target, value) => 
        D4.validateTarget<TomBaseException>(target, 'TomBaseException').defaultUserMessage = D4.extractBridgedArg<String>(value, 'defaultUserMessage'),
      'stack': (visitor, target, value) => 
        D4.validateTarget<TomBaseException>(target, 'TomBaseException').stack = D4.extractBridgedArgOrNull<Object>(value, 'stack'),
      'rootException': (visitor, target, value) => 
        D4.validateTarget<TomBaseException>(target, 'TomBaseException').rootException = D4.extractBridgedArgOrNull<Object>(value, 'rootException'),
      'stackTrace': (visitor, target, value) => 
        D4.validateTarget<TomBaseException>(target, 'TomBaseException').stackTrace = D4.extractBridgedArg<String>(value, 'stackTrace'),
    },
    methods: {
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomBaseException>(target, 'TomBaseException');
        return t.toString();
      },
      'printStackTrace': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomBaseException>(target, 'TomBaseException');
        final depth = D4.getOptionalArgWithDefault<int>(positional, 0, 'depth', -1);
        t.printStackTrace(depth);
        return null;
      },
    },
    constructorSignatures: {
      '': 'TomBaseException(String key, String defaultUserMessage, {String? requestUuid, Map<String, Object?>? parameters, Object? rootException, Object? stack, String? uuid})',
    },
    methodSignatures: {
      'toString': 'String toString()',
      'printStackTrace': 'void printStackTrace([int depth = -1])',
    },
    getterSignatures: {
      'uuid': 'String get uuid',
      'requestUuid': 'String? get requestUuid',
      'timeStamp': 'DateTime get timeStamp',
      'key': 'String get key',
      'defaultUserMessage': 'String get defaultUserMessage',
      'parameters': 'Map<String, Object?>? get parameters',
      'stack': 'Object? get stack',
      'rootException': 'Object? get rootException',
      'stackTrace': 'String get stackTrace',
    },
    setterSignatures: {
      'uuid': 'set uuid(dynamic value)',
      'requestUuid': 'set requestUuid(dynamic value)',
      'timeStamp': 'set timeStamp(dynamic value)',
      'key': 'set key(dynamic value)',
      'defaultUserMessage': 'set defaultUserMessage(dynamic value)',
      'parameters': 'set parameters(dynamic value)',
      'stack': 'set stack(dynamic value)',
      'rootException': 'set rootException(dynamic value)',
      'stackTrace': 'set stackTrace(dynamic value)',
    },
  );
}

// =============================================================================
// TomLogLevel Bridge
// =============================================================================

BridgedClass _createTomLogLevelBridge() {
  return BridgedClass(
    nativeType: $tom_basics_1.TomLogLevel,
    name: 'TomLogLevel',
    isAssignable: (v) => v is $tom_basics_1.TomLogLevel,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomLogLevel');
        final levelPattern = D4.getRequiredArg<int>(positional, 0, 'levelPattern', 'TomLogLevel');
        return $tom_basics_1.TomLogLevel(levelPattern);
      },
    },
    getters: {
      'levelPattern': (visitor, target) => D4.validateTarget<$tom_basics_1.TomLogLevel>(target, 'TomLogLevel').levelPattern,
    },
    setters: {
      'levelPattern': (visitor, target, value) => 
        D4.validateTarget<$tom_basics_1.TomLogLevel>(target, 'TomLogLevel').levelPattern = D4.extractBridgedArg<int>(value, 'levelPattern'),
    },
    methods: {
      'matches': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_1.TomLogLevel>(target, 'TomLogLevel');
        D4.requireMinArgs(positional, 1, 'matches');
        final messageLevel = D4.getRequiredArg<$tom_basics_1.TomLogLevel>(positional, 0, 'messageLevel', 'matches');
        return t.matches(messageLevel);
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_1.TomLogLevel>(target, 'TomLogLevel');
        return t.toString();
      },
      '+': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_1.TomLogLevel>(target, 'TomLogLevel');
        final other = D4.getRequiredArg<$tom_basics_1.TomLogLevel>(positional, 0, 'other', 'operator+');
        return t + other;
      },
      '-': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_1.TomLogLevel>(target, 'TomLogLevel');
        final other = D4.getRequiredArg<$tom_basics_1.TomLogLevel>(positional, 0, 'other', 'operator-');
        return t - other;
      },
    },
    staticGetters: {
      'trace': (visitor) => $tom_basics_1.TomLogLevel.trace,
      'debug': (visitor) => $tom_basics_1.TomLogLevel.debug,
      'traffic': (visitor) => $tom_basics_1.TomLogLevel.traffic,
      'info': (visitor) => $tom_basics_1.TomLogLevel.info,
      'warn': (visitor) => $tom_basics_1.TomLogLevel.warn,
      'status': (visitor) => $tom_basics_1.TomLogLevel.status,
      'error': (visitor) => $tom_basics_1.TomLogLevel.error,
      'severe': (visitor) => $tom_basics_1.TomLogLevel.severe,
      'fatal': (visitor) => $tom_basics_1.TomLogLevel.fatal,
      'all': (visitor) => $tom_basics_1.TomLogLevel.all,
      'development': (visitor) => $tom_basics_1.TomLogLevel.development,
      'extended': (visitor) => $tom_basics_1.TomLogLevel.extended,
      'errors': (visitor) => $tom_basics_1.TomLogLevel.errors,
      'production': (visitor) => $tom_basics_1.TomLogLevel.production,
      'still': (visitor) => $tom_basics_1.TomLogLevel.still,
      'silent': (visitor) => $tom_basics_1.TomLogLevel.silent,
      'off': (visitor) => $tom_basics_1.TomLogLevel.off,
      'none': (visitor) => $tom_basics_1.TomLogLevel.none,
    },
    staticMethods: {
      'byName': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'byName');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'byName');
        return $tom_basics_1.TomLogLevel.byName(name);
      },
    },
    staticSetters: {
      'trace': (visitor, value) => 
        $tom_basics_1.TomLogLevel.trace = D4.extractBridgedArg<$tom_basics_1.TomLogLevel>(value, 'trace'),
      'debug': (visitor, value) => 
        $tom_basics_1.TomLogLevel.debug = D4.extractBridgedArg<$tom_basics_1.TomLogLevel>(value, 'debug'),
      'traffic': (visitor, value) => 
        $tom_basics_1.TomLogLevel.traffic = D4.extractBridgedArg<$tom_basics_1.TomLogLevel>(value, 'traffic'),
      'info': (visitor, value) => 
        $tom_basics_1.TomLogLevel.info = D4.extractBridgedArg<$tom_basics_1.TomLogLevel>(value, 'info'),
      'warn': (visitor, value) => 
        $tom_basics_1.TomLogLevel.warn = D4.extractBridgedArg<$tom_basics_1.TomLogLevel>(value, 'warn'),
      'status': (visitor, value) => 
        $tom_basics_1.TomLogLevel.status = D4.extractBridgedArg<$tom_basics_1.TomLogLevel>(value, 'status'),
      'error': (visitor, value) => 
        $tom_basics_1.TomLogLevel.error = D4.extractBridgedArg<$tom_basics_1.TomLogLevel>(value, 'error'),
      'severe': (visitor, value) => 
        $tom_basics_1.TomLogLevel.severe = D4.extractBridgedArg<$tom_basics_1.TomLogLevel>(value, 'severe'),
      'fatal': (visitor, value) => 
        $tom_basics_1.TomLogLevel.fatal = D4.extractBridgedArg<$tom_basics_1.TomLogLevel>(value, 'fatal'),
      'all': (visitor, value) => 
        $tom_basics_1.TomLogLevel.all = D4.extractBridgedArg<$tom_basics_1.TomLogLevel>(value, 'all'),
      'development': (visitor, value) => 
        $tom_basics_1.TomLogLevel.development = D4.extractBridgedArg<$tom_basics_1.TomLogLevel>(value, 'development'),
      'extended': (visitor, value) => 
        $tom_basics_1.TomLogLevel.extended = D4.extractBridgedArg<$tom_basics_1.TomLogLevel>(value, 'extended'),
      'errors': (visitor, value) => 
        $tom_basics_1.TomLogLevel.errors = D4.extractBridgedArg<$tom_basics_1.TomLogLevel>(value, 'errors'),
      'production': (visitor, value) => 
        $tom_basics_1.TomLogLevel.production = D4.extractBridgedArg<$tom_basics_1.TomLogLevel>(value, 'production'),
      'still': (visitor, value) => 
        $tom_basics_1.TomLogLevel.still = D4.extractBridgedArg<$tom_basics_1.TomLogLevel>(value, 'still'),
      'silent': (visitor, value) => 
        $tom_basics_1.TomLogLevel.silent = D4.extractBridgedArg<$tom_basics_1.TomLogLevel>(value, 'silent'),
      'off': (visitor, value) => 
        $tom_basics_1.TomLogLevel.off = D4.extractBridgedArg<$tom_basics_1.TomLogLevel>(value, 'off'),
      'none': (visitor, value) => 
        $tom_basics_1.TomLogLevel.none = D4.extractBridgedArg<$tom_basics_1.TomLogLevel>(value, 'none'),
    },
    constructorSignatures: {
      '': 'TomLogLevel(int levelPattern)',
    },
    methodSignatures: {
      'matches': 'bool matches(TomLogLevel messageLevel)',
      'toString': 'String toString()',
    },
    getterSignatures: {
      'levelPattern': 'int get levelPattern',
    },
    setterSignatures: {
      'levelPattern': 'set levelPattern(dynamic value)',
    },
    staticMethodSignatures: {
      'byName': 'TomLogLevel? byName(String name)',
    },
    staticGetterSignatures: {
      'trace': 'TomLogLevel get trace',
      'debug': 'TomLogLevel get debug',
      'traffic': 'TomLogLevel get traffic',
      'info': 'TomLogLevel get info',
      'warn': 'TomLogLevel get warn',
      'status': 'TomLogLevel get status',
      'error': 'TomLogLevel get error',
      'severe': 'TomLogLevel get severe',
      'fatal': 'TomLogLevel get fatal',
      'all': 'TomLogLevel get all',
      'development': 'TomLogLevel get development',
      'extended': 'TomLogLevel get extended',
      'errors': 'TomLogLevel get errors',
      'production': 'TomLogLevel get production',
      'still': 'TomLogLevel get still',
      'silent': 'TomLogLevel get silent',
      'off': 'TomLogLevel get off',
      'none': 'TomLogLevel get none',
    },
    staticSetterSignatures: {
      'trace': 'set trace(dynamic value)',
      'debug': 'set debug(dynamic value)',
      'traffic': 'set traffic(dynamic value)',
      'info': 'set info(dynamic value)',
      'warn': 'set warn(dynamic value)',
      'status': 'set status(dynamic value)',
      'error': 'set error(dynamic value)',
      'severe': 'set severe(dynamic value)',
      'fatal': 'set fatal(dynamic value)',
      'all': 'set all(dynamic value)',
      'development': 'set development(dynamic value)',
      'extended': 'set extended(dynamic value)',
      'errors': 'set errors(dynamic value)',
      'production': 'set production(dynamic value)',
      'still': 'set still(dynamic value)',
      'silent': 'set silent(dynamic value)',
      'off': 'set off(dynamic value)',
      'none': 'set none(dynamic value)',
    },
  );
}

// =============================================================================
// TomLogger Bridge
// =============================================================================

BridgedClass _createTomLoggerBridge() {
  return BridgedClass(
    nativeType: $tom_basics_1.TomLogger,
    name: 'TomLogger',
    isAssignable: (v) => v is $tom_basics_1.TomLogger,
    constructors: {
      '': (visitor, positional, named) {
        return $tom_basics_1.TomLogger();
      },
    },
    getters: {
      'logLevel': (visitor, target) => D4.validateTarget<$tom_basics_1.TomLogger>(target, 'TomLogger').logLevel,
      'logOutput': (visitor, target) => D4.validateTarget<$tom_basics_1.TomLogger>(target, 'TomLogger').logOutput,
    },
    setters: {
      'logOutput': (visitor, target, value) => 
        D4.validateTarget<$tom_basics_1.TomLogger>(target, 'TomLogger').logOutput = D4.extractBridgedArg<$tom_basics_1.TomLogOutput>(value, 'logOutput'),
    },
    methods: {
      'setLogLevel': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_1.TomLogger>(target, 'TomLogger');
        D4.requireMinArgs(positional, 1, 'setLogLevel');
        final l = D4.getRequiredArg<$tom_basics_1.TomLogLevel>(positional, 0, 'l', 'setLogLevel');
        t.setLogLevel(l);
        return null;
      },
      'pushLogLevel': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_1.TomLogger>(target, 'TomLogger');
        D4.requireMinArgs(positional, 1, 'pushLogLevel');
        final l = D4.getRequiredArg<$tom_basics_1.TomLogLevel>(positional, 0, 'l', 'pushLogLevel');
        t.pushLogLevel(l);
        return null;
      },
      'popLogLevel': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_1.TomLogger>(target, 'TomLogger');
        t.popLogLevel();
        return null;
      },
      'info': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_1.TomLogger>(target, 'TomLogger');
        D4.requireMinArgs(positional, 1, 'info');
        final s = D4.getRequiredArg<Object>(positional, 0, 's', 'info');
        t.info(s);
        return null;
      },
      'warn': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_1.TomLogger>(target, 'TomLogger');
        D4.requireMinArgs(positional, 1, 'warn');
        final s = D4.getRequiredArg<Object>(positional, 0, 's', 'warn');
        t.warn(s);
        return null;
      },
      'error': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_1.TomLogger>(target, 'TomLogger');
        D4.requireMinArgs(positional, 1, 'error');
        final s = D4.getRequiredArg<Object>(positional, 0, 's', 'error');
        t.error(s);
        return null;
      },
      'debug': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_1.TomLogger>(target, 'TomLogger');
        D4.requireMinArgs(positional, 1, 'debug');
        final s = D4.getRequiredArg<Object>(positional, 0, 's', 'debug');
        t.debug(s);
        return null;
      },
      'trace': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_1.TomLogger>(target, 'TomLogger');
        D4.requireMinArgs(positional, 1, 'trace');
        final s = D4.getRequiredArg<Object>(positional, 0, 's', 'trace');
        t.trace(s);
        return null;
      },
      'traffic': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_1.TomLogger>(target, 'TomLogger');
        D4.requireMinArgs(positional, 1, 'traffic');
        final s = D4.getRequiredArg<Object>(positional, 0, 's', 'traffic');
        t.traffic(s);
        return null;
      },
      'severe': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_1.TomLogger>(target, 'TomLogger');
        D4.requireMinArgs(positional, 1, 'severe');
        final s = D4.getRequiredArg<Object>(positional, 0, 's', 'severe');
        t.severe(s);
        return null;
      },
      'fatal': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_1.TomLogger>(target, 'TomLogger');
        D4.requireMinArgs(positional, 1, 'fatal');
        final s = D4.getRequiredArg<Object>(positional, 0, 's', 'fatal');
        t.fatal(s);
        return null;
      },
      'status': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_1.TomLogger>(target, 'TomLogger');
        D4.requireMinArgs(positional, 1, 'status');
        final s = D4.getRequiredArg<Object>(positional, 0, 's', 'status');
        t.status(s);
        return null;
      },
      'output': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_1.TomLogger>(target, 'TomLogger');
        D4.requireMinArgs(positional, 3, 'output');
        final messageLogLevel = D4.getRequiredArg<$tom_basics_1.TomLogLevel>(positional, 0, 'messageLogLevel', 'output');
        final level = D4.getRequiredArg<String>(positional, 1, 'level', 'output');
        final message = D4.getRequiredArg<Object>(positional, 2, 'message', 'output');
        t.output(messageLogLevel, level, message);
        return null;
      },
      'addNameLevel': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_1.TomLogger>(target, 'TomLogger');
        D4.requireMinArgs(positional, 2, 'addNameLevel');
        final t_ = D4.getRequiredArg<String>(positional, 0, 't', 'addNameLevel');
        final tll = D4.getRequiredArg<$tom_basics_1.TomLogLevel>(positional, 1, 'tll', 'addNameLevel');
        t.addNameLevel(t_, tll);
        return null;
      },
      'getNameLevel': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_1.TomLogger>(target, 'TomLogger');
        D4.requireMinArgs(positional, 1, 'getNameLevel');
        final t_ = D4.getRequiredArg<String>(positional, 0, 't', 'getNameLevel');
        return t.getNameLevel(t_);
      },
      'removeNameLevel': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_1.TomLogger>(target, 'TomLogger');
        D4.requireMinArgs(positional, 1, 'removeNameLevel');
        final t_ = D4.getRequiredArg<String>(positional, 0, 't', 'removeNameLevel');
        t.removeNameLevel(t_);
        return null;
      },
      'setLogLevelByName': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_1.TomLogger>(target, 'TomLogger');
        D4.requireMinArgs(positional, 1, 'setLogLevelByName');
        final levelName = D4.getRequiredArg<String>(positional, 0, 'levelName', 'setLogLevelByName');
        t.setLogLevelByName(levelName);
        return null;
      },
      'setLogLevelExceptions': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_1.TomLogger>(target, 'TomLogger');
        D4.requireMinArgs(positional, 1, 'setLogLevelExceptions');
        final pattern = D4.getRequiredArg<String>(positional, 0, 'pattern', 'setLogLevelExceptions');
        t.setLogLevelExceptions(pattern);
        return null;
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_1.TomLogger>(target, 'TomLogger');
        return t.toString();
      },
    },
    staticGetters: {
      'INFO': (visitor) => $tom_basics_1.TomLogger.INFO,
      'ERROR': (visitor) => $tom_basics_1.TomLogger.ERROR,
      'WARN': (visitor) => $tom_basics_1.TomLogger.WARN,
      'DEBUG': (visitor) => $tom_basics_1.TomLogger.DEBUG,
      'TRACE': (visitor) => $tom_basics_1.TomLogger.TRACE,
      'TRAFFIC': (visitor) => $tom_basics_1.TomLogger.TRAFFIC,
      'SEVERE': (visitor) => $tom_basics_1.TomLogger.SEVERE,
      'FATAL': (visitor) => $tom_basics_1.TomLogger.FATAL,
      'STATUS': (visitor) => $tom_basics_1.TomLogger.STATUS,
      'globalSettingDetermineCaller': (visitor) => $tom_basics_1.TomLogger.globalSettingDetermineCaller,
      'fallback': (visitor) => $tom_basics_1.TomLogger.fallback,
      'globalSettingInfoEnabled': (visitor) => $tom_basics_1.TomLogger.globalSettingInfoEnabled,
      'globalSettingWarnEnabled': (visitor) => $tom_basics_1.TomLogger.globalSettingWarnEnabled,
      'globalSettingErrorEnabled': (visitor) => $tom_basics_1.TomLogger.globalSettingErrorEnabled,
      'globalSettingDebugEnabled': (visitor) => $tom_basics_1.TomLogger.globalSettingDebugEnabled,
      'globalSettingTraceEnabled': (visitor) => $tom_basics_1.TomLogger.globalSettingTraceEnabled,
      'globalSettingTrafficEnabled': (visitor) => $tom_basics_1.TomLogger.globalSettingTrafficEnabled,
      'globalSettingSevereEnabled': (visitor) => $tom_basics_1.TomLogger.globalSettingSevereEnabled,
      'globalSettingFatalEnabled': (visitor) => $tom_basics_1.TomLogger.globalSettingFatalEnabled,
      'globalSettingStatusEnabled': (visitor) => $tom_basics_1.TomLogger.globalSettingStatusEnabled,
    },
    staticSetters: {
      'globalSettingDetermineCaller': (visitor, value) => 
        $tom_basics_1.TomLogger.globalSettingDetermineCaller = D4.extractBridgedArg<bool>(value, 'globalSettingDetermineCaller'),
      'globalSettingInfoEnabled': (visitor, value) => 
        $tom_basics_1.TomLogger.globalSettingInfoEnabled = D4.extractBridgedArg<bool>(value, 'globalSettingInfoEnabled'),
      'globalSettingWarnEnabled': (visitor, value) => 
        $tom_basics_1.TomLogger.globalSettingWarnEnabled = D4.extractBridgedArg<bool>(value, 'globalSettingWarnEnabled'),
      'globalSettingErrorEnabled': (visitor, value) => 
        $tom_basics_1.TomLogger.globalSettingErrorEnabled = D4.extractBridgedArg<bool>(value, 'globalSettingErrorEnabled'),
      'globalSettingDebugEnabled': (visitor, value) => 
        $tom_basics_1.TomLogger.globalSettingDebugEnabled = D4.extractBridgedArg<bool>(value, 'globalSettingDebugEnabled'),
      'globalSettingTraceEnabled': (visitor, value) => 
        $tom_basics_1.TomLogger.globalSettingTraceEnabled = D4.extractBridgedArg<bool>(value, 'globalSettingTraceEnabled'),
      'globalSettingTrafficEnabled': (visitor, value) => 
        $tom_basics_1.TomLogger.globalSettingTrafficEnabled = D4.extractBridgedArg<bool>(value, 'globalSettingTrafficEnabled'),
      'globalSettingSevereEnabled': (visitor, value) => 
        $tom_basics_1.TomLogger.globalSettingSevereEnabled = D4.extractBridgedArg<bool>(value, 'globalSettingSevereEnabled'),
      'globalSettingFatalEnabled': (visitor, value) => 
        $tom_basics_1.TomLogger.globalSettingFatalEnabled = D4.extractBridgedArg<bool>(value, 'globalSettingFatalEnabled'),
      'globalSettingStatusEnabled': (visitor, value) => 
        $tom_basics_1.TomLogger.globalSettingStatusEnabled = D4.extractBridgedArg<bool>(value, 'globalSettingStatusEnabled'),
    },
    constructorSignatures: {
      '': 'TomLogger()',
    },
    methodSignatures: {
      'setLogLevel': 'void setLogLevel(TomLogLevel l)',
      'pushLogLevel': 'void pushLogLevel(TomLogLevel l)',
      'popLogLevel': 'void popLogLevel()',
      'info': 'void info(Object s)',
      'warn': 'void warn(Object s)',
      'error': 'void error(Object s)',
      'debug': 'void debug(Object s)',
      'trace': 'void trace(Object s)',
      'traffic': 'void traffic(Object s)',
      'severe': 'void severe(Object s)',
      'fatal': 'void fatal(Object s)',
      'status': 'void status(Object s)',
      'output': 'void output(TomLogLevel messageLogLevel, String level, Object message)',
      'addNameLevel': 'void addNameLevel(String t, TomLogLevel tll)',
      'getNameLevel': 'TomLogLevel? getNameLevel(String t)',
      'removeNameLevel': 'void removeNameLevel(String t)',
      'setLogLevelByName': 'void setLogLevelByName(String levelName)',
      'setLogLevelExceptions': 'void setLogLevelExceptions(String pattern)',
      'toString': 'String toString()',
    },
    getterSignatures: {
      'logLevel': 'TomLogLevel get logLevel',
      'logOutput': 'TomLogOutput get logOutput',
    },
    setterSignatures: {
      'logOutput': 'set logOutput(dynamic value)',
    },
    staticGetterSignatures: {
      'INFO': 'String get INFO',
      'ERROR': 'String get ERROR',
      'WARN': 'String get WARN',
      'DEBUG': 'String get DEBUG',
      'TRACE': 'String get TRACE',
      'TRAFFIC': 'String get TRAFFIC',
      'SEVERE': 'String get SEVERE',
      'FATAL': 'String get FATAL',
      'STATUS': 'String get STATUS',
      'globalSettingDetermineCaller': 'bool get globalSettingDetermineCaller',
      'fallback': 'Type get fallback',
      'globalSettingInfoEnabled': 'bool get globalSettingInfoEnabled',
      'globalSettingWarnEnabled': 'bool get globalSettingWarnEnabled',
      'globalSettingErrorEnabled': 'bool get globalSettingErrorEnabled',
      'globalSettingDebugEnabled': 'bool get globalSettingDebugEnabled',
      'globalSettingTraceEnabled': 'bool get globalSettingTraceEnabled',
      'globalSettingTrafficEnabled': 'bool get globalSettingTrafficEnabled',
      'globalSettingSevereEnabled': 'bool get globalSettingSevereEnabled',
      'globalSettingFatalEnabled': 'bool get globalSettingFatalEnabled',
      'globalSettingStatusEnabled': 'bool get globalSettingStatusEnabled',
    },
    staticSetterSignatures: {
      'globalSettingDetermineCaller': 'set globalSettingDetermineCaller(dynamic value)',
      'globalSettingInfoEnabled': 'set globalSettingInfoEnabled(dynamic value)',
      'globalSettingWarnEnabled': 'set globalSettingWarnEnabled(dynamic value)',
      'globalSettingErrorEnabled': 'set globalSettingErrorEnabled(dynamic value)',
      'globalSettingDebugEnabled': 'set globalSettingDebugEnabled(dynamic value)',
      'globalSettingTraceEnabled': 'set globalSettingTraceEnabled(dynamic value)',
      'globalSettingTrafficEnabled': 'set globalSettingTrafficEnabled(dynamic value)',
      'globalSettingSevereEnabled': 'set globalSettingSevereEnabled(dynamic value)',
      'globalSettingFatalEnabled': 'set globalSettingFatalEnabled(dynamic value)',
      'globalSettingStatusEnabled': 'set globalSettingStatusEnabled(dynamic value)',
    },
  );
}

// =============================================================================
// TomLoggable Bridge
// =============================================================================

BridgedClass _createTomLoggableBridge() {
  return BridgedClass(
    nativeType: TomLoggable,
    name: 'TomLoggable',
    isAssignable: (v) => v is TomLoggable,
    constructors: {
    },
    getters: {
      'logRepresentation': (visitor, target) => D4.validateTarget<TomLoggable>(target, 'TomLoggable').logRepresentation,
    },
    getterSignatures: {
      'logRepresentation': 'String get logRepresentation',
    },
  );
}

// =============================================================================
// TomLogOutput Bridge
// =============================================================================

BridgedClass _createTomLogOutputBridge() {
  return BridgedClass(
    nativeType: $tom_basics_1.TomLogOutput,
    name: 'TomLogOutput',
    isAssignable: (v) => v is $tom_basics_1.TomLogOutput,
    constructors: {
    },
    methods: {
      'output': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_1.TomLogOutput>(target, 'TomLogOutput');
        D4.requireMinArgs(positional, 7, 'output');
        final loggerLevel = D4.getRequiredArg<$tom_basics_1.TomLogLevel>(positional, 0, 'loggerLevel', 'output');
        final logLevel = D4.getRequiredArg<$tom_basics_1.TomLogLevel>(positional, 1, 'logLevel', 'output');
        final level = D4.getRequiredArg<String>(positional, 2, 'level', 'output');
        final message = D4.getRequiredArg<Object>(positional, 3, 'message', 'output');
        final isolateName = D4.getRequiredArg<String>(positional, 4, 'isolateName', 'output');
        final timeStamp = D4.getRequiredArg<DateTime>(positional, 5, 'timeStamp', 'output');
        final origin = D4.getRequiredArg<String?>(positional, 6, 'origin', 'output');
        t.output(loggerLevel, logLevel, level, message, isolateName, timeStamp, origin);
        return null;
      },
      'convertToString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_1.TomLogOutput>(target, 'TomLogOutput');
        D4.requireMinArgs(positional, 1, 'convertToString');
        final message = D4.getRequiredArg<Object>(positional, 0, 'message', 'convertToString');
        return t.convertToString(message);
      },
    },
    staticGetters: {
      'globalSettingRemoteLogEndpoint': (visitor) => $tom_basics_1.TomLogOutput.globalSettingRemoteLogEndpoint,
    },
    staticSetters: {
      'globalSettingRemoteLogEndpoint': (visitor, value) => 
        $tom_basics_1.TomLogOutput.globalSettingRemoteLogEndpoint = D4.extractBridgedArg<String>(value, 'globalSettingRemoteLogEndpoint'),
    },
    methodSignatures: {
      'output': 'void output(TomLogLevel loggerLevel, TomLogLevel logLevel, String level, Object message, String isolateName, DateTime timeStamp, String? origin)',
      'convertToString': 'String convertToString(Object message)',
    },
    staticGetterSignatures: {
      'globalSettingRemoteLogEndpoint': 'String get globalSettingRemoteLogEndpoint',
    },
    staticSetterSignatures: {
      'globalSettingRemoteLogEndpoint': 'set globalSettingRemoteLogEndpoint(dynamic value)',
    },
  );
}

// =============================================================================
// TomConsoleLogOutput Bridge
// =============================================================================

BridgedClass _createTomConsoleLogOutputBridge() {
  return BridgedClass(
    nativeType: TomConsoleLogOutput,
    name: 'TomConsoleLogOutput',
    isAssignable: (v) => v is TomConsoleLogOutput,
    constructors: {
      '': (visitor, positional, named) {
        return TomConsoleLogOutput();
      },
    },
    getters: {
      'useExtendedFormat': (visitor, target) => D4.validateTarget<TomConsoleLogOutput>(target, 'TomConsoleLogOutput').useExtendedFormat,
    },
    setters: {
      'useExtendedFormat': (visitor, target, value) => 
        D4.validateTarget<TomConsoleLogOutput>(target, 'TomConsoleLogOutput').useExtendedFormat = D4.extractBridgedArg<bool>(value, 'useExtendedFormat'),
    },
    methods: {
      'output': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomConsoleLogOutput>(target, 'TomConsoleLogOutput');
        D4.requireMinArgs(positional, 6, 'output');
        final loggerLevel = D4.getRequiredArg<$tom_basics_1.TomLogLevel>(positional, 0, 'loggerLevel', 'output');
        final logLevel = D4.getRequiredArg<$tom_basics_1.TomLogLevel>(positional, 1, 'logLevel', 'output');
        final level = D4.getRequiredArg<String>(positional, 2, 'level', 'output');
        final message = D4.getRequiredArg<Object>(positional, 3, 'message', 'output');
        final isolateName = D4.getRequiredArg<String>(positional, 4, 'isolateName', 'output');
        final timeStamp = D4.getRequiredArg<DateTime>(positional, 5, 'timeStamp', 'output');
        final origin = D4.getOptionalArg<String?>(positional, 6, 'origin');
        t.output(loggerLevel, logLevel, level, message, isolateName, timeStamp, origin);
        return null;
      },
      'convertToString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomConsoleLogOutput>(target, 'TomConsoleLogOutput');
        D4.requireMinArgs(positional, 1, 'convertToString');
        final message = D4.getRequiredArg<Object>(positional, 0, 'message', 'convertToString');
        return t.convertToString(message);
      },
    },
    staticGetters: {
      'globalSettingStderrLogLevel': (visitor) => TomConsoleLogOutput.globalSettingStderrLogLevel,
      'globalSettingStdoutLogLevel': (visitor) => TomConsoleLogOutput.globalSettingStdoutLogLevel,
    },
    staticSetters: {
      'globalSettingStderrLogLevel': (visitor, value) => 
        TomConsoleLogOutput.globalSettingStderrLogLevel = D4.extractBridgedArg<$tom_basics_1.TomLogLevel>(value, 'globalSettingStderrLogLevel'),
      'globalSettingStdoutLogLevel': (visitor, value) => 
        TomConsoleLogOutput.globalSettingStdoutLogLevel = D4.extractBridgedArg<$tom_basics_1.TomLogLevel>(value, 'globalSettingStdoutLogLevel'),
    },
    constructorSignatures: {
      '': 'TomConsoleLogOutput()',
    },
    methodSignatures: {
      'output': 'void output(TomLogLevel loggerLevel, TomLogLevel logLevel, String level, Object message, String isolateName, DateTime timeStamp, [String? origin])',
      'convertToString': 'String convertToString(Object message)',
    },
    getterSignatures: {
      'useExtendedFormat': 'bool get useExtendedFormat',
    },
    setterSignatures: {
      'useExtendedFormat': 'set useExtendedFormat(dynamic value)',
    },
    staticGetterSignatures: {
      'globalSettingStderrLogLevel': 'TomLogLevel get globalSettingStderrLogLevel',
      'globalSettingStdoutLogLevel': 'TomLogLevel get globalSettingStdoutLogLevel',
    },
    staticSetterSignatures: {
      'globalSettingStderrLogLevel': 'set globalSettingStderrLogLevel(dynamic value)',
      'globalSettingStdoutLogLevel': 'set globalSettingStdoutLogLevel(dynamic value)',
    },
  );
}

// =============================================================================
// TomPlatformUtils Bridge
// =============================================================================

BridgedClass _createTomPlatformUtilsBridge() {
  return BridgedClass(
    nativeType: $tom_basics_3.TomPlatformUtils,
    name: 'TomPlatformUtils',
    isAssignable: (v) => v is $tom_basics_3.TomPlatformUtils,
    constructors: {
    },
    methods: {
      'isDesktop': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_3.TomPlatformUtils>(target, 'TomPlatformUtils');
        return t.isDesktop();
      },
      'isMobile': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_3.TomPlatformUtils>(target, 'TomPlatformUtils');
        return t.isMobile();
      },
      'isWeb': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_3.TomPlatformUtils>(target, 'TomPlatformUtils');
        return t.isWeb();
      },
      'isWindows': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_3.TomPlatformUtils>(target, 'TomPlatformUtils');
        return t.isWindows();
      },
      'isLinux': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_3.TomPlatformUtils>(target, 'TomPlatformUtils');
        return t.isLinux();
      },
      'isMacOs': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_3.TomPlatformUtils>(target, 'TomPlatformUtils');
        return t.isMacOs();
      },
      'isFuchsia': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_3.TomPlatformUtils>(target, 'TomPlatformUtils');
        return t.isFuchsia();
      },
      'isAndroid': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_3.TomPlatformUtils>(target, 'TomPlatformUtils');
        return t.isAndroid();
      },
      'isIos': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_3.TomPlatformUtils>(target, 'TomPlatformUtils');
        return t.isIos();
      },
      'outError': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_3.TomPlatformUtils>(target, 'TomPlatformUtils');
        D4.requireMinArgs(positional, 1, 'outError');
        final s = D4.getRequiredArg<String>(positional, 0, 's', 'outError');
        t.outError(s);
        return null;
      },
      'out': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_3.TomPlatformUtils>(target, 'TomPlatformUtils');
        D4.requireMinArgs(positional, 1, 'out');
        final s = D4.getRequiredArg<String>(positional, 0, 's', 'out');
        t.out(s);
        return null;
      },
      'httpClient': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_3.TomPlatformUtils>(target, 'TomPlatformUtils');
        return t.httpClient();
      },
      'getTomEnvVars': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_3.TomPlatformUtils>(target, 'TomPlatformUtils');
        return t.getTomEnvVars();
      },
      'getBrowserLocation': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_3.TomPlatformUtils>(target, 'TomPlatformUtils');
        return t.getBrowserLocation();
      },
      'getIsolateName': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_3.TomPlatformUtils>(target, 'TomPlatformUtils');
        return t.getIsolateName();
      },
    },
    staticGetters: {
      'envVars': (visitor) => $tom_basics_3.TomPlatformUtils.envVars,
      'current': (visitor) => $tom_basics_3.TomPlatformUtils.current,
    },
    staticMethods: {
      'setCurrentPlatform': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'setCurrentPlatform');
        final newCurrent = D4.getRequiredArg<$tom_basics_3.TomPlatformUtils>(positional, 0, 'newCurrent', 'setCurrentPlatform');
        return $tom_basics_3.TomPlatformUtils.setCurrentPlatform(newCurrent);
      },
    },
    staticSetters: {
      'envVars': (visitor, value) => 
        $tom_basics_3.TomPlatformUtils.envVars = (value as Map).cast<String, String>(),
    },
    methodSignatures: {
      'isDesktop': 'bool isDesktop()',
      'isMobile': 'bool isMobile()',
      'isWeb': 'bool isWeb()',
      'isWindows': 'bool isWindows()',
      'isLinux': 'bool isLinux()',
      'isMacOs': 'bool isMacOs()',
      'isFuchsia': 'bool isFuchsia()',
      'isAndroid': 'bool isAndroid()',
      'isIos': 'bool isIos()',
      'outError': 'void outError(String s)',
      'out': 'void out(String s)',
      'httpClient': 'Client httpClient()',
      'getTomEnvVars': 'Map<String, String> getTomEnvVars()',
      'getBrowserLocation': 'String? getBrowserLocation()',
      'getIsolateName': 'String getIsolateName()',
    },
    staticMethodSignatures: {
      'setCurrentPlatform': 'void setCurrentPlatform(TomPlatformUtils newCurrent)',
    },
    staticGetterSignatures: {
      'envVars': 'Map<String, String> get envVars',
      'current': 'TomPlatformUtils get current',
    },
    staticSetterSignatures: {
      'envVars': 'set envVars(dynamic value)',
    },
  );
}

// =============================================================================
// TomFallbackPlatformUtils Bridge
// =============================================================================

BridgedClass _createTomFallbackPlatformUtilsBridge() {
  return BridgedClass(
    nativeType: TomFallbackPlatformUtils,
    name: 'TomFallbackPlatformUtils',
    isAssignable: (v) => v is TomFallbackPlatformUtils,
    constructors: {
      '': (visitor, positional, named) {
        return TomFallbackPlatformUtils();
      },
    },
    methods: {
      'isDesktop': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomFallbackPlatformUtils>(target, 'TomFallbackPlatformUtils');
        return t.isDesktop();
      },
      'isMobile': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomFallbackPlatformUtils>(target, 'TomFallbackPlatformUtils');
        return t.isMobile();
      },
      'isWeb': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomFallbackPlatformUtils>(target, 'TomFallbackPlatformUtils');
        return t.isWeb();
      },
      'isWindows': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomFallbackPlatformUtils>(target, 'TomFallbackPlatformUtils');
        return t.isWindows();
      },
      'isLinux': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomFallbackPlatformUtils>(target, 'TomFallbackPlatformUtils');
        return t.isLinux();
      },
      'isMacOs': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomFallbackPlatformUtils>(target, 'TomFallbackPlatformUtils');
        return t.isMacOs();
      },
      'isFuchsia': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomFallbackPlatformUtils>(target, 'TomFallbackPlatformUtils');
        return t.isFuchsia();
      },
      'isAndroid': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomFallbackPlatformUtils>(target, 'TomFallbackPlatformUtils');
        return t.isAndroid();
      },
      'isIos': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomFallbackPlatformUtils>(target, 'TomFallbackPlatformUtils');
        return t.isIos();
      },
      'outError': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomFallbackPlatformUtils>(target, 'TomFallbackPlatformUtils');
        D4.requireMinArgs(positional, 1, 'outError');
        final s = D4.getRequiredArg<String>(positional, 0, 's', 'outError');
        t.outError(s);
        return null;
      },
      'out': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomFallbackPlatformUtils>(target, 'TomFallbackPlatformUtils');
        D4.requireMinArgs(positional, 1, 'out');
        final s = D4.getRequiredArg<String>(positional, 0, 's', 'out');
        t.out(s);
        return null;
      },
      'httpClient': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomFallbackPlatformUtils>(target, 'TomFallbackPlatformUtils');
        return t.httpClient();
      },
      'getTomEnvVars': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomFallbackPlatformUtils>(target, 'TomFallbackPlatformUtils');
        return t.getTomEnvVars();
      },
      'getBrowserLocation': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomFallbackPlatformUtils>(target, 'TomFallbackPlatformUtils');
        return t.getBrowserLocation();
      },
      'getIsolateName': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<TomFallbackPlatformUtils>(target, 'TomFallbackPlatformUtils');
        return t.getIsolateName();
      },
    },
    constructorSignatures: {
      '': 'TomFallbackPlatformUtils()',
    },
    methodSignatures: {
      'isDesktop': 'bool isDesktop()',
      'isMobile': 'bool isMobile()',
      'isWeb': 'bool isWeb()',
      'isWindows': 'bool isWindows()',
      'isLinux': 'bool isLinux()',
      'isMacOs': 'bool isMacOs()',
      'isFuchsia': 'bool isFuchsia()',
      'isAndroid': 'bool isAndroid()',
      'isIos': 'bool isIos()',
      'outError': 'void outError(String s)',
      'out': 'void out(String s)',
      'httpClient': 'Client httpClient()',
      'getTomEnvVars': 'Map<String, String> getTomEnvVars()',
      'getBrowserLocation': 'String? getBrowserLocation()',
      'getIsolateName': 'String getIsolateName()',
    },
  );
}

// =============================================================================
// TomEnvironment Bridge
// =============================================================================

BridgedClass _createTomEnvironmentBridge() {
  return BridgedClass(
    nativeType: $tom_basics_2.TomEnvironment,
    name: 'TomEnvironment',
    isAssignable: (v) => v is $tom_basics_2.TomEnvironment,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomEnvironment');
        final env = D4.getRequiredArg<String>(positional, 0, 'env', 'TomEnvironment');
        final parent = D4.getOptionalNamedArg<$tom_basics_2.TomEnvironment?>(named, 'parent');
        final initializerRaw = named['initializer'];
        final isTest = D4.getNamedArgWithDefault<bool>(named, 'isTest', false);
        final isDevelopment = D4.getNamedArgWithDefault<bool>(named, 'isDevelopment', false);
        return $tom_basics_2.TomEnvironment(env, parent: parent, initializer: initializerRaw == null ? null : ($tom_basics_2.TomEnvironment p0) { D4.callInterpreterCallback(visitor!, initializerRaw, [p0]); }, isTest: isTest, isDevelopment: isDevelopment);
      },
    },
    getters: {
      'parent': (visitor, target) => D4.validateTarget<$tom_basics_2.TomEnvironment>(target, 'TomEnvironment').parent,
      'env': (visitor, target) => D4.validateTarget<$tom_basics_2.TomEnvironment>(target, 'TomEnvironment').env,
      'initializer': (visitor, target) => D4.validateTarget<$tom_basics_2.TomEnvironment>(target, 'TomEnvironment').initializer,
      'isTest': (visitor, target) => D4.validateTarget<$tom_basics_2.TomEnvironment>(target, 'TomEnvironment').isTest,
      'isDevelopment': (visitor, target) => D4.validateTarget<$tom_basics_2.TomEnvironment>(target, 'TomEnvironment').isDevelopment,
    },
    methods: {
      'initialize': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_2.TomEnvironment>(target, 'TomEnvironment');
        t.initialize();
        return null;
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_2.TomEnvironment>(target, 'TomEnvironment');
        return t.toString();
      },
    },
    constructorSignatures: {
      '': 'const TomEnvironment(String env, {TomEnvironment? parent, void Function(TomEnvironment)? initializer, bool isTest = false, bool isDevelopment = false})',
    },
    methodSignatures: {
      'initialize': 'void initialize()',
      'toString': 'String toString()',
    },
    getterSignatures: {
      'parent': 'TomEnvironment? get parent',
      'env': 'String get env',
      'initializer': 'void Function(TomEnvironment)? get initializer',
      'isTest': 'bool get isTest',
      'isDevelopment': 'bool get isDevelopment',
    },
  );
}

// =============================================================================
// TomPlatform Bridge
// =============================================================================

BridgedClass _createTomPlatformBridge() {
  return BridgedClass(
    nativeType: $tom_basics_2.TomPlatform,
    name: 'TomPlatform',
    isAssignable: (v) => v is $tom_basics_2.TomPlatform,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 1, 'TomPlatform');
        final name = D4.getRequiredArg<String>(positional, 0, 'name', 'TomPlatform');
        return $tom_basics_2.TomPlatform(name);
      },
    },
    getters: {
      'name': (visitor, target) => D4.validateTarget<$tom_basics_2.TomPlatform>(target, 'TomPlatform').name,
    },
    methods: {
      'setInitializer': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_2.TomPlatform>(target, 'TomPlatform');
        D4.requireMinArgs(positional, 1, 'setInitializer');
        if (positional.isEmpty) {
          throw ArgumentError('setInitializer: Missing required argument "initializer" at position 0');
        }
        final initializerRaw = positional[0];
        t.setInitializer(($tom_basics_2.TomPlatform p0, $tom_basics_2.TomEnvironment? p1) { D4.callInterpreterCallback(visitor!, initializerRaw, [p0, p1]); });
        return null;
      },
      'initializePlatform': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_2.TomPlatform>(target, 'TomPlatform');
        D4.requireMinArgs(positional, 1, 'initializePlatform');
        final env = D4.getRequiredArg<$tom_basics_2.TomEnvironment?>(positional, 0, 'env', 'initializePlatform');
        t.initializePlatform(env);
        return null;
      },
      'toString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$tom_basics_2.TomPlatform>(target, 'TomPlatform');
        return t.toString();
      },
    },
    constructorSignatures: {
      '': 'const TomPlatform(String name)',
    },
    methodSignatures: {
      'setInitializer': 'void setInitializer(void Function(TomPlatform, TomEnvironment?) initializer)',
      'initializePlatform': 'void initializePlatform(TomEnvironment? env)',
      'toString': 'String toString()',
    },
    getterSignatures: {
      'name': 'String get name',
    },
  );
}

// =============================================================================
// TomRuntime Bridge
// =============================================================================

BridgedClass _createTomRuntimeBridge() {
  return BridgedClass(
    nativeType: TomRuntime,
    name: 'TomRuntime',
    isAssignable: (v) => v is TomRuntime,
    constructors: {
      '': (visitor, positional, named) {
        return TomRuntime();
      },
    },
    staticMethods: {
      'printReport': (visitor, positional, named, typeArgs) {
        return TomRuntime.printReport();
      },
      'getEnvironments': (visitor, positional, named, typeArgs) {
        return TomRuntime.getEnvironments();
      },
      'addEnvironment': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'addEnvironment');
        final env = D4.getRequiredArg<$tom_basics_2.TomEnvironment>(positional, 0, 'env', 'addEnvironment');
        return TomRuntime.addEnvironment(env);
      },
      'setRootEnvironment': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'setRootEnvironment');
        final env = D4.getRequiredArg<$tom_basics_2.TomEnvironment>(positional, 0, 'env', 'setRootEnvironment');
        return TomRuntime.setRootEnvironment(env);
      },
      'setCurrentEnvironment': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'setCurrentEnvironment');
        final name = D4.getRequiredArg<String?>(positional, 0, 'name', 'setCurrentEnvironment');
        final fallback = D4.getOptionalArgWithDefault<String>(positional, 1, 'fallback', "defaultRoot");
        return TomRuntime.setCurrentEnvironment(name, fallback);
      },
      'getCurrentEnvironment': (visitor, positional, named, typeArgs) {
        return TomRuntime.getCurrentEnvironment();
      },
      'getEnvironmentHierarchy': (visitor, positional, named, typeArgs) {
        return TomRuntime.getEnvironmentHierarchy();
      },
      'getRoot': (visitor, positional, named, typeArgs) {
        return TomRuntime.getRoot();
      },
      'addPlatform': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'addPlatform');
        final platform = D4.getRequiredArg<$tom_basics_2.TomPlatform>(positional, 0, 'platform', 'addPlatform');
        return TomRuntime.addPlatform(platform);
      },
      'getPlatforms': (visitor, positional, named, typeArgs) {
        return TomRuntime.getPlatforms();
      },
      'getCurrentPlatform': (visitor, positional, named, typeArgs) {
        return TomRuntime.getCurrentPlatform();
      },
      'setCurrentPlatform': (visitor, positional, named, typeArgs) {
        D4.requireMinArgs(positional, 1, 'setCurrentPlatform');
        final platform = D4.getRequiredArg<$tom_basics_2.TomPlatform>(positional, 0, 'platform', 'setCurrentPlatform');
        return TomRuntime.setCurrentPlatform(platform);
      },
      'initializePlatform': (visitor, positional, named, typeArgs) {
        return TomRuntime.initializePlatform();
      },
    },
    constructorSignatures: {
      '': 'TomRuntime()',
    },
    staticMethodSignatures: {
      'printReport': 'String printReport()',
      'getEnvironments': 'List<TomEnvironment> getEnvironments()',
      'addEnvironment': 'TomEnvironment addEnvironment(TomEnvironment env)',
      'setRootEnvironment': 'void setRootEnvironment(TomEnvironment env)',
      'setCurrentEnvironment': 'void setCurrentEnvironment(String? name, [String fallback = "defaultRoot"])',
      'getCurrentEnvironment': 'TomEnvironment getCurrentEnvironment()',
      'getEnvironmentHierarchy': 'List<TomEnvironment> getEnvironmentHierarchy()',
      'getRoot': 'TomEnvironment getRoot()',
      'addPlatform': 'TomPlatform addPlatform(TomPlatform platform)',
      'getPlatforms': 'List<TomPlatform> getPlatforms()',
      'getCurrentPlatform': 'TomPlatform? getCurrentPlatform()',
      'setCurrentPlatform': 'void setCurrentPlatform(TomPlatform platform)',
      'initializePlatform': 'void initializePlatform()',
    },
  );
}

// =============================================================================
// Request Bridge
// =============================================================================

BridgedClass _createRequestBridge() {
  return BridgedClass(
    nativeType: $shelf_3.Request,
    name: 'Request',
    isAssignable: (v) => v is $shelf_3.Request,
    constructors: {
      '': (visitor, positional, named) {
        D4.requireMinArgs(positional, 2, 'Request');
        final method = D4.getRequiredArg<String>(positional, 0, 'method', 'Request');
        final requestedUri = D4.getRequiredArg<Uri>(positional, 1, 'requestedUri', 'Request');
        final protocolVersion = D4.getOptionalNamedArg<String?>(named, 'protocolVersion');
        final headers = D4.coerceMapOrNull<String, Object>(named['headers'], 'headers');
        final handlerPath = D4.getOptionalNamedArg<String?>(named, 'handlerPath');
        final url = D4.getOptionalNamedArg<Uri?>(named, 'url');
        final body = D4.getOptionalNamedArg<Object?>(named, 'body');
        final encoding = D4.getOptionalNamedArg<Encoding?>(named, 'encoding');
        final context = D4.coerceMapOrNull<String, Object>(named['context'], 'context');
        final onHijackRaw = named['onHijack'];
        return $shelf_3.Request(method, requestedUri, protocolVersion: protocolVersion, headers: headers, handlerPath: handlerPath, url: url, body: body, encoding: encoding, context: context, onHijack: onHijackRaw == null ? null : (void Function($stream_channel_1.StreamChannel<List<int>>) p0) { D4.callInterpreterCallback(visitor!, onHijackRaw, [p0]); });
      },
    },
    getters: {
      'url': (visitor, target) => D4.validateTarget<$shelf_3.Request>(target, 'Request').url,
      'method': (visitor, target) => D4.validateTarget<$shelf_3.Request>(target, 'Request').method,
      'handlerPath': (visitor, target) => D4.validateTarget<$shelf_3.Request>(target, 'Request').handlerPath,
      'protocolVersion': (visitor, target) => D4.validateTarget<$shelf_3.Request>(target, 'Request').protocolVersion,
      'requestedUri': (visitor, target) => D4.validateTarget<$shelf_3.Request>(target, 'Request').requestedUri,
      'canHijack': (visitor, target) => D4.validateTarget<$shelf_3.Request>(target, 'Request').canHijack,
      'ifModifiedSince': (visitor, target) => D4.validateTarget<$shelf_3.Request>(target, 'Request').ifModifiedSince,
      'headers': (visitor, target) => D4.validateTarget<$shelf_3.Request>(target, 'Request').headers,
      'headersAll': (visitor, target) => D4.validateTarget<$shelf_3.Request>(target, 'Request').headersAll,
      'context': (visitor, target) => D4.validateTarget<$shelf_3.Request>(target, 'Request').context,
      'isEmpty': (visitor, target) => D4.validateTarget<$shelf_3.Request>(target, 'Request').isEmpty,
      'contentLength': (visitor, target) => D4.validateTarget<$shelf_3.Request>(target, 'Request').contentLength,
      'mimeType': (visitor, target) => D4.validateTarget<$shelf_3.Request>(target, 'Request').mimeType,
      'encoding': (visitor, target) => D4.validateTarget<$shelf_3.Request>(target, 'Request').encoding,
    },
    methods: {
      'change': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$shelf_3.Request>(target, 'Request');
        final headers = D4.coerceMapOrNull<String, Object?>(named['headers'], 'headers');
        final context = D4.coerceMapOrNull<String, Object?>(named['context'], 'context');
        final path = D4.getOptionalNamedArg<String?>(named, 'path');
        final body = D4.getOptionalNamedArg<Object?>(named, 'body');
        return t.change(headers: headers, context: context, path: path, body: body);
      },
      'hijack': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$shelf_3.Request>(target, 'Request');
        D4.requireMinArgs(positional, 1, 'hijack');
        if (positional.isEmpty) {
          throw ArgumentError('hijack: Missing required argument "callback" at position 0');
        }
        final callbackRaw = positional[0];
        return t.hijack(($stream_channel_1.StreamChannel<List<int>> p0) { D4.callInterpreterCallback(visitor!, callbackRaw, [p0]); });
      },
      'read': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$shelf_3.Request>(target, 'Request');
        return t.read();
      },
      'readAsString': (visitor, target, positional, named, typeArgs) {
        final t = D4.validateTarget<$shelf_3.Request>(target, 'Request');
        final encoding = D4.getOptionalArg<Encoding?>(positional, 0, 'encoding');
        return t.readAsString(encoding);
      },
    },
    constructorSignatures: {
      '': 'Request(String method, Uri requestedUri, {String? protocolVersion, Map<String, Object>? headers, String? handlerPath, Uri? url, Object? body, Encoding? encoding, Map<String, Object>? context, void Function(void Function(StreamChannel<List<int>>))? onHijack})',
    },
    methodSignatures: {
      'change': 'Request change({Map<String, Object?>? headers, Map<String, Object?>? context, String? path, Object? body})',
      'hijack': 'Never hijack(void Function(StreamChannel<List<int>>) callback)',
      'read': 'Stream<List<int>> read()',
      'readAsString': 'Future<String> readAsString([Encoding? encoding])',
    },
    getterSignatures: {
      'url': 'Uri get url',
      'method': 'String get method',
      'handlerPath': 'String get handlerPath',
      'protocolVersion': 'String get protocolVersion',
      'requestedUri': 'Uri get requestedUri',
      'canHijack': 'bool get canHijack',
      'ifModifiedSince': 'DateTime? get ifModifiedSince',
      'headers': 'Map<String, String> get headers',
      'headersAll': 'Map<String, List<String>> get headersAll',
      'context': 'Map<String, Object> get context',
      'isEmpty': 'bool get isEmpty',
      'contentLength': 'int? get contentLength',
      'mimeType': 'String? get mimeType',
      'encoding': 'Encoding? get encoding',
    },
  );
}

