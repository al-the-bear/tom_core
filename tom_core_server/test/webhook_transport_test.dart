/// The third implementation of [TomMessageTransport], and the second piece of
/// evidence that the contract is an abstraction rather than a description of
/// email.
///
/// Everything here asserts one of three things:
///
/// - **the request** — that what arrives at the endpoint is the message's own
///   JSON, with the headers the message and the deployment between them named,
///   and that the deployment's win;
/// - **classification** — the single judgement a transport is allowed to make,
///   here a single layer because a webhook endpoint answers for itself;
/// - **the refusals** — the two shapes a webhook message can have that no
///   endpoint could accept, both permanent by construction.
///
/// Connection-free: every response is scripted through a fake `BaseClient`, so
/// no socket is opened and every branch is reachable.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart'
    show BaseClient, BaseRequest, Request, StreamedResponse;
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

// =============================================================================
// FIXTURES
// =============================================================================

/// A [BaseClient] whose every response is scripted.
class _FakeEndpoint extends BaseClient {
  _FakeEndpoint(this.handler);

  /// Answers one request. Throwing from here is how a network failure is
  /// spelled.
  final Future<StreamedResponse> Function(BaseRequest request) handler;

  /// Every request the transport made, in order.
  final List<BaseRequest> requests = [];

  /// The bodies of those requests, in the same order.
  final List<String> bodies = [];

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    requests.add(request);
    bodies.add(request is Request ? request.body : '');
    return handler(request);
  }
}

class _FakeEndpointFactory implements TomHttpClientAbstractFactory {
  _FakeEndpointFactory(this._client);

  final _FakeEndpoint _client;

  @override
  _FakeEndpoint getClient() => _client;
}

/// A clock that only moves when a test moves it.
class _FakeClock {
  DateTime now;

  _FakeClock(this.now);

  DateTime call() => now;

  void advance(Duration by) => now = now.add(by);
}

StreamedResponse _answer(String body, {int status = 200}) {
  final bytes = utf8.encode(body);
  return StreamedResponse(
    Stream<List<int>>.value(bytes),
    status,
    contentLength: bytes.length,
  );
}

TomMessage _hook({
  String id = 'w1',
  List<String> to = const ['https://hooks.example.com/orders'],
  Map<String, String>? headers,
  String text = '{"order":42}',
}) => TomMessage(
  id: id,
  channel: TomMessageChannel.webhook,
  recipients: to.map(TomRecipient.new).toList(),
  bodies: [TomMessageBody.text(text)],
  headers: headers,
);

({TomWebhookTransport transport, _FakeEndpoint endpoint}) _transport(
  Future<StreamedResponse> Function(BaseRequest request) handler, {
  TomWebhookSettings? settings,
}) {
  final endpoint = _FakeEndpoint(handler);
  return (
    transport: TomWebhookTransport(
      settings: settings,
      openChannel: (uri) => TomServerChannel(
        uri.host,
        uri.hasPort ? uri.port : 443,
        clientFactory: _FakeEndpointFactory(endpoint),
      ),
    ),
    endpoint: endpoint,
  );
}

void main() {
  group('the request', () {
    test('posts the message JSON to the address', () async {
      final t = _transport((_) async => _answer('{"ok":true}'));
      final receipt = await t.transport.send(_hook());

      expect(receipt.isDelivered, isTrue);
      expect(t.endpoint.requests.single.method, 'POST');
      expect(
        t.endpoint.requests.single.url.toString(),
        'https://hooks.example.com/orders',
      );

      // The body is the message's own representation, which is the one the
      // outbox already round-trips — so what an endpoint receives and what a
      // queued message *is* cannot drift apart.
      final sent = jsonDecode(t.endpoint.bodies.single) as Map<String, Object?>;
      expect(sent['id'], 'w1');
      expect(sent['channel'], 'webhook');
      expect((sent['bodies'] as List), hasLength(1));
    });

    test('declares JSON', () async {
      final t = _transport((_) async => _answer(''));
      await t.transport.send(_hook());
      expect(
        t.endpoint.requests.single.headers['content-type'],
        contains('application/json'),
      );
    });

    test("carries the message's headers", () async {
      // TomMessage.headers has said "email headers, webhook HTTP headers"
      // since it was written; this is the half that was never true.
      final t = _transport((_) async => _answer(''));
      await t.transport.send(_hook(headers: {'X-Tenant': 'acme'}));
      expect(t.endpoint.requests.single.headers['x-tenant'], 'acme');
    });

    test('the deployment\'s headers win over the message\'s', () async {
      // The settings carry the credential. A message is composed by
      // application code, and letting it overwrite one would let it strip the
      // authentication off a call — not a decision a message gets to make.
      final t = _transport(
        (_) async => _answer(''),
        settings: TomWebhookSettings(headers: {'X-Api-Key': 'deployment'}),
      );
      await t.transport.send(_hook(headers: {'X-Api-Key': 'message'}));
      expect(t.endpoint.requests.single.headers['x-api-key'], 'deployment');
    });

    test('presents no bearer token of its own', () async {
      // The kernel call layer injects the caller's bearer by default. A
      // subscribed endpoint has no idea what that is, and presenting it would
      // hand a user credential to a third party.
      final t = _transport((_) async => _answer(''));
      await t.transport.send(_hook());
      expect(
        t.endpoint.requests.single.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('authorization')),
      );
    });
  });

  group('classification', () {
    test('2xx is delivered, with the answer kept for diagnosis', () async {
      final t = _transport((_) async => _answer('accepted', status: 202));
      final receipt = await t.transport.send(_hook());
      expect(receipt.isDelivered, isTrue);
      expect(receipt.detail, 'accepted');
    });

    for (final status in [408, 425, 429, 500, 503]) {
      test('$status is transient', () async {
        final t = _transport((_) async => _answer('later', status: status));
        await expectLater(
          t.transport.send(_hook()),
          throwsA(
            isA<TomDeliveryException>()
                .having((e) => e.isPermanent, 'isPermanent', isFalse)
                .having((e) => e.statusCode, 'statusCode', status),
          ),
        );
      });
    }

    for (final status in [400, 401, 403, 404, 422]) {
      test('$status is permanent', () async {
        // A retry sends the same wrong request, so the budget is spent saying
        // the same thing again while the caller waits for a report it could
        // have acted on now.
        final t = _transport((_) async => _answer('no', status: status));
        await expectLater(
          t.transport.send(_hook()),
          throwsA(
            isA<TomDeliveryException>()
                .having((e) => e.isPermanent, 'isPermanent', isTrue)
                .having((e) => e.statusCode, 'statusCode', status),
          ),
        );
      });
    }

    test('an unreachable endpoint is transient', () async {
      final t = _transport((_) async => throw const SocketishError());
      await expectLater(
        t.transport.send(_hook()),
        throwsA(
          isA<TomDeliveryException>()
              .having((e) => e.isPermanent, 'isPermanent', isFalse)
              .having((e) => e.key, 'key', 'messaging.webhook.unreachable'),
        ),
      );
    });

    test('an endpoint that never answers is transient', () async {
      // The deadline is the transport's, not the outbox's: a hung endpoint
      // would otherwise hold the delivery open for as long as it liked.
      final t = _transport(
        (_) => Completer<StreamedResponse>().future,
        settings: TomWebhookSettings(timeout: const Duration(milliseconds: 50)),
      );
      await expectLater(
        t.transport.send(_hook()),
        throwsA(
          isA<TomDeliveryException>()
              .having((e) => e.isPermanent, 'isPermanent', isFalse)
              .having((e) => e.key, 'key', 'messaging.webhook.unreachable'),
        ),
      );
    });

    test('a long answer is truncated before it reaches the receipt', () async {
      // The body is a stranger's and the receipt is logged.
      final t = _transport(
        (_) async => _answer('x' * 5000),
        settings: TomWebhookSettings(maxDetailChars: 16),
      );
      final receipt = await t.transport.send(_hook());
      expect(receipt.detail, 'xxxxxxxxxxxxxxxx…');
    });

    test('an empty answer leaves no detail rather than an empty one', () async {
      final t = _transport((_) async => _answer(''));
      expect((await t.transport.send(_hook())).detail, isNull);
    });
  });

  group('the refusals', () {
    test('a second endpoint is refused, permanently', () async {
      // The outbox retries a *message*, not a recipient, so a POST that
      // succeeded at one endpoint and failed at another would be re-sent to
      // both — and a webhook is not idempotent. Fan-out is two messages.
      final t = _transport((_) async => _answer(''));
      await expectLater(
        t.transport.send(
          _hook(
            to: const [
              'https://hooks.example.com/a',
              'https://hooks.example.com/b',
            ],
          ),
        ),
        throwsA(
          isA<TomDeliveryException>()
              .having((e) => e.isPermanent, 'isPermanent', isTrue)
              .having(
                (e) => e.key,
                'key',
                'messaging.webhook.not_one_endpoint',
              ),
        ),
      );
      expect(
        t.endpoint.requests,
        isEmpty,
        reason: 'nothing may be delivered before the refusal',
      );
    });

    for (final address in [
      'mailto:ops@example.com',
      'not a url',
      'ftp://x/y',
    ]) {
      test('"$address" is not an endpoint', () async {
        final t = _transport((_) async => _answer(''));
        await expectLater(
          t.transport.send(_hook(to: [address])),
          throwsA(
            isA<TomDeliveryException>()
                .having((e) => e.isPermanent, 'isPermanent', isTrue)
                .having((e) => e.key, 'key', 'messaging.webhook.bad_endpoint'),
          ),
        );
      });
    }

    test('a message for another channel is refused by the base', () async {
      // checkSupported, inherited: the rule is the contract's, not this
      // transport's, and asserting it here is what says the transport calls it.
      final t = _transport((_) async => _answer(''));
      await expectLater(
        t.transport.send(
          TomMessage(
            channel: TomMessageChannel.email,
            recipients: [TomRecipient('https://hooks.example.com/orders')],
          ),
        ),
        throwsA(
          isA<TomDeliveryException>().having(
            (e) => e.key,
            'key',
            'messaging.transport.wrong_channel',
          ),
        ),
      );
    });

    test('an attachment is refused: HTTP JSON cannot carry one', () async {
      final t = _transport((_) async => _answer(''));
      await expectLater(
        t.transport.send(
          TomMessage(
            channel: TomMessageChannel.webhook,
            recipients: [TomRecipient('https://hooks.example.com/orders')],
            attachments: [
              TomAttachment.text(fileName: 'note.txt', text: 'hello'),
            ],
          ),
        ),
        throwsA(
          isA<TomDeliveryException>().having(
            (e) => e.key,
            'key',
            'messaging.transport.no_attachments',
          ),
        ),
      );
    });

    test('a negative detail cap is refused at construction', () {
      expect(
        () => TomWebhookSettings(maxDetailChars: -1),
        throwsA(isA<TomMessagingException>()),
      );
    });
  });

  group('a webhook on the outbox', () {
    // The seam: a queued webhook rides the same outbox, the same retry budget
    // and the same permanence marker an email or an SMS does. The transport
    // makes one judgement and the outbox acts on it — a transport with its own
    // retry loop would make the configured policy a lie.

    late _FakeClock clock;

    TomMessageOutbox outboxOver(TomMessageTransport transport) {
      clock = _FakeClock(DateTime.utc(2026, 9, 15, 10));
      return TomMessageOutbox(
        router: TomMessageRouter([transport]),
        clock: clock.call,
        retryPolicy: const TomRetryPolicy(
          maxAttempts: 3,
          initialBackoff: Duration(minutes: 1),
          jitter: 0,
        ),
      );
    }

    test('a 503 is retried and then succeeds', () async {
      var call = 0;
      final t = _transport((_) async {
        call++;
        return call == 1 ? _answer('busy', status: 503) : _answer('ok');
      });
      final outbox = outboxOver(t.transport);
      addTearDown(outbox.close);

      await outbox.sendNow(_hook());
      expect(call, 1);

      clock.advance(const Duration(minutes: 2));
      await outbox.tick();

      final run = (await outbox.store.all()).single;
      expect(run.state, TomJobRunState.succeeded);
      expect(run.attempt, 2);
    });

    test('a 404 burns no retry', () async {
      var call = 0;
      final t = _transport((_) async {
        call++;
        return _answer('gone', status: 404);
      });
      final outbox = outboxOver(t.transport);
      addTearDown(outbox.close);

      await outbox.sendNow(_hook());

      final run = (await outbox.store.all()).single;
      expect(run.state, TomJobRunState.failed);
      expect(run.attempt, 1);
      expect(call, 1);
    });

    test('a webhook and an email share one router and one queue', () async {
      // Three channels now, one delivery mechanism.
      final t = _transport((_) async => _answer('ok'));
      final mail = TomMemoryMessageTransport();
      clock = _FakeClock(DateTime.utc(2026, 9, 15, 10));
      final shared = TomMessageOutbox(
        router: TomMessageRouter([mail, t.transport]),
        clock: clock.call,
      );
      addTearDown(shared.close);

      await shared.sendNow(_hook());
      await shared.sendNow(
        TomMessage.email(
          to: [TomRecipient('ops@example.com')],
          subject: 'hello',
          text: 'hello',
        ),
      );

      expect(t.endpoint.requests, hasLength(1));
      expect(mail.sent, hasLength(1));
      expect(
        (await shared.store.all()).every(
          (r) => r.state == TomJobRunState.succeeded,
        ),
        isTrue,
      );
    });
  });

  group('it is an ordinary transport', () {
    test('it registers and routes like the others', () {
      final router = TomMessageRouter([TomWebhookTransport()]);
      expect(router.supports(TomMessageChannel.webhook), isTrue);
      expect(
        router.transportFor(
          TomMessage(
            channel: TomMessageChannel.webhook,
            recipients: [TomRecipient('https://hooks.example.com/orders')],
          ),
        ),
        isA<TomWebhookTransport>(),
      );
    });

    test('it declares the two capabilities it does not have', () {
      final transport = TomWebhookTransport();
      expect(transport.supportsCopies, isFalse);
      expect(transport.supportsAttachments, isFalse);
      expect(transport.channel, TomMessageChannel.webhook);
    });
  });
}

/// A stand-in for the socket errors a real client raises.
class SocketishError implements Exception {
  const SocketishError();
}
