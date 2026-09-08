import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The module readmes' closing pointer: does every one name its doc page, its
/// example and its test, and does every path it names exist?
///
/// A module readme is where a reader arrives from the source, and the pointer
/// is their only route from there to the prose that explains the module and the
/// programs that demonstrate it. Half the readmes reached this suite without
/// one, which is what a convention that is applied whenever somebody happens to
/// be editing a file converges on — so the convention is asserted here instead
/// of remembered.
///
/// The path check is the half that keeps working after a rename. Markdown links
/// are caught by the workspace's `check_doc_links.py` gate, but the example and
/// test paths are named in backticks rather than linked, and nothing else reads
/// those.

/// The package's module directories, read off disk.
List<String> _modules() =>
    Directory(p.join('lib', 'src', 'tomserver'))
        .listSync()
        .whereType<Directory>()
        .map((d) => p.basename(d.path))
        .toList()
      ..sort();

/// Modules that carry no `readme.md`, and why.
///
/// Stated rather than skipped: a module absent from this map and absent from
/// disk fails the first test, so the set can shrink but cannot silently grow.
///
/// **Empty, and that is the assertion.** Every module carries one. The map
/// stays because it is the mechanism by which the first test reads in both
/// directions — a module that loses its readme fails there rather than dropping
/// silently out of every test below.
const _withoutReadme = <String, String>{};

/// Where a path named by a readme may live.
///
/// The package first, then the kernel: `scheduling/readme.md` names the
/// kernel's parameterised contract suite, and says in the same sentence that it
/// is the kernel's. A pointer into a sibling package is worth resolving rather
/// than exempting, since a rename there breaks the reader here just the same.
final _roots = <String>['.', p.join('..', 'tom_core_kernel')];

/// The backticked paths a readme names under `doc/`, `example/` or `test/`.
///
/// Those three are the artefact roots the convention is about. Other backticked
/// text — `datasources/`, `GET /todos`, `multipart/alternative` — also contains
/// a slash without being a path, which is why the roots are named rather than
/// inferred from the shape of the token.
Iterable<String> _pathsNamedBy(String source) => RegExp(
  r'`((?:doc|example|test)/[^`\s]*)`',
).allMatches(source).map((m) => m.group(1)!);

/// Whether [path] exists, as a file or a directory, under any of [_roots].
bool _resolves(String path) => _roots.any((root) {
  final full = p.join(root, path);
  return File(full).existsSync() || Directory(full).existsSync();
});

void main() {
  final modules = _modules();

  String readmePath(String module) =>
      p.join('lib', 'src', 'tomserver', module, 'readme.md');

  final withReadme = modules
      .where((m) => File(readmePath(m)).existsSync())
      .toList();

  group('Every module', () {
    test('either carries a readme or is a stated exception', () {
      // Both directions. A module that loses its readme fails here rather than
      // dropping out of every test below unnoticed, and a module that gains one
      // fails here rather than leaving a stale excuse in the map.
      final missing = modules.where((m) => !withReadme.contains(m)).toList();
      expect(
        missing,
        _withoutReadme.keys.toList()..sort(),
        reason:
            'the modules without a lib/src/tomserver/<module>/readme.md are no '
            'longer the ones _withoutReadme names',
      );
    });
  });

  group("Every module readme's closing pointer", () {
    for (final module in withReadme) {
      final source = File(readmePath(module)).readAsStringSync();
      final named = _pathsNamedBy(source).toSet();

      test('names doc/$module.md: $module', () {
        // Linked, not merely backticked, because this is the one artefact a
        // reader follows rather than opens: the doc page is the module's prose
        // and the readme is its summary.
        expect(
          source,
          contains('](../../../../doc/$module.md)'),
          reason:
              'the $module readme does not link its doc page, so a reader who '
              'starts at the module has no route to the prose that explains it',
        );
      });

      test('names an example: $module', () {
        // Under `example/<module>/` specifically. A module whose example is a
        // migration rather than a program satisfies this too, and its readme
        // says which it is — what must not happen is silence.
        expect(
          named.where((path) => path.startsWith('example/$module/')),
          isNotEmpty,
          reason:
              'the $module readme names nothing under example/$module/, so a '
              'reader has no route to what demonstrates the module',
        );
      });

      test('names a test: $module', () {
        expect(
          named.where((path) => path.startsWith('test/')),
          isNotEmpty,
          reason:
              'the $module readme names no test, so a reader cannot tell what '
              'holds the claims above to the code',
        );
      });

      test('names only paths that exist: $module', () {
        // The half that survives a rename. Everything above asks whether the
        // readme points somewhere; this asks whether it still points at
        // something.
        final dead = named.where((path) => !_resolves(path)).toList()..sort();
        expect(
          dead,
          isEmpty,
          reason:
              'the $module readme names paths that are not on disk, under '
              'either ${_roots.join(' or ')}',
        );
      });
    }
  });
}
