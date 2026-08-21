import 'dart:io';

import 'package:test/test.dart';

/// A `TomShutdownCleanup` nobody disposes keeps the isolate alive.
///
/// Its constructor arms SIGHUP and SIGINT watchers, and a live watcher is a
/// live subscription: the isolate has a reason to stay up. The global
/// [tomShutdownCleanup] wants exactly that for the life of the process, but
/// every short-lived instance — every one an example or a test builds — has to
/// be torn down again.
///
/// The failure this guards is quiet in the worst way. A leaked watcher does not
/// break the test that leaked it; it makes the *suite* hang after the last test
/// reports, or the sample print its final line and never exit. The cost lands
/// somewhere other than the code that caused it, which is why the discipline
/// drifted here before: the teardown idiom already existed and was simply not
/// applied everywhere.
///
/// What this can and cannot check: proving "disposed on every path" needs
/// dataflow analysis, which a test like this has no business attempting. It
/// checks the two shapes that actually go wrong instead — a test file that
/// constructs instances without ever registering a teardown, and an example
/// that builds one and never mentions teardown at all. Both are the "built it
/// and walked away" case, and both are what the drift looked like.
void main() {
  // ===========================================================================
  // Shutdown watchers are disposed
  // ===========================================================================
  group('shutdown watchers are disposed', () {
    test('test files construct through a teardown-registering helper', () {
      expect(_testFilesWithoutTeardown(), isEmpty, reason: _testReason);
    });

    test('example files dispose the instances they build', () {
      expect(_exampleFilesWithoutTeardown(), isEmpty, reason: _exampleReason);
    });

    // A scan that matches nothing reports a clean tree, which is the one
    // failure this kind of test cannot survive — it would keep passing through
    // exactly the leak it exists to catch. The floor is below the present
    // count, so it fires on a broken scan rather than on the next file
    // somebody adds or deletes.
    test('the scan reaches the files it claims to check', () {
      expect(_filesConstructingCleanups(), hasLength(greaterThanOrEqualTo(4)));
    });
  });
}

// -----------------------------------------------------------------------------
// The rule
// -----------------------------------------------------------------------------

/// A direct call to the `TomShutdownCleanup` constructor.
final _construction = RegExp(r'\bTomShutdownCleanup\(\)');

/// Any of the three ways an instance's watchers get released.
///
/// `dispose()` delegates to `cancelAll()`, so either call is a real teardown;
/// `addTearDown` defers one to the end of the running test. All three are the
/// rule being followed.
// No trailing \b: these end in ')', and a word boundary after it would demand
// a word character next — which `dispose();` does not have.
final _teardown = RegExp(r'\.dispose\(\)|\.cancelAll\(\)|\baddTearDown\b');

/// Test files that build cleanups but never register a teardown.
///
/// One construction is expected and allowed — the file's own `_newCleanup()`
/// helper, which is the thing that registers the teardown. More than one means
/// tests are constructing directly and bypassing it.
List<String> _testFilesWithoutTeardown() {
  final offenders = <String>[];

  for (final file in _filesConstructingCleanups()) {
    if (!file.path.startsWith('test${Platform.pathSeparator}')) continue;

    final source = file.readAsStringSync();
    final constructions = _construction.allMatches(source).length;
    final registersTeardown = source.contains('addTearDown');

    if (!registersTeardown) {
      offenders.add(
        '${file.path}: $constructions construction(s), no '
        'addTearDown anywhere',
      );
    } else if (constructions > 1) {
      offenders.add(
        '${file.path}: $constructions direct constructions — only '
        'the teardown-registering helper should call the constructor',
      );
    }
  }

  return offenders;
}

/// Example files that build cleanups and never tear one down.
List<String> _exampleFilesWithoutTeardown() => [
  for (final file in _filesConstructingCleanups())
    if (file.path.startsWith('example${Platform.pathSeparator}') &&
        !_teardown.hasMatch(file.readAsStringSync()))
      '${file.path}: constructs a cleanup, never disposes one',
];

// -----------------------------------------------------------------------------
// The scan
// -----------------------------------------------------------------------------

/// Trees whose cleanups are short-lived. `lib` is deliberately absent: the one
/// construction there is the process-lifetime global, which must not be
/// disposed.
const _scannedDirectories = ['test', 'example'];

/// Generated sources carry whatever the generator emits, and are corrected by
/// regenerating rather than by editing.
bool _isGenerated(String path) =>
    path.endsWith('.reflection.dart') || path.endsWith('.g.dart');

List<File> _filesConstructingCleanups() => [
  for (final directory in _scannedDirectories)
    if (Directory(directory).existsSync())
      for (final entity in Directory(directory).listSync(recursive: true))
        if (entity is File &&
            entity.path.endsWith('.dart') &&
            !_isGenerated(entity.path) &&
            // This file quotes the constructor call it looks for.
            !entity.path.endsWith('shutdown_watchers_disposed_test.dart') &&
            _construction.hasMatch(entity.readAsStringSync()))
          entity,
];

const _testReason =
    'A test file builds TomShutdownCleanup instances without registering a '
    'teardown. Each construction arms two OS-signal watchers and a live '
    'watcher keeps the isolate alive, so the leak surfaces as a suite that '
    'hangs after the last test reports — nowhere near the test that caused '
    'it. Build them through a helper that calls addTearDown(cleanup.dispose).';

const _exampleReason =
    'An example builds a TomShutdownCleanup and never disposes one. Running a '
    'cleanup is not disposing it: performShutdown() executes the registrations '
    'but leaves the SIGHUP/SIGINT watchers the constructor started, so the '
    'sample prints its last line and then hangs instead of exiting.';
