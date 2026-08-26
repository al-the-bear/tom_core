/// Executable example for the configuration module of `tom_core_flutter`.
///
/// Demonstrates the full life of a machine-scoped client configuration: declare
/// settings, resolve them against the shipped config resources, adopt this
/// install's persisted overrides, observe changes per field and as a whole, and
/// persist only what the install actually changed.
///
/// A deterministic in-memory config provider is installed so the example is
/// self-contained. Both shipped stores are exercised: the in-memory one for the
/// bulk of the walk-through, and `TomFileClientConfigurationStore` over a
/// temporary directory for the persistence step. A real client differs only in
/// the *path* — it takes one from `path_provider`
/// (`getApplicationSupportDirectory()`), which this package does not depend on.
///
/// The barrel import pulls in `flutter/material` (and thus `dart:ui`), so run
/// this under the Flutter toolchain, e.g.
/// `flutter test example/configuration/configuration_example.dart`, not bare
/// `dart run`. `test/configuration_test.dart` covers the same behaviour and
/// also runs [run], so the code below is checked rather than merely shown.
library;

import 'dart:io';

import 'package:tom_core_flutter/tom_core_flutter.dart';

/// A client app's machine-scoped configuration.
///
/// Settings are declared in [declareSettings], which the base constructor calls
/// — Dart field initialisers cannot call instance methods, and declaring in one
/// place keeps the set complete by the end of construction.
class AppConfiguration extends TomBaseClientConfiguration {
  AppConfiguration({super.store});

  late final TomSetting<String> serverUrl;
  late final TomSetting<int> refreshSeconds;
  late final TomSetting<bool> darkMode;

  @override
  void declareSettings() {
    serverUrl = stringSetting('client.server.url', 'https://api.example.com');
    refreshSeconds = intSetting('client.refresh.seconds', 60);
    darkMode = boolSetting('client.ui.darkMode', false);
  }
}

Future<void> run() async {
  // The values shipped with the app. `client.refresh.seconds` is set here, so
  // it wins over the default written at the declaration site; the other two
  // keys are absent, so their declared defaults apply.
  TomConfigResourceProvider.setAppConfigProvider(
    TomConfigResourceProvider.from({'client.refresh.seconds': 30}),
  );

  // What this install saved last time it ran. An in-memory store keeps
  // Examples 1-7 deterministic and free of I/O; Example 8 then repeats the
  // persistence step over a real file, which is what a shipped client uses.
  final store = TomMemoryClientConfigurationStore({'client.ui.darkMode': true});

  final config = AppConfiguration(store: store);

  // Example 1: resolution before any load — shipped value, then declared
  // default.
  print('shipped refreshSeconds=${~config.refreshSeconds}'); // 30, not 60
  print('declared serverUrl=${~config.serverUrl}');
  assert(~config.refreshSeconds == 30);
  assert(config.refreshSeconds.declaredDefault == 60);

  // Example 2: observation, both granularities at once. Retain the observers —
  // they are held by weak reference, so a discarded one silently stops firing.
  var darkModeChanges = 0;
  var anyChanges = 0;
  final fieldObserver = config.darkMode >> (_) => darkModeChanges++;
  final holderObserver = config >> (_) => anyChanges++;

  // Example 3: adopt this install's overrides. One holder notification for the
  // whole load, however many settings it touches.
  await config.load();
  print('after load darkMode=${~config.darkMode}'); // true, from the store
  assert(~config.darkMode == true);
  assert(config.isOverridden('client.ui.darkMode'));
  assert(anyChanges == 1);
  assert(darkModeChanges == 1);

  // Example 4: the install changes a setting, then saves. Only the overrides
  // are written — a setting still sitting on its baseline is re-resolved from
  // the shipped resources at every start, so a future app update can still
  // change it.
  config.serverUrl | 'https://eu.example.com';
  await config.save();
  final persisted = await store.read();
  print('persisted=$persisted');
  assert(persisted.length == 2);
  assert(persisted.containsKey('client.ui.darkMode'));
  assert(persisted.containsKey('client.server.url'));
  assert(!persisted.containsKey('client.refresh.seconds'));

  // Example 5: resetting drops the override; saving then removes the key.
  config.reset('client.ui.darkMode');
  await config.save();
  print('after reset persisted=${await store.read()}');
  assert(!(await store.read()).containsKey('client.ui.darkMode'));
  assert(~config.darkMode == false); // back to the baseline

  // Example 6: keys the running build does not declare are carried forward, so
  // a build that has dropped a setting cannot destroy an install's value for it.
  // The carry-forward is seeded by re-reading the store at save time, not from
  // what load() saw — so a key another writer added in between survives too.
  await store.write({
    ...await store.read(),
    'client.legacy.key': 'written-by-someone-else',
  });
  config.refreshSeconds | 15;
  await config.save();
  final carried = await store.read();
  print('carried=$carried');
  assert(carried['client.legacy.key'] == 'written-by-someone-else');
  assert(carried['client.refresh.seconds'] == 15);

  // Example 7: pointing the holder at a different store discards the snapshot
  // of the old one but keeps the settings — a swap is not a load. So the first
  // store's foreign keys are not deposited into the second, and the second's
  // own are left alone. Call load() to adopt the new store's overrides.
  final otherStore = TomMemoryClientConfigurationStore({'client.other': 'kept'});
  config.store = otherStore;
  await config.save();
  final swapped = await otherStore.read();
  print('other store=$swapped');
  assert(!swapped.containsKey('client.legacy.key')); // not carried across
  assert(swapped['client.other'] == 'kept'); // its own key survives
  assert(swapped['client.refresh.seconds'] == 15); // this holder's override

  print('field notifications=$darkModeChanges holder notifications=$anyChanges');

  config.darkMode.removeObserver(fieldObserver);
  config.removeObserver(holderObserver);

  // Example 8: the same holder over a real file — the store a shipped client
  // actually uses. Only the path differs: a real client passes
  // `'${(await getApplicationSupportDirectory()).path}/client_config.json'`
  // from `path_provider`. That package is not a dependency here (a doc snippet
  // is not a reason to take one on), so a temporary directory stands in, and
  // the `path_provider` call is the single line of this example that is not
  // itself executed.
  final directory = Directory.systemTemp.createTempSync('tom_client_config_');
  try {
    final path = '${directory.path}/client_config.json';

    final fileConfig = AppConfiguration(
      store: TomFileClientConfigurationStore(path),
    );
    // Nothing persisted yet, so every setting resolves to its baseline. An
    // absent file reads as empty rather than failing — a first run is normal.
    await fileConfig.load();
    assert(!fileConfig.hasOverrides);

    fileConfig.darkMode | true;
    await fileConfig.save();
    print('on disk=${File(path).readAsStringSync()}');

    // A fresh holder over the same path adopts what the first one wrote. That
    // round trip across two holders is the whole point of persisting, and it
    // is what an in-memory store cannot demonstrate.
    final reopened = AppConfiguration(
      store: TomFileClientConfigurationStore(path),
    );
    await reopened.load();
    print('reopened darkMode=${~reopened.darkMode}');
    assert(~reopened.darkMode == true);
    assert(reopened.isOverridden('client.ui.darkMode'));

    // Only the override was written, so the shipped value is still re-resolved
    // from the config resources rather than frozen into the file.
    assert(~reopened.refreshSeconds == 30);
    assert(!reopened.isOverridden('client.refresh.seconds'));
  } finally {
    directory.deleteSync(recursive: true);
  }
}

Future<void> main() => run();
