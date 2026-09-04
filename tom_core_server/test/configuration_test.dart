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

/// A configuration that names itself in its own constructor body, the way every
/// server in this workspace does.
///
/// Its [setValues] deliberately assigns nothing, so the only writer of [appId]
/// is the subclass constructor — which runs *after* the base constructor. That
/// ordering is the whole point: it is what a global published from inside
/// `setValues` cannot see.
class _LateAppIdConfig extends TomBaseServerConfiguration {
  _LateAppIdConfig(super.args) {
    appId = 'fromConstructor';
  }
  @override
  void setValues(Map<String, Object?> values) {}
}

/// A configuration whose [setValues] assigns [appId] from the merged values,
/// standing in for what the generated reflection does with an `appId` key.
class _MergedAppIdConfig extends TomBaseServerConfiguration {
  _MergedAppIdConfig(super.args);
  @override
  void setValues(Map<String, Object?> values) =>
      appId = (values['appId'] as String?) ?? '';
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

    // A dotted key has two possible meanings in one flat map, and the provider
    // answers both: `server.port` may be a path into a nested tree, or the
    // literal spelling of a top-level key. YAML lets an operator write either,
    // and nothing in the file says which was meant -- so the resolution order
    // between them is a rule a deployment can hit by writing its configuration
    // the other way round.
    group('a flat dotted key', () {
      test('resolves as though it were a path', () {
        // `server.port: 8080` written flat, rather than nested under `server:`.
        // The tree walk fails on it -- there is no `server` branch to descend
        // -- and the top-level lookup behind it is what answers. Both halves
        // of the provider's fallback are asserted, and so is the TomConfig on
        // top, because that is where a deployment meets this.
        final p = TomServerConfigResourceProvider.from({'server.port': 8080});
        expect(p.exists('server.port'), isTrue);
        expect(p.get('server.port'), 8080);
        _install({'server.port': 8080});
        expect(TomIntConfig('server.port').get(), 8080);
      });

      test('is shadowed by a real path of the same spelling', () {
        // With both present the tree walk succeeds, so the nested value wins
        // and the flat key becomes unreachable -- not merged, not reported,
        // just never consulted. This is the case worth pinning of the two: an
        // operator who adds a nested `server:` block to a file that already
        // carried a flat `server.port` silently loses the flat one, and no
        // layer of the module says so.
        final p = TomServerConfigResourceProvider.from({
          'server': {'port': 8080},
          'server.port': 9999,
        });
        expect(p.get('server.port'), 8080);
      });
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
      // A bare String, not an Exception -- so `on Exception catch` misses it
      // and only a bare `catch` sees it. Asserted by type rather than with
      // `anything`, because that is the part doc/configuration.md warns about
      // under *Not Yet Implemented*: an assertion that accepts either shape
      // would let the warning outlive the behaviour it describes.
      _install({});
      expect(() => TomStringConfig('obligatory'), throwsA(isA<String>()));
    });

    test('throws an Exception on a type mismatch', () {
      _install({'port': 'not-an-int'});
      expect(() => TomIntConfig('port'), throwsException);
    });

    test('the cast failure carries the TypeError it caught', () {
      // A failed `as` throws a TypeError, which is an Error and not an
      // Exception -- so the catch cannot be `on Exception` and the caught
      // object cannot simply be rethrown to a caller that expects one. It is
      // converted, and the conversion is where a cause is easiest to drop.
      _install({'port': 'not-an-int'});
      Object? thrown;
      try {
        TomIntConfig('port');
      } catch (e) {
        thrown = e;
      }
      expect(thrown, isA<TomConfigurationException>());
      final ex = thrown as TomConfigurationException;
      expect(ex.rootException, isA<TypeError>());
      expect(ex.stack, isA<StackTrace>());
      expect(ex.key, 'configuration.tom_config.property_type_mismatch');
    });

    test('the cast failure reports key, type and value as data', () {
      // The class dartdoc promises these three separately "so a handler can
      // report them without parsing the message". A handler that has to
      // recover the key by scanning the sentence is coupled to its wording,
      // which is the coupling the parameters map exists to prevent -- so the
      // promise needs an assertion of its own rather than being taken as
      // implied by the message test above.
      _install({'port': 'not-an-int'});
      Object? thrown;
      try {
        TomIntConfig('port');
      } catch (e) {
        thrown = e;
      }
      expect((thrown as TomConfigurationException).parameters, {
        'key': 'port',
        'type': 'int',
        'value': 'not-an-int',
      });
    });

    test('the cast failure keeps the subtype relation that failed', () {
      // Not a restatement of the test above: this is *why* the cause is worth
      // keeping. A YAML `hosts: [a, b]` decodes as List<dynamic>, so asking for
      // List<String> fails on the element type -- and the replacement message
      // reports "with value [a, b]", which is exactly what the operator wrote
      // and looks perfectly valid. Only the TypeError names the real problem.
      // Asserted on the chained cause rather than on the message, so the
      // diagnostic has to still be *reachable*, not merely once have been
      // interpolated into a string.
      _install({
        'hosts': <dynamic>['a', 'b'],
      });
      Object? thrown;
      try {
        TomConfig<List<String>>('hosts');
      } catch (e) {
        thrown = e;
      }
      final cause = (thrown as TomConfigurationException).rootException;
      expect(cause.toString(), contains('List<dynamic>'));
      expect(cause.toString(), contains('List<String>'));
      // And the message the operator sees still names the key and the value,
      // so chaining adds to the report rather than replacing it.
      expect(thrown.toString(), contains('hosts'));
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

  // `tomAppId` is the process-wide answer to "which application is this", and
  // for as long as it existed the library neither produced nor consumed one:
  // five servers across this workspace each published it by hand and nothing
  // ever read it. The hand-written line was also wrong in all five -- it sat in
  // a `setValues` override, which the base constructor calls *before* the
  // subclass constructor body that names the application, so every one of them
  // published the empty string. These pin the wiring that replaced it.
  group('tomAppId', () {
    test('reports an app id resolved from the merged configuration', () {
      _install({});
      _MergedAppIdConfig(['appId=fromCommandLine']);
      expect(tomAppId, 'fromCommandLine');
    });

    test('reports an app id the subclass constructor sets after setValues', () {
      // The case the hand-written line got wrong. `appId` is assigned after the
      // base constructor has finished, so anything that samples it *during*
      // construction reads the wrong value -- which is why tomAppId resolves
      // the field on each read instead of holding a copy taken at some instant.
      _install({});
      _LateAppIdConfig([]);
      expect(tomAppId, 'fromConstructor');
    });

    test('follows the configuration built most recently', () {
      // A server builds one configuration per isolate, and globals are
      // per-isolate, so in a running process "most recent" and "the only one"
      // coincide. Stated as a test because it is the rule that decides what a
      // second configuration means, and a test doing so twice is the only place
      // the question comes up.
      _install({});
      _MergedAppIdConfig(['appId=first']);
      expect(tomAppId, 'first');
      _MergedAppIdConfig(['appId=second']);
      expect(tomAppId, 'second');
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
            'quantity="420"',
            'accountNumber=00420',
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
      // Quoting is how a value that would otherwise convert stays textual; the
      // quotes are stripped as a pair, so the digits arrive without them.
      expect(~TomStringConfig('quantity'), '420');
      // Padding needs no quotes to survive: a digit run with leading zeros is
      // an identifier, so the converter never turns it into a number in the
      // first place.
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

    test('an explicit environment replaces the process environment', () async {
      // The parameter exists so a boot can expand its YAML from something the
      // process environment does not contain -- a `.env` file, in the case it
      // was added for. PATH is used as the probe because it is set on every
      // supported platform, so shadowing it proves the passed map *replaces*
      // the process environment rather than layering under it: if the two were
      // merged with the process winning, the assertion below would see the real
      // PATH. Nothing here reads a `.env`; assembling one is the caller's job
      // (TomEnvFile.resolveEnvironment), and this is only the seam it hands to.
      final f = File('${dir.path}/c.yaml');
      await f.writeAsString(
        'p: \${PATH}\n'
        'host: \${TOM_CFG_TEST_HOST:fallback}\n',
      );
      final map = TomYaml.loadYamlFile(
        f.path,
        environment: <String, String>{
          'PATH': '/from/the/passed/map',
          'TOM_CFG_TEST_HOST': 'explicit.host',
        },
      );
      expect(map['p'], '/from/the/passed/map');
      // And a variable the passed map *does* supply beats the `:default`,
      // exactly as a process-environment one would.
      expect(map['host'], 'explicit.host');
    });

    test('mergeInYamlFile passes the environment through', () async {
      // mergeInYamlFile is one line over loadYamlFile, and that line is the
      // whole risk: forgetting to forward the argument would leave every
      // overlay expanding from the process environment while the base file
      // expanded from the caller's -- a split that no other assertion here
      // would notice, because both files parse and merge fine either way.
      final f = File('${dir.path}/o.yaml');
      await f.writeAsString('host: \${TOM_CFG_TEST_HOST:fallback}\n');
      final target = <String, Object?>{};
      TomYaml.mergeInYamlFile(
        target,
        f.path,
        environment: <String, String>{'TOM_CFG_TEST_HOST': 'overlaid.host'},
      );
      expect(target['host'], 'overlaid.host');
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

    test('the overlaid file wins the keys the two files share', () async {
      // The test above uses disjoint keys, so it shows the overlay *arriving*
      // and says nothing about what happens where two files disagree -- which
      // is the only question layering asks. Both directions are asserted here
      // because "one-sided" is a claim about each: the file overwrites what it
      // names, and leaves what it does not.
      final f = File('${dir.path}/o.yaml');
      await f.writeAsString('shared: fromFile\nonlyInFile: yes\n');
      final target = <String, Object?>{
        'shared': 'fromTarget',
        'onlyInTarget': 1,
      };
      TomYaml.mergeInYamlFile(target, f.path);
      expect(target['shared'], 'fromFile');
      expect(target['onlyInTarget'], 1);
      expect(target['onlyInFile'], 'yes');
    });

    test('an overlaid subtree merges into the existing one', () async {
      // The collision rule above is per *leaf*, not per branch: a file that
      // names one key of an existing subtree replaces that key and leaves the
      // subtree's other keys standing. This is what makes a layered file a
      // patch rather than a wholesale substitution -- an environment overlay
      // can set `db.host` alone without having to restate `db.port` -- and it
      // is the behaviour that would quietly invert if the merge ever stopped
      // recursing, wiping every setting the overlay did not mention.
      final f = File('${dir.path}/n.yaml');
      await f.writeAsString('db:\n  host: fromFile\n');
      final target = <String, Object?>{
        'db': {'host': 'fromTarget', 'port': 3306},
      };
      TomYaml.mergeInYamlFile(target, f.path);
      expect((target['db'] as Map)['host'], 'fromFile');
      expect((target['db'] as Map)['port'], 3306);
    });

    test('the two entry points load a file identically', () async {
      // The one invariant the two methods have to share and nothing used to
      // check: whatever loadYamlFile does to a file on the way in --
      // normalise, substitute, type -- mergeInYamlFile must do the same, or
      // the same configuration file means two things depending on which
      // method the caller reached for. Asserted differentially rather than by
      // restating the expected tree, because the claim is that the two agree,
      // not that either produces some particular shape; a literal expectation
      // would have to be updated twice and could drift to match one side.
      final f = File('${dir.path}/c.yaml');
      await f.writeAsString(
        'database:\n'
        '  host: \${TOM_CFG_TEST_HOST:localhost}\n'
        '  port: 3306\n'
        '  debug: true\n'
        'path: \${PATH}\n',
      );

      final loaded = TomYaml.loadYamlFile(f.path);
      final merged = <String, Object?>{};
      TomYaml.mergeInYamlFile(merged, f.path);

      expect(merged, loaded);
      // Not vacuous: the file really did carry a substitution and a typed
      // scalar through both paths.
      expect((merged['database'] as Map)['host'], 'localhost');
      expect((merged['database'] as Map)['port'], isA<int>());
      expect(merged['path'], Platform.environment['PATH']);
    });

    test('both entry points throw when the file is absent', () {
      // The sibling loader in the same configuration pipeline does the
      // opposite -- TomEnvFile.read returns an empty map for an absent file,
      // and its dartdoc says so -- so a reader who has met one has a
      // reasonable and wrong expectation of the other. Both directions are
      // pinned here, in one test, because it is the *contrast* that has to
      // hold: if either side changes, this asymmetry stops being what
      // doc/configuration.md describes.
      final missing = '${dir.path}/absent.yaml';
      expect(File(missing).existsSync(), isFalse);

      expect(
        () => TomYaml.loadYamlFile(missing),
        throwsA(isA<PathNotFoundException>()),
      );
      expect(
        () => TomYaml.mergeInYamlFile(<String, Object?>{}, missing),
        throwsA(isA<PathNotFoundException>()),
      );
      expect(TomEnvFile.read(missing), isEmpty);
    });

    test('a failed merge leaves the target map untouched', () {
      // mergeInYamlFile reads before it merges, so an absent file cannot
      // half-apply an overlay. That is what makes `try`/`catch` a usable
      // remedy for an optional overlay: the caller can carry on with the map
      // it already had. Worth pinning separately from the throw itself --
      // were the read ever moved after a partial merge, the throw would still
      // be there and the remedy would silently stop being sound.
      final existing = <String, Object?>{'existing': 1};
      expect(
        () => TomYaml.mergeInYamlFile(existing, '${dir.path}/absent.yaml'),
        throwsA(isA<PathNotFoundException>()),
      );
      expect(existing, {'existing': 1});
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
      expect(
        source,
        contains("import '../_support/check.dart'"),
        reason: 'the example states its expectations through the shared helper',
      );
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

    test('exercising every way a tree gets installed', () {
      // The exit-code test above cannot see a deleted step: the numbering
      // closes over the gap and eleven steps pass exactly as twelve did. So
      // the entry points themselves are named here. All three installs matter
      // because they are not interchangeable -- `loader` is reachable only
      // before a provider exists, `.load` only after -- and the completion
      // document now points at these steps for that rule rather than
      // asserting it in prose, which is the coupling this guards.
      final source = File(examplePath).readAsStringSync();
      expect(
        source,
        contains('TomServerConfigResourceProvider.loader = '),
        reason: 'the example must show the lazy loader hook',
      );
      expect(
        source,
        contains('TomServerConfigResourceProvider.load('),
        reason: 'the example must show the .load constructor',
      );
      expect(
        source,
        contains('TomYaml.mergeInYamlFile('),
        reason: 'the example must show a layered overlay',
      );
      expect(
        source,
        contains('on PathNotFoundException'),
        reason: 'the example must show that an absent overlay throws',
      );
    });
  });

  // Each limitation listed under *Not Yet Implemented* in doc/configuration.md,
  // pinned so the section cannot go on warning about a behaviour that has since
  // been fixed -- a stale warning costs a reader the same working-around as a
  // missing one. Four of the eight are pinned by their own tests above (the
  // key-string fallback under TomServerConfigResourceProvider, the bare-String
  // throw under TomConfig resolution, and the substituted-YAML and
  // missing-file ones under TomYaml); the four with nowhere else to live are
  // here.
  group('the documented limitations hold', () {
    test('a misspelled setting merges as a live key and fills no field', () {
      // `prot` is a typo for `port`. Nothing validates the merged tree against
      // the fields it will fill, so the typo survives the merge as an ordinary
      // key while `port` -- the key that would have set the field -- is simply
      // absent. The reflection layer then drops `prot`, because no field is
      // named that, and reports nothing either way.
      _install({});
      final merged = TomBaseServerConfiguration.getDefaultValues(['prot=8080']);
      expect(merged['prot'], 8080);
      expect(merged.containsKey('port'), isFalse);
    });

    test('a TomConfig does not observe a provider installed later', () {
      _install({'n': 1});
      final resolved = TomIntConfig('n');
      _install({'n': 2});
      // The second read proves the install really took, so the first is about
      // the cache rather than about a provider that never changed.
      expect(resolved.get(), 1);
      expect(TomIntConfig('n').get(), 2);
    });

    test('the default TLS material is the checked-in self-signed pair', () {
      _install({});
      final config = _CapturingConfig([]);
      expect(config.certificateChain, contains('BEGIN CERTIFICATE'));
      expect(config.privateKey, contains('BEGIN PRIVATE KEY'));
    });

    test('jwtSharedSecretKey defaults to a literal passphrase', () {
      _install({});
      expect(
        _CapturingConfig([]).jwtSharedSecretKey,
        'config-secret-passphrase',
      );
    });
  });

  // The rule that a dartdoc or document may not gesture at "the quest
  // completion steps" is not specific to configuration, so it is not guarded
  // here: `api_reference_coverage_test.dart` ('shipped text stands on its own')
  // applies it to every source under `lib/` and every hand-written document in
  // the package.
}
