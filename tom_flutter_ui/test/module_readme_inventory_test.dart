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
  /// `tool/check_doc_class_inventories.py`) and, for the whole barrel rather
  /// than the fields alone, `doc/api/api_summary_forms.md` (held by the
  /// summary cases below).
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
  // The return type, in the two shapes that are not a bare identifier soup:
  // a record — `(String, List<String>)`, and one level deeper,
  // `(T? value, List<(double, T)> overrides)?` — and a function type,
  // `Stream<List<int>> Function()?`. Both carry parentheses, which the
  // identifier alternation cannot cross, so without these two alternatives
  // the match lands on the wrong token — `Function` is captured as if it were
  // the member's name — or stops at the return type and misses the member.
  // One level of nesting is where this stops: a regex cannot balance
  // parentheses, and the deepest return type the package declares is
  // `TomCtr.breakpointed`'s.
  r'^\s*static\s+(?:\((?:[^()]|\([^()]*\))*\)\s*\??\s+|[\w<>,\s?]+\s+)?'
  r'(?:Function\s*\([^)]*\)\s*\??\s+)?'
  // The name, and its own type parameters when it is a generic static —
  // `compose<T>(...)`, whose `<` is likewise not a body opener.
  r'(?:get\s+|set\s+)?(\w+)\s*(?:<[\w<>,\s?]*>\s*)?[({=;]',
  multiLine: true,
);

final _export = RegExp(r"^export\s+'([^']+)'", multiLine: true);

final _part = RegExp(r"^part\s+'([^']+)'", multiLine: true);

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
  // The barrel itself, because a module may declare a type in it rather than
  // in a file beneath it. Omitting it made the barrel a blind spot.
  final sources = <String>[barrel];
  for (final m in _export.allMatches(barrel)) {
    final library = File('$dir/${m.group(1)}');
    if (!library.existsSync()) continue;
    final text = library.readAsStringSync();
    sources.add(text);
    // A library's declarations are not all in the file the barrel names.
    // `acl_container.dart` is one library across twelve files, and reading
    // only the named one drops most of its exported surface — which reads as
    // an inventory getting smaller rather than a scan getting narrower.
    for (final part in _part.allMatches(text)) {
      final file = File('$dir/${part.group(1)}');
      if (file.existsSync()) sources.add(file.readAsStringSync());
    }
  }
  return sources;
}

/// A top-level declaration whose name starts with `_`.
final _privateDeclaration = RegExp(
  r'^(?:abstract\s+|base\s+|final\s+|sealed\s+|interface\s+|mixin\s+)*'
  r'(?:class|mixin|enum|extension)\s+_\w+',
  multiLine: true,
);

/// [source] with the body of every private top-level declaration removed.
///
/// A `static` member is part of the surface only when the thing declaring it
/// is. `_GlobalHook.acquire` is on a class no consumer can name, and asking a
/// module readme to document it is asking it to describe an internal — which
/// is the opposite of what an inventory is for.
///
/// The body is taken to end at the first `}` in column 0, which is how this
/// package is formatted and what every other source scan here assumes.
String _withoutPrivateDeclarations(String source) {
  final lines = source.split('\n');
  final kept = <String>[];
  var skipping = false;
  for (final line in lines) {
    if (skipping) {
      if (line == '}') skipping = false;
      continue;
    }
    if (_privateDeclaration.hasMatch(line)) {
      // A declaration written entirely on one line — `enum _FABVariant {
      // regular, small, large, extended }` — closes its own body, so there is
      // nothing to skip past. Treating it like a multi-line one swallowed
      // everything up to the next `}` in column 0, which in that file was 450
      // lines and two public types: `TomFloatingActionButton` and
      // `TomIconButton` were exempt from every inventory in the package.
      if (line.contains('{') &&
          '{'.allMatches(line).length == '}'.allMatches(line).length) {
        continue;
      }
      skipping = true;
      continue;
    }
    kept.add(line);
  }
  return kept.join('\n');
}

Set<String> _publicNames(List<String> sources, RegExp pattern) => sources
    .map(_withoutPrivateDeclarations)
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

/// What a module's **barrel library dartdoc** claims — the `///` block above
/// `library;`, which is the first thing a reader of the barrel sees and what
/// `dart doc` publishes as the library page.
///
/// Classified per module for the same reason [_Claim] is: a list of the modules
/// that are checked says nothing about the ones outside it, so a module can sit
/// uncovered without anyone deciding it should.
enum _BarrelDoc {
  /// The dartdoc links every public type the barrel exports.
  ///
  /// Not named `index`, which an enum already declares.
  complete,

  /// The dartdoc orients rather than enumerates, because the module is a
  /// catalogue where a complete list would be unreadable and is kept somewhere
  /// that is itself checked. The same two modules [_Claim.rule] covers.
  orientation,

  /// The dartdoc enumerates, incompletely — it reads as an index and is not
  /// one, which is the shape that misleads: a reader concludes from a name's
  /// absence that the type does not exist.
  ///
  /// A measurement, not an exemption. Each of these was counted, and the
  /// assertion below holds them to that count, so a module here cannot quietly
  /// get worse — only better, which then requires moving it to [index].
  partial,
}

/// Every module, and what its barrel dartdoc claims.
///
/// The `partial` counts were measured on 2026-09-21 against the barrel's own
/// exports.
const _barrelDocs = <String, _BarrelDoc>{
  'actions': _BarrelDoc.complete,
  'groups': _BarrelDoc.complete,
  'theme': _BarrelDoc.complete,
  'forms': _BarrelDoc.orientation,
  'widgets': _BarrelDoc.orientation,
  'advanced_container_layout': _BarrelDoc.partial,
  'custom': _BarrelDoc.partial,
  'resource_auth': _BarrelDoc.partial,
  'widget_base': _BarrelDoc.partial,
};

/// How many exported types each `partial` barrel dartdoc leaves unlinked.
///
/// Held exactly, in both directions: a module that slips further is a
/// regression, and one that improves has to be re-classified rather than
/// silently drifting into passing a weaker check than it now deserves.
const _partialBarrelGaps = <String, int>{
  'advanced_container_layout': 7,
  'custom': 6,
  'resource_auth': 6,
  'widget_base': 25,
};

/// The `[Name]` dartdoc references in a barrel's library comment.
final _dartdocLink = RegExp(r'\[(\w+)\]');

/// The `///` block a barrel carries above its `library;` directive.
String _libraryDartdoc(String module) {
  final dir = 'lib/src/$module';
  final barrel = File(
    '$dir/${_moduleBarrels[module] ?? '$module.dart'}',
  ).readAsStringSync();
  final upToLibrary = barrel
      .split(RegExp(r'^library\b', multiLine: true))
      .first;
  return upToLibrary
      .split('\n')
      .where((l) => l.trimLeft().startsWith('///'))
      .join('\n');
}

/// The index of the summaries, named by the workspace convention. It is the one
/// file in `doc/api/` matching the summary pattern that is not a module's
/// summary, so it is excluded by name and checked separately below — the
/// alternative, letting it through, asks for a `lib/src/index/` that will never
/// exist.
const _apiSummaryIndex = 'api_summary_index.md';

/// The exported public-type count at which a module earns a symbol-level
/// summary under `doc/api/`.
///
/// Counting **types**, not lines or files, because a section per exported type
/// is what a summary is. The two disagree, and the type count is the one that
/// sorts the package correctly: `resource_auth` declares 13 of them across
/// 11,352 lines and wants a summary; `theme` declares 4 across 365 and does
/// not. A line threshold placing those two on the same side of it would be
/// measuring the generated tables inside one of them.
///
/// Ten is where a readme table stops working. Below it the module's own
/// `readme.md` **is** the mirror, and not merely by assertion — a
/// [_Claim.inventory] readme is held to every public type and static by the
/// group above, so the small modules are checked, they are just checked
/// somewhere else. `groups` is the case that shows it: two exported types, a
/// readme that names both plus the two kernel types it bridges, and a summary
/// would be the fourth document over 297 lines of code.
///
/// Measured 2026-09-22, exported public types per module: forms 212, widgets
/// 299, advanced_container_layout 35, widget_base 34, custom 16, actions 13,
/// resource_auth 13, theme 4, groups 2.
const _summaryThreshold = 10;

/// The modules at or above [_summaryThreshold] whose summary is not written.
///
/// Held **exactly**, in both directions, for the reason [_partialBarrelGaps]
/// is: a module that slips out of a summary is a regression, and one that
/// gains a summary has to be taken off this list rather than quietly passing a
/// weaker check than it now deserves.
///
/// A [_Claim.rule] module is not in scope at all — its complete list is kept
/// and checked elsewhere by that classification, which is what the
/// classification is for. That is why `widgets` (299 types) is absent from
/// this set while `forms` (212) has a summary anyway: a rule module may have
/// one, it is simply not owed one.
const _summaryBacklog = <String>{};

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
    if (name == _apiSummaryIndex) continue;
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

    test('the index names every summary beside it', () {
      // An index is only worth having while it is complete: a summary missing
      // from it is a module a reader concludes has none, which is the same
      // failure as a missing section inside a summary.
      final index = File('doc/api/$_apiSummaryIndex');
      expect(
        index.existsSync(),
        isTrue,
        reason:
            'doc/api/ holds ${summaries.length} summaries and no '
            '$_apiSummaryIndex — the convention names one',
      );
      final text = index.readAsStringSync();
      final missing =
          summaries.values
              .map((f) => f.path.split(Platform.pathSeparator).last)
              .where((name) => !text.contains(name))
              .toList()
            ..sort();
      expect(
        missing,
        isEmpty,
        reason: 'doc/api/$_apiSummaryIndex never links these: $missing',
      );
    });

    test('stripping private declarations never removes a public one', () {
      // The helper above is a heuristic over text, and its failure mode is
      // silent: a public type it swallows is not reported missing anywhere,
      // it simply stops being part of the surface every other case here is
      // derived from. `widgets/` is where that bit, because it is the one
      // module with no inventory to compare against — its own
      // `widget_census.dart` counted 299 public types while this file's scan
      // counted 297, and nothing put the two numbers side by side.
      //
      // So the helper is checked against itself: whatever it removes, the set
      // of public declarations must survive it.
      final faults = <String>[];
      for (final module in _moduleClaims.keys) {
        for (final source in _exportedSources(module)) {
          final before = _declaration
              .allMatches(source)
              .map((m) => m.group(1)!)
              .where((n) => !n.startsWith('_'))
              .toSet();
          final after = _declaration
              .allMatches(_withoutPrivateDeclarations(source))
              .map((m) => m.group(1)!)
              .where((n) => !n.startsWith('_'))
              .toSet();
          faults.addAll(before.difference(after).map((n) => '$module: $n'));
        }
      }
      expect(
        faults..sort(),
        isEmpty,
        reason:
            'stripping a private declaration also removed these public ones, '
            'so they are silently outside every check in this file: $faults',
      );
    });

    test('every module the threshold reaches has a summary, or is a named '
        'entry in the backlog', () {
      // What an absent summary means. Without this, "no summary" reads the
      // same for `groups` — two exported types, whose readme is the mirror and
      // is held to be — as for `widget_base`, which is 34 types nobody has
      // written up. A reader cannot tell "small" from "unfinished", and that
      // ambiguity is what the threshold removes.
      final owed = <String>{};
      for (final entry in _moduleClaims.entries) {
        if (entry.value != _Claim.inventory) continue;
        final types = _publicNames(_exportedSources(entry.key), _declaration);
        if (types.length >= _summaryThreshold) owed.add(entry.key);
      }
      expect(
        owed,
        isNotEmpty,
        reason: 'no module reaches the threshold — the count is broken',
      );
      expect(
        owed.difference(summaries.keys.toSet()),
        _summaryBacklog,
        reason:
            'these modules are at or above $_summaryThreshold exported public '
            'types with no summary in doc/api/. Write one, or record it here '
            'if it is genuinely outstanding — and take it off this set when '
            'the summary lands.',
      );
    });

    test('the threshold is not vacuous, and the modules under it are '
        'mirrored by their own readme', () {
      // The control. A threshold every module clears asserts nothing, and one
      // that exempts a module whose readme is *not* an inventory would be
      // exempting it into having no mirror at all.
      final below = <String>[];
      for (final entry in _moduleClaims.entries) {
        final types = _publicNames(_exportedSources(entry.key), _declaration);
        if (types.length < _summaryThreshold) below.add(entry.key);
      }
      expect(
        below,
        isNotEmpty,
        reason:
            'every module reaches $_summaryThreshold exported public types, so '
            'the threshold exempts nothing and states nothing',
      );
      for (final module in below) {
        expect(
          _moduleClaims[module],
          _Claim.inventory,
          reason:
              '$module is under the threshold, so its readme is what stands in '
              'for a summary — and a ${_moduleClaims[module]} readme does not '
              'inventory anything',
        );
      }
    });

    test('the index names every module that has no summary', () {
      // The other half of "the index names every summary beside it": a module
      // absent from both lists is one the index is silent about, which is the
      // state this whole file exists to make impossible.
      final index = File('doc/api/$_apiSummaryIndex').readAsStringSync();
      final missing =
          _moduleClaims.keys
              .where((m) => !summaries.containsKey(m))
              .where((m) => !index.contains('`$m`'))
              .toList()
            ..sort();
      expect(
        missing,
        isEmpty,
        reason:
            'doc/api/$_apiSummaryIndex says nothing about these modules, which '
            'have no summary: $missing',
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

  group('barrel library dartdocs', () {
    test('every module is classified, and every classification names one', () {
      final onDisk = Directory('lib/src')
          .listSync()
          .whereType<Directory>()
          .map((d) => d.path.split(Platform.pathSeparator).last)
          .where(
            (m) => File(
              'lib/src/$m/${_moduleBarrels[m] ?? '$m.dart'}',
            ).existsSync(),
          )
          .toSet();
      expect(
        onDisk,
        isNotEmpty,
        reason: 'found no barrels — the scan is broken',
      );
      expect(
        onDisk.difference(_barrelDocs.keys.toSet()).toList()..sort(),
        isEmpty,
        reason:
            'these modules ship a barrel and _barrelDocs does not say what its '
            'dartdoc claims — classify them rather than leaving them unchecked',
      );
      expect(
        _barrelDocs.keys.toSet().difference(onDisk).toList()..sort(),
        isEmpty,
        reason: '_barrelDocs names modules that no longer ship a barrel',
      );
      expect(
        _partialBarrelGaps.keys.toSet(),
        _barrelDocs.entries
            .where((e) => e.value == _BarrelDoc.partial)
            .map((e) => e.key)
            .toSet(),
        reason: 'every partial barrel needs a measured gap, and vice versa',
      );
    });

    test('an index dartdoc links every type its barrel exports', () {
      // The barrel dartdoc is the first inventory a reader meets and the one
      // nothing was holding: `actions` listed ten of its thirteen types, and
      // the three it omitted — TomSimpleAction, TomCompositeStep,
      // TomUndoRedoContext — are each the only way to do something the module
      // is for.
      final faults = <String>[];
      for (final module in _barrelDocs.keys.where(
        (m) => _barrelDocs[m] == _BarrelDoc.complete,
      )) {
        final linked = _dartdocLink
            .allMatches(_libraryDartdoc(module))
            .map((m) => m.group(1)!)
            .toSet();
        final missing = _publicNames(
          _exportedSources(module),
          _declaration,
        ).difference(linked).toList()..sort();
        faults.addAll(missing.map((t) => 'lib/src/$module: $t'));
      }
      expect(
        faults,
        isEmpty,
        reason:
            'these public types are exported by the barrel and absent from its '
            'library dartdoc, which reads as an index: $faults',
      );
    });

    test('a partial dartdoc has not slipped further, or quietly improved', () {
      for (final entry in _partialBarrelGaps.entries) {
        final linked = _dartdocLink
            .allMatches(_libraryDartdoc(entry.key))
            .map((m) => m.group(1)!)
            .toSet();
        final gap = _publicNames(
          _exportedSources(entry.key),
          _declaration,
        ).difference(linked).length;
        expect(
          gap,
          entry.value,
          reason:
              'lib/src/${entry.key}: its barrel dartdoc leaves $gap exported '
              'types unlinked, measured at ${entry.value}. Fewer is progress — '
              'update the count, or move the module to _BarrelDoc.complete once '
              'it reaches zero.',
        );
      }
    });

    test('an orientation dartdoc does not pretend to enumerate', () {
      // The catalogues name a handful of types to orient the reader. The risk
      // is the opposite one: a list long enough to read as complete.
      for (final module in _barrelDocs.keys.where(
        (m) => _barrelDocs[m] == _BarrelDoc.orientation,
      )) {
        final linked = _dartdocLink
            .allMatches(_libraryDartdoc(module))
            .map((m) => m.group(1)!)
            .toSet();
        final exported = _publicNames(_exportedSources(module), _declaration);
        expect(
          linked.intersection(exported).length,
          lessThan(exported.length),
          reason:
              'lib/src/$module is classified as orienting rather than '
              'enumerating, but its dartdoc names every exported type — '
              'reclassify it as an index',
        );
      }
    });
  });
}
