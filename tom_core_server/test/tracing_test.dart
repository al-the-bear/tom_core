/// Tracing with the OpenTelemetry tracer: the spans the server records for a
/// request, a transaction, an outbox message and an outgoing call, exported
/// through the SDK — and the configuration that switches it on.
///
/// The span tree of a request that queries a live database is
/// `tracing_db_test.dart`'s; the export to an OpenTelemetry Collector is
/// `tracing_otel_test.dart`'s.
library;

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opentelemetry/api.dart' as otel;
import 'package:opentelemetry/sdk.dart' as otel_sdk;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

const _callerTrace = '4bf92f3577b34da6a3ce929d0e0e4736';
const _callerSpan = '00f067aa0ba902b7';

/// A participant that agrees to everything.
class _Participant extends TomTransactionParticipant {
  _Participant(this.id);

  final String id;

  @override
  String getParticipantId() => id;

  @override
  Future<bool> startTransaction(TomTransaction transaction) async => true;

  @override
  Future<bool> prepare(TomTransaction transaction) async => true;

  @override
  Future<bool> commit(TomTransaction transaction) async => true;

  @override
  Future<bool> rollback(TomTransaction transaction) async => true;

  @override
  Future<bool> endTransaction(TomTransaction transaction) async => true;
}

/// A transport recording the messages it was handed, and the trace each was
/// delivered in.
class _RecordingTransport extends TomMessageTransport {
  final List<TomMessage> sent = [];
  final List<TomTraceContext?> traces = [];

  @override
  TomMessageChannel get channel => TomMessageChannel.sms;

  @override
  Future<TomDeliveryReceipt> send(TomMessage message) async {
    sent.add(message);
    traces.add(TomTraceContext.current);
    return TomDeliveryReceipt(
      messageId: message.id,
      outcome: TomDeliveryOutcome.delivered,
      at: DateTime.utc(2026, 10, 27),
    );
  }
}

/// A configuration holding only its field defaults — the base constructor
/// reads no source.
class _Configuration extends TomBaseServerConfiguration {
  _Configuration() : super(const []);

  @override
  void setValues(Map<String, Object?> values) {}
}

/// A client recording whether it was closed.
class _ClosingClient extends http.BaseClient {
  _ClosingClient(this._inner);

  final http.Client _inner;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request);

  @override
  void close() => closed = true;
}

String _id(otel_sdk.ReadOnlySpan span) => span.spanContext.spanId.toString();

Object? _attr(otel_sdk.ReadOnlySpan span, String key) =>
    TomInMemorySpanExporter.attributeOf(span, key);

void main() {
  late TomInMemorySpanExporter exported;

  TomOtelTracer install({int samplePercent = 100}) {
    exported = TomInMemorySpanExporter();
    final tracer = TomOtelTracer(
      processors: [otel_sdk.SimpleSpanProcessor(exported)],
      resource: {'service.name': 'tracing-test'},
      samplePercent: samplePercent,
    );
    TomTracing.install(tracer);
    return tracer;
  }

  setUp(TomHttpResilience.reset);
  tearDown(() => TomTracing.install(null));

  group('configuration', () {
    test('tracing is off unless configured', () {
      final configuration = _Configuration();
      expect(configuration.tracing, isFalse);
      expect(configuration.tracingSamplePercent, 100);
      expect(
        TomOtelTracer.fromConfiguration(configuration, serviceName: 'x'),
        isNull,
      );
    });

    test('tracing without an endpoint is refused', () {
      final configuration = _Configuration()..tracing = true;
      expect(
        () => TomOtelTracer.fromConfiguration(configuration, serviceName: 'x'),
        throwsA(
          isA<TomTracingException>().having(
            (e) => e.key,
            'key',
            'tracing.config.no_endpoint',
          ),
        ),
      );
    });

    test('a sample percentage outside 0 to 100 is refused', () {
      final configuration = _Configuration()
        ..tracing = true
        ..otlpEndpoint = 'http://127.0.0.1:4318'
        ..tracingSamplePercent = 101;
      expect(
        () => TomOtelTracer.fromConfiguration(configuration, serviceName: 'x'),
        throwsA(
          isA<TomTracingException>().having(
            (e) => e.key,
            'key',
            'tracing.config.invalid_sample_percent',
          ),
        ),
      );
    });

    test('a configured tracer exports to the endpoint\'s v1/traces', () async {
      final requests = <http.Request>[];
      final tracer = TomOtelTracer.otlp(
        endpoint: Uri.parse('http://collector:4318'),
        headers: {'authorization': 'Bearer t'},
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('', 200);
        }),
      );
      TomTracing.install(tracer);
      await TomTracing.trace('work', (_) async {});
      await tracer.flush();
      await Future<void>.delayed(Duration.zero);
      expect(requests, hasLength(1));
      expect(requests.single.url.toString(), 'http://collector:4318/v1/traces');
      expect(requests.single.headers['authorization'], 'Bearer t');
      expect(requests.single.headers['content-type'], 'application/x-protobuf');
      await tracer.shutdown();
    });
  });

  group('the tracer', () {
    test('its spans carry the exported ids', () async {
      install();
      late TomTraceContext seen;
      await TomTracing.trace('outer', (outer) async {
        seen = TomTraceContext.current!;
        await TomTracing.trace('inner', (_) async {});
      });
      final outer = exported.named('outer').single;
      final inner = exported.named('inner').single;
      expect(seen.traceId, outer.spanContext.traceId.toString());
      expect(seen.spanId, _id(outer));
      expect(exported.childrenOf(outer), [inner]);
      expect(outer.parentSpanId.isValid, isFalse);
    });

    test('attributes keep their types, errors mark the span', () async {
      install();
      await expectLater(
        TomTracing.trace(
          'fails',
          attributes: {
            's': 'x',
            'i': 1,
            'd': 1.5,
            'b': true,
            'l': ['a'],
          },
          (_) async => throw StateError('boom'),
        ),
        throwsStateError,
      );
      final span = exported.spans.single;
      expect(_attr(span, 's'), 'x');
      expect(_attr(span, 'i'), 1);
      expect(_attr(span, 'd'), 1.5);
      expect(_attr(span, 'b'), true);
      expect(_attr(span, 'l'), ['a']);
      expect(span.status.code, otel.StatusCode.error);
      expect(span.events.single.name, 'exception');
    });

    test('a span continuing a caller follows the caller\'s sampling', () async {
      install(samplePercent: 0);
      for (final flags in ['01', '00']) {
        await TomTraceContext.run(
          TomTraceContext.parse('00-$_callerTrace-$_callerSpan-$flags')!,
          () => TomTracing.trace('handled $flags', (span) async {
            expect(span!.context.sampled, flags == '01');
          }),
        );
      }
      expect(exported.spans.map((s) => s.name), ['handled 01']);
      expect(exported.spans.single.parentSpanId.toString(), _callerSpan);
    });

    test('new traces are sampled at the configured percentage', () async {
      install(samplePercent: 0);
      await TomTracing.trace('dropped', (span) async {
        expect(span!.context.sampled, isFalse);
      });
      expect(exported.spans, isEmpty);

      install(samplePercent: 50);
      for (var i = 0; i < 400; i++) {
        await TomTracing.trace('maybe', (_) async {});
      }
      expect(exported.spans.length, inInclusiveRange(140, 260));
    });

    test(
      'closing the export client lets the export in flight finish',
      () async {
        final answer = Completer<http.Response>();
        final inner = _ClosingClient(MockClient((_) => answer.future));
        final client = TomUntracedClient(inner);
        final export = client.post(Uri.parse('http://collector/v1/traces'));
        client.close();
        expect(inner.closed, isFalse);
        var idle = false;
        unawaited(client.idle.then((_) => idle = true));
        answer.complete(http.Response('ok', 200));
        expect((await export).body, 'ok');
        await Future<void>.delayed(Duration.zero);
        expect(inner.closed, isTrue);
        expect(idle, isTrue);
      },
    );

    test('the exporter\'s own calls are not traced', () async {
      install();
      final client = TomUntracedClient(
        MockClient((_) async => http.Response('', 200)),
      );
      await client.get(Uri.parse('http://collector/v1/traces'));
      expect(exported.spans, isEmpty);
    });
  });

  group('a request', () {
    Handler pipeline(Handler handler) => const Pipeline()
        .addMiddleware(tomRequestLogInfoMiddleware())
        .addMiddleware(tomRequestContextMiddleware())
        .addHandler(handler);

    test(
      'is a server span continuing the caller, named after its route',
      () async {
        install();
        final handler = pipeline((request) {
          (request.context[TomRequestLogInfo.contextName]! as TomRequestLogInfo)
                  .route =
              '/tasks/<id>';
          return Response.ok('');
        });
        final response = await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/tasks/42'),
            headers: {'traceparent': '00-$_callerTrace-$_callerSpan-01'},
          ),
        );
        final span = exported.spans.single;
        expect(span.name, 'GET /tasks/<id>');
        expect(span.kind, otel.SpanKind.server);
        expect(span.spanContext.traceId.toString(), _callerTrace);
        expect(span.parentSpanId.toString(), _callerSpan);
        expect(_attr(span, 'http.route'), '/tasks/<id>');
        expect(_attr(span, 'url.path'), '/tasks/42');
        expect(_attr(span, 'http.response.status_code'), 200);
        expect(
          response.headers['traceparent'],
          '00-$_callerTrace-${_id(span)}-01',
        );
        expect(response.headers['x-request-id'], _callerTrace);
      },
    );

    test('answered with a server error is a failed span', () async {
      install();
      await pipeline((_) => Response.internalServerError())(
        Request('POST', Uri.parse('http://localhost/x')),
      );
      final span = exported.spans.single;
      expect(span.name, 'POST');
      expect(span.parentSpanId.isValid, isFalse);
      expect(span.status.code, otel.StatusCode.error);
    });

    test('without a tracer still carries a trace', () async {
      final response = await pipeline((_) => Response.ok(''))(
        Request('GET', Uri.parse('http://localhost/x')),
      );
      expect(TomTraceContext.parse(response.headers['traceparent']), isNotNull);
    });
  });

  group('a transaction', () {
    test('is a span around its work, ending with its outcome', () async {
      install();
      await TomTracing.trace('request', (_) async {
        await TomTransactionManager.runInTransaction((transaction) async {
          await transaction.registerParticipant(_Participant('db'));
          await TomTracing.trace('statement', (_) async {});
        });
      });
      final request = exported.named('request').single;
      final transaction = exported.named('transaction').single;
      expect(exported.childrenOf(request), [transaction]);
      expect(exported.childrenOf(transaction).map((s) => s.name), [
        'statement',
      ]);
      expect(_attr(transaction, 'tom.transaction.outcome'), 'committed');
      expect(_attr(transaction, 'tom.transaction.participants'), 1);
      expect(_attr(transaction, 'tom.transaction.read_only'), false);
    });

    test('rolled back by a failure records it once', () async {
      install();
      await expectLater(
        TomTracing.trace(
          'request',
          (_) => TomTransactionManager.runInTransaction((_) async {
            throw StateError('no');
          }),
        ),
        throwsStateError,
      );
      final transaction = exported.named('transaction').single;
      expect(_attr(transaction, 'tom.transaction.outcome'), 'rolledBack');
    });
  });

  test('a transaction outside traced work records nothing', () async {
    install();
    final committed = await TomTransactionManager.runInTransaction(
      (transaction) async => transaction.span,
    );
    expect(committed, isNull);
    expect(exported.spans, isEmpty);
  });

  group('an outbox message', () {
    test('carries the trace that queued it to its delivery', () async {
      install();
      final transport = _RecordingTransport();
      final outbox = TomMessageOutbox(router: TomMessageRouter([transport]));
      addTearDown(outbox.close);
      final message = TomMessage(
        id: 'm1',
        channel: TomMessageChannel.sms,
        recipients: [TomRecipient('+41791234567')],
        bodies: [TomMessageBody.text('hello')],
      );

      await TomTracing.trace('request', (_) => outbox.send(message));
      await outbox.tick();

      final request = exported.named('request').single;
      final send = exported.named('outbox send').single;
      final deliver = exported.named('outbox deliver').single;
      expect(exported.childrenOf(request), [send]);
      expect(exported.childrenOf(send), [deliver]);
      expect(send.kind, otel.SpanKind.producer);
      expect(deliver.kind, otel.SpanKind.consumer);
      expect(_attr(deliver, 'messaging.message.id'), 'm1');
      expect(
        transport.sent.single.headers['traceparent'],
        '00-${send.spanContext.traceId}-${_id(send)}-01',
      );
      expect(transport.traces.single!.spanId, _id(deliver));
      // The run is a job span of its own trace.
      expect(exported.named('job $tomOutboxJobName'), hasLength(1));
    });

    test('without a tracer is queued unchanged', () async {
      final transport = _RecordingTransport();
      final outbox = TomMessageOutbox(router: TomMessageRouter([transport]));
      addTearDown(outbox.close);
      await outbox.sendNow(
        TomMessage(
          id: 'm2',
          channel: TomMessageChannel.sms,
          recipients: [TomRecipient('+41791234567')],
          bodies: [TomMessageBody.text('hello')],
        ),
      );
      expect(transport.sent.single.headers, isEmpty);
    });
  });

  group('an outgoing call to a Tom server', () {
    test('is continued by the callee\'s server span', () async {
      install();
      final callee = await shelf_io.serve(
        const Pipeline()
            .addMiddleware(tomRequestLogInfoMiddleware())
            .addMiddleware(tomRequestContextMiddleware())
            .addHandler((_) => Response.ok('pong')),
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() => callee.close(force: true));
      final client = TomResilientClient();
      addTearDown(client.close);

      await TomTracing.trace('caller', (_) async {
        await client.get(Uri.parse('http://127.0.0.1:${callee.port}/ping'));
      });

      final caller = exported.named('caller').single;
      final call = exported.named('GET').where((s) {
        return s.kind == otel.SpanKind.client;
      }).single;
      final served = exported.spans
          .where((s) => s.kind == otel.SpanKind.server)
          .single;
      expect(exported.childrenOf(caller), [call]);
      expect(exported.childrenOf(call), [served]);
      expect(_attr(call, 'http.response.status_code'), 200);
    });
  });
}
