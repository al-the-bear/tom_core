import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// Tests for the connection-free surface of the db_migration module.
///
/// The MariaDB adaptor's SQL needs a live data source, so that is exercised by
/// `db_migration_db_test.dart`. This suite pins the types a caller touches
/// without a database — the [TomDbMigrationAdaptor] type binding, the
/// [TomDbVersion] row type, and the two exception types — plus the filename
/// parsing / ordering logic ([TomDbMigrations.parseMigrationFileName] and
/// [TomDbMigrations.orderMigrationNames]) extracted from the walk so the
/// version-ordering and anchored-name validation are unit-testable.
///
/// It also pins the **schema lifecycle**: [TomDbMigrations.migrateDataSource]
/// takes the migrator as an argument, so the walk over a data source's schemas
/// can be driven with a recording fake and no server at all. That matters
/// because the lifecycle was wrong and nothing here could see it — the
/// orchestrator reset the migrator once per *data source* while initialising it
/// once per *schema*, which aborted the run on the second schema and, with that
/// abort removed, would have judged the second schema's migrations against the
/// first schema's applied-version history.
void main() {
  // C-16 production-safety default: with no environment initialized on
  // TomRuntime, resolveActiveEnvironment falls back to the default environment
  // — under which only untagged migrations apply. Declared first so it observes
  // the pristine (uninitialized) TomRuntime before any later group sets it.
  group('C-16 uninitialized-environment fallback', () {
    test('falls back to the default environment when none is set', () {
      expect(
        TomDbMigrations.resolveActiveEnvironment(),
        defaultTomEnvironment.env,
      );
      final ordered = TomDbMigrations.orderMigrationNames([
        '[0]-schema',
        '[1]-demo_seed@dev',
      ]);
      // Under the default fallback, the @dev seed is skipped — production-safe.
      expect(
        TomDbMigrations.selectForEnvironment(
          ordered,
          TomDbMigrations.resolveActiveEnvironment(),
        ).map((e) => e.parsed.version),
        [0],
      );
    });
  });

  group('TomDbMigrationAdaptor', () {
    test('binds a migrator to a data-source type', () {
      const adaptor = TomDbMigrationAdaptor('mariadb');
      expect(adaptor.type, 'mariadb');
    });
  });

  // The adaptor scan runs at startup over a reflective registry no test can
  // populate, so the instantiation step is split out and driven directly. What
  // it must not do is what it used to: catch the constructor's error, report
  // only the candidate's name, and drop the cause — on a reflective startup
  // path, which is where an operator has the least context to reconstruct it.
  group('TomDbMigrations.instantiateMigrator', () {
    test('returns the instance when the candidate constructs a migrator', () {
      expect(
        TomDbMigrations.instantiateMigrator(
          'GoodMigrator',
          () => _RecordingMigrator(),
        ),
        isA<_RecordingMigrator>(),
      );
    });

    test('forwards the constructor error as the root exception', () {
      final cause = StateError('no zero-argument constructor');
      final error = _instantiationFailure(() => throw cause);

      expect(
        error.key,
        'db_migration.initialization.failed_to_instantiate_migrator',
      );
      // Identity, not equality: what the operator needs is the error object
      // itself — its type and its own fields — not a string resembling it.
      expect(error.rootException, same(cause));
    });

    test('names both the candidate and the cause in the message', () {
      final error = _instantiationFailure(
        () => throw StateError('field initialiser blew up'),
      );

      expect(error.defaultUserMessage, contains('BrokenMigrator'));
      expect(error.defaultUserMessage, contains('field initialiser blew up'));
    });

    test('carries the trace of the failing constructor, not of the scan', () {
      final error = _instantiationFailure(_throwingConstructor);

      // Left to capture its own construction site the exception records the
      // inside of the catch block, by which point the constructor has already
      // unwound — so the report names the scan and never the failure.
      expect(error.stack.toString(), contains('_throwingConstructor'));
    });

    test('a candidate that is not a migrator is rejected by name', () {
      TomDbMigrationException? error;
      try {
        TomDbMigrations.instantiateMigrator('NotAMigrator', () => 'a string');
      } on TomDbMigrationException catch (e) {
        error = e;
      }

      expect(error, isNotNull);
      expect(
        error!.key,
        'db_migration.initialization.'
        'migrator_does_not_implement_tom_db_migrator',
      );
      expect(error.defaultUserMessage, contains('NotAMigrator'));
      // Nothing threw, so there is no cause to forward. An absent root
      // exception here is the honest answer, not a dropped one.
      expect(error.rootException, isNull);
    });
  });

  group('TomDbVersion', () {
    test('has zero/empty defaults before any migration is recorded', () {
      final version = TomDbVersion();
      expect(version.installedRank, 0);
      expect(version.version, 0);
      expect(version.description, '');
      expect(version.script, '');
      expect(version.checksum, '');
      expect(version.installedBy, '');
      expect(version.success, 0);
    });

    test('records the fields of a single applied migration', () {
      final version = TomDbVersion()
        ..installedRank = 1
        ..version = 2
        ..description = 'add_orders'
        ..script = 'CREATE TABLE orders (id INT PRIMARY KEY);'
        ..checksum = '12345'
        ..success = 1;
      expect(version.installedRank, 1);
      expect(version.version, 2);
      expect(version.description, 'add_orders');
      expect(version.script, 'CREATE TABLE orders (id INT PRIMARY KEY);');
      expect(version.checksum, '12345');
      expect(version.success, 1);
    });
  });

  // The validation pattern must be anchored to the whole basename, so
  // a name that merely *contains* the pattern, or whose description holds a
  // digit, is rejected rather than silently misparsed.
  group('TomDbMigrations.parseMigrationFileName', () {
    test('parses a well-formed name into version and description', () {
      final parsed = TomDbMigrations.parseMigrationFileName('[2]-add_orders');
      expect(parsed.version, 2);
      expect(parsed.description, 'add_orders');
    });

    test('parses a multi-digit version', () {
      final parsed = TomDbMigrations.parseMigrationFileName('[10]-add_index');
      expect(parsed.version, 10);
      expect(parsed.description, 'add_index');
    });

    test('rejects a name with surrounding text', () {
      // An unanchored regex would accept this as version 5 / "temp".
      expect(
        () => TomDbMigrations.parseMigrationFileName('notes_[5]-temp'),
        throwsA(
          isA<TomDbMigrationException>().having(
            (e) => e.key,
            'key',
            'db_migration.migration.illegal_filename_in_migrations_directory',
          ),
        ),
      );
    });

    test('rejects a description containing a digit', () {
      // A description group that stops at the first digit would silently
      // truncate this to "add_orders_" instead of rejecting it.
      expect(
        () => TomDbMigrations.parseMigrationFileName('[1]-add_orders_2024'),
        throwsA(isA<TomDbMigrationException>()),
      );
    });

    test('rejects a name with no version bracket', () {
      expect(
        () => TomDbMigrations.parseMigrationFileName('add_orders'),
        throwsA(isA<TomDbMigrationException>()),
      );
    });
  });

  // Ordering must be by the numeric version, not lexicographic, so a
  // schema with more than nine versions still runs in numeric order.
  group('TomDbMigrations.orderMigrationNames', () {
    test('orders by numeric version, so [2] precedes [10]', () {
      // Lexicographically '[10]-...' sorts before '[2]-...'; numerically it must
      // come after.
      final ordered = TomDbMigrations.orderMigrationNames([
        '[10]-c',
        '[2]-b',
        '[1]-a',
      ]);
      expect(ordered.map((e) => e.parsed.version), [1, 2, 10]);
      expect(ordered.map((e) => e.basename), ['[1]-a', '[2]-b', '[10]-c']);
    });

    test('throws on any malformed name in the set', () {
      expect(
        () => TomDbMigrations.orderMigrationNames(['[1]-ok', 'bad-name']),
        throwsA(isA<TomDbMigrationException>()),
      );
    });

    // A version number is what the versioning table records and what
    // `applyMigration` decides "already applied" from, so two files claiming
    // one version cannot both be recorded distinguishably. Left unguarded the
    // pair applies twice on the first run and collides with itself on the
    // second — see the group below for the full sequence.
    test('two names claiming the same version are refused', () {
      expect(
        () => TomDbMigrations.orderMigrationNames(['[1]-schema', '[1]-seed']),
        throwsA(
          isA<TomDbMigrationException>().having(
            (e) => e.key,
            'key',
            'db_migration.migration.duplicate_migration_version',
          ),
        ),
      );
    });

    test('the message names the version and both basenames', () {
      // Sorted, not input order: the same broken tree has to produce the same
      // message on every machine, and the input order here is a directory
      // listing.
      expect(
        () => TomDbMigrations.orderMigrationNames(['[1]-seed', '[1]-schema']),
        throwsA(
          isA<TomDbMigrationException>().having(
            (e) => e.defaultUserMessage,
            'message',
            allOf(
              contains('1'),
              contains('[1]-schema'),
              contains('[1]-seed'),
              // The order the two are named in must not depend on the order
              // they were listed in.
              contains('[1]-schema and [1]-seed'),
            ),
          ),
        ),
      );
    });

    // Leading zeroes are not part of the version — `parseMigrationFileName`
    // reads an int — so a tree holding `[1]` and `[001]` is the same collision
    // wearing a disguise. A guard comparing the bracketed text would miss it.
    test('leading zeroes do not disguise a collision', () {
      expect(
        () => TomDbMigrations.orderMigrationNames(['[1]-a', '[001]-b']),
        throwsA(isA<TomDbMigrationException>()),
      );
    });

    // The guard runs before environment selection, so it fires on a pair no
    // single environment would ever apply together. That is deliberate: the
    // versioning table keys history on the version alone, so a box switched
    // from one environment to the other would meet the first tag's row while
    // being offered the second tag's script. A tree that is valid only on
    // some boxes is the failure this module exists to prevent.
    test('environment tags do not license a shared version', () {
      expect(
        () => TomDbMigrations.orderMigrationNames([
          '[1]-seed@dev',
          '[1]-seed@prod',
        ]),
        throwsA(isA<TomDbMigrationException>()),
      );
    });

    test('distinct versions still pass, tags or not', () {
      final ordered = TomDbMigrations.orderMigrationNames([
        '[2]-seed@dev',
        '[1]-schema',
      ]);
      expect(ordered.map((e) => e.parsed.version), [1, 2]);
    });
  });

  // Migrations are keyed by basename-without-extension, so two files that
  // differ only in extension claim the same key. Collecting them into a plain
  // map let whichever the directory listing happened to yield last overwrite
  // the other, and the run continued as if the tree had always held one file.
  // That is the opposite of how this module treats every other surprise in a
  // migrations directory — an unparseable name aborts, on the reasoning that a
  // stray file is more likely a migration nobody noticed was not running.
  group('TomDbMigrations.collectMigrationFiles', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('tom_mig_dupe_'));
    tearDown(() => dir.deleteSync(recursive: true));

    /// Writes [names] as empty files and returns the directory's entries.
    List<FileSystemEntity> entriesFor(Iterable<String> names) {
      for (final name in names) {
        File(p.join(dir.path, name)).writeAsStringSync('-- $name');
      }
      return dir.listSync();
    }

    test('collects one file per basename when nothing collides', () {
      final files = TomDbMigrations.collectMigrationFiles(
        entriesFor(['[1]-first.sql', '[2]-second.ddl']),
      );
      expect(files.keys.toList()..sort(), ['[1]-first', '[2]-second']);
    });

    test('two files differing only in extension abort rather than one '
        'silently winning', () {
      expect(
        () => TomDbMigrations.collectMigrationFiles(
          entriesFor(['[3]-add_index.sql', '[3]-add_index.ddl']),
        ),
        throwsA(isA<TomDbMigrationException>()),
      );
    });

    test('the abort names both colliding paths', () {
      Object? caught;
      try {
        TomDbMigrations.collectMigrationFiles(
          entriesFor(['[3]-add_index.sql', '[3]-add_index.ddl']),
        );
      } catch (error) {
        caught = error;
      }
      // Naming only the basename would leave the reader to find which two of
      // the directory's files are the pair.
      expect(caught, isNotNull);
      expect(caught.toString(), contains('[3]-add_index.sql'));
      expect(caught.toString(), contains('[3]-add_index.ddl'));
    });

    test('the two paths are named in a stable order, not encounter order', () {
      entriesFor(['[3]-add_index.sql', '[3]-add_index.ddl']);
      final sql = File(p.join(dir.path, '[3]-add_index.sql'));
      final ddl = File(p.join(dir.path, '[3]-add_index.ddl'));

      // Fed directly rather than through `listSync`, because the point is the
      // order the collector *encounters* the pair in — which a directory
      // listing does not let a test control, and which the file system is free
      // to vary between machines. If the message inherited it, the same broken
      // tree would report differently from one host to the next.
      String messageFor(List<File> entries) {
        try {
          TomDbMigrations.collectMigrationFiles(entries);
        } catch (error) {
          return error.toString();
        }
        return fail('expected a collision');
      }

      // `.ddl` sorts before `.sql`, so it is named first whichever way round
      // the pair arrives.
      for (final message in [
        messageFor([sql, ddl]),
        messageFor([ddl, sql]),
      ]) {
        expect(
          message.indexOf('[3]-add_index.ddl'),
          lessThan(message.indexOf('[3]-add_index.sql')),
          reason: message,
        );
      }
    });

    test('a stale editor artifact cannot displace the real migration', () {
      // The hazard that makes this more than a tidiness rule: `.orig` strips
      // to the same basename as `.sql`, so a backup file could be applied
      // *instead of* the migration it was a backup of.
      expect(
        () => TomDbMigrations.collectMigrationFiles(
          entriesFor(['[3]-add_index.sql', '[3]-add_index.orig']),
        ),
        throwsA(isA<TomDbMigrationException>()),
      );
    });

    test(
      'three files sharing a basename are still reported as a collision',
      () {
        expect(
          () => TomDbMigrations.collectMigrationFiles(
            entriesFor([
              '[3]-add_index.sql',
              '[3]-add_index.ddl',
              '[3]-add_index.txt',
            ]),
          ),
          throwsA(isA<TomDbMigrationException>()),
        );
      },
    );

    test('directories in the schema folder are ignored, not collected', () {
      Directory(p.join(dir.path, 'notes')).createSync();
      final files = TomDbMigrations.collectMigrationFiles(
        entriesFor(['[1]-first.sql']),
      );
      expect(files.keys, ['[1]-first']);
    });
  });

  // The statement splitter the applier drives lives in `TomSqlLexer` and is
  // pinned by `sql_lexer_test.dart` — it is shared with the DDL reader, so it
  // is tested where it lives rather than from either consumer.

  // The recorded checksum is what decides, on every later startup, whether an
  // already-applied migration has been edited. It therefore has to mean the
  // same thing in the process that *writes* it and in every process that reads
  // it back — including one on a different SDK, platform or isolate. These pin
  // the digest to a constant, so a change of algorithm is a red suite here
  // rather than a fleet-wide `checksum_mismatch` on the next deployment.
  group('a schema directory may hold what a machine put there', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('tom_mig_stray_'));
    tearDown(() => dir.deleteSync(recursive: true));

    /// Writes [names] as empty files and returns the directory's entries.
    List<FileSystemEntity> entriesFor(Iterable<String> names) {
      for (final name in names) {
        File(p.join(dir.path, name)).writeAsStringSync('-- $name');
      }
      return dir.listSync();
    }

    /// The basenames [names] collect to, sorted.
    List<String> collected(Iterable<String> names) =>
        TomDbMigrations.collectMigrationFiles(entriesFor(names)).keys.toList()
          ..sort();

    test('a dot-file is ignored, whatever it is', () {
      // The class, not a list: a dot-file is hidden by convention on every
      // platform this runs on, which is as close as a file system comes to
      // saying "not content". `.DS_Store` arrives from the macOS Finder,
      // `.gitkeep` from whoever needed the empty directory committed, and the
      // swap file from an editor left open on the migration beside it.
      expect(
        collected([
          '[1]-first.sql',
          '.DS_Store',
          '.gitkeep',
          '.gitignore',
          // vim's swap file for the migration beside it; the leading dot is
          // what makes it invisible here.
          '.[1]-first.sql.swp',
        ]),
        ['[1]-first'],
      );
    });

    test('the three named files are ignored, in any case', () {
      // A fixed list rather than a pattern, so a reader can see all of it. Two
      // are written by a file explorer and one by a person documenting the
      // directory — none of them by the author of a migration.
      expect(
        collected(['[1]-first.sql', 'README.md', 'Thumbs.db', 'desktop.ini']),
        ['[1]-first'],
      );
      expect(collected(['[1]-first.sql', 'readme.md', 'THUMBS.DB']), [
        '[1]-first',
      ]);
    });

    test('an ignored file does not collide with a migration', () {
      // The skip happens before the duplicate-basename check, so a `README.md`
      // beside a `README.sql` — or any pair an ignored name could strip to —
      // cannot be reported as a collision.
      expect(collected(['[1]-first.sql', 'readme.md', 'readme.sql']), [
        '[1]-first',
        'readme',
      ]);
    });

    test('a directory of nothing but ignorable files collects nothing', () {
      expect(collected(['.DS_Store', 'README.md']), isEmpty);
    });

    test('a mis-typed migration is still collected, and still refused', () {
      // The line is drawn here rather than at the extension precisely for
      // this: under an extension filter `[3]-add_index.sqll` would be
      // invisible, and a migration that was meant to run simply would not.
      // Collected, it reaches the parser, which reports it.
      expect(collected(['[3]-add_index.sqll']), ['[3]-add_index']);
      expect(
        () => TomDbMigrations.orderMigrationNames(['[3]-add_index.sqll']),
        throwsA(
          isA<TomDbMigrationException>().having(
            (e) => e.key,
            'key',
            'db_migration.migration.illegal_filename_in_migrations_directory',
          ),
        ),
      );
    });

    test('an editor backup is still a duplicate, not an ignored file', () {
      // `.orig` and `.bak` are not dot-files and are not on the list, which is
      // deliberate: a backup strips to the same key as the migration it is a
      // backup *of*, so tolerating it would let the losing file be the one
      // that was meant to run.
      expect(
        () => TomDbMigrations.collectMigrationFiles(
          entriesFor(['[3]-add_index.sql', '[3]-add_index.orig']),
        ),
        throwsA(
          isA<TomDbMigrationException>().having(
            (e) => e.key,
            'key',
            'db_migration.migration.duplicate_migration_basename',
          ),
        ),
      );
    });

    test('a stray name nobody accounted for still aborts the run', () {
      // What the policy does not do. A file a developer put there under a name
      // that is neither a migration nor recognised clutter is still the case
      // this module exists to be loud about.
      expect(collected(['notes_about_the_chain.txt']), [
        'notes_about_the_chain',
      ]);
      expect(
        () => TomDbMigrations.orderMigrationNames(['notes_about_the_chain']),
        throwsA(isA<TomDbMigrationException>()),
      );
    });

    test('the rule is one predicate, and it is the one the collector uses', () {
      // Named so the policy can be read and asserted on its own rather than
      // only through a directory listing.
      expect(TomDbMigrations.isNotAMigrationFile('.DS_Store'), isTrue);
      expect(TomDbMigrations.isNotAMigrationFile('README.md'), isTrue);
      expect(TomDbMigrations.isNotAMigrationFile('[1]-first.sql'), isFalse);
      expect(TomDbMigrations.isNotAMigrationFile('[1]-first.orig'), isFalse);
    });
  });

  group('TomSqlMigrationAdaptor.checksumOf', () {
    test('a known script produces a known constant digest', () {
      // The constant is the whole point: it is the contract between a row
      // written last year and the code reading it today. `String.hashCode`
      // could not be written down like this — that is what made it wrong.
      expect(
        TomSqlMigrationAdaptor.checksumOf(
          'CREATE TABLE orders (id INT PRIMARY KEY);',
        ),
        '9ad9167cb37c929c8f439bcc29682d4f4b6a963310c983d1bdd35ebc21634483',
      );
    });

    test('the empty script produces the empty SHA-256', () {
      // Pins the encoding as much as the algorithm: this is the digest of zero
      // bytes, so an implementation that hashed a quoted or padded form of the
      // script would not land here.
      expect(
        TomSqlMigrationAdaptor.checksumOf(''),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });

    test('the digest is 64 lowercase hex characters', () {
      expect(
        TomSqlMigrationAdaptor.checksumOf('SELECT 1'),
        matches(RegExp(r'^[0-9a-f]{64}$')),
      );
    });

    test('a one-character edit changes the digest', () {
      // The guard exists to catch edits, so an edit must move the value.
      expect(
        TomSqlMigrationAdaptor.checksumOf('SELECT 1'),
        isNot(TomSqlMigrationAdaptor.checksumOf('SELECT 2')),
      );
    });

    test('non-ASCII script text hashes by its UTF-8 bytes', () {
      // A seed migration carrying accented data is ordinary; the digest must
      // not depend on how the string happens to be represented in memory.
      expect(
        TomSqlMigrationAdaptor.checksumOf("INSERT INTO t VALUES ('é');"),
        TomSqlMigrationAdaptor.checksumOf("INSERT INTO t VALUES ('é');"),
      );
    });

    test('every digest it produces is well-formed', () {
      // The pair has to agree: whatever `checksumOf` writes, the readability
      // guard must accept, or the adaptor would reject its own rows.
      for (final script in ['', 'SELECT 1', 'CREATE TABLE t (id INT);', 'é']) {
        expect(
          TomSqlMigrationAdaptor.isWellFormedChecksum(
            TomSqlMigrationAdaptor.checksumOf(script),
          ),
          isTrue,
          reason: 'checksumOf($script) must be readable back',
        );
      }
    });

    test('the digest fits the checksum column', () {
      // The column is VARCHAR(200); a digest longer than that would be
      // truncated on write and mismatch on every later read.
      expect(
        TomSqlMigrationAdaptor.checksumOf('SELECT 1').length,
        lessThanOrEqualTo(200),
      );
    });
  });

  // A stored checksum the adaptor cannot read is a different fact from a
  // checksum that disagrees, and it wants a different response: a mismatch says
  // "find the edit", an unreadable value says "this row was not written by this
  // adaptor — repair it". Conflating them sends the operator looking for an edit
  // that never happened, so the shape is decided here, once.
  group('TomSqlMigrationAdaptor.isWellFormedChecksum', () {
    test('accepts a 64-character lowercase hex digest', () {
      expect(
        TomSqlMigrationAdaptor.isWellFormedChecksum(
          '9ad9167cb37c929c8f439bcc29682d4f4b6a963310c983d1bdd35ebc21634483',
        ),
        isTrue,
      );
    });

    test('rejects the empty string the column defaults to', () {
      // `checksum VARCHAR(200) NOT NULL DEFAULT ''` — so any row inserted by
      // anything other than applyMigration carries exactly this.
      expect(TomSqlMigrationAdaptor.isWellFormedChecksum(''), isFalse);
    });

    test('rejects a decimal hash code — the format this module used to '
        'store', () {
      // The realistic case: a versioning table written before the checksum
      // became a content digest. It has to be reported as unreadable, not as a
      // mismatch, or every such row accuses someone of an edit.
      expect(TomSqlMigrationAdaptor.isWellFormedChecksum('12345'), isFalse);
      expect(
        TomSqlMigrationAdaptor.isWellFormedChecksum('-1234567890'),
        isFalse,
      );
    });

    test('rejects uppercase hex', () {
      // `checksumOf` never produces it, so accepting it would mean accepting a
      // value this module cannot have written — and it would compare unequal to
      // the lowercase digest anyway, reporting a mismatch for a row that is
      // really just in the wrong format.
      expect(
        TomSqlMigrationAdaptor.isWellFormedChecksum(
          '9AD9167CB37C929C8F439BCC29682D4F4B6A963310C983D1BDD35EBC21634483',
        ),
        isFalse,
      );
    });

    test('rejects a digest one character short or long', () {
      final digest = TomSqlMigrationAdaptor.checksumOf('SELECT 1');
      expect(
        TomSqlMigrationAdaptor.isWellFormedChecksum(
          digest.substring(0, digest.length - 1),
        ),
        isFalse,
      );
      expect(TomSqlMigrationAdaptor.isWellFormedChecksum('${digest}a'), false);
    });

    test('rejects a digest with surrounding whitespace or text', () {
      // The check must be anchored: an unanchored pattern would accept a
      // padded or commented value that no comparison could ever match.
      final digest = TomSqlMigrationAdaptor.checksumOf('SELECT 1');
      expect(TomSqlMigrationAdaptor.isWellFormedChecksum(' $digest'), isFalse);
      expect(TomSqlMigrationAdaptor.isWellFormedChecksum('$digest\n'), isFalse);
      expect(
        TomSqlMigrationAdaptor.isWellFormedChecksum('sha256:$digest'),
        isFalse,
      );
    });

    test('rejects 64 characters that are not all hex', () {
      expect(
        TomSqlMigrationAdaptor.isWellFormedChecksum('z' * 64),
        isFalse,
        reason: 'a length-only check would accept this',
      );
    });
  });

  // C-16: an optional `@<env>[,<env>…]` tag on the description selects the
  // environment(s) a migration belongs to; untagged migrations apply
  // everywhere. These pin the tag parse, the per-environment predicate, and the
  // pure selection that the engine drives from TomRuntime.
  group('C-16 environment tag parsing', () {
    test('an untagged name parses to an empty (all-environments) tag', () {
      final parsed = TomDbMigrations.parseMigrationFileName('[0]-app_core');
      expect(parsed.version, 0);
      expect(parsed.description, 'app_core');
      expect(parsed.environments, isEmpty);
    });

    test('a single @env tag parses to a one-element list', () {
      final parsed = TomDbMigrations.parseMigrationFileName(
        '[3]-demo_seed@dev',
      );
      expect(parsed.version, 3);
      expect(parsed.description, 'demo_seed');
      expect(parsed.environments, ['dev']);
    });

    test('a comma list parses to each environment in file order', () {
      final parsed = TomDbMigrations.parseMigrationFileName(
        '[4]-perf_probe@dev,test',
      );
      expect(parsed.description, 'perf_probe');
      expect(parsed.environments, ['dev', 'test']);
    });

    test('rejects a trailing comma in the tag', () {
      expect(
        () => TomDbMigrations.parseMigrationFileName('[1]-seed@dev,'),
        throwsA(isA<TomDbMigrationException>()),
      );
    });

    test('rejects a digit inside an environment name', () {
      expect(
        () => TomDbMigrations.parseMigrationFileName('[1]-seed@dev,env2'),
        throwsA(isA<TomDbMigrationException>()),
      );
    });

    test('rejects an empty tag (bare @)', () {
      expect(
        () => TomDbMigrations.parseMigrationFileName('[1]-seed@'),
        throwsA(isA<TomDbMigrationException>()),
      );
    });
  });

  group('TomMigrationFileName.appliesInEnvironment', () {
    test('an untagged migration applies in every environment', () {
      const untagged = TomMigrationFileName(0, 'schema');
      expect(untagged.appliesInEnvironment('prod'), isTrue);
      expect(untagged.appliesInEnvironment('dev'), isTrue);
      expect(untagged.appliesInEnvironment('anything'), isTrue);
    });

    test('a tagged migration applies only for a listed environment', () {
      const tagged = TomMigrationFileName(3, 'demo_seed', ['dev', 'test']);
      expect(tagged.appliesInEnvironment('dev'), isTrue);
      expect(tagged.appliesInEnvironment('test'), isTrue);
      expect(tagged.appliesInEnvironment('prod'), isFalse);
    });
  });

  // The C-16 done-bar: the same demo-seed migration applies under `dev` and is
  // skipped under `prod`, while every untagged (schema) migration applies in
  // both. Proven here at the pure-selection level (the actual applyMigration DB
  // write is the live-DB follow-up) so it is verified "at two environment
  // values" without a connection.
  group('TomDbMigrations.selectForEnvironment (C-16 done-bar)', () {
    final ordered = TomDbMigrations.orderMigrationNames([
      '[0]-app_core_schema',
      '[1]-authz_grants',
      '[2]-admin_seed@prod,dev,test',
      '[3]-demo_seed@dev,test',
      '[4]-perf_probe@dev',
    ]);

    test('under dev the demo seed and probe are included', () {
      final selected = TomDbMigrations.selectForEnvironment(ordered, 'dev');
      expect(selected.map((e) => e.parsed.version), [0, 1, 2, 3, 4]);
    });

    test('under prod the @dev/@test-only migrations are skipped', () {
      final selected = TomDbMigrations.selectForEnvironment(ordered, 'prod');
      // Untagged schema (0,1) and the @prod-tagged admin seed (2) survive; the
      // demo seed (3, @dev,test) and probe (4, @dev) are dropped — no rows.
      expect(selected.map((e) => e.parsed.version), [0, 1, 2]);
      expect(
        selected.every((e) => e.parsed.appliesInEnvironment('prod')),
        isTrue,
      );
    });
  });

  // The engine resolves the active environment via TomRuntime (never a raw
  // Platform read, G-ENV-1). TomRuntime is global static state; dart test runs
  // this file in its own isolate, so setting the environment here does not leak
  // to other files.
  group('TomDbMigrations.resolveActiveEnvironment', () {
    test('reads the environment set on TomRuntime and drives selection', () {
      final ordered = TomDbMigrations.orderMigrationNames([
        '[0]-schema',
        '[1]-demo_seed@dev',
      ]);

      TomRuntime.addEnvironment(
        const TomEnvironment('dev', isDevelopment: true),
      );
      TomRuntime.addEnvironment(const TomEnvironment('prod'));

      TomRuntime.setCurrentEnvironment('dev');
      expect(TomDbMigrations.resolveActiveEnvironment(), 'dev');
      expect(
        TomDbMigrations.selectForEnvironment(
          ordered,
          TomDbMigrations.resolveActiveEnvironment(),
        ).map((e) => e.parsed.version),
        [0, 1],
      );

      TomRuntime.setCurrentEnvironment('prod');
      expect(TomDbMigrations.resolveActiveEnvironment(), 'prod');
      expect(
        TomDbMigrations.selectForEnvironment(
          ordered,
          TomDbMigrations.resolveActiveEnvironment(),
        ).map((e) => e.parsed.version),
        [0],
      );
    });
  });

  // A migrator's applied-version state belongs to one (data source, schema)
  // pair, so the walk has to rebind it per schema. These drive the real
  // committed fixture tree — which carries two schemas under one data source
  // precisely so this is observable — through a recording fake, and assert the
  // call sequence rather than its effect on a database.
  group('TomDbMigrations.migrateDataSource schema lifecycle', () {
    /// The committed fixture tree's data-source directory.
    final dataSourceDirectory = Directory(
      'test/fixtures/migrations/tom_core_server_test',
    );

    /// A data source the fake migrator only reads a name from — no connection
    /// is opened, and it is deliberately not registered, so this leaves no
    /// global state behind.
    TomDataSourceInfo dsi() =>
        TomDataSourceInfo('tom_core_server_test', <String, dynamic>{})
          ..type = 'mariadb';

    Future<List<String>> eventsOf(_RecordingMigrator migrator) async {
      await TomDbMigrations.migrateDataSource(
        migrator,
        dsi(),
        dataSourceDirectory,
        defaultTomEnvironment.env,
      );
      return migrator.events;
    }

    // Without two schemas in the tree the assertions below are vacuous: one
    // schema cannot distinguish per-schema from per-data-source state. So the
    // fixture's shape is asserted, not assumed.
    test('the fixture data source really has more than one schema', () {
      final schemas =
          dataSourceDirectory
              .listSync()
              .whereType<Directory>()
              .map((d) => d.path.split(Platform.pathSeparator).last)
              .toList()
            ..sort();
      expect(schemas, ['fixture_schema', 'fixture_schema_two']);
    });

    test('resets and initialises once per schema, not once per run', () async {
      final events = await eventsOf(_RecordingMigrator());

      // Two schemas, so two of each. The defect was exactly one reset for the
      // whole data source against two initialisations.
      expect(events.where((e) => e == 'reset'), hasLength(2));
      expect(events.where((e) => e.startsWith('init:')), hasLength(2));
      expect(
        events
            .where((e) => e.startsWith('init:'))
            .map((e) => e.substring(5))
            .toList()
          ..sort(),
        ['fixture_schema', 'fixture_schema_two'],
      );
    });

    test('every initialisation is preceded by its own reset', () async {
      final events = await eventsOf(_RecordingMigrator());

      for (var i = 0; i < events.length; i++) {
        if (!events[i].startsWith('init:')) continue;
        expect(
          i > 0 && events[i - 1] == 'reset',
          isTrue,
          reason:
              'Initialising without first dropping the previous schema\'s '
              'state is what let one schema\'s applied-version history stand '
              'for the next one\'s. Events: $events',
        );
      }
    });

    test('no migration is applied to a schema other than the last '
        'initialised one', () async {
      final events = await eventsOf(_RecordingMigrator());

      String? current;
      var applied = 0;
      for (final event in events) {
        if (event.startsWith('init:')) {
          current = event.substring(5);
          continue;
        }
        if (!event.startsWith('apply:')) continue;
        applied++;
        expect(
          event.split(':')[1],
          current,
          reason:
              'a migration judged against another schema\'s version list is '
              'the silent half of this defect',
        );
      }
      // Both fixture migrations reached the migrator — an assertion that
      // passes because nothing was applied would prove nothing.
      expect(applied, 2);
    });

    test('both schemas are at version 0, which is what makes the fixture '
        'discriminating', () async {
      final events = await eventsOf(_RecordingMigrator());
      final applies = events.where((e) => e.startsWith('apply:')).toList();

      // Same version, different schemas: a shared version list would read the
      // second one as already applied.
      expect(applies.map((e) => e.split(':')[2]).toSet(), {'0'});
      expect(applies.map((e) => e.split(':')[1]).toSet(), {
        'fixture_schema',
        'fixture_schema_two',
      });
    });
  });

  // The engine half of the collision bar. The collector is unit-tested above;
  // this proves the walk actually routes through it, and that the collision
  // stops the run instead of applying whichever file won the map.
  group('TomDbMigrations.migrateDataSource duplicate basenames', () {
    late Directory root;
    late Directory schema;

    setUp(() {
      root = Directory.systemTemp.createTempSync('tom_mig_dupe_ds_');
      schema = Directory(p.join(root.path, 'fixture_schema'))
        ..createSync(recursive: true);
    });
    tearDown(() => root.deleteSync(recursive: true));

    TomDataSourceInfo dsi() =>
        TomDataSourceInfo('tom_core_server_test', <String, dynamic>{})
          ..type = 'mariadb';

    void write(String name, String sql) =>
        File(p.join(schema.path, name)).writeAsStringSync(sql);

    test('a collision aborts the run', () async {
      write('[0]-create_it.sql', 'CREATE TABLE a (id BIGINT);');
      write('[0]-create_it.ddl', 'CREATE TABLE b (id BIGINT);');

      await expectLater(
        TomDbMigrations.migrateDataSource(
          _RecordingMigrator(),
          dsi(),
          root,
          defaultTomEnvironment.env,
        ),
        throwsA(isA<TomDbMigrationException>()),
      );
    });

    test('nothing is applied when the schema collides', () async {
      write('[0]-create_it.sql', 'CREATE TABLE a (id BIGINT);');
      write('[0]-create_it.ddl', 'CREATE TABLE b (id BIGINT);');
      final migrator = _RecordingMigrator();

      await expectLater(
        TomDbMigrations.migrateDataSource(
          migrator,
          dsi(),
          root,
          defaultTomEnvironment.env,
        ),
        throwsA(isA<TomDbMigrationException>()),
      );
      // Applying one of an ambiguous pair and *then* aborting would leave the
      // database holding a migration nobody chose.
      expect(migrator.events.where((e) => e.startsWith('apply:')), isEmpty);
    });

    test('a schema with distinct basenames still runs', () async {
      write('[0]-create_it.sql', 'CREATE TABLE a (id BIGINT);');
      write('[1]-alter_it.sql', 'ALTER TABLE a ADD COLUMN n INT;');
      final migrator = _RecordingMigrator();

      await TomDbMigrations.migrateDataSource(
        migrator,
        dsi(),
        root,
        defaultTomEnvironment.env,
      );
      expect(
        migrator.events.where((e) => e.startsWith('apply:')),
        hasLength(2),
      );
    });
  });

  // The basename collector above catches two files that strip to one key. Two
  // files claiming one *version* strip to two different keys, so they pass it
  // untouched — and a version, not a basename, is what the versioning table
  // records and what `applyMigration` decides "already applied" from.
  //
  // Unguarded, the pair produced a three-stage failure. Both scripts applied in
  // one pass, because `MariadbMigrationAdaptor.versions` is a snapshot taken at
  // initialisation and is not extended as migrations run, so the second call
  // could not see the first. Their relative order was undefined — equal keys
  // make the sort arbitrary — so an untagged `[1]-schema` and a `[1]-seed@dev`
  // could run seed-before-schema on one machine and the other way on the next.
  // And the versioning table was left holding two rows for version 1, so the
  // *following* run met the first of them while being offered the second's
  // script and raised `description_mismatch` — a message that accuses someone
  // of editing a past migration when nobody had.
  group('TomDbMigrations.migrateDataSource duplicate versions', () {
    late Directory root;
    late Directory schema;

    setUp(() {
      root = Directory.systemTemp.createTempSync('tom_mig_dupe_ver_');
      schema = Directory(p.join(root.path, 'fixture_schema'))
        ..createSync(recursive: true);
    });
    tearDown(() => root.deleteSync(recursive: true));

    TomDataSourceInfo dsi() =>
        TomDataSourceInfo('tom_core_server_test', <String, dynamic>{})
          ..type = 'mariadb';

    void write(String name, String sql) =>
        File(p.join(schema.path, name)).writeAsStringSync(sql);

    Future<void> run(TomDbMigrator migrator, String environment) =>
        TomDbMigrations.migrateDataSource(migrator, dsi(), root, environment);

    test('nothing is applied when two files claim one version', () async {
      write('[1]-schema.sql', 'CREATE TABLE a (id BIGINT);');
      write('[1]-seed.sql', 'INSERT INTO a VALUES (1);');
      final migrator = _RecordingMigrator();

      await expectLater(
        run(migrator, defaultTomEnvironment.env),
        throwsA(isA<TomDbMigrationException>()),
      );
      // Aborting *after* applying one of the two would leave the database
      // holding half a collision, and the versioning row that makes the next
      // run fail.
      expect(migrator.events.where((e) => e.startsWith('apply:')), isEmpty);
    });

    // The reachable shape of the defect, and the one a tag makes easy to write
    // by accident: neither file collides by basename, and both apply in `dev`.
    test('an untagged and a tagged file cannot share a version', () async {
      write('[1]-schema.sql', 'CREATE TABLE a (id BIGINT);');
      write('[1]-seed@dev.sql', 'INSERT INTO a VALUES (1);');
      final migrator = _RecordingMigrator();

      await expectLater(
        run(migrator, 'dev'),
        throwsA(isA<TomDbMigrationException>()),
      );
      expect(migrator.events.where((e) => e.startsWith('apply:')), isEmpty);
    });

    // Same tree, an environment in which only one of the pair would have been
    // selected. It still aborts: a tree may not be valid on prod and broken on
    // dev, because the collision it carries is in the history it will write,
    // not in the run that writes it.
    test('the tree is refused in an environment that would apply only '
        'one of the pair', () async {
      write('[1]-schema.sql', 'CREATE TABLE a (id BIGINT);');
      write('[1]-seed@dev.sql', 'INSERT INTO a VALUES (1);');
      final migrator = _RecordingMigrator();

      await expectLater(
        run(migrator, defaultTomEnvironment.env),
        throwsA(isA<TomDbMigrationException>()),
      );
      expect(migrator.events.where((e) => e.startsWith('apply:')), isEmpty);
    });

    test('a schema with distinct versions still runs', () async {
      write('[1]-schema.sql', 'CREATE TABLE a (id BIGINT);');
      write('[2]-seed@dev.sql', 'INSERT INTO a VALUES (1);');
      final migrator = _RecordingMigrator();

      await run(migrator, 'dev');
      expect(
        migrator.events.where((e) => e.startsWith('apply:')),
        hasLength(2),
      );
    });
  });

  // A migration tree the engine is told to walk has to be there. Walking a
  // path that does not exist used to surface `PathNotFoundException` — a
  // `dart:io` type from outside this module's exception family, carrying no key
  // and no mention of migrations — so a caller matching on
  // TomDbMigrationException saw a wrong path as an unrelated crash.
  group('TomDbMigrations missing migrations directory', () {
    late Directory root;

    setUp(() => root = Directory.systemTemp.createTempSync('tom_mig_absent_'));
    tearDown(() => root.deleteSync(recursive: true));

    /// A path under the temp root that is deliberately never created.
    String absent() => p.join(root.path, 'not_created');

    TomDataSourceInfo dsi() =>
        TomDataSourceInfo('tom_core_server_test', <String, dynamic>{})
          ..type = 'mariadb';

    test('migrateDatabases aborts inside the module exception family', () async {
      // Reflection is deliberately *not* initialized here. The test therefore
      // also pins the order: were the guard placed after the adaptor scan, this
      // would fail with a StateError about reflection — naming the runtime
      // instead of the path the caller actually got wrong.
      await expectLater(
        TomDbMigrations.migrateDatabases(absent()),
        throwsA(isA<TomDbMigrationException>()),
      );
    });

    test('the abort carries the shared missing-directory key', () async {
      final error = await _errorOf(
        () => TomDbMigrations.migrateDatabases(absent()),
      );
      expect(
        (error as TomDbMigrationException).key,
        'db_migration.migration.migrations_directory_not_found',
      );
    });

    test('the abort names the path and where it resolved to', () async {
      // A relative path plus a wrong working directory is the common cause, and
      // the given path alone cannot distinguish the two — so the message has to
      // say what it resolved to as well.
      final error = await _errorOf(
        () => TomDbMigrations.migrateDatabases('zz_no_such_migrations_dir'),
      );
      expect(error.toString(), contains('zz_no_such_migrations_dir'));
      expect(
        error.toString(),
        contains(Directory('zz_no_such_migrations_dir').absolute.path),
      );
      expect(error.toString(), contains('resolved to'));
    });

    test('an absolute path is not resolved against itself', () async {
      // The other branch. `absent()` is already absolute, so repeating it under
      // "resolved to" would be noise in the one message a reader is squinting
      // at to spot a wrong path.
      final error = await _errorOf(
        () => TomDbMigrations.migrateDatabases(absent()),
      );
      expect(error.toString(), contains(absent()));
      expect(error.toString(), isNot(contains('resolved to')));
    });

    test('migrateDataSource aborts the same way', () async {
      final error = await _errorOf(
        () => TomDbMigrations.migrateDataSource(
          _RecordingMigrator(),
          dsi(),
          Directory(absent()),
          defaultTomEnvironment.env,
        ),
      );
      expect(error, isA<TomDbMigrationException>());
      expect(
        (error as TomDbMigrationException).key,
        'db_migration.migration.migrations_directory_not_found',
      );
    });

    test('an existing but empty tree is not an error', () async {
      // The negative direction. "Nothing to migrate" is a legitimate state — a
      // guard that rejected it would break every deployment whose migrations
      // have not been written yet.
      await TomDbMigrations.migrateDataSource(
        _RecordingMigrator(),
        dsi(),
        root,
        defaultTomEnvironment.env,
      );
    });

    test(
      'a tree holding only files, no schema directories, is not an error',
      () async {
        File(p.join(root.path, 'README.md')).writeAsStringSync('not a schema');
        final migrator = _RecordingMigrator();

        await TomDbMigrations.migrateDataSource(
          migrator,
          dsi(),
          root,
          defaultTomEnvironment.env,
        );
        expect(migrator.events, isEmpty);
      },
    );
  });

  // The adaptor half of the same invariant. Whether a migration counts as
  // already applied is read from `versions`, which describes one schema, so
  // applying against a schema the instance is not bound to is refused rather
  // than answered from the wrong history. The mismatched-pair case needs a
  // successful initialisation and therefore a server (see
  // `db_migration_db_test.dart`); the unbound case is reachable here because
  // the guard runs before any statement is issued.
  group('MariadbMigrationAdaptor schema binding', () {
    final dsi = TomDataSourceInfo('some_ds', <String, dynamic>{});

    test('refuses to apply before initializeMigration has bound it', () async {
      await expectLater(
        MariadbMigrationAdaptor().applyMigration(
          dsi,
          'schema_a',
          0,
          'create_thing',
          'SELECT 1',
        ),
        throwsA(
          isA<MariadbMigrationException>().having(
            (e) => e.key,
            'key',
            'mariadb_migration.apply_migration.not_initialized_for_schema',
          ),
        ),
      );
    });

    test('reset leaves no applied-version state behind', () {
      final adaptor = MariadbMigrationAdaptor()
        ..versions.add(TomDbVersion()..version = 7);
      adaptor.reset();
      expect(adaptor.versions, isEmpty);
    });

    test('reset unbinds, so a later apply is refused again', () async {
      final adaptor = MariadbMigrationAdaptor()..reset();
      await expectLater(
        adaptor.applyMigration(dsi, 'schema_a', 0, 'create_thing', 'SELECT 1'),
        // The key is asserted, not merely the type: without the binding check
        // this call still throws a MariadbMigrationException — the one wrapping
        // the datasource failure it runs into next — so a type-only assertion
        // would pass whether or not the migration was refused.
        throwsA(
          isA<MariadbMigrationException>().having(
            (e) => e.key,
            'key',
            'mariadb_migration.apply_migration.not_initialized_for_schema',
          ),
        ),
      );
    });
  });

  group('exception types', () {
    test('TomDbMigrationException is a TomServerException', () {
      final exception = TomDbMigrationException('key', 'message');
      expect(exception, isA<TomServerException>());
      expect(exception.key, 'key');
    });

    test('MariadbMigrationException is a TomServerException', () {
      final exception = MariadbMigrationException('key', 'message');
      expect(exception, isA<TomServerException>());
      expect(exception.key, 'key');
    });
  });

  // The prose describing this module drifted away from the parser: the class
  // dartdoc claimed migrations run in *name* order long after the sort had been
  // moved onto the parsed integer, and every text stating the grammar omitted
  // the optional environment tag — so C-16 was live behaviour a reader could
  // not learn about. Prose cannot be kept honest by review alone; this group
  // makes the parser the arbiter of what the prose is allowed to say.
  group('documentation matches the parser', () {
    test('every grammar the docs state is the grammar the parser enforces', () {
      final canonical = _normalizedGrammar(_grammarQuotedByParser());
      for (final site in _grammarSites) {
        final stated = _statedGrammars(File(site).readAsStringSync());
        expect(
          stated,
          isNotEmpty,
          reason:
              '$site is registered as a site that states the file-name '
              'grammar, but states none. Either restore the grammar or drop '
              'the site from _grammarSites.',
        );
        for (final grammar in stated) {
          expect(
            _normalizedGrammar(grammar),
            canonical,
            reason:
                '$site states the grammar as "$grammar", which is not what '
                'parseMigrationFileName accepts. The parser is the source of '
                'truth — update the text.',
          );
        }
      }
    });

    test('every migration file name the docs exhibit actually parses', () {
      for (final site in _grammarSites) {
        final source = File(site).readAsStringSync();
        // A description letter is required, so the `[2]-…` shorthand the prose
        // uses to talk about *ordering* is not mistaken for an exhibited name.
        // Past that the token runs to its delimiter and takes every character
        // with it, legal or not — a class narrow enough to be "the characters a
        // name may contain" would stop short of the very character that makes
        // an exhibited name illegal, and pass it.
        final names = RegExp(
          '\\[\\d+\\]-[A-Za-z_][^\\s`\'"|)]*',
        ).allMatches(source);
        expect(
          names,
          isNotEmpty,
          reason: '$site exhibits no migration file name',
        );
        for (final match in names) {
          final basename = _exhibitedBasename(match.group(0)!);
          expect(
            () => TomDbMigrations.parseMigrationFileName(basename),
            returnsNormally,
            reason:
                '$site shows "${match.group(0)}" as a migration file name, '
                'but the parser rejects it.',
          );
        }
      }
    });

    test('no text still claims migrations run in name order', () {
      for (final site in _grammarSites) {
        expect(
          File(site).readAsStringSync(),
          isNot(contains('ascending name order')),
          reason:
              '$site claims name order; orderMigrationNames sorts on the '
              'parsed integer, under which [2] precedes [10].',
        );
      }
    });
  });

  group('The example runs green', () {
    final examplePath = p.join(
      'example',
      'db_migration',
      'db_migration_example.dart',
    );

    test('under exactly the command its header documents', () async {
      final result = await Process.run(Platform.resolvedExecutable, [
        'run',
        examplePath,
      ]);
      expect(
        result.exitCode,
        0,
        reason: 'example failed: ${result.stdout}${result.stderr}',
      );
      // The transcript's step numbers, in the order they were printed. The
      // whole list is compared rather than each step being looked for in turn,
      // because only one of the two failures is caught by looking: a step that
      // stopped printing fails either way, but a step *added* without being
      // listed here is a surface nothing checks — and that is the state this
      // example was in, with four steps standing for ten connection-free
      // surfaces and a header claiming the rest needed a database.
      final printed = RegExp(r'^(\d+)\. ', multiLine: true)
          .allMatches(result.stdout as String)
          .map((match) => match.group(1)!)
          .toList();
      expect(printed, [
        for (var step = 1; step <= 10; step++) '$step',
      ], reason: 'the example demonstrates ten surfaces, in order');
    });

    test('with its expectations checked rather than asserted', () {
      // The example's own header gives `dart run`, under which `assert` is
      // compiled out. Checks that vanish under the documented invocation are
      // worse than none: the transcript still looks plausible and the exit
      // code is still 0.
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

    test('demonstrating the surface it says it demonstrates', () {
      // A header list and a transcript can drift apart in either direction, and
      // both directions are silent: a surface dropped from the code leaves a
      // header entry pointing at nothing, and one added without a header entry
      // is undocumented. Neither is visible to the step-count check above,
      // which only reads what was printed.
      final source = File(examplePath).readAsStringSync();
      final headerEntries = RegExp(
        r'^///\s+(\d+)\. ',
        multiLine: true,
      ).allMatches(source).map((match) => match.group(1)!).toList();
      expect(headerEntries, [for (var step = 1; step <= 10; step++) '$step']);

      // Every type the todo counted as the module's connection-free surface,
      // named in the file the reader is sent to. Listed explicitly rather than
      // derived from the barrel, because the barrel also exports the half that
      // genuinely needs a server, and a rule that demanded those would be
      // satisfiable only by a lie.
      //
      // Four of them — the replay result and its errors, the convergence report
      // and the schema table — are *returned*, so `var`/`final` would reach them
      // without ever spelling them. That reads fine and teaches nothing: a
      // reader who wants to know what `replay()` handed back has no name to look
      // up. The example therefore writes those declarations out in full, and
      // this list is what keeps it doing so.
      for (final type in const [
        'TomDbMigrationAdaptor',
        'TomDbVersion',
        'TomSqlMigrationAdaptor',
        'TomDbMigrations',
        'TomMigrationFileName',
        'TomSchemaBuilder',
        'TomSchemaColumn',
        'TomSchemaModel',
        'TomSchemaTable',
        'TomSqlLexer',
        'TomMigrationArtifact',
        'TomSchemaDdlReader',
        'TomDdlReplayResult',
        'TomDdlReplayError',
        'TomSqlTypeFamily',
        'TomSchemaConvergenceCheck',
        'TomSchemaConvergenceReport',
        'TomSchemaDivergenceKind',
      ]) {
        expect(
          source,
          contains(type),
          reason: '$type is connection-free and the example never reaches it',
        );
      }
    });
  });
}

/// The texts that state the migration file-name grammar in full.
///
/// Deliberately short: the grammar has one owner ([TomDbMigrations]) and two
/// authorised restatements — the module guide and the module example. Other
/// modules that mention a migration path (`doc/scheduling.md`) describe only
/// the shape *their* shipped files take and link here for the rest, so they
/// state no grammar to keep honest.
const _grammarSites = [
  'lib/src/tomserver/db_migration/db_migration.dart',
  'doc/db_migration.md',
  'example/db_migration/db_migration_example.dart',
];

/// The grammar [TomDbMigrations.parseMigrationFileName] quotes back when it
/// refuses a name — read from the refusal itself, so a change to the pattern
/// that forgets the message is caught here rather than in the prose.
String _grammarQuotedByParser() {
  try {
    TomDbMigrations.parseMigrationFileName('not a migration');
  } on TomDbMigrationException catch (e) {
    final refusal = e.toString();
    final quoted = RegExp(
      r'must follow (.+?) pattern',
    ).firstMatch(refusal)?.group(1);
    if (quoted != null) return quoted;
    fail('the refusal no longer quotes the grammar: $refusal');
  }
  fail('parseMigrationFileName accepted a name that is not one');
}

/// Reduces a file name as a text *exhibits* it to the basename the parser is
/// given.
///
/// A name met in prose can end in the sentence's punctuation as well as its own
/// extension, and only the latter is the parser's to ignore.
String _exhibitedBasename(String exhibited) =>
    p.basenameWithoutExtension(exhibited.replaceAll(RegExp(r'[.,]+$'), ''));

/// Every grammar statement in [source]: the version placeholder running
/// straight into the description placeholder, then on to wherever the token
/// ends.
///
/// Requiring `-<description>` is what separates a statement of the whole rule
/// from prose naming one part of it — `_migrationNamePattern` describes its
/// pieces one at a time, and a text is entitled to do that without restating
/// the grammar.
List<String> _statedGrammars(String source) => [
  for (final match in RegExp(
    '\\[<(?:numeric )?version>\\]-<description>[^\\s`\'"]*',
  ).allMatches(source))
    match.group(0)!,
];

/// Reduces a grammar statement to what it *says*, so the two legitimate
/// spellings compare equal.
///
/// `<numeric version>` and `<version>` name the same slot; the extension is
/// unconstrained, so a text may spell it out, abbreviate it or leave it to
/// prose; and a typographic ellipsis is the same "and so on" as three periods.
/// What survives normalisation is the structure — in particular whether the
/// optional `@<env>` tag is mentioned at all, which is exactly what every one
/// of these texts used to omit.
String _normalizedGrammar(String grammar) => grammar
    .replaceAll('…', '...')
    .replaceAll('<numeric version>', '<version>')
    .replaceAll(RegExp(r'\.<(?:anyfileextension|ext)>'), '')
    .replaceAll(RegExp(r'\s+'), '');

/// Drives [TomDbMigrations.instantiateMigrator] with a [construct] that fails
/// and returns the exception it raised.
TomDbMigrationException _instantiationFailure(Object? Function() construct) {
  try {
    TomDbMigrations.instantiateMigrator('BrokenMigrator', construct);
  } on TomDbMigrationException catch (e) {
    return e;
  }
  fail('instantiateMigrator accepted a constructor that threw');
}

/// A constructor stand-in that fails from a **named top-level frame**, so a
/// forwarded trace can be told apart from one captured at the catch site.
Never _throwingConstructor() => throw StateError('constructor exploded');

/// Runs [action] and returns the error it raised.
///
/// `throwsA` proves the *type*; several of the missing-directory tests need the
/// instance itself, to read its `key` or its message. A
/// [TomDbMigrationException]'s `toString` embeds a per-instance uuid, so the
/// message can only ever be asserted by substring — never by equality against a
/// second instance.
Future<Object> _errorOf(Future<void> Function() action) async {
  try {
    await action();
  } catch (error) {
    return error;
  }
  fail('expected the call to throw');
}

/// A [TomDbMigrator] that records the calls it receives and does nothing else.
///
/// The subject of the lifecycle group is the *sequence* the orchestrator drives
/// a migrator through — how often it resets, when it initialises, and which
/// schema each migration is applied against. That sequence is what was wrong,
/// and it is entirely observable without a database, so this fake stands in for
/// [MariadbMigrationAdaptor] and the walk runs over the committed fixture tree
/// exactly as it would in production.
class _RecordingMigrator implements TomDbMigrator {
  /// Every call, in order: `reset`, `init:<schema>`,
  /// `apply:<schema>:<version>:<description>`.
  final List<String> events = [];

  @override
  void reset() => events.add('reset');

  @override
  Future<void> initializeMigration(
    TomDataSourceInfo dsi,
    String schemaName,
  ) async {
    events.add('init:$schemaName');
  }

  @override
  Future<void> applyMigration(
    TomDataSourceInfo dsi,
    String schemaName,
    int version,
    String description,
    String sql,
  ) async {
    events.add('apply:$schemaName:$version:$description');
  }
}
