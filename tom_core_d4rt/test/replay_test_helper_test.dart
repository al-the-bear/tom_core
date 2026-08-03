/// Tests for the replay suite's own harness.
///
/// The replay tests (`d4rt_replay_test.dart`, `dcli_compat_test.dart`) only
/// mean anything if the bridges they exercise were regenerated from the
/// current sources. [ReplayTestHelper.prepare] is what guarantees that, so it
/// needs a test of its own: the failure it must never repeat is *silently
/// generating nothing and reporting success*, which leaves the whole suite
/// validating stale bridges while showing green.
///
/// Run with: `dart test test/replay_test_helper_test.dart`
@TestOn('vm')
@Timeout(Duration(minutes: 3))
library;

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
}
