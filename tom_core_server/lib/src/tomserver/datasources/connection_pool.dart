/// A bounded pool of database connections, shared by every driver.
///
/// A data source with one connection serialises its users: a transaction
/// holds the connection from its first statement to its conclusion, so every
/// other transaction on that database waits, and one slow request stalls all
/// of them. [TomConnectionPool] gives each user a connection of its own, up to
/// [TomConnectionPoolSettings.maxSize], and hands connections back for reuse.
///
/// The pool knows nothing about any database. A driver supplies a
/// [TomConnectionFactory] that opens, closes, checks and validates its own
/// connection type, and decides what a lease is held for: the MariaDB drivers
/// pin one connection to a transaction from its first statement to its end,
/// and lend one to a statement outside a transaction for that statement alone.
library;

import 'dart:async';
import 'dart:collection';

import '../little_things/server_exception.dart';

/// Thrown when the pool cannot hand out a connection: it is closed, every
/// connection stayed busy past the acquire timeout, or its settings are
/// inconsistent.
///
/// A server-side condition, so it is not shown to the caller
/// (`clientThrow: false`); the key is what an operator matches on.
class TomConnectionPoolException extends TomServerException {
  /// Creates the exception with a message [key] and [defaultUserMessage].
  TomConnectionPoolException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.rootException,
    super.stack,
  }) : super(clientThrow: false);
}

/// How a [TomConnectionPool] sizes itself and when it retires a connection.
///
/// The defaults are the common ones of JDBC pools (HikariCP among them): at
/// most ten connections, none kept open for nothing, a thirty-second wait for a
/// free one, idle connections closed after ten minutes and every connection
/// replaced after thirty, and a connection that sat idle for more than thirty
/// seconds checked before it is lent out.
class TomConnectionPoolSettings {
  /// The most connections open at once, lent out or idle. At least 1.
  final int maxSize;

  /// How many idle connections the pool keeps open ahead of demand. At most
  /// [maxSize]; `0` opens connections only when they are asked for.
  final int minIdle;

  /// How long [TomConnectionPool.acquire] waits for a connection when all
  /// [maxSize] are lent out, before it fails.
  final Duration acquireTimeout;

  /// How long a connection may sit idle before the pool closes it (while more
  /// than [minIdle] are idle).
  ///
  /// Checked whenever the pool is used — and, with [sweepIdle], by a timer
  /// while idle connections are open: without it a pool with no traffic
  /// closes its idle connections when traffic resumes, since a timer would
  /// keep a process that never closes its data source from exiting.
  final Duration idleTimeout;

  /// Whether a timer closes idle connections past [idleTimeout] while the
  /// pool sees no traffic. For pools that are many and mostly quiet — a
  /// tenant's own — so a tenant nobody uses holds no connection; such a pool
  /// must be closed, or its timer keeps the process alive until the
  /// connections are retired.
  final bool sweepIdle;

  /// How long a connection is used at all before the pool replaces it.
  ///
  /// Bounds what a long-lived connection can accumulate — server-side session
  /// state, a load balancer's idea of where it points — and keeps the pool
  /// clear of the server's own idle disconnect.
  final Duration maxLifetime;

  /// A connection idle for longer than this is validated before it is lent,
  /// and replaced if the check fails. Shorter idle periods are trusted.
  final Duration validateAfterIdle;

  /// Creates settings; every value defaults to the pool's standard one.
  const TomConnectionPoolSettings({
    this.maxSize = 10,
    this.minIdle = 0,
    this.acquireTimeout = const Duration(seconds: 30),
    this.idleTimeout = const Duration(minutes: 10),
    this.maxLifetime = const Duration(minutes: 30),
    this.validateAfterIdle = const Duration(seconds: 30),
    this.sweepIdle = false,
  });

  /// Throws `error.datasource.pool.invalid_settings` unless every value is
  /// usable: [maxSize] at least 1, [minIdle] between 0 and [maxSize], and
  /// every duration positive.
  void validate() {
    String? fault;
    if (maxSize < 1) {
      fault = 'maxSize must be at least 1, was $maxSize';
    } else if (minIdle < 0 || minIdle > maxSize) {
      fault = 'minIdle must be between 0 and maxSize ($maxSize), was $minIdle';
    } else if (acquireTimeout <= Duration.zero ||
        idleTimeout <= Duration.zero ||
        maxLifetime <= Duration.zero ||
        validateAfterIdle < Duration.zero) {
      fault = 'every timeout must be positive';
    }
    if (fault == null) return;
    throw TomConnectionPoolException(
      'error.datasource.pool.invalid_settings',
      'Connection pool settings are not usable: $fault.',
      parameters: {'fault': fault},
    );
  }

  @override
  String toString() =>
      'TomConnectionPoolSettings(maxSize: $maxSize, minIdle: $minIdle, '
      'acquireTimeout: $acquireTimeout, idleTimeout: $idleTimeout, '
      'maxLifetime: $maxLifetime, validateAfterIdle: $validateAfterIdle, '
      'sweepIdle: $sweepIdle)';
}

/// What a driver tells a [TomConnectionPool] about its connection type [C].
abstract interface class TomConnectionFactory<C extends Object> {
  /// Opens a new connection. A failure propagates to the caller of
  /// [TomConnectionPool.acquire] that needed it.
  Future<C> open();

  /// Closes [connection]. Called once per connection, when the pool retires
  /// it; a failure is logged by the caller, never propagated.
  Future<void> close(C connection);

  /// Whether [connection] is still usable without asking the server — the
  /// driver's own record of whether its link is up.
  bool isUsable(C connection);

  /// Asks the server whether [connection] still works (a `SELECT 1`).
  Future<bool> validate(C connection);
}

/// One open connection and the times the pool judges it by.
class _Entry<C extends Object> {
  _Entry(this.connection, this.openedAt) : lastReleasedAt = openedAt;

  final C connection;
  final DateTime openedAt;
  DateTime lastReleasedAt;
}

/// A bounded pool of connections of type [C]; see the library documentation.
///
/// [acquire] lends a connection and [release] takes it back. A released
/// connection goes to the longest-waiting [acquire] first, so a caller that
/// arrived later cannot overtake one that has been waiting.
class TomConnectionPool<C extends Object> {
  /// Creates a pool over [factory]. [clock] is injectable for tests.
  TomConnectionPool(
    this.factory, {
    this.settings = const TomConnectionPoolSettings(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    settings.validate();
  }

  /// Opens, closes and checks the connections.
  final TomConnectionFactory<C> factory;

  /// How the pool sizes itself and retires connections.
  final TomConnectionPoolSettings settings;

  final DateTime Function() _clock;

  /// Idle connections; the most recently released is at the end and is lent
  /// first, so the rest age out under [TomConnectionPoolSettings.idleTimeout].
  final List<_Entry<C>> _idle = [];

  /// Lent connections, by identity.
  final Map<C, _Entry<C>> _lent = HashMap.identity();

  /// Callers waiting for a connection, oldest first. Completed with a
  /// connection handed over by [release], or with `null` when capacity freed
  /// up and the caller should try again.
  final Queue<Completer<C?>> _waiters = Queue();

  int _opening = 0;
  bool _closed = false;

  /// Whether [close] has been called.
  bool get isClosed => _closed;

  /// Open connections, lent or idle, plus those being opened.
  int get size => _idle.length + _lent.length + _opening;

  /// Idle connections.
  int get idleCount => _idle.length;

  /// Lent connections.
  int get lentCount => _lent.length;

  /// Callers waiting in [acquire].
  int get waitingCount => _waiters.length;

  /// Every open connection, lent or idle.
  Iterable<C> get connections => [
    for (final e in _idle) e.connection,
    ..._lent.keys,
  ];

  /// The idle connections, which nothing is using.
  Iterable<C> get idleConnections => [for (final e in _idle) e.connection];

  /// Whether [connection] is currently lent out.
  bool isLent(C connection) => _lent.containsKey(connection);

  /// Lends a connection, opening one if there is room, or waiting up to
  /// [TomConnectionPoolSettings.acquireTimeout] for one to be released.
  ///
  /// Throws `error.datasource.pool.closed` once the pool is closed, and
  /// `error.datasource.pool.acquire_timeout` when the wait runs out. A failure
  /// to open a connection propagates as the factory raised it.
  Future<C> acquire() async {
    final deadline = _clock().add(settings.acquireTimeout);
    while (true) {
      _refuseIfClosed();
      _retireIdle();
      final idle = await _takeIdle();
      if (idle != null) return idle;
      if (size < settings.maxSize) return _openLent();

      final waiter = Completer<C?>();
      _waiters.add(waiter);
      final remaining = deadline.difference(_clock());
      final timer = Timer(remaining.isNegative ? Duration.zero : remaining, () {
        if (waiter.isCompleted) return;
        _waiters.remove(waiter);
        waiter.completeError(
          TomConnectionPoolException(
            'error.datasource.pool.acquire_timeout',
            'No database connection became free within '
                '${settings.acquireTimeout.inMilliseconds} ms; all '
                '${settings.maxSize} are in use.',
            parameters: {
              'maxSize': settings.maxSize,
              'timeoutMs': settings.acquireTimeout.inMilliseconds,
            },
          ),
        );
      });
      final C? handedOver;
      try {
        handedOver = await waiter.future;
      } finally {
        timer.cancel();
      }
      if (handedOver != null) return handedOver;
    }
  }

  /// Takes [connection] back.
  ///
  /// With [discard], or when the connection is no longer usable, past its
  /// [TomConnectionPoolSettings.maxLifetime], or the pool is closed, it is
  /// closed instead of kept. Otherwise it goes to the longest waiter, or to the
  /// idle list. Releasing a connection the pool did not lend throws
  /// [StateError]: that is a bookkeeping bug in the caller.
  Future<void> release(C connection, {bool discard = false}) async {
    final entry = _lent.remove(connection);
    if (entry == null) {
      // throws-outside-family: programmer error — a caller handing back a
      // connection the pool never lent has lost track of its own lease.
      throw StateError('$connection was not lent by this pool.');
    }
    if (discard ||
        _closed ||
        !factory.isUsable(connection) ||
        _expired(entry)) {
      await _destroy(entry);
      _wakeOne(null);
      _fillMinIdle();
      return;
    }
    entry.lastReleasedAt = _clock();
    if (_waiters.isNotEmpty) {
      _lent[connection] = entry;
      _wakeOne(connection);
      return;
    }
    _idle.add(entry);
    _retireIdle();
    _scheduleSweep();
  }

  Timer? _sweep;

  /// With [TomConnectionPoolSettings.sweepIdle], retires idle connections
  /// once the oldest of them has been idle for the idle timeout, and again
  /// while any remain.
  void _scheduleSweep() {
    if (!settings.sweepIdle || _closed || _sweep != null) return;
    if (_idle.length <= settings.minIdle) return;
    final oldest = _idle
        .map((e) => e.lastReleasedAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final due = settings.idleTimeout - _clock().difference(oldest);
    _sweep = Timer(due.isNegative ? Duration.zero : due, () {
      _sweep = null;
      _retireIdle();
      _scheduleSweep();
    });
  }

  /// Closes the pool: idle connections are closed now, lent ones when they are
  /// released, and every waiter fails with `error.datasource.pool.closed`.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _sweep?.cancel();
    _sweep = null;
    while (_waiters.isNotEmpty) {
      _waiters.removeFirst().completeError(_closedException());
    }
    final idle = List.of(_idle);
    _idle.clear();
    for (final e in idle) {
      await _destroy(e);
    }
  }

  void _refuseIfClosed() {
    if (_closed) throw _closedException();
  }

  TomConnectionPoolException _closedException() => TomConnectionPoolException(
    'error.datasource.pool.closed',
    'The connection pool has been closed.',
  );

  /// Lends the most recently released usable idle connection, discarding the
  /// ones that are down, past their lifetime or fail validation.
  Future<C?> _takeIdle() async {
    while (_idle.isNotEmpty) {
      final entry = _idle.removeLast();
      if (!factory.isUsable(entry.connection) || _expired(entry)) {
        await _destroy(entry);
        continue;
      }
      _lent[entry.connection] = entry;
      final idleFor = _clock().difference(entry.lastReleasedAt);
      if (idleFor > settings.validateAfterIdle) {
        bool valid;
        try {
          valid = await factory.validate(entry.connection);
        } catch (_) {
          valid = false;
        }
        if (!valid) {
          _lent.remove(entry.connection);
          await _destroy(entry);
          continue;
        }
      }
      return entry.connection;
    }
    return null;
  }

  /// Opens a connection and lends it; the slot is reserved while opening so
  /// concurrent callers cannot open more than [TomConnectionPoolSettings.maxSize].
  Future<C> _openLent() async {
    _opening++;
    C opened;
    try {
      opened = await factory.open();
    } catch (_) {
      _opening--;
      // The reserved slot is free again; a waiter may take it.
      _wakeOne(null);
      rethrow;
    }
    _opening--;
    _lent[opened] = _Entry(opened, _clock());
    if (_closed) {
      await release(opened, discard: true);
      throw _closedException();
    }
    return opened;
  }

  bool _expired(_Entry<C> entry) =>
      _clock().difference(entry.openedAt) >= settings.maxLifetime;

  /// Closes idle connections past their idle timeout or lifetime, keeping
  /// [TomConnectionPoolSettings.minIdle] of them.
  void _retireIdle() {
    final now = _clock();
    final retire = <_Entry<C>>[];
    var kept = _idle.length;
    for (final e in _idle) {
      final idleTooLong =
          now.difference(e.lastReleasedAt) >= settings.idleTimeout &&
          kept > settings.minIdle;
      if (_expired(e) || idleTooLong) {
        retire.add(e);
        kept--;
      }
    }
    for (final e in retire) {
      _idle.remove(e);
      unawaited(_destroy(e));
    }
  }

  /// Opens idle connections in the background until [TomConnectionPoolSettings.minIdle]
  /// are available. A failure is left for the next [acquire] to meet.
  void _fillMinIdle() {
    if (_closed) return;
    final missing = settings.minIdle - _idle.length;
    for (var i = 0; i < missing && size < settings.maxSize; i++) {
      _opening++;
      unawaited(
        factory.open().then(
          (c) {
            _opening--;
            final entry = _Entry(c, _clock());
            if (_closed) {
              unawaited(_destroy(entry));
              return;
            }
            if (_waiters.isNotEmpty) {
              _lent[c] = entry;
              _wakeOne(c);
            } else {
              _idle.add(entry);
            }
          },
          onError: (Object _) {
            _opening--;
            _wakeOne(null);
          },
        ),
      );
    }
  }

  void _wakeOne(C? connection) {
    if (_waiters.isEmpty) {
      if (connection != null) {
        // Nobody to hand it to after all: keep it idle.
        final entry = _lent.remove(connection);
        if (entry != null) _idle.add(entry);
      }
      return;
    }
    _waiters.removeFirst().complete(connection);
  }

  Future<void> _destroy(_Entry<C> entry) async {
    try {
      await factory.close(entry.connection);
    } catch (_) {
      // A connection being retired is gone either way; the driver's own
      // close logs what it knows.
    }
  }

  @override
  String toString() =>
      'TomConnectionPool(lent: $lentCount, idle: $idleCount, '
      'waiting: $waitingCount, max: ${settings.maxSize}'
      '${_closed ? ', closed' : ''})';
}
