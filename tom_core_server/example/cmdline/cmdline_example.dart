/// Executable example for the command-line module of `tom_core_server`.
///
/// Demonstrates the codegen-free helpers: parsing `key=value` arguments into a
/// typed map ([TomArgs.parseArgsToMap]), normalising an existing string map
/// ([TomArgs.convertToObjectMap]), parsing, reading and merging `.env` content
/// ([TomEnvFile]), and resolving the two into the environment that
/// `${VAR:default}` placeholders expand from
/// ([TomEnvFile.resolveEnvironment]).
///
/// Two members are deliberately not shown, for two different reasons:
///
/// - [TomArgs.fillFromArgs] needs a reflected configuration type, which would
///   make this file depend on generated code; `doc/cmdline.md` describes it.
/// - `TomEnvFile.load` does nothing [TomEnvFile.read] does not. It calls `read`
///   and returns the result — `Platform.environment` is read-only, so there is
///   nothing for it to install the values into — and `doc/cmdline.md` lists it
///   as a limitation with the advice to prefer `read`. An example is a
///   recommendation, so demonstrating it here would contradict that advice.
///
/// Every other [TomEnvFile] method appears below, as do [TomArgs]'s three
/// parsing entry points. [TomArgs.unquote] and the [TomArgs.intPattern] /
/// [TomArgs.doublePattern] matchers are the shared machinery behind the
/// conversions shown here — step 4's quoted value is `unquote` at work, the
/// `int` and `double` in steps 1 and 3 are the two patterns, and step 4's
/// padded and `+`-signed phone numbers are the shapes those patterns refuse —
/// rather than operations a caller performs separately.
///
/// Run with `dart run example/cmdline/cmdline_example.dart`.
/// The same behaviour is covered by `test/cmdline_test.dart`.
library;

import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';

/// Whether [a] and [b] hold the same keys with the same values.
///
/// Dart's `==` on `Map` is identity, so two maps built from the same file are
/// never equal by it. Compared entry by entry here rather than by pulling in
/// `package:collection`, to keep the example's imports to what it demonstrates.
bool _sameMap(Map<String, Object?> a, Map<String, Object?> b) =>
    a.length == b.length &&
    a.keys.every((key) => b.containsKey(key) && a[key] == b[key]);

Future<void> run() async {
  // 1. Parse `key=value` arguments. Values are converted to their natural type;
  //    a bare flag becomes the boolean true, and a key is named without the
  //    dashes it was written with.
  final args = TomArgs.parseArgsToMap(['--port=8080', 'rate=1.5', '--verbose']);
  print('1. parsed args               : $args');
  check(args['port'] == 8080, 'port converts to the int 8080');
  check(args['rate'] == 1.5, 'rate converts to the double 1.5');
  check(args['verbose'] == true, 'a bare flag becomes the boolean true');

  // 2. Normalise an existing string map (e.g. the OS environment) with the same
  //    conversion rules.
  final typed = TomArgs.convertToObjectMap({'DEBUG': 'true', 'WORKERS': '4'});
  print('2. converted string map      : $typed');
  check(
    typed['DEBUG'] == true && typed['WORKERS'] == 4,
    'a string map converts by the same rules as the command line',
  );

  // 3. `.env` syntax without a file. `parse` takes the lines from any source —
  //    here a blob that arrived from a secret store rather than from disk. It
  //    is also what `read` is built on: read the lines, then parse them.
  const fromSecretStore = '''
# issued by the secret store, never written to disk
DB_URL=mysql://host/db?user=root
DB_POOL=16
''';
  final secrets = TomEnvFile.parse(fromSecretStore.split('\n'));
  print('3. parsed .env lines         : $secrets');
  check(secrets['DB_POOL'] == 16, 'the same conversion rules apply off-disk');
  // The split is on the *first* `=`, so the query parameter stays part of the
  // URL instead of being read as a second pair.
  check(
    secrets['DB_URL'] == 'mysql://host/db?user=root',
    'a value carrying further "=" characters survives whole',
  );

  // 4. Read a .env file. Write one to a temp dir first, then read it back.
  final dir = await Directory.systemTemp.createTemp('tom_cmdline_example');
  final envFile = File('${dir.path}/.env');
  await envFile.writeAsString('''
# server settings
SERVER_PORT=8080
SERVER_NAME="my service"   # inline comment is stripped
ENABLED=true
SUPPORT_PHONE=004917612345678901
CLOCK_SKEW=-5
BILLING_PHONE=+4917612345678
''');
  final env = TomEnvFile.read(envFile.path);
  print('4. read .env                 : $env');
  check(env['SERVER_PORT'] == 8080, 'an unquoted .env number converts to int');
  check(
    env['SERVER_NAME'] == 'my service',
    'a quoted value keeps its spaces, loses its quotes, and stays a String',
  );
  check(env['ENABLED'] == true, 'an unquoted "true" converts to bool');
  // A digit run with leading zeros is an identifier, not a quantity: an int has
  // no notion of the padding, so converting it would hand back a different
  // phone number and report nothing. It stays a String, and it needs no quotes
  // to do so.
  check(
    env['SUPPORT_PHONE'] == '004917612345678901',
    'a zero-padded identifier keeps its zeros, unquoted',
  );
  // A `-` changes the value it introduces, so it is part of the number and a
  // negative setting reaches a numeric field. A `+` decorates one — it is how
  // an international phone number is written — so it is refused for the same
  // reason the padding is: converting it would hand back a different
  // identifier and report nothing.
  check(env['CLOCK_SKEW'] == -5, 'a leading minus is part of the number');
  check(
    env['BILLING_PHONE'] == '+4917612345678',
    'a leading plus keeps an identifier textual, unquoted',
  );

  // 5. The same file read without blocking the isolate. Prefer this wherever
  //    the call site can await — start-up usually can.
  final envAsync = await TomEnvFile.readAsync(envFile.path);
  print('5. readAsync .env            : $envAsync');
  check(envAsync['SERVER_PORT'] == 8080, 'readAsync converts values too');
  check(
    _sameMap(envAsync, env),
    'readAsync returns what read returns, for the same file',
  );

  // 6. A missing file is not an error: it yields an empty map. Both variants
  //    answer the same way, so neither needs an existence check first.
  final missing = TomEnvFile.read('${dir.path}/.env.absent');
  final missingAsync = await TomEnvFile.readAsync('${dir.path}/.env.absent');
  print('6. missing .env              : $missing (empty)');
  check(missing.isEmpty, 'a missing .env yields an empty map, not an error');
  check(missingAsync.isEmpty, 'readAsync answers the same way');

  // 7. Merge layers a local override on top of a base; later sources win.
  final merged = TomEnvFile.merge([
    {'SERVER_PORT': 8080, 'SERVER_NAME': 'base'},
    {'SERVER_NAME': 'override'},
  ]);
  print('7. merged env                : $merged');
  check(
    merged['SERVER_PORT'] == 8080 && merged['SERVER_NAME'] == 'override',
    'a later source overrides an earlier one and leaves the rest alone',
  );

  // 8. Build the environment that `${VAR:default}` placeholders expand from:
  //    the process environment with the `.env` layered on top. This is the map
  //    to hand `TomYaml.loadYamlFile(..., environment:)`, and it is what makes
  //    editing a `.env` move the datasource the server actually dials rather
  //    than only the one Docker Compose starts.
  //
  //    Note the direction: the `.env` wins over the process environment, which
  //    is the opposite of Docker Compose's precedence and the same as
  //    `TomBaseServerConfiguration.getDefaultValues`. A boot reads both, so the
  //    two halves of it agree.
  final expansion = TomEnvFile.resolveEnvironment(
    path: envFile.path,
    processEnvironment: {'SERVER_PORT': '3306', 'HOME': '/home/deploy'},
  );
  print('8. expansion environment     : $expansion');
  check(
    expansion['SERVER_PORT'] == '8080',
    'the .env value wins over the one already in the process environment',
  );
  check(
    expansion['HOME'] == '/home/deploy',
    'a process variable the .env says nothing about survives',
  );
  // Values arrive as text because that is what a placeholder expands to. Step
  // 4 read the same key as the int 8080; here it is the string '8080'.
  check(
    expansion['ENABLED'] == 'true',
    'values are stringified, because an expansion is substituted as text',
  );

  await dir.delete(recursive: true);
}

Future<void> main() async {
  await run();
}
