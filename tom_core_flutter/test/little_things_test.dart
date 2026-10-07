import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

import '../example/little_things/little_things_example.dart' as example;
import 'support/exception_constructor_mirror.dart';

/// A log output that keeps what it is given, so a test can assert on the
/// records `autoLog` writes instead of only on the flag that causes them.
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

/// Runs [body] with the log captured, and returns what was written.
///
/// The output is restored in a `finally`: a failing expectation inside [body]
/// would otherwise leave the recorder installed and silence every later test
/// in the process.
List<String> recordedLogs(void Function() body) {
  final recorder = _RecordingLogOutput();
  final previousOutput = tomLog.logOutput;
  tomLog.logOutput = recorder;
  try {
    body();
  } finally {
    tomLog.logOutput = previousOutput;
  }
  return recorder.messages;
}

/// Tests for the little_things module (`TomClientException`,
/// `TomClientUIException`).
void main() {
  group('TomClientException', () {
    test('carries the key, message and parameters', () {
      final ex = TomClientException(
        'client.error',
        'Something went wrong',
        parameters: {'field': 'email'},
      );
      expect(ex.key, 'client.error');
      expect(ex.defaultUserMessage, 'Something went wrong');
      expect(ex.parameters, {'field': 'email'});
    });

    test('is a kernel TomException', () {
      final ex = TomClientException('client.error', 'msg');
      expect(ex, isA<TomException>());
    });

    test('is not a TomClientUIException', () {
      final ex = TomClientException('client.error', 'msg');
      expect(ex, isNot(isA<TomClientUIException>()));
    });

    // Full-surface: the constructor forwards every optional argument to the
    // kernel TomException. `parameters`/`rootException` are covered above; these
    // pin the remaining two — `stack` (the raw trace object) and `autoLog`.
    test('forwards the stack trace object to the kernel exception', () {
      final trace = StackTrace.current;
      final ex = TomClientException('client.error', 'msg', stack: trace);
      expect(identical(ex.stack, trace), isTrue);
      // The formatted representation is derived from the forwarded trace.
      expect(ex.stackTrace, isNotEmpty);
    });

    test('forwards the autoLog flag (default false, honours true)', () {
      expect(TomClientException('client.error', 'msg').autoLog, isFalse);
      // Captured only to keep the log this construction writes out of the test
      // output; what it emits is the next test's subject.
      late final TomClientException ex;
      recordedLogs(() {
        ex = TomClientException('client.error', 'msg', autoLog: true);
      });
      expect(ex.autoLog, isTrue);
    });

    test('autoLog writes the exception and its trace on construction', () {
      // The flag above is the cause; these are the effect, and the effect is
      // what callers are choosing when they pass it. Asserting only the field
      // would keep passing if the kernel stopped logging altogether.
      late final TomClientException logged;
      final quiet = recordedLogs(() {
        TomClientException('client.error', 'msg');
      });
      final noisy = recordedLogs(() {
        logged = TomClientException('client.error', 'msg', autoLog: true);
      });

      expect(quiet, isEmpty, reason: 'construction must be silent by default');
      expect(noisy, hasLength(2));
      expect(noisy.first, startsWith('EXCEPTION: '));
      expect(noisy.last, startsWith('EXCEPTION_STACKTRACE: '));
      // Both records name the same exception, so a trace can be joined back to
      // the failure it came from.
      expect(noisy.every((m) => m.contains(logged.uuid)), isTrue);
    });
  });

  group('TomClientUIException', () {
    test('is both a TomClientException and a TomException', () {
      final ex = TomClientUIException('ui.error', 'Please try again');
      expect(ex, isA<TomClientException>());
      expect(ex, isA<TomException>());
      expect(ex.key, 'ui.error');
      expect(ex.defaultUserMessage, 'Please try again');
    });

    test('forwards stack, parameters and autoLog through both super calls', () {
      final trace = StackTrace.current;
      late final TomClientUIException ex;
      // Captured rather than left to the console: these arguments travel two
      // super calls rather than one, so the records are the evidence that the
      // flag survived the extra hop instead of merely being stored.
      final logs = recordedLogs(() {
        ex = TomClientUIException(
          'ui.error',
          'Please try again',
          parameters: {'retryable': true},
          stack: trace,
          autoLog: true,
        );
      });
      expect(ex.parameters, {'retryable': true});
      expect(identical(ex.stack, trace), isTrue);
      expect(ex.autoLog, isTrue);
      expect(logs, hasLength(2));
      expect(logs.every((m) => m.contains(ex.uuid)), isTrue);
    });

    test('type discriminates user-facing from internal client errors', () {
      // A presentable error rethrows; a non-presentable one is wrapped.
      TomException surface(TomException e) {
        if (e is TomClientUIException) return e;
        return TomClientUIException(
          'wrapped',
          'Unexpected error',
          rootException: e,
        );
      }

      final presentable = TomClientUIException('ui.error', 'Shown to user');
      final internal = TomClientException('internal', 'Do not show');

      expect(identical(surface(presentable), presentable), isTrue);
      final wrapped = surface(internal);
      expect(wrapped, isA<TomClientUIException>());
      expect(wrapped.rootException, internal);
    });
  });

  group('the three identifying arguments', () {
    // `uuid`, `requestUuid` and `serverCallError` say *which* failure this is
    // and where it came from, rather than what it was. They were reachable only
    // by assignment after construction, which is a different promise: a report
    // edited between the throw and the catch describes a failure the code in
    // between decided on.
    for (final build
        in <
          TomClientException Function({
            String? uuid,
            String? requestUuid,
            TomServerCallError? serverCallError,
          })
        >[
          ({uuid, requestUuid, serverCallError}) => TomClientException(
            'client.error',
            'msg',
            uuid: uuid,
            requestUuid: requestUuid,
            serverCallError: serverCallError,
          ),
          ({uuid, requestUuid, serverCallError}) => TomClientUIException(
            'ui.error',
            'msg',
            uuid: uuid,
            requestUuid: requestUuid,
            serverCallError: serverCallError,
          ),
        ]) {
      final typeName = build().runtimeType.toString();

      test('$typeName forwards a supplied uuid', () {
        // The case that needs it: a failure rebuilt from a server's envelope
        // has to keep the identity the far side logged it under, and a
        // generated one can never be matched back to that log line.
        expect(
          build(uuid: 'UUID-FROM-THE-SERVER').uuid,
          'UUID-FROM-THE-SERVER',
        );
      });

      test('$typeName still generates a uuid when none is given', () {
        final first = build();
        final second = build();
        expect(first.uuid, isNotEmpty);
        expect(first.uuid, isNot(second.uuid));
      });

      test('$typeName forwards requestUuid', () {
        expect(build(requestUuid: 'REQ-7').requestUuid, 'REQ-7');
        expect(build().requestUuid, isNull);
      });

      test('$typeName forwards serverCallError', () {
        final callError = TomServerCallError(
          statusCode: 503,
          response: 'unavailable',
        );
        final ex = build(serverCallError: callError);
        expect(identical(ex.serverCallError, callError), isTrue);
        expect(build().serverCallError, isNull);
      });
    }
  });

  group('the rest of the documented surface', () {
    test('toString names the identity, the type and the whole payload', () {
      // The format a log line and a debugger both show. Asserted by its parts
      // rather than as one literal: the order is the kernel's to change, the
      // presence of each part is what a reader relies on.
      final cause = TomException('server.down', 'Service unavailable');
      final error = TomClientUIException(
        'tasks.unavailable',
        'Tasks are not available right now.',
        requestUuid: 'REQ-9',
        parameters: {'retryable': true},
        rootException: cause,
      );

      final rendered = error.toString();
      expect(rendered, contains(error.uuid));
      expect(rendered, contains('REQ-9'));
      expect(rendered, contains('TomClientUIException'));
      expect(rendered, contains('tasks.unavailable'));
      expect(rendered, contains('Tasks are not available right now.'));
      expect(rendered, contains('retryable'));
      expect(rendered, contains('server.down'));
    });

    test('and logRepresentation is the same string', () {
      // `TomLoggable`'s rendering. Equal by construction today, which is worth
      // pinning precisely because it is: a log line and a debugger view that
      // silently diverged would be two descriptions of one failure.
      final error = TomClientException('cache.miss', 'No cached profile');

      expect(error.logRepresentation, error.toString());
    });

    test('a non-trace stack is refused at the call site', () {
      // `stack` is `StackTrace?` on both the field and the kernel constructor,
      // so a literal non-trace does not compile. `dynamic` is the only way
      // past the compiler, and it fails at the *argument*: the downcast happens
      // at the call boundary, so the exception object is never built and the
      // trace names the mistake rather than the reporting code.
      //
      // Worth a case because the opposite has been reported twice — as a
      // `TypeError` thrown from inside the constructor, "while reporting some
      // other failure". It is not that, and this is what says so.
      dynamic notATrace = 'not-a-trace';

      expect(
        () => TomClientException('client.error', 'msg', stack: notATrace),
        throwsA(isA<TypeError>()),
      );
    });

    test('a real trace is kept as given', () {
      // The other arm of the same boundary, so the refusal above cannot be
      // read as "stack is awkward".
      final trace = StackTrace.current;
      final error = TomClientUIException('ui.error', 'msg', stack: trace);

      expect(identical(error.stack, trace), isTrue);
      expect(error.stackTrace, isNotEmpty);
    });

    test('the UI subtype inherits the autoLog default, and its silence', () {
      // The `TomClientException` case pins both arms; this one is the arm that
      // travels through *two* super calls carrying an inherited default value,
      // which is the fragile one. The flag alone is not enough — a default that
      // arrived as `false` but logged anyway would pass a field check.
      late final TomClientUIException ex;
      final records = recordedLogs(() {
        ex = TomClientUIException('ui.error', 'Please try again');
      });

      expect(ex.autoLog, isFalse);
      expect(
        records,
        isEmpty,
        reason: 'construction must be silent without the flag, two hops down',
      );
    });
  });

  group('discriminating with catch clauses', () {
    // The `is` check above and these `on` clauses answer the same question, but
    // they are not equally easy to get wrong. An `is` check has no order: each
    // branch names its own type and the compiler cannot mistake one for
    // another. A chain of `on` clauses is ordered, the first match wins, and
    // `TomClientUIException` is a subtype of `TomClientException` — so a general
    // clause placed ahead of the specific one takes every failure and the
    // presentable message is never shown.
    //
    // That order rule is stated in the class dartdoc and in the module readme,
    // and it is the one thing a consumer can actually get wrong. Stating it
    // three times and testing it nowhere is what these cases fix.

    /// The correct shape: specific clause first, general clause second.
    ///
    /// The parameter is the *kernel* type so that the handler's reach is
    /// testable — it handles client failures and nothing else, and what it
    /// leaves alone matters as much as what it takes.
    String route(TomException failure) {
      try {
        throw failure;
      } on TomClientUIException catch (e) {
        return 'banner: ${e.defaultUserMessage}';
      } on TomClientException catch (e) {
        return 'logged: ${e.key}';
      }
    }

    /// The mistake, in the only spelling that compiles.
    ///
    /// A literally reversed pair — `on TomClientException` before
    /// `on TomClientUIException` — is rejected by the analyzer as
    /// `dead_code_on_catch_subtype`, so no consumer can ship it. What a
    /// consumer *can* ship is a handler that only ever grew the general clause,
    /// and its effect is identical: the subtype is swallowed.
    String routeGeneralOnly(TomException failure) {
      try {
        throw failure;
      } on TomClientException catch (e) {
        return 'logged: ${e.key}';
      }
    }

    test('the specific clause takes a presentable failure', () {
      expect(
        route(TomClientUIException('login.failed', 'Could not sign you in.')),
        'banner: Could not sign you in.',
      );
    });

    test('the general clause takes a failure that is not presentable', () {
      expect(
        route(TomClientException('cache.miss', 'No cached profile')),
        'logged: cache.miss',
      );
    });

    test('a general clause alone swallows the presentable subtype', () {
      // The point of the pair: identical input, and the message the user was
      // supposed to see does not appear in the result at all.
      final presentable = TomClientUIException(
        'login.failed',
        'Could not sign you in.',
      );
      expect(route(presentable), 'banner: Could not sign you in.');
      expect(routeGeneralOnly(presentable), 'logged: login.failed');
    });

    test('neither client clause catches a kernel failure', () {
      // Why the boundary wrap below catches `TomException` and not
      // `TomClientException`: a failure raised below the client layer walks
      // straight past both clauses.
      expect(
        () => route(TomException('server.down', 'Service unavailable')),
        throwsA(
          allOf(
            isA<TomException>().having((e) => e.key, 'key', 'server.down'),
            isNot(isA<TomClientException>()),
          ),
        ),
      );
    });

    test('a kernel failure is wrapped at a layer boundary', () {
      // `on TomException` rather than `on TomClientException` is the deliberate
      // choice: what is being wrapped came from a lower layer, which is exactly
      // the distinction the client type exists to draw.
      TomClientUIException loadTasks(void Function() call) {
        try {
          call();
          fail('the call under test was expected to throw');
        } on TomException catch (e) {
          return TomClientUIException(
            'tasks.unavailable',
            'Tasks are not available right now.',
            rootException: e,
          );
        }
      }

      final serverFailure = TomException('server.down', 'Service unavailable');
      final wrapped = loadTasks(() => throw serverFailure);

      expect(wrapped.key, 'tasks.unavailable');
      expect(wrapped.defaultUserMessage, 'Tasks are not available right now.');
      expect(identical(wrapped.rootException, serverFailure), isTrue);
    });

    test('the wrap is what makes a lower-layer failure presentable', () {
      // Without it the failure reaching the UI is a `TomException` whose
      // message is written for an operator, not for a user — which is the
      // reason the boundary exists.
      final serverFailure = TomException('server.down', 'Service unavailable');
      expect(serverFailure, isNot(isA<TomClientUIException>()));
      expect(
        TomClientUIException(
          'tasks.unavailable',
          'Tasks are not available right now.',
          rootException: serverFailure,
        ),
        isA<TomClientUIException>(),
      );
    });
  });

  group('resolving the message for display', () {
    // Every artefact says the same thing: `key` is what a UI resolves against
    // the text resources and `defaultUserMessage` is the fallback. Nothing in
    // the exception types performs that lookup, and that is the decision rather
    // than an omission — so both halves are asserted here, the refusal and the
    // pattern that replaces it.
    setUp(TomTextResourceProvider.clearAppResourceProvider);
    tearDown(TomTextResourceProvider.clearAppResourceProvider);

    void installResources(Map<String, dynamic> bundle) =>
        TomTextResourceProvider.setAppResourceProvider(
          TomTextResourceProvider.from(bundle),
        );

    /// The lookup a UI layer performs at the display boundary — the shape
    /// `doc/little_things.md` documents, executed rather than quoted.
    String messageFor(TomException failure) =>
        TomTextResourceProvider.getAppResources().getTextOrNull(failure.key) ??
        failure.defaultUserMessage;

    test('the exception does not resolve, even when the bundle could', () {
      // The negative with teeth: a resource entry exists under this exact key,
      // and the exception still answers the string the throw site wrote. A
      // convenience getter added later would have to break this.
      installResources({
        'login': {'failed': 'Anmeldung fehlgeschlagen.'},
      });

      final error = TomClientUIException('login.failed', 'Could not sign in.');

      expect(error.defaultUserMessage, 'Could not sign in.');
      expect(error.toString(), contains('Could not sign in.'));
    });

    test('the source names no part of the resource layer', () {
      // The dependency-free half of the decision, read off the file rather
      // than trusted. A resolving getter cannot be added without touching one
      // of these names.
      final source = File(
        'lib/src/tomclient/little_things/client_exceptions.dart',
      ).readAsStringSync();
      // The dartdoc explains what the class deliberately does not do, so only
      // the code is read.
      final code = source
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('///'))
          .join('\n');

      for (final name in const [
        'TomTextResourceProvider',
        'getAppResources',
        'getText',
        'TomProperty',
      ]) {
        expect(
          code,
          isNot(contains(name)),
          reason: 'the exception types stay independent of the resource layer',
        );
      }
    });

    test('the documented lookup answers from the bundle when it can', () {
      installResources({
        'login': {'failed': 'Anmeldung fehlgeschlagen.'},
      });

      expect(
        messageFor(TomClientUIException('login.failed', 'Could not sign in.')),
        'Anmeldung fehlgeschlagen.',
      );
    });

    test('and falls back to the message the throw site wrote', () {
      installResources({});

      expect(
        messageFor(TomClientUIException('login.failed', 'Could not sign in.')),
        'Could not sign in.',
      );
    });

    test('which is why the contract names getTextOrNull, not getText', () {
      // The trap the wording exists to avoid: `getText` echoes the key on a
      // miss, so a helper written with it shows `login.failed` to a user and
      // discards the fallback entirely. Asserted rather than warned about,
      // because the two calls differ by four characters.
      installResources({});
      final resources = TomTextResourceProvider.getAppResources();

      expect(resources.getText('login.failed'), 'login.failed');
      expect(resources.getTextOrNull('login.failed'), isNull);
    });

    test('an uninstalled bundle throws, so the boundary must expect it', () {
      // The situation the decision's reasoning names — early start-up, a worker
      // isolate, a unit test. Reading resources there does not degrade quietly;
      // it fails. An exception type that resolved on construction would carry
      // that failure into every one of those places, which is the case for
      // keeping the lookup at the boundary that knows a tree exists.
      final error = TomClientUIException('login.failed', 'Could not sign in.');

      expect(
        () => messageFor(error),
        throwsA(
          isA<TomResourceException>().having(
            (e) => e.key,
            'key',
            'resources.text_provider.not_installed',
          ),
        ),
      );
      // Constructing and reading the exception itself is unaffected, which is
      // the property that makes it usable there at all.
      expect(error.defaultUserMessage, 'Could not sign in.');
    });
  });

  group('the limitations the module document states', () {
    // Each bullet of `doc/little_things.md`'s Limitations section is a claim
    // about behaviour, so each one that can be executed is executed here. A
    // limitation nobody can check is indistinguishable from a limitation that
    // has quietly stopped being true.
    test('the payload stays writable after construction', () {
      // The constructor is where a complete report is assembled — but nothing
      // *enforces* that, and the fields are public. A caller five frames up can
      // rewrite the failure it is about to report.
      final error = TomClientException(
        'upload.failed',
        'Upload failed',
        parameters: {'bytes': 1},
      );

      final laterTrace = StackTrace.current;
      final laterCause = TomException('server.down', 'Service unavailable');

      error.key = 'something.else';
      error.defaultUserMessage = 'Rewritten';
      error.requestUuid = 'REQ-LATER';
      error.uuid = 'UUID-LATER';
      error.parameters = {'bytes': 99};
      error.stack = laterTrace;
      error.rootException = laterCause;

      // All seven the Limitations bullet names, asserted together: the bullet
      // is a claim about the whole payload, and a test covering four of them
      // would let the other three become `final` without anyone noticing the
      // document had gone stale.
      expect(error.key, 'something.else');
      expect(error.defaultUserMessage, 'Rewritten');
      expect(error.requestUuid, 'REQ-LATER');
      expect(error.uuid, 'UUID-LATER');
      expect(error.parameters, {'bytes': 99});
      expect(identical(error.stack, laterTrace), isTrue);
      expect(identical(error.rootException, laterCause), isTrue);
    });

    test('but autoLog and serverCallError are constructor-only', () {
      // The two the kernel declares `final`, and the reason the seven above
      // are worth naming individually rather than as "the payload": this is
      // not a class where everything is writable. Both are read off the kernel
      // source, because "you cannot assign it" is exactly the assertion a test
      // cannot make by assigning it — the line would not compile.
      final kernel = File(kernelExceptionPath).readAsStringSync();

      expect(kernel, contains('final bool autoLog;'));
      expect(kernel, contains('final TomServerCallError? serverCallError;'));
    });

    test('and the parameters map is held by reference', () {
      // Not a copy: the caller's map is the exception's map, so editing either
      // edits both. Worth stating because `parameters` is the one argument
      // callers routinely build inline and then reuse.
      final context = <String, Object?>{'bytes': 1};
      final error = TomClientException(
        'upload.failed',
        'msg',
        parameters: context,
      );

      context['bytes'] = 2;

      expect(error.parameters!['bytes'], 2);
    });

    test('a wrap does not share its cause identity', () {
      // `rootException` is the only link between a wrapped failure and its
      // cause. Two log lines about one incident carry two uuids, so joining
      // them means following the reference, not matching an id.
      final cause = TomException('server.down', 'Service unavailable');
      final wrap = TomClientUIException(
        'tasks.unavailable',
        'Tasks are not available right now.',
        rootException: cause,
      );

      expect(identical(wrap.rootException, cause), isTrue);
      expect(wrap.uuid, isNot(cause.uuid));
      expect(wrap.requestUuid, isNull);
    });

    test('autoLog writes at construction, with no throw involved', () {
      // The flag is named for logging, but what it is tied to is *building*
      // the object. An exception constructed for a test, or built and then
      // discarded on a branch that decided not to throw, is logged all the
      // same.
      final records = recordedLogs(() {
        TomClientException('sync.failed', 'Sync failed', autoLog: true);
      });

      expect(records, hasLength(2));
    });

    test('the document carries the section, and it is not empty', () {
      // The section is the deliverable; this is what keeps it from being
      // quietly dropped in a later edit that finds it inconvenient.
      final document = File('doc/little_things.md').readAsStringSync();

      expect(document, contains('## Limitations'));
      final section = document
          .split('## Limitations')
          .last
          .split('\n## ')
          .first;
      final bullets = section
          .split('\n')
          .where((line) => line.startsWith('- '))
          .toList();
      expect(
        bullets.length,
        greaterThanOrEqualTo(5),
        reason:
            'the Limitations section exists to tell a consumer what this '
            'module does not do; an empty one is worse than none',
      );
    });
  });

  group('the module readme describes a role, not just its contents', () {
    // `little_things` is the same directory in all three tom_core packages:
    // where a small cross-cutting thing lands once more than one module needs
    // it. The kernel's holds zone accessors, trace helpers and atomic writes;
    // the server's held two exception classes and nothing else until it
    // acquired a request-id type and a wire-envelope helper within a fortnight.
    //
    // The client's holds exceptions only, so far — and the risk is that a
    // future helper gets parked somewhere more specific because this directory
    // reads as "the exceptions folder". The readme is what prevents that, by
    // presenting the exception family as the current contents of a general
    // module rather than as the module's definition. That is a promise about
    // wording, so it is worth a test: prose has no compiler.
    const readmePath = 'lib/src/tomclient/little_things/readme.md';

    /// The readme's paragraphs, each with its hard wrapping flowed back into a
    /// single line so a phrase that straddles a line break still matches.
    List<String> paragraphs() => File(readmePath)
        .readAsStringSync()
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((p) => p.isNotEmpty)
        .toList();

    test('it still names the general role the directory plays', () {
      // Checked separately from the paragraph below: a readme that dropped the
      // general framing but kept the word "Today" would pass that test while
      // having lost the point of it.
      expect(
        paragraphs().join(' '),
        contains('cross-cutting'),
        reason:
            'the readme must describe the module by the role it plays, '
            'not only by the two classes currently in it',
      );
    });

    test('it presents the exception family as the current contents', () {
      final describing = paragraphs()
          .where((p) => p.contains('exception family'))
          .toList();
      expect(
        describing,
        isNotEmpty,
        reason:
            'no paragraph of $readmePath describes the exception family; '
            'this guard has lost the text it was written to watch',
      );

      // A qualifier, not one specific sentence. Forbidding a phrasing would be
      // satisfied by deleting the sentence; requiring one would freeze it.
      final qualified = RegExp(
        r'\b(today|currently|at present|for now|so far|at the moment)\b',
        caseSensitive: false,
      );
      expect(
        describing.where(qualified.hasMatch),
        isNotEmpty,
        reason:
            'the paragraph introducing the exception family must mark it '
            'as the module\'s present contents — otherwise the readme reads '
            'as though `little_things` means "exceptions" on the client, and '
            'the next cross-cutting helper goes somewhere else',
      );
    });
  });

  group('the API summary mirrors the little_things sources', () {
    // The `doc/` API summary is a mirror of the source, and a mirror is to be
    // verified rather than trusted: nothing regenerates it, so a hand-edit that
    // gets a parameter's type wrong stands until a reader trusts it and writes
    // a call the compiler rejects. This performs the verification on every run.
    //
    // The checks themselves live in `support/exception_constructor_mirror.dart`
    // because `preferences` and `configuration` need the identical ones — their
    // exceptions are declared the same way, and their summaries drifted the
    // same way. That file also explains why the types must be read from the
    // kernel constructor rather than from the field declarations; the short
    // version is that a super-parameter resolves against the immediate
    // superclass constructor, and for `stack` the two disagree.
    const summaryPath = 'doc/api/api_summary_little_things.md';
    const sourcePath = 'lib/src/tomclient/little_things/client_exceptions.dart';
    const classNames = ['TomClientException', 'TomClientUIException'];
    final kernel = File(kernelExceptionPath).readAsStringSync();

    test('the summary shows the parameters the source actually forwards', () {
      expectSummaryListsForwardedParameters(
        summaryPath: summaryPath,
        sourcePaths: const [sourcePath],
        classNames: classNames,
      );
    });

    test(
      'every parameter type matches the kernel constructor it comes from',
      () {
        expectSummaryTypesMatchKernel(
          summaryPath: summaryPath,
          classNames: classNames,
        );
      },
    );

    test('the kernel constructor parser reports the types it should', () {
      // Without this the two tests above pass just as happily on an empty
      // parse. These three are the ones the mirror got wrong or was accused
      // of getting wrong, so pinning them pins the parser where it matters.
      //
      // It is deliberately the only copy: the parser is now shared with the
      // `preferences` and `configuration` guards, so pinning it once pins it
      // for all three, and a second copy would only be a second thing to keep
      // in step.
      final parsed = kernelParameters();
      expect(parsed['stack'], 'StackTrace?');
      expect(parsed['autoLog'], 'bool = false');
      expect(parsed['parameters'], 'Map<String, Object?>?');
    });

    test('the class hierarchy is drawn as deep as the source goes', () {
      // Conditioned on the source rather than hard-coded: if a base class is
      // ever inserted or removed, this fails rather than silently blessing a
      // diagram that no longer describes anything.
      final summary = File(summaryPath).readAsStringSync();
      final hierarchy = RegExp(
        r'## Class Hierarchy\n+```\n([\s\S]*?)```',
      ).firstMatch(summary);
      expect(hierarchy, isNotNull, reason: 'no class hierarchy block');

      final bases = <String>[];
      for (var type in const ['TomClientUIException', 'TomClientException']) {
        while (true) {
          final source = type.startsWith('TomClient')
              ? File(sourcePath).readAsStringSync()
              : kernel;
          final extends_ = RegExp(
            'class $type extends (\\w+)',
          ).firstMatch(source)?.group(1);
          if (extends_ == null) break;
          bases.add(extends_);
          type = extends_;
        }
        break;
      }
      // TomBaseException lives in tom_basics, which the walk above cannot
      // reach — it stops when it runs out of readable source, and that last
      // name is exactly the one the diagram used to omit.
      expect(bases, contains('TomBaseException'));

      for (final name in bases) {
        expect(
          hierarchy!.group(1),
          contains(name),
          reason:
              '`$name` is in the chain above TomClientUIException but is '
              'missing from the hierarchy diagram',
        );
      }
    });
  });

  group('the shipped example runs', () {
    const examplePath = 'example/little_things/little_things_example.dart';
    const sourcePath = 'lib/src/tomclient/little_things/client_exceptions.dart';

    /// The example's source split into its comment lines and its code lines.
    ({String comments, String code}) exampleText() {
      final comments = StringBuffer();
      final code = StringBuffer();
      for (final line in File(examplePath).readAsLinesSync()) {
        (line.trimLeft().startsWith('//') ? comments : code).writeln(line);
      }
      return (comments: comments.toString(), code: code.toString());
    }

    /// The named arguments `TomClientException` forwards to the kernel, read
    /// from the source rather than listed here — a seventh added tomorrow is
    /// then covered without anyone remembering to extend this test.
    Set<String> forwardedNamedArguments() {
      final source = File(sourcePath).readAsStringSync();
      final start = source.indexOf('TomClientException(');
      expect(start, isNot(-1), reason: 'no TomClientException constructor');
      final open = source.indexOf('{', start);
      final close = source.indexOf('}', open);
      expect(
        open,
        isNot(-1),
        reason: 'the constructor takes no named arguments',
      );
      return RegExp(r'super\.(\w+)')
          .allMatches(source.substring(open, close))
          .map((m) => m.group(1)!)
          .toSet();
    }

    test('little_things_example.run() completes its assertions', () {
      // The example is quoted as documentation, so it has to be executable
      // documentation. Running it here is what stops a snippet that no longer
      // compiles — or an assertion that no longer holds — from being shown to
      // a reader as the way to use the module. It is also what makes the
      // `autoLog` demonstration below mean anything: the example asserts on
      // the records the constructor wrote, and those assertions only run when
      // something runs the example.
      example.run();
    });

    test('it names no forwarded argument that it never passes', () {
      final text = exampleText();
      final advertised = forwardedNamedArguments()
          .where((name) => text.comments.contains('`$name`'))
          .toList();
      expect(
        advertised,
        isNotEmpty,
        reason:
            'the example no longer describes the forwarded payload at all, '
            'so this guard has lost the text it was written to watch',
      );
      final unpassed = advertised
          .where((name) => !text.code.contains('$name:'))
          .toList();
      expect(
        unpassed,
        isEmpty,
        reason:
            'the example introduces ${unpassed.join(', ')} in a comment '
            'and never passes it — an example that narrates instead of '
            'demonstrating compiles, runs, and proves nothing',
      );
    });

    test('it demonstrates autoLog rather than describing it', () {
      // The general guard above is satisfied by deleting the mention, which
      // would be the wrong repair: of the forwarded arguments this is the only
      // one with an observable side effect, so it is the only one an example
      // can show rather than tell.
      expect(
        exampleText().code,
        contains('autoLog: true'),
        reason: 'autoLog is only demonstrated by passing it',
      );
    });

    test('it discriminates with catch clauses, not only with `is`', () {
      // The module's stated reason for existing is that `on X catch` clauses
      // separate a presentable client failure from a non-presentable one, and
      // the single rule a consumer can get wrong is the order of those clauses.
      // An `is` check has no order, so an example built only on `is` cannot
      // show the mistake — which is how the rule came to be asserted in the
      // dartdoc, the readme and the completion document, and executed nowhere.
      final code = exampleText().code;
      expect(code, contains('on TomClientUIException catch'));
      expect(code, contains('on TomClientException catch'));
      expect(
        code,
        contains('on TomException catch'),
        reason:
            'the boundary wrap catches the kernel type rather than the '
            'client one, and that choice is the whole point of it',
      );
      expect(
        code.indexOf('on TomClientUIException catch'),
        lessThan(code.indexOf('on TomClientException catch')),
        reason:
            'the specific clause has to come first — a reader copying this '
            'takes the order from the code, not from the prose beside it',
      );
    });
  });
}
