/// DCli compatibility tests run via d4rt.
///
/// Runs the DCli `.dcli` replay files shipped by the `tom_d4rt_dcli` package
/// using the d4rt binary to verify backward compatibility.
/// D4rt must be able to run all DCli replay files without errors.
///
/// ## Limitations
///
/// Of the thirteen DCli replay files, only `test_dcli_basics.dcli` currently
/// runs under d4rt:
///
/// - **Eleven** open with an `import` statement, which d4rt replay mode does
///   not support. The skip list is derived from the files themselves, so a
///   future DCli release that drops an import should have the corresponding
///   skip removed here.
/// - **One** (`test_dcli_multiline.dcli`) has no imports but uses a
///   `.start-execute` block that d4rt mis-parses — a d4rt gap tracked
///   separately, not a property of the file.
///
/// Run with: `dart test test/dcli_compat_test.dart`
@TestOn('vm')
@Timeout(Duration(minutes: 5))
library;

import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'replay_test_helper.dart';

/// Absolute path to the `test/replay` corpus shipped by `tom_d4rt_dcli`.
///
/// Resolved through *this* project's package resolution rather than a presumed
/// sibling checkout. `tom_d4rt_dcli` is a hosted dependency, so its replay
/// files live in the pub cache; the previous hard-coded
/// `../../xternal/tom_module_d4rt/...` named a directory that has never
/// existed in this workspace, which made the one executed case in this file a
/// permanent red. Going through package resolution also keeps the suite
/// correct if the dependency is later switched to a path — it follows however
/// the package actually resolves instead of assuming a layout.
final String _dcliReplayDir = _resolveDcliReplayDir();

/// Locate the replay corpus inside the resolved `tom_d4rt_dcli` package.
String _resolveDcliReplayDir() {
  final libraryUri = Isolate.resolvePackageUriSync(
    Uri.parse('package:tom_d4rt_dcli/tom_d4rt_dcli.dart'),
  );
  if (libraryUri == null) {
    throw StateError(
      'Cannot resolve package:tom_d4rt_dcli. It must be a dependency of '
      'tom_core_d4rt and `dart pub get` must have been run.',
    );
  }
  // <package root>/lib/tom_d4rt_dcli.dart -> <package root>
  final packageRoot = p.dirname(p.dirname(libraryUri.toFilePath()));
  return p.join(packageRoot, 'test', 'replay');
}

void main() {
  late ReplayTestHelper helper;

  setUpAll(() async {
    // Checked before anything expensive runs: without the corpus every case
    // below would fail as an opaque "Replay file not found" from the d4rt
    // binary, naming a path but not what was supposed to provide it.
    expect(
      Directory(_dcliReplayDir).existsSync(),
      isTrue,
      reason:
          'The tom_d4rt_dcli replay corpus is missing at $_dcliReplayDir. '
          'The published package ships it under test/replay; if a release '
          'starts excluding test files, this suite has no input and must be '
          'reworked rather than left pointing at a path that does not exist.',
    );

    helper = ReplayTestHelper(projectPath: Directory.current.path);
    final ok = await helper.ensurePrepared();
    expect(ok, isTrue,
        reason: 'Preparation failed: ${helper.preparationError ?? "unknown"}');
  });

  group('DCli compatibility', () {
    test('basics', () async {
      final result = await helper.runReplay(
        p.join(_dcliReplayDir, 'test_dcli_basics.dcli'),
      );
      expect(result.success, isTrue, reason: result.failureReason);
    });

    test(
      'classes',
      skip: 'D4rt replay does not support imports',
      () async {
        final result = await helper.runReplay(
          p.join(_dcliReplayDir, 'test_dcli_classes.dcli'),
        );
        expect(result.success, isTrue, reason: result.failureReason);
      },
    );

    test(
      'collections',
      skip: 'D4rt replay does not support imports',
      () async {
        final result = await helper.runReplay(
          p.join(_dcliReplayDir, 'test_dcli_collections.dcli'),
        );
        expect(result.success, isTrue, reason: result.failureReason);
      },
    );

    test(
      'core',
      skip: 'D4rt replay does not support imports',
      () async {
        final result = await helper.runReplay(
          p.join(_dcliReplayDir, 'test_dcli_core.dcli'),
        );
        expect(result.success, isTrue, reason: result.failureReason);
      },
    );

    test(
      'datetime',
      skip: 'D4rt replay does not support imports',
      () async {
        final result = await helper.runReplay(
          p.join(_dcliReplayDir, 'test_dcli_datetime.dcli'),
        );
        expect(result.success, isTrue, reason: result.failureReason);
      },
    );

    test(
      'filesystem',
      skip: 'D4rt replay does not support imports',
      () async {
        final result = await helper.runReplay(
          p.join(_dcliReplayDir, 'test_dcli_filesystem.dcli'),
        );
        expect(result.success, isTrue, reason: result.failureReason);
      },
    );

    test(
      'functions',
      skip: 'D4rt replay does not support imports',
      () async {
        final result = await helper.runReplay(
          p.join(_dcliReplayDir, 'test_dcli_functions.dcli'),
        );
        expect(result.success, isTrue, reason: result.failureReason);
      },
    );

    test(
      'io',
      skip: 'D4rt replay does not support imports',
      () async {
        final result = await helper.runReplay(
          p.join(_dcliReplayDir, 'test_dcli_io.dcli'),
        );
        expect(result.success, isTrue, reason: result.failureReason);
      },
    );

    test(
      'json',
      skip: 'D4rt replay does not support imports',
      () async {
        final result = await helper.runReplay(
          p.join(_dcliReplayDir, 'test_dcli_json.dcli'),
        );
        expect(result.success, isTrue, reason: result.failureReason);
      },
    );

    test(
      'math',
      skip: 'D4rt replay does not support imports',
      () async {
        final result = await helper.runReplay(
          p.join(_dcliReplayDir, 'test_dcli_math.dcli'),
        );
        expect(result.success, isTrue, reason: result.failureReason);
      },
    );

    // Skipped for a different reason than its eleven neighbours: this file has
    // no imports, but d4rt mis-parses its `.start-execute` block (it reports
    // "Expected to find ')'" on the block's first line, i.e. it feeds the whole
    // block to the parser as one fragment instead of executing it statement by
    // statement in a fresh environment). That is a d4rt replay-mode gap, not a
    // property of this file — see quest todo
    // tccc5_ahda-d4rt-replay-misparses-start-execute-blocks. When it is fixed,
    // drop the skip: this case is already wired up and will go green on its own.
    test(
      'multiline',
      skip: 'D4rt replay mis-parses .start-execute blocks (tccc5)',
      () async {
        final result = await helper.runReplay(
          p.join(_dcliReplayDir, 'test_dcli_multiline.dcli'),
        );
        expect(result.success, isTrue, reason: result.failureReason);
      },
    );

    test(
      'platform',
      skip: 'D4rt replay does not support imports',
      () async {
        final result = await helper.runReplay(
          p.join(_dcliReplayDir, 'test_dcli_platform.dcli'),
        );
        expect(result.success, isTrue, reason: result.failureReason);
      },
    );

    test(
      'strings',
      skip: 'D4rt replay does not support imports',
      () async {
        final result = await helper.runReplay(
          p.join(_dcliReplayDir, 'test_dcli_strings.dcli'),
        );
        expect(result.success, isTrue, reason: result.failureReason);
      },
    );
  });
}
