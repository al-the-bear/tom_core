/// Tom Core Kernel — the platform-neutral foundation of the Tom stack.
///
/// Eighteen modules that assume no server, no Flutter and no database:
/// dependency lookup, the execution context and its zone values, observables,
/// the security model — principals, grants and the access-control meet —
/// resources, settings and preferences, scheduling, metrics, reflection,
/// logging, JSON, timezone-aware instants and shutdown coordination. `tom_core_server` and
/// `tom_flutter_ui` are built on it and neither is needed to use it.
///
/// Everything is exported from this one library — including the `tom_basics`
/// and `tom_crypto` surfaces it re-exports — so a single import reaches all of
/// it:
///
/// ```dart
/// import 'package:tom_core_kernel/tom_core_kernel.dart';
/// ```
///
/// Each module has a guide under `doc/` and runnable samples under
/// `example/samples/`; `example/run_all_samples.dart` runs them all.
library;

export 'package:tom_basics/tom_basics.dart';
export 'package:tom_crypto/tom_crypto.dart';
export 'src/tombase/beanlocator/bean_locator.dart';
export 'src/tombase/context/execution_context.dart';
export 'src/tombase/context/tenant_context.dart';
export 'src/tombase/context/trace_context.dart';
export 'src/tombase/http_connection/server_connection.dart';
export 'src/tombase/http_connection/auth_retry.dart';
export 'src/tombase/http_connection/endpoints_apis.dart';
export 'src/tombase/http_connection/file_transfer.dart';
export 'src/tombase/http_connection/http_file_transfer.dart';
export 'src/tombase/http_connection/remote_context.dart';
export 'src/tombase/http_connection/resilience.dart';
export 'src/tombase/http_connection/httpmethods.dart';
export 'src/tombase/http_connection/mimetypes.dart';
export 'src/tombase/http_connection/headers.dart';
export 'src/tombase/isolate_pooling/tom_worker.dart';
export 'src/tombase/json/json_serializable.dart';
export 'src/tombase/json/map_merge_and_process.dart';
export 'src/tombase/json/pretty_json.dart';
export 'src/tombase/little_things/little_things.dart';
export 'src/tombase/little_things/exception_base.dart';
export 'src/tombase/little_things/formatting.dart';
export 'src/tombase/logging/json_logoutput.dart';
export 'src/tombase/logging/logging_isolate.dart';
export 'src/tombase/logging/remote_logoutput.dart';
export 'src/tombase/logging/file_log_replay_store.dart';
export 'src/tombase/logging/remote_logserver.dart';
export 'src/tombase/metrics/metrics.dart';
export 'src/tombase/metrics/prometheus_text.dart';
export 'src/tombase/preferences/user_preference_codec.dart';
export 'src/tombase/preferences/user_preference_keys.dart';
export 'src/tombase/preferences/user_preferences_contract.dart';
export 'src/tombase/resources/tom_resource_provider.dart';
export 'src/tombase/scheduling/job_definition.dart';
export 'src/tombase/scheduling/job_store.dart';
export 'src/tombase/scheduling/lease_lock.dart';
export 'src/tombase/scheduling/schedule.dart';
export 'src/tombase/scheduling/scheduled_job.dart';
export 'src/tombase/scheduling/scheduler.dart';
export 'src/tombase/scope_ids/scope_ids.dart';
export 'src/tombase/security/access_controls.dart';
export 'src/tombase/security/authentication_authorization.dart';
export 'src/tombase/security/bearer_authentication.dart';
export 'src/tombase/security/oauth_contract.dart';
export 'src/tombase/security/item_permissions.dart';
export 'src/tombase/security/resource_role_authorization.dart';
export 'src/tombase/security/server_principal.dart';
export 'src/tombase/security/tom_authorization.dart';
export 'src/tombase/security/two_factor.dart';
export 'src/tombase/security/webauthn.dart';
export 'src/tombase/security/user_principal_aci.dart';
export 'src/tombase/settings/settings_client_authorization.dart';
export 'src/tombase/shutdown_cleanup/tom_shutdown_cleanup.dart';
export 'src/tombase/observable/tom_observable_objects.dart';
export 'src/tombase/observable/tom_observable.dart';
export 'src/tombase/observable/tom_observable_enum.dart';
export 'src/tombase/reflection/reflection.dart';
export 'src/tombase/timezoned/date_timestamp.dart';
export 'src/tombase/timezoned/timezones.dart';
export 'package:tom_reflection/tom_reflection.dart';
export 'package:tom_reflection/generated.dart';
