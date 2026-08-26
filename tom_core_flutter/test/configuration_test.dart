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
import 'support/exception_constructor_mirror.dart';

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

    test('carries forward a key written after this holder loaded', () async {
      // Carry-forward seeds from the store it is about to write, not from the
      // snapshot taken at load(). Otherwise the promise above holds only for
      // keys that were already there when this holder started: a key another
      // writer added in between is not "carried forward", it is deleted.
      final store =
          TomMemoryClientConfigurationStore({'client.fromNewerBuild': 'keep'});
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
      expect(_TestConfiguration().save,
          throwsConfigException('client_configuration.store.not_configured'));
    });
  });

  group('swapping the store', () {
    test('does not carry the previous store\'s keys into the new one',
        () async {
      // Carry-forward protects the keys of *a* store. A holder moved to a
      // different store must not deposit the first store's keys in the second:
      // they describe an install location this holder has been moved away from.
      final oldStore =
          TomMemoryClientConfigurationStore({'client.legacy': 'FROM-OLD-STORE'});
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
      final oldStore =
          TomMemoryClientConfigurationStore({'client.legacy': 'FROM-OLD-STORE'});
      final config = _TestConfiguration(store: oldStore);
      await config.load();

      final newStore =
          TomMemoryClientConfigurationStore({'client.ownKey': 'KEEP-ME'});
      config.store = newStore;
      config.retries | 9;
      await config.save();

      expect(await newStore.read(),
          {'client.ownKey': 'KEEP-ME', 'client.retries': 9});
    });

    test('leaves the previous store untouched', () async {
      final oldStore =
          TomMemoryClientConfigurationStore({'client.legacy': 'FROM-OLD-STORE'});
      final config = _TestConfiguration(store: oldStore);
      await config.load();

      config.store = TomMemoryClientConfigurationStore();
      config.retries | 9;
      await config.save();

      expect(await oldStore.read(), {'client.legacy': 'FROM-OLD-STORE'},
          reason: 'saving to the new store must not write to the old one');
    });

    test('a setting declared after the swap does not see the old override',
        () async {
      // The same stale snapshot reaches a second consumer: a setting declared
      // late is initialised from it. After a swap that snapshot describes a
      // store this holder no longer writes to, so the override it carries
      // belongs to somebody else's install location.
      final config = _LateConfiguration(
          store: TomMemoryClientConfigurationStore({'client.retries': 9}));
      await config.load();

      config.store = TomMemoryClientConfigurationStore();
      expect(~config.declareRetries(), 3,
          reason: 'the new store has no override, so the baseline stands');
    });

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

  group('the two file-store variants present one signature', () {
    // The point of a conditional export is that one name means one thing on
    // every target. When the variants' constructors differ, code that compiles
    // on the platform you are building for fails on the one you are not — and
    // the compiler only says so once someone builds for the second platform,
    // which is the worst moment to find out.
    const io =
        'lib/src/tomclient/configuration/file_configuration_store_io.dart';
    const neutral =
        'lib/src/tomclient/configuration/file_configuration_store_neutral.dart';

    /// Whether [file] declares the store's constructor as `const`.
    bool declaresConstConstructor(String file) => RegExp(
          r'\bconst\s+TomFileClientConfigurationStore\s*\(',
        ).hasMatch(File(file).readAsStringSync());

    test('both variants agree about const', () {
      expect(
        declaresConstConstructor(io),
        declaresConstConstructor(neutral),
        reason: 'a const construction must compile on every target or on none; '
            'the neutral variant cannot be const because it throws from its '
            'body, so the io variant must not be const either',
      );
    });

    test('both variants declare the same public members', () {
      Set<String> publicMembersOf(String file) {
        final source = File(file).readAsStringSync();
        // `(?! )` pins the match to exactly one indent level — a class member.
        // Without it the character class swallows the deeper indentation of a
        // method body and every local variable reads as a member.
        return RegExp(r'^  (?! )(?:final |const )?[\w<>?, ]*\b(\w+)\s*[(;=]',
                multiLine: true)
            .allMatches(source)
            .map((m) => m.group(1)!)
            .where((name) => !name.startsWith('_'))
            .toSet();
      }

      expect(
        publicMembersOf(io),
        publicMembersOf(neutral),
        reason: 'the variants are interchangeable by name, so a member present '
            'on one and absent on the other is a compile error waiting for a '
            'platform switch',
      );
    });
  });

  group('the API summary mirrors the configuration sources', () {
    // `completion/README.md` §6 says the doc/ mirror is to be verified, not
    // trusted. This performs that verification on every run instead of leaving
    // it to whoever remembers: the summary had drifted to omit six public
    // members that the source declares.
    const summaryPath = 'doc/api_reference/api_summary_configuration.md';
    const sources = [
      'lib/src/tomclient/configuration/client_configuration.dart',
      'lib/src/tomclient/configuration/client_configuration_store.dart',
      'lib/src/tomclient/configuration/file_configuration_store_io.dart',
    ];

    /// Every public member name the configuration sources declare.
    ///
    /// Deliberately conservative: it reads members indented exactly one level
    /// inside a class, skips `_private` names, and skips the declaration
    /// keywords, so a name it reports is one a caller can type.
    Set<String> declaredPublicMembers() {
      final names = <String>{};
      for (final path in sources) {
        final source = File(path).readAsStringSync();
        // `(?! )` pins the match to one indent level — a class member. Without
        // it the character class swallows a method body's deeper indentation
        // and every local variable is reported as public API.
        for (final match in RegExp(
          r'^  (?! )(?:@override\s+)?(?:const |final |static |late )*'
          r'[\w<>?, ]*?\b(\w+)\s*(?:\(|=>|;|=[^=])',
          multiLine: true,
        ).allMatches(source)) {
          final name = match.group(1)!;
          if (name.startsWith('_')) continue;
          // A top-level function's body sits at the same indent as a class
          // member, so statement keywords reach here and must be dropped by
          // name. The meta-test below pins that real members still survive.
          if (const {
            'get', 'set', 'operator', //
            'if', 'for', 'while', 'do', 'else', 'switch', 'try', 'catch',
            'return', 'throw', 'assert', 'await', 'yield', 'final', 'var',
          }.contains(name)) {
            continue;
          }
          names.add(name);
        }
      }
      return names;
    }

    test('every public member the sources declare appears in the summary', () {
      final summary = File(summaryPath).readAsStringSync();
      final offenders = <String>[
        for (final name in declaredPublicMembers())
          if (!summary.contains('`$name`') && !summary.contains('$name(')) name,
      ]..sort();

      expect(
        offenders,
        isEmpty,
        reason: 'these public members are declared in the configuration '
            'sources but named nowhere in $summaryPath',
      );
    });

    test('the summary reproduces the file store constructor exactly', () {
      // The one signature the summary previously disagreed with the source
      // about. Pinning it here means the const decision cannot be made in the
      // source and forgotten in the mirror.
      final io = File(
        'lib/src/tomclient/configuration/file_configuration_store_io.dart',
      ).readAsStringSync();
      final declaresConst =
          RegExp(r'\bconst\s+TomFileClientConfigurationStore\s*\(')
              .hasMatch(io);
      final summary = File(summaryPath).readAsStringSync();

      expect(
        summary.contains('const TomFileClientConfigurationStore('),
        declaresConst,
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
        reason: 'these classes declare a public constructor that $summaryPath '
            'never shows the call shape of',
      );
    });

    test('the exception constructor is typed as the kernel types it', () {
      // The constructor-shape test above only checks that a call shape is
      // *shown*; it cannot see a wrong type inside one. This block had drifted
      // to `bool? autoLog`, which no call site can pass — `autoLog` is
      // non-nullable with an inherited default.
      //
      // It also pins `stack` as `StackTrace?` against the recurring correction
      // to `Object?` (tcinc617, tcinc654, tcinc664): `super.stack` resolves
      // against `TomException`'s constructor, which narrows the `Object?` field
      // to `StackTrace?`, not against the field declaration. See
      // `support/exception_constructor_mirror.dart`.
      const exceptionSource =
          'lib/src/tomclient/configuration/client_configuration_store.dart';
      const className = 'TomClientConfigurationException';

      expect(exceptionClassesIn(const [exceptionSource]), contains(className));
      expectSummaryListsForwardedParameters(
        summaryPath: summaryPath,
        sourcePaths: const [exceptionSource],
        classNames: const [className],
      );
      expectSummaryTypesMatchKernel(
        summaryPath: summaryPath,
        classNames: const [className],
      );
    });

    test('the members this guard was written for are among those it reads', () {
      // A coverage test that silently stopped parsing would pass forever. Pin
      // the six members whose omission prompted the guard, so a regex that
      // stops matching fails here rather than going quiet.
      expect(
        declaredPublicMembers(),
        containsAll(<String>[
          'toString',
          'path',
          'read',
          'write',
          'load',
          'save',
          'TomClientConfigurationStore',
          'TomClientConfigurationException',
        ]),
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
      final dependsOnCodeSpecs =
          File('pubspec.yaml').readAsStringSync().contains('tom_code_specs');
      if (dependsOnCodeSpecs) return;

      final offenders = <String>[
        for (final path in artefacts)
          if (File(path).readAsStringSync().contains('Cs*')) path,
      ];
      expect(
        offenders,
        isEmpty,
        reason: 'these artefacts point the reader at the `Cs*` annotations for '
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
        reason: 'the module performs no per-field validation, so the passage '
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
              child: (setting) => Switch(
                value: ~setting,
                onChanged: (next) => setting | next,
              ),
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
        reason: 'the widget observes the setting itself, so writing through '
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
              child: (setting) => Switch(value: ~setting, onChanged: (_) {}),
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
        expect(
          error.parameters?['path'],
          '/wherever/client_config.json',
        );
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
