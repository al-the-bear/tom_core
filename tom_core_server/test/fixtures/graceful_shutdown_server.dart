/// A server process for `graceful_shutdown_test.dart` to send SIGTERM to.
///
/// Starts a [TomServer] on an OS-chosen port whose `/slow` path takes
/// [_slowFor] to answer, and a scheduler whose job `long` holds its lease in a
/// [TomFileLeaseLock] under the directory given as the first argument and runs
/// for a minute. Prints `listening <port>` and `job started` for the test to
/// wait on, then waits for a signal; the framework's graceful shutdown does
/// the rest and ends the process.
library;

import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'reflection_fixture.dart';
import 'reflection_fixture.reflection.dart';

const Duration _slowFor = Duration(seconds: 2);

class _Config extends TomBaseServerConfiguration {
  _Config() : super([]) {
    noSsl = true;
    host = '127.0.0.1';
    isolateCount = 1;
    port = 0;
    shutdownGracePeriodSeconds = 4;
    // A request that arrives at `/slow` is answered here, inside the server's
    // pipeline and so inside its graceful-shutdown accounting.
    authenticationMiddleware = (inner) => (request) async {
      if (request.url.path == 'slow') {
        await Future<void>.delayed(_slowFor);
        return Response.ok('slow done');
      }
      return inner(request);
    };
  }

  @override
  void setValues(Map<String, Object?> values) {}
}

class _Long extends TomCommand {
  _Long(this.started);
  final Completer<void> started;

  @override
  Future<Object?> execute() async {
    if (!started.isCompleted) started.complete();
    await Future<void>.delayed(const Duration(minutes: 1));
    return 'done';
  }
}

Future<void> main(List<String> args) async {
  initializeReflection();
  tomLog.setLogLevel(TomLogLevel.errors);
  TomBean.withType<FixtureApiServer>(FixtureApiServer());
  TomBean.withType<TomHealthServer>(TomHealthServer());
  TomBean.withType<FixtureAccessApiService>(FixtureAccessApiService());
  registerFixtureAccessApi();

  final started = Completer<void>();
  final scheduler = TomScheduler(
    store: TomMemoryJobStore(),
    dispatcher: const TomInlineJobDispatcher(),
    lock: TomFileLeaseLock(args.first),
    ownerId: 'graceful-shutdown-fixture',
    leaseTtl: const Duration(minutes: 10),
  );
  scheduler.register(
    TomJobDefinition(
      name: 'long',
      schedule: const TomEventSchedule(
        Stream<Object?>.empty(),
        sourceName: 'fixture',
      ),
      body: (_) => _Long(started),
      timeout: const Duration(minutes: 5),
    ),
  );
  final now = DateTime.now();
  await scheduler.store.enqueue(
    TomJobRun(id: 'long:1', jobName: 'long', scheduledFor: now, runAt: now),
  );

  final server = await TomServer(_Config()).start();
  stdout.writeln('listening ${server.port}');
  unawaited(scheduler.start());
  await started.future;
  stdout.writeln('job started');
}
