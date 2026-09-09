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
///
/// The file also carries the module's schema guard, for the same reason: the
/// text `oauthStateTableDdl` renders is compared to the migration a DBA
/// applies. `framework_schema_test.dart` already replays the shipped chain and
/// compares the schema it *arrives at*, which is the stronger check and is not
/// repeated here — but it is deliberately blind to how a statement is spelled,
/// and a spelling is what a deployment copies into its own migration. That
/// blindness is measured rather than assumed: narrowing a column and dropping a
/// nullability both converge.
///
/// A store constructed with `table:` set to something else ships no migration at
/// all, so what the helper renders for that name is the only source of its DDL.
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/sql_text.dart';

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

  // The named constructor resolves a data source out of the registry and throws
  // before it touches one, so this needs no database — which is the reason it
  // lives here and not in `oauth_state_store_db_test.dart`.
  group('the relational state store resolves its data source by name', () {
    test('an unregistered name fails at construction, not at first login', () {
      // The assertion names the base class is what is raised, deliberately — a construction-time
      // wiring guard has no `catch` clause to discriminate for, so there is
      // nothing for a subtype to add. `TomServerException` gives the argument
      // and `server_exception_family_test.dart` pins the five sites that may do
      // it, so this assertion is as narrow as the type system allows here.
      expect(
        () => TomSqlOAuthStateStore.named('no-such-datasource'),
        throwsA(
          isA<TomServerException>()
              .having(
                (e) => e.key,
                'key',
                'oauth.state_store.unknown_datasource',
              )
              // The name is carried as a parameter rather than only baked into
              // the message: a cluster misconfigured this way has one typo in
              // one YAML key, and the failure has to say which.
              .having(
                (e) => e.parameters?['datasource'],
                'datasource',
                'no-such-datasource',
              ),
        ),
      );
    });
  });

  group('the OAuth-state migration matches the shipped DDL', () {
    test('the migration is the DDL the store creates', () {
      expect(
        normaliseSql(
          readMigration('authentication', '[2]-create_tom_oauth_state.sql'),
        ),
        normaliseSql(oauthStateTableDdl(defaultOAuthStateTable)),
      );
    });

    test('the DDL follows the table name it is given', () {
      // The whole reason the function takes a name. `TomSqlOAuthStateStore`
      // accepts `table:`, and a store over a renamed table ships no migration
      // of its own — this is where its DDL comes from, and it has to name the
      // table the store will actually address.
      expect(
        oauthStateTableDdl('sso_pending'),
        contains('CREATE TABLE IF NOT EXISTS sso_pending'),
      );
      expect(
        oauthStateTableDdl('sso_pending'),
        contains('KEY ix_sso_pending_expiry (expires_at)'),
        reason: 'the index is named after the table, not after the default',
      );
    });
  });

  group('the OAuth-state schema encodes what the store relies on', () {
    final ddl = oauthStateTableDdl(defaultOAuthStateTable);

    test('the handle is the identity, with no surrogate key beside it', () {
      // A second row for the same handle would make "which pending flow does
      // this callback complete" depend on row order, which is the one question
      // the table exists to answer unambiguously.
      expect(ddl, contains('PRIMARY KEY (state)'));
      expect(
        ddl,
        isNot(contains('AUTO_INCREMENT')),
        reason: 'a surrogate key would let the handle repeat',
      );
    });

    test('the sweep has an index to ride', () {
      // Without it, pruning is a full scan of a table whose whole point is to
      // be swept often — and both the throttled sweep and `purgeExpired` go
      // through the `expires_at` predicate the tests above pin.
      expect(
        ddl,
        contains('KEY ix_${defaultOAuthStateTable}_expiry (expires_at)'),
      );
    });

    test('the PKCE pair are the only nullable columns', () {
      // A provider may be configured without PKCE, so those two may be absent.
      // Every other column is written on every insert — the login-context
      // columns hold `''` for "not supplied", matching the Dart record whose
      // fields default to the empty string. A nullable one there would be a
      // second spelling of absence that every read would have to collapse.
      final nullable = ddl
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.endsWith('NULL,') && !line.contains('NOT NULL'))
          .map((line) => line.split(RegExp(r'\s+')).first);
      expect(nullable, ['pkce_verifier', 'pkce_challenge']);
    });

    test('both instants are DATETIME(6), the width sqlInstant writes', () {
      // Not a precision preference: every `DateTime` bound by this data source
      // is rendered by `sqlInstant`, which always emits six fractional digits,
      // and MariaDB silently *rounds* the excess on a narrower column rather
      // than rejecting it. A plain `DATETIME` would therefore store a different
      // moment, up to half a second away — and `expires_at` is a deadline the
      // completion predicate compares against.
      expect(ddl, contains('created_at      DATETIME(6)  NOT NULL'));
      expect(ddl, contains('expires_at      DATETIME(6)  NOT NULL'));
    });
  });
}
