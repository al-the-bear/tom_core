/// Graceful shutdown: what a server does between SIGTERM and exiting.
///
/// The first group sends a real SIGTERM to a server process
/// (`fixtures/graceful_shutdown_server.dart`) during a slow request, and
/// checks the three promises: the request completes, no new request is
/// accepted, and the scheduler's lease is released. The second drives the
/// same shutdown in-process, where each step can be observed on its own.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';

/// The `dart` launcher of the running SDK: the test runner itself may be the
/// bare VM, which has no `run` command.
String _dart() {
  final bin = File(Platform.resolvedExecutable).parent.path;
  final launcher = File('$bin${Platform.pathSeparator}dart');
  return launcher.existsSync() ? launcher.path : 'dart';
}

/// Whether [port] still accepts a request: its status, or `null` when the
/// connection is refused.
Future<int?> _statusOf(int port, String path) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
  try {
    final request = await client.get('127.0.0.1', port, path);
    final response = await request.close();
    await response.drain<void>();
    return response.statusCode;
  } on SocketException {
    return null;
  } on HttpException {
    return null;
  } finally {
    client.close(force: true);
  }
}

class _Long extends TomCommand {
  _Long(this.started, this.release);
  final Completer<void> started;
  final Future<void> release;

  @override
  Future<Object?> execute() async {
    started.complete();
    await release;
    return 'done';
  }
}

void main() {
  group('SIGTERM to a server process', () {
    test(
      'the slow request completes, no new request is accepted, the lease is released',
      () async {
        final leases = Directory.systemTemp.createTempSync('tom_shutdown_');
        addTearDown(() => leases.deleteSync(recursive: true));
        final process = await Process.start(_dart(), [
          'run',
          'test/fixtures/graceful_shutdown_server.dart',
          leases.path,
        ]);
        addTearDown(() => process.kill(ProcessSignal.sigkill));
        final lines = StreamController<String>.broadcast();
        final output = <String>[];
        process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
              output.add(line);
              lines.add(line);
            });
        process.stderr
            .transform(utf8.decoder)
            .listen((text) => output.add('stderr: $text'));

        final port = int.parse(
          (await lines.stream
                  .firstWhere((l) => l.startsWith('listening '))
                  .timeout(const Duration(minutes: 2)))
              .split(' ')
              .last,
        );
        await lines.stream
            .firstWhere((l) => l == 'job started')
            .timeout(const Duration(seconds: 30));

        final lock = TomFileLeaseLock(leases.path);
        expect((await lock.inspect('job:long')).isHeld, isTrue);

        final client = HttpClient();
        addTearDown(() => client.close(force: true));
        final slow = client
            .get('127.0.0.1', port, '/slow')
            .then((request) => request.close())
            .then(
              (response) async =>
                  (response.statusCode, await utf8.decodeStream(response)),
            );
        await Future<void>.delayed(const Duration(milliseconds: 500));

        expect(process.kill(ProcessSignal.sigterm), isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 500));

        final late = await _statusOf(port, '/slow');
        expect(late, anyOf(isNull, 503), reason: 'a new request was accepted');

        final (status, body) = await slow;
        expect(status, 200, reason: output.join('\n'));
        expect(body, 'slow done');

        final exitCode = await process.exitCode.timeout(
          const Duration(seconds: 30),
        );
        expect(exitCode, 0, reason: output.join('\n'));
        // The job was still running at the deadline: its lease was handed
        // back on close rather than left to its ten-minute TTL.
        expect((await lock.inspect('job:long')).isHeld, isFalse);
        expect(await _statusOf(port, '/health'), isNull);
      },
      skip: Platform.isWindows ? 'SIGTERM cannot be sent on Windows' : null,
      timeout: const Timeout(Duration(minutes: 4)),
    );
  });

  group('TomGracefulShutdown in process', () {
    setUpAll(initializeReflection);
    tearDown(TomHealthServer.resetHealthChecks);

    test(
      'drains a request in flight, refuses new ones, keeps the probes',
      () async {
        final shutdown = TomGracefulShutdown(
          gracePeriod: const Duration(seconds: 5),
        );
        final release = Completer<void>();
        final server = await shelf_io.serve(
          const Pipeline().addMiddleware(shutdown.middleware()).addHandler((
            request,
          ) async {
            if (request.url.path == 'slow') await release.future;
            return Response.ok(request.url.path);
          }),
          '127.0.0.1',
          0,
        );
        shutdown.httpServer = server;
        addTearDown(() => server.close(force: true));

        final client = HttpClient();
        addTearDown(() => client.close(force: true));
        // A kept-alive connection, opened before the shutdown.
        Future<HttpClientResponse> get(String path) =>
            client.get('127.0.0.1', server.port, path).then((r) => r.close());
        final first = await get('/ready');
        await first.drain<void>();
        final slow = get('/slow');
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(shutdown.inFlight, 1);

        final done = shutdown.shutdown();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(shutdown.isDraining, isTrue);
        expect(TomHealthServer.isShuttingDown, isTrue);
        expect(
          (await TomHealthServer().ready()).statusCode,
          503,
          reason: 'readiness must report the shutdown',
        );
        expect((await TomHealthServer().health()).statusCode, 200);

        // Refused by the gate, not routed — whatever the transport does with it.
        final refused = await shutdown.middleware()(
          (_) => Response.ok('should not run'),
        )(Request('GET', Uri.parse('http://localhost/anything')));
        expect(refused.statusCode, 503);
        expect(refused.headers['connection'], 'close');
        final probe = await shutdown.middleware()((_) => Response.ok('probe'))(
          Request('GET', Uri.parse('http://localhost/ready')),
        );
        expect(probe.statusCode, 200);

        release.complete();
        final response = await slow;
        expect(response.statusCode, 200);
        expect(await utf8.decodeStream(response), 'slow');
        await done;
        expect(shutdown.inFlight, 0);
      },
    );

    test(
      'stops schedulers, waits for their runs, then releases their leases',
      () async {
        final lock = TomMemoryLeaseLock();
        final scheduler = TomScheduler(
          store: TomMemoryJobStore(),
          dispatcher: const TomInlineJobDispatcher(),
          lock: lock,
        );
        final started = Completer<void>();
        final release = Completer<void>();
        scheduler.register(
          TomJobDefinition(
            name: 'drained',
            schedule: const TomEventSchedule(
              Stream<Object?>.empty(),
              sourceName: 'test',
            ),
            body: (_) => _Long(started, release.future),
          ),
        );
        final now = DateTime.now();
        await scheduler.store.enqueue(
          TomJobRun(
            id: 'drained:1',
            jobName: 'drained',
            scheduledFor: now,
            runAt: now,
          ),
        );
        unawaited(scheduler.start());
        await started.future;
        expect((await lock.inspect('job:drained')).isHeld, isTrue);

        final shutdown = TomGracefulShutdown(
          gracePeriod: const Duration(seconds: 5),
        );
        final done = shutdown.shutdown();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(scheduler.isRunning, isFalse, reason: 'no new run may start');
        expect(TomScheduler.started, contains(scheduler));

        release.complete();
        await done;
        expect(TomScheduler.started, isNot(contains(scheduler)));
        expect((await lock.inspect('job:drained')).isHeld, isFalse);
        final run = (await scheduler.store.all()).single;
        expect(run.state, TomJobRunState.succeeded, reason: 'it was drained');
      },
    );

    test(
      'a run past the grace period is abandoned and its lease released',
      () async {
        final lock = TomMemoryLeaseLock();
        final scheduler = TomScheduler(
          store: TomMemoryJobStore(),
          dispatcher: const TomInlineJobDispatcher(),
          lock: lock,
        );
        final started = Completer<void>();
        scheduler.register(
          TomJobDefinition(
            name: 'stuck',
            schedule: const TomEventSchedule(
              Stream<Object?>.empty(),
              sourceName: 'test',
            ),
            body: (_) => _Long(started, Completer<void>().future),
          ),
        );
        final now = DateTime.now();
        await scheduler.store.enqueue(
          TomJobRun(
            id: 'stuck:1',
            jobName: 'stuck',
            scheduledFor: now,
            runAt: now,
          ),
        );
        unawaited(scheduler.start());
        await started.future;

        final watch = Stopwatch()..start();
        await TomGracefulShutdown(
          gracePeriod: const Duration(milliseconds: 300),
        ).shutdown();
        expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
        expect((await lock.inspect('job:stuck')).isHeld, isFalse);
      },
    );

    test('a second call is handed the first shutdown', () {
      final shutdown = TomGracefulShutdown();
      expect(shutdown.shutdown(), same(shutdown.shutdown()));
    });
  });
}
