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

Future<void> run() async {
  // 1. Parse `key=value` arguments. Values are converted to their natural type;
  //    a bare flag becomes the boolean true.
  final args = TomArgs.parseArgsToMap(['port=8080', 'rate=1.5', '--verbose']);
  print('1. parsed args               : $args');
  assert(args['port'] == 8080); // int
  assert(args['rate'] == 1.5); // double
  assert(args['--verbose'] == true); // flag

  // 2. Normalise an existing string map (e.g. the OS environment) with the same
  //    conversion rules.
  final typed = TomArgs.convertToObjectMap({'DEBUG': 'true', 'WORKERS': '4'});
  print('2. converted string map      : $typed');
  assert(typed['DEBUG'] == true && typed['WORKERS'] == 4);

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
  assert(env['SERVER_PORT'] == 8080);
  assert(env['SERVER_NAME'] == 'my service'); // quoted -> kept as String
  assert(env['ENABLED'] == true);

  // 4. A missing file is not an error: it yields an empty map.
  final missing = TomEnvFile.read('${dir.path}/.env.absent');
  print('4. missing .env              : $missing (empty)');
  assert(missing.isEmpty);

  // 5. Merge layers a local override on top of a base; later sources win.
  final merged = TomEnvFile.merge([
    {'SERVER_PORT': 8080, 'SERVER_NAME': 'base'},
    {'SERVER_NAME': 'override'},
  ]);
  print('5. merged env                : $merged');
  assert(merged['SERVER_PORT'] == 8080 && merged['SERVER_NAME'] == 'override');

  await dir.delete(recursive: true);
}

Future<void> main() async {
  await run();
}
