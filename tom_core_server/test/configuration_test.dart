import 'dart:io';

// Prefixed `paths` rather than the `p` this package's other test files use:
// a dozen tests below name a provider `p`, and a local shadowing the prefix
// reads as a mistake even where it compiles.
import 'package:path/path.dart' as paths;
import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// A concrete configuration that captures the merged values instead of relying
/// on the generated reflection, so [TomBaseServerConfiguration.getDefaultValues]
/// and the source-merge order can be tested without codegen.
class _CapturingConfig extends TomBaseServerConfiguration {
  Map<String, Object?> captured = {};
  _CapturingConfig(super.args);
  @override
  void setValues(Map<String, Object?> values) => captured = values;
}

/// A configuration whose [setValues] overwrites `args`, standing in for the
/// generated reflection assigning a merged key that happens to be spelled
/// `args`.
///
/// Written by hand rather than reflected because the ordering under test is the
/// base constructor's, not the generator's: what matters is that the assignment
/// of the real invocation happens *after* whatever `setValues` did, whoever
/// implemented it.
class _ArgsOverwritingConfig extends TomBaseServerConfiguration {
  _ArgsOverwritingConfig(super.args);
  @override
  void setValues(Map<String, Object?> values) => this.args = ['fromConfigKey'];
}

/// Installs a fresh provider built from [resources] as the active source.
void _install(Map<String, dynamic> resources) {
  TomServerConfigResourceProvider.setServerConfigProvider(
    TomServerConfigResourceProvider.from(resources),
  );
}

void main() {
  group('TomServerConfigResourceProvider', () {
    test('exists/get resolve a top-level key', () {
      final p = TomServerConfigResourceProvider.from({'name': 'svc'});
      expect(p.exists('name'), isTrue);
      expect(p.get('name'), 'svc');
    });

    test('exists/get resolve a dotted path into the tree', () {
      final p = TomServerConfigResourceProvider.from({
        'server': {'port': 8080},
      });
      expect(p.exists('server.port'), isTrue);
      expect(p.get('server.port'), 8080);
    });

    test('exists is false for an unknown key', () {
      final p = TomServerConfigResourceProvider.from({'a': 1});
      expect(p.exists('b'), isFalse);
    });

    test('get falls back to the key string for an unknown key', () {
      final p = TomServerConfigResourceProvider.from({'a': 1});
      expect(p.get('unknown'), 'unknown');
    });

    test('setServerConfigProvider installs the active provider', () {
      final p = TomServerConfigResourceProvider.from({'x': 1});
      TomServerConfigResourceProvider.setServerConfigProvider(p);
      expect(TomServerConfigResourceProvider.getServerConfig(), same(p));
    });

    test('.load builds resources by invoking the supplied loader', () {
      var invocations = 0;
      final p = TomServerConfigResourceProvider.load(() {
        invocations++;
        return {'from': 'loader'};
      });
      expect(invocations, 1); // the loader runs eagerly in the constructor
      expect(p.get('from'), 'loader');
    });

    test(
      'the default constructor populates resources from the static loader',
      () {
        // The static loader feeds any provider created with the default
        // constructor (including the lazy one made by getServerConfig). Null it
        // again so it cannot leak into other tests' providers.
        addTearDown(() => TomServerConfigResourceProvider.loader = null);
        TomServerConfigResourceProvider.loader = () => {'seeded': 'yes'};
        final p = TomServerConfigResourceProvider();
        expect(p.get('seeded'), 'yes');
      },
    );

    test(
      'the default constructor yields empty resources when no loader is set',
      () {
        TomServerConfigResourceProvider.loader = null;
        final p = TomServerConfigResourceProvider();
        expect(p.resources, isEmpty);
      },
    );

    test('get returns the whole subtree map for a branch key', () {
      final p = TomServerConfigResourceProvider.from({
        'server': {'port': 8080, 'host': 'localhost'},
      });
      final subtree = p.get('server') as Map;
      expect(subtree['port'], 8080);
      expect(subtree['host'], 'localhost');
    });

    group('explicitly null properties', () {
      test('a null dotted property exists and reads as null', () {
        final p = TomServerConfigResourceProvider.from({
          'server': {'replica': null},
        });
        expect(p.exists('server.replica'), isTrue);
        expect(p.get('server.replica'), isNull);
      });

      test('a null top-level property exists and reads as null', () {
        final p = TomServerConfigResourceProvider.from({'cleared': null});
        expect(p.exists('cleared'), isTrue);
        expect(p.get('cleared'), isNull);
      });

      test('a null property is not confused with an unknown one', () {
        // The unknown key keeps the documented key-string fallback; the null
        // one does not, because it resolved.
        final p = TomServerConfigResourceProvider.from({'cleared': null});
        expect(p.exists('unknown'), isFalse);
        expect(p.get('unknown'), 'unknown');
        expect(p.get('cleared'), isNull);
      });
    });
  });

  group('TomConfig resolution', () {
    test('reads an existing value and casts it to T', () {
      _install({
        'server': {'port': 8080},
      });
      expect(TomIntConfig('server.port').get(), 8080);
    });

    test('uses the default when the key is absent', () {
      _install({});
      expect(TomIntConfig.withDefault('missing', 42).get(), 42);
    });

    test('prefers the configured value over the default', () {
      _install({'n': 7});
      expect(TomIntConfig.withDefault('n', 42).get(), 7);
    });

    test('the ~ operator returns the resolved value', () {
      _install({'flag': true});
      expect(~TomBoolConfig('flag'), isTrue);
    });

    test('throws for an obligatory key with no default', () {
      _install({});
      expect(() => TomStringConfig('obligatory'), throwsA(anything));
    });

    test('throws an Exception on a type mismatch', () {
      _install({'port': 'not-an-int'});
      expect(() => TomIntConfig('port'), throwsException);
    });

    test('the typed subclasses resolve their type', () {
      _install({'s': 'hi', 'i': 3, 'd': 1.5, 'b': false});
      expect(TomStringConfig('s').get(), 'hi');
      expect(TomIntConfig('i').get(), 3);
      expect(TomDoubleConfig('d').get(), 1.5);
      expect(TomBoolConfig('b').get(), isFalse);
    });

    // A configuration file cannot say "double". `rate: 2` in YAML and
    // `"rate": 2` in JSON both decode to an int, and the reflected path already
    // widens that onto a declared double field (cmdline_test.dart, "fills a
    // double field from a whole number"). These four pin the same rule here, so
    // one file cannot fill a double field and fail the matching lookup.
    test('a whole number resolves as a double', () {
      _install({'rate': 2});
      final value = TomDoubleConfig('rate').get();
      // isA matters: `expect(2, 2.0)` passes on value alone, because Dart's
      // `==` says 2 == 2.0. The claim here is about the type.
      expect(value, isA<double>());
      expect(value, 2.0);
    });

    test('a whole number resolves as a nullable double', () {
      _install({'rate': 2});
      expect(TomConfig<double?>('rate').get(), isA<double>());
    });

    test('a decimal is still refused for an int', () {
      // The converse is deliberately absent, for the reason the reflector gives
      // for not having it either: narrowing needs a rounding policy, and
      // truncating 2.5 silently loses what the operator wrote.
      _install({'port': 2.5});
      expect(() => TomIntConfig('port'), throwsException);
    });

    test('widening does not intercept a type the cast already accepts', () {
      // `2 as num` succeeds, so the int must survive as an int. This is what
      // makes the widening a fallback after a failed cast rather than a check
      // in front of it -- a pre-check on "does T accept a double" would convert
      // this one too, and silently change the runtime type of every num.
      _install({'n': 2});
      expect(TomConfig<num>('n').get(), isA<int>());
    });

    test('the value is captured at construction, not on read', () {
      _install({'v': 1});
      final config = TomIntConfig('v');
      _install({'v': 2}); // swap the provider after construction
      expect(config.get(), 1); // still the originally-resolved value
    });

    test('a nullable null default resolves to null, not a throw', () {
      _install({});
      // withDefault(key, null) over a nullable T must honour the supplied null
      // default rather than treating it as "no default" and throwing.
      expect(TomConfig<String?>.withDefault('absent', null).get(), isNull);
    });

    test('a non-null default still wins over an absent key', () {
      _install({});
      expect(
        TomConfig<String?>.withDefault('absent', 'fallback').get(),
        'fallback',
      );
    });

    test('an explicitly null value reaches a nullable T', () {
      _install({
        'server': {'replica': null},
      });
      expect(TomConfig<String?>('server.replica').get(), isNull);
    });

    test('an explicitly null value does not fall back to the default', () {
      // Defaults cover an *absent* key. A key the operator deliberately set to
      // null is present, so substituting the default would discard exactly the
      // setting they wrote -- it throws instead, naming the key.
      _install({'port': null});
      expect(() => TomIntConfig.withDefault('port', 8080), throwsException);
    });

    test('an explicitly null value beats a non-null default', () {
      // The case above shows a *non-nullable* T refusing to substitute the
      // default. This is the one a deployment actually writes: `smtpHost:` in
      // YAML, over a setting that has a default, on a nullable field. It must
      // resolve to null -- clearing the setting is the whole point of writing
      // the key -- rather than quietly handing back the default.
      _install({'smtpHost': null});
      expect(
        TomConfig<String?>.withDefault('smtpHost', 'mail.example.com').get(),
        isNull,
      );
    });
  });

  group('TomBaseServerConfiguration.getDefaultValues', () {
    // The resource tree is the base of the four-layer merge, and the only layer
    // that answers when nothing was passed -- so a setting that appears in a
    // running server without being written on the command line, in the
    // environment or in a `.env` file came from here. The documented layering
    // (doc/cmdline.md, doc/configuration.md) rests on this, so it is pinned on
    // its own rather than as a side assertion of an override test.
    test('a resource value no other source supplies reaches the config', () {
      _install({'only.in.resources': 'fromResource'});
      final config = _CapturingConfig([]);
      expect(config.captured['only.in.resources'], 'fromResource');
    });

    test('command-line args override configuration resources', () {
      _install({'override.me': 'fromResource', 'kept': 'resource'});
      final config = _CapturingConfig(['override.me=fromArgs']);
      expect(config.captured['override.me'], 'fromArgs');
      expect(config.captured['kept'], 'resource');
    });

    // The merge keys on the argument text before the first `=`, dashes
    // included, so the conventional `--port=9000` style names the key
    // `--port` -- which no Dart field can be called, and which the reflected
    // `setValues` therefore drops. The undashed form is the one that reaches a
    // field. Both halves are asserted here rather than only the working one,
    // because the failure is silent: nothing reports a key that bound nothing,
    // so a snippet claiming `--port=9000` sets `port` reads as plausible until
    // it is run. `doc/cmdline.md` states the same limitation for
    // `fillFromArgs`; this pins it on the configuration merge, which is the
    // path a server actually starts through.
    test(
      'a dashed argument merges under the dashed key, not the field name',
      () {
        _install({});
        final config = _CapturingConfig(['--port=9000']);
        expect(config.captured['--port'], 9000);
        expect(config.captured.containsKey('port'), isFalse);
      },
    );

    test('an argument named as the field is named merges under that name', () {
      _install({});
      final config = _CapturingConfig(['port=9000']);
      expect(config.captured['port'], 9000);
      expect(config.captured.containsKey('--port'), isFalse);
    });

    test('the OS environment is merged in', () {
      _install({});
      final config = _CapturingConfig([]);
      // PATH is present on every supported platform's environment.
      expect(config.captured.containsKey('PATH'), isTrue);
    });

    test(
      'constructing a configuration leaves the provider resources unchanged',
      () {
        _install({'kept': 'resource'});
        final provider = TomServerConfigResourceProvider.getServerConfig();
        final before = provider.resources.keys.toSet();
        _CapturingConfig(
          [],
        ); // merges env/.env/args into a copy, not the provider
        // The OS environment (PATH et al.) must not have leaked into the provider.
        expect(provider.resources.keys.toSet(), before);
        expect(provider.resources.containsKey('PATH'), isFalse);
      },
    );

    test('a nested provider subtree is not mutated by construction', () {
      _install({
        'server': {'port': 8080},
      });
      final provider = TomServerConfigResourceProvider.getServerConfig();
      _CapturingConfig(['server.host=example']);
      // The deep copy means the provider's nested map keeps only its own keys,
      // regardless of how overrides are shaped.
      expect((provider.resources['server'] as Map).keys.toSet(), {'port'});
    });

    test('the captured values are a copy, mutating them leaves the provider'
        ' untouched', () {
      _install({
        'server': {'port': 8080},
      });
      final provider = TomServerConfigResourceProvider.getServerConfig();
      final config = _CapturingConfig([]);
      (config.captured['server'] as Map)['port'] = 9999;
      expect((provider.resources['server'] as Map)['port'], 8080);
    });

    test(
      '.env overlays between env and args (resources < env < .env < args)',
      () async {
        final prevCwd = Directory.current;
        final dir = await Directory.systemTemp.createTemp('tom_cfg_env');
        try {
          await File('${dir.path}/.env').writeAsString(
            'r_key=fromEnvFile\nPATH=SENTINEL_PATH\na_key=fromEnvFile\n',
          );
          Directory.current = dir;
          _install({'r_key': 'fromResource'});
          final config = _CapturingConfig(['a_key=fromArgs']);
          expect(
            config.captured['r_key'],
            'fromEnvFile',
          ); // .env beats resources
          expect(config.captured['PATH'], 'SENTINEL_PATH'); // .env beats env
          expect(config.captured['a_key'], 'fromArgs'); // args beat .env
        } finally {
          Directory.current = prevCwd;
          if (await dir.exists()) await dir.delete(recursive: true);
        }
      },
    );

    test('the default bind host is empty (anyIPv4-eligible)', () {
      _install({});
      // An empty host routes TomServer.start to InternetAddress.anyIPv4; the
      // previous "t"/"0" defaults were invalid addresses.
      expect(_CapturingConfig([]).host, '');
    });
  });

  // `args` is the one field on the configuration base that is *derived* rather
  // than configured: every other field answers "what was I told", this one
  // answers "how was I invoked". The distinction is invisible in the class --
  // it is declared beside the rest and is reflected like the rest -- so it is
  // pinned here instead.
  group('TomBaseServerConfiguration.args', () {
    test('a constructed configuration reads back the arguments it was given', () {
      _install({});
      // The claim both documents make about this field. It went unasserted, and
      // the field went unassigned, for as long as both have existed: the
      // constructor forwarded its parameter to getDefaultValues and dropped it,
      // so every configuration ever built reported an empty command line.
      expect(_CapturingConfig(['--port=9000', 'appId=svc']).args, [
        '--port=9000',
        'appId=svc',
      ]);
    });

    test('the invocation survives a configuration key of the same name', () {
      _install({});
      // `args` is a field name, so the generated setValues will assign it from
      // a merged key spelled `args` -- from a YAML resource, the environment, a
      // `.env` line or an `args=...` argument. That value is a different thing
      // from the invocation, and the invocation is the one the documented
      // meaning promises, so the constructor assigns last. Reflection is not
      // needed to state that: this override does what a reflected setValues
      // would do with such a key.
      expect(_ArgsOverwritingConfig(['real']).args, ['real']);
    });

    test('it is not read back out of the merged map', () {
      _install({});
      // The corollary of the test above, from the other side: the merge is
      // still free to carry an `args` key and getDefaultValues still reports
      // it. The field simply stops being where that key lands.
      final config = _CapturingConfig(['args=fromCommandLine']);
      expect(config.captured['args'], 'fromCommandLine');
      expect(config.args, ['args=fromCommandLine']);
    });
  });

  // The merged map and the provider tree are two different stores, and the
  // module reads each of them from a different type: the merge feeds
  // `setValues`, so it lands on the configuration object's *fields*, while
  // `TomConfig` resolves against the process-wide provider and nothing else.
  //
  // That separation is deliberate -- it is the bug-62 fix, which stopped
  // building a configuration from injecting the environment into the
  // process-wide provider -- but it is invisible at a call site, because both
  // halves are spelled as an ordinary property read. So the two are pinned
  // against each other here rather than each on its own: the assertions that
  // matter are the ones about the *boundary*.
  group('the environment and the command line as TomConfig sees them', () {
    test('an environment variable is not visible to TomConfig', () {
      _install({});
      // PATH is present in Platform.environment on every supported platform,
      // and getDefaultValues would merge it. TomConfig never consults that
      // merge, so the key is simply absent and the obligatory lookup throws.
      expect(() => TomStringConfig('PATH'), throwsA(anything));
    });

    test('a default silently wins over the environment variable it shadows', () {
      _install({});
      // The same absence as above, but with a default there is nothing to
      // throw: the declared fallback is returned as though the environment had
      // said nothing. This is the shape that makes the boundary worth
      // documenting -- the obligatory form at least fails loudly.
      expect(TomStringConfig.withDefault('PATH', 'fallback').get(), 'fallback');
    });

    test('constructing a configuration does not publish its merged values', () {
      _install({});
      _CapturingConfig(['appId=svc']);
      // The argument reached the configuration object -- asserted by the
      // getDefaultValues group above -- but the provider is untouched, so a
      // TomConfig declared afterwards still cannot see it.
      expect(() => TomStringConfig('appId'), throwsA(anything));
      expect(
        TomServerConfigResourceProvider.getServerConfig().exists('appId'),
        isFalse,
      );
    });

    test('installing the merged map as the provider is what makes both '
        'sources readable', () {
      _install({});
      // The one line that joins the two stores. It is the caller's to write:
      // the module never does it, which is why every claim that a TomConfig
      // lookup sees an environment or command-line value needs it first.
      TomServerConfigResourceProvider.setServerConfigProvider(
        TomServerConfigResourceProvider.from(
          TomBaseServerConfiguration.getDefaultValues([
            'DB_PORT=3307',
            '--verbose',
            'accountNumber="00420"',
          ]).cast<String, dynamic>(),
        ),
      );
      // The environment, now reachable.
      expect(TomStringConfig('PATH').get(), isNotEmpty);
      // An all-digit argument arrives already typed, so the strict int cast
      // holds -- the conversion happens on the way into the map, not on read.
      expect(TomIntConfig('DB_PORT').get(), 3307);
      // A bare flag is stored as the boolean true under its own dashed key,
      // which is the one case where the dashed spelling is useful: it is read
      // back as a key rather than bound to a field of that name.
      expect(~TomBoolConfig('--verbose'), isTrue);
      // Quoting is how a value that looks numeric stays textual; the quotes
      // are stripped as a pair, so the leading zeros survive.
      expect(~TomStringConfig('accountNumber'), '00420');
    });
  });

  group('TomYaml', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('tom_config_test');
    });
    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('loads a YAML file into a nested map', () async {
      final f = File('${dir.path}/c.yaml');
      await f.writeAsString('database:\n  host: localhost\n  port: 3306\n');
      final map = TomYaml.loadYamlFile(f.path);
      final db = map['database'] as Map;
      expect(db['host'], 'localhost');
      expect(db['port'], 3306);
    });

    test('substitutes a missing variable with its :default', () async {
      final f = File('${dir.path}/c.yaml');
      await f.writeAsString('host: \${TOM_CFG_TEST_HOST:fallback}\n');
      final map = TomYaml.loadYamlFile(f.path);
      expect(map['host'], 'fallback');
    });

    test('substitutes a real environment variable', () async {
      // PATH is set in every supported platform's environment; the substitution
      // must resolve ${PATH} to its actual value, not the literal placeholder.
      final path = Platform.environment['PATH'];
      expect(path, isNotNull, reason: 'PATH must be set for this test');
      final f = File('${dir.path}/c.yaml');
      await f.writeAsString('p: \${PATH}\n');
      final map = TomYaml.loadYamlFile(f.path);
      expect(map['p'], path);
    });

    test('a substituted value is text, where a literal one is typed', () async {
      // The one place a configuration value reaches TomConfig untyped. A YAML
      // scalar is typed by the YAML parser, but substitution runs afterwards
      // and writes the expansion back as text -- so the same number is an int
      // when written literally and a String when written as a placeholder,
      // even though the placeholder's own default supplies the same digits.
      // TomConfig casts rather than parses, so the second form throws.
      final f = File('${dir.path}/c.yaml');
      await f.writeAsString(
        'literal: 3306\n'
        'substituted: \${TOM_CFG_TEST_PORT:3306}\n',
      );
      final map = TomYaml.loadYamlFile(f.path);
      expect(map['literal'], isA<int>());
      expect(map['substituted'], isA<String>());
      expect(map['substituted'], '3306');

      _install(map);
      expect(TomIntConfig('literal').get(), 3306);
      expect(
        () => TomIntConfig('substituted').get(),
        throwsA(isA<Exception>()),
      );
      // It is readable as what it actually is.
      expect(TomStringConfig('substituted').get(), '3306');
    });

    test('mergeInYamlFile overlays a file onto an existing map', () async {
      final f = File('${dir.path}/c.yaml');
      await f.writeAsString('added: yes\n');
      final existing = <String, Object?>{'existing': 1};
      TomYaml.mergeInYamlFile(existing, f.path);
      expect(existing['existing'], 1);
      expect(existing['added'], 'yes');
    });
  });

  group('The example runs green', () {
    final examplePath = paths.join(
      'example',
      'configuration',
      'configuration_example.dart',
    );

    test('under exactly the command its header documents', () async {
      // The example is this module's worked demonstration and the source of
      // the completion document's snippets, so it drifts silently unless
      // something runs it. Run it the way a reader would — plain `dart run`,
      // no extra flags — and require the exit code its own checks produce.
      final result = await Process.run(Platform.resolvedExecutable, [
        'run',
        examplePath,
      ]);
      expect(
        result.exitCode,
        0,
        reason: 'example failed: ${result.stdout}${result.stderr}',
      );
      // A crash before the last step would also exit 0 if it were swallowed,
      // so pin that every numbered step actually reported. The count is read
      // off the example rather than written here: a literal only matches the
      // file on the day it is written, and a stale one stops covering the
      // steps added since — silently, which is the failure this test exists
      // to prevent.
      final declared = RegExp(r"print\('(\d+)\. ")
          .allMatches(File(examplePath).readAsStringSync())
          .map((m) => int.parse(m.group(1)!))
          .toList();
      expect(declared, isNotEmpty, reason: 'no numbered step found at all');
      expect(
        declared,
        List.generate(declared.length, (i) => i + 1),
        reason: "the example's steps must be numbered 1..n without a gap",
      );
      for (final step in declared) {
        expect(result.stdout, contains('$step. '));
      }
    });

    test('with its expectations checked rather than asserted', () async {
      // The test above cannot see the difference on its own: an example that
      // checks nothing exits 0 too. `dart run` leaves assertions disabled —
      // that is what `--enable-asserts` is for — so an `assert` in the example
      // is compiled out under the very command the test above uses, and the
      // run stays green with every expectation violated. This example was
      // written that way. It now states its expectations through a throwing
      // helper, and this guards the regression of quietly reverting them.
      final source = File(examplePath).readAsStringSync();
      expect(
        source,
        isNot(contains('assert(')),
        reason: 'an assert in the example does not run under `dart run`',
      );
      expect(source, contains('void check(bool ok, String expectation)'));
    });

    test('demonstrating that TomConfig does not see the environment', () {
      // The completion document's "Reading a property the environment or the
      // command line supplied" section once showed three `TomConfig` lookups
      // that could never resolve, because nothing had installed the merged map
      // as the provider. The section is now backed by the example's last two
      // steps, so this pins that the backing exists: without them the prose is
      // unsupported again and the false claim can quietly return.
      final source = File(examplePath).readAsStringSync();
      expect(
        source,
        contains('TomBaseServerConfiguration.getDefaultValues('),
        reason: 'the example must show the merge that feeds setValues',
      );
      expect(
        source,
        contains('the environment is not visible to TomConfig'),
        reason: 'the example must show the lookup that fails before install',
      );
      expect(
        source,
        contains(
          'the environment resolves once the merged map is the '
          'provider',
        ),
        reason: 'the example must show the install that makes it resolve',
      );
    });
  });
}
