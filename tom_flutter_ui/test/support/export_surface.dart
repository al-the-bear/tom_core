/// What each file under `lib/` offers a reader, computed from its directives.
///
/// Two suites need this and neither is about the other. `library_dartdoc_test`
/// asks whether a `[Type]` link in a library dartdoc resolves, which turns on
/// the difference between `import` (puts a name in library scope) and `export`
/// (does not). `package_barrel_test` asks what names the package barrel places
/// in a *consumer's* namespace, which is the transitive export surface of that
/// one file. Same walk, opposite ends of it — so the walk lives here and each
/// suite documents the rule it draws from the result.
///
/// This reads source text rather than the analyzer. That is a deliberate floor
/// on the precision: a directive assembled at runtime, or a name introduced by
/// something other than a top-level type declaration, is invisible. Neither
/// occurs in this package, and the alternative — standing up an
/// `AnalysisContextCollection` — costs a suite that runs in milliseconds today.
library;

import 'dart:io';

/// Every Dart source file under `lib/`, as repo-relative paths.
///
/// Walked rather than listed: a file added tomorrow is covered without anyone
/// remembering these tests exist.
List<String> allLibrarySources() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path)
        .where((p) => p.endsWith('.dart'))
        .toList()
      ..sort();

/// Type names declared in [source] — `class`, `enum`, `mixin`, `extension`
/// and `typedef`.
Set<String> declaredTypes(String source) => RegExp(
  r'^(?:abstract\s+|base\s+|final\s+|sealed\s+|interface\s+)*'
  r'(?:class|enum|mixin|extension|typedef)\s+(\w+)',
  multiLine: true,
).allMatches(source).map((m) => m.group(1)!).toSet();

/// Every `import` / `export` in a source file, as `(keyword, target)`.
final directive = RegExp(r"^\s*(import|export)\s+'([^']+)'", multiLine: true);

/// The repo-relative path a directive in [from] names, or `null` when the
/// target leaves the package (`dart:…`, or another package's `package:` URI).
///
/// `package:tom_flutter_ui/…` and a relative path are both resolved, because a
/// file inside the package may reach its neighbours either way and the two
/// spellings have to land on the same key for the fixpoint below to join them.
String? directiveTarget(String from, String target) {
  const own = 'package:tom_flutter_ui/';
  if (target.startsWith('package:')) {
    return target.startsWith(own)
        ? 'lib/${target.substring(own.length)}'
        : null;
  }
  if (target.contains(':')) return null; // dart:…
  final segments = from.split('/')..removeLast();
  for (final segment in target.split('/')) {
    if (segment == '.') continue;
    if (segment == '..') {
      if (segments.isNotEmpty) segments.removeLast();
      continue;
    }
    segments.add(segment);
  }
  return segments.join('/');
}

/// For every file under `lib/`, the type names it *offers*: the types it
/// declares, plus everything its `export` directives surface, transitively.
///
/// Computed to a fixpoint rather than by recursion, so an export cycle
/// terminates instead of needing a visited set carried through the walk.
Map<String, Set<String>> exportSurfaces() {
  final sources = allLibrarySources();
  final exports = <String, List<String>>{};
  final surfaces = <String, Set<String>>{};
  for (final path in sources) {
    final source = File(path).readAsStringSync();
    surfaces[path] = declaredTypes(source);
    exports[path] = [
      for (final m in directive.allMatches(source))
        if (m.group(1) == 'export') ?directiveTarget(path, m.group(2)!),
    ];
  }
  var changed = true;
  while (changed) {
    changed = false;
    for (final path in sources) {
      for (final target in exports[path]!) {
        final offered = surfaces[target];
        if (offered == null) continue; // Left the package.
        if (surfaces[path]!.containsAll(offered)) continue;
        surfaces[path]!.addAll(offered);
        changed = true;
      }
    }
  }
  return surfaces;
}

/// The type names in scope inside [path]: what the file declares, plus the
/// export surface of everything it imports.
///
/// `import` is the only directive that puts a name in library scope, which is
/// why [exportSurfaces] is consulted *through* the imports rather than folded
/// into one set.
Set<String> reachableTypes(String path, Map<String, Set<String>> surfaces) {
  final source = File(path).readAsStringSync();
  final reachable = <String>{...declaredTypes(source)};
  for (final m in directive.allMatches(source)) {
    if (m.group(1) != 'import') continue;
    final target = directiveTarget(path, m.group(2)!);
    if (target == null) continue;
    reachable.addAll(surfaces[target] ?? const <String>{});
  }
  return reachable;
}

/// Where each type under `lib/` is declared, as `name -> repo-relative path`.
///
/// First declaration wins. A duplicated type name would make the entry
/// arbitrary, but only for the path a failure message prints — membership,
/// which is what the checks branch on, is unaffected.
Map<String, String> typeHomes() {
  final homes = <String, String>{};
  for (final path in allLibrarySources()) {
    for (final name in declaredTypes(File(path).readAsStringSync())) {
      homes.putIfAbsent(name, () => path);
    }
  }
  return homes;
}
