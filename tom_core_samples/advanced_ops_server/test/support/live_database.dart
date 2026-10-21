/// The live `app_db` the ops server's live suites run against: brought up the
/// way `bin/ops_server_start.dart` brings it up, and a uniform way to skip when
/// it is not there.
///
/// Shared by `ops_live_test.dart` and `ops_privacy_live_test.dart`, which both
/// skip rather than fail when `app_db` is unreachable — so `testkit :test` on a
/// laptop with no docker stays green — and both of which
/// `tool/run_ops_integration.sh` runs with the database up, treating a skip as
/// a failure.
///
/// The skip is per test via [markTestSkipped], not a `skip:` argument on a
/// group: a `skip:` expression is evaluated while `main()` builds the tree —
/// before any `setUpAll` has run — so it could only ever read the *initial*
/// value of [liveDatabaseAvailable] and would skip unconditionally.
library;

import 'package:advanced_app_server/advanced_app_server.dart';
import 'package:advanced_ops_server/advanced_ops_server.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import '../../bin/ops_server_start.dart'
    show
        blobStoreLoaderFunction,
        datasourceLoaderFunction,
        initializeRuntime,
        initializeServerResources;
import '../../bin/ops_server_start.reflection.dart' show initializeReflection;

/// The uniform skip message when the live database is unreachable.
const String liveSkipMessage =
    'app_db unreachable — start it with `docker compose up -d app-db` in '
    'advanced_app_server, or run tool/run_ops_integration.sh';

/// Whether `app_db` answered. Set once by [bootstrapLiveDatabase].
bool _available = false;

/// Whether `app_db` answered [bootstrapLiveDatabase].
bool get liveDatabaseAvailable => _available;

/// Marks the running test skipped when `app_db` did not answer.
///
/// Returns `true` when the caller should return without asserting.
bool liveDatabaseUnavailable() {
  if (_available) return false;
  markTestSkipped(liveSkipMessage);
  return true;
}

/// Brings up the same picture of `app_db` the live server has.
///
/// Deliberately the boot sequence of `bin/ops_server_start.dart`, in its order,
/// and not a shortcut. Two things depend on that order: the config-resource
/// provider must exist before the datasource YAML's `${VAR:default}` terms can
/// resolve, and `registerAppDataScopes` constructs repositories — which requires
/// the datasource *info* to already be registered, `main` delegation included.
/// Getting it wrong fails loudly here rather than subtly later, which is why the
/// loaders are imported from the boot instead of copied.
Future<void> bootstrapLiveDatabase() async {
  TomPlatformUtils.setCurrentPlatform(standalonePlatformUtils);
  initializeReflection();
  registerProjectRoleVocabulary();
  // `env=dev` rather than an empty argument list: the boot resolves the runtime
  // environment from the command line first, and a test that runs from a
  // directory without a `.env` would otherwise fall back to `prod`.
  initializeRuntime(['env=dev']);
  initializeServerResources();
  try {
    await TomDataSourceInfo.initializeDatasourceInfo(
      datasourceLoaderFunction(),
    );
    await TomBlobStoreInfo.initializeBlobStores(blobStoreLoaderFunction());
    registerAppDataScopes();
    registerAppColumnGrades();
    registerOpsPersonalData();
    // A query that answers is the only proof worth having; a reachable host with
    // an unmigrated schema would fail later and less clearly.
    await TomDataScope.runUnscoped(
      () => itemRepository.countByQuerySentence('COUNT BY id > :zero', {
        'zero': 0,
      }),
    );
    _available = true;
  } on Object {
    // Any failure — refused connection, missing table, bad credentials — means
    // the same thing for this suite: there is no live database to assert
    // against. The runner turns the resulting skip into a failure.
    _available = false;
  }
}
