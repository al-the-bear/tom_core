/// Spans: what the kernel records with a tracer installed, and that it
/// records nothing — and changes nothing — without one.
library;

import 'dart:isolate';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A command recording the trace it ran under.
class _Recording extends TomCommand {
  TomTraceContext? trace;
  TomRequestId? id;

  @override
  Future<Object?> execute() async {
    trace = TomTraceContext.current;
    id = TomRequestId.current;
    return null;
  }
}

void main() {
  late TomRecordingTracer tracer;

  setUp(() {
    tracer = TomRecordingTracer();
    TomHttpResilience.reset();
  });
  tearDown(() => TomTracing.install(null));

  group('with no tracer installed', () {
    test('nothing starts, and the work runs as it is', () async {
      expect(TomTracing.isRecording, isFalse);
      expect(TomTracing.start('x'), isNull);
      TomSpan? seen;
      final result = await TomTracing.trace('x', (span) async {
        seen = span;
        return 42;
      });
      expect(result, 42);
      expect(seen, isNull);
      expect(TomTracing.currentSpan, isNull);
    });

    test('a job run still gets a trace and request id of its own', () {
      final trace = TomRequestId.runRoot(
        spanName: 'job x',
        () => TomTraceContext.current,
      );
      expect(trace, isNotNull);
      expect(trace!.parentSpanId, isNull);
    });
  });

  group('with a tracer installed', () {
    setUp(() => TomTracing.install(tracer));

    test('a span is the trace context its work runs in', () async {
      await TomTracing.trace('outer', (outer) async {
        expect(TomTracing.currentSpan, same(outer));
        expect(TomTraceContext.current, outer!.context);
        await TomTracing.trace(
          'inner',
          kind: TomSpanKind.client,
          attributes: {'a': 1},
          (inner) async => inner!.setAttribute('b', 'two'),
        );
      });
      final outer = tracer.named('outer').single;
      final inner = tracer.named('inner').single;
      expect(outer.context.parentSpanId, isNull);
      expect(tracer.childrenOf(outer), [inner]);
      expect(inner.kind, TomSpanKind.client);
      expect(inner.attributes, {'a': 1, 'b': 'two'});
      expect(tracer.open, isEmpty);
    });

    test('a span continues the trace the zone carries', () async {
      final caller = TomTraceContext.parse(
        '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01',
      )!;
      await TomTraceContext.run(
        caller,
        () => TomTracing.trace('handled', (_) async {}),
      );
      final span = tracer.spans.single;
      expect(span.context.traceId, caller.traceId);
      expect(span.context.parentSpanId, caller.spanId);
    });

    test('an error is recorded on the span and passed on', () async {
      await expectLater(
        TomTracing.trace('fails', (_) async => throw StateError('boom')),
        throwsStateError,
      );
      expect(TomTracing.ending(TomTracing.start('sync')!, () => 7), 7);
      expect(
        () => TomTracing.ending(
          TomTracing.start('sync fails')!,
          () => throw ArgumentError('no'),
        ),
        throwsArgumentError,
      );
      expect(tracer.named('fails').single.errors.single, isStateError);
      expect(tracer.named('sync').single.errorDescription, isNull);
      expect(tracer.named('sync fails').single.errors.single, isArgumentError);
    });

    test('a child-only span starts only inside a trace', () async {
      expect(TomTracing.start('poll', childOnly: true), isNull);
      await TomTracing.trace('request', (_) async {
        expect(TomTracing.start('statement', childOnly: true), isNotNull);
      });
    });

    test('untraced work records nothing', () async {
      await TomTracing.untraced(
        () => TomTracing.trace('hidden', (span) async {
          expect(span, isNull);
          expect(TomTracing.isRecording, isFalse);
        }),
      );
      expect(tracer.spans, isEmpty);
    });

    test('a job run is the first span of a trace of its own', () async {
      final body = _Recording();
      final saves = ReceivePort();
      addTearDown(saves.close);
      await TomTraceContext.run(
        TomTraceContext.newRoot(),
        () => TomJobRunCommand(
          inner: body,
          runId: 'run-1',
          jobName: 'nightly',
          checkpoint: null,
          saves: saves.sendPort,
        ).execute(),
      );
      final span = tracer.named('job nightly').single;
      expect(span.context.parentSpanId, isNull);
      expect(span.attributes, {
        'tom.job.name': 'nightly',
        'tom.job.run_id': 'run-1',
      });
      expect(body.trace, span.context);
      expect(body.id!.value, span.context.traceId);
    });

    test('an outgoing call is a client span the callee continues', () async {
      late http.BaseRequest seen;
      final client = TomResilientClient(
        MockClient((request) async {
          seen = request;
          return http.Response('', request.url.path == '/down' ? 503 : 200);
        }),
        const TomHttpResiliencePolicy(retry: TomHttpRetryPolicy.none),
      );
      await TomTracing.trace('request', (_) async {
        await client.get(
          Uri.parse('https://user:secret@api.example.com:8443/tasks?q=1'),
        );
        await client.post(Uri.parse('http://api.example.com/down'));
      });
      final request = tracer.named('request').single;
      final calls = tracer.childrenOf(request);
      expect(calls.map((s) => s.name), ['GET', 'POST']);
      final get = calls.first;
      expect(get.kind, TomSpanKind.client);
      expect(get.attributes, {
        'http.request.method': 'GET',
        'url.full': 'https://api.example.com:8443/tasks',
        'server.address': 'api.example.com',
        'server.port': 8443,
        'http.response.status_code': 200,
      });
      expect(get.errorDescription, isNull);
      expect(calls.last.errorDescription, 'HTTP 503');
      expect(seen.headers['traceparent'], calls.last.context.traceparent);
    });

    test('a call that gets no answer is a failed span', () async {
      final client = TomResilientClient(
        MockClient((_) async => throw http.ClientException('refused')),
        const TomHttpResiliencePolicy(retry: TomHttpRetryPolicy.none),
      );
      await expectLater(
        client.get(Uri.parse('http://nowhere.example/')),
        throwsA(isA<http.ClientException>()),
      );
      expect(tracer.spans.single.errors.single, isA<http.ClientException>());
    });
  });
}
