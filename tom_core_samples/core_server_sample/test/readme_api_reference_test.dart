/// Holds the README's `## API` section to the source it indexes.
///
/// **Shared in shape with `advanced_client_core`, `advanced_todo_domain` and
/// `advanced_ops_server`**, whose `test/readme_api_reference_test.dart` files
/// hold those packages' READMEs the same way; the copies differ only in
/// [_barrel].
///
/// **Why the section exists.** A sample package carries no `doc/api/` mirror —
/// that is decided once for the whole sample suite in `tom_core_samples/README.md`,
/// because a hand-copied index of a sample's internals would drift from the
/// first refactor with nothing to notice. This package's README carries the
/// index instead, and this suite is the thing that notices.
///
/// Both directions are checked:
///
/// * **Nothing listed that the source does not say.** Every line of every
///   ```dart block under `## API` must occur in the library named by the
///   heading above it, once both are reduced to their tokens — whitespace and
///   trailing commas removed, comments stripped from the source. A renamed
///   parameter, a changed return type or a dropped member fails here.
/// * **Nothing exported that the section omits.** Every public declaration in
///   every library the barrel exports — top-level, and the members of its
///   public classes — must be named in that library's block.
///
/// The declaration scan leans on `dart format`: a top-level declaration starts
/// in column 0 and a class member in column 2, while bodies and wrapped
/// parameter lists sit deeper. `check_dart_format.py` holds the package to that
/// layout.
library;

import 'dart:io';

import 'package:test/test.dart';

/// The package barrel whose exports the section indexes.
const _barrel = 'lib/core_server_sample.dart';

void main() {
  final exported = _exportedLibraries(_barrel);
  final blocks = _apiBlocks(File('README.md').readAsStringSync());

  group('README `## API`', () {
    test('has one block per exported library, and no other', () {
      expect(exported, isNotEmpty);
      expect(blocks.keys.toSet(), equals(exported.toSet()));
    });

    for (final library in exported) {
      final source = File(library).readAsStringSync();

      test('every line listed for $library occurs in it', () {
        final haystack = _tokens(_stripComments(source));
        final absent = [
          for (final line in blocks[library] ?? const <String>[])
            if (!haystack.contains(_tokens(line))) line.trim(),
        ];
        expect(absent, isEmpty, reason: 'not in $library as written');
      });

      test('every public declaration of $library is listed', () {
        final listed = (blocks[library] ?? const <String>[]).join('\n');
        final missing = [
          for (final name in _publicDeclarations(source))
            if (!RegExp('\\b${RegExp.escape(name)}\\b').hasMatch(listed)) name,
        ];
        expect(missing, isEmpty, reason: 'exported by $library but unlisted');
      });
    }
  });
}

/// Every library [barrel] exports, following nested barrels, in export order,
/// keeping only libraries that declare something public themselves - a barrel
/// that merely re-exports has no block of its own.
List<String> _exportedLibraries(String barrel) {
  final result = <String>[];
  void visit(String path) {
    final source = File(path).readAsStringSync();
    final directory = path.substring(0, path.lastIndexOf('/'));
    if (_publicDeclarations(source).isNotEmpty) result.add(path);
    for (final m in RegExp(
      r"^export '([^':]+)'",
      multiLine: true,
    ).allMatches(source)) {
      visit('$directory/${m.group(1)}');
    }
  }

  visit(barrel);
  return result..remove(barrel);
}

/// The lines of each ```dart block under `## API`, keyed by the library path
/// its `### \`lib/…\`` heading names.
Map<String, List<String>> _apiBlocks(String readme) {
  final start = readme.indexOf('\n## API\n');
  if (start < 0) return const {};
  final rest = readme.substring(start + 1);
  final end = rest.indexOf('\n## ', 1);
  final section = end < 0 ? rest : rest.substring(0, end);

  final blocks = <String, List<String>>{};
  String? library;
  var inBlock = false;
  for (final line in section.split('\n')) {
    final heading = RegExp(r'^### `(lib/[^`]+)`').firstMatch(line);
    if (heading != null) {
      library = heading.group(1);
      continue;
    }
    if (line.startsWith('```')) {
      inBlock = !inBlock;
      continue;
    }
    if (inBlock && library != null && line.trim().isNotEmpty) {
      blocks.putIfAbsent(library, () => []).add(line);
    }
  }
  return blocks;
}

/// [text] reduced to its tokens: no whitespace, no trailing commas.
String _tokens(String text) => text
    .replaceAll(RegExp(r'\s+'), '')
    .replaceAllMapped(RegExp(r',([)}\]])'), (m) => m.group(1)!);

/// [source] with `//` and `/* */` comments removed. A `//` counts only at the
/// start of a line or after whitespace, which is how `dart format` lays out
/// every comment — and what keeps the `http://` in a URL default intact.
String _stripComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'(^|\s)//[^\n]*', multiLine: true), '');

/// The public names [source] declares: top-level declarations in column 0, and
/// the members of public classes in column 2.
List<String> _publicDeclarations(String source) {
  final names = <String>[];
  var inPublicClass = false;
  for (final line in _stripComments(source).split('\n')) {
    if (line.trim().isEmpty) continue;
    final column = line.length - line.trimLeft().length;
    final text = line.trim();
    if (column == 0) {
      if (text.startsWith('}')) {
        inPublicClass = false;
        continue;
      }
      if (RegExp(r'^(library|import|export|part)\b').hasMatch(text)) continue;
      // A multi-line annotation opens and closes in column 0 too; neither line
      // declares anything.
      if (text.startsWith('@') || text.startsWith(')')) continue;
      final type = RegExp(
        r'^(?:abstract |final |sealed |base |interface )*(?:class|mixin|enum|typedef|extension)\s+(\w+)',
      ).firstMatch(text);
      if (type != null) {
        final name = type.group(1)!;
        inPublicClass = !name.startsWith('_');
        if (inPublicClass) names.add(name);
        continue;
      }
      final name = _declaredName(text);
      if (name != null && !name.startsWith('_')) names.add(name);
    } else if (column == 2 && inPublicClass) {
      if (text.startsWith('@') || text.startsWith('}')) continue;
      final name = _declaredName(text);
      if (name != null && !name.split('.').last.startsWith('_')) {
        names.add(name.split('.').first);
      }
    }
  }
  return names;
}

/// The name a declaration line introduces: the identifier after `get`/`set`,
/// or the one directly before `(`, `=`, `;` or a type-parameter list.
String? _declaredName(String text) {
  final accessor = RegExp(r'\b(?:get|set)\s+(\w+)').firstMatch(text);
  if (accessor != null) return accessor.group(1);
  final match = RegExp(
    r'([A-Za-z_][\w.]*)\s*(?:<[^>(]*>)?\s*(?:\(|=|;)',
  ).firstMatch(text);
  return match?.group(1);
}
