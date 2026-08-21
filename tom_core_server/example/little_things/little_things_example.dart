/// Executable example for the little-things module of `tom_core_server`.
///
/// The module contributes a single type, [TomServerException], the base class
/// for every server-raised exception. This example shows its three
/// distinguishing features: isolate attribution, the `clientThrow` flag, and
/// zone-based request correlation.
///
/// Run with `dart run example/little_things/little_things_example.dart`.
/// The same behaviour is covered by `test/little_things_test.dart`.
library;

import 'dart:async';

import 'package:tom_core_server/tom_core_server.dart';

void run() {
  // 1. A server exception carries the kernel TomException surface (key,
  //    user message) plus the originating isolate name.
  final basic = TomServerException(
    'payment.charge.failed',
    'The payment failed',
  );
  print('1. key            => ${basic.key}');
  print('   isolateName    => ${basic.isolateName}');
  print('   clientThrow    => ${basic.clientThrow}');
  assert(basic.key == 'payment.charge.failed');
  assert(basic.isolateName.isNotEmpty);
  assert(basic.clientThrow == true);

  // 2. Mark internal failures clientThrow: false so the pipeline masks them.
  final internal = TomServerException(
    'storage.connect.unavailable',
    'Database unavailable',
    clientThrow: false,
  );
  print('2. internal clientThrow => ${internal.clientThrow}');
  assert(internal.clientThrow == false);

  // 3. Constructed outside a request zone, requestUuid is unset.
  print('3. requestUuid (no zone) => ${basic.requestUuid}');
  assert(basic.requestUuid == null);

  // 4. Constructed inside a zone carrying a TomRequestId, the exception
  //    correlates itself with the active request automatically.
  final requestId = TomRequestId();
  runZoned(() {
    final correlated = TomServerException(
      'request.validate.bad_input',
      'Bad input',
    );
    print('4. requestUuid (in zone) => ${correlated.requestUuid}');
    assert(correlated.requestUuid == requestId.uuid);
  }, zoneValues: {TomRequestId: requestId});

  print('\nLittle-things example completed.');
}

void main() {
  run();
}
