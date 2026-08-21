import 'dart:io';

import 'package:test/test.dart';

/// Shutdown state must not outlive the artefact that created it.
///
/// Two shapes of one mistake live here, because they fail the same way: not in
/// the code that commits them, but on some later test, or on the process's
/// ability to exit at all. That displacement is why both drifted back more than
/// once while every individual change looked fine on its own.
///
/// **A cleanup nobody disposes keeps the isolate alive.** The constructor arms
/// SIGHUP and SIGINT watchers, and a live watcher is a live subscription: the
/// isolate has a reason to stay up. The global [tomShutdownCleanup] wants
/// exactly that for the life of the process, but every short-lived instance —
/// every one an example or a test builds — has to be torn down again. A leaked
/// watcher makes the *suite* hang after the last test reports, or the sample
/// print its final line and never exit.
///
/// **The global cannot be cleaned up after.** It has no unregister path, so a
/// test that registers a closable on it registers it for the rest of the run,
/// and `cancelAll()` is no escape — that would cancel the global's own
/// watchers. Every later test then meets a pre-populated global. Nothing fails
/// today only because nothing drives the global's `performShutdown()`; the
/// first test that does would inherit every registration made before it.
///
/// What this can and cannot check: proving "disposed on every path" needs
/// dataflow analysis, which a test like this has no business attempting. It
/// checks the shapes that actually go wrong instead — a test file that
/// constructs instances without ever registering a teardown, an example that
/// builds one and never mentions teardown, and a test that calls a
/// state-changing method on the global.
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

  // ===========================================================================
  // The global instance is left as it was found
  // ===========================================================================
  group('the global instance is left as it was found', () {
    test('no test file changes the global state', () {
      expect(_testFilesMutatingTheGlobal(), isEmpty, reason: _globalReason);
    });

    // The counterpart to the scan floor above: that one proves the scan reads
    // files, this proves the pattern still recognises what it names. A rule
    // whose regex quietly stopped matching reports the same empty list as a
    // tree that is genuinely clean.
    test('the pattern matches the calls it forbids, and only those', () {
      for (final forbidden in [
        'tomShutdownCleanup.addClosable(closable);',
        'tomShutdownCleanup.addDisposable(disposable);',
        'tomShutdownCleanup.addSignalHandler((signal) {});',
        'tomShutdownCleanup.addSignal(ProcessSignal.sigterm);',
        'tomShutdownCleanup.performShutdown();',
        'await tomShutdownCleanup.cancelAll();',
        'await tomShutdownCleanup.dispose();',
        'tomShutdownCleanup.paused = true;',
        'tomShutdownCleanup.silent = true;',
      ]) {
        expect(
          _globalMutation.hasMatch(forbidden),
          isTrue,
          reason: 'should be caught: $forbidden',
        );
      }

      // Reading the global is the sanctioned way to test it, and a mutating
      // call on some other instance is the normal case everywhere else in the
      // suite — a rule that caught either would be unusable.
      for (final allowed in [
        'expect(tomShutdownCleanup, isA<TomShutdownCleanup>());',
        'expect(tomShutdownCleanup.paused, isFalse);',
        'expect(tomShutdownCleanup.silent, isFalse);',
        'cleanup.addClosable(closable);',
      ]) {
        expect(
          _globalMutation.hasMatch(allowed),
          isFalse,
          reason: 'should be allowed: $allowed',
        );
      }
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

/// A call on the global that leaves it different from how it was found.
///
/// The three `add*` methods and the two public flags change what a later
/// `performShutdown()` will do; `performShutdown`, `cancelAll` and `dispose`
/// spend or unhook the global itself. Reads are absent on purpose — asserting
/// on the global is the sanctioned way to test it.
// `=(?!=)` so that an `==` comparison counts as a read, not an assignment.
final _globalMutation = RegExp(
  r'\btomShutdownCleanup\.'
  r'(addClosable|addDisposable|addSignalHandler|addSignal|'
  r'performShutdown|cancelAll|dispose)\s*\('
  r'|\btomShutdownCleanup\.(paused|silent)\s*=(?!=)',
);

/// Test files that change the global's state.
///
/// Examples are not scanned: a sample is its own process and exits when it
/// ends, so the global is its to use — and using it is what several samples
/// are for. A test shares one process with every other test in the file, and
/// the module offers no way to put back what a test registers.
List<String> _testFilesMutatingTheGlobal() => [
  for (final file in _dartFilesIn(['test']))
    for (final match in _globalMutation.allMatches(file.readAsStringSync()))
      '${file.path}: ${match.group(0)}',
];

// -----------------------------------------------------------------------------
// The scan
// -----------------------------------------------------------------------------

/// Trees whose cleanups are short-lived. `lib` is deliberately absent: the one
/// construction there is the process-lifetime global, which must not be
/// disposed.
const _scannedDirectories = ['test', 'example'];

/// This file states both rules in the terms they forbid, so it matches them.
const _thisFile = 'shutdown_state_not_leaked_test.dart';

/// Generated sources carry whatever the generator emits, and are corrected by
/// regenerating rather than by editing.
bool _isGenerated(String path) =>
    path.endsWith('.reflection.dart') || path.endsWith('.g.dart');

/// Every hand-written Dart file under [directories], this one excepted.
List<File> _dartFilesIn(List<String> directories) => [
  for (final directory in directories)
    if (Directory(directory).existsSync())
      for (final entity in Directory(directory).listSync(recursive: true))
        if (entity is File &&
            entity.path.endsWith('.dart') &&
            !_isGenerated(entity.path) &&
            !entity.path.endsWith(_thisFile))
          entity,
];

List<File> _filesConstructingCleanups() => [
  for (final file in _dartFilesIn(_scannedDirectories))
    if (_construction.hasMatch(file.readAsStringSync())) file,
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

const _globalReason =
    'A test changes the state of the process-wide tomShutdownCleanup. There is '
    'no unregister path, and cancelAll() would cancel the very watchers the '
    'global exists to hold, so what the test registers is still registered '
    'when the last test in '
    'the run executes. Exercise a local instance instead — the whole API is '
    'covered that way already — and keep the global for assertions that only '
    'read it.';
