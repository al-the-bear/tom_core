import 'dart:async';

import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// Tests for the little-things module: the [TomServerException] base class.
///
/// Covers the zone-free surface (construction, defaults, the kernel
/// [TomException] inheritance, isolate attribution, the `toString` format) and
/// the zone-based request correlation via a `runZoned` carrying a
/// [TomRequestId].
void main() {
  group('TomServerException', () {
    test('forwards key and message to TomException', () {
      final e = TomServerException('ERR_CODE', 'Something went wrong');
      expect(e.key, 'ERR_CODE');
      expect(e.defaultUserMessage, 'Something went wrong');
    });

    test('is a TomException', () {
      expect(TomServerException('K', 'm'), isA<TomException>());
    });

    test('clientThrow defaults to true', () {
      expect(TomServerException('K', 'm').clientThrow, isTrue);
    });

    test('clientThrow can be set false for internal errors', () {
      expect(
        TomServerException('K', 'm', clientThrow: false).clientThrow,
        isFalse,
      );
    });

    test('captures a non-empty isolate name', () {
      // In the test isolate the debug name is set, so it is never the fallback
      // placeholder — but it is always non-empty either way.
      expect(TomServerException('K', 'm').isolateName, isNotEmpty);
    });

    test('requestUuid is unset when constructed outside a request zone', () {
      expect(TomServerException('K', 'm').requestUuid, isNull);
    });

    test('correlates requestUuid from a TomRequestId in the zone', () {
      final requestId = TomRequestId();
      runZoned(() {
        final e = TomServerException('K', 'm');
        expect(e.requestUuid, requestId.uuid);
      }, zoneValues: {TomRequestId: requestId});
    });

    test('toString includes isolate name and client-throw flag', () {
      final s = TomServerException('K', 'm').toString();
      expect(s, contains('client-throw: true'));
      expect(s, contains(TomServerException('K', 'm').isolateName));
    });
  });
}
