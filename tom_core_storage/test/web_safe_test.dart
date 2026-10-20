/// The platform-neutral entry point stays platform-neutral, executed rather
/// than asserted.
///
/// Two guards, because they catch disjoint failures:
///
/// 1. A walk of the default entry point's import closure inside this package:
///    no library reachable from `tom_core_storage.dart` imports `dart:io`, and
///    none imports `package:web` or a cipher. `dart compile js` from the plain
///    Dart SDK *accepts* `dart:io` (the SDK ships a throwing stub), so only a
///    walk catches it before a web build does.
/// 2. A real dart2js compile of a program using the default entry point, one
///    using `web.dart` and one using `github.dart`. That catches codegen-level problems the VM never
///    sees, such as integer literals above 2^53.
///
/// The inverse is pinned too: `io.dart` is where `dart:io` actually lives, so
/// deleting the local filesystem would not pass as "moved".
@Timeout(Duration(minutes: 4))
library;

import 'dart:io';

import 'package:test/test.dart';

import 'support/scratch.dart';

final _directive = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');
final _conditional = RegExp(r"""^\s*if\s*\([^)]*\)\s*['"]([^'"]+)['"]""");

/// Library → the external URIs it imports, over the libraries reachable from
/// [entry] inside this package (conditional alternatives included).
Map<String, Set<String>> closureOf(String entry) {
  final closure = <String, Set<String>>{};
  final queue = [File(entry).absolute.path];
  while (queue.isNotEmpty) {
    final path = queue.removeLast();
    if (closure.containsKey(path)) continue;
    final file = File(path);
    if (!file.existsSync()) continue;
    final external = <String>{};
    for (final line in file.readAsLinesSync()) {
      final uri = (_directive.firstMatch(line) ?? _conditional.firstMatch(line))
          ?.group(1);
      if (uri == null) continue;
      if (uri.startsWith('package:tom_core_storage/')) {
        queue.add(
          '${Directory.current.absolute.path}/lib/'
          '${uri.substring('package:tom_core_storage/'.length)}',
        );
      } else if (uri.contains(':')) {
        external.add(uri);
      } else {
        queue.add(File('${file.parent.path}/$uri').absolute.path);
      }
    }
    closure[path] = external;
  }
  return closure;
}

Set<String> reached(String entry) =>
    closureOf(entry).values.expand((uris) => uris).toSet();

void main() {
  group('STORAGE-WEB the default entry point links everywhere', () {
    test('STORAGE-WEB-1: no dart:io, no browser API, no cipher reachable from '
        'tom_core_storage.dart', () {
      final closure = closureOf('lib/tom_core_storage.dart');
      expect(
        closure.length,
        greaterThan(8),
        reason: 'the walk found almost nothing, so it proved nothing',
      );
      final uris = reached('lib/tom_core_storage.dart');
      expect(uris, isNot(contains('dart:io')));
      expect(uris.where((u) => u.startsWith('package:web/')), isEmpty);
      expect(uris.where((u) => u.startsWith('package:pointycastle/')), isEmpty);
      expect(
        uris.where(
          (u) =>
              u.startsWith('package:tom_github_api/') ||
              u.startsWith('package:http/'),
        ),
        isEmpty,
        reason: 'the default entry point is network-free',
      );
    });

    test('STORAGE-WEB-2: io.dart is where dart:io lives, cipher.dart where the '
        'cipher lives, web.dart where the browser API lives, github.dart where '
        'the network lives', () {
      expect(reached('lib/io.dart'), contains('dart:io'));
      expect(
        reached(
          'lib/cipher.dart',
        ).where((u) => u.startsWith('package:pointycastle/')),
        isNotEmpty,
      );
      expect(
        reached('lib/web.dart').where((u) => u.startsWith('package:web/')),
        isNotEmpty,
      );
      expect(reached('lib/web.dart'), isNot(contains('dart:io')));
      expect(
        reached(
          'lib/github.dart',
        ).where((u) => u.startsWith('package:tom_github_api/')),
        isNotEmpty,
      );
      expect(
        reached('lib/github.dart'),
        isNot(contains('dart:io')),
        reason: 'a browser build stores documents on GitHub',
      );
    });

    for (final (name, program) in [
      (
        'default',
        '''
import 'dart:typed_data';

import 'package:tom_core_storage/tom_core_storage.dart';

Future<void> main() async {
  final medium = TomMemoryBundleMedium();
  await medium.writeString('a.yaml', 'a: 1');
  final journal = TomMediumCommitJournal(medium: medium);
  await journal.append(
      locator: 'mem:/x',
      changeset: TomChangeset.singleFile(Uint8List.fromList([1, 2])),
      baseHead: null,
      version: 1);
  print((await journal.pending()).length);
}
''',
      ),
      (
        'github',
        '''
import 'package:tom_core_storage/github.dart';
import 'package:tom_core_storage/tom_core_storage.dart';

Future<void> main() async {
  final storage = TomGitHubStorage(tokens: TomInMemoryTokenSource());
  print(storage.handles('github:o/r/notes.yaml'));
}
''',
      ),
      (
        'web',
        '''
import 'package:tom_core_storage/web.dart';

Future<void> main() async {
  final medium = tomOpenBrowserMedium('tom.web-safe');
  await medium.writeString('a.yaml', 'a: 1');
  print(await medium.readString('a.yaml'));
}
''',
      ),
    ]) {
      test('STORAGE-WEB-3 $name: a program over the $name entry point compiles '
          'under dart2js', () async {
        final dart = Platform.resolvedExecutable;
        expect(
          dart.endsWith('dart') || dart.endsWith('dart.exe'),
          isTrue,
          reason:
              'run this suite with `dart test`; under another runner '
              'there is no Dart CLI to compile with',
        );
        final tmp = scratchDirectory('web_safe').createTempSync('$name-');
        addTearDown(() => tmp.deleteSync(recursive: true));
        final entry = File('${tmp.path}/main.dart')..writeAsStringSync(program);
        final result = await Process.run(dart, [
          'compile',
          'js',
          '--no-source-maps',
          '--packages=${Directory.current.absolute.path}/.dart_tool/package_config.json',
          '-o',
          '${tmp.path}/out.js',
          entry.path,
        ]);
        expect(
          result.exitCode,
          0,
          reason: 'dart2js rejected it:\n${result.stdout}\n${result.stderr}',
        );
      });
    }
  });
}
