/// Tests for the little-things module: the three types it contributes.
///
/// [TomRequestId] is the per-request correlation id the rest of the package
/// reads out of the zone. It is produced by the server module's authentication
/// middleware — that seeding is covered in `server_test.dart`, where the
/// middleware lives — and consumed here, which is why it is declared in this
/// module rather than beside its producer.
///
/// [TomServerException] is the base class every other `tom_core_server`
/// exception extends; its zone-free surface (construction, defaults, the kernel
/// [TomException] inheritance, isolate attribution, the `toString` format) and
/// its zone-based request correlation via a `runZoned` carrying a
/// [TomRequestId] are covered first.
///
/// [TomLoginException] is the one subclass declared beside the base rather than
/// beside the module that raises it. It adds no members, so what is pinned here
/// is that it inherits the base surface unchanged and that its constructor does
/// **not** forward `clientThrow` — the property that belongs to the declaration
/// rather than to the login flow. The login flow itself is covered by
/// `authentication_test.dart`.
library;

import 'dart:async';

import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

void main() {
  group('TomRequestId', () {
    test('generates a non-empty v4 uuid', () {
      expect(TomRequestId().uuid, isNotEmpty);
    });

    test('generates distinct ids per instance', () {
      expect(TomRequestId().uuid, isNot(TomRequestId().uuid));
    });

    test('toString carries the uuid', () {
      final id = TomRequestId();
      expect(id.toString(), 'TomRequestId: ${id.uuid}');
    });
  });

  group('TomServerException', () {
    test('forwards key and message to TomException', () {
      final e = TomServerException('test.error.code', 'Something went wrong');
      expect(e.key, 'test.error.code');
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

    test('toString omits the request segment outside a request zone', () {
      // An exception raised outside a request has no correlation to report, so
      // the segment is dropped rather than rendered as `request: null`. The
      // base contributes three nulls of its own; a fourth, trailing and
      // unlabelled, reads as a formatting fault rather than as data.
      final s = TomServerException('K', 'm').toString();
      expect(s, endsWith('client-throw: true'));
      expect(s, isNot(contains('request:')));
    });

    test('toString labels the request uuid inside a request zone', () {
      // The base already carries the id, but only inside the composite leading
      // token `<exception-uuid>-<request-uuid>` — two v4 UUIDs joined by a
      // hyphen, and v4 UUIDs contain hyphens, so that token cannot be split by
      // eye. The labelled trailing segment is what makes the correlation
      // greppable.
      final requestId = TomRequestId();
      runZoned(() {
        final s = TomServerException('K', 'm').toString();
        expect(s, endsWith(' request: ${requestId.uuid}'));
        expect(s, contains('client-throw: true'));
      }, zoneValues: {TomRequestId: requestId});
    });

    test('toString labels the request uuid for a masked exception too', () {
      // The request segment trails `client-throw`, so the two must not collide
      // when the flag is false and the id is present.
      final requestId = TomRequestId();
      runZoned(() {
        final s = TomServerException('K', 'm', clientThrow: false).toString();
        expect(s, endsWith('client-throw: false request: ${requestId.uuid}'));
      }, zoneValues: {TomRequestId: requestId});
    });
  });

  group('TomLoginException', () {
    test('is a TomServerException and a TomException', () {
      final e = TomLoginException('K', 'm');
      expect(e, isA<TomServerException>());
      expect(e, isA<TomException>());
    });

    test('forwards key and message to the base', () {
      final e = TomLoginException(
        'error.invalid-user-or-password',
        'The username or password is not correct.',
      );
      expect(e.key, 'error.invalid-user-or-password');
      expect(e.defaultUserMessage, 'The username or password is not correct.');
    });

    test('forwards parameters to the base', () {
      final e = TomLoginException(
        'K',
        'm',
        parameters: {'username': 'mallory'},
      );
      expect(e.parameters, containsPair('username', 'mallory'));
    });

    test('is born client-visible', () {
      // Deliberate: the constructor does not accept `clientThrow`, so every
      // TomLoginException carries the base default `true`. That is not the
      // package-wide norm being restated — fifteen of the twenty-eight
      // subclasses inherit `true` by omitting the parameter the same way. It
      // is specific to the authentication neighbourhood, where every other
      // exception is hidden from the caller: Tom2FAException and
      // TomServerSelfLoginException hard-wire `clientThrow: false` and
      // TomOAuthException re-defaults it to `false`. TomLoginException is the
      // one failure that subsystem raises whose message is written for the
      // person who mistyped a password, so it is the one that may reach them.
      expect(TomLoginException('K', 'm').clientThrow, isTrue);
    });

    test('can still be masked after construction', () {
      // `clientThrow` is a plain mutable field on the base, so what the
      // omitted constructor parameter fixes is the *default*, not the value: a
      // catch site that decides the detail must not leave the server can set
      // it before rethrowing.
      final e = TomLoginException('K', 'm')..clientThrow = false;
      expect(e.clientThrow, isFalse);
    });

    test('captures a non-empty isolate name like the base', () {
      expect(TomLoginException('K', 'm').isolateName, isNotEmpty);
    });

    test('requestUuid is unset when constructed outside a request zone', () {
      expect(TomLoginException('K', 'm').requestUuid, isNull);
    });

    test('correlates requestUuid from a TomRequestId in the zone', () {
      final requestId = TomRequestId();
      runZoned(() {
        expect(TomLoginException('K', 'm').requestUuid, requestId.uuid);
      }, zoneValues: {TomRequestId: requestId});
    });

    test('is caught by a clause written for the base type', () {
      // The pattern the api summary advertises: one clause reaches every
      // server exception, including the ones declared elsewhere.
      Object? caught;
      try {
        throw TomLoginException('auth.rejected', 'Login rejected.');
      } on TomServerException catch (e) {
        caught = e;
      }
      expect(caught, isA<TomLoginException>());
    });
  });
}
