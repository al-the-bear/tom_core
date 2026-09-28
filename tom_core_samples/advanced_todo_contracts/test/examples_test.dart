/// Runs each file in `example/` the way its header tells a reader to, and
/// checks what it prints.
///
/// Both examples need no infrastructure, so there is no skip: an example that
/// cannot run on a bare checkout is the defect.
library;

import 'dart:io';

import 'package:test/test.dart';

/// Runs `example/[file]` with `dart run` and returns its stdout.
Future<String> _run(String file) async {
  final result = await Process.run(Platform.resolvedExecutable, [
    'run',
    'example/$file',
  ]);
  expect(result.exitCode, 0, reason: '${result.stderr}');
  return result.stdout as String;
}

void main() {
  test('read_endpoint_facts_example prints routes, methods and access from the '
      'registry', () async {
    final lines = (await _run(
      'read_endpoint_facts_example.dart',
    )).trim().split('\n').map((l) => l.split(RegExp(r'\s+'))).toList();

    expect(lines, [
      ['auth.authLogin', 'POST', 'http://localhost:8081/auth/login', 'public'],
      [
        'auth.authSecondFactor',
        'POST',
        'http://localhost:8081/auth/second-factor',
        'public',
      ],
      ['auth.authMe', 'GET', 'http://localhost:8081/auth/me', 'authenticated'],
      [
        'admin.adminListUsers',
        'GET',
        'http://localhost:8081/admin/users',
        'role',
        'admin',
      ],
      [
        'admin.adminPutGrants',
        'PUT',
        'http://localhost:8081/admin/grants',
        'role',
        'admin',
      ],
      ['app.appHealth', 'GET', 'http://localhost:8080/status', 'public'],
      [
        'app.appListItems',
        'GET',
        'http://localhost:8080/items',
        'authenticated',
      ],
    ]);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test(
    'dto_round_trip_example puts the tokens on the wire and never in the log',
    () async {
      final out = await _run('dto_round_trip_example.dart');
      final wire = out.split('\n').firstWhere((l) => l.startsWith('wire:'));
      final restored = out
          .split('\n')
          .firstWhere((l) => l.startsWith('restored:'));

      expect(wire, contains('"authzToken":"interim-authz"'));
      expect(wire, contains('"requires2FA":true'));
      expect(wire, contains('"expiresAt":"2026-06-28T12:05:00.000Z"'));
      expect(restored, contains('pending 2FA: totp'));
      expect(restored, isNot(contains('interim')));
      expect(
        out,
        contains(
          'second factor pending: true (totp), expires 2026-06-28 12:05:00.000Z',
        ),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
