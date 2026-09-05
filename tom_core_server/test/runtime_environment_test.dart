import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// Runs [body] in a temporary directory holding a `.env` file of [contents].
///
/// `TomEnvFile.read()` resolves `.env` against the current directory, so the
/// only way to give the lookup an environment file is to move into one — which
/// is process-global state, hence the `finally` that puts the directory back
/// whether [body] returned or threw.
Future<void> _withEnvFile(String contents, void Function() body) async {
  final previous = Directory.current;
  final dir = await Directory.systemTemp.createTemp('tom_runtime_env');
  try {
    await File('${dir.path}/.env').writeAsString(contents);
    Directory.current = dir;
    body();
  } finally {
    Directory.current = previous;
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

void main() {
  // A server picks its runtime environment before it has a configuration —
  // the environment is what selects the configuration overlay — so the
  // selection cannot go through the configuration merge and has to read the
  // same sources itself. Every server in this workspace previously read
  // `Platform.environment['env']` alone, which meant the `env=dev` line that
  // every sample's `.env.example` ends with reached the *configuration* and
  // never the runtime: the samples shipped a `config-resources_dev.yaml`
  // overlay and, unless the operator exported `env` in their shell, booted
  // under `prod` without it. These tests fix the three sources and their order.
  group('selectedRuntimeEnvironmentName', () {
    test('reads the OS environment, which is what a container sets', () {
      // `PATH` stands in for "a variable this process really has": the test
      // cannot add one to its own OS environment, so it asserts the source is
      // consulted by naming a variable that is certainly there.
      expect(
        selectedRuntimeEnvironmentName([], variable: 'PATH'),
        Platform.environment['PATH'],
      );
    });

    test('reads the .env file, which is what the sample recipes write', () {
      return _withEnvFile('env=dev\n', () {
        expect(selectedRuntimeEnvironmentName([]), 'dev');
      });
    });

    test('a command-line argument wins over the .env file', () {
      // The same precedence the configuration merge gives these two sources,
      // so a server's environment and its configuration cannot be chosen by
      // different rules.
      return _withEnvFile('env=dev\n', () {
        expect(selectedRuntimeEnvironmentName(['env=staging']), 'staging');
      });
    });

    test('the .env file wins over the OS environment', () {
      return _withEnvFile('PATH=from-env-file\n', () {
        expect(
          selectedRuntimeEnvironmentName([], variable: 'PATH'),
          'from-env-file',
        );
      });
    });

    test('a selection nobody made is null, not a guess', () {
      // Null is what `TomRuntime.setCurrentEnvironment` takes as "apply the
      // fallback", so the caller's fallback stays the caller's to choose.
      return _withEnvFile('', () {
        expect(selectedRuntimeEnvironmentName([]), isNull);
      });
    });

    test('a non-string value is returned as text', () {
      // `TomEnvFile` converts `2` to an int, and an environment is named, not
      // numbered — a caller comparing against `TomEnvironment.env` needs the
      // text or the lookup silently misses.
      return _withEnvFile('env=2\n', () {
        expect(selectedRuntimeEnvironmentName([]), '2');
      });
    });
  });
}
