import 'dart:io';

import 'package:test/test.dart';
import 'package:path/path.dart' as p;

/// How this package refers to its own libraries, in both directions, and
/// whether the barrel still reaches every module.
///
/// Inside `lib/`, a sibling module is reached by a relative path. Outside it —
/// from `test/`, `example/` or `tool/` — the same module is reached by a
/// `package:` URI. Each side has exactly one correct form, and the wrong one
/// resolves anyway, so no mistake announces itself:
///
/// 1. **`package:tom_core_kernel/src/…` inside `lib/`.** A `package:` URI that
///    reaches into a `src/` tree is what the `implementation_imports` lint
///    exists to refuse; it stays silent here only because the package is
///    importing *itself*. The line therefore reads as a sanctioned instance of
///    a pattern banned everywhere else, and it is the shape a copy-paste into
///    another package carries over — where it is a genuine violation.
/// 2. **`package:tom_core_kernel/tom_core_kernel.dart` inside `lib/`.** A file
///    under `lib/src/` that imports the barrel is importing the library that
///    exports it. It pulls in the whole package — every module, plus
///    `tom_basics`, `tom_crypto` and `tom_reflection` — to reach a handful of
///    symbols; it erases the dependency graph, since a module that appears to
///    depend on everything says the same as one that declares nothing, and
///    that graph is what tells you whether a module can be lifted out and what
///    an edit in it can reach; and it makes the file's own exports reachable
///    through a cycle back to itself.
/// 3. **`../lib/…` from outside `lib/`.** A relative path into `lib/` gives the
///    file a second library identity, so the same class arrives under two
///    types and `is` checks start failing on values that are obviously the
///    right thing.
///
/// Rules 1 and 3 are caught by no lint the shared options enable: neither
/// `implementation_imports` nor `avoid_relative_lib_imports` is among them.
///
/// Rule 2 *is* a lint — `prefer_relative_imports`, enabled in
/// `tom_ai/core/analysis_options.yaml` — and that is the reason for the last
/// test in the first group rather than an argument against it. The rule's
/// default severity is `info`, and `dart analyze` prints an info and then exits
/// **zero**: measured, by planting a barrel import and reading the exit code.
/// So the rule that was relied on to stop this shape returning was being
/// reported and not enforced. The options now raise it to `warning`, and the
/// severity itself is asserted here — a lint is only load-bearing while the
/// gate can fail on it, and a severity is one line for a later edit to lower.
///
/// Rule 2 is worth all of that because the cause is structural. Every module
/// readme opens with the barrel import, because that *is* the right import for
/// a consumer; copying that quick-start line into a source file is the natural
/// mistake, and a natural mistake will be made again. It was made six times in
/// `http_connection` alone.
///
/// The last group is the counterpart of rule 2: `lib/src` files stop reaching
/// for the barrel only while the barrel still reaches them, so a module no
/// export mentions is unreachable to consumers however tidy its imports.
void main() {
  // ===========================================================================
  // Import convention
  // ===========================================================================
  group('import convention', () {
    test('no library under lib/ reaches into this package\'s src/', () {
      expect(_selfSrcImportsInLib(), isEmpty, reason: _selfSrcReason);
    });

    test('no library under lib/ imports the package barrel', () {
      expect(_barrelImportsInLib(), isEmpty, reason: _barrelReason);
    });

    test('nothing outside lib/ reaches into lib/ by relative path', () {
      expect(_relativeLibImports(), isEmpty, reason: _relativeLibReason);
    });

    test('the lint that catches the barrel import can fail the gate', () {
      // `prefer_relative_imports` defaults to `info`, and an info does not
      // change `dart analyze`'s exit code — so enabling the rule reports the
      // shape without stopping it. The workspace's quality gate is that
      // command, which makes the severity the load-bearing half of the
      // configuration and the half nothing else would notice losing.
      final options = File(
        p.join('..', 'analysis_options.yaml'),
      ).readAsStringSync();
      expect(
        options,
        contains(RegExp(r'prefer_relative_imports:\s*(warning|error)')),
        reason:
            'tom_ai/core/analysis_options.yaml no longer raises '
            'prefer_relative_imports above its default `info` severity. At '
            '`info` the rule is printed and `dart analyze` still exits 0, so '
            'a library that imports its own barrel passes the gate.',
      );
    });
  });

  // ===========================================================================
  // Barrel coverage
  // ===========================================================================
  group('the barrel reaches every module', () {
    test('every module directory is exported', () {
      expect(_unexportedModules(), isEmpty, reason: _unexportedReason);
    });

    test('the scan reads the modules it claims to check', () {
      // A walk that found no directories would pass the assertion above by
      // having nothing to judge. The module names are not listed here — that
      // would be the same "written once, never revisited" list this file exists
      // to avoid — so a floor and one known member is what pins it.
      final modules = _moduleDirectories();
      expect(modules.length, greaterThan(10));
      expect(modules, contains('http_connection'));
    });
  });
}

// -----------------------------------------------------------------------------
// The two rules
// -----------------------------------------------------------------------------

/// A `package:` URI pointing into this package's own `src/` tree.
///
/// Matched anywhere on the line, not only in a directive: this spelling is
/// wrong in a doc comment too, where it reads as an instruction.
final _selfSrcImport = RegExp(r'''package:tom_core_kernel/src/''');

/// An `import` or `export` of this package by name, other than into `src/`,
/// which [_selfSrcImport] already reports.
///
/// A **directive** rather than any line, unlike the rule above. A dartdoc that
/// shows `import 'package:tom_core_kernel/tom_core_kernel.dart';` is showing a
/// consumer the right thing to write, and refusing it would make the guard
/// argue against the documentation it is supposed to protect. What costs the
/// dependency graph is the directive.
final _barrelImport = RegExp(
  r'''^\s*(?:import|export)\s+['"]package:tom_core_kernel/(?!src/)''',
);

/// A relative path that climbs into `lib/`, e.g. `'../lib/src/…'`.
final _relativeLibImport = RegExp(
  r'''^\s*(?:import|export)\s+['"](?:\.\./)*lib/''',
  multiLine: false,
);

/// Generated sources carry whatever the generator emits, and are corrected by
/// regenerating rather than by editing.
bool _isGenerated(String path) =>
    path.endsWith('.reflection.dart') || path.endsWith('.g.dart');

// -----------------------------------------------------------------------------
// The scans
// -----------------------------------------------------------------------------

/// Returns `'<path>:<line>: <text>'` for every `lib/` line matching
/// [_selfSrcImport].
List<String> _selfSrcImportsInLib() => _scan(['lib'], _selfSrcImport);

/// Returns `'<path>:<line>: <text>'` for every `lib/` line matching
/// [_barrelImport].
///
/// The barrel itself is exempt: exporting `src/` is exactly its job, and it is
/// also where the two `package:` re-exports of `tom_basics` and `tom_crypto`
/// belong.
List<String> _barrelImportsInLib() =>
    _scan(['lib'], _barrelImport).where((line) => !_isBarrel(line)).toList();

/// Whether an offender line comes from the barrel library itself.
bool _isBarrel(String offender) =>
    offender.startsWith('lib/tom_core_kernel.dart:') ||
    offender.startsWith('lib${Platform.pathSeparator}tom_core_kernel.dart:');

/// Returns `'<path>:<line>: <text>'` for every line outside `lib/` matching
/// [_relativeLibImport].
List<String> _relativeLibImports() =>
    _scan(['test', 'example', 'tool'], _relativeLibImport);

/// The module directory names under `lib/src/tombase`, sorted.
List<String> _moduleDirectories() =>
    Directory('lib/src/tombase')
        .listSync()
        .whereType<Directory>()
        .map((entity) => entity.path.split(Platform.pathSeparator).last)
        .toList()
      ..sort();

/// The module directories the barrel exports nothing from.
List<String> _unexportedModules() {
  final barrel = File('lib/tom_core_kernel.dart').readAsStringSync();
  return _moduleDirectories()
      .where((module) => !barrel.contains('src/tombase/$module/'))
      .toList();
}

List<String> _scan(List<String> directories, RegExp pattern) {
  final offenders = <String>[];

  for (final directory in directories) {
    final dir = Directory(directory);
    if (!dir.existsSync()) continue;

    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File) continue;
      final path = entity.path;
      if (!path.endsWith('.dart')) continue;
      // Generated sources carry whatever the generator emits and are corrected
      // by regenerating, never by editing.
      if (_isGenerated(path)) continue;
      // This file states the patterns it refuses, so it matches both.
      if (path.endsWith('import_convention_test.dart')) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!pattern.hasMatch(lines[i])) continue;
        offenders.add('$path:${i + 1}: ${lines[i].trim()}');
      }
    }
  }

  return offenders;
}

const _selfSrcReason =
    'A library under lib/ imports this package through a package: URI into '
    'src/. Use the relative path to the sibling module instead — the package: '
    'form is what implementation_imports refuses for every other package, and '
    'it only passes here because the package is importing itself.';

const _barrelReason =
    'A library under lib/ imports the barrel that exports it. Import the '
    'specific src files it uses instead — a relative path to a sibling '
    'module, a package: URI for a real dependency. The barrel pulls in every '
    'module to reach a handful of symbols, erases what this module actually '
    'depends on, and makes the file reachable from itself.';

const _unexportedReason =
    'These module directories are exported by nothing in '
    'lib/tom_core_kernel.dart, so no consumer can reach them. A module that '
    'the barrel does not name is unreachable however tidy its own imports.';

const _relativeLibReason =
    'A file outside lib/ reaches into lib/ by relative path. Import it as '
    'package:tom_core_kernel/... instead: a relative path gives the library a '
    'second identity, so the same class arrives under two distinct types.';
