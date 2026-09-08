import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

// The generated reflection bootstrap. `initializeReflection()` populates the
// global reflection data, which is what lets this suite *ask*
// `MariaDbDatasource` which keys it can be configured through instead of
// restating a list here that would drift away from the class.
import 'fixtures/reflection_fixture.dart';
import 'fixtures/reflection_fixture.reflection.dart';

/// The keys `TomDataSourceInfo` reads itself, before any driver exists.
///
/// `type` selects the driver and `delegateTo` turns the entry into an alias
/// for another one. Neither is a field on a data source, so neither shows up in
/// the reflected set — yet both are legitimate in a configuration block. Taken
/// from the registry rather than restated, because the registry strips exactly
/// this set before the driver sees the block: a copy here would let the two
/// definitions of "not a driver setting" drift apart, which is the failure the
/// strict check exists to make impossible.
const _registryKeys = TomDataSourceInfo.registryKeys;

/// The settings keys an instance of [type] can actually be configured through.
///
/// Derived from reflection rather than written out, because binding *is*
/// reflection: a driver's `initialize` hands the settings map to
/// `tomReflectionInfo.setValues`, which assigns entry by entry through the
/// setter named by the key. A key with no setter therefore binds nothing, and
/// `TomDataSourceInfo.initialize` refuses the block for it. Deriving the set
/// here means a *renamed field* fails this suite too, not just a mistyped
/// document — and it is the same derivation the registry makes, so the two
/// cannot disagree about what a driver accepts.
Set<String> _bindableKeys(Type type) {
  final mirror = tomReflector.reflectType(type) as ClassMirror;
  return {
    for (final member in mirror.instanceMembers.keys)
      if (member.endsWith('=')) member.substring(0, member.length - 1),
  };
}

/// One documented data-source configuration, with the position a failure has
/// to name to be actionable.
class _ConfigBlock {
  /// `path:line` of the `type:` entry that anchors the block.
  final String location;

  /// Every settings key the block presents to a reader.
  final Set<String> keys;

  /// The driver name the block's `type:` entry selects (`mariadb`, …).
  final String driverType;

  _ConfigBlock(this.location, this.keys, this.driverType);
}

/// The `type:` entry that anchors a data-source configuration.
///
/// Anchoring on the driver name rather than on a surrounding `datasources:`
/// heading is what keeps unrelated YAML out: the configuration examples in
/// `TomYaml` show `${VAR:default}` expansion over an arbitrary tree and happen
/// to spell a branch `database:`, which is not a settings key and must not be
/// read as one.
final _anchor = RegExp(r'''['"]?type['"]?\s*:\s*['"]?(mariadb[A-Za-z_]*)''');

/// Marks a block that is deliberately wrong, so the sweep leaves it alone.
///
/// The sweep polices blocks a reader might copy, and a block written to be
/// *rejected* is not one of those — the tests below need a misspelled key in a
/// real configuration block to have anything to assert. Opting out by an
/// explicit marker rather than by excluding this file keeps the sweep over the
/// rest of it: a genuinely mistaken example here still fails.
const _counterexample = 'not-a-valid-block';

/// A settings key opening a line, in either YAML (`host:`) or Dart
/// (`'host':`) spelling.
final _lineKey = RegExp(r'''^\s*['"]?([A-Za-z_][A-Za-z0-9_]*)['"]?\s*:''');

/// Every key of a map written inline on one line.
final _inlineKey = RegExp(r'''['"]?([A-Za-z_][A-Za-z0-9_]*)['"]?\s*:''');

/// Strips a leading Dart comment marker, so an example inside dartdoc indents
/// like the YAML it is showing.
String _uncomment(String line) {
  final marker = RegExp(r'^(\s*)//+ ?').firstMatch(line);
  if (marker == null) return line;
  return '${marker.group(1)}${line.substring(marker.end)}';
}

int _indent(String line) => line.length - line.trimLeft().length;

/// Reads the configuration block anchored at [index].
///
/// Two shapes occur and both are documented, so both are read. A map written
/// inline (`{'type': 'mariadb', 'host': 'db'}`) is bounded by its own braces;
/// one written over several lines is bounded by indentation — its keys are the
/// sibling lines at the anchor's indent, and the block ends where the
/// indentation falls below it.
_ConfigBlock _blockAt(List<String> lines, int index, String path) {
  final location = '$path:${index + 1}';
  final line = lines[index];
  final match = _anchor.firstMatch(line)!;

  final driverType = match.group(1)!;

  final open = line.lastIndexOf('{', match.start);
  if (open >= 0) {
    final close = line.indexOf('}', match.end);
    final inner = line.substring(open, close < 0 ? line.length : close);
    return _ConfigBlock(location, {
      for (final key in _inlineKey.allMatches(inner)) key.group(1)!,
    }, driverType);
  }

  final indent = _indent(line);
  final keys = <String>{};
  for (final step in const [-1, 1]) {
    for (var i = index; i >= 0 && i < lines.length; i += step) {
      final candidate = lines[i];
      if (candidate.trim().isEmpty) continue;
      // Deeper lines are a value spilling over (`'databaseName': _env(`), not
      // siblings; shallower ones are outside the block entirely.
      if (_indent(candidate) > indent) continue;
      if (_indent(candidate) < indent) break;
      final key = _lineKey.firstMatch(candidate);
      if (key == null) break;
      keys.add(key.group(1)!);
    }
  }
  return _ConfigBlock(location, keys, driverType);
}

/// Every data-source configuration shipped with the package.
///
/// Generated reflection is skipped: it is machine-written, and nobody reads it
/// to learn how to configure anything.
List<_ConfigBlock> _shippedConfigBlocks() {
  final blocks = <_ConfigBlock>[];
  for (final root in ['lib', 'doc', 'example', 'test']) {
    for (final entry in Directory(root).listSync(recursive: true)) {
      if (entry is! File) continue;
      final path = entry.path;
      if (path.endsWith('.reflection.dart')) continue;
      if (!path.endsWith('.dart') &&
          !path.endsWith('.md') &&
          !path.endsWith('.yaml')) {
        continue;
      }
      final lines = entry.readAsLinesSync().map(_uncomment).toList();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains(_counterexample)) continue;
        if (_anchor.hasMatch(lines[i])) blocks.add(_blockAt(lines, i, path));
      }
    }
  }
  return blocks;
}

void main() {
  setUpAll(initializeReflection);

  group('documented data-source configuration', () {
    test('every documented key is one the driver can bind', () {
      // A settings key that matches no field is not an approximation of the
      // right one — it is nothing at all. The reader who copies it gets a data
      // source pointed at no database with no credentials, and a connection
      // error that names neither, because the key never reached anything that
      // could complain about it.
      final bindable = _bindableKeys(MariaDbDatasource).union(_registryKeys);
      final offenders = <String>[];
      for (final block in _shippedConfigBlocks()) {
        for (final key in block.keys) {
          if (!bindable.contains(key)) offenders.add('${block.location} $key');
        }
      }
      expect(offenders, isEmpty);
    });

    test('the sweep reaches the documents it is meant to police', () {
      // Without this, the check above passes just as happily on a scan that
      // matched nothing at all — a silent guard is worse than none, because it
      // is mistaken for coverage.
      final located = _shippedConfigBlocks().map((b) => b.location).toList();
      expect(located, isNotEmpty);
      expect(located.any((l) => l.startsWith('doc/datasources.md:')), isTrue);
    });

    test('the names the documents use are the names the driver declares', () {
      final bindable = _bindableKeys(MariaDbDatasource);
      expect(
        bindable,
        containsAll([
          'username',
          'password',
          'host',
          'port',
          'databaseName',
          'timeOut',
        ]),
      );
      // The two plausible-looking names that bind nothing. They are the ones a
      // writer reaches for — every other database's documentation calls them
      // that — which is exactly why they are pinned as absent.
      expect(bindable, isNot(contains('user')));
      expect(bindable, isNot(contains('database')));
    });

    test('every documented type name resolves to a registered driver', () {
      // The first thing a configuration block does is name a driver, and the
      // keys below it are worth checking only if that name resolves. It is
      // reached through the same call the server startup makes, because the
      // failure this pins is not a property of the source text: the driver
      // scan walks `tomReflector.annotatedClasses`, so a class that stops
      // being `@tomReflector`-annotated silently leaves the registry and every
      // server configured for its type dies at startup with
      // `no_driver_found`.
      //
      // Which is not hypothetical. `@tomReflector` and
      // `@TomDatasourceDriver("mariadb")` sat above `MariaDbDatasource` until
      // two private helpers were inserted between them and the class, at which
      // point both annotations bound to the first helper instead. Nothing
      // caught it: the DB-backed suite that exercises discovery skips without a
      // server, and the checked-in reflection artifacts still carried the old,
      // correct data — so the defect stayed invisible until they were
      // regenerated. Asserting through `createDatasourceOf` here keeps the
      // check running on every machine, with no database.
      final unresolved = <String>[];
      for (final block in _shippedConfigBlocks()) {
        try {
          expect(TomDataSource.createDatasourceOf(block.driverType), isNotNull);
        } catch (e) {
          unresolved.add('${block.location} ${block.driverType}: $e');
        }
      }
      expect(unresolved, isEmpty);
    });

    test('the shared converter still drops a key no field matches', () {
      // What a configuration block would cost if it reached the converter: no
      // throw, no log the caller sees, and a data source left at its defaults,
      // which then fails to connect naming neither the schema nor the
      // credentials it was never given.
      //
      // The tolerance is right where the converter is normally used — a wire
      // payload whose sender may be newer than its receiver — so it is pinned
      // here rather than removed. What changed is that a datasource block no
      // longer arrives here to be tolerated: the registry checks the keys
      // first. The group below is that check.
      final datasource = MariaDbDatasource();
      tomReflectionInfo.setValues<MariaDbDatasource>(datasource, {
        'database': 'app_db',
        'user': 'app',
      });
      expect(datasource.databaseName, isEmpty);
      expect(datasource.username, isEmpty);
    });
  });

  group('a settings key that binds nothing is refused', () {
    setUp(TomDataSourceInfo.datasources.clear);
    tearDown(TomDataSourceInfo.datasources.clear);

    /// Registers a single datasource block named [name] and returns whatever
    /// it threw, or null when it initialised.
    ///
    /// The whole registry entry point rather than the check alone, because the
    /// behaviour under test is what a *configuration file* does at start-up —
    /// and the two keys the registry consumes on the way are half the question.
    Future<Object?> register(String name, Map<String, dynamic> block) async {
      try {
        await TomDataSourceInfo.initializeDatasourceInfo({name: block});
        return null;
      } catch (error) {
        return error;
      }
    }

    Matcher unknownSetting(String datasource, List<String> keys) =>
        isA<TomDatasourceInitException>()
            .having(
              (e) => e.key,
              'key',
              'tom_datasource_info.initialize.unknown_setting',
            )
            .having(
              (e) => e.parameters?['datasource'],
              'datasource',
              datasource,
            )
            .having((e) => e.parameters?['keys'], 'keys', keys);

    test('a misspelled key names itself and the data source', () async {
      // `database` for `databaseName` — the misspelling the shipped documents
      // carried until they were corrected, and the one every other database's
      // documentation invites. Both halves of the message matter: the key is
      // what to fix, and the data-source name is which block to open. The
      // driver knows only the first, which is why the check is the registry's.
      final error = await register('app_db', {
        'type': 'fixture_settings',
        'host': 'localhost',
        'database': 'app_db',
      });
      expect(error, unknownSetting('app_db', ['database']));
      expect('$error', contains('app_db'));
      expect('$error', contains("'database'"));
    });

    test('every offending key is named, not just the first', () {
      // A block with two typos in it should take one restart to fix, not two.
      return register('app_db', {
        'type': 'fixture_settings',
        'database': 'app_db',
        'user': 'app',
      }).then(
        (error) =>
            expect(error, unknownSetting('app_db', ['database', 'user'])),
      );
    });

    test('the registry keys are not settings, and pass', () async {
      // `type` is read by the registry and is a field of no driver, so a strict
      // check that saw it would refuse every correctly configured data source.
      // It passes because the registry *removes* it rather than excusing it —
      // and the driver, which never sees it, cannot be asked to.
      final error = await register('app_db', {
        'type': 'fixture_settings',
        'host': 'localhost',
        'port': 3306,
        'databaseName': 'app_db',
      });
      expect(error, isNull);
      final driver =
          TomDataSourceInfo.getDataSourceInfo('app_db')!.datasource
              as FixtureSettingsDatasource;
      expect(driver.databaseName, 'app_db');
      expect(driver.port, 3306);
    });

    test('a delegate block is an alias and is never checked as settings', () {
      // `delegateTo` returns before a driver exists, so there is nothing to
      // check the block against — which is why it is a registry key and not an
      // allowlisted exception inside the check.
      final base = TomDataSourceInfo('base', <String, dynamic>{});
      TomDataSourceInfo.datasources['base'] = base;
      return register('alias', {'delegateTo': 'base'}).then((error) {
        expect(error, isNull);
        expect(TomDataSourceInfo.getDataSourceInfo('alias'), same(base));
      });
    });

    test('a driver that declares extra fields accepts them', () async {
      // The set is read off the driver the block selected, not off the one
      // driver the framework ships. `applicationName` exists on the fixture
      // driver and on no other.
      final error = await register('app_db', {
        'type': 'fixture_settings',
        'databaseName': 'app_db',
        'applicationName': 'reporting',
      });
      expect(error, isNull);
      final driver =
          TomDataSourceInfo.getDataSourceInfo('app_db')!.datasource
              as FixtureSettingsDatasource;
      expect(driver.applicationName, 'reporting');
    });

    test('and another driver refuses the same key', () async {
      // The other half of the asymmetry. Without it the test above passes on a
      // check that accepts everything.
      final error = await register('app_db', {
        // The marker is spelled out because a comment is not interpolated;
        // `_counterexample` names the same text for the sweep that reads it.
        'type': 'mariadb', // not-a-valid-block
        'databaseName': 'app_db',
        'applicationName': 'reporting',
      });
      expect(error, unknownSetting('app_db', ['applicationName']));
      expect('$error', contains('MariaDbDatasource'));
    });
  });
}
