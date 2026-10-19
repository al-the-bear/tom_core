/// Whether a failed data-source write is *known* not to have happened, or
/// merely unknown.
///
/// ## The question this answers
///
/// A write that throws has two very different meanings. If the server answered
/// — "duplicate key", "deadlock, transaction rolled back", "syntax error" —
/// then the statement definitively did not take effect, and the caller may
/// treat the failure as a clean no-op. If the *connection* failed, the caller
/// learned nothing: the statement may have been received, executed and
/// committed, with only the acknowledgement lost. The write may well have
/// happened.
///
/// For most statements this distinction does not matter, because the caller
/// retries or gives up either way. It matters wherever the affected-row count
/// **is** the answer to a question — an exclusive claim, a compare-and-set
/// takeover — because there "the write failed" and "I did not get it" are then
/// two different statements, and conflating them hands ownership to a node that
/// believes it does not own anything.
///
/// ## Why the test recognises the *definite* side
///
/// The obvious shape is a list of transport failures — socket closed, broken
/// pipe, TLS reset, timeout — treated as ambiguous and everything else as
/// definite. That list is open-ended: it grows with every driver, every proxy
/// and every platform, and each omission is a silent correctness bug that only
/// shows up under a network fault.
///
/// The other side is closed and recognisable. "The server sent back an error"
/// is exactly one thing — a [MySQLServerException], carrying the server's own
/// error code — and it is the only case in which the outcome is known. So the
/// test is inverted: **definite when the server answered, ambiguous
/// otherwise**.
///
/// The asymmetry of the costs makes this the right default. Deciding
/// "ambiguous" when the truth was "definite" costs one extra `SELECT` that
/// finds nothing changed. Deciding "definite" when the truth was "ambiguous" is
/// the bug this file exists to prevent.
library;

import 'package:mysql_client/exception.dart';
import 'package:postgres/postgres.dart' as pg;
import 'package:tom_basics/tom_basics.dart';

/// What a failed data-source write says about whether it took effect.
enum TomSqlFailureMode {
  /// The server answered with an error, so the statement did not take effect.
  definite,

  /// The outcome is unknown: the failure was on the way to or from the server,
  /// and the write may have been applied anyway.
  ambiguous,
}

/// How far [classifySqlFailure] follows a `rootException` chain.
///
/// Wrapping is shallow in practice — a driver exception inside a
/// `MariadbDatasourceException` is two links. The bound exists only so a cyclic
/// or pathologically nested chain cannot spin.
const int _maxCauseDepth = 8;

/// Classifies [error], the failure of a data-source write.
///
/// Returns [TomSqlFailureMode.definite] when the chain contains a
/// [MySQLServerException] or a PostgreSQL `ServerException` — the server
/// received the statement, rejected it, and said so — and [TomSqlFailureMode.ambiguous] for everything else. See the
/// library comment for why the recognisable side is the definite one.
TomSqlFailureMode classifySqlFailure(Object? error) {
  for (final cause in sqlFailureCauses(error)) {
    if (cause is MySQLServerException || cause is pg.ServerException) {
      return TomSqlFailureMode.definite;
    }
  }
  return TomSqlFailureMode.ambiguous;
}

/// Whether [error] left the statement without a live server to have run on, so
/// that reconnecting and trying once more is worth doing.
///
/// [connected] is the driver's own view of the link when the failure was caught
/// (`MySQLConnection.connected`, and so `MariaDbDatasource.connected`). It is
/// the load-bearing half, because the exception on its own cannot answer this:
/// the driver reports a link it already knows is gone as a bare
/// [MySQLClientException] with no error code, and raises that same type for a
/// protocol desync, a second `BEGIN` and a failed handshake. Matching the type
/// would retry failures a second attempt cannot fix; matching the *message*
/// binds this decision to the wording of a third-party `toString`, which no
/// contract holds still. Every "connection closed" the driver throws sits
/// behind its own `!connected` guard, so the flag recognises exactly those —
/// by documented API.
///
/// The chain is still consulted, for the opposite case. A
/// [MySQLServerException] anywhere beneath [error] means the server received
/// the statement and rejected it, and that verdict stands however the link
/// looks afterwards — retrying would re-run a statement the server has
/// already judged, and for a write, one whose effect is unknown. That is the
/// same reading of the same evidence as [classifySqlFailure], so it is asked
/// rather than repeated.
bool isLostConnectionFailure(Object? error, {required bool connected}) =>
    !connected && classifySqlFailure(error) == TomSqlFailureMode.ambiguous;

/// [error] and every `rootException` beneath it, outermost first.
///
/// Exposed because a caller that has decided a failure is ambiguous usually
/// wants to log *what* it was, and the driver exception it needs to name is
/// several wrappers down.
Iterable<Object> sqlFailureCauses(Object? error) sync* {
  var current = error;
  for (var depth = 0; current != null && depth < _maxCauseDepth; depth++) {
    yield current;
    current = current is TomBaseException ? current.rootException : null;
  }
}
