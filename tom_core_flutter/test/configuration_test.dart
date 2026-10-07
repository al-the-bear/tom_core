import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

// The neutral file store is selected by conditional *export*, so on this target
// the barrel name resolves to the io variant. Importing the neutral source
// directly is what makes its documented web behaviour testable here at all;
// the prefix keeps the two same-named classes apart.
import 'package:tom_core_flutter/src/tomclient/configuration/file_configuration_store_neutral.dart'
    as neutral;

import '../example/configuration/configuration_example.dart' as example;
import 'support/conditional_export_variants.dart';

/// A store that lets a test run somebody else's whole save *inside* one
/// holder's `read()`.
///
/// `save()` is read-then-write, and the two are separate awaits — but from a
/// test's side the pair is atomic unless the store can be interrupted between
/// them. This one can: [onNextRead] fires after the snapshot is taken and
/// before it is returned, so the second holder's save completes while the first
/// is still holding a snapshot that predates it. That is the interleaving the
/// module documents as undetected, reproduced deterministically rather than by
/// racing two futures and hoping.
class _InterleavingStore extends TomClientConfigurationStore {
  _InterleavingStore([Map<String, Object?>? initialValues])
    : _values = {...?initialValues};

  Map<String, Object?> _values;

  /// Run once, inside the next [read], after its snapshot is taken.
  Future<void> Function()? onNextRead;

  @override
  Future<Map<String, Object?>> read() async {
    final snapshot = {..._values};
    final hook = onNextRead;
    onNextRead = null;
    if (hook != null) await hook();
    return snapshot;
  }

  @override
  Future<void> write(Map<String, Object?> values) async {
    _values = {...values};
  }
}

/// A holder with one setting of each supported type.
class _TestConfiguration extends TomBaseClientConfiguration {
  _TestConfiguration({super.store});

  late final TomSetting<String> serverUrl;
  late final TomSetting<int> retries;
  late final TomSetting<double> ratio;
  late final TomSetting<bool> darkMode;

  @override
  void declareSettings() {
    serverUrl = stringSetting('client.server.url', 'https://default.example');
    retries = intSetting('client.retries', 3);
    ratio = doubleSetting('client.ratio', 1.0);
    darkMode = boolSetting('client.darkMode', false);
  }
}

/// A holder whose two settings name environment variables.
///
/// Separate from [_TestConfiguration] on purpose: an `envAlias` changes what
/// `load`, `save` and `reset` do to a setting, so putting one in the shared
/// fixture would quietly change the subject of every test that counts the
/// document `save` writes.
class _EnvConfiguration extends TomBaseClientConfiguration {
  _EnvConfiguration({super.store});

  late final TomSetting<String> endpoint;
  late final TomSetting<int> retries;

  @override
  void declareSettings() {
    endpoint = stringSetting(
      'client.endpoint',
      'https://default.example',
      envAlias: 'APP_ENDPOINT',
    );
    retries = intSetting('client.retries', 3, envAlias: 'APP_RETRIES');
  }
}

/// A holder with a single `String` setting and no other type.
///
/// The echo a missing key can produce is a `String`, so `String` is the one
/// declared type that swallows it silently — an `int` or a `bool` setting
/// throws a type mismatch instead, and throws *first* when several settings are
/// declared together. A fixture that mixes types therefore fails the wrong way:
/// it reports a mismatch on some other key and never reaches the assertion
/// about the value of this one.
class _StringOnlyConfiguration extends TomBaseClientConfiguration {
  late final TomSetting<String> serverUrl;

  @override
  void declareSettings() {
    serverUrl = stringSetting('client.server.url', 'https://default.example');
  }
}

/// A holder that declares nothing up front, so a test can declare a setting
/// *after* [TomBaseClientConfiguration.load] has run.
class _LateConfiguration extends TomBaseClientConfiguration {
  _LateConfiguration({super.store});

  @override
  void declareSettings() {}

  TomSetting<int> declareRetries() => intSetting('client.retries', 3);
}

/// A holder that declares the same key twice.
class _DuplicateConfiguration extends TomBaseClientConfiguration {
  @override
  void declareSettings() {
    stringSetting('client.dup', 'a');
    stringSetting('client.dup', 'b');
  }
}

/// A holder declaring one setting per shadowing arm.
class _ShadowedConfiguration extends TomBaseClientConfiguration {
  late final TomSetting<String> pinned;
  late final TomSetting<String> byUser;
  late final TomSetting<String> byDevice;
  late final TomSetting<int> retries;

  @override
  void declareSettings() {
    pinned = stringSetting('client.pinned', 'install');
    byUser = stringSetting(
      'client.byUser',
      'install',
      overridableBy: TomOverridableBy.user,
    );
    byDevice = stringSetting(
      'client.byDevice',
      'install',
      overridableBy: TomOverridableBy.device,
    );
    retries = intSetting(
      'client.retries',
      3,
      overridableBy: TomOverridableBy.device,
    );
  }
}

/// A holder whose environment-bound setting also opens itself to a device
/// preference — the two layers the module treats as independent.
class _EnvShadowedConfiguration extends TomBaseClientConfiguration {
  late final TomSetting<String> endpoint;

  @override
  void declareSettings() {
    endpoint = stringSetting(
      'client.endpoint',
      'https://default.example',
      envAlias: 'APP_ENDPOINT',
      overridableBy: TomOverridableBy.device,
    );
  }
}

/// A preference lookup that answers from a map and records what it was asked.
///
/// Recording is the point: half of what [TomEffectiveSettings] promises is
/// which stores it does **not** consult, and a value-only fake cannot show
/// that.
class _RecordingPreferences {
  _RecordingPreferences([Map<String, Object>? values]) : values = {...?values};

  final Map<String, Object> values;
  final List<String> reads = [];

  Future<T?> get<T extends Object>(String key) async {
    reads.add(key);
    return values[key] as T?;
  }
}

/// A holder that opens a key the preference vocabulary rejects.
class _IllegalShadowKeyConfiguration extends TomBaseClientConfiguration {
  @override
  void declareSettings() {
    stringSetting(
      'client/byUser',
      'install',
      overridableBy: TomOverridableBy.user,
    );
  }
}

/// The same key, pinned — where the vocabulary has no say.
class _PinnedOddKeyConfiguration extends TomBaseClientConfiguration {
  late final TomSetting<String> odd;

  @override
  void declareSettings() {
    odd = stringSetting('client/byUser', 'install');
  }
}

Matcher throwsConfigException(String key) => throwsA(
  isA<TomClientConfigurationException>().having((e) => e.key, 'key', key),
);

void main() {
  void installConfig(Map<String, Object> values) {
    TomConfigResourceProvider.setAppConfigProvider(
      TomConfigResourceProvider.from(values),
    );
  }

  setUp(() => installConfig({}));

  group('baseline resolution', () {
    test('falls back to the declared default when the key is absent', () {
      final config = _TestConfiguration();
      expect(~config.serverUrl, 'https://default.example');
      expect(~config.retries, 3);
      expect(~config.ratio, 1.0);
      expect(~config.darkMode, isFalse);
      expect(config.hasOverrides, isFalse);
    });

    test('an absent key does not resolve to the key string itself', () {
      // The sharp edge under the fallback above, stated so it cannot be
      // weakened by accident. `TomConfigResourceProvider.getObject` answers a
      // miss with **the key you asked for**, so a lookup that reaches it
      // unguarded hands a `String` setting the literal `'client.server.url'` —
      // which coerces cleanly and is stored as though somebody had configured
      // it. A silent wrong value, not a failure.
      //
      // The declared default is asserted a line above; what this adds is the
      // name of the thing that must not appear, because "equals the default"
      // and "is not the key" fail together today and would come apart the
      // moment a default were ever changed to match a key.
      final config = _StringOnlyConfiguration();
      expect(~config.serverUrl, 'https://default.example');
      expect(
        ~config.serverUrl,
        isNot('client.server.url'),
        reason:
            'the key echoed back as its own value is the miss behaviour of '
            '`getObject`; the resolution must not be able to reach it',
      );
    });

    test('a shipped config-resources value beats the declared default', () {
      installConfig({
        'client.server.url': 'https://shipped.example',
        'client.retries': 7,
        'client.ratio': 2.5,
        'client.darkMode': true,
      });
      final config = _TestConfiguration();
      expect(~config.serverUrl, 'https://shipped.example');
      expect(~config.retries, 7);
      expect(~config.ratio, 2.5);
      expect(~config.darkMode, isTrue);
      // Resolved from a shipped source is still *not* an install override —
      // that distinction is what keeps save() from freezing shipped defaults.
      expect(config.hasOverrides, isFalse);
      expect(config.retries.baseline, 7);
      expect(config.retries.declaredDefault, 3);
    });

    test('the baseline does not move when the config provider is replaced', () {
      installConfig({'client.retries': 7});
      final config = _TestConfiguration();
      installConfig({'client.retries': 11});
      expect(config.retries.baseline, 7);
      expect(config.isOverridden('client.retries'), isFalse);
    });
  });

  group('value coercion', () {
    test('an int config value reads as a double', () {
      installConfig({'client.ratio': 2});
      expect(~_TestConfiguration().ratio, 2.0);
    });

    test('a String config value parses into int, double and bool', () {
      installConfig({
        'client.retries': '7',
        'client.ratio': '2.5',
        'client.darkMode': 'true',
      });
      final config = _TestConfiguration();
      expect(~config.retries, 7);
      expect(~config.ratio, 2.5);
      expect(~config.darkMode, isTrue);
    });

    test('an unreadable value throws type_mismatch naming the key', () {
      installConfig({'client.retries': 'not-a-number'});
      expect(
        _TestConfiguration.new,
        throwsA(
          isA<TomClientConfigurationException>()
              .having(
                (e) => e.key,
                'key',
                'client_configuration.value.type_mismatch',
              )
              .having(
                (e) => e.toString(),
                'message',
                contains('client.retries'),
              ),
        ),
      );
    });

    test('a double is not silently truncated into an int', () {
      installConfig({'client.retries': 1.5});
      expect(
        _TestConfiguration.new,
        throwsConfigException('client_configuration.value.type_mismatch'),
      );
    });
  });

  group('declaration', () {
    test('a duplicate key is rejected at declaration', () {
      expect(
        _DuplicateConfiguration.new,
        throwsConfigException('client_configuration.key.duplicate'),
      );
    });

    test('settings are addressable as a set', () {
      final config = _TestConfiguration();
      expect(
        config.settings.keys,
        containsAll(<String>['client.retries', 'client.darkMode']),
      );
      expect(config.settingFor('client.retries'), same(config.retries));
      expect(config.settingFor('client.nope'), isNull);
    });
  });

  group('load', () {
    test('adopts the persisted overrides', () async {
      final store = TomMemoryClientConfigurationStore({
        'client.retries': 9,
        'client.darkMode': true,
      });
      final config = _TestConfiguration(store: store);
      await config.load();
      expect(~config.retries, 9);
      expect(~config.darkMode, isTrue);
      expect(config.isOverridden('client.retries'), isTrue);
      // Untouched keys stay on their baseline.
      expect(~config.serverUrl, 'https://default.example');
      expect(config.isOverridden('client.server.url'), isFalse);
    });

    test(
      'restores the baseline for settings the store does not carry',
      () async {
        final store = TomMemoryClientConfigurationStore();
        final config = _TestConfiguration(store: store);
        config.retries | 42;
        await config.load();
        expect(~config.retries, 3, reason: 'load() reproduces a fresh start');
      },
    );

    test('a setting declared after load still sees its override', () async {
      final store = TomMemoryClientConfigurationStore({'client.retries': 9});
      final config = _LateConfiguration(store: store);
      await config.load();
      expect(~config.declareRetries(), 9);
    });

    test('throws when no store is wired', () {
      expect(
        _TestConfiguration().load,
        throwsConfigException('client_configuration.store.not_configured'),
      );
    });

    test('a store wired after construction is used', () async {
      final config = _TestConfiguration();
      config.store = TomMemoryClientConfigurationStore({'client.retries': 9});
      await config.load();
      expect(~config.retries, 9);
    });
  });

  group('save', () {
    test('persists overrides and only overrides', () async {
      final store = TomMemoryClientConfigurationStore();
      final config = _TestConfiguration(store: store);
      config.retries | 9;
      await config.save();
      expect(await store.read(), {'client.retries': 9});
    });

    test('drops a key that has been reset back to its baseline', () async {
      final store = TomMemoryClientConfigurationStore({'client.retries': 9});
      final config = _TestConfiguration(store: store);
      await config.load();
      config.reset('client.retries');
      await config.save();
      expect(await store.read(), isEmpty);
    });

    test(
      'carries forward persisted keys this build does not declare',
      () async {
        final store = TomMemoryClientConfigurationStore({
          'client.fromNewerBuild': 'keep',
        });
        final config = _TestConfiguration(store: store);
        await config.load();
        config.retries | 9;
        await config.save();
        expect(await store.read(), {
          'client.fromNewerBuild': 'keep',
          'client.retries': 9,
        });
      },
    );

    test('carries forward a key written after this holder loaded', () async {
      // Carry-forward seeds from the store it is about to write, not from the
      // snapshot taken at load(). Otherwise the promise above holds only for
      // keys that were already there when this holder started: a key another
      // writer added in between is not "carried forward", it is deleted.
      final store = TomMemoryClientConfigurationStore({
        'client.fromNewerBuild': 'keep',
      });
      final config = _TestConfiguration(store: store);
      await config.load();
      await store.write({
        'client.fromNewerBuild': 'keep',
        'client.writtenLater': 'also-keep',
      });
      config.retries | 9;
      await config.save();
      expect(await store.read(), {
        'client.fromNewerBuild': 'keep',
        'client.writtenLater': 'also-keep',
        'client.retries': 9,
      });
    });

    test('writes carried-forward keys first, then overrides in declaration '
        'order', () async {
      // Nothing *depends* on this order — a JSON object is unordered either
      // way. It is pinned because the documentation quotes the printed map
      // literally, and a reader compares their own run against it. An order
      // that drifts silently turns that quotation into a false report, which
      // is worse than not quoting the output at all.
      final store = TomMemoryClientConfigurationStore({
        'client.fromNewerBuild': 'keep',
      });
      final config = _TestConfiguration(store: store);
      await config.load();

      // Overridden out of declaration order, so passing cannot be an accident
      // of the order the test happened to write them in.
      config.darkMode | true;
      config.serverUrl | 'https://eu.example.com';
      await config.save();

      expect((await store.read()).keys, [
        'client.fromNewerBuild', // undeclared, carried forward
        'client.server.url', // declared first
        'client.darkMode', // declared last
      ]);
    });

    test('throws when no store is wired', () {
      expect(
        _TestConfiguration().save,
        throwsConfigException('client_configuration.store.not_configured'),
      );
    });
  });

  // Two holders over one store location. `save()` writes **this holder's**
  // complete override set for the keys it declares, plus whatever it found in
  // the store under keys it does not — so the carry-forward protects a key
  // another *build* owns, and does not protect a key both holders declare.
  //
  // The second half is the part worth testing, because it is stronger and
  // simpler than the race it is usually described by: a holder that has not
  // adopted the other's change erases it on save, sequentially, with no
  // concurrency at all. Its own view of that key is "not overridden", and the
  // document is what this holder has to say about the keys it owns.
  //
  // That is accepted rather than guarded. A client configuration is scoped to
  // (this app, this machine), so two holders over one location are two sources
  // of truth for the same keys — and no merge rule reconciles them without
  // changing what `save()` means. See `doc/configuration.md`, Limitations.
  // Only overrides are stored, so a shipped default can still move in an app
  // update — the module's central decision, argued in the class documentation.
  // This group is what keeps its consequence visible: a stored value that
  // merely *equals* the baseline is not an override either, so it survives
  // `load()` and is deleted by the next `save()`. An install therefore cannot
  // pin a setting to the value it sees today, which is a real operation the
  // module silently turns into its opposite.
  // Layer 0 of the resolution order, and the one the module's own headline use
  // case wants: "point this install at a different server" is what an installer
  // or a CI job does with a variable, not by editing a file or shipping a build.
  //
  // It sits *above* the persisted override because the two answer different
  // people — an override is what this install chose, a variable is what the
  // operator who launched it decided — and a layer the install could quietly
  // out-vote would not configure a deployment at all. Everything below follows
  // from that one placement.
  group('the environment layer', () {
    setUp(() {
      addTearDown(TomClientEnvironment.useDefaultReader);
    });

    void environment(Map<String, String> values) {
      TomClientEnvironment.reader = (name) => values[name];
    }

    test('an unset variable leaves the layers below alone', () {
      environment({});
      final config = _EnvConfiguration();

      expect(~config.endpoint, 'https://default.example');
      expect(config.endpoint.isFromEnvironment, isFalse);
      expect(config.endpoint.envAlias, 'APP_ENDPOINT');
    });

    test('a set variable supplies the value', () {
      environment({'APP_ENDPOINT': 'https://staging.example'});
      final config = _EnvConfiguration();

      expect(~config.endpoint, 'https://staging.example');
      expect(config.endpoint.isFromEnvironment, isTrue);
    });

    test('and outranks a persisted override', () async {
      // The placement, stated as the case that decides it.
      environment({'APP_ENDPOINT': 'https://staging.example'});
      final config = _EnvConfiguration(
        store: TomMemoryClientConfigurationStore({
          'client.endpoint': 'https://stored.example',
        }),
      );

      await config.load();

      expect(~config.endpoint, 'https://staging.example');
    });

    test('an empty value is set, not absent', () {
      // `APP_ENDPOINT=` is an operator saying "present and empty". Reading it
      // as unset would send the setting to a shipped default the operator was
      // deliberately replacing.
      environment({'APP_ENDPOINT': ''});
      final config = _EnvConfiguration();

      expect(~config.endpoint, '');
      expect(config.endpoint.isFromEnvironment, isTrue);
    });

    test('the value is coerced, and a bad one fails at declaration', () {
      environment({'APP_RETRIES': '11'});
      expect(~_EnvConfiguration().retries, 11);

      environment({'APP_RETRIES': 'not-a-number'});
      expect(
        _EnvConfiguration.new,
        throwsConfigException('client_configuration.value.type_mismatch'),
        reason:
            'a typo in a deployment variable has to fail where it names the '
            'key, not at the first read of whatever screen shows it',
      );
    });

    test('save never writes an environment-configured setting', () async {
      // The other half of "outranks the override": if it were written, the
      // operator's value would outlive the variable being unset.
      environment({'APP_ENDPOINT': 'https://staging.example'});
      final store = TomMemoryClientConfigurationStore();
      final config = _EnvConfiguration(store: store);
      await config.load();

      await config.save();

      expect(await store.read(), isEmpty);
      expect(config.endpoint.isOverridden, isFalse);
      expect(config.hasOverrides, isFalse);
      expect(config.hasUnsavedChanges, isFalse);
    });

    test('and unsetting it later restores the layers below', () async {
      // The consequence of not writing it, driven end to end: the store never
      // held the operator's value, so a run without the variable resolves from
      // the shipped default.
      environment({'APP_ENDPOINT': 'https://staging.example'});
      final store = TomMemoryClientConfigurationStore();
      await _EnvConfiguration(store: store).load();
      await _EnvConfiguration(store: store).save();

      environment({});
      final after = _EnvConfiguration(store: store);
      await after.load();

      expect(~after.endpoint, 'https://default.example');
    });

    test('reset restores the operator value, not the baseline', () async {
      // `reset` means "drop the install's override". The environment is not the
      // install's override, so dropping it would be resetting somebody else's
      // decision.
      environment({'APP_ENDPOINT': 'https://staging.example'});
      final config = _EnvConfiguration();

      config.endpoint | 'https://typed-by-the-user.example';
      config.reset('client.endpoint');

      expect(~config.endpoint, 'https://staging.example');
    });

    test('an in-memory change does not survive a reload', () async {
      // `set` is not taken away — a TomSetting is a TomObject and removing the
      // setter would remove the observable with it — so the guarantee is that
      // nothing persists the change and a reload puts the operator's value
      // back. A settings screen reads `isFromEnvironment` and disables the
      // field; this is what happens if it does not.
      environment({'APP_ENDPOINT': 'https://staging.example'});
      final store = TomMemoryClientConfigurationStore();
      final config = _EnvConfiguration(store: store);
      await config.load();

      config.endpoint | 'https://typed-by-the-user.example';
      await config.save();
      await config.load();

      expect(~config.endpoint, 'https://staging.example');
      expect(await store.read(), isEmpty);
    });

    test('a setting with no alias is untouched by the layer', () async {
      // The control: declaring one env-aliased setting must not change how its
      // neighbours behave.
      environment({'APP_ENDPOINT': 'https://staging.example'});
      final store = TomMemoryClientConfigurationStore();
      final config = _EnvConfiguration(store: store);
      await config.load();

      config.retries | 9;
      await config.save();

      expect(await store.read(), {'client.retries': 9});
      expect(config.retries.isFromEnvironment, isFalse);
    });
  });

  group('a persisted value equal to the baseline', () {
    test('survives load and survives a save that did not touch it', () async {
      // The entry is not this holder's override, so leaving it alone is not a
      // change, and `save()` carries forward what it did not change.
      final store = TomMemoryClientConfigurationStore({'client.retries': 3});
      final config = _TestConfiguration(store: store);

      await config.load();
      expect(~config.retries, 3, reason: 'the value is applied and is right');
      expect(config.retries.isOverridden, isFalse);

      config.darkMode | true;
      await config.save();

      expect(await store.read(), {
        'client.retries': 3,
        'client.darkMode': true,
      });
    });

    test(
      'but the install cannot create one: back to baseline removes the key',
      () async {
        final store = TomMemoryClientConfigurationStore({'client.retries': 9});
        final config = _TestConfiguration(store: store);
        await config.load();

        config.retries | 3;
        await config.save();

        expect(
          await store.read(),
          isEmpty,
          reason:
              'a value equal to the baseline is no override, so setting it is '
              'dropping the override; if this keeps the key, the module has '
              'gained the ability to pin a value and its documentation is wrong',
        );
      },
    );

    test('and the holder is not reported as dirty before that save', () async {
      // `hasUnsavedChanges` agrees with `isOverridden` and with `save()` about
      // what an override is. Counting this entry would warn on a freshly
      // loaded, untouched holder — the defect the getter exists to prevent.
      final config = _TestConfiguration(
        store: TomMemoryClientConfigurationStore({'client.retries': 3}),
      );

      await config.load();

      expect(config.hasOverrides, isFalse);
      expect(config.hasUnsavedChanges, isFalse);
    });

    test('even when the store spells it in another type', () async {
      // The store round-trips JSON and a config file may spell `3` as `'3'`,
      // so the comparison has to coerce. Raw equality would call this dirty.
      final config = _TestConfiguration(
        store: TomMemoryClientConfigurationStore({'client.retries': '3'}),
      );

      await config.load();

      expect(~config.retries, 3);
      expect(config.hasUnsavedChanges, isFalse);
    });

    test('and changing it away from the baseline is unsaved work', () async {
      // The skip must not swallow a real edit to the same key.
      final config = _TestConfiguration(
        store: TomMemoryClientConfigurationStore({'client.retries': 3}),
      );
      await config.load();

      config.retries | 11;

      expect(config.hasUnsavedChanges, isTrue);
    });

    test(
      'a persisted override reset to the baseline is still unsaved work',
      () async {
        // The case the skip must not be confused with: here the stored value is
        // 9, the user reset to 3, and the store still holds an override this
        // holder has dropped.
        final config = _TestConfiguration(
          store: TomMemoryClientConfigurationStore({'client.retries': 9}),
        );
        await config.load();

        config.reset('client.retries');

        expect(config.hasUnsavedChanges, isTrue);
      },
    );
  });

  group('two holders over one store location', () {
    test(
      'a key the saving holder does not declare is carried forward',
      () async {
        // The protection that does exist, and the reason `save()` re-reads
        // instead of seeding from its own snapshot: a key written by anyone else
        // since this holder loaded is still in the store when it looks.
        final store = TomMemoryClientConfigurationStore();
        final config = _TestConfiguration(store: store);
        await config.load();
        await store.write({'client.fromAnotherBuild': 'keep'});

        config.retries | 9;
        await config.save();

        expect(await store.read(), {
          'client.fromAnotherBuild': 'keep',
          'client.retries': 9,
        });
      },
    );

    test(
      'a key both holders declare is kept by the holder that did not touch it',
      () async {
        // A saves, then B saves, and B never reloads. B declares
        // `client.retries` but did not change it since its snapshot, so B
        // carries the store's value forward instead of writing its own view.
        final store = TomMemoryClientConfigurationStore();
        final a = _TestConfiguration(store: store);
        final b = _TestConfiguration(store: store);
        await a.load();
        await b.load();

        a.retries | 9;
        await a.save();
        b.darkMode | true;
        await b.save();

        expect(await store.read(), {
          'client.retries': 9,
          'client.darkMode': true,
        });
      },
    );

    test(
      'and the saving holder adopts it, so holder and store agree',
      () async {
        final store = TomMemoryClientConfigurationStore();
        final a = _TestConfiguration(store: store);
        final b = _TestConfiguration(store: store);
        await a.load();
        await b.load();

        a.retries | 9;
        await a.save();
        expect(~b.retries, 3, reason: 'nothing has told B yet');

        b.darkMode | true;
        await b.save();

        expect(~b.retries, 9);
        expect(b.hasUnsavedChanges, isFalse);
      },
    );

    test(
      'a key both holders changed goes to the one that saves last',
      () async {
        final store = TomMemoryClientConfigurationStore();
        final a = _TestConfiguration(store: store);
        final b = _TestConfiguration(store: store);
        await a.load();
        await b.load();

        a.retries | 9;
        await a.save();
        b.retries | 4;
        await b.save();

        expect(await store.read(), {'client.retries': 4});
        expect(~b.retries, 4);
      },
    );

    test(
      'a reset is a change, and removes the other holder\'s value',
      () async {
        final store = TomMemoryClientConfigurationStore({'client.retries': 9});
        final a = _TestConfiguration(store: store);
        await a.load();

        a.reset('client.retries');
        await a.save();

        expect(await store.read(), isEmpty);
      },
    );

    test('an external edit to an untouched key survives the save', () async {
      final store = TomMemoryClientConfigurationStore();
      final config = _TestConfiguration(store: store);
      await config.load();
      await store.write({'client.ratio': 0.5});

      config.darkMode | true;
      await config.save();

      expect(await store.read(), {
        'client.ratio': 0.5,
        'client.darkMode': true,
      });
      expect(~config.ratio, 0.5);
    });

    test(
      'saving twice with nothing changed writes back what it read',
      () async {
        final store = TomMemoryClientConfigurationStore({'client.retries': 9});
        final config = _TestConfiguration(store: store);
        await config.load();
        await config.save();
        await store.write({'client.retries': 7, 'client.legacy': 'x'});

        await config.save();

        expect(await store.read(), {'client.retries': 7, 'client.legacy': 'x'});
        expect(~config.retries, 7);
      },
    );

    test('and reloading in between changes nothing', () async {
      // Before the merge rule this reload was what made sharing safe; now it
      // is merely harmless.
      final store = TomMemoryClientConfigurationStore();
      final a = _TestConfiguration(store: store);
      final b = _TestConfiguration(store: store);
      await a.load();
      await b.load();

      a.retries | 9;
      await a.save();
      await b.load();
      b.darkMode | true;
      await b.save();

      expect(await store.read(), {
        'client.retries': 9,
        'client.darkMode': true,
      });
    });

    test(
      'an interleaved save loses the earlier reader\'s change silently',
      () async {
        // read-A, read-B, write-B, write-A. Even a holder that did reload cannot
        // help itself here: A's snapshot predates B's write. Nothing throws —
        // there is no version stamp to compare and `save()` cannot fail on a
        // conflict — which is the property that makes the loss silent.
        final store = _InterleavingStore({'client.fromAnotherBuild': 'keep'});
        final a = _TestConfiguration(store: store);
        final b = _TestConfiguration(store: store);
        await a.load();
        await b.load();

        a.retries | 9;
        b.darkMode | true;
        store.onNextRead = b.save;

        await a.save();

        final persisted = await store.read();
        expect(
          persisted['client.darkMode'],
          isNull,
          reason: 'B\'s change is lost',
        );
        expect(persisted['client.retries'], 9);
        expect(
          persisted['client.fromAnotherBuild'],
          'keep',
          reason: 'a key neither holder declares is never at risk, race or not',
        );
      },
    );
  });

  group('swapping the store', () {
    test(
      'with no snapshot, overrides are written and untouched keys adopted',
      () async {
        // The snapshot is empty after a swap, so every override counts as
        // added and every setting at its baseline as untouched.
        final config = _TestConfiguration(
          store: TomMemoryClientConfigurationStore(),
        );
        await config.load();
        final newStore = TomMemoryClientConfigurationStore({
          'client.ratio': 0.25,
        });
        config.store = newStore;
        config.retries | 9;

        await config.save();

        expect(await newStore.read(), {
          'client.ratio': 0.25,
          'client.retries': 9,
        });
        expect(~config.ratio, 0.25);
      },
    );

    test('does not carry the previous store\'s keys into the new one', () async {
      // Carry-forward protects the keys of *a* store. A holder moved to a
      // different store must not deposit the first store's keys in the second:
      // they describe an install location this holder has been moved away from.
      final oldStore = TomMemoryClientConfigurationStore({
        'client.legacy': 'FROM-OLD-STORE',
      });
      final config = _TestConfiguration(store: oldStore);
      await config.load();

      final newStore = TomMemoryClientConfigurationStore();
      config.store = newStore;
      config.retries | 9;
      await config.save();

      expect(await newStore.read(), {'client.retries': 9});
    });

    test('preserves the new store\'s own undeclared keys', () async {
      // The distinction that decides the fix. Merely discarding the stale
      // snapshot on swap would satisfy the test above while destroying the new
      // store's foreign keys — trading a leak for a wipe, and breaking the
      // carry-forward promise for the store actually being written. Only
      // reading the store that is about to be written gets both right.
      final oldStore = TomMemoryClientConfigurationStore({
        'client.legacy': 'FROM-OLD-STORE',
      });
      final config = _TestConfiguration(store: oldStore);
      await config.load();

      final newStore = TomMemoryClientConfigurationStore({
        'client.ownKey': 'KEEP-ME',
      });
      config.store = newStore;
      config.retries | 9;
      await config.save();

      expect(await newStore.read(), {
        'client.ownKey': 'KEEP-ME',
        'client.retries': 9,
      });
    });

    test('leaves the previous store untouched', () async {
      final oldStore = TomMemoryClientConfigurationStore({
        'client.legacy': 'FROM-OLD-STORE',
      });
      final config = _TestConfiguration(store: oldStore);
      await config.load();

      config.store = TomMemoryClientConfigurationStore();
      config.retries | 9;
      await config.save();

      expect(
        await oldStore.read(),
        {'client.legacy': 'FROM-OLD-STORE'},
        reason: 'saving to the new store must not write to the old one',
      );
    });

    test(
      'a setting declared after the swap does not see the old override',
      () async {
        // The same stale snapshot reaches a second consumer: a setting declared
        // late is initialised from it. After a swap that snapshot describes a
        // store this holder no longer writes to, so the override it carries
        // belongs to somebody else's install location.
        final config = _LateConfiguration(
          store: TomMemoryClientConfigurationStore({'client.retries': 9}),
        );
        await config.load();

        config.store = TomMemoryClientConfigurationStore();
        expect(
          ~config.declareRetries(),
          3,
          reason: 'the new store has no override, so the baseline stands',
        );
      },
    );

    test('re-assigning the same store keeps the loaded snapshot', () async {
      // Only a *change* of store invalidates the snapshot. Assigning the same
      // instance again is a no-op, so a late declaration still finds its
      // override.
      final store = TomMemoryClientConfigurationStore({'client.retries': 9});
      final config = _LateConfiguration(store: store);
      await config.load();

      config.store = store;
      expect(~config.declareRetries(), 9);
    });
  });

  group('overrides', () {
    test('resetAll restores every baseline', () {
      final config = _TestConfiguration();
      config.retries | 9;
      config.darkMode | true;
      expect(config.hasOverrides, isTrue);
      config.resetAll();
      expect(config.hasOverrides, isFalse);
      expect(~config.retries, 3);
      expect(~config.darkMode, isFalse);
    });

    test('an unknown key is rejected rather than silently ignored', () {
      final config = _TestConfiguration();
      expect(
        () => config.reset('client.nope'),
        throwsConfigException('client_configuration.key.unknown'),
      );
      expect(
        () => config.isOverridden('client.nope'),
        throwsConfigException('client_configuration.key.unknown'),
      );
    });
  });

  // The question a settings screen asks before it lets itself be dismissed, and
  // the one `hasOverrides` cannot answer: "differs from baseline" is a fact
  // about the install, so a holder that `load` filled from the store is already
  // overridden with nothing unsaved.
  group('unsaved changes', () {
    test('a freshly loaded holder is overridden and not dirty', () async {
      // The confusion stated as a test. A screen guarding its dismiss with
      // `if (hasOverrides) warn()` warns here, on a holder nobody has touched.
      final config = _TestConfiguration(
        store: TomMemoryClientConfigurationStore({'client.retries': 9}),
      );

      await config.load();

      expect(config.hasOverrides, isTrue);
      expect(config.hasUnsavedChanges, isFalse);
    });

    test('changing a setting makes it dirty, saving makes it clean', () async {
      final config = _TestConfiguration(
        store: TomMemoryClientConfigurationStore({'client.retries': 9}),
      );
      await config.load();

      config.retries | 11;
      expect(config.hasUnsavedChanges, isTrue);

      await config.save();
      expect(config.hasUnsavedChanges, isFalse);
    });

    test('adding an override the store never had is dirty', () async {
      final config = _TestConfiguration(
        store: TomMemoryClientConfigurationStore({'client.retries': 9}),
      );
      await config.load();

      config.darkMode | true;

      expect(config.hasUnsavedChanges, isTrue);
    });

    test('dropping a persisted override is unsaved work too', () async {
      // A removal is a change to what the store should hold, and the naive
      // "any setting is overridden" reading calls this one clean — which is the
      // direction that loses work silently.
      final config = _TestConfiguration(
        store: TomMemoryClientConfigurationStore({'client.retries': 9}),
      );
      await config.load();

      config.reset('client.retries');

      expect(config.hasOverrides, isFalse);
      expect(
        config.hasUnsavedChanges,
        isTrue,
        reason: 'the store still holds an override this holder has dropped',
      );
    });

    test('resetAll on a loaded holder is dirty until it is saved', () async {
      final config = _TestConfiguration(
        store: TomMemoryClientConfigurationStore({
          'client.retries': 9,
          'client.darkMode': true,
        }),
      );
      await config.load();

      config.resetAll();
      expect(config.hasUnsavedChanges, isTrue);

      await config.save();
      expect(config.hasUnsavedChanges, isFalse);
    });

    test('a key this build does not declare is never unsaved', () async {
      // `save` carries a foreign key forward untouched, so nothing this holder
      // does can make it differ. Counting it would leave a settings screen
      // permanently dirty because an older build wrote a setting this one
      // dropped.
      final config = _TestConfiguration(
        store: TomMemoryClientConfigurationStore({'client.gone': 'legacy'}),
      );

      await config.load();

      expect(config.hasUnsavedChanges, isFalse);
    });

    test('with no store wired an override reads as unsaved', () async {
      // There is nowhere it could have been saved, and the getter has to answer
      // rather than throw: a dismiss guard runs where an exception is not an
      // option.
      final config = _TestConfiguration();

      expect(config.hasUnsavedChanges, isFalse);
      config.retries | 11;
      expect(config.hasUnsavedChanges, isTrue);
    });

    test('pointing at a different store discards the snapshot', () async {
      // The snapshot describes the store it was read from. Keeping it across a
      // swap would report a holder as clean against a store it has never read.
      final config = _TestConfiguration(
        store: TomMemoryClientConfigurationStore({'client.retries': 9}),
      );
      await config.load();
      expect(config.hasUnsavedChanges, isFalse);

      config.store = TomMemoryClientConfigurationStore();

      expect(config.hasUnsavedChanges, isTrue);
    });
  });

  group('shadowing by a narrower scope', () {
    test('a pinned setting is answered from the install alone', () async {
      final device = _RecordingPreferences({'client.pinned': 'device'});
      final user = _RecordingPreferences({'client.pinned': 'user'});
      final config = _ShadowedConfiguration();
      final effective = TomEffectiveSettings(
        fromDeviceStore: device.get,
        fromUserStore: user.get,
      );

      expect(await effective.valueOf(config.pinned), 'install');
      // Not merely outranked — never asked. A pinned key costs no round trip.
      expect(device.reads, isEmpty);
      expect(user.reads, isEmpty);
    });

    test('a user-overridable setting takes the account value', () async {
      final user = _RecordingPreferences({'client.byUser': 'account'});
      final config = _ShadowedConfiguration();
      final effective = TomEffectiveSettings(fromUserStore: user.get);

      expect(await effective.valueOf(config.byUser), 'account');
    });

    test('a user-overridable setting is not opened to the device', () async {
      // The arm names the *narrowest* scope permitted, so `user` stops there.
      final device = _RecordingPreferences({'client.byUser': 'device'});
      final user = _RecordingPreferences();
      final config = _ShadowedConfiguration();
      final effective = TomEffectiveSettings(
        fromDeviceStore: device.get,
        fromUserStore: user.get,
      );

      expect(await effective.valueOf(config.byUser), 'install');
      expect(device.reads, isEmpty);
      expect(user.reads, ['client.byUser']);
    });

    test('a device-overridable setting takes the device value', () async {
      final device = _RecordingPreferences({'client.byDevice': 'device'});
      final user = _RecordingPreferences({'client.byDevice': 'account'});
      final config = _ShadowedConfiguration();
      final effective = TomEffectiveSettings(
        fromDeviceStore: device.get,
        fromUserStore: user.get,
      );

      expect(await effective.valueOf(config.byDevice), 'device');
      // The account is the wider of the two and is not consulted once this
      // device has answered.
      expect(user.reads, isEmpty);
    });

    test('a device-overridable setting falls through to the account', () async {
      final device = _RecordingPreferences();
      final user = _RecordingPreferences({'client.byDevice': 'account'});
      final config = _ShadowedConfiguration();
      final effective = TomEffectiveSettings(
        fromDeviceStore: device.get,
        fromUserStore: user.get,
      );

      expect(await effective.valueOf(config.byDevice), 'account');
      expect(device.reads, ['client.byDevice']);
    });

    test('and to the install when neither store holds the key', () async {
      final device = _RecordingPreferences();
      final user = _RecordingPreferences();
      final config = _ShadowedConfiguration();
      final effective = TomEffectiveSettings(
        fromDeviceStore: device.get,
        fromUserStore: user.get,
      );

      expect(await effective.valueOf(config.byDevice), 'install');
      expect(device.reads, ['client.byDevice']);
      expect(user.reads, ['client.byDevice']);
    });

    test('an omitted store is skipped rather than failing', () async {
      final config = _ShadowedConfiguration();

      expect(
        await const TomEffectiveSettings().valueOf(config.byDevice),
        'install',
      );
    });

    test('the install value it falls back to is the resolved one', () async {
      installConfig({
        'client': {'byDevice': 'shipped'},
      });
      final config = _ShadowedConfiguration();
      final effective = TomEffectiveSettings(
        fromDeviceStore: _RecordingPreferences().get,
      );

      // Not the declared default: the floor is the whole install stack, which
      // the setting has already resolved.
      expect(await effective.valueOf(config.byDevice), 'shipped');
    });

    test('a non-String setting keeps its type', () async {
      final device = _RecordingPreferences({'client.retries': 9});
      final config = _ShadowedConfiguration();
      final effective = TomEffectiveSettings(fromDeviceStore: device.get);

      final int resolved = await effective.valueOf(config.retries);
      expect(resolved, 9);
    });

    test('the environment layer does not close a setting', () async {
      addTearDown(TomClientEnvironment.useDefaultReader);
      TomClientEnvironment.reader = (name) =>
          name == 'APP_ENDPOINT' ? 'https://operator.example' : null;
      final config = _EnvShadowedConfiguration();
      final device = _RecordingPreferences({
        'client.endpoint': 'https://device.example',
      });
      final effective = TomEffectiveSettings(fromDeviceStore: device.get);

      // The operator sets the *install's* value; `overridableBy` says who may
      // shadow the install. A setting the operator must win is declared
      // `none`, and that is the only lever.
      expect(config.endpoint.isFromEnvironment, isTrue);
      expect(
        await effective.valueOf(config.endpoint),
        'https://device.example',
      );
    });

    test(
      'a preference of the wrong type is raised, not stepped over',
      () async {
        final store = TomStoredDevicePreferences(
          TomMemoryDevicePreferenceStore(),
        );
        await store.set<int>('client.byDevice', 7);
        final config = _ShadowedConfiguration();
        final effective = TomEffectiveSettings(fromDeviceStore: store.get);

        await expectLater(
          () => effective.valueOf(config.byDevice),
          throwsA(isA<TomUserPreferenceCodecException>()),
        );
      },
    );

    test('both shipped stores read as a TomPreferenceLookup', () {
      // The typedef's claim: a caller passes the method, not an adapter.
      final device = TomStoredDevicePreferences(
        TomMemoryDevicePreferenceStore(),
      );
      final account = TomUserPreferencesClient(
        baseUri: Uri.parse('https://example.invalid'),
      );
      addTearDown(account.close);

      final TomPreferenceLookup fromDevice = device.get;
      final TomPreferenceLookup fromAccount = account.get;
      expect(fromDevice, isNotNull);
      expect(fromAccount, isNotNull);
    });

    test('opening a key the preference stores would refuse is refused', () {
      expect(
        _IllegalShadowKeyConfiguration.new,
        throwsA(
          isA<TomUserPreferenceKeyException>().having(
            (e) => e.key,
            'key',
            'preferences.key.invalid',
          ),
        ),
      );
    });

    test('a pinned setting may carry any key', () {
      // The rule applies where the promise is made. A key no preference store
      // will ever see is none of the preference vocabulary's business.
      final config = _PinnedOddKeyConfiguration();
      expect(~config.odd, 'install');
    });
  });

  group('a holder built before its config provider', () {
    // Every other test in this file installs a provider in `setUp`, so the
    // ordering an application can actually get wrong — holder first, resource
    // providers second — was the one case the suite never reached.
    test('declaring a setting fails loudly rather than defaulting', () {
      TomConfigResourceProvider.clearAppConfigProvider();

      expect(
        _TestConfiguration.new,
        throwsA(
          isA<TomResourceException>().having(
            (e) => e.key,
            'key',
            'resources.config_provider.not_installed',
          ),
        ),
        reason:
            'a holder whose baselines were resolved against nothing would '
            'serve declared defaults that look configured',
      );
    });

    test('the failure names the remedy, and the remedy works', () {
      TomConfigResourceProvider.clearAppConfigProvider();

      late final TomResourceException failure;
      try {
        _TestConfiguration();
        fail('expected the unbootstrapped lookup to throw');
      } on TomResourceException catch (error) {
        failure = error;
      }
      expect(
        failure.toString(),
        contains('TomConfigResourceProvider.from({})'),
        reason: 'an app with no configuration bundle still installs one',
      );

      // The message is only worth its length if what it tells you to do is
      // enough. It is: an empty provider is a complete answer, and every
      // setting then resolves to the default written at its declaration.
      TomConfigResourceProvider.setAppConfigProvider(
        TomConfigResourceProvider.from({}),
      );
      final config = _TestConfiguration();
      expect(~config.retries, 3);
      expect(config.hasOverrides, isFalse);
    });
  });

  group('applyRaw', () {
    // The method the store side goes through. `load()` exercises it on every
    // key it adopts, but a store that round-tripped through JSON — or one an
    // older build wrote — can hold a `'9'` where an `int` is declared, and
    // that widening is the reason the method is not a plain `set`.
    test('coerces a store-shaped value to the declared type', () {
      final config = _TestConfiguration();

      config.retries.applyRaw('9');
      config.ratio.applyRaw(2);
      config.darkMode.applyRaw('true');

      expect(~config.retries, 9);
      expect(~config.ratio, 2.0);
      expect(~config.darkMode, isTrue);
      expect(config.isOverridden('client.retries'), isTrue);
    });

    test('throws type_mismatch naming the key it could not read', () {
      final config = _TestConfiguration();

      expect(
        () => config.retries.applyRaw('not a number'),
        throwsA(
          isA<TomClientConfigurationException>()
              .having(
                (e) => e.key,
                'key',
                'client_configuration.value.type_mismatch',
              )
              .having(
                (e) => e.toString(),
                'message',
                contains('client.retries'),
              ),
        ),
      );
      expect(~config.retries, 3, reason: 'a refused value is not applied');
    });

    test('load() coerces what the store round-tripped', () async {
      final store = TomMemoryClientConfigurationStore({
        'client.retries': '9',
        'client.ratio': 2,
        'client.darkMode': 'true',
      });
      final config = _TestConfiguration(store: store);

      await config.load();

      expect(~config.retries, 9);
      expect(~config.ratio, 2.0);
      expect(~config.darkMode, isTrue);
    });

    test('load() throws on a stored value it cannot read', () async {
      final store = TomMemoryClientConfigurationStore({
        'client.retries': 'not a number',
      });
      final config = _TestConfiguration(store: store);

      await expectLater(
        config.load,
        throwsConfigException('client_configuration.value.type_mismatch'),
      );
    });
  });

  group('toString', () {
    // Both formats are documented with their exact shape, and a debugger's
    // view of a settings holder is the one place a reader meets them.
    test('a setting reads key=value', () {
      final config = _TestConfiguration();
      expect(config.retries.toString(), 'client.retries=3');
    });

    test('and gains the overridden suffix exactly when it is', () {
      final config = _TestConfiguration();

      config.retries | 9;
      expect(config.retries.toString(), 'client.retries=9 (overridden)');

      config.retries.reset();
      expect(
        config.retries.toString(),
        'client.retries=3',
        reason: 'the suffix tracks isOverridden, not "was ever written"',
      );
    });

    test('an environment-bound setting is never suffixed', () {
      // It carries the operator's value, which is not the install's override —
      // the suffix says "this install changed it", and here it did not.
      addTearDown(TomClientEnvironment.useDefaultReader);
      TomClientEnvironment.reader = (name) =>
          name == 'APP_ENDPOINT' ? 'https://staging.example' : null;
      final config = _EnvConfiguration();

      expect(
        config.endpoint.toString(),
        'client.endpoint=https://staging.example',
      );
    });

    test('a holder reads as its type over every declared setting', () {
      final config = _TestConfiguration();
      config.darkMode | true;

      expect(
        config.toString(),
        '_TestConfiguration(client.server.url=https://default.example, '
        'client.retries=3, client.ratio=1.0, '
        'client.darkMode=true (overridden))',
      );
    });
  });

  group('observation', () {
    test('a per-field observer sees only its own setting', () {
      final config = _TestConfiguration();
      var retriesChanges = 0;
      final observer = config.retries >> (_) => retriesChanges++;

      config.retries | 9;
      config.darkMode | true;

      expect(retriesChanges, 1);
      config.retries.removeObserver(observer);
    });

    test('a holder observer sees every field change', () {
      final config = _TestConfiguration();
      var holderChanges = 0;
      final observer = config >> (_) => holderChanges++;

      config.retries | 9;
      config.darkMode | true;

      expect(holderChanges, 2);
      config.removeObserver(observer);
    });

    test('load emits one holder notification for the whole load', () async {
      final store = TomMemoryClientConfigurationStore({
        'client.retries': 9,
        'client.darkMode': true,
        'client.ratio': 2.5,
      });
      final config = _TestConfiguration(store: store);
      var holderChanges = 0;
      final observer = config >> (_) => holderChanges++;

      await config.load();

      expect(holderChanges, 1);
      config.removeObserver(observer);
    });

    // A screen batching a multi-setting edit around a reload mutes the holder,
    // writes, reloads, writes again, and unmutes — and asks for exactly one
    // rebuild. It gets one only because the kernel's `mute` is a depth counter:
    // `load` and `resetAll` mute the same holder the caller already muted, and
    // a boolean flag would let their `unmute` release the caller's batch,
    // flushing what it had suppressed and leaving every later write notifying
    // immediately.
    //
    // Nothing in this module can enforce that: the depth belongs to
    // `TomObservable`, in another package. So it is asserted from the outside
    // here rather than assumed. Both mutations were run — the kernel's `unmute`
    // dropping to zero instead of decrementing, and this module releasing one
    // mute too many — and each fails these two.
    test('load inside a caller mute does not release it', () async {
      final store = TomMemoryClientConfigurationStore({'client.retries': 9});
      final config = _TestConfiguration(store: store);
      var holderChanges = 0;
      final observer = config >> (_) => holderChanges++;

      config.mute();
      config.serverUrl | 'https://batched.example';
      await config.load();
      expect(
        holderChanges,
        0,
        reason: 'the load released the caller\'s mute and flushed its write',
      );
      config.darkMode | true;
      expect(
        holderChanges,
        0,
        reason: 'the holder came back unmuted, so the next write escaped',
      );

      config.unmute();

      expect(
        holderChanges,
        1,
        reason: 'the caller asked for one notification and got one',
      );
      config.removeObserver(observer);
    });

    test('resetAll inside a caller mute does not release it either', () async {
      final config = _TestConfiguration(
        store: TomMemoryClientConfigurationStore(),
      );
      var holderChanges = 0;
      final observer = config >> (_) => holderChanges++;

      config.mute();
      config.serverUrl | 'https://batched.example';
      config.resetAll();
      expect(holderChanges, 0);
      config.darkMode | true;
      expect(holderChanges, 0);

      config.unmute();

      expect(holderChanges, 1);
      config.removeObserver(observer);
    });

    test('a load that changes nothing is silent', () async {
      final config = _TestConfiguration(
        store: TomMemoryClientConfigurationStore(),
      );
      var holderChanges = 0;
      final observer = config >> (_) => holderChanges++;

      await config.load();

      expect(holderChanges, 0);
      config.removeObserver(observer);
    });

    test('resetAll emits one holder notification', () {
      final config = _TestConfiguration();
      config.retries | 9;
      config.darkMode | true;
      var holderChanges = 0;
      final observer = config >> (_) => holderChanges++;

      config.resetAll();

      expect(holderChanges, 1);
      config.removeObserver(observer);
    });
  });

  group('TomMemoryClientConfigurationStore', () {
    test('reads back what was written, and copies in and out', () async {
      final store = TomMemoryClientConfigurationStore();
      expect(await store.read(), isEmpty);

      final written = <String, Object?>{'a': 1};
      await store.write(written);
      written['b'] = 2; // must not leak into the store

      final read = await store.read();
      expect(read, {'a': 1});
      read['c'] = 3; // must not leak back either
      expect(await store.read(), {'a': 1});
    });

    test('an empty write clears the store', () async {
      final store = TomMemoryClientConfigurationStore({'a': 1});
      await store.write({});
      expect(await store.read(), isEmpty);
    });
  });

  group('TomFileClientConfigurationStore', () {
    late Directory directory;
    late String path;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('tom_client_config_');
      path = '${directory.path}/nested/config.json';
    });

    tearDown(() => directory.deleteSync(recursive: true));

    test('an absent file reads as empty', () async {
      expect(await TomFileClientConfigurationStore(path).read(), isEmpty);
    });

    test('round-trips the override map, creating parent directories', () async {
      final store = TomFileClientConfigurationStore(path);
      await store.write({'client.retries': 9, 'client.darkMode': true});
      expect(File(path).existsSync(), isTrue);
      expect(await store.read(), {
        'client.retries': 9,
        'client.darkMode': true,
      });
    });

    test('an empty write deletes the file', () async {
      final store = TomFileClientConfigurationStore(path);
      await store.write({'client.retries': 9});
      await store.write({});
      expect(File(path).existsSync(), isFalse);
      expect(await store.read(), isEmpty);
    });

    test('leaves no temporary file behind', () async {
      final store = TomFileClientConfigurationStore(path);
      await store.write({'client.retries': 9});
      expect(File('$path.part').existsSync(), isFalse);
    });

    test('a zero-length file reads as empty', () async {
      File(path).createSync(recursive: true);
      expect(await TomFileClientConfigurationStore(path).read(), isEmpty);
    });

    test('unparseable content throws instead of looking empty', () async {
      File(path)
        ..createSync(recursive: true)
        ..writeAsStringSync('{not json');
      expect(
        TomFileClientConfigurationStore(path).read,
        throwsConfigException('client_configuration.store.invalid_content'),
      );
    });

    test('a JSON value that is not an object throws', () async {
      File(path)
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode([1, 2, 3]));
      expect(
        TomFileClientConfigurationStore(path).read,
        throwsConfigException('client_configuration.store.invalid_content'),
      );
    });

    test('drives a holder end to end', () async {
      final config = _TestConfiguration(
        store: TomFileClientConfigurationStore(path),
      );
      config.serverUrl | 'https://chosen.example';
      await config.save();

      // A second holder over the same file is what the next app start sees.
      final reloaded = _TestConfiguration(
        store: TomFileClientConfigurationStore(path),
      );
      await reloaded.load();
      expect(~reloaded.serverUrl, 'https://chosen.example');
      expect(~reloaded.retries, 3, reason: 'defaults are not persisted');
    });
  });

  group('the two file-store variants present one signature', () {
    // The point of a conditional export is that one name means one thing on
    // every target. When the variants' constructors differ, code that compiles
    // on the platform you are building for fails on the one you are not — and
    // the compiler only says so once someone builds for the second platform,
    // which is the worst moment to find out.
    //
    // The checks live in `support/conditional_export_variants.dart`, shared
    // with the preferences module's three-variant store. They read the sources
    // with comments stripped, which this copy needs: the dartdoc recording why
    // the io variant is not const has to quote the
    // `const TomFileClientConfigurationStore(path)` expression it warns about,
    // so a guard that read comments too would match the quotation instead of
    // the declaration, and a single reflow of that paragraph would decide
    // whether it does. That makes it green-on-anything by accident.
    const io =
        'lib/src/tomclient/configuration/file_configuration_store_io.dart';
    const neutral =
        'lib/src/tomclient/configuration/file_configuration_store_neutral.dart';
    const className = 'TomFileClientConfigurationStore';

    test('both variants agree about const', () {
      expectVariantsAgreeOnConst(
        variantPaths: const [io, neutral],
        className: className,
      );
    });

    test('both variants declare the same public members', () {
      expectVariantsDeclareSameMembers(const [io, neutral]);
    });
  });

  group('the API summary mirrors the configuration sources', () {
    // The coverage sweep this group began as — every public member the sources
    // declare must be named in the summary — now runs for all seven modules in
    // `api_reference_coverage_test.dart`, along with the exception-parameter
    // mirror. What stays here is what is genuinely about *this* module: the
    // conditional-export store's `const` decision, and the hand-picked list of
    // classes whose constructor call shape the summary must show.
    const summaryPath = 'doc/api/api_summary_configuration.md';

    test('the summary reproduces the file store constructor exactly', () {
      // The one signature the summary previously disagreed with the source
      // about. Pinning it here means the const decision cannot be made in the
      // source and forgotten in the mirror.
      //
      // Both sides are read through the shared helpers, which skip the dartdoc
      // and the summary's prose. This check used to match raw text on both
      // sides and so reported the *explanation* of why the constructor is not
      // const as a const declaration — it stayed green only because the
      // explaining sentence happened to wrap between the keyword and the class
      // name, and it went red the moment that sentence was rewrapped to read
      // better. See `support/conditional_export_variants.dart`.
      const className = 'TomFileClientConfigurationStore';
      expect(
        summaryDeclaresConstConstructor(summaryPath, className),
        declaresConstConstructor(
          'lib/src/tomclient/configuration/file_configuration_store_io.dart',
          className,
        ),
        reason: 'the summary must show `const` exactly when the source does',
      );
    });

    test('every class with a public constructor shows it', () {
      // The name check above cannot see this one. A class whose constructor is
      // undocumented still has its *name* all over the page as a type, so the
      // omission reads as covered. Constructors are therefore checked by
      // signature: the summary must show a call shape for each.
      final summary = File(summaryPath).readAsStringSync();
      final offenders = <String>[
        for (final className in const [
          'TomClientConfigurationStore',
          'TomMemoryClientConfigurationStore',
          'TomFileClientConfigurationStore',
          'TomClientConfigurationException',
          'TomBaseClientConfiguration',
          'TomEffectiveSettings',
        ])
          // The paren must abut the name. Allowing whitespace between them
          // matches the alignment spaces in the class-hierarchy diagram
          // (`TomClientConfigurationStore          (abstract)`), so the guard
          // would pass on a page that shows no constructor at all.
          if (!summary.contains('$className(')) className,
      ];

      expect(
        offenders,
        isEmpty,
        reason:
            'these classes declare a public constructor that $summaryPath '
            'never shows the call shape of',
      );
    });
  });

  group('the module documents validation truthfully', () {
    // Documentation that points somewhere is a promise that the somewhere
    // exists. These artefacts pointed per-field validation at the `Cs*`
    // code-spec annotations, which carry no constraint of any kind and live in
    // a package this one does not depend on — so a reader following the
    // pointer found neither the constraints nor a way to reach them.
    const artefacts = [
      'lib/src/tomclient/configuration/client_configuration.dart',
      'doc/configuration.md',
    ];

    test('no artefact defers validation to an unreachable annotation set', () {
      // Conditioned on the pubspec rather than hard-coding the answer: if
      // `tom_code_specs` ever becomes a dependency, pointing at its
      // annotations stops being a dead end and this guard stops objecting.
      final dependsOnCodeSpecs = File(
        'pubspec.yaml',
      ).readAsStringSync().contains('tom_code_specs');
      if (dependsOnCodeSpecs) return;

      final offenders = <String>[
        for (final path in artefacts)
          if (File(path).readAsStringSync().contains('Cs*')) path,
      ];
      expect(
        offenders,
        isEmpty,
        reason:
            'these artefacts point the reader at the `Cs*` annotations for '
            'per-field constraints, but tom_code_specs is not a dependency of '
            'this package, so nothing here can reference them',
      );
    });

    /// Every blank-line-delimited paragraph of [path] that discusses validation.
    ///
    /// A whole-file search would be worthless here: both artefacts use the word
    /// "caller" in unrelated passages, so `contains` over the file passes
    /// however the validation paragraph reads. Paragraph boundaries are blank
    /// lines, and — because a dartdoc block has no blank lines — a bare `///`.
    ///
    /// All matches are returned rather than the first, so the guards below do
    /// not depend on where in the file the paragraphs happen to sit.
    ///
    /// A markdown bullet list has no blank lines inside it, so a top-level `- `
    /// also starts a new paragraph: in a list the unit a reader takes as one
    /// statement is the bullet, not the whole list.
    List<String> validationParagraphsOf(String path) => File(path)
        .readAsStringSync()
        .split('\n')
        .fold<List<List<String>>>([[]], (acc, line) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || trimmed == '///') {
            acc.add([]);
          } else if (line.startsWith('- ')) {
            acc.add([line]);
          } else {
            acc.last.add(line);
          }
          return acc;
        })
        .map((lines) => lines.join('\n'))
        .where((p) => p.toLowerCase().contains('validation'))
        .toList();

    test('both artefacts say the caller owns per-field constraints', () {
      // The replacement for the deflection has to actually say something. A
      // guard that only forbade the old text would be satisfied by deleting
      // the paragraph, which loses a true and useful statement.
      final offenders = <String>[
        for (final path in artefacts)
          if (!validationParagraphsOf(path).any((p) => p.contains('caller')))
            path,
      ];
      expect(
        offenders,
        isEmpty,
        reason:
            'the module performs no per-field validation, so the passage '
            'that says so must name who does',
      );
    });

    test('the paragraphs this guard reads are the ones about validation', () {
      // A splitter that silently stopped finding anything would make the guard
      // above fail loudly, but one that returned the *whole file* would pass
      // forever. Pin that what it returns is non-empty, short and on-topic.
      for (final path in artefacts) {
        final paragraphs = validationParagraphsOf(path);
        expect(paragraphs, isNotEmpty, reason: path);
        for (final paragraph in paragraphs) {
          expect(paragraph.toLowerCase(), contains('validation'), reason: path);
          expect(paragraph.split('\n').length, lessThan(12), reason: path);
        }
      }
    });

    test('a setting really does accept any value of its type', () {
      // The claim the documentation now makes, asserted rather than promised.
      TomConfigResourceProvider.setAppConfigProvider(
        TomConfigResourceProvider.from({}),
      );
      final config = _ValidationProbeConfiguration();

      config.refreshSeconds | -1;
      expect(~config.refreshSeconds, -1, reason: 'no range check exists');

      config.serverUrl | '';
      expect(~config.serverUrl, '', reason: 'no non-empty check exists');

      // Type, by contrast, *is* enforced — that is the one check the module
      // performs, and it is why the documentation says "type, not value".
      expect(
        () => config.refreshSeconds.applyRaw('not a number'),
        throwsA(
          isA<TomClientConfigurationException>().having(
            (e) => e.key,
            'key',
            'client_configuration.value.type_mismatch',
          ),
        ),
      );
    });
  });

  group('a setting drives a widget directly', () {
    // The practical payoff of settings being observables rather than map
    // entries: a TomSetting is a legal `subState` with nothing adapting it.
    // Asserted here rather than only shown in prose, because "no adapter
    // needed" is a claim about the type bound, and a type bound can drift.
    testWidgets('TomObservingWidget rebuilds on a setting change', (
      tester,
    ) async {
      TomConfigResourceProvider.setAppConfigProvider(
        TomConfigResourceProvider.from({}),
      );
      final config = _TestConfiguration();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TomObservingWidget<TomSetting<bool>>(
              subState: config.darkMode,
              builder: (setting, _) =>
                  Switch(value: ~setting, onChanged: (next) => setting | next),
            ),
          ),
        ),
      );

      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(
        tester.widget<Switch>(find.byType(Switch)).value,
        isTrue,
        reason:
            'the widget observes the setting itself, so writing through '
            'the setting must repaint it',
      );
      expect(~config.darkMode, isTrue);
      expect(config.isOverridden('client.darkMode'), isTrue);
    });

    testWidgets('the widget follows a later change made elsewhere', (
      tester,
    ) async {
      // Tapping the Switch proves the round trip through the widget's own
      // callback. This proves the direction that matters for a settings
      // screen: something else changes the setting and the screen follows.
      TomConfigResourceProvider.setAppConfigProvider(
        TomConfigResourceProvider.from({}),
      );
      final config = _TestConfiguration();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TomObservingWidget<TomSetting<bool>>(
              subState: config.darkMode,
              builder: (setting, _) =>
                  Switch(value: ~setting, onChanged: (_) {}),
            ),
          ),
        ),
      );

      config.darkMode | true;
      await tester.pump();

      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });
  });

  group('the neutral file store fails loudly', () {
    // The neutral variant is only conditionally *exported*, not conditionally
    // compiled — so it can be imported by path and asserted on any target,
    // including this one. Without that, the documented web behaviour would be
    // a promise no test ever checks, on the one code path whose whole purpose
    // is to fail rather than degrade quietly.
    test('construction throws unsupported_platform', () {
      expect(
        () => neutral.TomFileClientConfigurationStore(
          '/wherever/client_config.json',
        ),
        throwsConfigException(
          'client_configuration.store.unsupported_platform',
        ),
      );
    });

    test('the failure names the path that was asked for', () {
      // A settings screen that fails at startup has to be able to say what it
      // was trying to open, or the report is unactionable.
      try {
        neutral.TomFileClientConfigurationStore('/wherever/client_config.json');
        fail('expected the neutral store to throw');
      } on TomClientConfigurationException catch (error) {
        expect(error.parameters?['path'], '/wherever/client_config.json');
      }
    });
  });

  group('the shipped example runs', () {
    test('configuration_example.run() completes its assertions', () async {
      // The example is quoted as documentation, so it has to be executable
      // documentation. Running it here is what stops a snippet that no longer
      // compiles — or an assert that no longer holds — from being shown to a
      // reader as the way to use the module.
      await example.run();
    });
  });
}

/// A holder for the validation probe: two settings whose values have obvious
/// real-world constraints, neither of which this module enforces.
class _ValidationProbeConfiguration extends TomBaseClientConfiguration {
  late final TomSetting<String> serverUrl;
  late final TomSetting<int> refreshSeconds;

  @override
  void declareSettings() {
    serverUrl = stringSetting('probe.server.url', 'https://api.example.com');
    refreshSeconds = intSetting('probe.refresh.seconds', 60);
  }
}
