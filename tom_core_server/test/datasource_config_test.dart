import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

// The generated reflection bootstrap. `initializeReflection()` populates the
// global reflection data, which is what lets this suite *ask*
// `MariaDbDatasource` which keys it can be configured through instead of
// restating a list here that would drift away from the class.
import 'fixtures/reflection_fixture.reflection.dart';

/// The keys `TomDataSourceInfo` reads itself, before any driver exists.
///
/// `type` selects the driver and `delegateTo` turns the entry into an alias
/// for another one; see `TomDataSourceInfo.initialize`. Neither is a field on
/// a data source, so neither shows up in the reflected set — yet both are
/// legitimate in a configuration block, so both belong here.
const _registryKeys = {'type', 'delegateTo'};

/// The settings keys an instance of [type] can actually be configured through.
///
/// Derived from reflection rather than written out, because binding *is*
/// reflection: `MariaDbDatasource.initialize` hands the whole settings map to
/// `tomReflectionInfo.setValues`, which assigns entry by entry through the
/// setter named by the key. A key with no setter therefore binds nothing —
/// and, because the shared converter is deliberately tolerant of unknown
/// fields, it is dropped without a word. Deriving the set here means a
/// *renamed field* fails this suite too, not just a mistyped document.
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

    test('a key no field matches is dropped in silence', () {
      // The cost of a wrong key, stated as behaviour: no throw, no log the
      // caller sees, and a data source left at its defaults. This is why the
      // documents have to be right rather than merely close.
      final datasource = MariaDbDatasource();
      tomReflectionInfo.setValues<MariaDbDatasource>(datasource, {
        'database': 'app_db',
        'user': 'app',
      });
      expect(datasource.databaseName, isEmpty);
      expect(datasource.username, isEmpty);
    });
  });
}
