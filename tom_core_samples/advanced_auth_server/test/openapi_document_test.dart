/// The committed `openapi/openapi.json` is what the endpoint annotations
/// generate today, and it validates against the OpenAPI 3.1 meta-schema.
///
/// Both run the server's own `tool/openapi.dart`, so the test exercises the
/// command a developer runs, with the defaults it states, rather than a second
/// copy of them.
library;

import 'dart:io';

import 'package:test/test.dart';

Future<ProcessResult> _tool(List<String> args) => Process.run(
  Platform.resolvedExecutable,
  ['run', 'tool/openapi.dart', ...args],
);

void main() {
  test('openapi/openapi.json is current', () async {
    final run = await _tool([':document', '--check']);
    expect(
      run.exitCode,
      0,
      reason:
          'regenerate with: dart run tool/openapi.dart :document\n'
          '${run.stdout}${run.stderr}',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('openapi/openapi.json validates', () async {
    final run = await _tool([':validate']);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect('${run.stdout}', contains('openapi/openapi.json: valid'));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
