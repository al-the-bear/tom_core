/// Database-free unit tests for the one *configured* value `/health` reports:
/// the application title.
///
/// `app.title` is declared in the base configuration asset and overridden by
/// the `env=dev` overlay (see `config_assets.dart`), so the title the endpoint
/// serves is a fact about the resolved configuration, not about the source. A
/// literal in the endpoint would make the two silently disagree — the server
/// would report the production name while running the dev overlay — which is
/// what these tests exist to prevent (guideline G-RES-1: a configured resource
/// is read through the provider, never restated as a string).
///
/// The wire half of the same claim is asserted live by
/// `todo_endpoints_integration_test.dart`, whose runner boots with `env=dev`:
/// these tests prove `health()` reads the provider, that one proves the overlay
/// survives the whole boot and reaches an HTTP client.
library;

import 'package:core_server_sample/core_server_sample.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'config_assets.dart';

void main() {
  group('health() reports the configured application title', () {
    test('reads app.title from the active config-resource provider', () async {
      // A title that appears in no asset and no source file, so the only way it
      // can reach the response is the provider. This is the assertion the
      // hardcoded literal fails.
      _install(<String, dynamic>{
        'app': <String, dynamic>{'title': 'Some Other Product'},
      });

      final body = await TodoApiServer().health();
      expect(body['app'], equals('Some Other Product'));
      expect(body['status'], equals('ok'));
    });

    test('serves the base asset title when no overlay is merged', () async {
      // Deliberately reads the expected value out of the same file it installs.
      // That is not circular for the thing being checked: it pins the *key*
      // (`app.title`) and the asset's shape, so renaming the key in the YAML
      // without renaming it in `health()` fails here instead of silently
      // falling back.
      _install(mergedConfigAssets([defaultConfigAsset]));

      expect(await _healthTitle(), equals(assetAppTitle(defaultConfigAsset)));
    });

    test('serves the dev overlay title once the dev overlay is merged', () async {
      // The overlay proof, stated as a difference rather than a value: the two
      // assets must disagree, and health() must follow the overlay. This is the
      // assertion the hardcoded literal failed, and the reason the one above
      // could not catch it — the literal was a copy of the *default*, so it
      // agreed with the base asset and only ever diverged under an overlay.
      final devTitle = assetAppTitle(devConfigAsset);
      expect(
        devTitle,
        isNot(equals(assetAppTitle(defaultConfigAsset))),
        reason:
            '$devConfigAsset must override app.title for this to prove '
            'anything',
      );

      _install(mergedConfigAssets([defaultConfigAsset, devConfigAsset]));

      expect(await _healthTitle(), equals(devTitle));
    });
  });
}

/// The `app` entry of a fresh [TodoApiServer]'s health response.
Future<Object?> _healthTitle() async => (await TodoApiServer().health())['app'];

/// Installs [resources] as the process-wide configuration source.
void _install(Map<String, dynamic> resources) {
  TomServerConfigResourceProvider.setServerConfigProvider(
    TomServerConfigResourceProvider.from(resources),
  );
}
