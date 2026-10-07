/// Pins the error key of the worker-pool supervision refusals that no other
/// test names.
///
/// `TomWorkerPool.withSize` refuses a supervision setting that would produce a
/// pool unable to do useful work, and it does so under a key per argument so
/// the caller can tell which configuration value was wrong. A test that only
/// checks the exception type passes just as well when the key is misspelled
/// or raised from the wrong branch, so a key no test names is a failure mode
/// nobody checks.
///
/// Each refusal is raised before any worker is spawned, so these cases start
/// no isolate. The other supervision refusals are pinned in
/// `isolate_pooling_test.dart`.
library;

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// The minimal context a pool needs; it is never handed to a worker here.
class _UnusedContext extends TomWorkerContext {
  _UnusedContext()
    : super(
        const TomEnvironment('test', isTest: true),
        platformLinux,
        [],
        'ErrorKeys',
      );
}

void main() {
  group('TomWorkerPool.withSize supervision', () {
    final cases = <String, Future<TomWorkerPool> Function()>{
      'isolate.invalid_health_check_interval.with_size': () =>
          TomWorkerPool.withSize(
            1,
            _UnusedContext(),
            healthCheckInterval: Duration.zero,
          ),
      'isolate.invalid_health_check_timeout.with_size': () =>
          TomWorkerPool.withSize(
            1,
            _UnusedContext(),
            healthCheckInterval: const Duration(seconds: 1),
            healthCheckTimeout: Duration.zero,
          ),
    };
    cases.forEach((key, create) {
      test('refused under $key', () async {
        await expectLater(
          create(),
          throwsA(isA<TomWorkerException>().having((e) => e.key, 'key', key)),
        );
      });
    });
  });
}
