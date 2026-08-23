/// Executable example for the command-line module of `tom_core_server`.
///
/// Demonstrates the codegen-free helpers: parsing `key=value` arguments into a
/// typed map ([TomArgs.parseArgsToMap]), normalising an existing string map
/// ([TomArgs.convertToObjectMap]), and reading / merging `.env` files
/// ([TomEnvFile]). The reflection-backed [TomArgs.fillFromArgs] is described in
/// `doc/cmdline.md`; it needs a reflected configuration type and so is not shown
/// here.
///
/// Run with `dart run example/cmdline/cmdline_example.dart`.
/// The same behaviour is covered by `test/cmdline_test.dart`.
library;

import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';

/// Throws when [ok] does not hold, naming the [expectation] that failed.
///
/// Deliberately not `assert`: `dart run` leaves assertions **disabled** — that
/// is what its `--enable-asserts` flag is for — so an `assert` here compiles
/// out under the very command this file's header gives. An example whose
/// checks vanish under its own documented invocation is worse than one with no
/// checks at all, because it still prints a plausible transcript and still
/// exits 0 while every expectation in it is violated. A plain `if`/`throw`
/// holds however the file is run.
void check(bool ok, String expectation) {
  if (!ok) throw StateError('cmdline example failed: $expectation');
}

Future<void> run() async {
  // 1. Parse `key=value` arguments. Values are converted to their natural type;
  //    a bare flag becomes the boolean true.
  final args = TomArgs.parseArgsToMap(['port=8080', 'rate=1.5', '--verbose']);
  print('1. parsed args               : $args');
  check(args['port'] == 8080, 'port converts to the int 8080');
  check(args['rate'] == 1.5, 'rate converts to the double 1.5');
  check(args['--verbose'] == true, 'a bare flag becomes the boolean true');

  // 2. Normalise an existing string map (e.g. the OS environment) with the same
  //    conversion rules.
  final typed = TomArgs.convertToObjectMap({'DEBUG': 'true', 'WORKERS': '4'});
  print('2. converted string map      : $typed');
  check(
    typed['DEBUG'] == true && typed['WORKERS'] == 4,
    'a string map converts by the same rules as the command line',
  );

  // 3. Read a .env file. Write one to a temp dir first, then read it back.
  final dir = await Directory.systemTemp.createTemp('tom_cmdline_example');
  final envFile = File('${dir.path}/.env');
  await envFile.writeAsString('''
# server settings
SERVER_PORT=8080
SERVER_NAME="my service"   # inline comment is stripped
ENABLED=true
''');
  final env = TomEnvFile.read(envFile.path);
  print('3. read .env                 : $env');
  check(env['SERVER_PORT'] == 8080, 'an unquoted .env number converts to int');
  check(
    env['SERVER_NAME'] == 'my service',
    'a quoted value keeps its spaces, loses its quotes, and stays a String',
  );
  check(env['ENABLED'] == true, 'an unquoted "true" converts to bool');

  // 4. A missing file is not an error: it yields an empty map.
  final missing = TomEnvFile.read('${dir.path}/.env.absent');
  print('4. missing .env              : $missing (empty)');
  check(missing.isEmpty, 'a missing .env yields an empty map, not an error');

  // 5. Merge layers a local override on top of a base; later sources win.
  final merged = TomEnvFile.merge([
    {'SERVER_PORT': 8080, 'SERVER_NAME': 'base'},
    {'SERVER_NAME': 'override'},
  ]);
  print('5. merged env                : $merged');
  check(
    merged['SERVER_PORT'] == 8080 && merged['SERVER_NAME'] == 'override',
    'a later source overrides an earlier one and leaves the rest alone',
  );

  await dir.delete(recursive: true);
}

Future<void> main() async {
  await run();
}
