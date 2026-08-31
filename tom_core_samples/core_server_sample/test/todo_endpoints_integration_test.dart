/// Live integration test for the three public endpoints: the one artifact that
/// can fail if the server-plus-MariaDB path breaks.
///
/// Everything else in this package verifies without a database — the mapping
/// unit tests and the example both run on pure functions. That leaves the
/// sample's headline claim, "a live Tom Core backend", carried by nothing an
/// operator or a CI job could re-run: `README.md` ("The live server boot") gave
/// three `curl`s and the README asserted the result was verified, which really
/// meant *someone once typed them*. A regression in the boot sequence, the
/// migration tree or the DTO serialization would have broken the sample's whole
/// point while every green check in the repo stayed green. This file is that
/// missing check.
///
/// **It skips rather than fails when nothing is listening on
/// [_baseUri].** A developer running `dart test` on a laptop with no Docker
/// must still get a green package, so an unreachable socket is a skip. The
/// consequence is that a skip here proves nothing at all — which is exactly why
/// `tool/run_integration.sh` exists: that runner brings the database and the
/// server up itself, so under it a skip means the suite could not reach a stack
/// the script had just verified as healthy, and the runner turns it into a
/// failure. Run the runner, not this file, when you want an answer.
///
/// ```sh
/// ./tool/run_integration.sh
/// ```
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'config_assets.dart';
import 'documented_authorization.dart';

/// Where `bin/server_start.dart` binds by default (`_defaultPort`).
const _baseUri = 'http://localhost:8080';

void main() {
  group('live endpoints (running server + MariaDB)', () {
    test('GET /health reports the server booted under the dev overlay',
        () async {
      final body = await _getJsonOrSkip('/health');
      if (body == null) return;

      // Touches no database on purpose, so when this passes and the two below
      // fail, the fault is in persistence rather than in the boot.
      //
      // `app` is the *configured* title, read out of the dev overlay asset
      // rather than restated here. That makes this the end-to-end half of the
      // configuration claim: `todo_health_config_test.dart` proves `health()`
      // reads the provider, and this proves the `.env` selector, the overlay
      // merge and the provider install all survive a real boot and reach an
      // HTTP client. Both supported boots select `env=dev` — the runner writes
      // it, and the README's manual boot copies `.env.example`, which sets it —
      // so the `(DEV)` title is what a correctly booted sample serves.
      expect(
          body, equals({'status': 'ok', 'app': assetAppTitle(devConfigAsset)}));
    });

    test('GET /todos round-trips the seeded rows out of MariaDB', () async {
      final body = await _getJsonOrSkip('/todos');
      if (body == null) return;

      // A bare JSON array, not an envelope: the endpoint returns
      // `List<TodoItemDto>` and the pipeline serializes it (G-DTO). An envelope
      // appearing here would mean someone had gone back to hand-written JSON.
      expect(body, isA<List<Object?>>());
      final items = (body as List<Object?>).cast<Map<String, Object?>>();

      // The exact rows `[000]-todo_core_schema.sql` inserts. Asserting the
      // seeded *values* — not merely "some rows came back" — is what makes this
      // a persistence proof: these strings exist nowhere in Dart, so their only
      // possible route into the response is the database.
      expect(items, hasLength(2));
      expect(items[0]['title'], equals('Write the launch article'));
      expect(items[0]['priority'], equals('high'));
      expect(items[0]['label'], equals('docs'));
      expect(items[1]['title'], equals('Fix the nav contrast bug'));
      expect(items[1]['priority'], equals('critical'));
      expect(items[1]['label'], equals('bug'));

      // The reflected `TodoItemDto` shape, named field by field. The mapping
      // unit tests cover the domain ↔ record half; nothing but a live request
      // covers record → DTO → wire, and a renamed or dropped field there is
      // invisible to every other check in the package.
      expect(
          items.first.keys,
          containsAll(<String>[
            'id',
            'title',
            'description',
            'done',
            'priority',
            'label',
            'assigneeId',
            'dueDate',
            'listId',
          ]));

      // Unset foreign keys travel as empty strings rather than JSON null —
      // `_recordToDto`'s deliberate choice, and the one the client sample reads.
      expect(items.first['assigneeId'], equals(''));
      expect(items.first['listId'], equals('1'));
    });

    test('GET /todos/field-states returns exactly the matrix the README prints',
        () async {
      final body = await _getJsonOrSkip('/todos/field-states');
      if (body == null) return;

      // The README does not merely *say* this endpoint works — it prints the
      // response. That printed block is a claim about the running system in the
      // same shape as every other document claim in this package, so it is
      // checked the same way: the documented JSON is decoded and used as the
      // expectation. Re-grading a field in `[001]-todo_authz_grants.sql` now
      // fails here until the README is updated to match, instead of leaving the
      // document quietly wrong.
      expect(body, equals(documentedFieldStates()));

      // Stated separately because the round-trip above would still pass if both
      // the migration and the README lost a state: all four `TomAuthState`
      // tokens must be visible, which is the sample's teaching point.
      final states = ((body as Map<String, Object?>)['states']!
              as Map<String, Object?>)
          .values
          .expand((role) => (role! as Map<String, Object?>).values)
          .toSet();
      expect(states, equals(<String>{'full', 'read', 'disabled', 'none'}));
    });
  });
}

/// GETs [path] and decodes the JSON body, or calls [markTestSkipped] and returns
/// `null` when the server is not listening.
///
/// Extracted because all three tests need the identical
/// request-or-skip behaviour; inlining it would put the same `try`/`on
/// SocketException` block in each, and a skip message that drifted between them
/// would be the first thing to mislead whoever hits it.
Future<Object?> _getJsonOrSkip(String path) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse('$_baseUri$path'));
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    expect(response.statusCode, equals(200),
        reason: 'GET $path returned ${response.statusCode}: $text');
    return jsonDecode(text);
  } on SocketException catch (e) {
    markTestSkipped(
        'no server on $_baseUri — start the stack with ./tool/run_integration.sh '
        '(or `docker compose up -d db && dart run bin/server_start.dart`) to run '
        'this integration test ($e)');
    return null;
  } finally {
    client.close(force: true);
  }
}

