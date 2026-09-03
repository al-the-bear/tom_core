import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The modules whose readme claims to be a *complete* inventory of what the
/// module exports.
///
/// Not every module can make that claim, and this list is the honest half of
/// saying so. `widgets/` exports 290 mostly-mechanical Flutter wrappers and
/// `widget_base/` 24 `…Base` types; enumerating either would produce a worse
/// document than the summary that is there, so neither is checked. The four
/// below are small enough that "the table lists everything" is both true and
/// useful — and that is exactly the claim that rots, because adding a type to a
/// module is a one-line edit away from leaving the table behind.
///
/// A module joins this list by having a readme that already lists everything.
/// Never add one and then loosen the assertions to accommodate it.
const _inventoryModules = ['actions', 'groups', 'resource_auth', 'theme'];

/// A public top-level declaration. The leading alternation is the modifier
/// soup Dart allows (`abstract base class`, `mixin class`, `sealed class`);
/// the captured group is the name.
final _declaration = RegExp(
  r'^(?:abstract\s+|base\s+|final\s+|sealed\s+|interface\s+|mixin\s+)*'
  r'(?:class|mixin|enum|extension|typedef)\s+(\w+)',
  multiLine: true,
);

/// A `static` member, including `static get` / `static set` and
/// `static const` fields. Matching the declaration rather than a call site is
/// what keeps this derived from the source instead of from a hand-kept list —
/// a hand-kept list is the same artifact as the table it is guarding, and would
/// go stale with it.
final _staticMember = RegExp(
  r'^\s*static\s+(?:[\w<>,\s?]+\s+)?(?:get\s+|set\s+)?(\w+)\s*[({=;]',
  multiLine: true,
);

final _export = RegExp(r"^export\s+'([^']+)'", multiLine: true);

/// A fenced code block, stripped before scanning: the samples inside are
/// compiled by the doc-sample gate, and re-checking them here would duplicate
/// a stronger check with a weaker one.
final _fencedBlock = RegExp(r'```.*?```', dotAll: true);

/// An inline code span. A span counts as a type claim only when the whole of
/// its content is a bare `Tom…` identifier, which is what lets `TomAnimated…`
/// and `TomAnimated*` (abbreviations), `TomWidgetFamily.button` (a member) and
/// `tomId` (a parameter) fall out without being special-cased.
final _inlineCode = RegExp(r'`([^`\n]+)`');

final _bareTomType = RegExp(r'^Tom[A-Z]\w*$');

/// The `lib/` root of a package this one depends on, via the package config.
///
/// The documents describe how the kit composes with `tom_core_kernel`, so a
/// name like `TomAuthState` is a real reference that this package's own
/// sources cannot resolve. Reading `.dart_tool/package_config.json` rather
/// than guessing at `../tom_core_kernel` keeps the check working under any
/// checkout layout, and avoids the alternative of an allowlist — the package
/// README alone names twenty-five kernel types, and a hand-kept list of them
/// would rot exactly like the table it is meant to guard.
Directory _packageLib(String name) {
  final config =
      jsonDecode(File('.dart_tool/package_config.json').readAsStringSync())
          as Map<String, dynamic>;
  final entry = (config['packages'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((p) => p['name'] == name);
  var root = entry['rootUri'] as String;
  if (!root.endsWith('/')) root = '$root/';
  final base = Directory('.dart_tool').absolute.uri;
  return Directory.fromUri(
    base.resolve(root).resolve(entry['packageUri'] as String),
  );
}

/// Every type declared under [root], private ones included — a document has
/// no business naming those either, so there is nothing to filter out.
Set<String> _typesDeclaredIn(Directory root) {
  final out = <String>{};
  final files = root
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));
  for (final file in files) {
    out.addAll(
      _declaration.allMatches(file.readAsStringSync()).map((m) => m.group(1)!),
    );
  }
  return out;
}

/// The documents that describe what the package *is*: the package README and
/// every module readme.
///
/// `doc/` is deliberately not here. It carries design material that names
/// types on purpose before they exist — `tom_observable_state_management.md`
/// flags `TomLabel`, `TomPanel` and `TomMenuItem` as proposed names that do
/// not ship, and points at the shipped substitute for each. That document is
/// already telling the truth, and a check that failed it would be pressuring
/// a correct document to stop saying something useful.
List<File> _surfaceDocuments() => [
  File('README.md'),
  ...Directory('lib/src')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('readme.md')),
]..sort((a, b) => a.path.compareTo(b.path));

/// The source of every file the module's barrel re-exports.
///
/// Going through the barrel rather than globbing the directory is deliberate:
/// a file that exists but is not exported is not part of the public surface,
/// and demanding the readme document it would be wrong.
List<String> _exportedSources(String module) {
  final dir = 'lib/src/$module';
  final barrel = File('$dir/$module.dart').readAsStringSync();
  return _export
      .allMatches(barrel)
      .map((m) => File('$dir/${m.group(1)}'))
      .where((f) => f.existsSync())
      .map((f) => f.readAsStringSync())
      .toList();
}

Set<String> _publicNames(List<String> sources, RegExp pattern) => sources
    .expand(pattern.allMatches)
    .map((m) => m.group(1)!)
    .where((n) => !n.startsWith('_'))
    .toSet();

void main() {
  group('module readmes list the surface their module exports', () {
    for (final module in _inventoryModules) {
      final sources = _exportedSources(module);
      final readme = File('lib/src/$module/readme.md').readAsStringSync();

      test('$module/readme.md names every public type', () {
        final types = _publicNames(sources, _declaration);
        expect(
          types,
          isNotEmpty,
          reason:
              'found no public types in $module — the barrel parse or '
              'the declaration pattern is broken, not the readme',
        );

        final missing = types.where((t) => !readme.contains(t)).toList()
          ..sort();
        expect(
          missing,
          isEmpty,
          reason:
              'lib/src/$module/$module.dart exports these public types '
              'and lib/src/$module/readme.md never names them: $missing',
        );
      });

      test('$module/readme.md names every public static entry point', () {
        // Types alone are not the surface. The omission that prompted this
        // check was the teardown half of resource_auth's lifecycle —
        // `reset` and the `clearCustom…` pair — none of which a table of
        // types has a row for, and all of which are what authors get wrong.
        final statics = _publicNames(sources, _staticMember);
        final missing = statics.where((s) => !readme.contains(s)).toList()
          ..sort();
        expect(
          missing,
          isEmpty,
          reason:
              'lib/src/$module declares these public statics and '
              'lib/src/$module/readme.md never names them: $missing',
        );
      });
    }
  });

  // The group above asks whether a readme omits something real. This asks the
  // opposite question, and it is the one that actually bit: the widgets
  // readme and the package README both offered `TomLabel` as a representative
  // of the label family, and no such type has ever been declared anywhere in
  // the package. That failure is worse than an omission — an omission leaves
  // a reader with less than the truth, whereas a phantom sends them looking
  // for something that was never there, with no way to tell a rename from a
  // deletion from a typo.
  //
  // This runs over every surface document, not just the four modules with
  // inventory tables, because naming a type costs nothing and all of them
  // do it.
  group('surface documents name only types that exist', () {
    final declared = _typesDeclaredIn(
      Directory('lib/src'),
    ).union(_typesDeclaredIn(_packageLib('tom_core_kernel')));
    final documents = _surfaceDocuments();

    test('tccg1-01: the scan finds documents and declarations to compare', () {
      // Without this, a glob that silently matched nothing — or a package
      // config that resolved the kernel to an empty directory — would make
      // the check below pass by having no input to disagree with. That is the
      // failure mode that makes a derived test worthless exactly when it is
      // needed.
      expect(
        documents.length,
        greaterThanOrEqualTo(10),
        reason:
            'found ${documents.length} surface documents — the scan is '
            'broken, not the documents',
      );
      expect(
        declared.length,
        greaterThan(500),
        reason:
            'found only ${declared.length} declarations — the pattern '
            'or the package-config resolution is broken',
      );
      expect(declared, contains('TomText'), reason: 'local types missing');
      expect(
        declared,
        contains('TomAuthState'),
        reason: 'kernel types missing — package-config resolution broke',
      );
    });

    test('tccg1-02: every bare Tom type a document names is declared', () {
      final faults = <String>[];
      for (final document in documents) {
        final prose = document.readAsStringSync().replaceAll(_fencedBlock, '');
        final phantom =
            _inlineCode
                .allMatches(prose)
                .map((m) => m.group(1)!)
                .where(_bareTomType.hasMatch)
                .toSet()
                .difference(declared)
                .toList()
              ..sort();
        faults.addAll(phantom.map((t) => '${document.path}: $t'));
      }
      expect(
        faults,
        isEmpty,
        reason:
            'these documents name a type that is declared neither in '
            'this package nor in tom_core_kernel: $faults',
      );
    });
  });
}
