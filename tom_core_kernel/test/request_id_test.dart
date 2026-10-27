/// The request id of a unit of work: its grammar, the zone it lives in, the
/// `request_id` field it gives log lines, the trace it is drawn from, and the
/// work the kernel starts under one of its own — job runs — plus the trace an
/// outgoing call carries.
library;

import 'dart:convert';
import 'dart:isolate';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

const _traceparent = '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01';

/// A command recording the request id and trace it ran under, and logging.
class _Recording extends TomCommand {
  TomRequestId? id;
  TomTraceContext? trace;

  @override
  Future<Object?> execute() async {
    id = TomRequestId.current;
    trace = TomTraceContext.current;
    tomLog.info('job ran');
    return null;
  }
}

void main() {
  late List<Map<String, Object?>> lines;
  late TomLogOutput previousOutput;
  late TomLogLevel previousLevel;

  setUp(() {
    lines = [];
    previousOutput = tomLog.logOutput;
    previousLevel = tomLog.logLevel;
    tomLog.logOutput = TomJsonLogOutput(
      writer: (line, _) => lines.add(jsonDecode(line) as Map<String, Object?>),
    );
    tomLog.setLogLevel(TomLogLevel.all);
  });
  tearDown(() {
    tomLog.logOutput = previousOutput;
    tomLog.setLogLevel(previousLevel);
  });

  group('TomRequestId', () {
    test('a new id is a version-4 UUID, and every one differs', () {
      final a = TomRequestId();
      expect(
        a.value,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
            r'[0-9a-f]{12}$',
          ),
        ),
      );
      expect(a, isNot(TomRequestId()));
      expect(TomRequestId.isValid(a.value), isTrue);
      expect(a.toString(), 'TomRequestId: ${a.value}');
    });

    test('accepts only a narrow grammar', () {
      for (final good in [
        '4bf92f3577b34da6a3ce929d0e0e4736',
        'req-2026.10.27:0001',
        'A1234567',
        'a' * 128,
      ]) {
        expect(TomRequestId.isValid(good), isTrue, reason: good);
        expect(TomRequestId.of(good).value, good);
      }
      for (final bad in [
        '',
        'short',
        'a' * 129,
        '-leading-dash',
        'has space inside',
        'line\nbreak-inject',
        'quote"injection',
        'ümlautsss',
      ]) {
        expect(TomRequestId.isValid(bad), isFalse, reason: bad);
        expect(TomRequestId.tryOf(bad), isNull, reason: bad);
        expect(() => TomRequestId.of(bad), throwsFormatException);
      }
      expect(TomRequestId.tryOf(null), isNull);
    });

    test('is current inside run, under its own type, and absent outside', () {
      final id = TomRequestId();
      expect(TomRequestId.current, isNull);
      TomRequestId.run(id, () {
        expect(TomRequestId.current, same(id));
        expect(getFromCurrentZone<TomRequestId>(), same(id));
      });
      expect(TomRequestId.current, isNull);
    });

    test('runRoot starts a trace and takes its id', () {
      TomTraceContext.run(TomTraceContext.parse(_traceparent)!, () {
        TomRequestId.runRoot(() {
          final trace = TomTraceContext.current!;
          expect(trace.parentSpanId, isNull, reason: 'a new trace');
          expect(trace.traceId, isNot('4bf92f3577b34da6a3ce929d0e0e4736'));
          expect(TomRequestId.current!.value, trace.traceId);
        });
      });
    });

    test('runChild continues the trace with an id of its own per step', () {
      final parent = TomTraceContext.parse(_traceparent)!;
      final ids = <String>[];
      TomTraceContext.run(parent, () {
        for (var i = 0; i < 2; i++) {
          TomRequestId.runChild(() {
            final trace = TomTraceContext.current!;
            expect(trace.traceId, parent.traceId);
            expect(trace.parentSpanId, parent.spanId);
            ids.add(TomRequestId.current!.value);
            expect(
              TomRequestId.current!.value,
              '${trace.traceId}-${trace.spanId}',
            );
          });
        }
      });
      expect(ids.toSet(), hasLength(2));
      // Without a trace to continue it starts one.
      TomRequestId.runChild(() {
        expect(TomRequestId.current!.value, TomTraceContext.current!.traceId);
      });
    });

    test('every log line written under it carries it as request_id', () {
      tomLog.info('outside');
      TomRequestId.runRoot(() => tomLog.info('inside'));
      expect(lines.first.keys, isNot(contains('request_id')));
      expect(lines.last['request_id'], lines.last['trace_id']);
      expect(lines.last['request_id'], isA<String>());
    });
  });

  group('tracestate', () {
    test('is carried with the trace and onto its children', () {
      final context = TomTraceContext.parse(
        _traceparent,
        traceState: ' congo=t61rcWkgMzE,rojo=00f067aa0ba902b7 ',
      )!;
      expect(context.traceState, 'congo=t61rcWkgMzE,rojo=00f067aa0ba902b7');
      final child = context.child();
      expect(child.traceState, context.traceState);
      expect(child.headers, {
        'traceparent': child.traceparent,
        'tracestate': 'congo=t61rcWkgMzE,rojo=00f067aa0ba902b7',
      });
    });

    test('a malformed one is dropped and the trace kept', () {
      for (final bad in ['x' * 513, 'bad\nline', '   ']) {
        final context = TomTraceContext.parse(_traceparent, traceState: bad)!;
        expect(context.traceState, isNull, reason: bad);
        expect(context.headers.keys, ['traceparent']);
      }
    });
  });

  group('an outgoing framework call', () {
    late List<http.BaseRequest> sent;
    late TomResilientClient client;

    setUp(() {
      sent = [];
      client = TomResilientClient(
        MockClient((request) async {
          sent.add(request);
          return http.Response('', 200);
        }),
        const TomHttpResiliencePolicy(retry: TomHttpRetryPolicy.none),
      );
    });

    test('carries the current trace as a new span', () async {
      final trace = TomTraceContext.parse(
        _traceparent,
        traceState: 'congo=t61rcWkgMzE',
      )!;
      await TomTraceContext.run(
        trace,
        () => client.get(Uri.parse('https://api.example.com/x')),
      );
      final carried = TomTraceContext.parse(
        sent.single.headers['traceparent'],
      )!;
      expect(carried.traceId, trace.traceId);
      expect(carried.spanId, isNot(trace.spanId));
      expect(sent.single.headers['tracestate'], 'congo=t61rcWkgMzE');
      expect(sent.single.headers.keys, isNot(contains('x-request-id')));
    });

    test('adds nothing outside a trace, and keeps a caller\'s own', () async {
      await client.get(Uri.parse('https://api.example.com/x'));
      expect(sent.single.headers.keys, isNot(contains('traceparent')));
      await TomTraceContext.run(
        TomTraceContext.newRoot(),
        () => client.get(
          Uri.parse('https://api.example.com/x'),
          headers: {'traceparent': _traceparent},
        ),
      );
      expect(sent.last.headers['traceparent'], _traceparent);
    });
  });

  group('a job run', () {
    test('runs under a trace and request id of its own, logged', () async {
      final saves = ReceivePort();
      addTearDown(saves.close);
      final first = _Recording();
      final second = _Recording();
      // Started inside a request's trace: the run must not inherit it.
      await TomRequestId.run(
        TomRequestId.of('request-from-a-caller'),
        () =>
            TomTraceContext.run(TomTraceContext.parse(_traceparent)!, () async {
              for (final body in [first, second]) {
                await TomJobRunCommand(
                  inner: body,
                  runId: 'run-1',
                  jobName: 'job',
                  checkpoint: null,
                  saves: saves.sendPort,
                ).execute();
              }
            }),
      );
      for (final body in [first, second]) {
        expect(body.trace!.parentSpanId, isNull);
        expect(body.id!.value, body.trace!.traceId);
        expect(body.id!.value, isNot('request-from-a-caller'));
      }
      expect(first.id, isNot(second.id), reason: 'each attempt its own');
      expect(
        [for (final line in lines) line['request_id']],
        [first.id!.value, second.id!.value],
      );
    });

    test('through the scheduler, each run has its id in its log', () async {
      var now = DateTime.utc(2026, 10, 27, 12);
      final bodies = <_Recording>[];
      final scheduler = TomScheduler(
        store: TomMemoryJobStore(),
        dispatcher: const TomInlineJobDispatcher(),
        clock: () => now,
        onAlert: (_) {},
      );
      addTearDown(scheduler.close);
      scheduler.register(
        TomJobDefinition(
          name: 'job',
          schedule: TomIntervalSchedule(const Duration(minutes: 1)),
          body: (_) {
            final body = _Recording();
            bodies.add(body);
            return body;
          },
        ),
      );
      for (var i = 0; i < 3; i++) {
        await scheduler.tick();
        await scheduler.drain();
        now = now.add(const Duration(minutes: 1, seconds: 1));
      }
      expect(bodies, isNotEmpty);
      final logged = [
        for (final line in lines)
          if (line['message'] == 'job ran') line['request_id'],
      ];
      expect(logged, [for (final body in bodies) body.id!.value]);
      expect(logged.toSet(), hasLength(logged.length));
    });
  });
}
