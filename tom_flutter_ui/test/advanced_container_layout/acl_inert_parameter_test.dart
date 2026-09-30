import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// No public field of this unit is stored and never consumed.
///
/// `parentIdPath` was: declared on four types, bound in four constructors,
/// forwarded four times, and read nowhere. A public parameter that does nothing
/// is a false affordance — a caller who needs to control the id path finds it,
/// sets it, and gets no effect and no error — and it has to be threaded through
/// every `copyWith` and every rebuild pass on the way to doing nothing.
///
/// The property is checkable because *every* occurrence of an inert field is
/// one of three forms. Two naive versions of this check passed on the tree that
/// still contained `parentIdPath`, which is how the third form was found:
///
/// | Form | Example | A read? |
/// | ---- | ------- | ------- |
/// | declaration | `final String? parentIdPath;` | no |
/// | constructor binding | `this.parentIdPath,` / `super.parentIdPath,` | no |
/// | **forward** | `parentIdPath: parentIdPath,` / `parentIdPath: _parentIdPath,` | **no** |
///
/// A forward is a *write* into another constructor's parameter, not a use of
/// the value. Missing that is what made the first two attempts vacuous: they
/// skipped `x: x,` and counted `x: _x,` as a read.
///
/// The check runs at **name** granularity across the whole package, tests and
/// examples included, so one genuine read anywhere clears every type that
/// carries the name — which is correct for the question being asked, *is this
/// parameter consumed at all*. It errs toward leniency: a field whose name
/// happens to appear in unrelated code reads as used. That is the safe
/// direction for a heuristic, and the reason this is a test of the unit rather
/// than of the package.
/// The fields that are inert today, each one a measurement rather than a
/// licence.
///
/// Held **exactly, in both directions**: a new inert field fails because it is
/// not on this list, and wiring one of these in fails until it is taken off. So
/// the set can only shrink, and shrinking it is a deliberate edit.
///
/// Empty. `aclGroup` was the last entry, and it is now the outermost default
/// of a component's group chain (`_componentGroup` in
/// `acl_container_identity.dart`).
const _knownInert = <String>{};

void main() {
  /// `  final <Type> <name>;` — a public instance field, two-space indented.
  final declaration = RegExp(
    r'^\s{2}final\s+[\w<>,\s?\[\]]+?\s+(\w+);\s*$',
    multiLine: true,
  );

  List<File> dartFilesUnder(String dir) => Directory(dir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('no public field of the unit is stored without being read', () {
    final unit = dartFilesUnder('lib/src/advanced_container_layout');
    expect(
      unit,
      isNotEmpty,
      reason: 'the scan found no sources — it is broken',
    );

    final fields = <String>{
      for (final file in unit)
        for (final m in declaration.allMatches(file.readAsStringSync()))
          if (!m.group(1)!.startsWith('_')) m.group(1)!,
    };
    expect(
      fields.length,
      greaterThan(50),
      reason:
          'the unit declares scores of public fields; far fewer means the '
          'declaration pattern stopped matching rather than the unit shrinking',
    );

    // Comments are stripped, and this file is excluded from its own haystack.
    // Both for the same reason: a field *named* is not a field *read*. Prose
    // explaining why the container's `aclGroup` reaches variant rows without
    // being copied would otherwise certify `aclGroup` as consumed, and naming
    // a field in [_knownInert] would make the exception list certify the very
    // thing it records.
    final lines = [
      for (final file in [
        ...dartFilesUnder('lib'),
        ...dartFilesUnder('test'),
        ...dartFilesUnder('example'),
      ])
        if (!file.path.endsWith('acl_inert_parameter_test.dart'))
          for (final line in file.readAsLinesSync())
            if (!line.trimLeft().startsWith('//')) line,
    ];

    final inert = <String>[];
    for (final name in fields) {
      final mention = RegExp(r'\b' + name + r'\b');
      final declares = RegExp(r'^final\s+[\w<>,\s?\[\]]+\s+' + name + r';$');
      final binds = RegExp(
        r'^(required\s+)?(this|super)\.' + name + r'(\s*=\s*[^,]+)?,?$',
      );
      // `name: <identifier chain>,` — a write into another constructor's
      // parameter of the same name, not a use of this field's value.
      final forwards = RegExp(r'^' + name + r':\s*[\w.!]+\s*,?$');
      final read = lines.any((line) {
        final t = line.trim();
        if (!mention.hasMatch(t)) return false;
        return !declares.hasMatch(t) &&
            !binds.hasMatch(t) &&
            !forwards.hasMatch(t);
      });
      if (!read) inert.add(name);
    }
    inert.sort();

    expect(
      inert.toSet().difference(_knownInert).toList()..sort(),
      isEmpty,
      reason:
          'these public fields of advanced_container_layout are declared, '
          'bound and forwarded, and never consumed — either wire each into the '
          'behaviour it names or delete it: $inert',
    );
    expect(
      _knownInert.difference(inert.toSet()).toList()..sort(),
      isEmpty,
      reason:
          'these fields are listed as inert and are now read — take them off '
          '_knownInert, so the list keeps meaning what it says',
    );
  });
}
