/// The live proof that files move end to end across both servers — and that a
/// file column which never said `exposed: true` is unreachable over HTTP.
///
/// Everything else about the file feature is asserted without a socket: the
/// annotations are read by the unit suites, the DDL by the two convergence
/// tests, the mapping by the persistence tests. What none of them can show is
/// the part that only exists when the whole stack is running — that a byte
/// stream posted by a client lands in a blob store, that the row's key column is
/// updated, and that a later `GET` hands the same bytes back. That is a claim
/// about six layers agreeing at once (client → endpoint → repository → column
/// grade → blob store → database), and the only honest way to make it is to run
/// them.
///
///  - [TC-FT-01] **the app server stores and serves an item attachment.** `alice`
///    uploads to `app_items/1/attachment`, the descriptor comes back with the
///    size and media type she sent, `HEAD` reports the same without transferring
///    anything, `GET` returns the identical bytes, and `DELETE` empties the slot.
///    The lifecycle is walked in full rather than stopping at the round-trip
///    because the delete is what leaves `app_db` as seeded, so the test is
///    re-runnable.
///  - [TC-FT-02] **the auth server does the same for a user avatar** at
///    `auth_users/2/avatar_ref` — a *second* server, a *second* database, a
///    *second* blob store. The two are deliberately separate configurations
///    (`datasource: app_db` and `datasource: auth_db`), so a single passing
///    round-trip on one of them would prove nothing about the other.
///  - [TC-FT-03] **the non-exposed column is not addressable.** `internal_note`
///    is a `@TomFileReference` column of the *same row* as `attachment` and says
///    nothing about `exposed`. The contrast is made at one moment, by one
///    principal, against one row that demonstrably has a reachable file column:
///    `attachment` describes, `internal_note` does not exist, and a write to it
///    is refused. This is the framework's default-closed rule — reaching a file
///    over HTTP is opted into per column, never inherited from the row — and it
///    is the single most important thing in this file, because the failure it
///    guards against is silent: a column that becomes reachable by accident
///    looks exactly like one that was always meant to be.
///  - [TC-FT-04] **an unauthenticated caller is refused at the gate**, on both
///    servers and in both directions. This is the assertion the other three
///    cannot make: they all run as `alice`, and every protection *below* the
///    gate is principal-relative — row scope decides which rows a principal may
///    have, column grade which columns, and neither is asked anything by a
///    request that carries no principal at all. `auth_users` declares no
///    `@TomDbScope`, so without the endpoint's own
///    [TomAuthenticatedAccess] an avatar would be readable by anyone; the test
///    reads exactly that slot.
///
///  - [TC-FT-05] **the file endpoint under the sample's four-role matrix.**
///    `carol` holds a `viewer` share on project 1, and the auth server's
///    `tom_resource_grant` matrix grades that role `read` on
///    `todo.item.attachment`. She downloads the file alice uploaded and is
///    **refused the upload and the delete**. This is the assertion that joins
///    the file feature to the sample's existing thesis: the grade is not a
///    second, file-specific permission model but *the same grant row* that makes
///    her `status` field read-only on the board, resolved per row at the file
///    endpoint. An administrator narrowing that row through the authadmin
///    console changes this outcome without touching a line of either server —
///    which is exactly what `run_cross_tier_integration.sh` then does live.
///
/// **404, 403 and the three different questions.** The endpoint answers a
/// refusal differently depending on which layer refused, and TC-FT-03/04/05 pin
/// one each:
///
///  - **Exposure** (TC-FT-03) is asked while resolving the slot, before any
///    principal is considered. [TomFileSlots.resolve] returns `null` for a
///    column that is merely closed just as it does for one that does not exist,
///    and the endpoint answers both with a plain **404** — for everybody
///    equally, the row's own owner included. A 403 would confirm the column is
///    there, the same reasoning that makes the framework map an out-of-scope row
///    to 404 rather than admitting the row exists.
///  - **Authentication** (TC-FT-04) is asked at the endpoint gate: no principal
///    at all → **403**.
///  - **The column grade** (TC-FT-05) is asked per row and per principal, once
///    the slot is known and the caller is known: the slot exists and this caller
///    may see it but not write it → **403**.
///
/// **Identity.** [TomBearerAuthentication] is a single global token store and
/// the transfer client reads it, so logging in through [AuthClient] is all a
/// transfer needs to be authenticated; each test resets the store around itself.
///
/// Needs both servers *and* their databases up (see
/// `tool/run_cross_tier_integration.sh`, which boots the stack and runs this
/// suite alongside the cross-tier one). As with those tests, an unreachable
/// server **skips** rather than fails — the socket-free suites carry the
/// always-on coverage.
library;

import 'dart:convert';
import 'dart:io';

import 'package:advanced_client_core/advanced_client_core.dart';
import 'package:advanced_client_core/reflection_seed.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:test/test.dart';

const _appBaseUri = 'http://localhost:8080';
const _authBaseUri = 'http://localhost:8081';

final _aliceLogin = LoginRequest(username: 'alice', password: 'alice-pass');

/// Carol holds a `viewer` share on project 1 (the `app_db` `[000]` seed's C-6
/// delegation), so item 1 is inside her row scope and her seeded attachment
/// grade is `read` — the principal TC-FT-05 needs.
final _carolLogin = LoginRequest(username: 'carol', password: 'carol-pass');

/// Slots addressed below, as `<table>/<id>/<column>`.
///
/// Item 1 sits in alice's workspace (the `app_db` `[000]` seed) so the row scope
/// lets her reach it; user 2 *is* alice (the `auth_db` `[003]` demo seed).
const _attachmentSlot = 'app_items/1/attachment';
const _internalNoteSlot = 'app_items/1/internal_note';
const _avatarSlot = 'auth_users/2/avatar_ref';

void main() {
  setUpAll(initializeReflection);

  group('file transfer (live auth + app servers)', () {
    setUp(() => TomBearerAuthentication.bearerAuthentication =
        TomBearerAuthentication());
    tearDown(() => TomBearerAuthentication.bearerAuthentication =
        TomBearerAuthentication());

    test(
        'TC-FT-01: the app server stores, describes, serves and clears an item '
        'attachment', () async {
      final c = _liveClients();
      final files = ioFileTransferClient(Uri.parse(_appBaseUri));
      try {
        expect((await c.app.health())['status'], equals('ok'));
        await c.auth.login(_aliceLogin);

        final bytes = utf8.encode('advanced sample attachment payload');
        final stored = await files.upload(
          slot: _attachmentSlot,
          // The media type is stated rather than left to
          // `TomFileSource.guessMediaType`: the framework's extension table is
          // for serving static assets and knows nothing of `.txt`, so a guess
          // here would assert the table's contents instead of the thing that
          // matters — that the type the client *declares* is the type the
          // server stores and hands back.
          source: TomFileSource.bytes('attachment.txt', bytes,
              mediaType: 'text/plain'),
        );
        expect(stored.byteCount, equals(bytes.length));
        expect(stored.mediaType, startsWith('text/plain'));
        expect(stored.key, isNotEmpty,
            reason: 'the server generates the storage key the row now holds');

        // HEAD: the same facts without moving the file, which is the whole point
        // of describe existing next to download.
        final described = await files.describe(_attachmentSlot);
        expect(described, isNotNull);
        expect(described!.byteCount, equals(bytes.length));
        expect(described.key, equals(stored.key));
        expect(described.mediaType, startsWith('text/plain'),
            reason: 'the type is persisted with the blob, not merely echoed '
                'back by the upload response');

        expect(await _downloadAll(files, _attachmentSlot), equals(bytes),
            reason: 'the bytes served back are the bytes uploaded');

        expect(await files.remove(_attachmentSlot), isTrue);
        expect(await files.describe(_attachmentSlot), isNull,
            reason: 'the delete empties the slot, leaving app_db as seeded');
      } on SocketException catch (e) {
        markTestSkipped(_skipMessage(e));
        return;
      } finally {
        files.close();
        c.transport.close();
      }
    });

    test(
        'TC-FT-02: the auth server stores and serves a user avatar from its own '
        'database and blob store', () async {
      final c = _liveClients();
      final files = ioFileTransferClient(Uri.parse(_authBaseUri));
      try {
        expect((await c.app.health())['status'], equals('ok'));
        await c.auth.login(_aliceLogin);

        final bytes = utf8.encode('advanced sample avatar payload');
        final stored = await files.upload(
          slot: _avatarSlot,
          source: TomFileSource.bytes('avatar.txt', bytes),
        );
        expect(stored.byteCount, equals(bytes.length));

        expect(await _downloadAll(files, _avatarSlot), equals(bytes),
            reason: 'the second server serves its own files from auth_db');

        // Cleared for the same re-runnability reason as TC-FT-01. Note this is
        // the HTTP clear (the column and its bytes), not a row delete — the
        // `cascadeDelete: false` contrast this column exists to teach is about
        // what happens when the *user row* goes, which no HTTP call here does.
        expect(await files.remove(_avatarSlot), isTrue);
        expect(await files.describe(_avatarSlot), isNull);
      } on SocketException catch (e) {
        markTestSkipped(_skipMessage(e));
        return;
      } finally {
        files.close();
        c.transport.close();
      }
    });

    test(
        'TC-FT-03: a file column that never said `exposed` is not addressable, '
        'while its neighbour on the same row is', () async {
      final c = _liveClients();
      final files = ioFileTransferClient(Uri.parse(_appBaseUri));
      var uploaded = false;
      try {
        expect((await c.app.health())['status'], equals('ok'));
        await c.auth.login(_aliceLogin);

        // The control: this principal, this row, this moment — a file column
        // that *is* exposed answers. Without it a 404 on the neighbour would be
        // consistent with the server simply being unable to see the row.
        await files.upload(
          slot: _attachmentSlot,
          source: TomFileSource.bytes(
            'attachment.txt',
            utf8.encode('reachable neighbour'),
          ),
        );
        uploaded = true;
        expect(await files.describe(_attachmentSlot), isNotNull);

        // The closed column: absent, not forbidden — and the distinction is the
        // lesson. `exposed` decides *which column a slot names*, never whether
        // this caller may have it: it is consulted while resolving the slot,
        // before any principal is looked at, so an unexposed column resolves to
        // nothing and the request 404s for everybody equally — alice, who owns
        // the row and is graded `full` on its neighbour, included. That is why
        // the answer here is "no such slot" and not "not for you": there is no
        // authorization question to ask about a column that HTTP cannot name.
        // The principal-relative refusals live one layer down and are asserted
        // by TC-FT-04 (no principal → 403) and TC-FT-05 (a read grade → 403).
        expect(await files.describe(_internalNoteSlot), isNull,
            reason: 'exposure decides which column a slot names, not who may '
                'have it — so this HEAD is a 404 for the row\'s own owner, at '
                'the same moment her neighbouring column answers');

        // And the dangerous direction — a write — is refused for the same
        // reason, with the same "no such thing" answer.
        await expectLater(
          files.upload(
            slot: _internalNoteSlot,
            source: TomFileSource.bytes('note.txt', utf8.encode('nope')),
          ),
          throwsA(isA<TomFileTransferException>()
              .having((e) => e.key, 'key', 'file_transfer.not_found')),
          reason: 'the endpoint refuses to write a column nobody exposed',
        );

        expect(await _downloadAll(files, _internalNoteSlot), isNull,
            reason: 'and GET hands back no bytes either');
      } on SocketException catch (e) {
        markTestSkipped(_skipMessage(e));
        return;
      } finally {
        if (uploaded) {
          try {
            await files.remove(_attachmentSlot);
          } on SocketException {
            // Stack already down — nothing to clean up.
          }
        }
        files.close();
        c.transport.close();
      }
    });

    test('TC-FT-04: an unauthenticated caller is refused at the gate, on both '
        'servers', () async {
      final c = _liveClients();
      final appFiles = ioFileTransferClient(Uri.parse(_appBaseUri));
      final authFiles = ioFileTransferClient(Uri.parse(_authBaseUri));
      try {
        // No login: the bearer store is reset around every test in this group,
        // so these requests carry no token at all.
        expect((await c.app.health())['status'], equals('ok'),
            reason: 'the stack is up — the refusals below are the gate, not a '
                'dead socket');

        // The avatar slot is the one that matters. `auth_users` declares no
        // `@TomDbScope`, so nothing downstream of the gate would have filtered
        // this request: row scope and column grade decide *which* rows and
        // columns a principal may have, never whether there is a principal. If
        // the endpoint did not require authentication, this would return
        // somebody's avatar to anybody who asked.
        await expectLater(
          _downloadAll(authFiles, _avatarSlot),
          throwsA(isA<TomFileTransferException>()
              .having((e) => e.parameters?['statusCode'], 'statusCode', 403)),
          reason: 'an anonymous read of an unscoped entity must be refused by '
              'the endpoint itself',
        );

        // And the write direction, on the other server.
        await expectLater(
          appFiles.upload(
            slot: _attachmentSlot,
            source: TomFileSource.bytes(
              'anon.txt',
              utf8.encode('written by nobody'),
            ),
          ),
          throwsA(isA<TomFileTransferException>()
              .having((e) => e.parameters?['statusCode'], 'statusCode', 403)),
          reason: 'and an anonymous write likewise',
        );
        // Whether the refused upload *stored* anything cannot be asked
        // anonymously — that is the whole point — so it is asked as alice, who
        // may look. The slot is empty at the start of every test (TC-FT-01 and
        // TC-FT-03 both clear it), so a file here could only have come from the
        // anonymous write above.
        await c.auth.login(_aliceLogin);
        expect(await appFiles.describe(_attachmentSlot), isNull,
            reason: 'the refused upload must have stored nothing');
      } on SocketException catch (e) {
        markTestSkipped(_skipMessage(e));
        return;
      } finally {
        appFiles.close();
        authFiles.close();
        c.transport.close();
      }
    });

    test(
        'TC-FT-05: a read-only column grade serves the download and refuses the '
        'upload', () async {
      final c = _liveClients();
      final files = ioFileTransferClient(Uri.parse(_appBaseUri));
      var uploaded = false;
      try {
        expect((await c.app.health())['status'], equals('ok'));

        // Alice owns the tree, is graded `full` on the attachment, and puts a
        // file in the slot for carol to find.
        await c.auth.login(_aliceLogin);
        final bytes = utf8.encode('alice uploaded this, carol may only read it');
        await files.upload(
          slot: _attachmentSlot,
          source: TomFileSource.bytes('shared.txt', bytes,
              mediaType: 'text/plain'),
        );
        uploaded = true;

        // Now carol. Her share on project 1 is `viewer`, which the auth seed
        // grades `read` on `todo.item.attachment` — so the app server's per-row
        // resolver folds "carol's role on *this item*" with "that role's grant"
        // and reaches `read`.
        await c.auth.login(_carolLogin);

        // `read` means showsContent: the two read verbs answer, in full.
        final described = await files.describe(_attachmentSlot);
        expect(described, isNotNull,
            reason: 'the grade is read, not none — carol is not being hidden '
                'from the file, she is being denied the write');
        expect(described!.byteCount, equals(bytes.length));
        expect(await _downloadAll(files, _attachmentSlot), equals(bytes),
            reason: 'a read grade serves the bytes, not a redacted stand-in');

        // `read` means !isInteractive: the two write verbs are refused, with the
        // *forbidden* answer rather than the *absent* one. The distinction from
        // TC-FT-03 is the whole point of this test — there the slot did not
        // exist for anybody (404); here it exists, carol may see it, and the
        // refusal is about her grade on it (403).
        await expectLater(
          files.upload(
            slot: _attachmentSlot,
            source: TomFileSource.bytes('carol.txt', utf8.encode('overwrite')),
          ),
          throwsA(isA<TomFileTransferException>()
              .having((e) => e.parameters?['statusCode'], 'statusCode', 403)),
          reason: 'the same four-role matrix that makes a field read-only makes '
              'this file column read-only — one grant row, both effects',
        );
        await expectLater(
          files.remove(_attachmentSlot),
          throwsA(isA<TomFileTransferException>()
              .having((e) => e.parameters?['statusCode'], 'statusCode', 403)),
          reason: 'clearing is a write too; a grade that refuses the replace '
              'must refuse the delete, or the read-only file could still be '
              'destroyed',
        );

        // And the refusals stored nothing: the bytes alice uploaded are intact.
        expect(await _downloadAll(files, _attachmentSlot), equals(bytes),
            reason: 'both refusals happened before the blob store was touched');
      } on SocketException catch (e) {
        markTestSkipped(_skipMessage(e));
        return;
      } finally {
        if (uploaded) {
          try {
            // Cleared as alice — carol demonstrably cannot, which is the point.
            await c.auth.login(_aliceLogin);
            await files.remove(_attachmentSlot);
          } on SocketException {
            // Stack already down — nothing to clean up.
          }
        }
        files.close();
        c.transport.close();
      }
    });
  });
}

/// Every byte [slot] serves, or `null` when the slot holds no file.
///
/// Buffered deliberately: these payloads are a few dozen bytes, and comparing
/// the whole thing is the assertion. Production code streams instead — which is
/// exactly why [TomFileTransferClient.download] returns a stream and this helper
/// has to do the collecting.
Future<List<int>?> _downloadAll(
  TomFileTransferClient files,
  String slot,
) async {
  final received = <int>[];
  try {
    await for (final chunk in files.download(slot)) {
      received.addAll(chunk);
    }
  } on TomFileTransferException catch (e) {
    if (e.key == 'file_transfer.not_found') return null;
    rethrow;
  }
  return received;
}

String _skipMessage(SocketException e) =>
    'auth/app server not reachable on $_authBaseUri/$_appBaseUri — run '
    'tool/run_cross_tier_integration.sh (or start both servers + their '
    'databases) to run this end-to-end test ($e)';

/// One live transport plus the auth and app clients that share it.
///
/// The app client is here only for its health check — the file transfers go
/// through [TomHttpFileTransferClient], which speaks the byte contract rather
/// than the JSON one and therefore carries its own connection.
({IoJsonTransport transport, AuthClient auth, AppApiClient app})
    _liveClients() {
  final transport = IoJsonTransport();
  final auth = AuthClient(Uri.parse(_authBaseUri), transport: transport);
  return (
    transport: transport,
    auth: auth,
    app: AppApiClient(
      Uri.parse(_appBaseUri),
      AuthorizedHttp(transport, auth),
    ),
  );
}
