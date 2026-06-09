// Domain-free file-scope containment (Todo 9, G-C3).
//
// `PathScope` is the path-normalisation / containment primitive the creation
// loop's file-scope sandbox is built on (`creation_specification.md` § 7). It is
// deliberately domain-free — it knows nothing about brain tools or wire error
// codes — so the brain's `FileScopeViolation`-throwing wrapper and any other
// agent runtime can share one containment rule. A path is in scope when, after
// normalisation, it lands inside the *union* of the configured roots; a `..`
// escape, an absolute path, or any other break drops out of a given root and is
// only a violation when it escapes them all.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tom_core_agentic/tom_core_agentic.dart';
import 'package:test/test.dart';

void main() {
  group('PathScope', () {
    test('normalises roots to absolute on construction', () {
      final scope = PathScope(['relative/root']);
      expect(p.isAbsolute(scope.roots.single), isTrue);
      expect(scope.roots.single, p.normalize(p.absolute('relative/root')));
    });

    test('rejects an empty root set', () {
      expect(() => PathScope(const <String>[]), throwsArgumentError);
    });

    test('admits a plain relative path under the root', () {
      final scope = PathScope(['/work']);
      final hits = scope.resolve('src/main.dart');
      expect(hits, hasLength(1));
      expect(hits.single.root, p.normalize('/work'));
      expect(hits.single.path, p.normalize('/work/src/main.dart'));
    });

    test('admits the root itself', () {
      final scope = PathScope(['/work']);
      expect(scope.resolve('.'), hasLength(1));
      expect(scope.resolve('.').single.path, p.normalize('/work'));
    });

    test('drops a path that escapes the single root via ..', () {
      final scope = PathScope(['/work']);
      expect(scope.resolve('../etc/passwd'), isEmpty);
      expect(scope.admits('../etc/passwd'), isFalse);
    });

    test('drops an absolute path outside the root', () {
      final scope = PathScope(['/work']);
      expect(scope.resolve('/etc/passwd'), isEmpty);
    });

    test('treats roots as a union — a hit in any root is in scope', () {
      final scope = PathScope(['/work/a', '/work/b']);
      final hits = scope.resolve('../b/file.txt');
      // Escapes root a (../b leaves /work/a), lands in root b.
      expect(hits, hasLength(1));
      expect(hits.single.root, p.normalize('/work/b'));
    });

    test('returns hits in configured root order (priority preserved)', () {
      // A relative path valid under both roots returns both, first root first.
      final scope = PathScope(['/work/a', '/work/a/nested']);
      final hits = scope.resolve('inner.dart');
      expect(hits.first.root, p.normalize('/work/a'));
    });

    test('admits is false only when every root is escaped', () {
      final scope = PathScope(['/work/a', '/work/b']);
      expect(scope.admits('a/x'), isTrue);
      expect(scope.admits('b/x'), isTrue);
      expect(scope.admits('../c/x'), isFalse);
    });

    test('contains a real created file and excludes its sibling', () {
      final root = Directory.systemTemp.createTempSync('path_scope_');
      addTearDown(() => root.deleteSync(recursive: true));
      File(p.join(root.path, 'inside.txt')).writeAsStringSync('x');
      final scope = PathScope([root.path]);
      expect(scope.admits('inside.txt'), isTrue);
      expect(scope.admits('../outside.txt'), isFalse);
    });
  });
}
