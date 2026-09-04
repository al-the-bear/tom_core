/// The boot's asset preconditions: which configuration files the server
/// refuses to start without, and which one it is allowed to start without.
///
/// `bin/ops_server_start.dart` resolves every asset by a path relative to the
/// process working directory, so the directory the server is launched from is
/// load-bearing. That is a normal thing for a sample to do — the alternative,
/// resolving against the script location, hides the fact that a deployed server
/// has to be given its configuration somehow. What is *not* acceptable is
/// failing quietly when the directory is wrong: a boot that finds no
/// configuration, no datasource and no blob store, and starts anyway, reports
/// its first symptom several layers later as a connection or a missing-key
/// error that says nothing about the real cause.
///
/// That matters more here than in the two HTTP servers. `advanced_ops_server`
/// binds no port, so a misconfigured process has no failing request to make the
/// problem visible: it would sit in its scheduler loop and do nothing, which
/// from the outside is indistinguishable from a quiet week.
///
/// So the boot draws a line this suite pins: the base configuration, the
/// datasource asset and the blob-store asset are **required** and their absence
/// throws, naming the absolute path that was tried and the directory it was
/// resolved against; the per-environment overlay is **optional** and its
/// absence is silent. The distinction is not a preference — the overlay for the
/// root environment genuinely does not exist in this package, and one of the
/// tests below reads that off disk rather than asserting it from memory.
///
/// The blob-store asset is the one this server has that `core_server_sample`
/// does not, and it is required for a reason worth stating: the boot calls
/// `TomBlobStoreInfo.initializeBlobStores(blobStoreLoaderFunction())`
/// unconditionally, so an empty map is not "no file storage configured" but a
/// store registry with nothing in it, which fails only when the weekly export
/// first tries to write.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import '../bin/ops_server_start.dart'
    show
        blobStoreLoaderFunction,
        blobStoresAsset,
        configResourcesAsset,
        datasourceLoaderFunction,
        datasourcesAsset,
        environmentProd,
        mergeOptionalYaml,
        mergeRequiredYaml;

/// A relative path that resolves to nothing, in the directory the assets live
/// in — so a failure is about the *file*, not about an unreadable folder.
const String _absentAsset = 'assets/config-resources_no-such-environment.yaml';

/// The `env=dev` overlay; re-declares `app.title` and nothing else about `app`.
const String _devConfigAsset = 'assets/config-resources_dev.yaml';

/// The `app.title` declared by [asset].
///
/// Read rather than duplicated: an assertion about what the boot loaded is only
/// a configuration proof if its expectation comes from the configuration. Read
/// through [TomYaml], which is the loader the boot itself calls, so a test can
/// never read an asset by a route the server does not use.
String _appTitle(String asset) {
  final app = TomYaml.loadYamlFile(asset)['app'];
  expect(
    app,
    isA<Map<String, Object?>>(),
    reason: '$asset must declare an `app` section',
  );
  return (app! as Map<String, Object?>)['title']! as String;
}

void main() {
  group('the assets the boot cannot start without', () {
    test('all three required assets exist at the package root', () {
      // Guards the three constants themselves. Every other test here would
      // still pass if a constant were misspelled — `mergeRequiredYaml` would
      // throw as designed, for the wrong reason.
      for (final asset in [
        configResourcesAsset,
        datasourcesAsset,
        blobStoresAsset,
      ]) {
        expect(
          File(asset).existsSync(),
          isTrue,
          reason: '$asset is required by the boot and must ship with it',
        );
      }
    });

    test('a missing one throws instead of being skipped', () {
      expect(
        () => mergeRequiredYaml(<String, dynamic>{}, _absentAsset),
        throwsA(isA<StateError>()),
      );
    });

    test('the failure names the absolute path that was tried', () {
      // The point of the message. A relative path in the error repeats what the
      // reader already knows; the absolute one is what tells them the working
      // directory is wrong, because they can see where it landed.
      expect(
        () => mergeRequiredYaml(<String, dynamic>{}, _absentAsset),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains(File(_absentAsset).absolute.path),
          ),
        ),
      );
    });

    test('the failure names the directory the path was resolved against', () {
      expect(
        () => mergeRequiredYaml(<String, dynamic>{}, _absentAsset),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains(Directory.current.path),
          ),
        ),
      );
    });

    test('a present one is merged', () {
      final loaded = <String, dynamic>{};
      mergeRequiredYaml(loaded, configResourcesAsset);

      // Read out of the asset rather than restated, so this cannot pass against
      // a loader that returned some other file's contents.
      expect(
        (loaded['app'] as Map<String, Object?>?)?['title'],
        equals(_appTitle(configResourcesAsset)),
      );
    });
  });

  group('the environment overlay, which is allowed to be absent', () {
    test('the root environment has no overlay asset', () {
      // This is *why* the overlay is loaded optionally, and it is the one fact
      // that would silently invalidate the distinction if it changed: the
      // hierarchy loop asks for an overlay per environment, and `prod` — the
      // root every hierarchy contains — has none. Add `config-resources_prod.
      // yaml` and this test says so.
      expect(
        File(
          'assets/config-resources_${environmentProd.env}.yaml',
        ).existsSync(),
        isFalse,
        reason:
            'the boot loads overlays optionally because this one does not exist',
      );
    });

    test(
      'a missing overlay leaves the accumulated configuration untouched',
      () {
        final loaded = <String, dynamic>{};
        mergeRequiredYaml(loaded, configResourcesAsset);
        final beforeOverlay = Map<String, dynamic>.from(loaded);

        mergeOptionalYaml(loaded, _absentAsset);

        expect(loaded, equals(beforeOverlay));
      },
    );

    test('a present overlay wins over the base', () {
      final loaded = <String, dynamic>{};
      mergeRequiredYaml(loaded, configResourcesAsset);
      mergeOptionalYaml(loaded, _devConfigAsset);

      expect(
        (loaded['app'] as Map<String, Object?>?)?['title'],
        equals(_appTitle(_devConfigAsset)),
      );
    });
  });

  group('the loaders the boot actually calls', () {
    test('datasourceLoaderFunction reads both databases', () {
      // Ties the required-asset rule to a real boot step: this is the loader
      // handed to `TomDataSourceInfo.initializeDatasourceInfo`, and each key
      // must equal the migration folder name under database_migrations/ for
      // migrations to resolve. The ops server is the one artifact that reads
      // *both* databases — `app_db` for the work it does, `auth_db` read-only
      // for the recipients the digest resolves through `userRepository` — so a
      // datasource asset carrying only one of them is a boot that half works.
      final datasources = datasourceLoaderFunction();
      expect(datasources, contains('app_db'));
      expect(datasources, contains('auth_db'));
    });

    test('blobStoreLoaderFunction reads the blob-store asset', () {
      // The loader handed to `TomBlobStoreInfo.initializeBlobStores`. `files`
      // is the store the weekly export resolves to by being the only one.
      expect(blobStoreLoaderFunction(), contains('files'));
    });
  });
}
