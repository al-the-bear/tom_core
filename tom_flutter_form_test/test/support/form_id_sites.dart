/// Reads the `formId:` / `listId:` literals out of this package's source.
///
/// Two tests need the same list and would otherwise carry two copies of the
/// pattern that produces it:
///
/// * `form_ids_are_usable_scope_ids_test.dart` — every id under `lib/` is one
///   the kernel accepts as a scope id.
/// * `example_key_maps_follow_form_ids_test.dart` — the ids under
///   `lib/examples/` are exactly the ones the example resource and
///   authorization maps are keyed by.
///
/// A pattern that stopped matching would empty *both* lists, and an empty list
/// reads as "every id is fine" unless something objects. Each caller therefore
/// keeps its own emptiness guard: the first asserts the list is non-empty, the
/// second compares it against forms it constructs, so a silent zero fails there
/// too.
///
/// The ids are read from the source rather than from constructed forms because
/// constructing every form in the package means binding every state class it
/// needs; the literal in the constructor is the thing under test and it is
/// right there.
library;

import 'dart:io';

/// `formId: 'x'` / `listId: 'x'`, single- or double-quoted, as written in a
/// constructor's initialiser list or argument list.
final RegExp _idLiteral = RegExp(
  r'''\b(formId|listId)\s*:\s*(?:'([^'\n]*)'|"([^"\n]*)")''',
);

/// `${expr}` or `$identifier` inside an id literal.
final RegExp _interpolation = RegExp(r'\$\{[^}]*\}|\$[A-Za-z_][A-Za-z0-9_]*');

/// Stands in for an interpolated value: a legal single segment, so what a
/// caller judges is the constant text the author typed around it.
const interpolationPlaceholder = 'x';

/// Where an id was written, so a failure names the line to edit.
///
/// [id] is the literal as written; [testable] is it with interpolations
/// replaced by [interpolationPlaceholder]. One id in this package is built at
/// construction time (`'phase5cFamily-${family.kind.name}'`), and its runtime
/// value is not knowable from the source — substituting keeps the *constant*
/// text assertable, which is the part a reader can get wrong while typing.
typedef IdSite = ({
  String file,
  int line,
  String kind,
  String id,
  String testable,
});

/// Every `formId` / `listId` literal written under [root] (default `lib`).
///
/// [root] is relative to the package root, which is the working directory
/// `flutter test` runs in.
List<IdSite> idSites({String root = 'lib'}) {
  final sites = <IdSite>[];
  for (final entity in Directory(root).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final lines = entity.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      for (final match in _idLiteral.allMatches(lines[i])) {
        final id = match.group(2) ?? match.group(3)!;
        sites.add((
          file: entity.path,
          line: i + 1,
          kind: match.group(1)!,
          id: id,
          testable: id.replaceAll(_interpolation, interpolationPlaceholder),
        ));
      }
    }
  }
  return sites;
}
