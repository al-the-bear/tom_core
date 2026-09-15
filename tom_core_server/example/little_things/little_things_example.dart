/// Executable example for the little-things module of `tom_core_server`.
///
/// The module contributes three types. [TomRequestId] is the per-request
/// correlation id (step 1) — the primitive the rest of the package reads out of
/// the zone. [TomServerException] is the base class for every server-raised
/// exception, and steps 2-5 show its three distinguishing features: isolate
/// attribution, the `clientThrow` flag, and the zone-based request correlation
/// that consumes step 1's type. [TomLoginException] is the one exception
/// subclass declared beside the base; step 6 shows what follows from it adding
/// no members — a clause written for the base type catches it, which is how the
/// pipeline reaches every server exception with one `on TomServerException`.
/// The login flow that raises and catches it is in `doc/authentication.md`.
///
/// Run with `dart run example/little_things/little_things_example.dart`. Every
/// step checks its own result and the run fails when one does not hold, so a
/// green run is a verification and not just a transcript. The same behaviour is
/// covered by `test/little_things_test.dart`.
library;

import 'dart:async';

import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';

void run() {
  // 1. Every request gets a fresh correlation id. The server's authentication
  //    middleware makes one per request and publishes it into the zone; the
  //    type is declared here because this module is where it is consumed.
  final id1 = TomRequestId();
  final id2 = TomRequestId();
  print('1. request id      => $id1');
  print('   distinct?       => ${id1.uuid != id2.uuid}');
  check(id1.uuid.isNotEmpty, 'a new request id arrives already identified');
  check(
    id1.uuid != id2.uuid,
    'two requests never share a correlation id, so a log line names one of them',
  );
  check(
    id1.toString() == 'TomRequestId: ${id1.uuid}',
    'the rendering carries the bare uuid, so a log line stays greppable by it',
  );

  // 2. A server exception carries the kernel TomException surface (key,
  //    user message) plus the originating isolate name.
  final basic = TomServerException(
    'payment.charge.failed',
    'The payment failed',
  );
  print('2. key             => ${basic.key}');
  print('   isolateName     => ${basic.isolateName}');
  print('   clientThrow     => ${basic.clientThrow}');
  check(
    basic.key == 'payment.charge.failed',
    'a server exception keeps the kernel key it was raised with',
  );
  check(
    basic.isolateName.isNotEmpty,
    'a server exception names the isolate it came from, without being told',
  );
  check(
    basic.clientThrow == true,
    'a server exception is reported to the client unless it says otherwise',
  );

  // 3. Mark internal failures clientThrow: false so the pipeline masks them.
  final internal = TomServerException(
    'storage.connect.unavailable',
    'Database unavailable',
    clientThrow: false,
  );
  print('3. internal clientThrow => ${internal.clientThrow}');
  check(
    internal.clientThrow == false,
    'an internal failure is marked for masking before it reaches a client',
  );

  // 4. Constructed outside a request zone, requestUuid is unset — and the
  //    rendering drops the request segment rather than trailing a bare null.
  print('4. requestUuid (no zone) => ${basic.requestUuid}');
  print('   rendered         => $basic');
  check(
    basic.requestUuid == null,
    'an exception raised outside a request belongs to no request',
  );
  check(
    basic.toString().endsWith('client-throw: true'),
    'the rendering stops rather than trailing a request segment with no request',
  );

  // 5. Constructed inside a zone carrying a TomRequestId, the exception
  //    correlates itself with the active request automatically, and says so
  //    with a label. The base string leads with the composite token
  //    `<exception-uuid>-<request-uuid>`, which cannot be split by eye because
  //    v4 UUIDs contain hyphens — the labelled copy is the greppable one.
  final requestId = TomRequestId();
  runZoned(() {
    final correlated = TomServerException(
      'request.validate.bad_input',
      'Bad input',
    );
    print('5. requestUuid (in zone) => ${correlated.requestUuid}');
    print('   rendered         => $correlated');
    check(
      correlated.requestUuid == requestId.uuid,
      'an exception raised while serving a request correlates itself with it, '
      'with nothing passed in',
    );
    check(
      correlated.toString().endsWith(' request: ${requestId.uuid}'),
      'the labelled segment separates the two uuids that the composite token '
      'runs together',
    );
  }, zoneValues: {TomRequestId: requestId});

  // 6. One clause written for the base type catches TomLoginException along
  //    with every other server exception, and the subclass arrives with its
  //    own payload intact — including the closed-set `reason` a client
  //    switches on instead of matching the free-form key. Note it is
  //    client-visible: its constructor does not accept `clientThrow`, while
  //    the rest of the authentication subsystem's exceptions set it false.
  //    `clientThrow` is final, so that holds for every instance rather than
  //    just the one this example builds.
  try {
    throw TomLoginException(
      'error.invalid-user-or-password',
      'The username or password is not correct.',
      reason: TomLoginFailure.accountProblem,
    );
  } on TomServerException catch (e) {
    print('6. caught as       => ${e.runtimeType}');
    print('   key             => ${e.key}');
    print('   clientThrow     => ${e.clientThrow}');
    print('   loginFailure    => ${tomErrorEnvelope(e)['loginFailure']}');
    check(
      e is TomLoginException,
      'one clause on the base type reaches the login subclass as well',
    );
    check(
      e is TomLoginException && e.reason == TomLoginFailure.accountProblem,
      'the reason travels with the exception, so a caller branches on a '
      'closed set rather than matching the key string',
    );
    check(
      tomErrorEnvelope(e)['loginFailure'] == 'accountProblem',
      'and it reaches the wire, which is where a client reads it',
    );
    check(
      e.key == 'error.invalid-user-or-password',
      'the subclass survives the base-typed clause with its own key intact',
    );
    check(
      e.clientThrow == true,
      'a rejected login is told to the user rather than masked as internal',
    );
  }

  print('\nLittle-things example completed.');
}

void main() {
  run();
}
