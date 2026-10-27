// ignore_for_file: avoid_print
/// Executable example for the tracing module of `tom_core_server`.
///
/// Shows what a traced server records and sends: a request continuing its
/// caller's trace as a server span named after its route, the transaction and
/// the outgoing call it makes as that span's children, the callee continuing
/// the call's own span, and the whole tree exported over OTLP to a receiver.
///
/// No server is started and no database is needed: the pipeline is the outer
/// edge `TomServer.start` composes, the callee and the OTLP receiver are
/// `HttpServer`s bound in this process, and a transaction participant stands
/// in for a database. `doc/tracing.md` lists every span the framework records
/// and the configuration that switches tracing on in a real server.
///
/// Run with `dart run example/tracing/tracing_example.dart`. Every step checks
/// its own result and the run fails when one does not hold, so a green run is
/// a verification and not just a transcript.
///
/// The behaviour shown here is pinned by `test/tracing_test.dart`.
library;

import 'dart:io';

import 'package:opentelemetry/sdk.dart' as otel_sdk;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';

/// The `traceparent` a traced caller sends.
const _caller = '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01';

/// A transaction participant agreeing to everything — a database's place.
class _Participant extends TomTransactionParticipant {
  @override
  String getParticipantId() => 'db';

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

/// The outer edge of a `TomServer` pipeline, around [handler].
Handler _served(Handler handler) => const Pipeline()
    .addMiddleware(tomRequestLogInfoMiddleware())
    .addMiddleware(tomRequestContextMiddleware())
    .addHandler(handler);

Future<void> run() async {
  final exported = TomInMemorySpanExporter();
  TomTracing.install(
    TomOtelTracer(
      processors: [otel_sdk.SimpleSpanProcessor(exported)],
      resource: {'service.name': 'tracing-example'},
    ),
  );
  final callee = await shelf_io.serve(
    _served((_) => Response.ok('pong')),
    InternetAddress.loopbackIPv4,
    0,
  );
  final client = TomResilientClient();

  // 1. A request from a traced caller: the server span continues the caller's
  //    trace, is named after the route its endpoint matched, and is the
  //    position the response hands back.
  final handler = _served((request) async {
    (request.context[TomRequestLogInfo.contextName]! as TomRequestLogInfo)
            .route =
        '/tasks/<id>';
    await TomTransactionManager.runInTransaction((transaction) async {
      await transaction.registerParticipant(_Participant());
    });
    await client.get(Uri.parse('http://127.0.0.1:${callee.port}/ping'));
    return Response.ok('');
  });
  final response = await handler(
    Request(
      'GET',
      Uri.parse('http://localhost/tasks/42'),
      headers: {'traceparent': _caller},
    ),
  );
  final server = exported.named('GET /tasks/<id>').single;
  print(
    '1. ${server.name}: trace ${server.spanContext.traceId}, '
    'parent ${server.parentSpanId}',
  );
  check(
    server.spanContext.traceId.toString() ==
            '4bf92f3577b34da6a3ce929d0e0e4736' &&
        server.parentSpanId.toString() == '00f067aa0ba902b7' &&
        response.headers['traceparent']!.contains(
          '${server.spanContext.spanId}',
        ),
    'the request continues the caller and answers with its own span',
  );

  // 2. The work the request did is its children: the transaction, with its
  //    outcome, and the outgoing call, with the status it got.
  final children = exported.childrenOf(server);
  final transaction = children.singleWhere((s) => s.name == 'transaction');
  final call = children.singleWhere((s) => s.name == 'GET');
  print(
    '2. children: ${children.map((s) => s.name).join(', ')}; transaction '
    '${TomInMemorySpanExporter.attributeOf(transaction, 'tom.transaction.outcome')}'
    ', call ${TomInMemorySpanExporter.attributeOf(call, 'http.response.status_code')}',
  );
  check(
    children.length == 2 &&
        TomInMemorySpanExporter.attributeOf(
              transaction,
              'tom.transaction.outcome',
            ) ==
            'committed' &&
        TomInMemorySpanExporter.attributeOf(
              call,
              'http.response.status_code',
            ) ==
            200,
    'the transaction and the outgoing call are the request\'s children',
  );

  // 3. The callee read the call's `traceparent`, so its server span is the
  //    call's child — one trace across both processes.
  final served = exported.childrenOf(call).single;
  print('3. the callee: ${served.name}, child of the call');
  check(
    served.spanContext.traceId.toString() ==
        server.spanContext.traceId.toString(),
    'the callee continues the trace of the call that reached it',
  );

  // 4. The same tree over OTLP: a receiver in this process answers what the
  //    tracer's exporter posts to `/v1/traces`.
  final posts = <String>[];
  final receiver = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  receiver.listen((request) async {
    posts.add('${request.uri.path} ${request.headers.contentType}');
    await request.drain<void>();
    request.response.statusCode = 200;
    await request.response.close();
  });
  final otlp = TomOtelTracer.otlp(
    endpoint: Uri.parse('http://127.0.0.1:${receiver.port}'),
  );
  TomTracing.install(otlp);
  await handler(Request('GET', Uri.parse('http://localhost/tasks/7')));
  await otlp.shutdown(); // exports the batch and waits for the answer
  print('4. OTLP: ${posts.join('; ')}');
  check(
    posts.length == 1 && posts.single.startsWith('/v1/traces'),
    'the batched spans are posted once to the receiver\'s /v1/traces',
  );

  // 5. Tracing off: nothing is recorded, and the request still carries a
  //    trace of its own for the logs and the response.
  TomTracing.install(null);
  final before = exported.spans.length;
  final untraced = await _served((_) => Response.ok(''))(
    Request('GET', Uri.parse('http://localhost/tasks/8')),
  );
  print('5. tracing off: ${untraced.headers['traceparent']}');
  check(
    exported.spans.length == before &&
        TomTraceContext.parse(untraced.headers['traceparent']) != null,
    'with no tracer nothing is recorded, and the trace context still flows',
  );

  client.close();
  await callee.close(force: true);
  await receiver.close(force: true);
}

Future<void> main() => run();
