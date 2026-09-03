import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Holds every module inventory in this package level with the folder.
///
/// `lib/src/tomclient/` is the only thing that says what modules exist. Eight
/// other places *describe* that set — the refactoring guide's Target Modules
/// table, its per-module checklist and its prose counts, the package barrel,
/// and the four per-module artifact families — and every one of them is written
/// by hand. For weeks they disagreed with the folder and with each other:
/// `configuration` and `preferences` were added and `forms/` was deleted while
/// the guide went on naming the deleted module and omitting the two live ones
/// (tcinc1111).
///
/// Nothing caught it, because the sibling guard in
/// `example_instructions_test.dart` is deliberately a **floor** — its own
/// comment says so — and a floor cannot notice an addition. That asymmetry is
/// the whole defect: adding a module is exactly the change that leaves every
/// hand-written list behind. These tests are the **census** the floor is not:
/// each asserts set *equality*, so drift fails in both directions.
void main() {
  /// The modules that exist — the one authority every other list answers to.
  Set<String> liveModules() => Directory('lib/src/tomclient')
      .listSync()
      .whereType<Directory>()
      .map((d) => d.uri.pathSegments[d.uri.pathSegments.length - 2])
      .toSet();

  final guidePath = '_copilot_guidelines/refactoring_guide.md';
  final guide = File(guidePath).readAsStringSync();

  /// The `## Target Modules` section, up to the horizontal rule that ends it.
  String targetModulesSection() {
    final start = guide.indexOf('## Target Modules');
    expect(
      start,
      isNot(-1),
      reason: '$guidePath has no Target Modules section',
    );
    final end = guide.indexOf('\n---', start);
    return guide.substring(start, end == -1 ? guide.length : end);
  }

  test('the guide\'s Target Modules table names every module and no other', () {
    // The table's own caption is "keep in sync with the folder", so it states
    // the contract this asserts. It is the inventory a reader meets first, and
    // the one that named `forms/` for four weeks after `forms/` was deleted.
    final tabled = RegExp(
      r'^\| `([a-z_]+)/` \|',
      multiLine: true,
    ).allMatches(targetModulesSection()).map((m) => m.group(1)!).toSet();
    expect(
      tabled,
      liveModules(),
      reason:
          'the Target Modules table in $guidePath must list exactly the '
          'directories under lib/src/tomclient/',
    );
  });

  test('every live module has a per-module checklist entry', () {
    // Subset, not equality, and deliberately: a module that has been *removed*
    // keeps its checklist entry as the record of the pass that removed it
    // (`camera/`, `forms/`, `localstorage/`, `qrcode/`). An entry for a module
    // that no longer exists is therefore history and correct. A live module
    // with no entry is the fault — it reads as never having been visited,
    // which is what `configuration` read as until tcinc1111.
    final listed = RegExp(
      r'Per-module pass — `([a-z_]+)/`',
    ).allMatches(guide).map((m) => m.group(1)!).toSet();
    final missing = liveModules().difference(listed);
    expect(
      missing,
      isEmpty,
      reason:
          'these modules exist but no per-module checklist step in '
          '$guidePath mentions them, so they read as unvisited: $missing',
    );
  });

  test('every current module count in the guide is the real one', () {
    // The guide states the count in prose three times, and prose counts are
    // exactly what went stale ("six" survived two additions and a removal).
    // The convention that makes this checkable is already the guide's own:
    // **bold** is a claim about *now* and must be true; a plain number is
    // date-anchored history ("six at OT2") and stays as written.
    final expected = _numberWords[liveModules().length];
    expect(
      expected,
      isNotNull,
      reason:
          'no spelled-out form for ${liveModules().length} modules — extend '
          '_numberWords',
    );
    final claimed = RegExp(
      '\\*\\*(${_numberWords.values.join('|')})\\*\\*',
    ).allMatches(guide).map((m) => m.group(1)!).toSet();
    expect(
      claimed,
      anyOf(isEmpty, equals({expected})),
      reason:
          'a bolded number in $guidePath is a claim about the package as '
          'it is now, and there are ${liveModules().length} modules. Either '
          'correct it to "$expected", or — if it is a historical figure — '
          'unbold it and anchor it to its date, as "six at OT2" is.',
    );
  });

  test('the barrel exports exactly the live modules', () {
    // Equality both ways: an export of a deleted module would not compile, but
    // a module absent from the barrel compiles perfectly and is simply
    // unreachable for every consumer — the failure `security/authentication`
    // had before OT2.
    final barrel = File('lib/tom_core_flutter.dart').readAsStringSync();
    // Anchored to the line start, so a *commented-out* export does not count
    // as one — which is how a module most plausibly drops out of the barrel,
    // and which an unanchored pattern reads as still present.
    final exported = RegExp(
      r"^export 'src/tomclient/([a-z_]+)/",
      multiLine: true,
    ).allMatches(barrel).map((m) => m.group(1)!).toSet();
    expect(
      exported,
      liveModules(),
      reason: 'lib/tom_core_flutter.dart must export from every module',
    );
  });

  test('every module carries the full artifact set', () {
    // The five things a module is expected to ship beside its code. Checking
    // them per module rather than per artifact type is what makes a *new*
    // module inherit the whole expectation the moment its directory appears —
    // `configuration` reached a release with four of the five, missing only
    // the module readme, and no list noticed.
    final offenders = <String>[];
    for (final module in liveModules().toList()..sort()) {
      for (final path in <String>[
        'lib/src/tomclient/$module/readme.md',
        'doc/$module.md',
        'doc/api_reference/api_summary_$module.md',
        'test/${module}_test.dart',
      ]) {
        if (!File(path).existsSync()) offenders.add(path);
      }
      if (!Directory('example/$module').existsSync()) {
        offenders.add('example/$module/');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'every module ships a readme, a doc page, an API summary, an '
          'example folder and a suite; these are missing:\n'
          '${offenders.join('\n')}',
    );
  });

  test('no artifact survives the module it documents', () {
    // The other direction: deleting a module must take its documentation with
    // it. `forms/` left `doc/forms.md` behind once already, which is how a
    // deleted module goes on looking supported.
    final live = liveModules();
    final offenders = <String>[];

    void check(String path, String module) {
      if (!live.contains(module)) offenders.add('$path (no module "$module")');
    }

    for (final file in Directory('doc').listSync().whereType<File>()) {
      final name = file.uri.pathSegments.last;
      if (!name.endsWith('.md') || _nonModuleDocs.contains(name)) continue;
      check('doc/$name', name.substring(0, name.length - 3));
    }
    for (final file in Directory(
      'doc/api_reference',
    ).listSync().whereType<File>()) {
      final name = file.uri.pathSegments.last;
      if (!name.startsWith('api_summary_') || _nonModuleDocs.contains(name)) {
        continue;
      }
      check(
        'doc/api_reference/$name',
        name.substring('api_summary_'.length, name.length - 3),
      );
    }
    for (final dir in Directory('example').listSync().whereType<Directory>()) {
      final name = dir.uri.pathSegments[dir.uri.pathSegments.length - 2];
      check('example/$name/', name);
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'these document a module that no longer exists:\n'
          '${offenders.join('\n')}',
    );
  });
}

/// Documents under `doc/` that describe the package rather than one module.
const _nonModuleDocs = <String>{'review_findings.md', 'api_summary_index.md'};

/// Spelled-out counts, for checking the guide's prose against the folder.
const _numberWords = <int, String>{
  1: 'one',
  2: 'two',
  3: 'three',
  4: 'four',
  5: 'five',
  6: 'six',
  7: 'seven',
  8: 'eight',
  9: 'nine',
  10: 'ten',
};
