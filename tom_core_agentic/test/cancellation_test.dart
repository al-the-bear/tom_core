import 'dart:async';

import 'package:tom_core_agentic/tom_core_agentic.dart';
import 'package:test/test.dart';

void main() {
  group('CancellationTokenSource', () {
    test('token starts uncancelled', () {
      final cts = CancellationTokenSource();
      expect(cts.isCancelled, isFalse);
      expect(cts.token.isCancelled, isFalse);
    });

    test('cancel signals the token and resolves whenCancelled', () async {
      final cts = CancellationTokenSource();
      final done = cts.token.whenCancelled;
      cts.cancel();
      expect(cts.isCancelled, isTrue);
      expect(cts.token.isCancelled, isTrue);
      await done; // resolves, does not throw
    });

    test('cancel is idempotent', () {
      final cts = CancellationTokenSource()..cancel();
      expect(cts.cancel, returnsNormally);
      expect(cts.isCancelled, isTrue);
    });

    test('awaiting an already-cancelled token returns immediately', () async {
      final cts = CancellationTokenSource()..cancel();
      await cts.token.whenCancelled.timeout(const Duration(seconds: 1));
    });
  });

  group('CancellationToken.none', () {
    test('is never cancelled', () {
      expect(CancellationToken.none.isCancelled, isFalse);
    });

    test('whenCancelled never resolves', () {
      var resolved = false;
      unawaited(CancellationToken.none.whenCancelled.then((_) {
        resolved = true;
      }));
      expect(resolved, isFalse);
    });
  });

  group('OperationCancelled', () {
    test('toString reflects the optional operation label', () {
      expect(const OperationCancelled().toString(), 'OperationCancelled');
      expect(
        const OperationCancelled('embedBatch').toString(),
        'OperationCancelled(embedBatch)',
      );
    });
  });
}
