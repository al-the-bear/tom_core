/// The guard that keeps `lib/src/` from importing its own package barrel.
///
/// A file under `lib/src/` that writes
/// `import 'package:tom_core_server/tom_core_server.dart'` is importing the
/// library that exports it. Dart accepts this — it is not a compile error — so
/// nothing objects, and the cost is paid quietly in three places.
///
/// It pulls in the whole package to reach a handful of symbols. The barrel
/// re-exports every module plus `mysql_client` and `tom_core_kernel`, so a file
/// needing `TomArgs` gets the persistence layer, the export renderers and a
/// database driver as well.
///
/// It erases the dependency graph. `configuration` really depends on
/// `cmdline`, `server` and the kernel; through the barrel it appears to depend
/// on everything, which is the same as saying nothing. That information is what
/// tells you whether a module can be extracted, and whether an edit in one
/// module can reach another.
///
/// And it makes each such file's own exports reachable through a cycle back to
/// itself, which is a shape no reader expects and no tool can simplify.
///
/// This is checked rather than remembered because the three instances it first
/// caught — in `configuration`, `healthcheck` and `little_things` — arrived
/// independently, and the reason is structural: every module readme opens with
/// the barrel import, because that *is* the right import for a consumer.
/// Copying the quick-start line into a source file is the natural mistake, and
/// a natural mistake will be made again.
///
/// The match is on `package:tom_core_server/` rather than on the barrel path,
/// because the third instance did not use the barrel: it reached into
/// `package:tom_core_server/src/tomserver/server/server.dart`, an absolute path
/// into the package's own private tree. That spelling is worse than the barrel
/// — it is the form that breaks if `src/` is ever rearranged, and it is exactly
/// what a grep for the barrel misses.
///
/// The barrel itself is exempt: exporting `src/` is exactly its job.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:path/path.dart' as p;

/// Every `.dart` file under `lib/`, as paths relative to the package root.
List<String> _libraryFiles() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .map((entity) => p.normalize(entity.path))
        .where((path) => path.endsWith('.dart'))
        .toList()
      ..sort();

/// The `package:tom_core_server/...` imports [path] declares, if any.
///
/// Matches `import` only, not `export`: re-exporting a sibling is a normal way
/// for a module to compose its own public surface, and the barrel does nothing
/// else.
List<String> _selfImports(String path) => File(path)
    .readAsLinesSync()
    .where(
      (line) => RegExp(
        r'''^\s*import\s+['"]package:tom_core_server/''',
      ).hasMatch(line),
    )
    .map((line) => line.trim())
    .toList();

void main() {
  group('lib/src reaches its dependencies directly', () {
    test('no source file imports the package barrel', () {
      final offenders = <String, List<String>>{};
      for (final path in _libraryFiles()) {
        // The barrel is the one file allowed to speak for the package.
        if (p.normalize(path) == p.join('lib', 'tom_core_server.dart')) {
          continue;
        }
        final imports = _selfImports(path);
        if (imports.isNotEmpty) offenders[path] = imports;
      }

      // Each offending file over its own offending lines, so the failure is
      // the edit list rather than a count.
      final listing = offenders.entries
          .map((entry) => '  ${entry.key}\n    ${entry.value.join('\n    ')}')
          .join('\n');

      expect(
        offenders,
        isEmpty,
        reason:
            'These files import the barrel that exports them. Import the '
            'specific src files they use instead — a relative import for a '
            'sibling module, a package import for a real dependency:\n'
            '$listing',
      );
    });

    test('the barrel exports every module directory', () {
      // The counterpart of the rule above: src files stop reaching for the
      // barrel only if the barrel still reaches them, so a module that no
      // export mentions is unreachable to consumers however tidy its imports.
      final barrel = File(
        p.join('lib', 'tom_core_server.dart'),
      ).readAsStringSync();
      final modules =
          Directory(p.join('lib', 'src', 'tomserver'))
              .listSync()
              .whereType<Directory>()
              .map((entity) => p.basename(entity.path))
              .toList()
            ..sort();

      final unexported = modules
          .where((module) => !barrel.contains('src/tomserver/$module/'))
          .toList();

      expect(
        unexported,
        isEmpty,
        reason:
            'These module directories are exported by nothing in '
            'lib/tom_core_server.dart, so no consumer can reach them: '
            '${unexported.join(', ')}',
      );
    });
  });
}
