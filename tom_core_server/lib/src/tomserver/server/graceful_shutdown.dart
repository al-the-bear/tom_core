/// Graceful shutdown: what a server does between SIGTERM and exiting.
///
/// An orchestrator stopping a pod sends SIGTERM, waits its grace period, then
/// kills. What happens in between decides whether the requests in flight
/// complete, whether the queued work is handed to another node at once or
/// after a lease expires, and whether the connections in the pool are closed
/// or simply dropped. [TomGracefulShutdown.shutdown] runs the steps in the
/// order that keeps all three:
///
/// 1. **Not ready.** `GET /ready` answers `503 shutting down`
///    ([TomHealthServer.markShuttingDown]), so the load balancer stops
///    sending traffic. Liveness keeps answering: a draining process is alive.
/// 2. **Readiness delay.** Requests are still accepted for
///    `shutdownReadinessDelaySeconds`, the time a load balancer needs to
///    notice — zero by default.
/// 3. **Stop accepting.** The listener closes, so no new connection is
///    accepted; a request arriving on a kept-alive connection is answered
///    `503` with `Connection: close`. The probe routes still answer, so the
///    orchestrator keeps seeing a live, unready process.
/// 4. **Drain.** Every started scheduler — the message outbox's included —
///    is stopped, so no new run begins, and the requests in flight and the
///    runs already started get until the deadline (`shutdownGracePeriodSeconds`)
///    to finish.
/// 5. **Hand back.** Once the answered requests' responses are written, the
///    outboxes and schedulers are closed, which releases their leases so
///    another node takes the work at once rather than after the lease's TTL;
///    a run still executing past the deadline is not waited for — its lease
///    goes back with the scheduler's, and its run record, still marked
///    running, is returned to the queue by the lease-timeout recovery of the
///    next scheduler to pass. Connections still open at the deadline are
///    closed.
/// 6. **Close the pools** of every registered data source.
///
/// It runs as a `tomShutdownCleanup` signal handler, before the closables and
/// disposables registered with it, which therefore still find the data sources
/// closed and the requests answered.
library;

import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../datasources/datasource_initialization.dart';
import '../healthcheck/health_check.dart';
import '../messaging/outbox.dart';

/// The paths a draining server keeps answering: the two probes, so an
/// orchestrator sees an alive, unready process rather than a dead one.
const Set<String> tomProbePaths = {'health', 'ready'};

/// The graceful shutdown of one server — see the library documentation.
class TomGracefulShutdown {
  /// A shutdown that waits [gracePeriod] for work to finish after waiting
  /// [readinessDelay] for the load balancer to notice.
  TomGracefulShutdown({
    this.gracePeriod = const Duration(seconds: 20),
    this.readinessDelay = Duration.zero,
  });

  /// How long requests in flight and running scheduled work may take to
  /// finish once the listener is closed.
  Duration gracePeriod;

  /// How long requests are still accepted after readiness turned to 503.
  Duration readinessDelay;

  /// The bound socket, set by `TomServer.start`.
  HttpServer? httpServer;

  int _inFlight = 0;
  Completer<void>? _idle;
  bool _draining = false;
  Future<void>? _shutdown;

  /// How many requests are being served right now.
  int get inFlight => _inFlight;

  /// Whether the listener has closed and new requests are refused.
  bool get isDraining => _draining;

  /// Whether [shutdown] has been started.
  bool get isShuttingDown => _shutdown != null;

  /// A [Middleware] counting the requests in flight and refusing new ones
  /// while draining — the outermost layer of the server's pipeline.
  ///
  /// A refused request is answered `503` with `Connection: close` and
  /// `Retry-After: 1`, which a client or proxy retries elsewhere. The probe
  /// paths ([tomProbePaths]) are always passed through.
  Middleware middleware() =>
      (innerHandler) => (request) async {
        if (_draining && !tomProbePaths.contains(request.url.path)) {
          return Response(
            503,
            body: 'shutting down',
            headers: {
              HttpHeaders.connectionHeader: 'close',
              HttpHeaders.retryAfterHeader: '1',
            },
          );
        }
        _inFlight++;
        try {
          return await innerHandler(request);
        } finally {
          _inFlight--;
          if (_inFlight == 0) _idle?.complete();
          if (_inFlight == 0) _idle = null;
        }
      };

  /// Runs the shutdown once; a second call is handed the first one's future.
  Future<void> shutdown() => _shutdown ??= _run();

  Future<void> _run() async {
    final watch = Stopwatch()..start();
    tomLog.info(
      'Graceful shutdown: readiness off, $inFlight request(s) in flight',
    );
    TomHealthServer.markShuttingDown();
    if (readinessDelay > Duration.zero)
      await Future<void>.delayed(readinessDelay);

    _draining = true;
    final server = httpServer;
    // Not awaited: it stops the listener, and the connections already open
    // are what the steps below wait for.
    unawaited(server?.close());

    final schedulers = TomScheduler.started.toList();
    for (final scheduler in schedulers) {
      scheduler.stop();
    }
    final deadline = DateTime.now().add(gracePeriod);
    final finished = await _within(
      deadline,
      Future.wait([
        _requestsFinished(),
        for (final scheduler in schedulers) scheduler.drain(),
      ]),
    );
    if (!finished) {
      tomLog.warn(
        'Graceful shutdown: the grace period of $gracePeriod ran out with '
        '$inFlight request(s) in flight or scheduled work still running; '
        'what is left is not waited for, and its leases are released.',
      );
    }

    // A handler returning is not its response written: shelf writes it
    // afterwards. After the listener's close, idle connections are closed at
    // once and an answered one after its response, so waiting for the
    // connection count to reach zero is waiting for the last response.
    if (server != null && !await _connectionsClosed(server, deadline)) {
      tomLog.warn(
        'Graceful shutdown: connections still open at the deadline are '
        'closed.',
      );
    }

    for (final outbox in TomMessageOutbox.started.toList()) {
      await _logged('closing an outbox', outbox.close);
    }
    for (final scheduler in TomScheduler.started.toList()) {
      await _logged('closing a scheduler', scheduler.close);
    }
    if (server != null) {
      await _logged('closing the listener', () => server.close(force: true));
    }
    await _logged('closing the data sources', TomDataSourceInfo.closeAll);
    tomLog.info('Graceful shutdown finished after ${watch.elapsed}');
  }

  Future<void> _requestsFinished() {
    if (_inFlight == 0) return Future<void>.value();
    return (_idle ??= Completer<void>()).future;
  }

  /// Whether every connection of [server] has closed before [deadline].
  static Future<bool> _connectionsClosed(
    HttpServer server,
    DateTime deadline,
  ) async {
    while (server.connectionsInfo().total > 0) {
      if (!DateTime.now().isBefore(deadline)) return false;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return true;
  }

  /// Whether [work] finishes before [deadline].
  static Future<bool> _within(DateTime deadline, Future<void> work) async {
    final left = deadline.difference(DateTime.now());
    if (left <= Duration.zero) return false;
    try {
      await work.timeout(left);
      return true;
    } on TimeoutException {
      return false;
    }
  }

  static Future<void> _logged(
    String what,
    FutureOr<void> Function() step,
  ) async {
    try {
      await step();
    } catch (error) {
      tomLog.warn('Graceful shutdown: $what failed: $error');
    }
  }
}
