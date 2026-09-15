/// Holds the package to the claim [TomServerException] makes about itself:
/// "Every server exception type ... subtypes this class, so a single
/// `on TomServerException catch (e)` clause reaches all of them."
///
/// That sentence is load-bearing rather than descriptive. Three things in the
/// framework are built on it:
///
///  * the endpoints pipeline classifies a failure by catching
///    [TomServerException], so a type outside the family reaches the client as
///    an unclassified error;
///  * `tomErrorEnvelope` writes the `clientThrow` field only for a
///    [TomServerException], so a type outside the family cannot say whether its
///    message may be shown;
///  * [TomServerException] is what captures `isolateName` and copies a
///    [TomRequestId] into `requestUuid`, so a type outside the family arrives
///    naming neither the worker that raised it nor the request that caused it.
///
/// Two classes falsified the claim — `TomDatasourceInitException` and
/// `TomAuthorizationCacheException` extended the kernel's [TomException]
/// directly. Both are exactly the kind of failure someone reads a log to
/// attribute, and both arrived without the isolate or the request.
///
/// **Why a source scan rather than a runtime check.** A runtime check can only
/// examine types it can name and construct, so it verifies the exceptions
/// someone remembered to list — which is the property that failed here. The
/// scan reads every class declaration under `lib/src/tomserver/` instead, so a
/// new exception class is covered by existing this file the moment it is
/// written. `crud_repository_exceptions_test.dart` guards one file this way;
/// this is the same guard made package-wide, which is what its own notes asked
/// for.
///
/// **Connection-free.** Nothing here runs server code; the subject is the
/// declarations themselves.
library;

import 'dart:io';

import 'package:test/test.dart';
// `TomException` arrives through this barrel: the server package re-exports the
// kernel, and importing the kernel again here would be a second route to the
// same class.
import 'package:tom_core_server/tom_core_server.dart';

/// Root of the package's own source. Every rule below reads it from disk, so
/// the suite must run from the package directory (as `dart test` does).
const _sourceRoot = 'lib/src/tomserver';

/// One class declaration found by [_scanDeclarations].
class _Declaration {
  _Declaration(this.name, this.superclass, this.file);

  /// The declared class name.
  final String name;

  /// The name after `extends`, or null for a class that extends nothing.
  final String? superclass;

  /// Package-relative path of the file declaring it, for the failure message —
  /// the name alone does not say where to go and fix it.
  final String file;
}

/// Matches a class declaration and captures its `extends` clause.
///
/// Anchored at the start of a line, so a class name appearing inside a comment,
/// a string or a nested generic is not mistaken for a declaration. `abstract`,
/// `base`, `final`, `sealed` and `mixin class` are all accepted because the
/// family contains an abstract member (`TomDeliveryException`) and nothing
/// stops it acquiring a sealed one.
final _classPattern = RegExp(
  r'^(?:abstract\s+|base\s+|final\s+|sealed\s+|interface\s+|mixin\s+)*'
  r'class\s+([A-Za-z_]\w*)\s*(?:<[^>]*>)?\s*'
  r'(?:extends\s+([A-Za-z_]\w*))?',
  multiLine: true,
);

/// Reads every class declaration under [_sourceRoot].
///
/// Generated reflection output is skipped: it restates declarations that are
/// already scanned from their own source, so including it would report every
/// finding twice and make a fault's location ambiguous.
List<_Declaration> _scanDeclarations() {
  final declarations = <_Declaration>[];
  final files = Directory(_sourceRoot)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.path.endsWith('.reflection.dart'));

  for (final file in files) {
    final source = file.readAsStringSync();
    for (final match in _classPattern.allMatches(source)) {
      declarations.add(
        _Declaration(match.group(1)!, match.group(2), file.path),
      );
    }
  }
  return declarations;
}

void main() {
  final declarations = _scanDeclarations();
  final superclassOf = {for (final d in declarations) d.name: d.superclass};

  /// Walks the `extends` chain from [name] and returns every ancestor named
  /// along it, stopping at a name this package does not declare (the kernel's
  /// [TomException], `Object`, a driver type).
  ///
  /// Returns the chain rather than a yes/no so a failure can print the route
  /// taken — "extends TomException" is the answer, and a bare `false` would
  /// make the reader find that out themselves.
  List<String> ancestry(String name) {
    final chain = <String>[];
    var current = superclassOf[name];
    // A malformed chain cannot loop in valid Dart, but the scan is not a
    // compiler: a `class A extends A` in a doc comment that slipped the anchor
    // would hang the suite rather than fail it.
    final seen = <String>{name};
    while (current != null && seen.add(current)) {
      chain.add(current);
      current = superclassOf[current];
    }
    return chain;
  }

  group('the scan sees the package', () {
    // Every rule below is a "for all" over the scan's output, so a scan that
    // found nothing would pass all of them while checking nothing. These two
    // tests are what makes the others mean something.
    test('it finds a substantial number of classes', () {
      expect(
        declarations.length,
        greaterThan(200),
        reason:
            'the scan should reach the whole of $_sourceRoot; a small count '
            'means the pattern or the root stopped matching',
      );
    });

    test('it finds the base class and resolves a known subtype', () {
      expect(superclassOf, contains('TomServerException'));
      expect(
        ancestry('TomCacheException'),
        contains('TomServerException'),
        reason: 'the ancestry walk should resolve a known member of the family',
      );
    });
  });

  group('every exception class is a TomServerException', () {
    // The rule, stated once: a class in this package that is an exception at
    // all must be a *server* exception. `TomServerException` itself is the one
    // exemption, being the class the rule is about.
    final offenders = <_Declaration>[];
    for (final declaration in declarations) {
      if (declaration.name == 'TomServerException') continue;
      final chain = ancestry(declaration.name);
      final isException =
          chain.contains('TomException') ||
          chain.contains('TomServerException');
      if (isException && !chain.contains('TomServerException')) {
        offenders.add(declaration);
      }
    }

    test('no exception class extends TomException directly', () {
      expect(
        offenders.map((o) => '${o.name} (${o.file})').toList(),
        isEmpty,
        reason:
            'a class outside the TomServerException family escapes every '
            '`on TomServerException catch` — including the endpoints '
            "pipeline's classification — and arrives without isolateName, "
            'clientThrow or the request correlation. Extend '
            'TomServerException instead.',
      );
    });

    test('the family has more than a handful of members', () {
      // Counted so the rule above cannot be satisfied by a scan that stopped
      // recognising `extends` and therefore classified nothing as an exception.
      final members = declarations
          .where((d) => ancestry(d.name).contains('TomServerException'))
          .map((d) => d.name)
          .toSet();
      expect(members.length, greaterThan(25));
      expect(members, contains('TomDatasourceInitException'));
      expect(members, contains('TomAuthorizationCacheException'));
    });
  });

  group('the base class is raised directly only where it is meant to be', () {
    // The companion to the rule above, and the one that keeps it honest. "Every
    // server exception type subtypes this class" says what a *type* must do; it
    // says nothing about what a raise site may do, and a site that throws the
    // base class satisfies the family rule while making the family useless at
    // that point. A caller wanting to handle a wiring fault differently from a
    // query fault has only the key string to match on.
    //
    // Five sites do exactly that, and they are meant to. Each is a `.named(...)`
    // constructor resolving a data source out of `TomDataSourceInfo` and
    // refusing before it opens a connection. There is nothing for a subtype to
    // add: all five happen at construction, before any request is served, so a
    // deployment meets them as a failed start-up in a log rather than as
    // something a `catch` clause discriminates — and the operator's next act is
    // to fix one name in one configuration file, which the key and the
    // `datasource` parameter already say.
    //
    // What this group buys is that the five stay five. The argument above is
    // about a construction-time wiring fault and does not carry to anything
    // else, but nothing in the source distinguishes a sixth direct raise from
    // these; without a pin, "the base class is fine here" erodes into "the base
    // class is fine anywhere", one site at a time, each one locally defensible.
    // So the set is named, and a new one has to be argued for rather than
    // merely written.

    /// Every `throw TomServerException(` under [_sourceRoot], as
    /// `file` → the key it raises.
    ///
    /// Read from source rather than by catching, because the subject is where
    /// the base class is *written*: a site reachable only by a misconfiguration
    /// nobody has made is exactly the one a runtime sweep would miss.
    final directRaises = <String, String>{};
    for (final file
        in Directory(_sourceRoot)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .where((f) => !f.path.endsWith('.reflection.dart'))) {
      final source = file.readAsStringSync();
      for (final match in RegExp(
        r'throw TomServerException\(\s*',
      ).allMatches(source)) {
        final key = RegExp(
          r'''["']([a-z][a-z0-9_.]*)["']''',
        ).matchAsPrefix(source.substring(match.end));
        directRaises[file.path] = key?.group(1) ?? '<no literal key>';
      }
    }

    /// The five sites, and the key each raises.
    const expected = {
      '$_sourceRoot/audit/sql_audit_sink.dart': 'audit.sink.unknown_datasource',
      '$_sourceRoot/authentication/sql_oauth_state_store.dart':
          'oauth.state_store.unknown_datasource',
      '$_sourceRoot/scheduling/sql_job_store.dart':
          'scheduling.store.unknown_datasource',
      '$_sourceRoot/scheduling/sql_lease_lock.dart':
          'scheduling.lock.unknown_datasource',
      '$_sourceRoot/scheduling/sql_scheduler_nodes.dart':
          'scheduling.nodes.unknown_datasource',
    };

    test('the five sites are exactly the five that are documented', () {
      expect(
        directRaises,
        expected,
        reason:
            'a site throwing TomServerException directly gives a caller '
            'nothing but the key to match on. The five listed are '
            'construction-time data-source guards, where a subtype would add '
            'nothing because no catch clause runs; see TomServerException. '
            'A new one needs that argument to hold for it too — otherwise '
            'declare a subtype for the module and throw that.',
      );
    });

    test('every one of them refuses a data source it cannot resolve', () {
      // The keys are what the argument rests on: it is specifically a *wiring*
      // fault that needs no type. A site keyed anything else has left the case
      // this exemption was written for, whatever its file.
      for (final entry in directRaises.entries) {
        expect(
          entry.value,
          endsWith('.unknown_datasource'),
          reason: '${entry.key} raises the base class for something else',
        );
        expect(
          entry.value.split('.').length,
          3,
          reason:
              "[${entry.value}] should read <area>.<operation>.<condition>, "
              "the shape TomException's own dartdoc fixes",
        );
      }
    });

    test('every one of them names the data source that was not found', () {
      // The parameter is half the contract. A cluster misconfigured this way
      // has one typo in one configuration key, and a failure that does not say
      // which name was rejected leaves the operator to find it by reading.
      for (final path in expected.keys) {
        final source = File(path).readAsStringSync();
        final raise = source.indexOf('throw TomServerException(');
        expect(raise, greaterThanOrEqualTo(0), reason: path);
        expect(
          source.substring(raise, source.indexOf(');', raise)),
          contains("parameters: {'datasource': "),
          reason:
              '$path throws without naming the unresolved data source, so the '
              'operator is told a name was wrong but not which',
        );
      }
    });
  });

  group('the two classes the rule was written for', () {
    // The scan reads text; these read the compiled types. Together they say
    // the declaration and the runtime agree, which neither says alone.
    test('a datasource-init failure is a server exception', () {
      final error = TomDatasourceInitException('a.b.c', 'a message');
      expect(error, isA<TomServerException>());
      expect(error, isA<TomException>());
    });

    test('an authorization-cache failure is a server exception', () {
      final error = TomAuthorizationCacheException('a.b.c', 'a message');
      expect(error, isA<TomServerException>());
      expect(error, isA<TomException>());
    });

    test('both now carry the isolate attribution', () {
      // The concrete thing the base class adds, and the reason the two were
      // worth moving rather than merely relabelling.
      expect(TomDatasourceInitException('a.b.c', 'm').isolateName, isNotEmpty);
      expect(
        TomAuthorizationCacheException('a.b.c', 'm').isolateName,
        isNotEmpty,
      );
    });

    test('a datasource-init failure never reaches the client', () {
      // Infrastructure: the messages name driver classes, datasource types and
      // raw driver errors. `clientThrow` is not a constructor parameter, so
      // this is an invariant of the type rather than a per-site default a
      // raise site could forget.
      expect(TomDatasourceInitException('a.b.c', 'm').clientThrow, isFalse);
    });

    test('an authorization-cache failure may reach the client', () {
      // The opposite decision, for the opposite reason: all three conditions
      // are about the token the caller presented, and two of them tell the
      // caller what to do next (re-authorize; fix the malformed claim).
      expect(TomAuthorizationCacheException('a.b.c', 'm').clientThrow, isTrue);
    });
  });

  group('the keys these two classes raise', () {
    // `TomException`'s own dartdoc fixes the shape: "written dotted-lowercase
    // as `<area>.<operation>.<condition>` — the first segment names the module,
    // so keys from unrelated code cannot collide."
    final keyPattern = RegExp(
      r'''["']([a-z][a-z0-9_]*(?:\.[a-z0-9_]+)+)["']''',
    );

    Set<String> keysRaisedIn(String path, String type) {
      final source = File(path).readAsStringSync();
      final keys = <String>{};
      for (final match in RegExp('throw $type\\(\\s*').allMatches(source)) {
        final rest = source.substring(match.end);
        final key = keyPattern.matchAsPrefix(rest);
        if (key != null) keys.add(key.group(1)!);
      }
      return keys;
    }

    final datasourceKeys = keysRaisedIn(
      '$_sourceRoot/datasources/datasource_initialization.dart',
      'TomDatasourceInitException',
    );
    final cacheKeys = keysRaisedIn(
      '$_sourceRoot/authorization/authorization_cache.dart',
      'TomAuthorizationCacheException',
    );

    test(
      'every datasource-init key names an area, an operation and a condition',
      () {
        expect(datasourceKeys, isNotEmpty);
        for (final key in datasourceKeys) {
          expect(
            key.split('.').length,
            3,
            reason:
                '[$key] should read <area>.<operation>.<condition>; without the '
                'operation segment the scan-time and create-time failures share '
                'a key and cannot be told apart',
          );
        }
      },
    );

    test(
      'every authorization-cache key is scoped to the authorization module',
      () {
        expect(cacheKeys, isNotEmpty);
        for (final key in cacheKeys) {
          expect(key.split('.').length, 3, reason: '[$key]');
          expect(
            key,
            startsWith('authorization.'),
            reason:
                '[$key] is raised by server-side code in the authorization '
                'module; a first segment naming another package is the collision '
                "TomException's key rule exists to prevent",
          );
        }
      },
    );

    test('no key claims to come from the client package', () {
      // The three cache keys read `tomclient.…` although the class that raises
      // them is server-side and unreachable from a client.
      expect(datasourceKeys.followedBy(cacheKeys), isNotEmpty);
      for (final key in datasourceKeys.followedBy(cacheKeys)) {
        expect(key, isNot(startsWith('tomclient.')), reason: '[$key]');
      }
    });
  });

  group('TomLoginException classification', () {
    // A login failure carries two audiences. The `key` is as specific as the
    // throw site can make it and serves the server's logs and its message
    // catalogue; `reason` is the coarse closed set a client switches on. The
    // set only earns that role if it is applied consistently, and consistency
    // across 35 sites in five files is not something review sustains.
    //
    // Read from source for the same reason the rules above are: a runtime
    // sweep verifies the sites somebody remembered to reach, and the sites
    // that go wrong are the ones nobody reaches.

    /// Every `throw TomLoginException(` under [_sourceRoot], as
    /// `(key, reason)` pairs.
    final classifications = <({String key, String reason, String file})>[];
    for (final file
        in Directory(_sourceRoot)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .where((f) => !f.path.endsWith('.reflection.dart'))) {
      final source = file.readAsStringSync();
      final chunks = source.split('throw TomLoginException(');
      for (final chunk in chunks.skip(1)) {
        final key = RegExp(
          r"""['"]([a-z][a-z0-9_.\-]*)['"]""",
        ).firstMatch(chunk);
        final reason = RegExp(
          r'reason: TomLoginFailure\.(\w+)',
        ).firstMatch(chunk);
        classifications.add((
          key: key?.group(1) ?? '<no literal key>',
          reason: reason?.group(1) ?? '<none>',
          file: file.path,
        ));
      }
    }

    test('every throw site names a reason', () {
      // The compiler already requires it, so this is not the guard — it is the
      // check that the scan below is reading what it thinks it is. A scan that
      // silently matched nothing would make every rule after it vacuous.
      expect(classifications, hasLength(greaterThan(30)));
      for (final c in classifications) {
        expect(c.reason, isNot('<none>'), reason: '[${c.key}] in ${c.file}');
        expect(c.key, isNot('<no literal key>'), reason: c.file);
      }
    });

    test('every reason has at least one producer', () {
      // A value nothing raises is a promise to a client that nothing keeps:
      // the client writes a branch for it, and the branch is dead. If a value
      // here has no site, either the classification is wrong or the value
      // should not exist.
      final produced = classifications.map((c) => c.reason).toSet();
      for (final value in TomLoginFailure.values) {
        expect(
          produced,
          contains(value.name),
          reason:
              'no throw site classifies itself as ${value.name}, so a client '
              'branching on it branches on nothing',
        );
      }
    });

    test('a key maps to one reason wherever it is raised', () {
      // The property that makes the closed set trustworthy. The same key
      // classified two ways is a client shown two different remedies for one
      // condition, and it is the way a 35-site classification decays.
      final byKey = <String, Set<String>>{};
      for (final c in classifications) {
        byKey.putIfAbsent(c.key, () => <String>{}).add(c.reason);
      }
      for (final entry in byKey.entries) {
        expect(
          entry.value,
          hasLength(1),
          reason:
              '[${entry.key}] is classified as ${entry.value.join(" and ")} at '
              'different sites; one condition has one remedy',
        );
      }
    });

    test('every login key is scoped to the login vocabulary', () {
      expect(classifications, isNotEmpty);
      for (final c in classifications) {
        expect(
          c.key,
          startsWith('login.error.'),
          reason:
              '[${c.key}] in ${c.file} is raised as a login failure, so it '
              'belongs to the login key vocabulary a message catalogue reads',
        );
      }
    });
  });
}
