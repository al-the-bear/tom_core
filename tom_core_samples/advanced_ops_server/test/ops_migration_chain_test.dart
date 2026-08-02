/// The one coordination cost of letting two packages contribute to one chain.
///
/// The migration engine matches a chain to a database by folder names —
/// `<datasource>/<schema>` — not by which package the folder sits in, and it
/// imposes no contiguity on versions: it records an applied version per
/// (datasource, schema) pair and applies whatever it has not seen. That is what
/// lets `advanced_app_server` own `[000]`–`[003]` of `app_db/app_schema` while
/// this package owns `[004]`, so nothing in the app server's package mentions a
/// job queue it never runs.
///
/// The price is that the two packages must not pick the same number, and neither
/// one can see the other's choice. A collision is not a loud failure either: the
/// engine records "version 4 applied" and the *second* file with that number is
/// never run at all — so the symptom is a missing table on a fresh deployment,
/// discovered at the first tick, in whichever environment was provisioned last.
///
/// So it is checked rather than trusted. This suite reads both packages'
/// directories off disk and compares the numbers, which is the only place the
/// arrangement can be verified — by construction, no single package knows.
library;

import 'dart:io';

import 'package:test/test.dart';

/// This package's contribution to the chain.
const String _opsSchemaDir = 'database_migrations/app_db/app_schema/';

/// The app server's part of the same chain.
const String _appSchemaDir =
    '../advanced_app_server/database_migrations/app_db/app_schema/';

/// The `[nnn]` prefix of a migration file name.
///
/// Returns `null` for a file that is not a migration, so a stray `.md` in the
/// directory is ignored rather than parsed into a spurious version.
int? _versionOf(String basename) {
  final match = RegExp(r'^\[(\d+)\]').firstMatch(basename);
  if (match == null) return null;
  return int.parse(match.group(1)!);
}

/// Every migration basename in [directory].
List<String> _basenames(String directory) =>
    Directory(directory).listSync().whereType<File>().map((file) {
      return file.uri.pathSegments.last;
    }).where((name) => name.endsWith('.sql')).toList()
      ..sort();

/// Every version number contributed by [directory].
List<int> _versions(String directory) => [
      for (final name in _basenames(directory))
        if (_versionOf(name) case final version?) version,
    ];

void main() {
  group('two packages, one chain, no collision', () {
    test('no version this package ships is also shipped by the app server', () {
      final ops = _versions(_opsSchemaDir).toSet();
      final app = _versions(_appSchemaDir).toSet();

      expect(
        ops.intersection(app),
        isEmpty,
        reason: 'app_db/app_schema versions collide: the engine would record '
            'the number as applied and silently never run the second file — '
            'renumber this package\'s migration above ${app.reduce((a, b) => a > b ? a : b)}',
      );
    });

    test('this package numbers above the app server, not into a gap', () {
      // Not required by the engine, which has no contiguity rule — but a
      // deployment that already applied `[004]` cannot receive a later `[003]`,
      // so numbering below the existing head would work on a fresh database and
      // silently skip on every existing one.
      final ops = _versions(_opsSchemaDir);
      final app = _versions(_appSchemaDir);
      expect(ops.reduce((a, b) => a < b ? a : b),
          greaterThan(app.reduce((a, b) => a > b ? a : b)));
    });

    test('this package ships exactly one migration, numbered [004]', () {
      expect(_basenames(_opsSchemaDir), ['[004]-ops_framework_tables.sql']);
    });

    test('the app server still ships the four this expects', () {
      // The other half of the pair. If the app server grows an `[004]` the test
      // above fails; if it grows an `[005]` nothing fails, but the head has
      // moved and this is where a reader finds out.
      expect(_versions(_appSchemaDir), [0, 1, 2, 3]);
    });
  });

  group('the chain is read from where it will actually be found', () {
    test('both directories exist and are non-empty', () {
      // A guard on the guard: a mistyped path would make every set empty, and
      // "no collision between two empty sets" is a test that passes by
      // asserting nothing.
      expect(_basenames(_opsSchemaDir), isNotEmpty);
      expect(_basenames(_appSchemaDir), isNotEmpty);
    });

    test('the datasource and schema folders are the ones the engine matches on',
        () {
      // `<datasource>/<schema>` is the whole matching rule, so a renamed folder
      // is a chain that quietly applies to nothing.
      expect(Directory(_opsSchemaDir).existsSync(), isTrue);
      expect(_opsSchemaDir, contains('app_db/app_schema'));
      expect(_appSchemaDir, contains('app_db/app_schema'));
    });

    test('this package adds no second chain', () {
      // The sample's promise: no new database. A folder for another datasource
      // here would be this server quietly acquiring a store of its own.
      final datasources = Directory('database_migrations')
          .listSync()
          .whereType<Directory>()
          .map((dir) => dir.uri.pathSegments[dir.uri.pathSegments.length - 2])
          .toList();
      expect(datasources, ['app_db']);
    });
  });
}
