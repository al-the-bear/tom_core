/// Executable example for the little_things module of `tom_core_flutter`.
///
/// Demonstrates the two client exception types, both ways UI layers
/// discriminate between them — an `is` check and a pair of `on` clauses, where
/// the order is load-bearing — the boundary wrap that gives a lower-layer
/// failure a presentable face, the forwarded kernel payload, including
/// `autoLog`, whose records are captured and printed rather than described, and
/// the message resolution a UI layer performs at the display boundary.
///
/// The barrel import pulls in `flutter/material` (and thus `dart:ui`), so this
/// runs under the Flutter toolchain, not bare `dart run`. Run it with
/// `flutter test test/little_things_test.dart`: that suite calls [run], so the
/// command executes everything below and its exit code says whether the
/// assertions held. Pointing `flutter test` at *this* file also runs it, but
/// then exits 79 ("No tests were found") whether it succeeded or not — an
/// example declares no `test()` of its own. The assertions below need asserts
/// enabled, which `flutter test` does by default.
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
  final uiError = TomClientUIException(
    'login.failed',
    'Could not sign you in.',
  );
  print('ui error: ${uiError.key} -> ${uiError.defaultUserMessage}');

  // Example 2: an internal client error that should not be shown verbatim.
  final internal = TomClientException('cache.miss', 'No cached profile');
  print('internal: ${internal.key} -> ${internal.defaultUserMessage}');

  // Example 3: surface presentable errors, wrap the rest.
  TomClientUIException surface(TomException e) {
    if (e is TomClientUIException) return e;
    return TomClientUIException(
      'app.error',
      'Unexpected error',
      rootException: e,
    );
  }

  final surfacedUi = surface(uiError);
  final surfacedInternal = surface(internal);
  print('surfaced ui identical: ${identical(surfacedUi, uiError)}');
  print(
    'surfaced internal wraps root: ${surfacedInternal.rootException == internal}',
  );

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
  print(
    'autoLog on  — records written on construction: '
    '${recorder.messages.length}',
  );
  for (final message in recorder.messages) {
    // First line only: the stack-trace record runs to many frames.
    print('  ${message.split('\n').first}');
  }
  print(
    'both records carry ${logged.uuid}, so a trace can be joined back to '
    'the failure it came from',
  );

  // Example 6: discriminating with `on` clauses rather than an `is` check.
  //
  // Example 3 asks the type a question; this asks the language to route on it,
  // and that is what most call sites actually write. The two are not
  // interchangeable: an `is` check cannot be written in the wrong order, and
  // order is the one thing a caller can get wrong here.
  String route(TomClientException failure) {
    try {
      throw failure;
    } on TomClientUIException catch (e) {
      return 'banner: ${e.defaultUserMessage}';
    } on TomClientException catch (e) {
      return 'logged: ${e.key}';
    }
  }

  print('route(ui)       -> ${route(uiError)}');
  print('route(internal) -> ${route(internal)}');

  // The same handler with only the general clause. `TomClientUIException` is a
  // subtype, so it lands there too and its presentable message never reaches
  // the banner — the failure is silent rather than loud, which is why it
  // survives review.
  //
  // Spelling the mistake as a literally reversed *pair* would be clearer still,
  // but the analyzer rejects that as `dead_code_on_catch_subtype`. This form is
  // the one that compiles, and therefore the one that ships.
  String routeGeneralOnly(TomClientException failure) {
    try {
      throw failure;
    } on TomClientException catch (e) {
      return 'logged: ${e.key}';
    }
  }

  print(
    'routeGeneralOnly(ui) -> ${routeGeneralOnly(uiError)} '
    '(the presentable message was swallowed)',
  );

  // Example 7: wrapping a lower-layer failure at a boundary.
  //
  // The clause catches the *kernel* type, not the client one. That is the
  // deliberate part: what is being wrapped did not come from the client layer
  // at all, and the wrap is what gives it a presentable face without losing the
  // cause, which stays reachable through `rootException`.
  final serverFailure = TomException('server.down', 'Service unavailable');
  TomClientUIException loadTasks() {
    try {
      throw serverFailure;
    } on TomException catch (e) {
      return TomClientUIException(
        'tasks.unavailable',
        'Tasks are not available right now.',
        rootException: e,
      );
    }
  }

  final unavailable = loadTasks();
  print('wrapped: ${unavailable.key} -> ${unavailable.defaultUserMessage}');
  print(
    'cause preserved: ${identical(unavailable.rootException, serverFailure)}',
  );

  // Example 8: resolving the message for display — at the boundary, not on
  // the exception.
  //
  // `key` is what a UI resolves against the text resources; `defaultUserMessage`
  // is the fallback for when no resource exists. Neither client exception type
  // performs that lookup, and that is the design: an exception is raised in
  // places a resource tree may not exist yet — early start-up, a worker
  // isolate, a unit test — and a type that resolved on construction would fail
  // or quietly degrade in exactly those places.
  //
  // So the lookup belongs to the one layer that already knows a resource tree
  // is installed. It is four lines, and they are these.
  String messageFor(TomException failure) {
    // `getTextOrNull`, never `getText`: the latter echoes the key when the
    // bundle has no entry, which would put `login.failed` in front of a user
    // and discard the fallback this message exists to be.
    final resources = TomTextResourceProvider.getAppResources();
    return resources.getTextOrNull(failure.key) ?? failure.defaultUserMessage;
  }

  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from({
      'login': {'failed': 'Anmeldung fehlgeschlagen.'},
    }),
  );

  final resolved = messageFor(uiError);
  final unresolved = messageFor(internal);
  print('resolved   : ${uiError.key} -> $resolved');
  print('unresolved : ${internal.key} -> $unresolved');
  print(
    'getText would have shown: '
    '${TomTextResourceProvider.getAppResources().getText(internal.key)}',
  );

  // The exception itself is untouched by any of this. The bundle carries an
  // entry under `login.failed` and `defaultUserMessage` still reads as it was
  // written — which is what makes the two independently testable.
  print('the exception still carries: ${uiError.defaultUserMessage}');

  // Assertions
  assert(resolved == 'Anmeldung fehlgeschlagen.');
  assert(
    unresolved == 'No cached profile',
    'a key with no resource falls back to the message the throw site wrote',
  );
  assert(
    uiError.defaultUserMessage == 'Could not sign you in.',
    'resolution happens at the boundary; the exception is not rewritten',
  );
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
  assert(
    route(uiError) == 'banner: Could not sign you in.',
    'the subtype clause must run first for a presentable failure',
  );
  assert(
    route(internal) == 'logged: cache.miss',
    'a plain client failure must fall through to the general clause',
  );
  assert(
    routeGeneralOnly(uiError) == 'logged: login.failed',
    'a general clause alone must swallow the presentable subtype',
  );
  assert(unavailable.key == 'tasks.unavailable');
  assert(identical(unavailable.rootException, serverFailure));
}

void main() => run();
