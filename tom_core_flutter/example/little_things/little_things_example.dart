/// Executable example for the little_things module of `tom_core_flutter`.
///
/// Demonstrates the two client exception types, the type-based discrimination
/// pattern UI layers rely on, and the forwarded kernel payload — including
/// `autoLog`, whose records are captured and printed rather than described.
///
/// The barrel import pulls in `flutter/material` (and thus `dart:ui`), so run
/// this under the Flutter toolchain, e.g.
/// `flutter test example/little_things/little_things_example.dart`, not bare
/// `dart run`. The assertions below only run with asserts enabled, which
/// `flutter test` does by default. `test/little_things_test.dart` covers the
/// same behaviour and also calls [run], so a snippet that stops compiling or
/// an assertion that stops holding fails the suite rather than the reader.
library;

import 'package:tom_core_flutter/tom_core_flutter.dart';

/// A log output that keeps what it is given, so the `autoLog` example can show
/// the records the constructor wrote rather than assert they exist unseen.
///
/// Defined here rather than shared: the kernel's examples and tests already
/// carry a fixture of this shape at every site that needs one, and extracting
/// a common helper for the tenth site would make the codebase less consistent,
/// not more.
class _RecordingLogOutput extends TomLogOutput {
  final List<String> messages = [];

  @override
  void output(
    TomLogLevel loggerLevel,
    TomLogLevel logLevel,
    String level,
    Object message,
    String isolateName,
    DateTime timeStamp, [
    String? origin,
  ]) {
    if (logLevel.matches(loggerLevel)) {
      messages.add(convertToString(message));
    }
  }
}

void run() {
  // Example 1: a user-facing error carries a presentable message.
  final uiError = TomClientUIException('login.failed', 'Could not sign you in.');
  print('ui error: ${uiError.key} -> ${uiError.defaultUserMessage}');

  // Example 2: an internal client error that should not be shown verbatim.
  final internal = TomClientException('cache.miss', 'No cached profile');
  print('internal: ${internal.key} -> ${internal.defaultUserMessage}');

  // Example 3: surface presentable errors, wrap the rest.
  TomClientUIException surface(TomException e) {
    if (e is TomClientUIException) return e;
    return TomClientUIException('app.error', 'Unexpected error', rootException: e);
  }

  final surfacedUi = surface(uiError);
  final surfacedInternal = surface(internal);
  print('surfaced ui identical: ${identical(surfacedUi, uiError)}');
  print('surfaced internal wraps root: ${surfacedInternal.rootException == internal}');

  // Example 4: the client exceptions forward the kernel's diagnostic payload —
  // `parameters` for context that must not reach the user, and `stack` for a
  // trace captured at the throw site rather than at the reporting site.
  final detailed = TomClientException(
    'upload.failed',
    'Upload failed',
    parameters: {'bytes': 2048, 'endpoint': '/files'},
    stack: StackTrace.current,
  );
  print('detailed params: ${detailed.parameters}');
  print('detailed stack captured: ${detailed.stackTrace.isNotEmpty}');

  // Example 5: `autoLog: true` writes the failure to the log as the exception
  // is constructed, before the throw completes.
  //
  // Every other forwarded argument is inert data; this one is a side effect,
  // so it is shown rather than described. A recorder stands in for the
  // configured output, one exception is built without the flag and one with
  // it, and the difference between them is the whole feature.
  final recorder = _RecordingLogOutput();
  final previousOutput = tomLog.logOutput;
  late final int quietCount;
  late final TomClientException logged;
  tomLog.logOutput = recorder;
  try {
    // Shown first so the records below are visibly caused by the flag rather
    // than by construction itself.
    TomClientException('sync.failed', 'Sync failed');
    quietCount = recorder.messages.length;

    logged = TomClientException('sync.failed', 'Sync failed', autoLog: true);
  } finally {
    // Restored in a `finally` because a failed assertion further down would
    // otherwise leave the recorder installed and silence every later log line
    // in the process that ran this example.
    tomLog.logOutput = previousOutput;
  }
  print('autoLog off — records written on construction: $quietCount');
  print('autoLog on  — records written on construction: '
      '${recorder.messages.length}');
  for (final message in recorder.messages) {
    // First line only: the stack-trace record runs to many frames.
    print('  ${message.split('\n').first}');
  }
  print('both records carry ${logged.uuid}, so a trace can be joined back to '
      'the failure it came from');

  // Assertions
  assert(internal is! TomClientUIException);
  assert(identical(surfacedUi, uiError));
  assert(surfacedInternal.rootException == internal);
  assert(detailed.parameters!['bytes'] == 2048);
  assert(detailed.stackTrace.isNotEmpty);
  assert(quietCount == 0, 'construction must be silent without autoLog');
  assert(
    recorder.messages.length == 2,
    'autoLog must write exactly two records: the exception and its trace',
  );
  assert(
    recorder.messages.every((m) => m.contains(logged.uuid)),
    'both autoLog records must carry the exception uuid',
  );
}

void main() => run();
