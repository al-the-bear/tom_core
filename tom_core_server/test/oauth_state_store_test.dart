/// The relational pending-authorization store's expiry prune, without a server.
///
/// `oauth_state_store_db_test.dart` proves what the prune *does* — which rows go
/// and which stay — and needs a real MariaDB to prove it. What is provable here
/// is the other half, and it is the half that drifts: **which statement the
/// store emits, and that both callers emit the same one.**
///
/// Two callers prune: the throttled sweep on [TomSqlOAuthStateStore.store], and
/// [TomSqlOAuthStateStore.purgeExpired], which a deployment drives from a
/// scheduled job or an operator drives by hand. They once carried a copy each of
/// `DELETE FROM tom_oauth_state WHERE expires_at <= :now`, which is the shape of
/// duplication that survives review and then diverges: a predicate widened in
/// one place (to keep rows for an audit window, say) leaves a store whose
/// background sweep and whose explicit purge disagree about what "expired"
/// means, and nothing fails until an operator notices rows a purge will not
/// remove. The sweep now goes through `purgeExpired`, and the tests below hold
/// it there.
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

// =============================================================================
// FIXTURES
// =============================================================================

/// One statement the store handed to its data source, with its binds.
class _Issued {
  _Issued(this.sql, this.params);

  /// The statement text.
  final String sql;

  /// The bind map, as the store supplied it.
  final Map<String, dynamic>? params;
}

/// A data source that records what it was asked and answers nothing.
///
/// Enough for the subject: no test here reads a row back, only what SQL was
/// emitted to get one. Modelled on `framework_schema_test.dart`'s recorder, but
/// keeping the binds too, because "the same statement" has to mean the same
/// parameter as well as the same text.
class _RecordingDataSource implements TomDataSource {
  /// Every statement issued, command and query alike, in order.
  final List<_Issued> issued = [];

  /// Just the expiry prunes: the deletes that name a deadline and no handle.
  ///
  /// Picked out by what distinguishes them structurally rather than by the
  /// predicate they carry — `consume` deletes by `state`, `deleteAll` names no
  /// column at all — so a test about the throttle keeps failing about the
  /// throttle even when the predicate is what someone changed.
  List<_Issued> get prunes => issued
      .where(
        (i) =>
            i.sql.startsWith('DELETE') &&
            i.sql.contains('expires_at') &&
            !i.sql.contains('state ='),
      )
      .toList();

  @override
  Future<BigInt> executeCommand(
    String command, [
    Map<String, dynamic>? params,
  ]) async {
    issued.add(_Issued(command, params));
    return BigInt.zero;
  }

  @override
  Future<List<T>> executeQuery<T extends Object>(
    String command, [
    Map<String, dynamic>? params,
    Type? resultType,
  ]) async {
    issued.add(_Issued(command, params));
    return <T>[];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'The recording data source was asked for ${invocation.memberName}, which '
    'no test needs. Implement it here if that changes.',
  );
}

/// A pending authorization under [state], with the minimum a write needs.
TomOAuthAuthorizationState _pending(String state) => TomOAuthAuthorizationState(
  state: state,
  providerId: 'stub',
  createdAt: DateTime.utc(2026, 8, 21, 12),
  client: 'web',
);

void main() {
  group('the relational state store prunes through one statement', () {
    test('the sweep and purgeExpired issue the same statement', () async {
      final datasource = _RecordingDataSource();
      final store = TomSqlOAuthStateStore(datasource);

      // The first write sweeps: nothing has stamped the throttle yet.
      await store.store(_pending('s-1'));
      await store.purgeExpired();

      final prunes = datasource.prunes;
      expect(prunes, hasLength(2));
      // Not "both look right" but "both are the same one" -- the assertion that
      // fails the moment a second copy of the predicate reappears, whatever it
      // says.
      expect(prunes.map((p) => p.sql).toSet(), hasLength(1));
      expect(
        prunes.first.sql,
        'DELETE FROM $defaultOAuthStateTable WHERE expires_at <= :now',
      );
    });

    test('both prunes bind the same single parameter', () async {
      final datasource = _RecordingDataSource();
      final store = TomSqlOAuthStateStore(datasource);

      await store.store(_pending('s-1'));
      await store.purgeExpired();

      for (final prune in datasource.prunes) {
        // One bind, named for what the predicate reads. A caller passing an
        // instant and a caller taking the store's clock must still produce the
        // same shape of statement, or they are not the same statement.
        expect(prune.params?.keys, ['now']);
        expect(prune.params?['now'], isA<String>());
      }
    });

    test('the sweep still prunes at most once per sweepInterval', () async {
      final datasource = _RecordingDataSource();
      final store = TomSqlOAuthStateStore(
        datasource,
        sweepInterval: const Duration(hours: 1),
      );

      await store.store(_pending('s-1'));
      await store.store(_pending('s-2'));

      // Sharing the statement must not cost the throttle: the prune is
      // bookkeeping, and every read already carries the expiry predicate, so a
      // delete per login would buy nothing.
      expect(datasource.prunes, hasLength(1));
    });

    test('a zero sweepInterval prunes on every write', () async {
      final datasource = _RecordingDataSource();
      final store = TomSqlOAuthStateStore(
        datasource,
        sweepInterval: Duration.zero,
      );

      await store.store(_pending('s-1'));
      await store.store(_pending('s-2'));

      expect(datasource.prunes, hasLength(2));
    });

    test('an explicit purge does not stand in for the sweep', () async {
      final datasource = _RecordingDataSource();
      final store = TomSqlOAuthStateStore(
        datasource,
        sweepInterval: const Duration(hours: 1),
      );

      // The delegation runs one way only. `purgeExpired` is the statement the
      // sweep uses, not a second entry point into the sweep's clock: an
      // operator pruning by hand does not thereby suppress the store's own
      // bookkeeping on the next login.
      await store.purgeExpired();
      await store.store(_pending('s-1'));

      expect(datasource.prunes, hasLength(2));
    });
  });
}
