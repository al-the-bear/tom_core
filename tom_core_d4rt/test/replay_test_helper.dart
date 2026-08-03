/// Helper for running D4rt replay integration tests.
///
/// Provides bridge generation, binary compilation, and replay execution
/// within the `package:test` framework.
///
/// ## Architecture
///
/// Unlike D4rtTester (which generates a test runner with --test mode),
/// replay tests use the full d4rt binary with `-run-replay <file> -test`.
/// This validates the complete d4rt REPL chain including bridge registration.
///
/// ## Usage
///
/// ```dart
/// late ReplayTestHelper helper;
///
/// setUpAll(() async {
///   helper = ReplayTestHelper(projectPath: Directory.current.path);
///   final ok = await helper.ensurePrepared();
///   expect(ok, isTrue, reason: helper.preparationError ?? 'unknown');
/// });
///
/// test('basics', () async {
///   final result = await helper.runReplay('test/replay/test_d4rt_basics.d4rt');
///   expect(result.exitCode, 0);
/// });
/// ```
///
/// [ReplayTestHelper.ensurePrepared] compiles only when the existing binary is
/// older than something it was built from, and logs which branch it took. The
/// binary is left in `bin/` afterwards — it is the cache that fast path exists
/// for, and it is now revalidated on every run rather than trusted blindly.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// Result of running a replay test.
class ReplayResult {
  /// Process exit code (0 = pass, non-zero = fail).
  final int exitCode;

  /// Captured stdout.
  final String stdout;

  /// Captured stderr.
  final String stderr;

  /// Whether the process timed out.
  final bool timedOut;

  const ReplayResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    this.timedOut = false,
  });

  /// Whether the replay test passed.
  bool get success => !timedOut && exitCode == 0;

  /// Human-readable failure description.
  String get failureReason {
    if (timedOut) return 'Timed out';
    if (exitCode != 0) {
      final msg = stderr.isNotEmpty ? stderr : stdout;
      // Extract verification failures if present
      final failIdx = msg.indexOf('VERIFICATION FAILURES');
      if (failIdx >= 0) {
        return msg.substring(failIdx).trim();
      }
      // Include both stdout and stderr for diagnosis
      final combined = StringBuffer();
      combined.writeln('Exit code $exitCode');
      if (stderr.isNotEmpty) {
        combined.writeln('STDERR: ${_truncate(stderr, 400)}');
      }
      if (stdout.isNotEmpty) {
        combined.writeln('STDOUT: ${_truncate(stdout, 400)}');
      }
      return combined.toString().trim();
    }
    return '';
  }

  static String _truncate(String s, int maxLen) {
    return s.length > maxLen ? '${s.substring(0, maxLen)}...' : s;
  }
}

/// Helper that manages bridge generation, binary compilation,
/// and replay test execution for tom_dartscript_bridges tests.
class ReplayTestHelper {
  /// Absolute path to the tom_dartscript_bridges project.
  final String projectPath;

  /// Name of the compiled test binary (placed in bin/).
  final String binaryName;

  /// Path to the Dart SDK (for d4rtgen).
  /// If null, uses DART_SDK env var or tries to auto-detect.
  final String? dartSdkPath;

  ReplayTestHelper({
    required this.projectPath,
    this.binaryName = 'd4rt_test',
    this.dartSdkPath,
  });

  /// Absolute path to the compiled binary.
  String get binaryPath => p.join(projectPath, 'bin', binaryName);

  /// Whether [prepare] has been called successfully.
  bool get isPrepared => _prepared;
  bool _prepared = false;

  /// Errors from preparation, if any.
  String? get preparationError => _preparationError;
  String? _preparationError;

  /// Prepare for replay tests, reusing an existing binary only when it is
  /// demonstrably current. This is what suites should call from `setUpAll`.
  ///
  /// ## Why existence is not enough
  ///
  /// Compiling takes ~100 s, so an unconditional rebuild is not the answer —
  /// but the fast path this replaces reused `bin/d4rt_test` whenever the file
  /// was merely *present*, comparing it against nothing. That produces a false
  /// red and a false green. The false red is how it was found: a suite reported
  /// two replay failures from a binary built half an hour before the `tom_d4rt`
  /// upgrade that fixed them — the code under test was correct, the harness was
  /// measuring a different build. A false green — a passing binary that
  /// predates a regression — does not announce itself at all.
  ///
  /// So the fast path stays and the decision becomes evidence-based: reuse only
  /// a binary newer than everything it was compiled from, and say out loud
  /// which branch was taken, so a reused binary is visible in the test log
  /// instead of being indistinguishable from a fresh one.
  ///
  /// ## Why the replay scripts are not build inputs
  ///
  /// `test/replay/*.d4rt` and `*.dcli` are deliberately excluded. Nothing
  /// embeds them: [runReplay] hands the path to the binary, which reads the
  /// file at run time. Editing a replay script therefore already takes effect
  /// on the very next run without a rebuild, so listing it here would buy no
  /// correctness — it would only spend 100 s and print a rebuild reason that is
  /// not true.
  Future<bool> ensurePrepared() async {
    final reasons = rebuildReasons();

    if (reasons.isEmpty) {
      print('[replay harness] reusing binary built '
          '${File(binaryPath).lastModifiedSync()} — '
          'newer than every build input');
      _prepared = true;
      return true;
    }

    final shown = reasons.take(3).join(', ');
    final rest = reasons.length > 3 ? ' (+${reasons.length - 3} more)' : '';
    print('[replay harness] rebuilding — $shown$rest');
    return prepare();
  }

  /// Why [ensurePrepared] would rebuild; empty when it would reuse the binary.
  ///
  /// Split out from [ensurePrepared] so the decision has one definition that is
  /// both printed and assertable — the alternative is a test that pays the
  /// ~100 s compile to observe which branch was taken, which is the kind of
  /// test that gets tagged and then never run.
  List<String> rebuildReasons() {
    final binary = File(binaryPath);
    if (!binary.existsSync()) {
      return ['no binary at ${p.relative(binaryPath, from: projectPath)}'];
    }
    return _buildInputsNewerThan(binary.lastModifiedSync()).toList();
  }

  /// Build inputs modified after [builtAt], as project-relative paths.
  ///
  /// The set is "everything the compiled binary was made from":
  ///
  /// - `bin/` and `lib/` — the entry point and every library reachable from it,
  ///   which includes the generated `*_bridges.b.dart`;
  /// - `pubspec.lock` — the resolved dependency set, standing in for the
  ///   sources of every package outside this one. An upgrade rewrites it, and
  ///   that is precisely the case that produced the false red.
  Iterable<String> _buildInputsNewerThan(DateTime builtAt) sync* {
    final lock = File(p.join(projectPath, 'pubspec.lock'));
    if (lock.existsSync() && lock.lastModifiedSync().isAfter(builtAt)) {
      yield 'pubspec.lock';
    }

    for (final root in const ['bin', 'lib']) {
      final dir = Directory(p.join(projectPath, root));
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.lastModifiedSync().isAfter(builtAt)) {
          yield p.relative(entity.path, from: projectPath);
        }
      }
    }
  }

  /// Prepare unconditionally: generate bridges and compile the d4rt binary.
  ///
  /// This is expensive (~1-3 minutes). Prefer [ensurePrepared], which does the
  /// same work but skips it when the existing binary is already current.
  /// Returns true on success.
  Future<bool> prepare({bool skipGeneration = false}) async {
    // Step 1: Generate bridges using d4rtgen
    if (!skipGeneration) {
      final genOk = await _generateBridges();
      if (!genOk) return false;
    }

    // Step 2: Compile d4rt binary
    final compileOk = await _compileBinary();
    if (!compileOk) return false;

    _prepared = true;
    return true;
  }

  /// Run a replay file and return the result.
  ///
  /// [replayFile] is relative to [projectPath] or absolute.
  /// [timeout] defaults to 30 seconds.
  Future<ReplayResult> runReplay(
    String replayFile, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!_prepared) {
      return const ReplayResult(
        exitCode: -1,
        stdout: '',
        stderr: 'ReplayTestHelper.prepare() was not called or failed',
      );
    }

    final absolutePath = p.isAbsolute(replayFile)
        ? replayFile
        : p.join(projectPath, replayFile);

    final process = await Process.start(
      binaryPath,
      ['-run-replay', absolutePath, '-test'],
      workingDirectory: projectPath,
    );

    final stdoutBuf = StringBuffer();
    final stderrBuf = StringBuffer();

    final stdoutFuture = process.stdout
        .transform(const SystemEncoding().decoder)
        .forEach(stdoutBuf.write);
    final stderrFuture = process.stderr
        .transform(const SystemEncoding().decoder)
        .forEach(stderrBuf.write);

    var timedOut = false;

    final exitCode = await process.exitCode.timeout(
      timeout,
      onTimeout: () {
        timedOut = true;
        process.kill(ProcessSignal.sigkill);
        return -1;
      },
    );

    await Future.wait([
      stdoutFuture.catchError((_) {}),
      stderrFuture.catchError((_) {}),
    ]);

    return ReplayResult(
      exitCode: exitCode,
      stdout: stdoutBuf.toString(),
      stderr: stderrBuf.toString(),
      timedOut: timedOut,
    );
  }

  /// Generate bridges using d4rtgen.
  ///
  /// ## Why the generator is run from source
  ///
  /// `dart run bin/d4rtgen.dart` in the generator's own directory, never a
  /// `d4rtgen` on PATH: PATH resolves to a prebuilt binary under
  /// `tom_binaries`, which may have been compiled from a *different* workspace
  /// checkout and would then generate against sources that are not the ones
  /// under test.
  ///
  /// ## Why the project is selected with `--scan`, not `--project`
  ///
  /// d4rtgen's `-p, --project` takes project **name/ID patterns**, not paths.
  /// Passing a filesystem path matches no project, so the generator does
  /// nothing — and still exits 0. `--scan <path> --not-recursive` selects
  /// exactly the one project rooted at [projectPath], which is the only thing
  /// this helper has (and the only thing it wants).
  Future<bool> _generateBridges() async {
    // Resolve the generator project path
    final generatorPath = p.normalize(
      p.join(projectPath, '../../d4rt/tom_d4rt_generator'),
    );

    // Resolve DART_SDK
    final sdk = dartSdkPath ??
        Platform.environment['DART_SDK'] ??
        _autoDetectDartSdk();

    if (sdk == null) {
      _preparationError =
          'DART_SDK not set and could not be auto-detected. '
          'Set DART_SDK environment variable or pass dartSdkPath.';
      return false;
    }

    // Filesystems differ in mtime granularity — some truncate to whole
    // seconds — so the freshness cutoff gets a little slack. Generation takes
    // tens of seconds, so a two-second window cannot admit a stale file.
    final cutoff = DateTime.now().subtract(const Duration(seconds: 2));

    final result = await Process.run(
      'dart',
      [
        'run',
        'bin/d4rtgen.dart',
        '--scan',
        p.absolute(projectPath),
        '--not-recursive',
      ],
      workingDirectory: generatorPath,
      environment: {'DART_SDK': sdk},
    );

    if (result.exitCode != 0) {
      _preparationError =
          'Bridge generation failed (exit ${result.exitCode}):\n'
          '${result.stderr}\n${result.stdout}';
      return false;
    }

    // A zero exit code is not evidence that anything was generated: d4rtgen
    // exits 0 when it finds no project to work on. Demand the actual proof —
    // bridge files rewritten during this run. Without this check the suite
    // silently validates whatever bridges happened to be on disk, which is how
    // the `--project <path>` bug above went unnoticed.
    final regenerated =
        _generatedBridgeFiles().where((f) => !f.isBefore(cutoff)).length;

    if (regenerated == 0) {
      _preparationError =
          'Bridge generation exited 0 but rewrote no "*.b.dart" file under '
          'lib/ or bin/ of $projectPath — d4rtgen selected no project.\n'
          'Check that buildkit.yaml still declares a d4rtgen: section, and '
          'that the generator CLI still selects projects the way this helper '
          'assumes (see the doc comment on _generateBridges).\n'
          'STDOUT: ${ReplayResult._truncate(result.stdout.toString(), 800)}\n'
          'STDERR: ${ReplayResult._truncate(result.stderr.toString(), 800)}';
      return false;
    }

    return true;
  }

  /// Last-modified stamps of every generated bridge file in the project.
  ///
  /// Generated bridges are the `*.b.dart` files d4rtgen writes under `lib/`
  /// (modules plus the barrel and dartscript registration) and `bin/` (the
  /// test runner). Only those two roots are walked — `.dart_tool/` is large
  /// and holds nothing of interest.
  Iterable<DateTime> _generatedBridgeFiles() sync* {
    for (final root in const ['lib', 'bin']) {
      final dir = Directory(p.join(projectPath, root));
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.b.dart')) {
          yield entity.lastModifiedSync();
        }
      }
    }
  }

  /// Compile the d4rt binary.
  ///
  /// Compiles to a process-unique temporary path and renames it into place.
  /// `package:test` runs test files in concurrent isolates, so the two replay
  /// suites can decide to rebuild at the same moment; a shared `-o` target
  /// would have them writing the same file while the other reads it. Rename is
  /// atomic within a directory, so the worst outcome is a duplicated compile —
  /// never a half-written binary, and never a window in which the binary is
  /// absent (which is what deleting it up-front used to create).
  Future<bool> _compileBinary() async {
    final stagingPath = '$binaryPath.${pid}_staging';

    final result = await Process.run(
      'dart',
      ['compile', 'exe', 'bin/d4rt.dart', '-o', stagingPath],
      workingDirectory: projectPath,
    );

    final staged = File(stagingPath);

    if (result.exitCode != 0) {
      if (staged.existsSync()) staged.deleteSync();
      _preparationError =
          'Binary compilation failed (exit ${result.exitCode}):\n'
          '${result.stderr}';
      return false;
    }

    if (!staged.existsSync()) {
      _preparationError = 'Compiled binary not found at $stagingPath';
      return false;
    }

    staged.renameSync(binaryPath);
    return true;
  }

  /// Try to auto-detect the Dart SDK path.
  String? _autoDetectDartSdk() {
    // Try Flutter SDK's bundled Dart
    final flutterPaths = [
      p.join(Platform.environment['HOME'] ?? '', 'Desktop/development/flutter/bin/cache/dart-sdk'),
      p.join(Platform.environment['HOME'] ?? '', '.flutter/bin/cache/dart-sdk'),
      '/usr/local/flutter/bin/cache/dart-sdk',
    ];
    for (final path in flutterPaths) {
      if (Directory(path).existsSync()) return path;
    }

    // Try standalone Dart SDK via `which dart`
    try {
      final result = Process.runSync('which', ['dart']);
      if (result.exitCode == 0) {
        // dart binary -> bin/dart -> SDK root
        final dartBin = (result.stdout as String).trim();
        final sdkPath = p.dirname(p.dirname(dartBin));
        if (Directory(p.join(sdkPath, 'lib')).existsSync()) {
          return sdkPath;
        }
      }
    } catch (_) {}

    return null;
  }

}
