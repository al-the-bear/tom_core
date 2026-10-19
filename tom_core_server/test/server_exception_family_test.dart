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
    // Seven sites do exactly that, and they are meant to. Each is a `.named(...)`
    // constructor resolving a data source out of `TomDataSourceInfo` and
    // refusing before it opens a connection. There is nothing for a subtype to
    // add: all seven happen at construction, before any request is served, so a
    // deployment meets them as a failed start-up in a log rather than as
    // something a `catch` clause discriminates — and the operator's next act is
    // to fix one name in one configuration file, which the key and the
    // `datasource` parameter already say.
    //
    // What this group buys is that the seven stay seven. The argument above is
    // about a construction-time wiring fault and does not carry to anything
    // else, but nothing in the source distinguishes a seventh direct raise from
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

    /// The seven sites, and the key each raises.
    const expected = {
      '$_sourceRoot/audit/sql_audit_sink.dart': 'audit.sink.unknown_datasource',
      '$_sourceRoot/authentication/sql_oauth_state_store.dart':
          'oauth.state_store.unknown_datasource',
      '$_sourceRoot/authentication/sql_scim_store.dart':
          'scim.store.unknown_datasource',
      '$_sourceRoot/messaging/sql_delivery_report_store.dart':
          'messaging.delivery_report.unknown_datasource',
      '$_sourceRoot/scheduling/sql_job_store.dart':
          'scheduling.store.unknown_datasource',
      '$_sourceRoot/scheduling/sql_lease_lock.dart':
          'scheduling.lock.unknown_datasource',
      '$_sourceRoot/scheduling/sql_scheduler_nodes.dart':
          'scheduling.nodes.unknown_datasource',
    };

    test('the seven sites are exactly the seven that are documented', () {
      expect(
        directRaises,
        expected,
        reason:
            'a site throwing TomServerException directly gives a caller '
            'nothing but the key to match on. The seven listed are '
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

  group('clientThrow is read through clientMessage', () {
    // `clientThrow` is the thrower's promise about its own text, and five types
    // in the package default it to `false` because their messages describe
    // server internals — an unreachable data source, a failed audit write, a
    // misconfigured identity provider. The flag binds the *value*; it cannot
    // bind the handler. A response built from `defaultUserMessage` directly
    // shows those messages and nothing complains, which is a leak by omission
    // rather than by decision.
    //
    // `TomServerException.clientMessage` is the sanctioned read, so the guard
    // is: nothing under `lib/src/tomserver/` touches `defaultUserMessage`
    // directly except the sites pinned below, each with the reason it is not a
    // wire response. A sixth site has to be argued for rather than merely
    // written — the same discipline the direct-raise rule above uses, and for
    // the same reason: a convention nobody can see erodes.

    /// Files under [_sourceRoot] that read `defaultUserMessage` directly, and
    /// why each is not a message on the wire.
    const permitted = <String, String>{
      'little_things/server_exception.dart':
          'the implementation of clientMessage itself, which is what the flag '
          'is read by',
      'server/server.dart':
          'a server-side log line for a failed self-login, written to the '
          'operator log and never to a response',
      'metrics/otlp_exporter.dart':
          'a server-side warning for a periodic OTLP push that failed, written '
          'to the operator log and never to a response',
    };

    /// Package-relative paths (below [_sourceRoot]) that read it, excluding
    /// dartdoc, line comments and the two shapes that pass the value along
    /// without looking at it.
    ///
    /// The exclusions are narrow on purpose — a filter that quietly drops a
    /// real read is worse than no filter — so the last two are whole-line
    /// matches rather than a substring anywhere on the line:
    ///
    ///  * `super.defaultUserMessage` / `this.defaultUserMessage`, the
    ///    forwarding form every subtype constructor uses;
    ///  * `String defaultUserMessage` as a parameter declaration (with or
    ///    without the `{` that opens the named group after it), and a bare
    ///    `defaultUserMessage,` as an argument — what a constructor that cannot
    ///    use `super.` parameters writes instead, because it also needs an
    ///    explicit `super(...)` call.
    final readers = <String>{};
    for (final file
        in Directory(_sourceRoot)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .where((f) => !f.path.endsWith('.reflection.dart'))) {
      for (final line in file.readAsLinesSync()) {
        final code = line.trim();
        if (code.startsWith('//')) continue;
        if (!code.contains('defaultUserMessage')) continue;
        if (code.contains('super.defaultUserMessage')) continue;
        if (code.contains('this.defaultUserMessage')) continue;
        // The trailing `,` of an argument and the `{` that opens a named
        // parameter group are punctuation, not part of the expression.
        final bare = code.replaceAll(',', '').replaceAll('{', '').trim();
        if (bare == 'String defaultUserMessage') continue;
        if (bare == 'defaultUserMessage') continue;
        readers.add(file.path.substring(_sourceRoot.length + 1));
      }
    }

    test('no unpinned file reads the message directly', () {
      expect(
        readers.difference(permitted.keys.toSet()),
        isEmpty,
        reason:
            'these read defaultUserMessage without going through '
            'clientMessage; if the value reaches a response, an exception '
            'marked clientThrow: false has had its message shown',
      );
    });

    test('every pinned exemption is still a real one', () {
      // A pin nobody removed after the site went away reads as permission that
      // was granted rather than as a fact, and the next site to want it finds
      // an entry already there.
      expect(permitted.keys.toSet().difference(readers), isEmpty);
    });

    test('the scan is reading the files it claims to', () {
      // Without this the two rules above are satisfied by a scan that matched
      // nothing at all.
      expect(readers, isNotEmpty);
      expect(readers, contains('little_things/server_exception.dart'));
    });
  });

  group('a raise site throws the family, or says why not', () {
    // The companion to the subtype rule: that rule says what a *type* must be,
    // this one what a *raise site* may throw. A site throwing a type from
    // outside the family is as invisible to `on TomServerException` as a class
    // declared outside it — so every `throw` of a new value must raise a family
    // member, directly or through a helper whose declared return type is one,
    // unless a marker above it says which of three legitimate reasons applies.
    // The rule is stated in doc/little_things.md; the reasons live at the raise
    // sites, not in a list here.
    final family = {
      'TomServerException',
      for (final d in declarations)
        if (ancestry(d.name).contains('TomServerException')) d.name,
    };
    final audit = _RaiseAudit(_readSources(), family);
    final sites = audit.sites();

    test('every raise site throws the family, or carries a marker', () {
      expect(
        [
          for (final site in sites)
            if (site.verdict == _Verdict.offender) site.describe(),
        ],
        isEmpty,
        reason:
            'these throw a type outside the TomServerException family with no '
            '`// $_raiseMarker <category> — <why>` above them. Raise a keyed '
            'server exception, or — for a programmer error, a public parse '
            "function keeping Dart's parse contract, or a kernel protocol "
            'signal — mark the site. See doc/little_things.md.',
      );
    });

    test('every marker names one of the three categories', () {
      expect(
        [
          for (final site in sites)
            if (site.marker != null && site.category == null) site.describe(),
        ],
        isEmpty,
        reason:
            'a marker must begin with one of: ${_raiseCategories.join(', ')}',
      );
    });

    test('every marker still stands above a raise outside the family', () {
      // A marker left behind after its site was converted reads as a standing
      // permission, and the next non-family raise put beside it inherits one.
      expect(audit.strayMarkers(sites), isEmpty);
    });

    test('the scan sees the package and resolves its helpers', () {
      // Every rule above is a "for all"; a scan that matched nothing passes it.
      expect(sites.length, greaterThan(300));
      expect(sites.where((s) => s.verdict == _Verdict.exempt), isNotEmpty);
      final helper = sites.firstWhere((s) => s.callee == '_asStorageException');
      expect(helper.thrownType, 'TomStorageException');
      final staticHelper = sites.firstWhere(
        (s) => s.callee == 'TomBlobStore.notFound',
      );
      expect(family, contains(staticHelper.thrownType));
    });

    group('the scan itself', () {
      _RaiseAudit auditOf(String source) => _RaiseAudit(
        {'lib/x.dart': source},
        {'TomServerException', 'TomXException'},
      );

      test('a family constructor passes', () {
        final site = auditOf(
          "f() { throw TomXException('k', 'm'); }",
        ).sites().single;
        expect(site.verdict, _Verdict.family);
      });

      test('a method called on a value resolves to its declared type', () {
        final site = auditOf(
          'class D {\n'
          '  TomXException failure(String k) => TomXException(k, k);\n'
          '}\n'
          "f(D d) { throw d.failure('k'); }",
        ).sites().firstWhere((s) => s.callee == 'd.failure');
        expect(site.thrownType, 'TomXException');
        expect(site.verdict, _Verdict.family);
      });

      test('a core error without a marker is an offender', () {
        final site = auditOf(
          "f() { throw FormatException('bad'); }",
        ).sites().single;
        expect(site.verdict, _Verdict.offender);
      });

      test('a marked core error is exempt, and its category is read', () {
        final site = auditOf(
          'f() {\n'
          '  // throws-outside-family: parse contract — mirrors int.parse.\n'
          "  throw FormatException('bad');\n"
          '}\n',
        ).sites().single;
        expect(site.verdict, _Verdict.exempt);
        expect(site.category, 'parse contract');
      });

      test('a helper is judged by its declared return type', () {
        final sites = auditOf(
          "TomXException _good() => TomXException('k', 'm');\n"
          "StateError _bad() => StateError('no');\n"
          'f() { throw _good(); }\n'
          'g() { throw _bad(); }\n',
        ).sites();
        expect(sites.map((s) => s.verdict), [
          _Verdict.family,
          _Verdict.offender,
        ]);
      });

      test('rethrowing a held value is propagation, not a raise', () {
        expect(auditOf('f(Object e) { throw e; }').sites(), isEmpty);
      });

      test('a raise named in a comment is not a raise', () {
        expect(
          auditOf("// throw FormatException('x') would be wrong\n").sites(),
          isEmpty,
        );
      });

      test('a marker with no raise outside the family below it is stray', () {
        final audit = auditOf(
          'f() {\n'
          '  // throws-outside-family: programmer error — no longer true.\n'
          "  throw TomXException('k', 'm');\n"
          '}\n',
        );
        expect(audit.strayMarkers(audit.sites()), hasLength(1));
      });
    });
  });
}

/// The marker a raise site outside the family carries on a line above it.
const _raiseMarker = 'throws-outside-family:';

/// The only reasons a server raise site may throw outside the family. The rule
/// and its reasoning are in doc/little_things.md.
const _raiseCategories = [
  'programmer error',
  'parse contract',
  'kernel protocol',
];

/// Every package source file, keyed by path, generated output excluded.
Map<String, String> _readSources() => {
  for (final file
      in Directory(_sourceRoot)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.endsWith('.reflection.dart')))
    file.path: file.readAsStringSync(),
};

/// How a raise site was judged.
enum _Verdict { family, exempt, offender }

/// One `throw` of a call, and what it raises.
class _RaiseSite {
  _RaiseSite(
    this.file,
    this.line,
    this.callee,
    this.thrownType,
    this.marker,
    this.verdict,
  );

  final String file;

  /// 1-based.
  final int line;

  /// What is called: `ArgumentError.value`, `_failure`, `TomBlobStore.notFound`.
  final String callee;

  /// The type the call produces, as far as the declarations say.
  final String thrownType;

  /// The marker text after [_raiseMarker], when the site carries one.
  final String? marker;

  final _Verdict verdict;

  /// The marker's category, or null when it names none of [_raiseCategories].
  String? get category {
    final text = marker?.trim();
    if (text == null) return null;
    for (final c in _raiseCategories) {
      if (text.startsWith(c)) return c;
    }
    return null;
  }

  String describe() => '$file:$line throw $callee(…) → $thrownType';
}

/// Finds every raise site in a set of sources and judges it.
///
/// A raise site is `throw` followed by a call: a constructor
/// (`FormatException(`), a named constructor or static helper
/// (`TomDeliveryException.permanent(`, `TomBlobStore.notFound(`), or a function
/// (`_failure(`). `throw e` of a value already held is propagation and is not a
/// site. A helper is resolved to the return type its declaration states, which
/// is what lets the scan follow `_asStorageException` rather than guess.
class _RaiseAudit {
  _RaiseAudit(this.sources, this.family);

  final Map<String, String> sources;
  final Set<String> family;

  static final _throwCall = RegExp(
    r'\bthrow\s+(?:const\s+)?([A-Za-z_]\w*)(?:\.([A-Za-z_]\w*))?\s*\(',
  );

  /// How far above a raise its marker may sit: a marker usually heads a short
  /// comment explaining the raise.
  static const _reach = 4;

  List<_RaiseSite> sites() {
    final found = <_RaiseSite>[];
    for (final entry in sources.entries) {
      final lines = entry.value.split('\n');
      for (var i = 0; i < lines.length; i++) {
        for (final match in _throwCall.allMatches(_code(lines[i]))) {
          final head = match.group(1)!;
          final member = match.group(2);
          final thrown = _resolve(entry.key, head, member);
          final marker = _markerAbove(lines, i);
          found.add(
            _RaiseSite(
              entry.key,
              i + 1,
              member == null ? head : '$head.$member',
              thrown,
              marker,
              family.contains(thrown)
                  ? _Verdict.family
                  : marker != null
                  ? _Verdict.exempt
                  : _Verdict.offender,
            ),
          );
        }
      }
    }
    return found;
  }

  /// Markers anywhere in the sources that no raise outside the family follows.
  List<String> strayMarkers(List<_RaiseSite> sites) {
    final served = {
      for (final s in sites)
        if (s.verdict == _Verdict.exempt) '${s.file}:${s.line}',
    };
    final stray = <String>[];
    for (final entry in sources.entries) {
      final lines = entry.value.split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains('// $_raiseMarker')) continue;
        final serves = [
          for (var j = i; j <= i + _reach && j < lines.length; j++)
            '${entry.key}:${j + 1}',
        ].any(served.contains);
        if (!serves) stray.add('${entry.key}:${i + 1}');
      }
    }
    return stray;
  }

  /// The code on [line]: nothing, for a line that is wholly a comment.
  static String _code(String line) {
    final trimmed = line.trimLeft();
    return trimmed.startsWith('//') || trimmed.startsWith('*') ? '' : line;
  }

  static String? _markerAbove(List<String> lines, int index) {
    for (var j = index; j >= 0 && j >= index - _reach; j--) {
      final at = lines[j].indexOf('// $_raiseMarker');
      if (at >= 0) return lines[j].substring(at + 3 + _raiseMarker.length);
    }
    return null;
  }

  /// The type `throw head.member(…)` or `throw head(…)` raises.
  ///
  /// `Type.member(…)` is looked up only in the file declaring `Type`: a type
  /// the package does not declare (`ArgumentError.value`) raises itself, and a
  /// method of the same name on an unrelated class must not answer for it.
  /// With no static method of that name, `member` is a named constructor or
  /// factory of `Type`. A bare function is looked up in its own file first.
  /// `value.member(…)` — a method called on a value, such as a statement
  /// raising through the data source that owns it — resolves to the return
  /// type the method is declared with.
  String _resolve(String file, String head, String? member) {
    final isType = head.startsWith(RegExp('[A-Z]'));
    if (!isType && member != null) {
      return _returnTypeOf(sources[file]!, member) ??
          sources.values
              .map((s) => _returnTypeOf(s, member))
              .nonNulls
              .firstOrNull ??
          '<unresolved $head.$member>';
    }
    if (isType) {
      if (member == null) return head;
      final owner = sources.values.where(
        (s) => RegExp('\\bclass\\s+${RegExp.escape(head)}\\b').hasMatch(s),
      );
      return owner.map((s) => _returnTypeOf(s, member)).nonNulls.firstOrNull ??
          head;
    }
    return _returnTypeOf(sources[file]!, head) ??
        sources.values
            .map((s) => _returnTypeOf(s, head))
            .nonNulls
            .firstOrNull ??
        '<unresolved $head>';
  }

  static String? _returnTypeOf(String source, String name) => RegExp(
    r'(?:^|\n)\s*(?:static\s+)?([A-Z]\w*)(?:<[^>]*>)?\??\s+' +
        RegExp.escape(name) +
        r'\s*\(',
  ).firstMatch(source)?.group(1);
}
