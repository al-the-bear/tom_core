import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

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
              .having((e) => e.key, 'key',
                  'client_configuration.value.type_mismatch')
              .having((e) => e.toString(), 'message',
                  contains('client.retries')),
        ),
      );
    });

    test('a double is not silently truncated into an int', () {
      installConfig({'client.retries': 1.5});
      expect(_TestConfiguration.new,
          throwsConfigException('client_configuration.value.type_mismatch'));
    });
  });

  group('declaration', () {
    test('a duplicate key is rejected at declaration', () {
      expect(_DuplicateConfiguration.new,
          throwsConfigException('client_configuration.key.duplicate'));
    });

    test('settings are addressable as a set', () {
      final config = _TestConfiguration();
      expect(config.settings.keys,
          containsAll(<String>['client.retries', 'client.darkMode']));
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

    test('restores the baseline for settings the store does not carry',
        () async {
      final store = TomMemoryClientConfigurationStore();
      final config = _TestConfiguration(store: store);
      config.retries | 42;
      await config.load();
      expect(~config.retries, 3, reason: 'load() reproduces a fresh start');
    });

    test('a setting declared after load still sees its override', () async {
      final store = TomMemoryClientConfigurationStore({'client.retries': 9});
      final config = _LateConfiguration(store: store);
      await config.load();
      expect(~config.declareRetries(), 9);
    });

    test('throws when no store is wired', () {
      expect(_TestConfiguration().load,
          throwsConfigException('client_configuration.store.not_configured'));
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

    test('carries forward persisted keys this build does not declare',
        () async {
      final store =
          TomMemoryClientConfigurationStore({'client.fromNewerBuild': 'keep'});
      final config = _TestConfiguration(store: store);
      await config.load();
      config.retries | 9;
      await config.save();
      expect(await store.read(),
          {'client.fromNewerBuild': 'keep', 'client.retries': 9});
    });

    test('throws when no store is wired', () {
      expect(_TestConfiguration().save,
          throwsConfigException('client_configuration.store.not_configured'));
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
      expect(() => config.reset('client.nope'),
          throwsConfigException('client_configuration.key.unknown'));
      expect(() => config.isOverridden('client.nope'),
          throwsConfigException('client_configuration.key.unknown'));
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

    test('a load that changes nothing is silent', () async {
      final config =
          _TestConfiguration(store: TomMemoryClientConfigurationStore());
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

    test('round-trips the override map, creating parent directories',
        () async {
      final store = TomFileClientConfigurationStore(path);
      await store.write({'client.retries': 9, 'client.darkMode': true});
      expect(File(path).existsSync(), isTrue);
      expect(await store.read(), {'client.retries': 9, 'client.darkMode': true});
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
      expect(TomFileClientConfigurationStore(path).read,
          throwsConfigException('client_configuration.store.invalid_content'));
    });

    test('a JSON value that is not an object throws', () async {
      File(path)
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode([1, 2, 3]));
      expect(TomFileClientConfigurationStore(path).read,
          throwsConfigException('client_configuration.store.invalid_content'));
    });

    test('drives a holder end to end', () async {
      final config =
          _TestConfiguration(store: TomFileClientConfigurationStore(path));
      config.serverUrl | 'https://chosen.example';
      await config.save();

      // A second holder over the same file is what the next app start sees.
      final reloaded =
          _TestConfiguration(store: TomFileClientConfigurationStore(path));
      await reloaded.load();
      expect(~reloaded.serverUrl, 'https://chosen.example');
      expect(~reloaded.retries, 3, reason: 'defaults are not persisted');
    });
  });
}
