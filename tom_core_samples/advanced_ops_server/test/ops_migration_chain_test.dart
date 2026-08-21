/// The one coordination cost of letting two packages contribute to one chain.
///
/// The migration engine matches a chain to a database by folder names —
/// `<datasource>/<schema>` — not by which package the folder sits in, and it
/// imposes no contiguity on versions: it records an applied version per
/// (datasource, schema) pair and applies whatever it has not seen. That is what
/// lets `advanced_app_server` and this package both contribute to
/// `app_db/app_schema`, so nothing in the app server's package mentions a job
/// queue it never runs.
///
/// The price is that the two packages must not pick the same number, and neither
/// one can see the other's choice. A collision is not a loud failure either: the
/// engine records "version 4 applied" and the *second* file with that number is
/// never run at all — so the symptom is a missing table on a fresh deployment,
/// discovered at the first tick, in whichever environment was provisioned last.
///
/// **The bands are what make that impossible rather than merely detected.** The
/// app server numbers in `[000]`–`[099]`, this package from `[100]` up. Neither
/// has to know what the other has already used, because the ranges cannot
/// overlap — so the app server may add a migration whenever it likes and this
/// package never has to move. That is the whole reason for the gap between
/// `app_db`'s highest app-server migration and `[100]`; it is deliberate, not an
/// accounting error. (`auth_db` has a single contributing package and so stays
/// contiguous — a band buys nothing where nobody else can collide with you.)
///
/// So it is checked rather than trusted. This suite reads both packages'
/// directories off disk and checks each side stays inside its band, which is the
/// only place the arrangement can be verified — by construction, no single
/// package knows.
library;

import 'dart:io';

import 'package:test/test.dart';

/// This package's contribution to the chain.
const String _opsSchemaDir = 'database_migrations/app_db/app_schema/';

/// The app server's part of the same chain.
const String _appSchemaDir =
    '../advanced_app_server/database_migrations/app_db/app_schema/';

/// The first version this package may use.
///
/// Everything below belongs to `advanced_app_server`. Raising this would strand
/// the migration already deployed at [_opsBandFloor]; the way to give the app
/// server more room is to have had a wider band from the start, not to move the
/// floor afterwards.
const int _opsBandFloor = 100;

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
    Directory(directory)
        .listSync()
        .whereType<File>()
        .map((file) {
          return file.uri.pathSegments.last;
        })
        .where((name) => name.endsWith('.sql'))
        .toList()
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

      // The goal. The bands below are only the mechanism that reaches it, so
      // this is asserted directly and not inferred from them: if the bands are
      // ever changed, this is the test that still has to hold.
      expect(
        ops.intersection(app),
        isEmpty,
        reason:
            'app_db/app_schema versions collide: the engine would record '
            'the number as applied and silently never run the second file. '
            'One of the two packages has numbered outside its band — the '
            'app server owns [000]-[099], this package [$_opsBandFloor] and up',
      );
    });

    test('every migration this package ships is inside its band', () {
      // The half of the contract this package can actually keep. Numbering
      // below the floor would work on a fresh database and silently skip on
      // every database that already applied `[$_opsBandFloor]`, because the
      // engine only applies versions above the one it has recorded.
      for (final version in _versions(_opsSchemaDir)) {
        expect(
          version,
          greaterThanOrEqualTo(_opsBandFloor),
          reason:
              'this package owns [$_opsBandFloor] and up; '
              '[$version] is in the app server\'s band',
        );
      }
    });

    test('the app server stays below this package\'s band', () {
      // The other half. The app server cannot run this test — it does not
      // depend on this package and must not — so the obligation is checked
      // from the side that can see both directories.
      for (final version in _versions(_appSchemaDir)) {
        expect(
          version,
          lessThan(_opsBandFloor),
          reason:
              'the app server has numbered into the ops band: '
              '[$version] >= [$_opsBandFloor]. The bands exist so neither '
              'package has to know what the other has used — widen them '
              'deliberately or renumber, but do not overlap',
        );
      }
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

    test(
      'the datasource and schema folders are the ones the engine matches on',
      () {
        // `<datasource>/<schema>` is the whole matching rule, so a renamed folder
        // is a chain that quietly applies to nothing.
        expect(Directory(_opsSchemaDir).existsSync(), isTrue);
        expect(_opsSchemaDir, contains('app_db/app_schema'));
        expect(_appSchemaDir, contains('app_db/app_schema'));
      },
    );

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
