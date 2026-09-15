/// Tests for the little-things module: the three types it contributes and the
/// one function.
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
///
/// [tomErrorEnvelope] is the package's single definition of the wire error
/// shape, and it lives here because [TomServerException] decides its one
/// conditional field. What is pinned here is the *shape* — which keys each kind
/// of error contributes, and that a key is absent rather than null when the
/// error does not carry it. How each error handler uses the envelope is covered
/// where those handlers live, in `server_test.dart` and
/// `preferences_endpoints_test.dart`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

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

  group('isolate attribution names the origin, not the reader', () {
    // The field exists so a failure can be attributed to one of several
    // identical workers — the server spreads work across an isolate pool, and
    // the message alone is ambiguous. That only works if the name travels with
    // the exception, which is the property these three pin. Resolving the name
    // lazily instead would report whichever isolate happened to read it, which
    // is the one isolate that is never the answer.

    test('an exception raised in a worker names the worker', () async {
      final reader = Isolate.current.debugName;
      Object? caught;
      try {
        await Isolate.run(
          () => throw TomServerException('probe.run', 'raised in a worker'),
          debugName: 'attribution-worker',
        );
      } catch (error) {
        caught = error;
      }

      expect(caught, isA<TomServerException>());
      expect((caught as TomServerException).isolateName, 'attribution-worker');
      expect(
        caught.isolateName,
        isNot(reader),
        reason: 'the name must not follow the isolate that caught it',
      );
    });

    test('and it survives being sent over a port', () async {
      // The half that had been assumed lost. An exception handed across a
      // SendPort is not the same object on the other side, so the question is
      // whether the field arrives at all — and within one isolate group, which
      // is what Isolate.spawn, Isolate.run and the server's isolate pooling
      // create, it does.
      final port = ReceivePort();
      await Isolate.spawn<SendPort>(
        (SendPort reply) =>
            reply.send(TomServerException('probe.port', 'raised in a worker')),
        port.sendPort,
        debugName: 'port-worker',
      );
      final received = await port.first;
      port.close();

      expect(received, isA<TomServerException>());
      expect((received as TomServerException).isolateName, 'port-worker');
    });

    test('an exception built here names this isolate', () {
      // The control. Without it the two above are satisfied by a field that is
      // simply always a string somebody else set.
      expect(
        TomServerException('K', 'm').isolateName,
        Isolate.current.debugName,
      );
    });
  });

  group('clientMessage', () {
    test('a client-visible exception hands over its own message', () {
      expect(
        TomServerException(
          'order.not-found',
          'No such order.',
        ).clientMessage('Request refused.'),
        'No such order.',
      );
    });

    test('a masked exception hands over the fallback instead', () {
      // The leak this closes. Five types in the package default the flag to
      // false because their messages describe server internals — an
      // unreachable data source, a failed audit write, a misconfigured
      // identity provider — and a handler reading `defaultUserMessage`
      // directly shows them.
      expect(
        TomServerException(
          'audit.sink.unavailable',
          'The audit datasource "audit_db" is not registered.',
          clientThrow: false,
        ).clientMessage('Request refused.'),
        'Request refused.',
      );
    });

    test('the exception still carries the masked message for a log', () {
      // Masking is a decision about the *response*, not an erasure: the server
      // still has to be able to say in its own log what actually failed.
      final e = TomServerException(
        'audit.sink.unavailable',
        'The audit datasource "audit_db" is not registered.',
        clientThrow: false,
      );
      expect(e.defaultUserMessage, contains('audit_db'));
      expect(e.toString(), contains('audit_db'));
    });

    test('the key is never masked, only the message', () {
      // The key is a stable code a client resolves against its own resources,
      // not free text an author wrote for a person — so it stays on the wire
      // for every exception, which is what leaves a masked response something
      // to render.
      final e = TomServerException(
        'audit.sink.unavailable',
        'internals',
        clientThrow: false,
      );
      expect(tomErrorEnvelope(e)['errorKey'], 'audit.sink.unavailable');
      expect(tomErrorEnvelope(e)['clientThrow'], isFalse);
    });

    test('a login failure is client-visible, so it keeps its message', () {
      expect(
        TomLoginException(
          'error.invalid-user-or-password',
          'The username or password is not correct.',
          reason: TomLoginFailure.accountProblem,
        ).clientMessage('Request refused.'),
        'The username or password is not correct.',
      );
    });
  });

  group('TomLoginException', () {
    test('is a TomServerException and a TomException', () {
      final e = TomLoginException(
        'K',
        'm',
        reason: TomLoginFailure.accountProblem,
      );
      expect(e, isA<TomServerException>());
      expect(e, isA<TomException>());
    });

    test('forwards key and message to the base', () {
      final e = TomLoginException(
        'error.invalid-user-or-password',
        'The username or password is not correct.',
        reason: TomLoginFailure.accountProblem,
      );
      expect(e.key, 'error.invalid-user-or-password');
      expect(e.defaultUserMessage, 'The username or password is not correct.');
    });

    test('forwards parameters to the base', () {
      final e = TomLoginException(
        'K',
        'm',
        reason: TomLoginFailure.accountProblem,
        parameters: {'username': 'mallory'},
      );
      expect(e.parameters, containsPair('username', 'mallory'));
    });

    test('is client-visible', () {
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
      //
      // Because `clientThrow` is final, this is an invariant of the type and
      // not merely the value it is born with: no instance of
      // TomLoginException is ever hidden from the caller.
      expect(
        TomLoginException(
          'K',
          'm',
          reason: TomLoginFailure.accountProblem,
        ).clientThrow,
        isTrue,
      );
    });

    test('captures a non-empty isolate name like the base', () {
      expect(
        TomLoginException(
          'K',
          'm',
          reason: TomLoginFailure.accountProblem,
        ).isolateName,
        isNotEmpty,
      );
    });

    test('requestUuid is unset when constructed outside a request zone', () {
      expect(
        TomLoginException(
          'K',
          'm',
          reason: TomLoginFailure.accountProblem,
        ).requestUuid,
        isNull,
      );
    });

    test('correlates requestUuid from a TomRequestId in the zone', () {
      final requestId = TomRequestId();
      runZoned(() {
        expect(
          TomLoginException(
            'K',
            'm',
            reason: TomLoginFailure.accountProblem,
          ).requestUuid,
          requestId.uuid,
        );
      }, zoneValues: {TomRequestId: requestId});
    });

    test('carries a closed-set reason beside the free-form key', () {
      // The defect this closes. Everything a caller might branch on — is this
      // the wrong code, are the attempts spent, is the provider down — used to
      // be encoded only in the key string, so a client that wanted to act on
      // it had to match strings that no type or constant enumerated.
      final e = TomLoginException(
        'login.error.2fa.enrolment-code-invalid',
        'That code does not match',
        reason: TomLoginFailure.secondFactorInvalid,
      );
      expect(e.reason, TomLoginFailure.secondFactorInvalid);
      expect(
        e.key,
        'login.error.2fa.enrolment-code-invalid',
        reason: 'the reason does not replace the key; the key stays specific',
      );
    });

    test('the reason is five values, and there is no bad-password value', () {
      // Pinned by name, because the omissions are the design. Splitting
      // "unknown user" from "wrong password" — or naming "locked" at all —
      // hands any caller a user-enumeration oracle, so all three are
      // accountProblem. The server keeps the distinction in the key.
      expect(TomLoginFailure.values, [
        TomLoginFailure.accountProblem,
        TomLoginFailure.secondFactorRequired,
        TomLoginFailure.secondFactorInvalid,
        TomLoginFailure.rateLimited,
        TomLoginFailure.providerError,
      ]);
    });

    test('toString carries the reason beside the key', () {
      expect(
        TomLoginException(
          'K',
          'm',
          reason: TomLoginFailure.providerError,
        ).toString(),
        endsWith('login-failure: providerError'),
      );
    });

    test('is caught by a clause written for the base type', () {
      // The pattern the api summary advertises: one clause reaches every
      // server exception, including the ones declared elsewhere.
      Object? caught;
      try {
        throw TomLoginException(
          'auth.rejected',
          'Login rejected.',
          reason: TomLoginFailure.accountProblem,
        );
      } on TomServerException catch (e) {
        caught = e;
      }
      expect(caught, isA<TomLoginException>());
    });
  });

  group('tomErrorEnvelope', () {
    test('a non-Tom error contributes only its runtime type', () {
      // Every failure has a runtime type, so `errorType` is the one field that
      // is never conditional: a client that recognises nothing else about the
      // body can still log something specific.
      final envelope = tomErrorEnvelope(StateError('boom'));
      expect(envelope.keys, ['errorType']);
      expect(envelope['errorType'], 'StateError');
    });

    test('a kernel exception contributes the fields a client branches on', () {
      final error = TomException('some.key', 'Some message');
      final envelope = tomErrorEnvelope(error);

      expect(envelope['errorType'], 'TomException');
      expect(envelope['errorKey'], 'some.key');
      expect(envelope['uuid'], error.uuid);
      expect(envelope['autoLog'], error.autoLog);
      expect(envelope['requestUuid'], error.requestUuid);
    });

    test('a kernel exception carries no clientThrow to report', () {
      // The flag is a `tom_core_server` concept, so an error raised in the
      // kernel does not have one — and the envelope leaves the key out rather
      // than inventing a default. That absence is the signal: a body with no
      // `clientThrow` came from outside this package.
      expect(
        tomErrorEnvelope(
          TomException('some.key', 'm'),
        ).containsKey('clientThrow'),
        isFalse,
      );
    });

    test('a server exception adds the masking flag', () {
      expect(
        tomErrorEnvelope(
          TomServerException('some.key', 'm', clientThrow: false),
        )['clientThrow'],
        isFalse,
      );
      expect(
        tomErrorEnvelope(TomServerException('some.key', 'm'))['clientThrow'],
        isTrue,
      );
    });

    test('the server arm builds on the kernel arm rather than replacing it', () {
      // The two conditionals are additive, not alternatives — a
      // TomServerException is a TomException, so it must report both sets. The
      // hand-built copy this function replaced got exactly this wrong.
      final envelope = tomErrorEnvelope(TomServerException('some.key', 'm'));
      expect(envelope.keys, [
        'errorType',
        'errorKey',
        'uuid',
        'autoLog',
        'requestUuid',
        'clientThrow',
      ]);
    });

    test('a login failure adds the closed-set reason', () {
      // The field that makes a login failure actionable without string
      // matching: a client shows "try the code again" for secondFactorInvalid
      // and "start the login over" for rateLimited by switching on a closed
      // set, where before it had to recognise `key` values no type enumerated.
      expect(
        tomErrorEnvelope(
          TomLoginException(
            'login.error.2fa.attempts-exhausted',
            'm',
            reason: TomLoginFailure.rateLimited,
          ),
        )['loginFailure'],
        'rateLimited',
      );
    });

    test('anything that is not a login failure omits the reason', () {
      // Absent rather than null, like every other conditional field: the
      // presence of `loginFailure` is itself the statement that this failure
      // was a login.
      expect(
        tomErrorEnvelope(
          TomServerException('some.key', 'm'),
        ).containsKey('loginFailure'),
        isFalse,
      );
    });

    test('every value in the envelope is JSON-encodable', () {
      // The envelope exists to be a response body, so a field that cannot be
      // encoded is not a rendering detail — it is a 500 raised while reporting
      // a 500, with the original error lost.
      final envelope = tomErrorEnvelope(
        TomServerException('some.key', 'm', parameters: {'k': 'v'}),
      );
      expect(
        jsonDecode(jsonEncode(envelope)),
        envelope,
        reason: 'the envelope must survive a round trip through the wire',
      );
    });

    test('reports the concrete subtype, not the base it was caught as', () {
      // `errorType` is read off the instance, so a client sees which failure
      // this actually was even when every catch site in the package is written
      // for TomServerException.
      expect(
        tomErrorEnvelope(
          TomLoginException(
            'auth.rejected',
            'm',
            reason: TomLoginFailure.accountProblem,
          ),
        )['errorType'],
        'TomLoginException',
      );
    });
  });
}
