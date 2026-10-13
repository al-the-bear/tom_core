/// The generated clients against the running servers: a login through the
/// generated `AuthApi`, then calls through the generated `AppApi` carrying the
/// token it returned.
///
/// Live only — `tool/run_cross_tier_integration.sh` in `advanced_client_core`
/// starts both servers and both databases and runs this suite; a run that
/// finds no server reports every test skipped, which that script counts as a
/// failure.
library;

import 'dart:convert';
import 'dart:io';

import 'package:advanced_openapi_client/app_api.dart';
import 'package:advanced_openapi_client/auth_api.dart' as auth;
import 'package:test/test.dart';

final _appBaseUri = Uri.parse('http://localhost:8080');
final _authBaseUri = Uri.parse('http://localhost:8081');

/// Runs [body], skipping the test when the servers are not running.
Future<void> _live(Future<void> Function() body) async {
  try {
    await body();
  } on SocketException catch (e) {
    markTestSkipped(
      'servers not reachable — start them with '
      'advanced_client_core/tool/run_cross_tier_integration.sh ($e)',
    );
  }
}

Future<String> _loginAs(String username, String password) async {
  final authApi = auth.AuthApi(_authBaseUri);
  try {
    final result = await authApi.authLogin(
      body: auth.LoginRequest(
        username: username,
        password: password,
        app: '',
        org: '',
      ),
    );
    return result.authzToken;
  } finally {
    authApi.close();
  }
}

void main() {
  test('OC-1: the generated AuthApi logs alice in', () async {
    await _live(() async {
      final authApi = auth.AuthApi(_authBaseUri);
      try {
        final result = await authApi.authLogin(
          body: auth.LoginRequest(
            username: 'alice',
            password: 'alice-pass',
            app: '',
            org: '',
          ),
        );
        expect(result.user.username, 'alice');
        expect(result.authzToken, isNotEmpty);
        expect(result.expiresAt.isAfter(DateTime.now()), isTrue);
      } finally {
        authApi.close();
      }
    });
  });

  test(
    'OC-2: the generated AppApi calls the app server with that token',
    () async {
      await _live(() async {
        final app = AppApi(
          _appBaseUri,
          bearerToken: await _loginAs('alice', 'alice-pass'),
        );
        try {
          final health = await app.appHealth();
          expect(health['status'], 'ok');
          final workspaces = await app.appListWorkspaces();
          expect(workspaces, isNotEmpty);
          final projects = await app.appListProjects(
            workspaceId: workspaces.first.id,
          );
          expect(
            projects.every((p) => p.workspaceId == workspaces.first.id),
            isTrue,
          );
        } finally {
          app.close();
        }
      });
    },
  );

  test('OC-3: a write round-trips through the generated models', () async {
    await _live(() async {
      final app = AppApi(
        _appBaseUri,
        bearerToken: await _loginAs('alice', 'alice-pass'),
      );
      try {
        final created = await app.appCreateWorkspace(
          body: Workspace(id: '', name: 'generated client', ownerId: ''),
        );
        expect(created.id, isNotEmpty);
        expect(created.name, 'generated client');
        await app.appDeleteWorkspace(id: created.id);
        final remaining = await app.appListWorkspaces();
        expect(remaining.map((w) => w.id), isNot(contains(created.id)));
      } finally {
        app.close();
      }
    });
  });

  test('OC-4: without a token the call is refused as the document says — a '
      'bare 404 that does not confirm the route exists', () async {
    await _live(() async {
      final app = AppApi(_appBaseUri);
      try {
        // Public, so it answers without a token: the reachability probe that
        // lets an offline run skip rather than fail inside the matcher.
        await app.appHealth();
        await expectLater(
          app.appListWorkspaces(),
          throwsA(
            isA<AppApiException>()
                .having((e) => e.statusCode, 'statusCode', 404)
                .having((e) => e.errorKey, 'errorKey', isNull),
          ),
        );
      } finally {
        app.close();
      }
    });
  });

  test(
    'OC-5: each server serves the document its client was generated from',
    () async {
      await _live(() async {
        for (final (base, committed) in [
          (_appBaseUri, '../advanced_app_server/openapi/openapi.json'),
          (_authBaseUri, '../advanced_auth_server/openapi/openapi.json'),
        ]) {
          final client = HttpClient();
          try {
            final request = await client.getUrl(base.resolve('/openapi.json'));
            final response = await request.close();
            expect(response.statusCode, 200);
            final served = jsonDecode(await utf8.decodeStream(response));
            expect(
              served,
              jsonDecode(File(committed).readAsStringSync()),
              reason: '$base serves a different document from $committed',
            );
          } finally {
            client.close();
          }
        }
      });
    },
  );
}
