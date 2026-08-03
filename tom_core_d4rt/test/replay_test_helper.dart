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
///   await helper.prepare();
/// });
///
/// test('basics', () async {
///   final result = await helper.runReplay('test/replay/test_d4rt_basics.d4rt');
///   expect(result.exitCode, 0);
/// });
/// ```
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

  /// Whether this helper compiled the binary itself (and therefore owns its
  /// lifecycle). Only an owned binary is removed by [cleanup]; a pre-existing
  /// binary reused via [markPrepared] is left in place so that sibling test
  /// suites sharing the same `bin/d4rt_test` do not delete it out from under
  /// each other when running concurrently.
  bool _ownsBinary = false;

  /// Mark as prepared without running generation or compilation.
  ///
  /// Use when the binary already exists (e.g. built by another test suite or a
  /// manual build). The binary is treated as externally owned, so [cleanup]
  /// will not delete it.
  void markPrepared() {
    _prepared = true;
    _ownsBinary = false;
  }

  /// Errors from preparation, if any.
  String? get preparationError => _preparationError;
  String? _preparationError;

  /// Prepare for replay tests: generate bridges and compile the d4rt binary.
  ///
  /// This is expensive (~1-3 minutes) and should be called once in `setUpAll`.
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
    _ownsBinary = true;
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
  Future<bool> _compileBinary() async {
    // Delete existing test binary
    final binFile = File(binaryPath);
    if (binFile.existsSync()) {
      binFile.deleteSync();
    }

    final result = await Process.run(
      'dart',
      ['compile', 'exe', 'bin/d4rt.dart', '-o', binaryPath],
      workingDirectory: projectPath,
    );

    if (result.exitCode != 0) {
      _preparationError =
          'Binary compilation failed (exit ${result.exitCode}):\n'
          '${result.stderr}';
      return false;
    }

    if (!File(binaryPath).existsSync()) {
      _preparationError = 'Compiled binary not found at $binaryPath';
      return false;
    }

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

  /// Clean up the test binary.
  void cleanup() {
    // Only remove a binary this helper compiled. A pre-existing binary reused
    // via markPrepared() is externally owned — deleting it would break a
    // sibling suite still running against the same shared bin/d4rt_test.
    if (!_ownsBinary) return;
    final binFile = File(binaryPath);
    if (binFile.existsSync()) {
      binFile.deleteSync();
    }
  }
}
