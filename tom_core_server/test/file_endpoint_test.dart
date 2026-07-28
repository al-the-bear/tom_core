import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' show Client;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' show Router;
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show
        FixtureAmbiguousSlotRecord,
        FixtureApiServer,
        FixtureDocumentRecord,
        FixtureFileSlotRecord,
        FixtureUnmappedFileRecord;
import 'fixtures/reflection_fixture.reflection.dart';

/// CSFSB1 / CSEXC4 — the framework's HTTP file endpoint, end to end.
///
/// The point of the suite is that the two halves of file storage meet: a *real*
/// [TomHttpFileTransferClient] from the kernel talks to a *real* HTTP server
/// running the reflected endpoint pipeline, over the wire contract, with no test
/// double on either side of the socket. If the descriptor shape, the header
/// names or the status codes ever drift apart, these tests stop passing —
/// which is the only reason to run a socket in a unit-test suite.
///
/// The repository below is in memory on purpose. What the endpoint owes the
/// system is that it *translates* the repository contract into HTTP: a refused
/// column becomes 403, an absent row becomes 404, a stream stays a stream. That
/// the repository enforces C-3/C-4 correctly in the first place is
/// `file_reference_test.dart`'s job, against MariaDB; asserting it twice would
/// only mean the endpoint suite could not run without a database.

/// An in-memory [TomFileRepository] over a real [TomBlobStore].
///
/// Mirrors the gates `TomSqlDatasourceRepository` applies — the write grade
/// before an upload, the read grade before a download, `row_not_found` for a row
/// that is not there (or not visible), `no_file` for a column that holds no key
/// — because those are exactly the outcomes the endpoint has to map, and a fake
/// that never refused anything would let a broken mapping pass.
class _MemoryFileRepository
    implements TomFileRepository<FixtureFileSlotRecord, int> {
  _MemoryFileRepository({
    this.grades = const {},
    this.outOfScope = const {},
    this.writeScopeRefused = const {},
    this.loseStoredBlob = false,
  });

  /// Column grades by resource key; an unlisted key is unrestricted.
  final Map<String, TomAuthState> grades;

  /// Row ids the current principal's data scope (C-3) excludes.
  ///
  /// Modelled exactly as `TomSqlDatasourceRepository` behaves: the scope
  /// predicate is ANDed into the read's `WHERE`, so an excluded row is not
  /// *refused*, it is not *found* — reads answer as they do for an id that never
  /// existed, and only a write names the refusal. Getting this wrong in the fake
  /// would let a wrong mapping pass, which is the whole reason the fake mirrors
  /// the gates rather than waving them through.
  final Set<int> outOfScope;

  /// Row ids whose *write* the scope refuses even though the read admits them.
  ///
  /// Not a state `TomSqlDatasourceRepository` can be in — its write guard reuses
  /// the read predicate — but [TomFileRepository] is an interface, and
  /// `TomDataScopeAuthorizationException` is part of its `saveFile` contract. The
  /// endpoint's job is to translate that contract into HTTP for *any*
  /// implementation of it, so the translation has to be exercised on its own,
  /// not only through the read gate that happens to fire first.
  final Set<int> writeScopeRefused;

  /// Drops the blob after a successful `saveFile`, leaving the row holding a key
  /// the store cannot answer for.
  ///
  /// The row and the store are two systems, and nothing in the interface makes
  /// them atomic — a store eviction, a failed replica, a key deleted out of band
  /// all land here. The endpoint has a named branch for exactly this
  /// (`stored_file_not_readable`), and the only way to reach it is to put the
  /// two into the disagreement it describes.
  final bool loseStoredBlob;

  /// The rows, by primary key.
  final Map<int, FixtureFileSlotRecord> rows = {};

  /// The row [id] as the scope lets the caller see it: `null` when excluded,
  /// which is the same answer an absent id gets.
  FixtureFileSlotRecord? _visible(int id) =>
      outOfScope.contains(id) ? null : rows[id];

  TomColumnInformation _column(String fieldName) {
    for (final column in TomAnnotationAnalyzer.findFileColumns(
      FixtureFileSlotRecord,
    )) {
      if (column.declaredName == fieldName ||
          column.getQueryFieldName() == fieldName) {
        return column;
      }
    }
    throw TomStorageException(
      'storage.file_reference.unknown_column',
      'That field is not a stored-file column of this entity.',
      parameters: {'field': fieldName},
    );
  }

  TomAuthState _grade(TomColumnInformation column) =>
      TomColumnAuthorization.stateForKey(
        column.column?.authKey,
        resolver: (key) => grades[key] ?? TomAuthState.full,
      );

  TomBlobStore _store(TomColumnInformation column) =>
      TomFileReferenceKeys.storeFor(column.fileReference!);

  @override
  Future<FixtureFileSlotRecord?> findById(int id) async => _visible(id);

  @override
  Future<FixtureFileSlotRecord> saveFile(
    FixtureFileSlotRecord entity,
    String fieldName,
    Stream<List<int>> bytes, {
    String? mediaType,
    String? fileName,
  }) async {
    final column = _column(fieldName);
    if (!_grade(column).isInteractive) {
      throw TomColumnAuthorizationException(
        'column_authorization.write.field_forbidden',
        'Column "${column.declaredName}" is not writable at your access level.',
      );
    }
    final id = entity.id;
    if (id != null && (outOfScope.contains(id) || writeScopeRefused.contains(id))) {
      throw TomDataScopeAuthorizationException(
        'data_scope.write.out_of_scope',
        'The requested row is not within your data scope.',
      );
    }
    final reference = column.fileReference!;
    final key = TomFileReferenceKeys.generate(reference, fileName: fileName);
    await _store(column).put(
      key: key,
      bytes: bytes,
      mediaType: mediaType ?? reference.mediaType,
      fileName: fileName,
    );
    column.setVariableValue(entity, key);
    // The row keeps the key; the bytes go. This is the write *succeeding* — the
    // caller is told nothing — and the disagreement only surfaces on the read
    // back, which is what makes it worth a branch of its own.
    if (loseStoredBlob) await _store(column).delete(key);
    return entity;
  }

  @override
  Stream<List<int>> openFile(int id, String fieldName) async* {
    final column = _column(fieldName);
    final row = _visible(id);
    if (row == null) {
      throw TomStorageException(
        'storage.file_reference.row_not_found',
        'No such record exists, or it is not visible to you.',
        parameters: {'id': '$id'},
      );
    }
    if (!_grade(column).showsContent) {
      throw TomColumnAuthorizationException(
        'column_authorization.read.field_forbidden',
        'Column "${column.declaredName}" is not readable at your access level.',
      );
    }
    final key = column.getVariableValue(row);
    if (key is! String || key.isEmpty) {
      throw TomStorageException(
        'storage.file_reference.no_file',
        'That record has no file attached.',
        parameters: {'id': '$id', 'field': fieldName},
      );
    }
    yield* _store(column).get(key);
  }

  @override
  Future<TomStoredBlob?> describeFile(int id, String fieldName) async {
    final column = _column(fieldName);
    final row = _visible(id);
    if (row == null) return null;
    if (!_grade(column).showsContent) {
      throw TomColumnAuthorizationException(
        'column_authorization.read.field_forbidden',
        'Column "${column.declaredName}" is not readable at your access level.',
      );
    }
    final key = column.getVariableValue(row);
    if (key is! String || key.isEmpty) return null;
    return _store(column).describe(key);
  }

  @override
  Future<FixtureFileSlotRecord> clearFile(
    FixtureFileSlotRecord entity,
    String fieldName,
  ) async {
    final column = _column(fieldName);
    final key = column.getVariableValue(entity);
    column.setVariableValue(entity, null);
    if (key is String && key.isNotEmpty && column.fileReference!.cascadeDelete) {
      await _store(column).delete(key);
    }
    return entity;
  }
}

/// Supplies a plain `dart:io` HTTP client to the kernel's transfer client.
///
/// The kernel's default factory delegates to `TomPlatformUtils.current`, whose
/// fallback implementation has no client — a Flutter or server host installs a
/// real one. A test is its own host, so it installs one too. (The kernel's own
/// `file_transfer_test.dart` does exactly this.)
class _TestClientFactory extends TomHttpClientFactory {
  @override
  Client getClient() => Client();
}

/// A repository that exists only to be *read for its annotations*.
///
/// [TomFileSlots.register] resolves the entity's table and file columns by
/// mirror and never calls a single repository method, so a type that cannot
/// serve a request is still a perfectly good argument. It has to be a fake
/// rather than a real `TomSqlDatasourceRepository`, because constructing one of
/// those resolves its data source and there is no database in this suite.
///
/// Generic in [T] because every registration failure is a failure to read some
/// entity's annotations, and they differ only in which entity: writing one such
/// stand-in per rejected fixture would be three copies of a class whose whole
/// body is a refusal.
class _AnnotationsOnlyRepository<T extends Object>
    implements TomFileRepository<T, int> {
  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'This repository is registered for its annotations only.',
  );
}

void main() {
  setUpAll(() {
    initializeReflection();
    TomHttpClientFactory.setGlobalHttpClientFactory(_TestClientFactory());
  });

  group('TomFileSlots.register (reflection-derived slots)', () {
    setUp(TomFileSlots.reset);
    tearDown(TomFileSlots.reset);

    test('derives one slot per exposed column, named by table and column', () {
      TomFileSlots.register(_MemoryFileRepository());
      // `internal_notes` is a file column too, and is deliberately absent: the
      // slot name comes from the mapped column name, and exposure is opt-in.
      expect(
        TomFileSlots.slots,
        unorderedEquals([
          'fixture_file_slot/poster',
          'fixture_file_slot/graded_poster',
        ]),
      );
    });

    test('an entity written before exposure existed publishes nothing', () {
      // FixtureDocumentRecord (CSFS1) has two @TomFileReference columns and
      // marks neither exposed. Default-closed means adding the endpoint did not
      // silently put its files on the network.
      expect(
        () => TomFileSlots.register(
          _AnnotationsOnlyRepository<FixtureDocumentRecord>(),
        ),
        throwsA(
          isA<TomFileSlotException>().having(
            (e) => e.key,
            'key',
            'file_endpoint.no_exposed_column',
          ),
        ),
      );
    });

    test('registering the same table twice is refused', () {
      TomFileSlots.register(_MemoryFileRepository());
      expect(
        () => TomFileSlots.register(_MemoryFileRepository()),
        throwsA(
          isA<TomFileSlotException>().having(
            (e) => e.key,
            'key',
            'file_endpoint.duplicate_slot',
          ),
        ),
      );
    });

    test('a non-exposed column resolves to no slot', () {
      TomFileSlots.register(_MemoryFileRepository());
      expect(
        TomFileSlots.resolve('fixture_file_slot', 'internal_notes'),
        isNull,
      );
      // …and neither does its Dart field name, which the repository would also
      // have accepted.
      expect(
        TomFileSlots.resolve('fixture_file_slot', 'internalNotes'),
        isNull,
      );
    });

    test('an entity that declares no table cannot expose files at all', () {
      // A slot is `<table>/<id>/<column>` and the table name comes from
      // `@TomDbTable`. An unmapped entity has no name to be addressed by, so
      // `exposed: true` on it is a declaration that cannot be honoured — and the
      // endpoint says so while the application is wiring itself up, rather than
      // publishing something and discovering at request time that there is
      // nothing behind it.
      expect(
        () => TomFileSlots.register(
          _AnnotationsOnlyRepository<FixtureUnmappedFileRecord>(),
        ),
        throwsA(
          isA<TomFileSlotException>().having(
            (e) => e.key,
            'key',
            'file_endpoint.entity_not_mapped',
          ),
        ),
      );
      // Nothing was published under any plausible name for it.
      expect(TomFileSlots.slots, isEmpty);
      expect(
        TomFileSlots.resolve('FixtureUnmappedFileRecord', 'attachment'),
        isNull,
      );
      expect(TomFileSlots.resolve('fixture_unmapped_file', 'attachment'),
          isNull);
    });

    group('the ambiguity guard behind the default-closed rule', () {
      // The `exposed: false` default is only as strong as this guard. A slot
      // serves its column by handing the column's *declared* name to the
      // repository, and the repository resolves a file field by declared name
      // **or** mapped column name, first match wins. So a closed column mapped
      // to the *declared* name of an exposed one answers in the exposed one's
      // place, and a caller reaches closed bytes through a slot that never
      // named them. `FixtureAmbiguousSlotRecord` is built to be exactly that
      // shape.

      test('a closed column would answer in the exposed column\'s place', () {
        // The premise, asserted rather than assumed — otherwise the guard below
        // is a test of an arbitrary rule instead of a test of a defence. This
        // repeats `TomSqlDatasourceRepository._fileColumn` verbatim: the same
        // list, the same order, the same first-match-wins predicate.
        final columns = TomAnnotationAnalyzer.findFileColumns(
          FixtureAmbiguousSlotRecord,
        );
        final exposed = columns.singleWhere(
          (column) => column.fileReference!.exposed,
        );
        final resolved = columns.firstWhere(
          (column) =>
              column.declaredName == exposed.declaredName ||
              column.getQueryFieldName() == exposed.declaredName,
        );
        expect(
          resolved.declaredName,
          'notes',
          reason: 'the field name the exposed slot would pass to the '
              'repository resolves to the closed column, so registering this '
              'entity would put closed bytes behind an open slot',
        );
        expect(resolved.fileReference!.exposed, isFalse);
      });

      test('registration is refused with ambiguous_slot', () {
        expect(
          () => TomFileSlots.register(
            _AnnotationsOnlyRepository<FixtureAmbiguousSlotRecord>(),
          ),
          throwsA(
            isA<TomFileSlotException>()
                .having((e) => e.key, 'key', 'file_endpoint.ambiguous_slot')
                .having(
                  (e) => e.parameters?['name'],
                  'the colliding name',
                  'dossier',
                ),
          ),
        );
      });

      test('the closed column is unreachable through any slot', () {
        // The assertion that matters. `ambiguous_slot` firing is only useful if
        // it leaves nothing published — a guard that threw *after* registering
        // the exposed column would have opened the hole it was written to
        // close. So: every name either column answers to resolves to no slot,
        // and the entity contributes nothing to the registry.
        expect(
          () => TomFileSlots.register(
            _AnnotationsOnlyRepository<FixtureAmbiguousSlotRecord>(),
          ),
          throwsA(isA<TomFileSlotException>()),
        );
        for (final name in [
          'dossier', // the collision itself
          'notes', // the closed column's declared name
          'public_dossier', // the exposed column's slot name
        ]) {
          expect(
            TomFileSlots.resolve('fixture_ambiguous_slot', name),
            isNull,
            reason: 'a rejected entity published the slot "$name"',
          );
        }
        expect(TomFileSlots.slots, isEmpty);
      });

      test('a sound entity registered alongside it is unaffected', () {
        // The guard is per entity, not a global kill switch: rejecting one
        // registration must not cost an application the slots it registered
        // correctly, or the safe response to an ambiguity would be to stop
        // serving files at all.
        TomFileSlots.register(_MemoryFileRepository());
        expect(
          () => TomFileSlots.register(
            _AnnotationsOnlyRepository<FixtureAmbiguousSlotRecord>(),
          ),
          throwsA(isA<TomFileSlotException>()),
        );
        expect(
          TomFileSlots.slots,
          unorderedEquals([
            'fixture_file_slot/poster',
            'fixture_file_slot/graded_poster',
          ]),
        );
      });
    });
  });

  group('the endpoint over a real socket', () {
    late _MemoryFileRepository repository;
    late HttpServer server;
    late TomHttpFileTransferClient client;

    /// Boots the reflected router behind a real HTTP server and points a real
    /// client at it. [grades] seeds the C-4 resolver the fake repository reads;
    /// [outOfScope] and [writeScopeRefused] seed its C-3 row scope.
    ///
    /// Row 2 is seeded alongside row 1 so a scope test has a row to *exclude*
    /// while row 1 stays reachable — without it, "excluded" and "the repository
    /// is empty" would be the same experiment.
    Future<void> start({
      Map<String, TomAuthState> grades = const {},
      Set<int> outOfScope = const {},
      Set<int> writeScopeRefused = const {},
      bool loseStoredBlob = false,
    }) async {
      TomBean.resetBeanContext();
      TomFileSlots.reset();
      TomBlobStoreInfo.stores.clear();
      TomBlobStoreInfo.register('files', TomMemoryBlobStore(), asDefault: true);

      repository = _MemoryFileRepository(
        grades: grades,
        outOfScope: outOfScope,
        writeScopeRefused: writeScopeRefused,
        loseStoredBlob: loseStoredBlob,
      );
      repository.rows[1] = FixtureFileSlotRecord()
        ..id = 1
        ..title = 'a row that exists';
      repository.rows[2] = FixtureFileSlotRecord()
        ..id = 2
        ..title = 'a row that belongs to someone else';
      TomFileSlots.register(repository);

      // The fixture service needs its bean; TomFileServer deliberately does not
      // get one, because a framework-shipped component with a no-argument
      // constructor must not force every application to register it.
      TomBean.withType(FixtureApiServer, FixtureApiServer());
      final router = TomEndpointRouting().initializeRouter();
      final handler = Pipeline()
          .addMiddleware(
            contextSetupMiddleware('file endpoint test', {
              TomRequestLogInfo.contextName: TomRequestLogInfo(),
            }),
          )
          .addHandler(router.call);
      server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, 0);
      client = TomHttpFileTransferClient(
        baseUri: Uri.parse('http://127.0.0.1:${server.port}/files'),
        includeBearerAuthentication: false,
      );
    }

    tearDown(() async {
      client.close();
      await server.close(force: true);
      TomBean.resetBeanContext();
      TomFileSlots.reset();
      TomBlobStoreInfo.stores.clear();
    });

    test('upload, describe, download and delete round-trip over HTTP', () async {
      await start();
      const slot = 'fixture_file_slot/1/poster';
      final payload = utf8.encode('the bytes that crossed the socket');

      final uploaded = await client.upload(
        slot: slot,
        source: TomFileSource.bytes(
          'poster.txt',
          payload,
          mediaType: 'text/plain',
        ),
      );
      expect(uploaded.byteCount, payload.length);
      expect(uploaded.mediaType, startsWith('text/plain'));
      expect(uploaded.fileName, 'poster.txt');
      // The server minted the key; the client never named one.
      expect(uploaded.key, startsWith('fixture/poster/'));
      expect(repository.rows[1]!.poster, uploaded.key);

      final described = await client.describe(slot);
      expect(described, isNotNull);
      expect(described!.key, uploaded.key);
      expect(described.byteCount, payload.length);
      expect(described.fileName, 'poster.txt');

      final downloaded = <int>[];
      await for (final chunk in client.download(slot)) {
        downloaded.addAll(chunk);
      }
      expect(utf8.decode(downloaded), 'the bytes that crossed the socket');

      expect(await client.remove(slot), isTrue);
      expect(repository.rows[1]!.poster, isNull);
      expect(await client.describe(slot), isNull);
    });

    test('a re-upload replaces the file and mints a new key', () async {
      await start();
      const slot = 'fixture_file_slot/1/poster';
      final first = await client.upload(
        slot: slot,
        source: TomFileSource.bytes('a.txt', utf8.encode('first')),
      );
      final second = await client.upload(
        slot: slot,
        source: TomFileSource.bytes('b.txt', utf8.encode('second version')),
      );
      expect(second.key, isNot(first.key));
      expect(second.byteCount, 'second version'.length);
      expect(repository.rows[1]!.poster, second.key);
    });

    test('a non-exposed column is unreachable', () async {
      await start();
      const slot = 'fixture_file_slot/1/internal_notes';
      // The column exists, holds files, and is addressable by the repository —
      // it is simply not published, and the endpoint will not admit it exists.
      //
      // A *read* is indistinguishable from an empty slot on purpose: the wire
      // contract makes 404 mean "no file", so `describe` reports null rather
      // than raising. That is the right answer to give a caller — telling them
      // apart would be telling them the column is there. The raw response below
      // is what proves the server never resolved a slot at all.
      expect(await client.describe(slot), isNull);
      final head = await _raw(server.port, 'HEAD', '/files/$slot');
      expect(head.statusCode, 404);

      // A *write* has no such ambiguity: there is nothing to write to, and the
      // client surfaces it.
      await expectLater(
        client.upload(
          slot: slot,
          source: TomFileSource.bytes('leak.txt', utf8.encode('nope')),
        ),
        throwsA(isA<TomFileTransferException>()),
      );
      final response = await _raw(server.port, 'GET', '/files/$slot');
      expect(response.statusCode, 404);
      expect(
        jsonDecode(await response.transform(utf8.decoder).join())['key'],
        'file_endpoint.unknown_slot',
      );
      // …and nothing was stored under it.
      expect(repository.rows[1]!.internalNotes, isNull);
    });

    test('an exposed but C-4 refused column answers 403, not 404', () async {
      await start(
        grades: {'fixture.file_slot.graded_poster': TomAuthState.none},
      );
      final response = await _raw(
        server.port,
        'GET',
        '/files/fixture_file_slot/1/graded_poster',
      );
      expect(response.statusCode, 403);
      expect(
        jsonDecode(await response.transform(utf8.decoder).join())['key'],
        'column_authorization.read.field_forbidden',
      );
    });

    test('an exposed column the caller may read but not write refuses the '
        'upload with 403', () async {
      await start(
        grades: {'fixture.file_slot.graded_poster': TomAuthState.read},
      );
      final response = await _raw(
        server.port,
        'POST',
        '/files/fixture_file_slot/1/graded_poster',
        body: utf8.encode('denied'),
      );
      expect(response.statusCode, 403);
      expect(
        jsonDecode(await response.transform(utf8.decoder).join())['key'],
        'column_authorization.write.field_forbidden',
      );
    });

    test('a row that does not exist answers 404', () async {
      await start();
      final response = await _raw(
        server.port,
        'GET',
        '/files/fixture_file_slot/99/poster',
      );
      expect(response.statusCode, 404);
    });

    group('a row outside the caller\'s data scope (C-3)', () {
      // The counterpart of the C-4 group's "403, not 404". Here the answer must
      // go the *other* way, and the reason is the addressing scheme: a slot is
      // `<table>/<id>/<column>` with the id supplied by the caller. A 403 would
      // confirm that a guessed id names a real row owned by someone else — the
      // existence of the row is itself the disclosure. So the endpoint must
      // answer an out-of-scope row exactly as it answers an absent one.

      /// Row 2 exists in the repository but the scope excludes it.
      const hidden = '/files/fixture_file_slot/2/poster';

      /// An id no row has, reachable by nobody.
      const absent = '/files/fixture_file_slot/99/poster';

      test('a download answers 404, not 403', () async {
        await start(outOfScope: {2});
        final response = await _raw(server.port, 'GET', hidden);
        expect(response.statusCode, 404, reason: '403 would confirm the row');
        // `file_endpoint.no_file`, not the repository's `row_not_found`: a
        // download resolves the descriptor first, and a hidden row describes as
        // `null` exactly as a row holding no file does. The endpoint therefore
        // conflates the two even harder than the repository does — which is the
        // direction to err in, since the wire contract already defines 404 as
        // "no file here" and says nothing about why.
        expect(
          jsonDecode(await response.transform(utf8.decoder).join())['key'],
          'file_endpoint.no_file',
        );
      });

      test('an upload answers 404, not 403', () async {
        await start(outOfScope: {2});
        final response = await _raw(
          server.port,
          'POST',
          hidden,
          body: utf8.encode('written to a row that is not mine'),
        );
        expect(response.statusCode, 404);
        // And the write did not happen: the row the caller could not see is
        // exactly as it was.
        expect(repository.rows[2]!.poster, isNull);
      });

      test('a HEAD and a DELETE answer 404 too', () async {
        await start(outOfScope: {2});
        expect((await _raw(server.port, 'HEAD', hidden)).statusCode, 404);
        expect((await _raw(server.port, 'DELETE', hidden)).statusCode, 404);
      });

      test('every method answers a hidden row exactly as it answers an absent '
          'one', () async {
        // The property that makes the status codes above load-bearing. If any
        // method distinguished the two, a caller could enumerate other
        // principals' row ids by probing — which is the breach, whatever status
        // code the distinguishing answer happens to carry.
        await start(outOfScope: {2});
        for (final method in ['GET', 'HEAD', 'DELETE']) {
          final onHidden = await _raw(server.port, method, hidden);
          final onAbsent = await _raw(server.port, method, absent);
          expect(
            onHidden.statusCode,
            onAbsent.statusCode,
            reason: '$method distinguishes a hidden row from an absent one',
          );
        }
        final uploadHidden = await _raw(
          server.port,
          'POST',
          hidden,
          body: utf8.encode('probe'),
        );
        final uploadAbsent = await _raw(
          server.port,
          'POST',
          absent,
          body: utf8.encode('probe'),
        );
        expect(uploadHidden.statusCode, uploadAbsent.statusCode);
      });

      test('a repository that names the write refusal is mapped to 404, not '
          'left to the generic handler', () async {
        // The write half of the `TomFileRepository` contract. A scoped read
        // filters the row away, so the refusal above arrived as `row_not_found`
        // and the endpoint never saw a scope exception at all. An
        // implementation whose write gate is stricter than its read gate raises
        // `TomDataScopeAuthorizationException` instead — and without a clause
        // for it that escapes to the pipeline's generic handler as a 500, which
        // is distinguishable from a 404 and so is itself the leak this whole
        // group exists to close.
        await start(writeScopeRefused: {2});
        final response = await _raw(
          server.port,
          'POST',
          hidden,
          body: utf8.encode('refused at the write gate'),
        );
        expect(response.statusCode, 404);
        expect(
          jsonDecode(await response.transform(utf8.decoder).join())['key'],
          'data_scope.write.out_of_scope',
        );
        expect(repository.rows[2]!.poster, isNull);
      });
    });

    test('a key that is not the entity key answers 400', () async {
      await start();
      final response = await _raw(
        server.port,
        'GET',
        '/files/fixture_file_slot/not-a-number/poster',
      );
      expect(response.statusCode, 400);
      expect(
        jsonDecode(await response.transform(utf8.decoder).join())['key'],
        'file_endpoint.invalid_id',
      );
    });

    test('HEAD answers from the descriptor without a body', () async {
      await start();
      const slot = 'fixture_file_slot/1/poster';
      await client.upload(
        slot: slot,
        source: TomFileSource.bytes(
          'h.txt',
          utf8.encode('head me'),
          mediaType: 'text/plain',
        ),
      );
      final response = await _raw(
        server.port,
        'HEAD',
        '/files/fixture_file_slot/1/poster',
      );
      expect(response.statusCode, 200);
      // The descriptor travels whole in x-tom-file, which is what makes the
      // content-length a HEAD cannot carry unnecessary.
      final descriptor = jsonDecode(response.headers.value('x-tom-file')!);
      expect(descriptor['byteCount'], 'head me'.length);
      expect(descriptor['fileName'], 'h.txt');
    });

    test('deleting a slot that holds no file answers 404', () async {
      await start();
      final response = await _raw(
        server.port,
        'DELETE',
        '/files/fixture_file_slot/1/poster',
      );
      expect(response.statusCode, 404);
    });

    test('PUT uploads exactly as POST does', () async {
      // `PUT` is a declared method of the endpoint and the handler routes it to
      // the same upload as `POST` — a file slot is a single resource whose
      // content is replaced whole, so "create" and "replace" are not two
      // operations here. Declared but never exercised, the two could have drifted
      // apart without anything noticing.
      await start();
      const slot = 'fixture_file_slot/1/poster';
      final response = await _raw(
        server.port,
        'PUT',
        '/files/$slot',
        body: utf8.encode('put across the socket'),
      );
      expect(response.statusCode, 201);
      final descriptor = jsonDecode(await response.transform(utf8.decoder).join());
      expect(descriptor['byteCount'], 'put across the socket'.length);
      expect(repository.rows[1]!.poster, descriptor['key']);

      final downloaded = <int>[];
      await for (final chunk in client.download(slot)) {
        downloaded.addAll(chunk);
      }
      expect(utf8.decode(downloaded), 'put across the socket');
    });

    test('a method the endpoint does not declare never reaches it', () async {
      // The first of the two gates on the method. `@TomEndpoint.methods` lists
      // five verbs and the router mounts one route per verb, so a `PATCH` never
      // matches a route and the handler is not entered at all — the answer is
      // the router's 404, not the handler's 405. Asserted so that the 405 test
      // below is understood for what it is: the handler's *own* guard, for a
      // handler mounted more widely than the framework mounts it.
      await start();
      final response = await _raw(
        server.port,
        'PATCH',
        '/files/fixture_file_slot/1/poster',
        body: utf8.encode('patched'),
      );
      expect(response.statusCode, 404);
    });

    test('a stored file the store cannot answer for is not silently a success',
        () async {
      // The row took the key and the store lost the bytes. `saveFile` reported
      // success, so the upload cannot simply be failed as a client error — but
      // neither may it be reported as stored, because the descriptor the client
      // is owed does not exist. The endpoint names the disagreement instead of
      // dereferencing the `null` it got back.
      await start(loseStoredBlob: true);
      final slot = TomFileSlots.resolve('fixture_file_slot', 'poster')!;
      await expectLater(
        slot.upload('1', Stream.value(utf8.encode('bytes that will vanish'))),
        throwsA(
          isA<TomFileSlotException>().having(
            (e) => e.key,
            'key',
            'file_endpoint.stored_file_not_readable',
          ),
        ),
      );
      // The row is left holding the key it was given — the endpoint reports the
      // inconsistency, it does not paper over it by clearing the column, which
      // would destroy the only evidence of what the store lost.
      expect(repository.rows[1]!.poster, isNotNull);
    });

    test('a lost blob surfaces as a server fault, not as a 404', () async {
      // Over the wire the same case must *not* join the 404 family. 404 tells a
      // client "there is no file here", which is a true statement about their
      // request and an invitation to move on; this is a true statement about the
      // server, and the client's request was fine. Conflating them would let a
      // storage outage be read as an empty slot and silently lose files.
      await start(loseStoredBlob: true);
      final response = await _raw(
        server.port,
        'POST',
        '/files/fixture_file_slot/1/poster',
        body: utf8.encode('bytes that will vanish'),
      );
      expect(response.statusCode, greaterThanOrEqualTo(500));
    });

    test('a large upload streams through without being buffered whole',
        () async {
      await start();
      const slot = 'fixture_file_slot/1/poster';
      // Comfortably more than one socket chunk, so the body genuinely arrives
      // in pieces and the endpoint has to hand a stream on rather than a list.
      final payload = List<int>.generate(512 * 1024, (i) => i % 251);
      final uploaded = await client.upload(
        slot: slot,
        source: TomFileSource.bytes('big.bin', payload),
      );
      expect(uploaded.byteCount, payload.length);

      var downloadedLength = 0;
      var chunks = 0;
      await for (final chunk in client.download(slot)) {
        downloadedLength += chunk.length;
        chunks++;
      }
      expect(downloadedLength, payload.length);
      expect(chunks, greaterThan(0));
    });
  });

  group('the handler mounted on its own', () {
    // `TomFileEndpoint.handle` is public and stateless, and an application may
    // mount it itself — behind its own auth, at its own path, or on a route that
    // matches every method. Mounted that way it is the only thing standing
    // between an unsupported verb and the switch's fall-through, so its method
    // guard is its own contract and not a restatement of `@TomEndpoint.methods`.
    // This group mounts it on a catch-all route, which is the only way the 405
    // branch is reachable at all.

    late HttpServer server;

    setUp(() async {
      TomFileSlots.reset();
      TomBlobStoreInfo.stores.clear();
      TomBlobStoreInfo.register('files', TomMemoryBlobStore(), asDefault: true);
      TomFileSlots.register(_MemoryFileRepository());
      final router = Router()
        ..all('/files/<entity>/<id>/<column>', TomFileEndpoint.handle);
      server = await shelf_io.serve(router.call, InternetAddress.loopbackIPv4, 0);
    });

    tearDown(() async {
      await server.close(force: true);
      TomFileSlots.reset();
      TomBlobStoreInfo.stores.clear();
    });

    for (final method in ['PATCH', 'OPTIONS', 'TRACE']) {
      test('$method on a real slot answers 405', () async {
        final response = await _raw(
          server.port,
          method,
          '/files/fixture_file_slot/1/poster',
        );
        expect(response.statusCode, 405);
        expect(
          jsonDecode(await response.transform(utf8.decoder).join())['key'],
          'file_endpoint.method_not_allowed',
        );
      });
    }

    test('an unsupported method on an unknown slot is still 404', () async {
      // Slot resolution runs before the method switch, and it must: answering
      // 405 here would tell a caller that `secret_column` is a slot they merely
      // used the wrong verb on. "That method is not supported *for a file slot*"
      // presumes a file slot.
      final response = await _raw(
        server.port,
        'PATCH',
        '/files/fixture_file_slot/1/internal_notes',
      );
      expect(response.statusCode, 404);
      expect(
        jsonDecode(await response.transform(utf8.decoder).join())['key'],
        'file_endpoint.unknown_slot',
      );
    });
  });
}

/// Issues a raw request, bypassing the client, so a status code the client
/// turns into an exception can be asserted directly.
Future<HttpClientResponse> _raw(
  int port,
  String method,
  String path, {
  List<int>? body,
}) async {
  final http = HttpClient();
  try {
    final request = await http.open(method, '127.0.0.1', port, path);
    if (body != null) {
      request.headers.contentType = ContentType('application', 'octet-stream');
      request.add(body);
    }
    return await request.close();
  } finally {
    http.close();
  }
}
