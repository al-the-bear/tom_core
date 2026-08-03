/// Tests for the replay suite's own harness.
///
/// The replay tests (`d4rt_replay_test.dart`, `dcli_compat_test.dart`) only
/// mean anything if the binary they run was built from the current sources.
/// Two harness behaviours guarantee that, and each has failed silently before,
/// so each is pinned here:
///
/// - [ReplayTestHelper.prepare] must not report success when d4rtgen generated
///   nothing — otherwise the suite validates stale bridges while showing green;
/// - [ReplayTestHelper.rebuildReasons] must notice that the binary predates
///   something it was compiled from — otherwise the suite reports a *different
///   build's* results as if they were the current tree's.
///
/// Run with: `dart test test/replay_test_helper_test.dart`
@TestOn('vm')
@Timeout(Duration(minutes: 3))
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'replay_test_helper.dart';

void main() {
  group('ReplayTestHelper.prepare', () {
    test(
      'fails loudly when d4rtgen selects no project',
      () async {
        // A sibling project with no `d4rtgen:` section in its buildkit.yaml.
        // d4rtgen finds nothing to generate for it and exits 0 — the same
        // observable outcome as passing a selector that matches no project,
        // which is exactly how this helper used to invoke it (`--project
        // <filesystem path>`, where --project takes name patterns).
        final unconfiguredProject = p.normalize(
          p.join(Directory.current.path, '../tom_core_kernel'),
        );
        expect(
          Directory(unconfiguredProject).existsSync(),
          isTrue,
          reason: 'Fixture project missing: $unconfiguredProject',
        );

        final helper = ReplayTestHelper(projectPath: unconfiguredProject);
        final ok = await helper.prepare();

        expect(ok, isFalse,
            reason: 'Generating nothing must not be reported as success');
        expect(
          helper.preparationError,
          contains('rewrote no'),
          reason: 'The failure must name the real cause — no bridges were '
              'written — rather than surfacing as a later compilation error',
        );
      },
      // Spawning d4rtgen costs ~10s even when it selects nothing.
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });

  group('ReplayTestHelper freshness', () {
    // A synthetic project tree rather than the real one: these cases turn on
    // exact modification times, and the only way to state "the binary is newer
    // than every source" as a fact rather than a hope is to set both stamps.
    // The fixture lives in the system temp directory because it is created and
    // destroyed inside a single test — nothing here is a work product a human
    // would ever want to inspect afterwards.
    late Directory fixture;
    late ReplayTestHelper helper;

    /// Fixed instant the binary is stamped with, so "newer"/"older" in each
    /// test is an offset from one known point instead of a race with the clock.
    final builtAt = DateTime(2026, 1, 1, 12);

    /// Write [relativePath] with [modified] as its last-modified time.
    void writeFile(String relativePath, DateTime modified) {
      final file = File(p.join(fixture.path, relativePath));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('// fixture\n');
      file.setLastModifiedSync(modified);
    }

    setUp(() {
      fixture = Directory.systemTemp.createTempSync('replay_harness_');
      helper = ReplayTestHelper(projectPath: fixture.path);

      writeFile('pubspec.lock', builtAt.subtract(const Duration(hours: 1)));
      writeFile('lib/src/foo.dart', builtAt.subtract(const Duration(hours: 1)));
      writeFile(
        'lib/src/foo_bridges.b.dart',
        builtAt.subtract(const Duration(hours: 1)),
      );
      writeFile('bin/d4rt.dart', builtAt.subtract(const Duration(hours: 1)));
      writeFile('bin/d4rt_test', builtAt);
    });

    tearDown(() => fixture.deleteSync(recursive: true));

    test('reuses the binary when it is newer than every build input', () {
      expect(helper.rebuildReasons(), isEmpty);
    });

    test('rebuilds when there is no binary', () {
      File(helper.binaryPath).deleteSync();

      expect(helper.rebuildReasons(), ['no binary at bin/d4rt_test']);
    });

    test('rebuilds when the resolved dependency set changed', () {
      // The case that produced the false red: `dart pub upgrade` rewrote
      // pubspec.lock, the binary kept the previous dependency set, and the
      // suite reported that binary's failures as the current tree's.
      writeFile('pubspec.lock', builtAt.add(const Duration(minutes: 1)));

      expect(helper.rebuildReasons(), ['pubspec.lock']);
    });

    test('rebuilds when a library source changed', () {
      writeFile('lib/src/foo.dart', builtAt.add(const Duration(minutes: 1)));

      expect(helper.rebuildReasons(), [p.join('lib', 'src', 'foo.dart')]);
    });

    test('rebuilds when a generated bridge was regenerated', () {
      // Named separately from the plain-source case because it is the one the
      // harness exists to protect: regenerating bridges is exactly what
      // `prepare()` does, and reusing a binary built before it would validate
      // the previous generation's output.
      writeFile(
        'lib/src/foo_bridges.b.dart',
        builtAt.add(const Duration(minutes: 1)),
      );

      expect(
        helper.rebuildReasons(),
        [p.join('lib', 'src', 'foo_bridges.b.dart')],
      );
    });

    test('rebuilds when the entry point changed', () {
      writeFile('bin/d4rt.dart', builtAt.add(const Duration(minutes: 1)));

      expect(helper.rebuildReasons(), [p.join('bin', 'd4rt.dart')]);
    });

    test('ignores replay scripts, which the binary reads at run time', () {
      // Deliberate exclusion, not an oversight. Nothing embeds the replay
      // files — runReplay passes the path and the binary opens it — so an
      // edited script already takes effect on the next run. Listing them would
      // spend ~100 s recompiling and print a rebuild reason that is untrue.
      writeFile(
        'test/replay/test_d4rt_basics.d4rt',
        builtAt.add(const Duration(minutes: 1)),
      );

      expect(helper.rebuildReasons(), isEmpty);
    });

    test('reports every stale input, not just the first', () {
      writeFile('pubspec.lock', builtAt.add(const Duration(minutes: 1)));
      writeFile('lib/src/foo.dart', builtAt.add(const Duration(minutes: 1)));

      expect(
        helper.rebuildReasons(),
        containsAll(['pubspec.lock', p.join('lib', 'src', 'foo.dart')]),
      );
    });

    test('ensurePrepared announces that it reused the binary', () async {
      // The reuse branch is the silent one — a reused binary otherwise looks
      // exactly like a freshly built one in the test log, which is what made
      // the stale-binary failure so expensive to diagnose. Only this branch is
      // asserted here; the rebuild branch would spend ~100 s compiling to
      // observe one print, and its decision is already pinned above.
      final log = <String>[];
      final ok = await runZoned(
        helper.ensurePrepared,
        zoneSpecification: ZoneSpecification(
          print: (_, _, _, line) => log.add(line),
        ),
      );

      expect(ok, isTrue);
      expect(helper.isPrepared, isTrue);
      expect(log, [contains('reusing binary')]);
    });
  });
}
