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
/// Run with `dart run example/little_things/little_things_example.dart`.
/// The same behaviour is covered by `test/little_things_test.dart`.
library;

import 'dart:async';

import 'package:tom_core_server/tom_core_server.dart';

void run() {
  // 1. Every request gets a fresh correlation id. The server's authentication
  //    middleware makes one per request and publishes it into the zone; the
  //    type is declared here because this module is where it is consumed.
  final id1 = TomRequestId();
  final id2 = TomRequestId();
  print('1. request id      => $id1');
  print('   distinct?       => ${id1.uuid != id2.uuid}');
  assert(id1.uuid.isNotEmpty);
  assert(id1.uuid != id2.uuid);
  assert(id1.toString() == 'TomRequestId: ${id1.uuid}');

  // 2. A server exception carries the kernel TomException surface (key,
  //    user message) plus the originating isolate name.
  final basic = TomServerException(
    'payment.charge.failed',
    'The payment failed',
  );
  print('2. key             => ${basic.key}');
  print('   isolateName     => ${basic.isolateName}');
  print('   clientThrow     => ${basic.clientThrow}');
  assert(basic.key == 'payment.charge.failed');
  assert(basic.isolateName.isNotEmpty);
  assert(basic.clientThrow == true);

  // 3. Mark internal failures clientThrow: false so the pipeline masks them.
  final internal = TomServerException(
    'storage.connect.unavailable',
    'Database unavailable',
    clientThrow: false,
  );
  print('3. internal clientThrow => ${internal.clientThrow}');
  assert(internal.clientThrow == false);

  // 4. Constructed outside a request zone, requestUuid is unset — and the
  //    rendering drops the request segment rather than trailing a bare null.
  print('4. requestUuid (no zone) => ${basic.requestUuid}');
  print('   rendered         => $basic');
  assert(basic.requestUuid == null);
  assert(basic.toString().endsWith('client-throw: true'));

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
    assert(correlated.requestUuid == requestId.uuid);
    assert(correlated.toString().endsWith(' request: ${requestId.uuid}'));
  }, zoneValues: {TomRequestId: requestId});

  // 6. TomLoginException adds no members, so one clause written for the base
  //    type catches it along with every other server exception. Note it is
  //    client-visible: its constructor does not accept `clientThrow`, while
  //    the rest of the authentication subsystem's exceptions set it false.
  //    `clientThrow` is final, so that holds for every instance rather than
  //    just the one this example builds.
  try {
    throw TomLoginException(
      'error.invalid-user-or-password',
      'The username or password is not correct.',
    );
  } on TomServerException catch (e) {
    print('6. caught as       => ${e.runtimeType}');
    print('   key             => ${e.key}');
    print('   clientThrow     => ${e.clientThrow}');
    assert(e is TomLoginException);
    assert(e.key == 'error.invalid-user-or-password');
    assert(e.clientThrow == true);
  }

  print('\nLittle-things example completed.');
}

void main() {
  run();
}
