import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What a module readme claims about the surface its module exports.
///
/// Every module is classified, and that is the point of the enum rather than a
/// list: an opt-in list is silent about the modules outside it, so a module can
/// sit uncovered without anyone deciding it should. `custom/` did — it passed
/// the inventory assertions all along and was simply never added.
enum _Claim {
  /// The readme names every public type and static the module barrel exports.
  ///
  /// This is the claim that rots, because adding a type to a module is a
  /// one-line edit away from leaving the table behind. A module earns this
  /// classification by having a readme that already lists everything. Never
  /// move a module here and then loosen the assertions to accommodate it.
  inventory,

  /// The readme states the rule the module follows and points at the complete
  /// list, which lives somewhere that is itself checked.
  ///
  /// Reserved for the two catalogues, where enumerating in the readme would
  /// produce a worse document *and* a second copy of a list already kept:
  /// `widgets/` is 290 mechanical Flutter wrappers whose exhaustive list is
  /// `test/widgets/widget_conformance_registry.dart` (held to the module in
  /// both directions by that suite's registry-completeness case), and `forms/`
  /// is a parallel
  /// Material/Cupertino field catalogue whose exhaustive list is Appendix C of
  /// `doc/tom_ui_widgets_forms.md` (held to `lib/src/forms/fields` by
  /// `tool/check_doc_class_inventories.py`).
  ///
  /// The classification is not an excuse to say nothing. A `rule` readme must
  /// carry [_notAnInventoryMarker], so a reader is told the table is a sample
  /// before they conclude from its absence that a type does not exist.
  rule,
}

/// Every module under `lib/src/` that ships a readme, and what that readme
/// claims. `_everyModuleIsClassified` fails if the two ever disagree.
const _moduleClaims = <String, _Claim>{
  'actions': _Claim.inventory,
  'advanced_container_layout': _Claim.inventory,
  'custom': _Claim.inventory,
  'forms': _Claim.rule,
  'groups': _Claim.inventory,
  'resource_auth': _Claim.inventory,
  'theme': _Claim.inventory,
  'widget_base': _Claim.inventory,
  'widgets': _Claim.rule,
};

/// The callout a `rule` readme has to carry, verbatim.
///
/// Checking for a fixed string rather than reading the prose is deliberate: the
/// assertion is not that the readme is well written, it is that the reader was
/// *told* the table is partial. A marker either appears or it does not.
const _notAnInventoryMarker = '**Not an inventory.**';

/// The module barrel, which is not always `<module>/<module>.dart`.
///
/// `custom/` and `forms/` name theirs after what they hold
/// (`tom_custom_widgets.dart`, `tom_forms.dart`), and hard-coding the tidy
/// convention is what kept both out of this check: `_exportedSources` threw for
/// them, so classifying them was impossible without this lookup.
const _moduleBarrels = <String, String>{
  'custom': 'tom_custom_widgets.dart',
  'forms': 'tom_forms.dart',
};

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

/// A `### TypeName` heading in an API summary, with any generic parameter list
/// dropped — summaries write those escaped (`### TomAction\<TContext, TUndo\>`)
/// so the anchor renders, and the type's name is the part before the `<`.
final _typeHeading = RegExp(r'^###\s+(\w+)', multiLine: true);

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
  final barrelName = _moduleBarrels[module] ?? '$module.dart';
  final barrel = File('$dir/$barrelName').readAsStringSync();
  return [
    // The barrel itself, because a module may declare a type in it rather than
    // in a file beneath it. Omitting it made the barrel a blind spot.
    barrel,
    ..._export
        .allMatches(barrel)
        .map((m) => File('$dir/${m.group(1)}'))
        .where((f) => f.existsSync())
        .map((f) => f.readAsStringSync()),
  ];
}

Set<String> _publicNames(List<String> sources, RegExp pattern) => sources
    .expand(pattern.allMatches)
    .map((m) => m.group(1)!)
    .where((n) => !n.startsWith('_'))
    .toSet();

/// Whether [readme] names [symbol] as API, rather than merely containing the
/// letters somewhere.
///
/// A plain `readme.contains(symbol)` passes vacuously for every short name, and
/// this module set is full of them: `TomCtr` alone declares `text`, `list`,
/// `map`, `value` and `exists`, and `AclScope` declares `of`. Each of those is
/// a substring of ordinary English, so the readme could name none of them and
/// still pass — the check would be strongest exactly where the documentation is
/// least self-explanatory.
///
/// So a symbol counts only when it appears as a whole word inside an inline
/// code span, which is how every one of these readmes writes API. Whole-word
/// alone would not do: "one **of** them" is a word.
bool _names(String readme, String symbol) {
  final code = _inlineCode.allMatches(readme).map((m) => m.group(1)!).join(' ');
  return RegExp(r'(?<!\w)' + RegExp.escape(symbol) + r'(?!\w)').hasMatch(code);
}

/// The modules that ship a symbol-level API summary under `doc/api/`, mapped to
/// the file that carries it.
///
/// Discovered from disk rather than listed, for the reason the `_moduleClaims`
/// enum exists: a map alone is silent about a summary nobody added it to. The
/// two assertions below therefore start from `doc/api/` and derive the module
/// from the file name, so a new summary is covered the moment it lands.
Map<String, File> _apiSummaries() {
  final dir = Directory('doc/api');
  if (!dir.existsSync()) return const {};
  final out = <String, File>{};
  for (final file in dir.listSync().whereType<File>()) {
    final name = file.path.split(Platform.pathSeparator).last;
    final match = RegExp(r'^api_summary_(\w+)\.md$').firstMatch(name);
    if (match != null) out[match.group(1)!] = file;
  }
  return out;
}

void main() {
  test('every module with a readme is classified, and every classification '
      'names a module', () {
    // The check this whole file rests on. An unclassified module is not a
    // module that passes, it is one nobody has looked at — which is the state
    // `custom/`, `forms/`, `widget_base/`, `widgets/` and
    // `advanced_container_layout/` were all in while the opt-in list named
    // four of the nine.
    final onDisk = Directory('lib/src')
        .listSync()
        .whereType<Directory>()
        .map((d) => d.path.split(Platform.pathSeparator).last)
        .where((m) => File('lib/src/$m/readme.md').existsSync())
        .toSet();

    expect(
      onDisk,
      isNotEmpty,
      reason: 'found no module readmes — the scan is broken, not the tree',
    );
    expect(
      onDisk.difference(_moduleClaims.keys.toSet()).toList()..sort(),
      isEmpty,
      reason:
          'these modules ship a readme and _moduleClaims does not say what it '
          'claims — classify them rather than leaving them unchecked',
    );
    expect(
      _moduleClaims.keys.toSet().difference(onDisk).toList()..sort(),
      isEmpty,
      reason: '_moduleClaims names modules that no longer ship a readme',
    );
  });

  group('a rule readme says so', () {
    for (final module
        in _moduleClaims.entries
            .where((e) => e.value == _Claim.rule)
            .map((e) => e.key)) {
      test('$module/readme.md tells the reader its table is a sample', () {
        // Without this a `rule` classification would be indistinguishable from
        // an unchecked one: the readme would carry a partial table and say
        // nothing about it, and a reader would take a type's absence for the
        // type not existing.
        final readme = File('lib/src/$module/readme.md').readAsStringSync();
        expect(
          readme,
          contains(_notAnInventoryMarker),
          reason:
              'lib/src/$module/readme.md is classified _Claim.rule, so it must '
              'carry the literal "$_notAnInventoryMarker" callout naming the '
              'rule it follows and where the complete list is kept',
        );
      });
    }
  });

  group('module readmes list the surface their module exports', () {
    for (final module
        in _moduleClaims.entries
            .where((e) => e.value == _Claim.inventory)
            .map((e) => e.key)) {
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

        final missing = types.where((t) => !_names(readme, t)).toList()..sort();
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
        final missing = statics.where((s) => !_names(readme, s)).toList()
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
    // `tom_basics` is in the set because the kernel barrel re-exports it in
    // full, so its types reach a reader through
    // `package:tom_core_kernel/tom_core_kernel.dart` exactly as the kernel's
    // own do. Leaving it out made every `tom_basics` type a phantom — which
    // is how this document's account of why the config enums are named
    // `TomConfigEnvironment` / `TomConfigPlatform` (they must not collide
    // with `tom_basics`' `TomEnvironment` / `TomPlatform`) came back as two
    // faults for naming the very types it is warning about.
    final declared = _typesDeclaredIn(Directory('lib/src'))
        .union(_typesDeclaredIn(_packageLib('tom_core_kernel')))
        .union(_typesDeclaredIn(_packageLib('tom_basics')));
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
      expect(
        declared,
        contains('TomEnvironment'),
        reason:
            'tom_basics types missing — the kernel barrel re-exports that '
            'package in full, so a document may name them',
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

  group('API summaries mirror the surface they claim to inventory', () {
    final summaries = _apiSummaries();

    test('a summary names a module that exists and exports something', () {
      // Starting from the file name rather than a list is what makes the two
      // cases below unable to miss a summary; this is the case that keeps the
      // derivation honest.
      for (final entry in summaries.entries) {
        expect(
          Directory('lib/src/${entry.key}').existsSync(),
          isTrue,
          reason:
              '${entry.value.path} claims to summarise lib/src/${entry.key}, '
              'which does not exist',
        );
        expect(_exportedSources(entry.key), isNotEmpty);
      }
    });

    test('a summary gives every public type its module exports a section', () {
      // The claim an inventory makes, and the one that rots: adding a type to
      // a module is one line away from leaving the summary behind. An API
      // summary is worth reading only while it is complete — an incomplete one
      // is worse than none, because absence reads as "does not exist".
      //
      // A *section*, not a mention. Merely being named somewhere passes
      // vacuously for any type that appears inside another one's signature:
      // `TomCompositeStep` is in `List<TomCompositeStep>` on a neighbouring
      // table row, so it could lose its own entry entirely and still be found.
      // Demanding a heading is what makes the assertion mean "documented".
      final faults = <String>[];
      for (final entry in summaries.entries) {
        final headed = _typeHeading
            .allMatches(entry.value.readAsStringSync())
            .map((m) => m.group(1)!)
            .toSet();
        final missing = _publicNames(
          _exportedSources(entry.key),
          _declaration,
        ).difference(headed).toList()..sort();
        faults.addAll(missing.map((t) => '${entry.value.path}: $t'));
      }
      expect(
        faults,
        isEmpty,
        reason:
            'these public types are exported by the module and have no section '
            'in its API summary: $faults',
      );
    });

    test('a summary names every public static its module exports', () {
      final faults = <String>[];
      for (final entry in summaries.entries) {
        final text = entry.value.readAsStringSync();
        final statics = _publicNames(
          _exportedSources(entry.key),
          _staticMember,
        );
        final missing = statics.where((m) => !_names(text, m)).toList()..sort();
        faults.addAll(missing.map((m) => '${entry.value.path}: $m'));
      }
      expect(
        faults,
        isEmpty,
        reason:
            'these public statics are exported by the module and never named '
            'in its API summary: $faults',
      );
    });
  });
}
