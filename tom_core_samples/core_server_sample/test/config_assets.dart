/// Shared test helper: reading the sample's configuration assets the way the
/// server reads them.
///
/// Two suites assert against `app.title` — the database-free
/// `todo_health_config_test.dart` and the live
/// `todo_endpoints_integration_test.dart` — and they have to agree with each
/// other *and* with the boot about what the assets say. One loader used by both
/// makes that true by construction instead of by review; two copies would be
/// free to drift in exactly the way the tests exist to catch.
///
/// Loaded through [TomYaml], which is the loader `bin/server_start.dart` calls,
/// so a test can never read an asset by a route the server does not use.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// The base configuration asset; declares `app.title`.
const defaultConfigAsset = 'assets/config-resources_default.yaml';

/// The `env=dev` overlay; re-declares `app.title` and nothing else about `app`.
const devConfigAsset = 'assets/config-resources_dev.yaml';

/// The `app.title` declared by [asset].
///
/// Read rather than duplicated: an assertion about what the wire serves is only
/// a configuration proof if its expectation comes from the configuration.
String assetAppTitle(String asset) {
  final app = _load(asset)['app'];
  expect(
    app,
    isA<Map<String, Object?>>(),
    reason: '$asset must declare an `app` section',
  );
  return (app! as Map<String, Object?>)['title']! as String;
}

/// Loads and merges [assets] the way `bin/server_start.dart` merges the base
/// asset and the active environment overlay.
///
/// Uses [TomYaml.mergeInYamlFile] rather than a `Map.addAll`, because the two
/// are not the same merge: `addAll` replaces a whole branch, the real one
/// overwrites per leaf. They happen to agree on today's assets — `app` has a
/// single key — and would part company the moment the overlay stated one key of
/// a branch that had two. A test that merged differently from the boot would be
/// asserting about a configuration the server never assembles.
Map<String, dynamic> mergedConfigAssets(List<String> assets) {
  final result = <String, dynamic>{};
  for (final asset in assets) {
    _requirePackageRoot(asset);
    TomYaml.mergeInYamlFile(result, asset);
  }
  return result;
}

/// Loads [asset] after checking the working directory is the package root.
Map<String, Object?> _load(String asset) {
  _requirePackageRoot(asset);
  return TomYaml.loadYamlFile(asset);
}

/// Fails naming the cause rather than the symptom: a relative asset path that
/// does not resolve almost always means the suite was run from somewhere other
/// than the package root, which `PathNotFoundException` does not say.
void _requirePackageRoot(String asset) {
  expect(
    File(asset).existsSync(),
    isTrue,
    reason: 'tests must run from the package root',
  );
}
