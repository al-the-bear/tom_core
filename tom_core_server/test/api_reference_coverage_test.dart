/// The guard that keeps `doc/api_reference/` a mirror of `lib/` (CSEXC6).
///
/// `doc/api_reference/` claims, by existing, that it documents the package.
/// Nothing enforced that claim, and it drifted: five modules — audit,
/// scheduling, messaging, export, file_storage — shipped with a full narrative
/// guide and no API summary at all. That was not any one module's omission.
/// Each shipped what its own done-bar asked for; the gap was in an invariant
/// nobody was checking, and an invariant five modules have already broken is
/// one that will break a sixth time.
///
/// So the invariant is checked here instead of remembered. Three sets must
/// agree, keyed by module directory name:
///
///  * the module directories under `lib/src/tomserver/`;
///  * the narrative guides `doc/<module>.md`;
///  * the API summaries `doc/api_reference/api_summary_<module>.md`.
///
/// Both directions matter. A module without a summary is undocumented; a
/// summary without a module documents something that no longer exists, which
/// is worse, because a reader cannot tell a stale page from a current one.
///
/// The fourth test covers the index: `api_summary_index.md` is the entry point,
/// and an index that omits part of the package reads as complete while being
/// wrong. A summary nobody can navigate to is only marginally better than one
/// that was never written.
///
/// The next group checks the same invariant one level finer. Each guide opens
/// with an Overview table headed `| Type | Kind | Purpose |`, which claims by
/// its heading to be the module's type list — and the claim drifts the same way
/// the file-level one did, because a type added later has no reason to send its
/// author back to a table written when the module was young. A partial table is
/// worse than none: a reader who finds fourteen of twenty types has no signal
/// that six are missing, so they conclude the six do not exist.
///
/// The last group goes one level finer again, for one class. A summary's
/// `#### Properties` table makes the same completeness claim about a class's
/// fields that the Overview table makes about a module's types, and
/// [TomBaseServerConfiguration] had drifted furthest: it declared 48 fields and
/// the table listed 25, so the whole server self-login block, the whole
/// outbound-mail block and the whole outbound-SMS block — 23 deployment-facing
/// settings, four of them secret-bearing — were absent from the page a deployer
/// reads to find out what can be configured. That class is checked because it
/// is the one whose readers are operators rather than callers: an undocumented
/// method can be found in the source by the developer calling it, whereas an
/// undocumented setting is invisible to the person who needed to set it.
///
/// The final group goes one level finer still, and changes the question from
/// *completeness* to *attribution*. Every previous check asks whether a member
/// is documented somewhere; this one asks whether the class it is documented
/// **under** is the class that declares it. A summary is organised as
/// `#### <ClassName>` sections, so a row's position is itself a claim of
/// ownership — and that claim is unchecked by every test above, which would
/// be equally satisfied by a correct row filed under the wrong heading.
///
/// It drifts in a way the completeness checks cannot see. `mapGroupedRow` is a
/// static of [MariaDbDatasource], and the datasources completion document
/// listed it under `MariadbPreparedStatement` — the class it is *about*,
/// being the reading half of a grouped query, not the class it is *on*. A
/// reader comparing two documents that disagree about where a public static
/// lives cannot tell which one to believe, and a reader trusting the wrong one
/// writes `MariadbPreparedStatement.mapGroupedRow(...)` and gets a compile
/// error naming a class they were told to use.
///
/// So ownership is derived from the source rather than reviewed. The parser is
/// deliberately three-valued: a member is *declared*, *absent*, or
/// **undecidable** — the last when the class inherits from a type this
/// package does not declare, as [TomConfigurationException] does from the
/// kernel's exception base. Only *absent* fails. Reporting a member missing
/// because the parser could not see the class that declares it would be a
/// false alarm, and a guard that cries wolf is turned off.
///
/// The last group changes the question a third time. Attribution asks *whose*
/// member this is; this one asks what the reader is being *asked to do* about
/// it. In a contract listing — the `abstract class X { … }` blocks the module
/// guides open a chapter with — a bare declaration is a demand and one with a
/// body is a gift, and nothing checked which one the source meant.
///
/// Both directions of the mistake cost something, and they cost different
/// things. A concrete member shown bare is work invented for the reader: they
/// implement what they already had, and the override silently displaces a
/// default that was load-bearing. `TomMessageTransport.supportsCopies` and
/// `supportsAttachments` default to `false` precisely so that a transport which
/// has never considered attachments cannot be handed one — presenting them as
/// abstract turns a safe default into a chore, and a chore done carelessly
/// answers `true`. The opposite mistake is louder but cheaper: an abstract
/// member shown with a body reads as optional, is skipped, and the class does
/// not compile.
///
/// The comparison is symmetric, and that is what makes it sound. What is
/// measured on both sides is whether a declaration ends at a `;` or at a body,
/// which for anything that *can* be abstract is abstractness, and for a field
/// is merely "no initialiser". Two exclusions keep the shapes comparable: a
/// `static` and a constructor are never abstract however they are written, so a
/// bodiless one is not evidence of anything.
///
/// The last group is the same lesson pointed at the guides' claims about their
/// own testing. `doc/datasources.md` said the unit tests covered "the
/// connection-independent surface" and named no suite — while two suites
/// covered the driver, one of them against a live server, and the reader was
/// told about neither. An unattributed claim is an uncheckable one: there was
/// no name in the sentence for anything to falsify, so a second suite arriving
/// changed nothing about it and it went on being wrong.
///
/// The repair is to name the suite; the check is what makes naming it mean
/// something. Every `…_test.dart` and `….sh` a guide mentions must be a file
/// that exists, so moving a suite fails the build and puts whoever moved it in
/// front of the prose that describes it. A path belonging to a sibling sample
/// package is excused when the paragraph names that package, which is the same
/// information a reader needs to make sense of it.
///
/// That check is about the references a guide *does* write, so it says nothing
/// about a guide that writes none — the exact state `doc/datasources.md` was in
/// when it prompted the check. The per-module half closes it from the other
/// side: each guide must name at least one suite, and — when the module ships
/// one — at least one runnable artefact under `example/<module>/`. Both, not
/// either, because they answer different halves of the same question, and an
/// example nobody points at is an example nobody runs. The datasources example
/// spent a year with nine expectations written as `assert`, which `dart run`
/// leaves disabled, so it printed a plausible transcript and exited 0 with
/// every one of them violated. Reference migrations under
/// `example/<module>/migrations/` do not satisfy this: four guides cite that
/// SQL while explaining a table, which is data a reader reads, not a program a
/// reader runs. Twelve modules are quarantined under one quest todo.
///
/// The group before it asks a question about the document's *tense* rather than
/// its content. Every check above compares a claim against the code as it
/// stands; a claim that something is **not finished** cannot be checked that
/// way, because there is nothing in the source that contradicts it — the
/// absence it asserts looks exactly like an absence that is intended.
///
/// What can be checked is where the claim lives. Eleven guides collect what
/// they have not done under `## Not Yet Implemented`, and `doc/authentication.md`
/// under `## Status and Limitations`; those sections are the ones re-read when
/// work completes. `doc/datasources.md` made its claim in the middle of a
/// chapter instead — escaping of interpolated literals was "a tracked follow-up
/// — see the completion steps" — and so nobody re-read it, and it outlived the
/// work by however long the escaping had been in `text`. The document a
/// consumer reads first was warning them off a facility that works and pointing
/// them at a follow-up that is closed.
///
/// So the placement is enforced and the staleness follows from it. A signpost
/// *to* the section is not a violation — the claim is still in one place — so a
/// line linking to it is allowed anywhere, as is a fenced block, which may be
/// quoting code as an example of what not to write.
///
/// That leaves the same hole the attribution check had, in the same shape: a
/// rule about where a claim goes says nothing about a document that makes no
/// claim, and a guide with no such section has nowhere legal to put one. The
/// pressure is then to leave the edge out rather than write it down.
/// `doc/datasources.md` was that document: it described a module that ships one
/// database driver, declares a `TomDbTime` nothing produces and runs XA with no
/// recovery, and mentioned none of the three. Silence reads as "no edges",
/// which is a stronger claim than any guide in this package can make. So the
/// per-module half requires the section to exist; eight guides are quarantined
/// under one quest todo.
///
/// The two groups after it ask a blunter question than anything above: not
/// whether a documented thing is documented correctly, but whether the document
/// knows the file exists at all. `api_summary_datasources.md` ran to 1116 lines
/// about a unit of ten source files while naming eight of them, and the two it
/// omitted were `framework_table.dart` and `sql_instant.dart` — the declaration
/// every framework-owned table is derived from, and the one encoding of an
/// instant every table stores. No check above can see that. An Overview table,
/// a Properties table, an attribution check and a contract listing all measure
/// what a summary already mentions, so a file it never mentions is invisible to
/// every one of them, and the more thorough the page looks the more completely
/// the omission is hidden.
///
/// So each summary's `Source:` list is compared against the barrel. The barrel
/// is the right anchor because it *is* the definition of the public surface: a
/// file it exports is one a reader can reach, and a file it does not export is
/// not the summary's business. Both directions fail. An exported file missing
/// from the list is undocumented; a listed file that is no longer exported is
/// worse, because it sends the reader to a page describing something they
/// cannot import.
///
/// The group after it asks the same question of the index, where the answer
/// carries further. `api_summary_index.md` is the only place in the package
/// where a reader can conclude that a name does not exist without opening a
/// file — which is precisely why it is the place where that conclusion must not
/// be drawable wrongly. Fifty-three exported names across seven modules were
/// in neither of its two tables, [TomSchemaModel] and [TomFileEndpoint] among
/// them, so the reader who looked them up was told, by the document built to
/// answer that question, that there was nothing to find.
///
/// Both carry a quarantine, because both were measured across all twenty
/// modules before being enforced and both found debt older than the module that
/// exposed them. The quarantines are visible skips naming their quest todos,
/// and a meta-test fails when an entry has nothing left to suppress, so the
/// exemption expires by itself rather than by being remembered.
///
/// The group after those two is the same completeness question asked about the
/// one kind of API the class-shaped checks structurally cannot reach. A summary
/// is organised as `#### <ClassName>` sections, so every check above finds a
/// member by finding its class — and a **free function has no class**. Its only
/// possible home is the module's `## Global Functions and Constants` section,
/// which is therefore not merely a convenience list but the sole place a
/// top-level function can be documented at all. That is what makes a section
/// reading "None — this module exposes no top-level functions or constants" a
/// claim rather than a formality, and `db_migration`'s said exactly that while
/// the module exported `frameworkOwnedTables` — the function from which a
/// deployment learns which tables the framework owns. Not an incomplete answer:
/// a wrong one.
///
/// Getting there exposed something worse than any document defect, in the
/// scanner the last three groups all read. [_functionDeclaration] required a
/// return type beginning with a letter, and a **record** type begins with `(`.
/// So `extractAuthentication` and `auditDiff` were in none of the sets this
/// file derives from source, and every check that consults one had been
/// excusing two documents from mentioning two exported functions — reporting
/// agreement it had not established. That is the failure mode a guard is worst
/// at surfacing, because it is indistinguishable from success: a parser blind
/// to a declaration reads its absence from a document as a match. The shapes
/// are now pinned by a fixture rather than by whatever the package happens to
/// contain, which is the only reading that would have caught it.
///
/// The section's *layout*, by contrast, is deliberately not pinned. The twenty
/// summaries write it more differently than they write anything else — one
/// table, or a split into `### Constants` and `### Functions`, or a sentence
/// where there is nothing to list — and none of that variation misleads anyone.
/// What is checked is which names appear, in both directions: a function absent
/// from the section is undocumented, and a row naming something the module does
/// not declare is worse, the reader having no way to tell it from a current
/// one. All twenty satisfy both today, so this one carries no quarantine.
///
/// The last group is the first check in this file whose subject is the document
/// as a document rather than as a set of claims about code, and it is the same
/// completeness failure as the Overview table one level up again. A guide's
/// `## Table of Contents` is how a reader decides what the document covers
/// without reading it, so a section it omits is a section most readers never
/// learn exists. `doc/datasources.md` had three source files with no section at
/// all; the repair added three, and nothing but attention would have kept their
/// entries in the list — adding a section being precisely the moment the list
/// is not what is being thought about.
///
/// Three ways for the list to be wrong are separated, because they fail
/// differently. A section with no entry is unreachable except by scrolling; an
/// entry with no section still renders and links nowhere, which is worse,
/// because the reader is told the material exists; and a list in the wrong
/// order misleads about distance, which is most of what a contents list is for.
/// All twenty guides satisfy all three today, so this one carries no
/// quarantine.
///
/// The group that closes the file is the attribution check run backwards, and
/// it is the last direction left. Attribution asks, of a row, whether it is
/// filed under the class that declares it; this asks, of a *declared member*,
/// whether any section mentions it at all. Between them the two exhaust the
/// class-shaped surface, and until now only one of them was checked — which is
/// why `TomOperator` could be documented at length, correctly, and still not
/// mention `children`, the single edge along which the whole operator tree is
/// walked. A `#### Properties` table is read as complete, because there is no
/// other way to read one, so an omitted member does not send anyone to the
/// source: it tells them the member is not there.
///
/// A mention counts wherever it falls — a row, a fenced constructor listing, a
/// sentence — because the summaries legitimately document different kinds of
/// member in different shapes, and a factory constructor has a row nowhere in
/// this package. Demanding a table row would force every summary to restate its
/// listings as a table, and would be a rule about formatting dressed up as one
/// about completeness. An override is satisfied by the ancestor that declares
/// it, since an override is not new API and the interface documents it once;
/// the `Object` members are excused entirely, being callable whether or not
/// they were overridden.
///
/// Measuring it first is what made it enforceable, and the measurement was
/// mostly a hunt for defects in the reader rather than in the documents. An
/// annotation carrying arguments survived the modifier strip and was read as a
/// declaration, so every entity class gained a phantom member named after its
/// annotation; the wrapped tail of a constructor — `  }) : id = …` — is
/// indented exactly like a member and contributed the vocabulary of its
/// initialisers; and a member heading split by subject (`##### Methods —
/// aggregates`) matched neither class nor member section, which closed the
/// class and orphaned every row beneath it. Each of those was silently
/// weakening the attribution check as well. Two modules' summaries remain
/// genuinely incomplete and are quarantined under their own quest todos.
///
/// Everything here reads the working tree, so the failure names the missing
/// file, type, field or section and appears the moment the next one lands.
library;

import 'dart:io';

import 'package:test/test.dart';

/// Module directory names under `lib/src/tomserver/`, sorted.
///
/// This is the anchor set: it is the code, so it cannot itself be out of date.
List<String> _modules() =>
    Directory('lib/src/tomserver')
        .listSync()
        .whereType<Directory>()
        .map(
          (entry) => entry.uri.pathSegments[entry.uri.pathSegments.length - 2],
        )
        .toList()
      ..sort();

/// Base names of the markdown files directly under [directory], sorted.
///
/// `stripPrefix` removes the naming prefix the summaries carry, so both sets
/// come back keyed by plain module name and can be compared directly.
List<String> _docs(String directory, {String stripPrefix = ''}) =>
    Directory(directory)
        .listSync()
        .whereType<File>()
        .map((entry) => entry.uri.pathSegments.last)
        .where((name) => name.endsWith('.md'))
        .map((name) => name.substring(0, name.length - '.md'.length))
        .where((name) => name.startsWith(stripPrefix))
        .map((name) => name.substring(stripPrefix.length))
        .toList()
      ..sort();

/// Matches a top-level type declaration, anchored at column zero.
///
/// Dart has no nested types, so a declaration that is indented is inside
/// something and not part of the module's surface — the anchor is what
/// distinguishes them, and it is why this stays a regex rather than growing an
/// `analyzer` dependency for four lines of parsing.
final RegExp _typeDeclaration = RegExp(
  r'^(?:abstract\s+|sealed\s+|final\s+|base\s+|interface\s+|mixin\s+)*'
  r'(?:class|enum|mixin|extension|typedef)\s+([A-Za-z_][A-Za-z0-9_]*)',
  multiLine: true,
);

/// Matches a top-level function declaration, anchored at column zero.
///
/// A return type, then the name, then the parameter list. The lazy prefix is
/// built from word characters, `<>,?.` and spaces, so it cannot cross an `=` —
/// which is what stops a top-level `final x = someCall();` from reading as a
/// declaration of `someCall`.
final RegExp _functionDeclaration = RegExp(
  r'^[A-Za-z_][\w<>,?\s.]*?\s+([A-Za-z_]\w*)\s*(?:<[^<>]*>)?\s*\(',
  multiLine: true,
);

/// Matches a top-level function whose return type is a **record**, anchored at
/// column zero.
///
/// [_functionDeclaration] cannot see one: its return type must start with a
/// letter, and a record type starts with `(`. Two of this package's functions
/// do — `extractAuthentication` returns `(TomPrincipal?, TomClientJwtToken?)`
/// and `auditDiff` returns `({Map<String, Object?> before, …})` — so both were
/// absent from every set this file derives from the source, and every check
/// that reads one was silently excusing the two documents from mentioning them.
/// A parser that cannot see a declaration reports its absence from a document
/// as agreement.
///
/// The parenthesis matcher allows one level of nesting, which is what a record
/// of function types needs, and stops there: a return type deep enough to
/// require more is one whose row a reader would want rewritten anyway.
final RegExp _recordFunctionDeclaration = RegExp(
  r'^\([^()]*(?:\([^()]*\)[^()]*)*\)\s+([A-Za-z_]\w*)\s*\(',
  multiLine: true,
);

/// Matches a top-level getter, anchored at column zero.
///
/// There is exactly one in the package — `configuration`'s `tomAppId` — and its
/// guide gives it a row, so a reading that knew only about functions would
/// report that row as naming something the module does not export.
final RegExp _getterDeclaration = RegExp(
  r'^[A-Za-z_][\w<>,?\s.]*?\s+get\s+([A-Za-z_]\w*)\b',
  multiLine: true,
);

/// The `##` headings of [guide] in document order, less its own contents entry.
List<String> _guideSections(String guide) =>
    RegExp(r'^## (.+)$', multiLine: true)
        .allMatches(File('doc/$guide.md').readAsStringSync())
        .map((match) => match.group(1)!.trim())
        .where((heading) => heading != 'Table of Contents')
        .toList();

/// The anchors [guide]'s table of contents links to, in document order.
///
/// `null` when the guide has no contents list at all, which is a different
/// finding from an incomplete one and is reported separately.
List<String>? _guideContents(String guide) {
  final text = File('doc/$guide.md').readAsStringSync();
  if (!text.contains('## Table of Contents')) return null;
  return RegExp(
    r'^- \[[^\]]+\]\(#([^)]+)\)$',
    multiLine: true,
  ).allMatches(text).map((match) => match.group(1)!).toList();
}

/// The fragment GitHub derives from a `##` heading.
///
/// Lower-cased, everything but letters, digits, spaces and hyphens dropped,
/// spaces to hyphens. That is enough for these guides — no two sections of one
/// guide collide, so the disambiguating `-1` suffix never arises.
String _anchorOf(String heading) => heading
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9 \-]'), '')
    .replaceAll(' ', '-');

/// Matches one `export 'src/tomserver/<module>/<file>';` line of the barrel.
final RegExp _barrelExport = RegExp(
  r"^export 'src/tomserver/([^/]+)/([^']+)';",
  multiLine: true,
);

/// The public API the package barrel exports for [module], sorted.
///
/// Read through the barrel rather than by listing the module directory,
/// because the two are not the same set: a file the barrel does not export is
/// module-internal, and documenting it in a table headed "Type" would promise
/// an API that a consumer cannot import.
///
/// Types *and* top-level functions and getters, because that is what the guides
/// already document: `function` is one of the values their Kind column takes,
/// eleven times across the set. Reading only types made every one of those
/// rows an orphan, which is why `datasources` — whose table carries three —
/// could not be reconciled at all while the check knew about types alone.
///
/// Top-level *variables* are deliberately not API here. `messaging` exports
/// `tomMimeLineEnding` and `tomMimeMaxLineLength`, which a reader meets in the
/// documentation of the field that uses them rather than as surface to look up,
/// and no guide gives a bare constant a row. The one constant that is arguably
/// surface — `endpoints`' `const tomService = TomService()` — is an instance of
/// an exported type, and the type already has the row.
List<String> _exportedApi(String module) =>
    _overExportedSources(module, _declaredApi).toList()..sort();

/// [source] with its multi-line strings emptied.
///
/// A multi-line string holds unindented DDL, and a `CREATE TABLE
/// tom_resource_grant (` line inside one has the exact shape of a top-level
/// function. Without this, the scans below report the contents of the package's
/// SQL constants as part of its API.
///
/// Comments need no such treatment, and deliberately get none: every pattern
/// is anchored at column zero and starts with a letter or `(`, so a `///` or
/// `//` line cannot match one however much code it quotes. Stripping them as
/// well would be a line nothing reaches, which is a line nobody maintains.
String _withoutMultilineStrings(String source) => source
    .replaceAll(RegExp(r"'''[\s\S]*?'''"), "''")
    .replaceAll(RegExp(r'"""[\s\S]*?"""'), '""');

/// The public top-level names [source] declares — its types and its functions.
///
/// Separated from [_exportedApi] so the scan can be driven over a source string
/// rather than only over the package, which is what makes the declaration
/// shapes checkable against a fixture. Some of them are rare enough that no
/// live comparison exercises them — the package has one top-level getter and
/// two functions returning a record — and a branch nothing reaches is a branch
/// nobody knows works.
Set<String> _declaredApi(String source) => {
  ..._typeDeclaration
      .allMatches(_withoutMultilineStrings(source))
      .map((declaration) => declaration.group(1)!)
      .where((name) => !name.startsWith('_')),
  ..._declaredFunctions(source),
};

/// The type names the first column of `doc/<module>.md`'s Overview table
/// carries, sorted — or `null` when the guide has no such table.
///
/// A cell may name more than one type (the delegation row names three), so
/// every backticked identifier in the cell counts.
///
/// A generic is written with its parameter — `` `TomDbType<T>` `` — which reads
/// better than the bare name and is the name all the same. The argument list is
/// dropped so the cell and the declaration agree; without that, three of this
/// module's oldest rows read as naming types the barrel does not export.
List<String>? _overviewTableTypes(String module) {
  final lines = File('doc/$module.md').readAsLinesSync();
  final heading = lines.indexWhere((line) => line.startsWith('| Type |'));
  if (heading < 0) return null;

  final names = <String>{};
  // +2 skips the heading and the `| ---- |` separator beneath it.
  for (final line in lines.skip(heading + 2)) {
    if (!line.startsWith('|')) break;
    final cell = line.split('|')[1];
    names.addAll(
      RegExp(
        r'`([A-Za-z_][A-Za-z0-9_]*)(?:<[^`]*>)?`',
      ).allMatches(cell).map((match) => match.group(1)!),
    );
  }
  return names.toList()..sort();
}

/// The files the package barrel exports for [module], as `<module>/<file>`
/// pairs, sorted.
///
/// The same anchor [_exportedApi] reads, one level coarser: what a summary's
/// `Source:` list is claiming to have covered is a set of *files*, and naming
/// them by hand is exactly the step that gets skipped when a file is added.
List<String> _exportedFiles(String module) => [
  for (final export in _barrelExport.allMatches(
    File('lib/tom_core_server.dart').readAsStringSync(),
  ))
    if (export.group(1) == module) '$module/${export.group(2)}',
]..sort();

/// The `<module>/<file>` pairs the `Source:` list at the top of [summary]
/// names, in the order given — or `null` when it has no such list.
///
/// The list runs from the `Source:` line (some summaries write `Sources:`) to
/// the first blank line after it, which is how all twenty write it. Taking it
/// as a string rather than a module lets the shapes below be checked against a
/// fixture instead of only against the package.
List<String>? _sourceListOf(String summary) {
  final start = RegExp(r'^Sources?:', multiLine: true).firstMatch(summary);
  if (start == null) return null;
  final rest = summary.substring(start.start);
  final blank = rest.indexOf('\n\n');
  return RegExp(r'`lib/src/tomserver/([^/`]+)/([^`]+)`')
      .allMatches(blank < 0 ? rest : rest.substring(0, blank))
      .map((match) => '${match.group(1)}/${match.group(2)}')
      .toList();
}

/// The `Source:` list of `doc/api_reference/api_summary_<module>.md`.
List<String>? _summarySourceList(String module) => _sourceListOf(
  File('doc/api_reference/api_summary_$module.md').readAsStringSync(),
);

/// Whether [index] names [api] — as a bare `` `name` `` or as a generic
/// `` `name<T>` ``, which is how the index writes the type parameters.
bool _indexNames(String index, String api) =>
    RegExp('`${RegExp.escape(api)}[<`]').hasMatch(index);

/// Matches a top-level `const` or `final` declaration, anchored at column zero.
///
/// Not part of [_declaredApi] — a bare constant is documentation of the field
/// that uses it rather than surface to look up, and no guide gives one a row.
/// It is needed here all the same, because the module's one list of free
/// functions is headed "Global Functions **and Constants**" and several modules
/// use it for exactly that. Without this, every constant row would read as
/// naming something the module does not declare.
final RegExp _variableDeclaration = RegExp(
  r'^(?:const|final)\s+(?:[\w<>,?\s.]+\s+)?([A-Za-z_]\w*)\s*=',
  multiLine: true,
);

/// The public top-level functions and getters [source] declares.
///
/// Narrower than [_declaredApi] on purpose: what a summary's Global Functions
/// section claims to list is the free functions, and folding the types in would
/// make the claim unfalsifiable — every module declares types, and none lists
/// them there.
Set<String> _declaredFunctions(String source) {
  final stripped = _withoutMultilineStrings(source);
  return {
    for (final pattern in [
      _functionDeclaration,
      _recordFunctionDeclaration,
      _getterDeclaration,
    ])
      for (final declaration in pattern.allMatches(stripped))
        if (!declaration.group(1)!.startsWith('_')) declaration.group(1)!,
  };
}

/// The public top-level functions and getters the barrel exports for [module],
/// sorted.
List<String> _exportedFunctions(String module) =>
    _overExportedSources(module, _declaredFunctions).toList()..sort();

/// Every public top-level name the barrel exports for [module] — types,
/// functions, getters *and* constants.
///
/// The set the Global Functions section is allowed to name. Broader than
/// [_exportedApi] by the constants, and broader still than what the section is
/// *required* to name, because a module may legitimately give a row to a
/// typedef or a constant that the forward check does not demand.
Set<String> _exportedNames(String module) => _overExportedSources(
  module,
  (source) => {
    ..._declaredApi(source),
    for (final declaration in _variableDeclaration.allMatches(
      _withoutMultilineStrings(source),
    ))
      if (!declaration.group(1)!.startsWith('_')) declaration.group(1)!,
  },
);

/// [scan] applied to every source file the barrel exports for [module],
/// unioned.
Set<String> _overExportedSources(
  String module,
  Set<String> Function(String source) scan,
) {
  final barrel = File('lib/tom_core_server.dart').readAsStringSync();
  final names = <String>{};
  for (final export in _barrelExport.allMatches(barrel)) {
    if (export.group(1) != module) continue;
    names.addAll(
      scan(
        File('lib/src/tomserver/$module/${export.group(2)}').readAsStringSync(),
      ),
    );
  }
  return names;
}

/// The names the first column of every table under [summary]'s
/// `## Global Functions and Constants` heading carries — or `null` when the
/// summary has no such section.
///
/// The section's *shape* varies across the set and deliberately is not pinned:
/// some summaries carry one table, some split it into `### Constants` and
/// `### Functions`, and the ones with nothing to list write a sentence instead
/// of an empty table. Reading every table beneath the heading accommodates all
/// three, and what is being checked is which names appear, not how they were
/// arranged.
///
/// A first cell may write a name with its parameter list —
/// `` `oauthStateTable(String table)` `` — so only the leading identifier of
/// each backticked run is taken.
List<String>? _globalFunctionNamesOf(String summary) {
  final heading = RegExp(
    r'^## Global Functions and Constants$',
    multiLine: true,
  ).firstMatch(summary);
  if (heading == null) return null;
  var section = summary.substring(heading.end);
  final next = RegExp(r'^## ', multiLine: true).firstMatch(section);
  if (next != null) section = section.substring(0, next.start);

  final names = <String>[];
  for (final line in section.split('\n')) {
    if (!line.startsWith('|')) continue;
    final cell = line.split('|')[1];
    if (cell.contains('---')) continue;
    names.addAll(
      RegExp(r'`([A-Za-z_]\w*)').allMatches(cell).map((m) => m.group(1)!),
    );
  }
  return names;
}

/// The Global Functions section of `doc/api_reference/api_summary_<module>.md`.
List<String>? _globalFunctionNames(String module) => _globalFunctionNamesOf(
  File('doc/api_reference/api_summary_$module.md').readAsStringSync(),
);

/// The body of `class <className>`, from its opening brace to the end of the
/// file, with the constructs that would otherwise be misread removed.
///
/// A multi-line default — the PEM certificate pair — is data whose lines would
/// be taken for declarations, and a block comment can hold anything at all.
/// Dartdoc is deliberately *kept*: [_secretBearingFields] reads it.
String _classBody(String path, String className) {
  final source = File(path).readAsStringSync();
  final start = source.indexOf('class $className {');
  if (start < 0) return '';
  return source
      .substring(start)
      .replaceAll(RegExp(r"'''[\s\S]*?'''"), "''")
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
}

/// The field name [line] declares, or `null` when it declares no field.
///
/// A declaration is exactly two spaces of indent, ends in `;`, and has a name
/// that is not followed by a parameter list. That last rule is what separates
/// `void setValues(Map<…> values);` from a field — without it the census counts
/// `values`, the method's final parameter, as a 49th field and then reports it
/// missing from a table that is in fact complete.
///
/// A regex rather than the `analyzer` package for the same reason
/// [_typeDeclaration] is one: this is a handful of lines of parsing against a
/// file whose layout the package's own formatter guarantees.
String? _fieldNameOf(String line) {
  if (!line.startsWith('  ') || line.startsWith('   ')) return null;
  final statement = line.trimRight();
  if (!statement.endsWith(';')) return null;

  // Everything left of the initialiser: a field's name is the last identifier
  // there, a method's is followed by its parameters.
  final declaration = statement
      .substring(0, statement.length - 1)
      .split('=')
      .first
      .trimRight();
  if (declaration.endsWith(')')) return null;

  final name = RegExp(r'([A-Za-z_][A-Za-z0-9_]*)$').firstMatch(declaration);
  if (name == null || name.group(1)!.startsWith('_')) return null;
  return name.group(1)!;
}

/// The instance field names a class declares in its source file, in source
/// order.
List<String> _declaredFields(String path, String className) {
  final body = _classBody(
    path,
    className,
  ).replaceAll(RegExp(r'^\s*///.*$', multiLine: true), '');

  final fields = <String>[];
  for (final line in body.split('\n')) {
    final name = _fieldNameOf(line);
    if (name != null) fields.add(name);
  }
  return fields;
}

/// The declared fields whose own dartdoc calls them **secret-bearing**, in
/// source order.
///
/// Derived rather than listed, so marking a new credential in the source is
/// what puts it on the guide's checked list — the alternative is a literal set
/// here, which is the same "written once, never revisited" failure this file
/// exists to close.
List<String> _secretBearingFields(String path, String className) {
  final secrets = <String>[];
  final doc = <String>[];
  for (final line in _classBody(path, className).split('\n')) {
    final trimmed = line.trim();
    if (trimmed.startsWith('///')) {
      doc.add(trimmed);
      continue;
    }
    // A blank line detaches a dartdoc from what follows it.
    if (trimmed.isEmpty) {
      doc.clear();
      continue;
    }
    if (doc.isEmpty) continue;
    final name = _fieldNameOf(line);
    if (name != null &&
        doc.join(' ').toLowerCase().contains('secret-bearing')) {
      secrets.add(name);
    }
    doc.clear();
  }
  return secrets;
}

/// Whether [field] belongs to one of the three deployment-facing blocks the
/// configuration guide documents: server self-login, outbound mail, outbound
/// SMS.
///
/// Matched by name rather than by a listed set, so a tenth `smtp*` setting is
/// covered by the guard the day it is declared.
bool _isDeploymentSetting(String field) =>
    field == 'authServerLoginUri' ||
    field.startsWith('serviceAccount') ||
    field.startsWith('smtp') ||
    field.startsWith('sms');

/// The settings the tables under `## Deployment Settings` in
/// `doc/configuration.md` carry: their names in document order, and the subset
/// whose row marks them secret-bearing.
///
/// Only the first column counts. A setting named in passing in another row's
/// prose is a cross-reference, not an entry — the claim being checked is that
/// the setting has a row of its own saying what it decides. The block-switch
/// table contributes nothing, because its first column names blocks rather than
/// settings.
(List<String>, Set<String>) _guideDeploymentSettings() {
  final lines = File('doc/configuration.md').readAsLinesSync();
  final start = lines.indexWhere(
    (line) => line.trim() == '## Deployment Settings',
  );
  if (start < 0) return (const [], const {});

  final names = <String>[];
  final secrets = <String>{};
  for (final line in lines.skip(start + 1)) {
    if (line.startsWith('## ')) break;
    if (!line.startsWith('|')) continue;
    final cell = RegExp(
      r'`([A-Za-z_][A-Za-z0-9_]*)`',
    ).firstMatch(line.split('|')[1]);
    if (cell == null) continue;
    names.add(cell.group(1)!);
    if (line.toLowerCase().contains('secret-bearing')) {
      secrets.add(cell.group(1)!);
    }
  }
  return (names, secrets);
}

/// The property names the `#### Properties` table under `### <className>` in
/// `doc/api_reference/api_summary_<module>.md` carries, in table order.
///
/// Scoped to the class's own section, because one summary documents several
/// classes and each has a Properties table of its own.
List<String> _summaryProperties(String module, String className) {
  final lines = File(
    'doc/api_reference/api_summary_$module.md',
  ).readAsLinesSync();

  final section = lines.indexWhere((line) => line.trim() == '### $className');
  if (section < 0) return const [];
  final heading = lines.indexWhere(
    (line) => line.startsWith('| Property |'),
    section,
  );
  if (heading < 0) return const [];

  final names = <String>[];
  // +2 skips the heading and the `| -------- |` separator beneath it.
  for (final line in lines.skip(heading + 2)) {
    if (!line.startsWith('|')) break;
    final cell = RegExp(
      r'`([A-Za-z_][A-Za-z0-9_]*)`',
    ).firstMatch(line.split('|')[1]);
    if (cell != null) names.add(cell.group(1)!);
  }
  return names;
}

/// One type declared by the package, with what it declares and what it
/// inherits from.
class _Declaration {
  _Declaration(this.name);

  final String name;

  /// Whether the type is declared `abstract`.
  bool isAbstract = false;

  /// Member names declared directly on this type — fields, getters, setters,
  /// methods, statics, named constructors and enum values alike. The kind does
  /// not matter to the question being asked, which is only whether the name
  /// belongs to this class at all.
  final Set<String> members = {};

  /// The members declared without a body or an initialiser — the ones whose
  /// declaration ends at a `;`.
  ///
  /// For a method or a getter that is exactly abstractness. For a field it is
  /// "no initialiser", which is not the same thing — a bare `List<Type> types;`
  /// is a real field, not a demand on a subclass. The distinction does not
  /// weaken the comparison this feeds, because both sides of it are measured
  /// the same way: what is being asked is whether a document and the source
  /// agree about the *shape* of a declaration, and for everything that can be
  /// abstract, that shape is abstractness.
  final Set<String> bodilessMembers = {};

  /// The names in the `extends` / `implements` / `with` clause.
  final Set<String> supertypes = {};
}

/// Matches a type declaration that can own members, anchored at column zero.
///
/// `typedef` and `extension` are deliberately absent. A typedef declares no
/// members, and an extension's members belong to the type it extends rather
/// than to itself — including either would attribute members to a name that
/// does not own them, which is the error this group exists to catch.
final RegExp _ownerDeclaration = RegExp(
  r'^(?:abstract\s+|final\s+|sealed\s+|base\s+|interface\s+|mixin\s+)*'
  r'(?:class|mixin|enum|extension type)\s+([A-Za-z_][A-Za-z0-9_]*)',
);

/// The modifiers that may precede a member's type, stripped before the name is
/// looked for.
///
/// `static` is the load-bearing one: a record return type makes the
/// declaration read `static (String, List<String>) toPositionalStatement(…)`,
/// where `static (` is indistinguishable from a call and would otherwise be
/// taken for the member's name.
///
/// An annotation is matched *with its argument list* rather than as a bare
/// `@\w+` followed by a space, because an annotation that carries arguments
/// otherwise survives the strip and is then read as a declaration:
/// `@TomDbColumn('name')` looks exactly like a call, so the entity classes each
/// gained a phantom member called `TomDbColumn`, and a bare `@override` on its
/// own line gained one called `override`. Those names belong to no class, and a
/// census that contains them cannot be asked what a class actually declares.
final RegExp _memberModifiers = RegExp(
  r'^\s*(?:@\w+(?:\s*\((?:[^()]|\([^()]*\))*\))?\s*|static\s+|final\s+'
  r'|late\s+|const\s+|external\s+|abstract\s+|covariant\s+|factory\s+)*',
);

/// The characters that open a *continuation* of the previous line rather than a
/// declaration of their own: the close of a wrapped parameter list or literal,
/// and the start of an initialiser list.
///
/// `  }) : id = id ?? const UuidV4().generate(),` is the tail of a constructor
/// whose named parameters were wrapped, and it is indented exactly like a
/// member. Read as one it declares `UuidV4`; its siblings declare `super`,
/// `unmodifiable`, `toUtc` and `toList` — the vocabulary of the initialiser
/// expressions rather than of the class. Nothing that is a declaration begins
/// with any of these characters.
final RegExp _continuationLine = RegExp(r'^\s*[)\]}:]');

/// An identifier followed by an argument list — the shape of a method or
/// constructor declaration, and the anchor the member name is read from.
final RegExp _parameterList = RegExp(r'(\w+)\s*(?:<[^<>]*>)?\s*\(');

/// The last identifier of a string — a field or getter's name, once the
/// initialiser and the trailing `;` are gone.
final RegExp _trailingIdentifier = RegExp(r'([A-Za-z_][A-Za-z0-9_]*)\s*$');

/// An enum value: an identifier opening a two-space-indented line.
final RegExp _enumValue = RegExp(r'^  ([a-z]\w*)\s*[,;(]');

/// The clause naming the supertypes, and the type names inside it.
final RegExp _supertypeClause = RegExp(
  r'\b(?:extends|implements|with)\s+([\w\s,]+)',
);
final RegExp _supertypeName = RegExp(r'\b([A-Z]\w+)');

/// [source] with every type-argument list removed.
///
/// Applied before the supertypes are read, because the *first* `extends` on
/// `class MariadbPreparedStatement<T extends Object> extends
/// TomPreparedStatement<T>` is the bound inside the type parameters. Reading
/// from there makes `Object` a supertype, and since this package does not
/// declare `Object` every lookup on the class becomes undecidable — the guard
/// would go quiet on exactly the class the misfiled static was blamed on.
String _withoutTypeArguments(String source) {
  final generic = RegExp(r'<[^<>]*>');
  var result = source;
  String previous;
  do {
    previous = result;
    result = result.replaceAll(generic, '');
  } while (previous != result);
  return result;
}

/// The offset in [line] where the declaration stops and the body or the
/// initialiser starts, i.e. the first `{`, `=` or `=>` outside any brackets.
///
/// Depth is what makes this correct rather than approximate. Both characters
/// occur *inside* a parameter list — `({String sentence, …})` as a record
/// return type, `{int retries = 3}` as an optional parameter — and cutting
/// there truncates the declaration before its name. Only a delimiter at depth
/// zero ends the declaration.
int _declarationEnd(String line) {
  var depth = 0;
  for (var i = 0; i < line.length; i++) {
    final character = line[i];
    if (character == '(' || character == '[') {
      depth++;
    } else if (character == ')' || character == ']') {
      depth--;
    } else if (depth == 0) {
      if (character == '{') return i;
      if (character != '=') continue;
      // `==`, `!=`, `<=` and `>=` are comparisons in a default value, not the
      // start of one. `=>` is an expression body, so cutting at it is right.
      final previous = i == 0 ? '' : line[i - 1];
      final next = i + 1 < line.length ? line[i + 1] : '';
      if ('=!<>'.contains(previous) || next == '=') continue;
      return i;
    }
  }
  return line.length;
}

/// [line] with any trailing `//` comment removed.
///
/// A comment is invisible to a reader and must be invisible to the parser, and
/// it is not: `bool get supportsCopies;   // Cc / Bcc` ends at its `;`, so
/// nothing after it is part of the declaration, and the name-of-last-resort
/// scan reads `Bcc` as the member. That misnames a member precisely when it is
/// *bodiless* — the case this whole comparison exists to catch — so the member
/// resolves against no class, is skipped as inherited, and the disagreement
/// passes unseen. Contract listings annotate their terse members exactly this
/// way, which is why the blind spot sat over the members most worth checking.
///
/// The quote tracking is what keeps `'http://…'` intact. It is per-line, so a
/// `//` inside a *multi-line* string would still be cut; those are stripped
/// wholesale before [_parseDeclarations] ever sees them, and no listing in
/// `doc/` contains one.
String _withoutLineComment(String line) {
  String? quote;
  for (var i = 0; i < line.length; i++) {
    final character = line[i];
    if (quote != null) {
      if (character == r'\') {
        i++;
      } else if (character == quote) {
        quote = null;
      }
      continue;
    }
    if (character == "'" || character == '"') {
      quote = character;
    } else if (character == '/' && i + 1 < line.length && line[i + 1] == '/') {
      return line.substring(0, i);
    }
  }
  return line;
}

/// Whether the declaration starting at [index] ends at a `;` rather than at a
/// body or an initialiser.
///
/// The scan runs *across* lines, which is the whole reason this exists next to
/// [_declarationEnd] rather than reusing it. A declaration need not fit on one
/// line — a wrapped parameter list closes on a later one — and a single-line
/// verdict reads every wrapped method as bodiless, i.e. as abstract. That would
/// be a false alarm on the most elaborate signatures in the package, which are
/// precisely the ones a document is most likely to get wrong.
bool _endsWithoutBody(List<String> lines, int index) {
  var depth = 0;
  for (var i = index; i < lines.length && i < index + 40; i++) {
    final line = _withoutLineComment(lines[i]);
    if (i > index && line.trimLeft().startsWith('///')) continue;
    for (var j = 0; j < line.length; j++) {
      final character = line[j];
      if (character == '(' || character == '[') {
        depth++;
      } else if (character == ')' || character == ']') {
        depth--;
      } else if (depth == 0) {
        if (character == '{') return false;
        if (character == ';') return true;
        if (character != '=') continue;
        final previous = j == 0 ? '' : line[j - 1];
        final next = j + 1 < line.length ? line[j + 1] : '';
        if ('=!<>'.contains(previous) || next == '=') continue;
        return false;
      }
    }
  }
  return false;
}

/// The member [line] declares, or `null` when it declares none.
///
/// Two shapes, distinguished by whether the declaration carries a parameter
/// list. With one, the name is the identifier introducing it; without one, the
/// name is the last identifier before the initialiser. `Function` is skipped
/// because `final DateTime Function() clock;` is a *field* whose type happens
/// to spell a parameter list.
String? _memberNameOf(String rawLine) {
  if (!rawLine.startsWith('  ') || rawLine.startsWith('   ')) return null;
  final line = _withoutLineComment(rawLine).trimRight();
  if (_continuationLine.hasMatch(line)) return null;

  var head = line.substring(0, _declarationEnd(line));
  head = head.substring(_memberModifiers.matchAsPrefix(head)?.end ?? 0);

  for (final match in _parameterList.allMatches(head)) {
    if (match.group(1) != 'Function') return match.group(1);
  }

  var remainder = head.trimRight();
  if (remainder.endsWith(';')) {
    remainder = remainder.substring(0, remainder.length - 1).trimRight();
  }
  return _trailingIdentifier.firstMatch(remainder)?.group(1);
}

/// Every type the package declares, keyed by name.
///
/// The multi-line string literals and block comments go first: their contents
/// are unindented prose, and a line of it at column zero would be read as the
/// end of the enclosing class, silently truncating the member list of whatever
/// class happened to contain one.
Map<String, _Declaration> _parseDeclarations() {
  final declarations = <String, _Declaration>{};
  final sources = Directory('lib/src/tomserver')
      .listSync(recursive: true)
      .whereType<File>()
      .where((entry) => entry.path.endsWith('.dart'));

  for (final file in sources) {
    final source = file
        .readAsStringSync()
        .replaceAll(RegExp(r"'''[\s\S]*?'''"), "''")
        .replaceAll(RegExp(r'"""[\s\S]*?"""'), '""')
        .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');

    _Declaration? current;
    // The declaration header, while it is still open. A long type parameter
    // list is wrapped across lines and closes with a `>` at column zero, which
    // read as the end of the class body and dropped every member of the four
    // classes declared that way — `TomEndpointBase` and `TomReference` among
    // them. So the header is accumulated until its `{`, and the supertypes are
    // read from the whole of it rather than from its first line.
    final header = <String>[];

    void readSupertypes(String text) {
      final clause = _supertypeClause.firstMatch(_withoutTypeArguments(text));
      if (clause == null) return;
      current!.supertypes.addAll(
        _supertypeName.allMatches(clause.group(1)!).map((m) => m.group(1)!),
      );
    }

    final lines = source.split('\n');
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      if (line.trimLeft().startsWith('///')) continue;

      if (header.isNotEmpty) {
        header.add(line);
        // `;` ends a mixin application (`class A = B with C;`), which has no
        // body at all.
        if (!line.contains('{') && !line.contains(';')) continue;
        readSupertypes(header.join(' '));
        header.clear();
        continue;
      }

      final declared = _ownerDeclaration.firstMatch(line);
      if (declared != null) {
        final name = declared.group(1)!;
        current = declarations.putIfAbsent(name, () => _Declaration(name));
        current.isAbstract = line.startsWith('abstract ');
        if (line.contains('{')) {
          readSupertypes(line);
        } else {
          header.add(line);
        }
        continue;
      }
      if (current == null) continue;
      // An unindented line has left the class body behind.
      if (line.isNotEmpty && !line.startsWith(' ')) {
        current = null;
        continue;
      }

      final member = _memberNameOf(line);
      if (member != null) {
        current.members.add(member);
        if (_endsWithoutBody(lines, index)) current.bodilessMembers.add(member);
      }
      final value = _enumValue.firstMatch(line);
      if (value != null) current.members.add(value.group(1)!);
    }
  }
  return declarations;
}

/// Parsed once: every test in the attribution group reads the same census, and
/// re-walking the package per test would be the slowest thing in the suite.
final Map<String, _Declaration> _declarations = _parseDeclarations();

/// Whether [type] declares or inherits [member] — `null` when the answer
/// cannot be established because some ancestor is not declared in this
/// package.
///
/// Inheritance is walked for a deliberate reason and with a known limit. It
/// must be walked, or every member a class inherits would read as absent. The
/// limit is that Dart does not inherit *statics*, so a parent's static
/// documented under a child would pass. That direction is not the drift being
/// chased and would take a real element model to distinguish, whereas the
/// misfiling this catches — a static on the wrong sibling class — does not.
bool? _resolveMember(String type, String member, [Set<String>? visited]) {
  final seen = visited ?? <String>{};
  if (!seen.add(type)) return false;

  final declaration = _declarations[type];
  if (declaration == null) return null;
  if (declaration.members.contains(member)) return true;

  var undecided = false;
  for (final parent in declaration.supertypes) {
    final inherited = _resolveMember(parent, member, seen);
    if (inherited == true) return true;
    if (inherited == null) undecided = true;
  }
  return undecided ? null : false;
}

/// One member row of a summary, with the class its heading attributes it to.
typedef _Attribution = ({String file, int line, String type, String member});

/// The sub-headings that divide a class's section. They group the rows by kind
/// and must not be read as a new class, or every table under one would be
/// skipped.
const Set<String> _memberSectionHeadings = {
  'Properties',
  'Methods',
  'Static Methods',
  'Constructors',
  'Constructor',
  'Factory Constructors',
  'Static Properties',
  'Static Fields',
  'Fields',
  'Enum Values',
  'Values',
  'Operators',
  'Static Members',
  'Static Constants',
  'Properties and Methods',
};

/// A qualifier appended to a member heading to say *which* members it holds:
/// `Methods — aggregates`, `Properties (DbCol)`.
final RegExp _memberSectionQualifier = RegExp(r'\s(?:[—–-]\s.*|\(.*\))$');

/// Whether [title] heads a member section rather than a class.
///
/// A long table is sometimes split by subject — `##### Methods — aggregates`,
/// `##### Properties (DbCol)` — and an exact-match lookup does not recognise
/// those. The consequence is not that they are read as a class (they are not
/// capitalised like one) but that they are read as *neither*, which closes the
/// current class and leaves every row beneath attributed to nothing. The seven
/// dialect methods split out that way were invisible to every check that reads
/// member rows. So the qualifier is cut and the kind matched on.
bool _isMemberSection(String title) => _memberSectionHeadings.contains(
  title.replaceFirst(_memberSectionQualifier, ''),
);

/// Every member row in `doc/api_reference/`, paired with the class it is filed
/// under — the rows of [_classSections], flattened.
List<_Attribution> _attributions() => [
  for (final section in _classSections)
    for (final row in section.rows)
      (
        file: section.file,
        line: row.line,
        type: section.type,
        member: row.member,
      ),
];

/// One class's section of a summary: the member rows filed under it, and every
/// identifier the section mentions anywhere — in a row, in a constructor
/// listing, or in prose.
///
/// The two are read for opposite questions. The rows answer "is this documented
/// member real", so they must be exact. The mentions answer "is this real member
/// documented", where a name that appears only in a fenced constructor or in a
/// sentence is documented just as truly as one with a row of its own — a factory
/// constructor has no row anywhere in this package, and demanding one would
/// force every summary to restate its listings as a table.
typedef _ClassSection = ({
  String file,
  String type,
  List<({int line, String member})> rows,
  Set<String> mentions,
});

/// The class sections of one summary [file] whose content is [lines].
///
/// A heading is taken for a class when it names one the package declares —
/// rather than by its depth, which is not uniform: the audit summary files
/// classes at `###` and the datasources summary at `####`. Any other heading
/// ends the current class, so rows under `## Overview` are attributed to
/// nothing instead of to whichever class was last seen.
///
/// A generic class is headed with its type parameters HTML-escaped
/// (`#### MariadbPreparedStatement&lt;T&gt;`), so the parameters are stripped
/// before the name is matched. Without that every generic class is skipped
/// silently — twenty-one of them, including both prepared-statement classes,
/// which is to say the guard would be blind in exactly the section that held
/// the misfiled static.
List<_ClassSection> _classSectionsOf(String file, List<String> lines) {
  final heading = RegExp(r'^#{2,6}\s+(.*?)\s*$');
  final memberRow = RegExp(r'^\|\s*`(\w+)`');
  final typeName = RegExp(r'^[A-Z]\w*$');
  final typeParameters = RegExp(r'&lt;.*&gt;|<[^<>]*>');
  final identifier = RegExp(r'[A-Za-z_]\w*');

  final sections = <_ClassSection>[];
  _ClassSection? current;
  for (var i = 0; i < lines.length; i++) {
    final title = heading.firstMatch(lines[i])?.group(1);
    if (title != null) {
      if (_isMemberSection(title)) continue;
      final type = title.replaceAll(typeParameters, '').trim();
      if (!typeName.hasMatch(type) || !_declarations.containsKey(type)) {
        current = null;
        continue;
      }
      current = (file: file, type: type, rows: [], mentions: {});
      sections.add(current);
      continue;
    }
    if (current == null) continue;
    final member = memberRow.firstMatch(lines[i])?.group(1);
    if (member != null) current.rows.add((line: i + 1, member: member));
    current.mentions.addAll(
      identifier.allMatches(lines[i]).map((match) => match.group(0)!),
    );
  }
  return sections;
}

/// Parsed once: every class section of every summary in `doc/api_reference/`.
final List<_ClassSection> _classSections = [
  for (final file
      in Directory('doc/api_reference').listSync().whereType<File>().where(
        (e) => e.uri.pathSegments.last.startsWith('api_summary_'),
      ))
    ..._classSectionsOf(file.uri.pathSegments.last, file.readAsLinesSync()),
];

/// Every name mentioned under a class, across all summaries.
final Map<String, Set<String>> _mentionsByType = () {
  final byType = <String, Set<String>>{};
  for (final section in _classSections) {
    (byType[section.type] ??= <String>{}).addAll(section.mentions);
  }
  return byType;
}();

/// The `Object` members whose override a class section need not mention.
///
/// The question a member list answers is "what can I call on this that I could
/// not have known without reading it". An override of one of these adds nothing
/// to that: the member exists on every class whether or not it is overridden,
/// and a caller who wants it does not go looking in a summary. Demanding them
/// would have added a `toString` row to thirty-odd sections and taught the
/// reader nothing.
const Set<String> _universalMembers = {
  'toString',
  'hashCode',
  'noSuchMethod',
  'runtimeType',
};

/// Whether [member] is documented for [type] — under its own section, or under
/// the section of an ancestor that declares it.
///
/// Ancestors count because an override is not new API. `TomSqlDatasourceRepository`
/// implements twenty-one methods of `TomCrudRepository`, all documented once on
/// the interface where they are defined; requiring the implementation section to
/// restate them would make the summary longer and the reader's job harder, and
/// it is the interface that a caller programs against anyway.
bool _mentionsMember(String type, String member, [Set<String>? visited]) {
  final seen = visited ?? <String>{};
  if (!seen.add(type)) return false;
  if (_mentionsByType[type]?.contains(member) ?? false) return true;
  for (final parent in _declarations[type]?.supertypes ?? const <String>{}) {
    if (_mentionsMember(parent, member, seen)) return true;
  }
  return false;
}

/// The public members [type] declares that no section of it — nor of any
/// ancestor — mentions, sorted.
List<String> _undocumentedMembers(String type) =>
    (_declarations[type]?.members ?? const <String>{})
        .where((member) => !member.startsWith('_'))
        // The unnamed constructor is spelled with the class's own name, and it
        // is documented as a fenced signature under `Constructors` rather than
        // as a member of itself.
        .where((member) => member != type)
        .where((member) => !_universalMembers.contains(member))
        .where((member) => !_mentionsMember(type, member))
        .toList()
      ..sort();

/// `type: a, b, c` for every class documented in [module]'s summary that has
/// undocumented members — empty when the summary is complete.
List<String> _incompleteSectionsOf(String module) => [
  for (final section in _classSections)
    if (section.file == 'api_summary_$module.md')
      if (_undocumentedMembers(section.type) case final missing
          when missing.isNotEmpty)
        '${section.type}: ${missing.join(', ')}',
];

/// One member as a module document's class listing presents it.
typedef _ListedMember = ({
  String file,
  int line,
  String type,
  String member,
  bool bodiless,
});

/// The header of a contract listing inside a fenced Dart block.
///
/// Only `abstract class` qualifies, because only there does a bare declaration
/// *mean* anything: a concrete class cannot hold an abstract member, so a bare
/// declaration in a listing of one is unambiguously a body left out for
/// brevity. Reading those as claims would fail every concrete-class listing in
/// `doc/` for saying something it never said.
final RegExp _listingHeader = RegExp(r'^abstract class ([A-Za-z_]\w*)');

/// Listings that describe *application* code rather than this package's.
///
/// `doc/audit.md` shows an invented `AdminApi` to demonstrate that
/// `@TomAudited` on a method audits the invocation; nothing in `lib/` declares
/// it, and nothing should. Naming the exemption rather than skipping every
/// unresolvable class keeps the reach check able to say what it is for: a
/// listing whose class has quietly been renamed still fails, because the
/// rename produces a name that is not on this list.
const Set<String> _illustrativeListings = {'AdminApi'};

/// A member declaration that cannot be abstract whatever its shape.
///
/// A `static` is never abstract, and neither is a constructor — a bodiless
/// `TomTypedPersistenceBase(this.types);` still constructs, and the source's
/// having a body there says nothing a subclass must act on. Comparing either
/// would report a difference that is not a defect.
bool _cannotBeAbstract(String line, String type) {
  final head = line.trimLeft();
  if (RegExp(r'^(?:@\w+\s+)*static\b').hasMatch(head)) return true;
  return RegExp('^(?:const |factory )*$type\\s*[.(]').hasMatch(head);
}

/// Every member of every contract listing in the module documents.
List<_ListedMember> _listedMembers() => Directory('doc')
    .listSync()
    .whereType<File>()
    .where((entry) => entry.path.endsWith('.md'))
    .expand(
      (file) =>
          _listedMembersOf(file.uri.pathSegments.last, file.readAsLinesSync()),
    )
    .toList();

/// The contract-listing members of one document, reported under [file].
///
/// Split from [_listedMembers] so the line handling can be exercised on a
/// listing written for the purpose. Its rules are individually small and
/// jointly not obvious — which fence counts, where a listing ends, what resets
/// the current class — and each of them, when wrong, changes *which class a
/// member is attributed to* rather than producing an error.
List<_ListedMember> _listedMembersOf(String file, List<String> lines) {
  final found = <_ListedMember>[];
  var inDart = false;
  String? current;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.startsWith('```')) {
      inDart = line.startsWith('```dart');
      current = null;
      continue;
    }
    if (!inDart) continue;

    final header = _listingHeader.firstMatch(line);
    if (header != null) {
      current = header.group(1);
      continue;
    }
    // A `}` at column zero closes the listing; anything else at column zero is
    // a sibling declaration, and either way the members have ended. Without
    // this the members of a concrete class declared later in the same fence —
    // `doc/audit.md` puts one right before its listing — are read as members
    // of the abstract class above, and are then compared against a class that
    // never declared them.
    if (line.isNotEmpty && !line.startsWith(' ')) {
      current = null;
      continue;
    }
    if (current == null) continue;
    if (_cannotBeAbstract(line, current)) continue;

    final member = _memberNameOf(line);
    if (member == null) continue;
    found.add((
      file: file,
      line: i + 1,
      type: current,
      member: member,
      bodiless: _endsWithoutBody(lines, i),
    ));
  }
  return found;
}

/// One claim of unfinished work, and where it was made.
typedef _UnfinishedClaim = ({String file, int line, String text});

/// A phrase by which a guide tells the reader something is not finished.
///
/// Deliberately narrow. A guide is full of prose that *sounds* provisional —
/// "for now", "at present", "deliberate" — and matching that would report a
/// dozen sentences that are simply describing a design. What is matched here
/// is the small set of phrases that assert a *state of the work* rather than a
/// property of the software, which is the only kind of sentence that can be
/// falsified by finishing the work.
final RegExp _unfinishedClaim = RegExp(
  r'tracked follow-?up|is a follow-?up|not yet implemented|completion steps|'
  r'will be added|planned for|not implemented|yet to be',
  caseSensitive: false,
);

/// The heading under which a guide collects what it has not done.
///
/// Two spellings, both in use: eleven guides say `Not Yet Implemented` and
/// `doc/authentication.md` says `Status and Limitations`. Which word is used
/// does not matter to this check — what matters is that there is exactly one
/// place per document where such a claim lives.
final RegExp _limitationsHeading = RegExp(
  r'^##\s+(?:Not Yet Implemented|Status and Limitations)\s*$',
);

/// Whether `doc/[module].md` has somewhere to put a claim of unfinished work.
///
/// The heading has to be a `##` section of its own, because that is what the
/// sweep above scopes to and what the table of contents links to. A `###`
/// sub-heading inside a chapter would read the same to a human and be invisible
/// to both.
bool _hasLimitationsSection(String module) =>
    File('doc/$module.md').readAsLinesSync().any(_limitationsHeading.hasMatch);

/// Guides with no section for what the module has not done.
///
/// Surfaced as a `skip:` rather than a filtered list so the gap is visible in
/// the run. Tracked by quest todo `tcincb126_ahxt`.
const Set<String> _limitationsPendingSection = {
  'authorization',
  'db_migration',
  'healthcheck',
  'little_things',
  'preferences',
  'resources',
  'scheduling',
  'transactions',
};

/// A link *to* the limitations section, as the table of contents and the
/// cross-references in the prose both write it.
///
/// Pointing at the section is the correct pattern, not a violation of it: the
/// claim still lives in one place and the sentence in the chapter is a signpost
/// to it. Only an unsignposted claim is counted.
final RegExp _limitationsLink = RegExp(
  r'\]\(#(?:not-yet-implemented|status-and-limitations)\)',
  caseSensitive: false,
);

/// The claims of unfinished work [file] makes outside its limitations section.
///
/// The unit of judgement is the **paragraph**, not the line, and that is not a
/// detail. These guides wrap at eighty columns, so a claim and the signpost
/// that excuses it routinely land on different lines — "…is not yet
/// implemented — see" / "[Not Yet Implemented](#not-yet-implemented) before
/// relying on it". Judging line by line reports that as a violation, and a
/// guard whose first report is a false alarm gets deleted rather than heeded.
///
/// Taking the paragraph does mean a second, unsignposted claim in an already
/// signposted paragraph goes unreported. That is the right way round to be
/// wrong: the cost of the miss is one sentence in a paragraph that already
/// directs the reader to the section, whereas the cost of the false alarm is
/// the whole check.
///
/// Fenced blocks are skipped entirely — a listing may be quoting a `// TODO`
/// as an example of what *not* to write.
///
/// A heading is an ordinary line. Every heading in these guides already has a
/// blank line above it, so separating it from the prose gains nothing — and
/// reading it as prose costs nothing while buying something: a rival
/// `### … not yet implemented` *heading* outside the swept section is a second
/// place the document collects unfinished work, which is the one arrangement
/// this check exists to prevent, and it is reported rather than skipped.
List<_UnfinishedClaim> _unfinishedClaimsOutsideSection(
  String file,
  List<String> lines,
) {
  var sectionStart = -1;
  var sectionEnd = lines.length;
  for (var i = 0; i < lines.length; i++) {
    if (_limitationsHeading.hasMatch(lines[i])) {
      sectionStart = i;
      sectionEnd = lines.length;
    } else if (sectionStart >= 0 &&
        sectionEnd == lines.length &&
        lines[i].startsWith('## ')) {
      sectionEnd = i;
    }
  }

  final found = <_UnfinishedClaim>[];
  for (final paragraph in _paragraphsOf(
    lines,
    isExcluded: (i) => sectionStart >= 0 && i >= sectionStart && i < sectionEnd,
  )) {
    if (paragraph.any((i) => _limitationsLink.hasMatch(lines[i]))) continue;
    for (final i in paragraph) {
      if (!_unfinishedClaim.hasMatch(lines[i])) continue;
      found.add((file: file, line: i + 1, text: lines[i].trim()));
    }
  }
  return found;
}

/// [lines] grouped into paragraphs, each a list of line indices.
///
/// Two checks in this file judge a document by the paragraph rather than the
/// line, for the same reason — these guides wrap at eighty columns, so a
/// sentence and the thing that qualifies it routinely land on different lines.
/// The rules for where a paragraph ends are small but easy to get subtly wrong,
/// and wrong here does not fail: it moves a line into a neighbouring paragraph,
/// which silently changes whether that neighbour's qualifier applies to it.
/// One implementation, exercised by both.
///
/// [includeFenced] is the one thing the two callers disagree about. Prose about
/// unfinished work must ignore fences, because a listing may be quoting a
/// `// TODO` as an example of what *not* to write; a reference to a test file
/// must read them, because a fenced block is exactly where a runnable command
/// naming a script lives.
///
/// [isExcluded] drops a line and ends the paragraph it would have joined, which
/// is how the limitations section is held out without a second walk.
List<List<int>> _paragraphsOf(
  List<String> lines, {
  bool includeFenced = false,
  bool Function(int index)? isExcluded,
}) {
  final paragraphs = <List<int>>[];
  var current = <int>[];
  var fenced = false;

  void close() {
    if (current.isNotEmpty) paragraphs.add(current);
    current = [];
  }

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.startsWith('```')) {
      close();
      fenced = !fenced;
      continue;
    }
    if (fenced && !includeFenced) continue;
    if (line.trim().isEmpty || (isExcluded?.call(i) ?? false)) {
      close();
      continue;
    }
    current.add(i);
  }
  close();
  return paragraphs;
}

/// A test suite or tool script a guide names, and where it names it.
typedef _NamedArtifact = ({String file, int line, String path});

/// A path to a suite or a script, as a guide writes one.
///
/// Matched anywhere on the line rather than only inside backticks, because the
/// reference that matters most is the runnable one — `tool/run_db_tests.sh` in
/// a fenced block is the line a reader will actually copy.
final RegExp _artifactReference = RegExp(r'[\w./-]+(?:_test\.dart|\.sh)\b');

/// A sibling sample package, whose suites live outside this package.
///
/// `doc/audit.md`, `doc/export.md`, `doc/messaging.md` and `doc/resources.md`
/// each point at a worked example in `advanced_ops_server`, writing its suite
/// as `test/ops_anchor_test.dart` — a path relative to *that* package. Naming
/// the package is what makes the path unambiguous, so naming it is what excuses
/// the reference from resolving here.
final RegExp _samplePackage = RegExp(r'advanced_\w+');

/// The suites and scripts [file] names that do not exist.
///
/// The claim being checked is small and completely mechanical: a guide that
/// tells the reader which suite covers something must name a suite that is
/// really there. It earns its place by making the *attribution* load-bearing.
/// `doc/datasources.md` used to say the unit tests covered "the
/// connection-independent surface" and name nothing, so when a second suite
/// arrived there was no name to go stale and nothing to re-read — the sentence
/// simply went on being wrong. A named suite cannot do that: rename or delete
/// it and this fails, which puts whoever moved it in front of the prose.
List<_NamedArtifact> _missingArtifacts(String file, List<String> lines) {
  final missing = <_NamedArtifact>[];
  for (final paragraph in _paragraphsOf(lines, includeFenced: true)) {
    final context = paragraph.map((i) => lines[i]).join(' ');
    final borrowed = _samplePackage.hasMatch(context);
    for (final i in paragraph) {
      for (final match in _artifactReference.allMatches(lines[i])) {
        final path = match.group(0)!;
        // `test/x_test.dart` as written, or the bare `x_test.dart` the prose
        // uses once the surrounding sentence has already said where it lives.
        if (File(path).existsSync()) continue;
        if (File('test/${path.split('/').last}').existsSync()) continue;
        if (borrowed) continue;
        missing.add((file: file, line: i + 1, path: path));
      }
    }
  }
  return missing;
}

/// Every module guide, as (name, lines).
List<(String, List<String>)> _guides() =>
    Directory('doc')
        .listSync()
        .whereType<File>()
        .where((entry) => entry.path.endsWith('.md'))
        .map((file) => (file.uri.pathSegments.last, file.readAsLinesSync()))
        .toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));

/// Every runnable artefact under `example/<module>/`, as a guide would write
/// the path.
///
/// Both extensions count. An example is not always a Dart program —
/// `example/scheduling/cluster/run_cluster_demo.sh` is the one artefact that
/// substantiates the cluster claims, and a guide that names it has pointed the
/// reader at the right thing.
List<String> _exampleArtifacts(String module) {
  final directory = Directory('example/$module');
  if (!directory.existsSync()) return const [];
  return [
    for (final entry in directory.listSync(recursive: true))
      if (entry is File &&
          (entry.path.endsWith('.dart') || entry.path.endsWith('.sh')))
        entry.path,
  ]..sort();
}

/// Matches a suite path, however a guide writes one.
final RegExp _suiteReference = RegExp(r'[\w./-]*_test\.dart\b');

/// What `doc/<module>.md` never points the reader at, in words.
///
/// Two artefacts, checked together because a reader arrives with one question:
/// *what actually substantiates this?* A guide answers it with the suite that
/// covers the behaviour and the example that shows it being used. Naming
/// neither is how `doc/datasources.md` spent a year describing an example that
/// nobody ran and whose every expectation was an `assert` — inert under the
/// `dart run` its own header documents.
///
/// Migration SQL under `example/<module>/migrations/` does not count, because
/// it is reference data a guide cites while explaining a table, not something
/// a reader runs; only `.dart` and `.sh` artefacts are looked for.
List<String> _unnamedVerification(String module) {
  final text = File('doc/$module.md').readAsStringSync();
  final examples = _exampleArtifacts(module);
  return [
    if (!_suiteReference.hasMatch(text)) 'names no test suite',
    if (examples.isNotEmpty && !examples.any(text.contains))
      'names none of its examples (${examples.join(', ')})',
  ];
}

/// The modules whose guide does not yet name the suite and the example that
/// verify it — quest todo `tcincb125_ahxt`.
const Set<String> _verificationPendingAttribution = {
  'audit',
  'authentication',
  'db_migration',
  'endpoints',
  'export',
  'file_storage',
  'healthcheck',
  'little_things',
  'messaging',
  'object_persistence',
  'server',
  'transactions',
};

/// The modules whose Overview table has not been reconciled against its
/// exports yet — quest todo `tcincb3_ahwn`.
///
/// A quarantine rather than an opt-in list, so that the default for a *new*
/// module is checked. The debt is deliberately spent as a visible skip on every
/// run: the trap this file exists to close is an invariant nobody was looking
/// at, and a list of modules silently exempted from the check would be the same
/// trap wearing the check's clothes.
const Set<String> _tablesPendingReconciliation = {
  'authentication',
  'configuration',
  'endpoints',
  'export',
  'file_storage',
  'little_things',
  'object_persistence',
  'preferences',
  'scheduling',
};

/// The modules whose summary `Source:` list has not been reconciled against the
/// barrel yet — quest todo `tcincb121_ahxs`.
const Set<String> _sourceListsPendingReconciliation = {
  'authorization',
  'endpoints',
  'object_persistence',
};

/// The modules whose class sections do not yet name every member their classes
/// declare — quest todos `tcincb123_ahxt` (authentication) and
/// `tcincb124_ahxt` (object_persistence).
const Set<String> _memberListsPendingReconciliation = {
  'authentication',
  'object_persistence',
};

/// The modules whose exported names are not all in the index yet — quest todo
/// `tcincb122_ahxs`.
const Set<String> _indexPendingReconciliation = {
  'audit',
  'authentication',
  'authorization',
  'configuration',
  'endpoints',
  'object_persistence',
};

void main() {
  group('doc/api_reference mirrors lib/src/tomserver', () {
    test('every module has an API summary', () {
      final modules = _modules();
      final summaries = _docs(
        'doc/api_reference',
        stripPrefix: 'api_summary_',
      ).where((name) => name != 'index').toList();

      final missing = modules.where((m) => !summaries.contains(m)).toList();
      expect(
        missing,
        isEmpty,
        reason:
            'These modules have no doc/api_reference/api_summary_<module>.md: '
            '${missing.join(', ')}. Add one following the structure the other '
            'summaries use and list it in api_summary_index.md.',
      );
    });

    test('every API summary has a module', () {
      final modules = _modules();
      final summaries = _docs(
        'doc/api_reference',
        stripPrefix: 'api_summary_',
      ).where((name) => name != 'index').toList();

      final orphaned = summaries.where((s) => !modules.contains(s)).toList();
      expect(
        orphaned,
        isEmpty,
        reason:
            'These API summaries document no module under lib/src/tomserver/: '
            '${orphaned.join(', ')}. Delete the summary, or rename it if the '
            'module was renamed.',
      );
    });

    test('every module has a narrative guide', () {
      final modules = _modules();
      final guides = _docs('doc');

      final missing = modules.where((m) => !guides.contains(m)).toList();
      expect(
        missing,
        isEmpty,
        reason:
            'These modules have no doc/<module>.md guide: '
            '${missing.join(', ')}. The summary lists the API; the guide '
            'explains what it is for, and both are expected.',
      );
    });

    test('the index links every API summary', () {
      final index = File(
        'doc/api_reference/api_summary_index.md',
      ).readAsStringSync();
      final summaries = _docs(
        'doc/api_reference',
        stripPrefix: 'api_summary_',
      ).where((name) => name != 'index').toList();

      final unlisted = summaries
          .where((s) => !index.contains('api_summary_$s.md'))
          .toList();
      expect(
        unlisted,
        isEmpty,
        reason:
            'api_summary_index.md does not link these summaries: '
            '${unlisted.join(', ')}. An index that omits part of the package '
            'reads as complete, so an unlisted summary is an invisible one.',
      );
    });
  });

  group('each guide\'s Overview table lists the module\'s exported API', () {
    for (final module in _modules()) {
      final table = _overviewTableTypes(module);
      if (table == null) continue;

      test(
        module,
        () {
          final exported = _exportedApi(module);

          final missing = exported.where((t) => !table.contains(t)).toList();
          expect(
            missing,
            isEmpty,
            reason:
                'doc/$module.md\'s Overview table does not list these exported '
                'names: ${missing.join(', ')}. The table is the first thing '
                'the guide shows, so a reader takes it for the module\'s '
                'surface and concludes an unlisted name does not exist — which '
                'is how three of this module\'s ten files became invisible.',
          );

          final orphaned = table.where((t) => !exported.contains(t)).toList();
          expect(
            orphaned,
            isEmpty,
            reason:
                'doc/$module.md\'s Overview table names these, which the '
                'barrel does not export from $module: ${orphaned.join(', ')}. '
                'Either it was renamed or removed, or it belongs to another '
                'module\'s table.',
          );
        },
        skip: _tablesPendingReconciliation.contains(module)
            ? 'Overview table not reconciled yet — quest todo tcincb3_ahwn.'
            : null,
      );
    }

    test('every quarantined module still has a table to reconcile', () {
      final stale = _tablesPendingReconciliation
          .where((module) => _overviewTableTypes(module) == null)
          .toList();
      expect(
        stale,
        isEmpty,
        reason:
            'These modules are quarantined but have no Overview table: '
            '${stale.join(', ')}. A quarantine entry that names nothing '
            'suppresses no check and reads as outstanding debt that is not, '
            'so remove it.',
      );
    });

    test('the scan reads the declaration shapes an exported file uses', () {
      // Each line below is a shape the package actually contains, and three of
      // them are shapes that defeated an earlier reading of it.
      final found = _declaredApi('''
class TomWidget {}
abstract class TomContract {}
mixin TomMixin {}
enum TomMode { a, b }
extension TomExt on String {}
typedef TomAlias = int;
String renderThing(int value) => '';
Future<List<String>> loadThings<T>(int n) async => [];
String get tomAppId => '';
String _privateThing(int n) => '';
class _PrivateWidget {}
const tomBareConstant = 3;
final tomBareVariable = buildDefaultThing();
''');

      expect(found, contains('TomWidget'), reason: 'a class');
      expect(found, contains('TomContract'), reason: 'an abstract class');
      expect(found, contains('TomMixin'), reason: 'a mixin');
      expect(found, contains('TomMode'), reason: 'an enum');
      expect(found, contains('TomExt'), reason: 'an extension');
      expect(found, contains('TomAlias'), reason: 'a typedef');
      expect(found, contains('renderThing'), reason: 'a top-level function');
      expect(found, contains('loadThings'), reason: 'a generic function');

      // The one shape no live comparison reaches: `configuration`'s `tomAppId`
      // is the package's only exported top-level getter, and that module's
      // table is still quarantined. Without this line, deleting the getter
      // pattern would break nothing that anyone would notice.
      expect(found, contains('tomAppId'), reason: 'a top-level getter');

      expect(found, isNot(contains('_privateThing')));
      expect(found, isNot(contains('_PrivateWidget')));

      // Top-level variables are deliberately not API — see [_declaredApi].
      expect(found, isNot(contains('tomBareConstant')));
      expect(found, isNot(contains('tomBareVariable')));

      // And the initialiser is not read as a declaration either, which is what
      // the function pattern's refusal to cross an `=` buys. The assertion is
      // on the *callee* rather than on `tomBareVariable`, because a pattern
      // that crossed the `=` would capture the name being called — so the
      // mistake shows up as an unrelated function appearing in the module's
      // API, and only a name declared nowhere else here can catch it.
      expect(found, isNot(contains('buildDefaultThing')));
    });

    test('the scan ignores declarations that are only quoted', () {
      // The multi-line string is the one that defeated the first reading of the
      // package: it is how every framework table's DDL is written, and
      // `CREATE TABLE tom_resource_grant (` has the exact shape of a top-level
      // function declaration, at column zero, where the anchor cannot save it.
      //
      // The doc comment is here for the opposite reason — to hold the claim in
      // [_declaredApi] that comments need no stripping. If an anchor is ever
      // relaxed, this is what notices.
      final found = _declaredApi('''
/// Renders a thing: `String quotedFunction(int value)`.
/// See also [QuotedClass], declared as `class QuotedClass {}`.
const ddl = \'\'\'
CREATE TABLE tom_resource_grant (
  id VARCHAR(191) NOT NULL
)\'\'\';
class RealClass {}
''');

      expect(found, contains('RealClass'));
      expect(found, isNot(contains('quotedFunction')));
      expect(found, isNot(contains('QuotedClass')));
      expect(found, isNot(contains('tom_resource_grant')));
    });
  });

  // A guide's contents list is how a reader finds out what the document covers
  // without reading it, so a section missing from it is a section most readers
  // never learn exists — the same failure as an unlisted type, one level up.
  // Nothing kept the two in step, and adding a section is exactly when the
  // omission happens, because the section is the part being thought about.
  group('each summary\'s Source list names every file it covers', () {
    for (final module in _modules()) {
      test(
        module,
        () {
          final listed = _summarySourceList(module);
          expect(
            listed,
            isNotNull,
            reason:
                'api_summary_$module.md has no "Source:" line. Every other '
                'summary opens its Overview with one, and it is the only place '
                'the document says which files it claims to cover.',
          );

          final exported = _exportedFiles(module);

          final missing = exported.where((f) => !listed!.contains(f)).toList();
          expect(
            missing,
            isEmpty,
            reason:
                'api_summary_$module.md\'s Source list does not name these '
                'files, which the barrel exports: ${missing.join(', ')}. A '
                'file left off the list is a file whose public types nobody '
                'notices are undocumented — which is how framework_table.dart '
                'and sql_instant.dart, four types and four functions between '
                'them, stayed out of this package\'s API reference.',
          );

          final orphaned = listed!.where((f) => !exported.contains(f)).toList();
          expect(
            orphaned,
            isEmpty,
            reason:
                'api_summary_$module.md\'s Source list names these, which the '
                'barrel does not export from $module: ${orphaned.join(', ')}. '
                'Either the file moved, or it is module-internal and the '
                'summary is documenting an API a consumer cannot import.',
          );
        },
        skip: _sourceListsPendingReconciliation.contains(module)
            ? 'Source list not reconciled yet — quest todo tcincb121_ahxs.'
            : null,
      );
    }

    test('every quarantined module still has files missing from its list', () {
      final clean = _sourceListsPendingReconciliation.where((module) {
        final listed = _summarySourceList(module);
        return listed != null &&
            _exportedFiles(module).every(listed.contains) &&
            listed.every(_exportedFiles(module).contains);
      }).toList();
      expect(
        clean,
        isEmpty,
        reason:
            'These modules are quarantined but their Source lists already '
            'agree with the barrel: ${clean.join(', ')}. A quarantine entry '
            'that suppresses nothing reads as outstanding debt that is not, '
            'and it silently disarms the check if the list drifts again.',
      );
    });

    test('the parser reads a list the way the summaries write one', () {
      // Both spellings, a list wrapped across lines, and the blank line that
      // ends it — the shapes the twenty summaries actually use.
      expect(
        _sourceListOf(
          'Source: `lib/src/tomserver/cache/server_cache.dart`.\n'
          '\n'
          'Prose that happens to mention '
          '`lib/src/tomserver/cache/not_a_source.dart`.\n',
        ),
        ['cache/server_cache.dart'],
      );
      expect(
        _sourceListOf(
          'Sources: `lib/src/tomserver/cmdline/args.dart`,\n'
          '`lib/src/tomserver/cmdline/env_file.dart`.\n'
          '\n',
        ),
        ['cmdline/args.dart', 'cmdline/env_file.dart'],
      );
      expect(_sourceListOf('# A summary with no Source line\n'), isNull);
    });
  });

  group('the index names every exported name', () {
    final index = File(
      'doc/api_reference/api_summary_index.md',
    ).readAsStringSync();

    for (final module in _modules()) {
      test(
        module,
        () {
          final missing = _exportedApi(
            module,
          ).where((name) => !_indexNames(index, name)).toList();
          expect(
            missing,
            isEmpty,
            reason:
                'api_summary_index.md names none of these, which the barrel '
                'exports from $module: ${missing.join(', ')}. The index is '
                'where a reader who does not yet know which module owns a name '
                'goes to look it up, so a name absent from it is a name that '
                'can only be found by someone who did not need the index.',
          );
        },
        skip: _indexPendingReconciliation.contains(module)
            ? 'Index not reconciled yet — quest todo tcincb122_ahxs.'
            : null,
      );
    }

    test('every quarantined module still has names missing', () {
      final clean = _indexPendingReconciliation
          .where((m) => _exportedApi(m).every((n) => _indexNames(index, n)))
          .toList();
      expect(
        clean,
        isEmpty,
        reason:
            'These modules are quarantined but the index already names '
            'everything they export: ${clean.join(', ')}. Remove the entry, '
            'or the check stays off for a module that has nothing left to fix.',
      );
    });

    test('the sweep is reading the index it claims to check', () {
      // Every finding above is an emptiness assertion, so an index that failed
      // to load — or a matcher that matched nothing — would pass in silence.
      expect(index, contains('## Alphabetical Type Index'));
      expect(_indexNames(index, 'TomDataSource'), isTrue);
      // The generic shape, which is why the matcher admits a `<` as well as a
      // closing backtick: the index writes `TomDbType<T>`, not `TomDbType`.
      expect(_indexNames(index, 'TomDbType'), isTrue);
      // A prefix must not satisfy a longer name, or `TomDataSource` would
      // vouch for `TomDataSourceInfo` and half the check would be vacuous.
      expect(_indexNames(index, 'TomDataSourceInf'), isFalse);
      expect(_indexNames(index, 'TomNoSuchTypeAtAll'), isFalse);
    });
  });

  group('each summary lists every free function its module exports', () {
    for (final module in _modules()) {
      test(module, () {
        final listed = _globalFunctionNames(module);
        expect(
          listed,
          isNotNull,
          reason:
              'api_summary_$module.md has no "## Global Functions and '
              'Constants" section. Every other summary has one — the ones with '
              'nothing to list say so in a sentence — so its absence reads as '
              'an omission rather than as an answer.',
        );

        final missing = _exportedFunctions(
          module,
        ).where((name) => !listed!.contains(name)).toList();
        expect(
          missing,
          isEmpty,
          reason:
              'api_summary_$module.md\'s Global Functions section does not '
              'name these, which the barrel exports from $module: '
              '${missing.join(', ')}. A free function has no class section to '
              'be found under, so this list is the only place in the summary '
              'it can appear — a module whose section says "None" while '
              'exporting one is not merely incomplete, it is answering the '
              'question wrongly.',
        );

        final exported = _exportedNames(module);
        final stale = listed!
            .where((name) => !exported.contains(name))
            .toList();
        expect(
          stale,
          isEmpty,
          reason:
              'api_summary_$module.md\'s Global Functions section names these, '
              'which $module does not declare: ${stale.join(', ')}. A row for '
              'something that no longer exists is worse than a missing row, '
              'because the reader has no way to tell it from a current one.',
        );
      });
    }

    test('the sweep is reading the sections it claims to check', () {
      // Two of the three findings above are emptiness assertions, so a parser
      // that found no rows at all would report every summary as agreeing.
      final datasources = _globalFunctionNames('datasources')!;
      expect(datasources, contains('sqlInstant'));
      expect(datasources, contains('unknownFrameworkColumns'));
      // The module with the most rows, so a section split across `###`
      // subheadings is known to be read whole rather than to the first break.
      expect(_globalFunctionNames('scheduling'), hasLength(greaterThan(8)));
      // And a module that legitimately lists nothing still has a section.
      expect(_globalFunctionNames('transactions'), isEmpty);
    });

    test('the parser reads a section the way the summaries write one', () {
      // The shapes across the twenty summaries, which differ more than any
      // other section of these documents: a plain table, a table split under
      // `###` subheadings, a first cell carrying a parameter list, and a
      // sentence in place of a table.
      expect(
        _globalFunctionNamesOf('''
intro

## Global Functions and Constants

| Name | Signature | Description |
| ---- | --------- | ----------- |
| `plain` | `void plain()` | one |
| `withArgs(String table)` | `TomFrameworkTable withArgs(String table)` | two |

### Constants

| Constant | Type | Description |
| -------- | ---- | ----------- |
| `aConstant` | `String` | three |

## Next Section

| Name | Signature | Description |
| ---- | --------- | ----------- |
| `notMine` | `void notMine()` | past the boundary |
'''),
        ['plain', 'withArgs', 'aConstant'],
      );
      expect(
        _globalFunctionNamesOf('''
## Global Functions and Constants

None — this module exposes no top-level functions or constants.
'''),
        isEmpty,
      );
      expect(_globalFunctionNamesOf('## Something Else\n\ntext\n'), isNull);
    });

    test('the declaration scan reads the shapes the package writes', () {
      // The two shapes no live comparison would have caught being wrong,
      // because for years neither was seen at all: a record return type, in
      // both the positional and the named spelling.
      expect(
        _declaredFunctions(
          '(TomPrincipal?, TomClientJwtToken?) '
          'extractAuthentication(Request r) {',
        ),
        contains('extractAuthentication'),
      );
      expect(
        _declaredFunctions(
          '({Map<String, Object?> before, Map<String, Object?> after}) '
          'auditDiff(\n  Map<String, Object?> before,\n) {',
        ),
        contains('auditDiff'),
      );
      expect(
        _declaredFunctions('String get tomAppId =>'),
        contains('tomAppId'),
      );
      expect(
        _declaredFunctions('List<TomFrameworkTable> frameworkOwnedTables({'),
        contains('frameworkOwnedTables'),
      );
      // Private declarations and indented members are not surface.
      expect(_declaredFunctions('void _hidden() {}'), isEmpty);
      expect(_declaredFunctions('  void indented() {}'), isEmpty);
      // A constant is not a function, and is admitted only by the broader scan
      // — which is what keeps "lists every free function" a falsifiable claim.
      expect(_declaredFunctions("const String aTable = 'tom_x';"), isEmpty);
      expect(_declaredApi("const String aTable = 'tom_x';"), isEmpty);
    });
  });

  group('every guide\'s table of contents matches its sections', () {
    for (final guide in _docs('doc')) {
      test(guide, () {
        final sections = _guideSections(guide);
        final contents = _guideContents(guide);

        expect(
          contents,
          isNotNull,
          reason:
              'doc/$guide.md has no "## Table of Contents". Every other guide '
              'has one, and a reader who has learned to look for it reads its '
              'absence as a short document rather than as a missing list.',
        );

        final anchors = {for (final s in sections) _anchorOf(s): s};

        final unlisted = sections
            .where((s) => !contents!.contains(_anchorOf(s)))
            .toList();
        expect(
          unlisted,
          isEmpty,
          reason:
              'doc/$guide.md has sections its contents list omits: '
              '${unlisted.join(', ')}. Add an entry, or the section is only '
              'reachable by scrolling.',
        );

        final dangling = contents!
            .where((a) => !anchors.containsKey(a))
            .toList();
        expect(
          dangling,
          isEmpty,
          reason:
              'doc/$guide.md\'s contents list links to anchors no section '
              'defines: ${dangling.join(', ')}. A renamed heading breaks the '
              'link silently — the entry still renders, it just goes nowhere.',
        );

        expect(
          contents.where(anchors.containsKey).toList(),
          sections.map(_anchorOf).toList(),
          reason:
              'doc/$guide.md\'s contents list is not in document order. A list '
              'that does not match the order of the sections it names is worse '
              'than no list, because a reader uses it to judge distance.',
        );
      });
    }

    test('the sweep is reading the guides it claims to check', () {
      // Every finding above is an emptiness assertion, so a sweep that read no
      // guide — or read them and recovered no headings — would pass in silence.
      final guides = _docs('doc');
      expect(guides, isNotEmpty, reason: 'no guides were found under doc/');
      expect(
        guides.where((g) => _guideSections(g).isEmpty).toList(),
        isEmpty,
        reason: 'these guides yielded no "##" headings at all',
      );
    });

    test('the anchor rule reproduces the fragments the guides link to', () {
      // The rule is a reimplementation of GitHub's, so it is worth pinning on
      // the shapes these headings actually take rather than trusting it.
      expect(_anchorOf('Instants Are UTC'), 'instants-are-utc');
      expect(_anchorOf('SQL-Typed Values'), 'sql-typed-values');
      expect(_anchorOf('Framework-Owned Tables'), 'framework-owned-tables');
      expect(_anchorOf('When a Write Fails'), 'when-a-write-fails');
      expect(
        _anchorOf('Finding Placeholders in Quoted SQL'),
        'finding-placeholders-in-quoted-sql',
      );
      // Punctuation is dropped, not replaced — `TomJob`'s guide would otherwise
      // gain a hyphen where the backticks were.
      expect(_anchorOf('The `TomJob` Contract'), 'the-tomjob-contract');
    });
  });

  group('the configuration summary lists every configurable field', () {
    const module = 'configuration';
    const className = 'TomBaseServerConfiguration';
    const path = 'lib/src/tomserver/$module/base_server_configuration.dart';

    test('the census recovers both sides', () {
      // Neither side may come back empty, or the two comparisons below would
      // pass by finding nothing to disagree about.
      expect(
        _declaredFields(path, className),
        isNotEmpty,
        reason: 'no field declarations were recovered from $path',
      );
      expect(
        _summaryProperties(module, className),
        isNotEmpty,
        reason:
            'no Properties table was found under "### $className" in '
            'doc/api_reference/api_summary_configuration.md',
      );
    });

    test('every declared field has a row', () {
      final documented = _summaryProperties(module, className);
      final missing = _declaredFields(
        path,
        className,
      ).where((field) => !documented.contains(field)).toList();
      expect(
        missing,
        isEmpty,
        reason:
            'api_summary_configuration.md\'s Properties table for $className '
            'omits these fields: ${missing.join(', ')}. Every field on this '
            'class is a deployment-facing setting, and one that is absent from '
            'the table is invisible to the operator who needed to set it.',
      );
    });

    test('every row has a declared field', () {
      final declared = _declaredFields(path, className);
      final orphaned = _summaryProperties(
        'configuration',
        className,
      ).where((property) => !declared.contains(property)).toList();
      expect(
        orphaned,
        isEmpty,
        reason:
            'api_summary_configuration.md\'s Properties table for $className '
            'lists these, which the class no longer declares: '
            '${orphaned.join(', ')}. A row for a removed field is worse than a '
            'missing one, because it reads as a setting that can be supplied.',
      );
    });

    test('the rows are in source order', () {
      // The table is a mirror, so the reader can hold it beside the class. Kept
      // in source order it stays diffable against the declarations, and a field
      // inserted mid-block lands in the table where it lands in the source
      // rather than at the end.
      expect(
        _summaryProperties(module, className),
        _declaredFields(path, className),
        reason:
            'the Properties table for $className is complete but reordered; '
            'keep it in declaration order so the two can be read side by side.',
      );
    });
  });

  group('the configuration guide explains every deployment setting', () {
    const className = 'TomBaseServerConfiguration';
    const path =
        'lib/src/tomserver/configuration/base_server_configuration.dart';

    List<String> declared() =>
        _declaredFields(path, className).where(_isDeploymentSetting).toList();

    test('the census recovers both sides', () {
      // Each block is asserted separately rather than the total: the guard
      // matches block membership by name prefix, so a block renamed wholesale
      // would otherwise vanish from *both* sides at once and the comparisons
      // below would agree about nothing.
      final fields = declared();
      expect(
        fields.where((field) => field.startsWith('serviceAccount')),
        isNotEmpty,
        reason: 'no self-login settings were recovered from $path',
      );
      expect(
        fields.where((field) => field.startsWith('smtp')),
        isNotEmpty,
        reason: 'no SMTP settings were recovered from $path',
      );
      expect(
        fields.where((field) => field.startsWith('sms')),
        isNotEmpty,
        reason: 'no SMS settings were recovered from $path',
      );

      final (documented, _) = _guideDeploymentSettings();
      expect(
        documented,
        isNotEmpty,
        reason:
            'no setting rows were found under "## Deployment Settings" in '
            'doc/configuration.md',
      );
      expect(
        _secretBearingFields(path, className),
        isNotEmpty,
        reason:
            'no field on $className is marked secret-bearing in its dartdoc; '
            'the guide derives its secret markings from those, so losing the '
            'marker would silently empty the check below',
      );
    });

    test('every deployment setting has a row', () {
      final (documented, _) = _guideDeploymentSettings();
      final missing = declared()
          .where((field) => !documented.contains(field))
          .toList();
      expect(
        missing,
        isEmpty,
        reason:
            'doc/configuration.md\'s "Deployment Settings" section says '
            'nothing about: ${missing.join(', ')}. These settings are filled '
            'in by an operator reading this guide, and one the guide never '
            'names cannot be set by someone who did not already know it '
            'existed.',
      );
    });

    test('every row names a deployment setting', () {
      final declaredFields = _declaredFields(path, className);
      final (documented, _) = _guideDeploymentSettings();
      final orphaned = documented
          .where((setting) => !declaredFields.contains(setting))
          .toList();
      expect(
        orphaned,
        isEmpty,
        reason:
            'doc/configuration.md\'s "Deployment Settings" section documents '
            'these, which $className no longer declares: '
            '${orphaned.join(', ')}. A row for a removed setting reads as an '
            'instruction to supply a key that nothing will ever read.',
      );
    });

    test('the rows are in source order', () {
      final (documented, _) = _guideDeploymentSettings();
      expect(
        documented,
        declared(),
        reason:
            'the "Deployment Settings" tables are complete but reordered. The '
            'three blocks are contiguous in the class, and keeping the tables '
            'in declaration order is what lets a reviewer diff them against '
            'the source rather than sort both by hand.',
      );
    });

    test('every secret-bearing setting is marked as one', () {
      final (_, marked) = _guideDeploymentSettings();
      expect(
        marked,
        _secretBearingFields(path, className).toSet(),
        reason:
            'the settings doc/configuration.md marks **Secret-bearing** and '
            'the ones whose dartdoc says so have drifted apart. A secret left '
            'unmarked is the dangerous direction — it invites someone to '
            'author the value into a spec or a checked-in configuration tree '
            'instead of supplying it out of band — but a value marked secret '
            'that is not one is checked too, because a marker that is '
            'sometimes wrong stops being read.',
      );
    });
  });

  group('every summary files a member under the class that declares it', () {
    test('mapGroupedRow belongs to the data source, not the statement', () {
      // The specific misfiling this group was written for, pinned by name. It
      // is a static of the driver that a grouped *statement* carries the
      // projection for, so "which class is this about" and "which class is
      // this on" give different answers — and the documents answered the
      // first question while appearing to answer the second.
      expect(
        _resolveMember('MariaDbDatasource', 'mapGroupedRow'),
        isTrue,
        reason:
            'mapGroupedRow is no longer declared on MariaDbDatasource. If it '
            'moved, move its row in api_summary_datasources.md with it.',
      );
      expect(
        _resolveMember('MariadbPreparedStatement', 'mapGroupedRow'),
        isFalse,
        reason:
            'MariadbPreparedStatement now resolves mapGroupedRow, so the two '
            'documents that disagreed about its owner can no longer be told '
            'apart by this test.',
      );
    });

    test('every documented member is declared on the class it sits under', () {
      final misfiled = <String>[];
      for (final row in _attributions()) {
        if (_resolveMember(row.type, row.member) == false) {
          misfiled.add('${row.file}:${row.line} ${row.type}.${row.member}');
        }
      }
      expect(
        misfiled,
        isEmpty,
        reason:
            'These rows are filed under a class that does not declare or '
            'inherit them:\n  ${misfiled.join('\n  ')}\nA summary section is a '
            'claim of ownership, so a row under the wrong heading tells a '
            'reader to call a member on a class that has none.',
      );
    });

    test('the sweep reaches the summaries it polices', () {
      // Every assertion above passes vacuously on a census that recovered
      // nothing — an empty parse reports no misfilings at all. These floors
      // are the difference between "checked and clean" and "not checked", and
      // they are floors rather than exact counts so that adding a class or a
      // row does not fail a test about coverage.
      expect(
        _declarations.length,
        greaterThan(300),
        reason:
            'only ${_declarations.length} types were recovered from '
            'lib/src/tomserver; the parser has stopped reading the package',
      );

      final rows = _attributions();
      expect(
        rows.length,
        greaterThan(1500),
        reason:
            'only ${rows.length} member rows were recovered from '
            'doc/api_reference; the summaries are no longer being read',
      );

      final undecidable = rows
          .where((row) => _resolveMember(row.type, row.member) == null)
          .toList();
      expect(
        undecidable.length / rows.length,
        lessThan(0.02),
        reason:
            '${undecidable.length} of ${rows.length} rows cannot be decided '
            'because an ancestor is declared outside this package. '
            'Undecidable rows are not checked, so a large share of them is a '
            'hole in the guard rather than a property of the documents.',
      );

      // Named because they are the two sections the misfiling moved between,
      // and because a generic class heading carries its type parameters — the
      // shape that silently excluded twenty-one classes.
      for (final type in const [
        'MariaDbDatasource',
        'MariadbPreparedStatement',
      ]) {
        expect(
          rows.where((row) => row.type == type),
          isNotEmpty,
          reason:
              'no rows were attributed to $type, so the section holding '
              'the misfiled static is not being read at all',
        );
      }
    });

    test('the parser reads the declaration shapes that defeated it', () {
      // Each of these silently broke the census while it was being written:
      // the member came back wrong or not at all, and the effect was a class
      // whose members went unseen — which reads as "documented member not
      // declared" and would have been mistaken for a documentation bug. They
      // are pinned here so a change to the parser fails loudly instead.
      expect(
        _memberNameOf('  static (String, List<String>) toPositional(String s)'),
        'toPositional',
        reason: 'a record return type must not make `static (` read as a call',
      );
      expect(
        _memberNameOf('  final DateTime Function() clock;'),
        'clock',
        reason: 'a function-typed field is a field, not a method `Function`',
      );
      expect(
        _memberNameOf('  Future<TomLease?> acquire(String r) async {'),
        'acquire',
        reason: 'an async body must not make `async` read as the member name',
      );
      expect(
        _memberNameOf('  static ({String sentence}) referenceQuery(int a) {'),
        'referenceQuery',
        reason: 'a record return type brace is not the start of the body',
      );
      expect(
        _memberNameOf('  Set<Type> get registeredTypes {'),
        'registeredTypes',
        reason: 'a block-bodied getter declares a member',
      );
      expect(
        _memberNameOf('  static String globalSettingKey ='),
        'globalSettingKey',
        reason: 'an initialiser continued on the next line still declares one',
      );
      expect(
        _withoutTypeArguments(
          'class Prepared<T extends Object> extends TomPrepared<T> {',
        ),
        'class Prepared extends TomPrepared {',
        reason:
            'the bound in a type parameter must not be read as a supertype, '
            'which would make every lookup on the class undecidable',
      );
    });
  });

  group('every contract listing agrees with source on what is abstract', () {
    test('a transport is told which members it actually has to write', () {
      // The three that were documented as demands and are in fact gifts. The
      // two `supports…` defaults are `false` on purpose — a transport that has
      // not considered attachments cannot carry them — so a document that
      // presents them as abstract hides the safe answer behind a chore.
      final transport = _declarations['TomMessageTransport']!;
      for (final member in ['supportsCopies', 'supportsAttachments', 'close']) {
        expect(
          transport.bodilessMembers,
          isNot(contains(member)),
          reason: '$member has a default in source',
        );
      }
      // The two that genuinely are demands, pinned so the fix above cannot be
      // "mark everything concrete and move on".
      expect(transport.bodilessMembers, containsAll(['channel', 'send']));
    });

    test('no listing presents an inherited member as one to implement', () {
      // The cost of getting this backwards runs both ways. A concrete member
      // shown bare is work invented for the reader — they implement what they
      // already had, and their override silently replaces a default that was
      // load-bearing. An abstract member shown with a body is worse: it reads
      // as optional, so it is skipped, and the class does not compile.
      final offenders = <String>[];
      for (final listed in _listedMembers()) {
        final declaration = _declarations[listed.type];
        // A class invented for the document has no source to disagree with,
        // and a member the listing shows but the class inherits is not this
        // check's business. Anything else unresolvable is a rename, which the
        // reach test below reports rather than swallowing here.
        if (declaration == null) continue;
        if (!declaration.members.contains(listed.member)) continue;
        final inSource = declaration.bodilessMembers.contains(listed.member);
        if (inSource == listed.bodiless) continue;
        offenders.add(
          '${listed.file}:${listed.line} ${listed.type}.${listed.member} '
          'documented as ${listed.bodiless ? "abstract" : "concrete"}, '
          'source is ${inSource ? "abstract" : "concrete"}',
        );
      }
      expect(offenders, isEmpty);
    });

    test('the sweep reaches the listings it is meant to police', () {
      final listed = _listedMembers();
      final resolved = listed
          .where(
            (m) => _declarations[m.type]?.members.contains(m.member) ?? false,
          )
          .toList();

      // Without a floor, the check above passes just as happily on a parser
      // that stopped finding listings at all — and it has failed that way
      // before, from a wrapped header and from an escaped generic.
      expect(resolved.length, greaterThan(25));
      expect(
        resolved.map((m) => m.type).toSet(),
        containsAll([
          'TomMessageTransport',
          'TomTransactionParticipant',
          'TomTabularRenderer',
          'TomExportStore',
        ]),
      );
      // Both shapes have to be present, or the comparison is only ever making
      // one of its two possible mistakes visible.
      expect(resolved.any((m) => m.bodiless), isTrue);
      expect(resolved.any((m) => !m.bodiless), isTrue);
      // Every class named by a listing is one the package declares, save the
      // few named as illustrations. Without this the sweep's `continue` on an
      // unresolvable class is indistinguishable from silence: a listing whose
      // class was renamed would be skipped rather than reported.
      final unknown = listed
          .map((m) => m.type)
          .toSet()
          .where((type) => !_declarations.containsKey(type))
          .where((type) => !_illustrativeListings.contains(type))
          .toSet();
      expect(unknown, isEmpty);
    });

    test('the parser reads the declaration shapes a listing uses', () {
      // Bodiless: the declaration ends at a `;`, on this line or a later one.
      expect(_endsWithoutBody(['  Future<void> close();'], 0), isTrue);
      expect(
        _endsWithoutBody([
          '  Future<TomPreparedStatement<T>> prepareStatement<T extends '
              'Object>(',
          '    TomQuery query, [',
          '    Type? resultType,',
          '  ]);',
        ], 0),
        isTrue,
        reason: 'a wrapped parameter list must not read as an abstract member',
      );
      // Bodied, in each spelling a listing uses.
      expect(
        _endsWithoutBody(['  bool get supportsCopies => false;'], 0),
        isFalse,
      );
      expect(_endsWithoutBody(['  Future<void> close() async {}'], 0), isFalse);
      expect(
        _endsWithoutBody(['  String indent(int i) { … }'], 0),
        isFalse,
        reason: 'an elided body is still a body',
      );
      expect(
        _endsWithoutBody(['  final List<int> _rows = [];'], 0),
        isFalse,
        reason: 'an initialiser ends the declaration as surely as a body',
      );
      expect(
        _endsWithoutBody(['  int retriesFor({int limit = 3}) => limit;'], 0),
        isFalse,
        reason: 'a default inside a parameter list is not the declaration end',
      );
      // The members no shape comparison applies to.
      expect(
        _cannotBeAbstract('  static Tom2FAPolicy resolve();', 'Tom2FAPolicy'),
        isTrue,
      );
      expect(
        _cannotBeAbstract(
          '  TomTypedPersistenceBase(this.types);',
          'TomTypedPersistenceBase',
        ),
        isTrue,
        reason: 'a bodiless constructor still constructs',
      );
      expect(
        _cannotBeAbstract(
          '  const TomFrameworkKey.unique(this.suffix);',
          'TomFrameworkKey',
        ),
        isTrue,
        reason: 'a named constructor is a constructor',
      );
      expect(
        _cannotBeAbstract('  Future<void> close();', 'TomMessageTransport'),
        isFalse,
      );
      // A trailing comment is the annotation style contract listings use, and
      // it is the *bodiless* members that carry one — `TomMessageTransport`
      // and `TomTransactionParticipant` both gloss theirs that way. Reading
      // the comment as the member excuses exactly those members from the
      // comparison, so the stripping is pinned rather than assumed.
      expect(
        _memberNameOf('  bool get supportsCopies;        // Cc / Bcc'),
        'supportsCopies',
      );
      expect(
        _withoutLineComment("  final Uri base = Uri.parse('http://a/b');"),
        "  final Uri base = Uri.parse('http://a/b');",
        reason: 'a `//` inside a string is not a comment',
      );
    });

    test('a listing ends where the document stops describing it', () {
      // Every way a listing can end, in one document. Getting any of them
      // wrong misattributes rather than fails: the members of whatever came
      // next are compared against the class above them, so the report names a
      // class the reader never wrote and the real disagreement goes unseen.
      final members = _listedMembersOf('synthetic.md', [
        'Prose naming `abstract class TomDecoy { }` outside a fence.',
        '',
        '```dart',
        'abstract class TomContract {',
        '  Future<void> demanded();',
        '}',
        '',
        'class TomConcrete {',
        '  void notPartOfTheContract() {}',
        '}',
        '```',
        '',
        '```yaml',
        'abstract class TomNotDart {',
        '  void ignored();',
        '}',
        '```',
      ]);

      expect(members.map((m) => '${m.type}.${m.member}'), [
        'TomContract.demanded',
      ]);
      expect(members.single.line, 5);
      expect(members.single.bodiless, isTrue);
    });
  });

  group('a claim of unfinished work lives where it gets swept', () {
    test('no guide warns off finished work in the middle of a chapter', () {
      final offenders = [
        for (final (name, lines) in _guides())
          ..._unfinishedClaimsOutsideSection(name, lines),
      ];
      expect(
        offenders.map((claim) => '${claim.file}:${claim.line} ${claim.text}'),
        isEmpty,
        reason:
            'A claim that something is unfinished belongs in the one section '
            'of the document that is re-read when work completes. Buried in a '
            'chapter it is never re-read, so it survives the work it '
            'describes: `doc/datasources.md` told the reader that escaping of '
            'interpolated literals was "a tracked follow-up" long after `text` '
            'had been escaping them, which warns a consumer off a facility '
            'that works and points at a follow-up that is closed. Either say '
            'what the code now does, or move the claim into the limitations '
            'section.',
      );
    });

    test('the sweep reaches the sections it is meant to leave alone', () {
      // The check above passes just as happily on a phrase list that matches
      // nothing at all. What proves it is still looking is that the phrases do
      // fire inside the sections — where such a claim is supposed to be.
      final guides = _guides();
      final withSection = guides
          .where((guide) => guide.$2.any(_limitationsHeading.hasMatch))
          .toList();
      expect(withSection.length, greaterThan(8));

      final inside = withSection.where((guide) {
        final all = guide.$2
            .where(_unfinishedClaim.hasMatch)
            .where((line) => !_limitationsLink.hasMatch(line))
            .length;
        final outside = _unfinishedClaimsOutsideSection(
          guide.$1,
          guide.$2,
        ).length;
        return all > outside;
      });
      expect(
        inside.length,
        greaterThan(5),
        reason:
            'the phrases must match the real limitation sections, or the '
            'guard above is only asserting that nothing matches anything',
      );
    });

    test('the parser separates a claim from a signpost to one', () {
      const heading = '## Not Yet Implemented';
      final claims = _unfinishedClaimsOutsideSection('synthetic.md', [
        '# Guide',
        '',
        '- [Not Yet Implemented](#not-yet-implemented)',
        '',
        '## Chapter',
        '',
        'Retry backoff is a tracked follow-up.',
        '',
        // Wrapped across two lines, with the signpost on the second — the
        // shape eighty-column prose produces, and the one a line-by-line
        // reading reports as a violation.
        'Clustered locking is not yet implemented — see',
        '[Not Yet Implemented](#not-yet-implemented) before relying on it.',
        '',
        '```dart',
        '// not yet implemented',
        '```',
        '',
        // A second place collecting unfinished work is the arrangement the
        // check exists to prevent, so the heading counts as a claim itself.
        '### Clustering is not yet implemented',
        '',
        heading,
        '',
        'Provider revocation is not implemented.',
        '',
        '## Dependencies',
        '',
        'Nothing here is planned for later.',
      ]);

      expect(
        claims.map((claim) => claim.line),
        [7, 16, 24],
        reason:
            'the table-of-contents entry, the signposted sentence, the '
            'fenced example and the section itself are all legitimate; the '
            'unlinked chapter claim, the rival heading and the claim after '
            'the section ends are not',
      );
      expect(claims.first.text, 'Retry backoff is a tracked follow-up.');
    });

    for (final module in _modules()) {
      test(
        '$module says what it has not done',
        () {
          expect(
            _hasLimitationsSection(module),
            isTrue,
            reason:
                'The check above says a claim of unfinished work must live in '
                'the limitations section. A guide without one therefore has '
                'nowhere legal to say it, and the pressure is to leave the '
                'edge undocumented rather than to write it down: '
                '`doc/datasources.md` described a module that ships one '
                'database driver, declares a `TomDbTime` nothing produces and '
                'runs XA with no recovery, and mentioned none of it. Silence '
                'reads as "no edges", which is a stronger claim than any of '
                'these guides can make.',
          );
        },
        skip: _limitationsPendingSection.contains(module)
            ? 'no limitations section yet — quest todo tcincb126_ahxt.'
            : null,
      );
    }

    test('every quarantined guide is still missing its section', () {
      final settled = [
        for (final module in _limitationsPendingSection)
          if (_hasLimitationsSection(module)) module,
      ];
      expect(
        settled,
        isEmpty,
        reason:
            'a quarantine entry with nothing left to suppress turns a passing '
            'guide back into an unchecked one; drop it from the set',
      );
    });

    test('the heading has to be the section, not a mention of one', () {
      expect(_limitationsHeading.hasMatch('## Not Yet Implemented'), isTrue);
      expect(_limitationsHeading.hasMatch('## Status and Limitations'), isTrue);
      expect(
        _limitationsHeading.hasMatch('### Not Yet Implemented'),
        isFalse,
        reason: 'a sub-heading is inside a chapter, which is what is swept',
      );
      expect(
        _limitationsHeading.hasMatch(
          '- [Not Yet Implemented](#not-yet-'
          'implemented)',
        ),
        isFalse,
        reason: 'the table-of-contents entry points at the section',
      );
    });
  });

  group('a guide names the suite that covers what it describes', () {
    test('every suite and script a guide names exists', () {
      final missing = [
        for (final (name, lines) in _guides())
          ..._missingArtifacts(name, lines),
      ];
      expect(
        missing.map((a) => '${a.file}:${a.line} ${a.path}'),
        isEmpty,
        reason:
            'A guide that tells the reader which suite covers something has to '
            'name one that is there. This is what makes the attribution worth '
            'writing: `doc/datasources.md` used to characterise its coverage '
            'without naming a suite, so when a second suite arrived there was '
            'no name to go stale and the sentence just went on being wrong. '
            'Rename or move a suite and this fails, which is the point.',
      );
    });

    test('the sweep is looking at the references it claims to check', () {
      // Emptiness is also what a regex that matches nothing produces. The
      // guides really do name their suites — thirty-odd times — and that is
      // the fact this check stands on.
      final found = [
        for (final (_, lines) in _guides())
          for (final line in lines) ..._artifactReference.allMatches(line),
      ];
      expect(
        found.length,
        greaterThan(25),
        reason:
            'the guides attribute their coverage by filename; if this '
            'drops, the check above is asserting that nothing matches nothing',
      );
      // The two this module owns, one from each side of the db gate.
      final paths = found.map((m) => m.group(0)).toSet();
      expect(paths, contains('test/datasources_test.dart'));
      expect(paths, contains('test/datasources_db_test.dart'));
      expect(paths, contains('tool/run_db_tests.sh'));
    });

    test('a reference is resolved the three ways the guides write one', () {
      final missing = _missingArtifacts('synthetic.md', [
        'Prose naming `test/datasources_test.dart` in full.',
        '',
        // Once the sentence has said where it lives, the guides drop the
        // directory — `doc/db_migration.md` lists three suites this way.
        'and the bare `datasources_test.dart` beside it.',
        '',
        '```bash',
        'tool/run_db_tests.sh',
        '```',
        '',
        // A worked example points into a sibling package, so the path is
        // relative to that package and cannot resolve here. Naming the
        // package is what makes it legible, so naming it is the exemption.
        "**Worked example.** `advanced_ops_server`'s own",
        '`test/ops_anchor_test.dart` asserts the publisher has no job.',
        '',
        'But `test/no_such_test.dart` is nowhere, and neither is',
        '`tool/no_such_script.sh`.',
        '',
        // A fenced command is the line a reader copies, so a broken one is the
        // most expensive kind to leave lying about — and it is the only case
        // that distinguishes reading fences from skipping them.
        '```bash',
        'tool/no_such_runner.sh',
        '```',
      ]);

      expect(
        missing.map((a) => '${a.line}:${a.path}'),
        [
          '12:test/no_such_test.dart',
          '13:tool/no_such_script.sh',
          '16:tool/no_such_runner.sh',
        ],
        reason:
            'the full path, the bare basename, the working fenced command '
            'and the sample-package reference all resolve; the two invented '
            'prose paths and the invented fenced command do not',
      );
    });

    for (final module in _modules()) {
      test(
        '$module names both',
        () {
          expect(
            _unnamedVerification(module),
            isEmpty,
            reason:
                'A guide is where a reader goes to find out what backs the '
                'claims in it. Naming a suite but not the example leaves the '
                'example unowned, which is exactly how the datasources '
                'example came to spend a year with nine expectations written '
                'as `assert` — inert under the `dart run` its own header '
                'documents, so it printed a plausible transcript and exited 0 '
                'with every one of them violated. Nothing pointed at it, so '
                'nothing ran it.',
          );
        },
        skip: _verificationPendingAttribution.contains(module)
            ? 'verification artefacts not attributed yet — quest todo '
                  'tcincb125_ahxt.'
            : null,
      );
    }

    test('every quarantined module still has something to attribute', () {
      final settled = [
        for (final module in _verificationPendingAttribution)
          if (_unnamedVerification(module).isEmpty) module,
      ];
      expect(
        settled,
        isEmpty,
        reason:
            'a quarantine entry with nothing left to suppress turns a passing '
            'module back into an unchecked one; drop it from the set',
      );
    });

    test('an unnamed artefact is what the sweep reports', () {
      // Emptiness for the settled modules is only worth something if the
      // measurement can see the debt at all — so drive it over one of each.
      expect(_unnamedVerification('datasources'), isEmpty);
      expect(_unnamedVerification('transactions'), [
        'names no test suite',
        startsWith('names none of its examples'),
      ]);
      // Reference migrations are not an example a reader runs, and `audit.md`
      // names some — so it is the case that separates citing data from
      // pointing at a program.
      expect(_exampleArtifacts('audit'), ['example/audit/audit_example.dart']);
      expect(_unnamedVerification('audit'), [
        startsWith('names none of its examples'),
      ]);
    });
  });

  group('every class section names the members its class declares', () {
    for (final module in _modules()) {
      test(
        module,
        () {
          final incomplete = _incompleteSectionsOf(module);
          expect(
            incomplete,
            isEmpty,
            reason:
                'doc/api_reference/api_summary_$module.md documents these '
                'classes without naming every public member they declare: '
                '${incomplete.join('; ')}. A member list is read as complete — '
                'that is the only way to read one — so an omission does not '
                'say "look at the source", it says the member is not there. '
                'The datasources summary described `TomOperator` for a year '
                'without mentioning `children`, which is the single edge the '
                'whole operator tree is walked along.',
          );
        },
        skip: _memberListsPendingReconciliation.contains(module)
            ? 'member lists not reconciled yet — quest todos tcincb123_ahxt '
                  '(authentication) and tcincb124_ahxt (object_persistence).'
            : null,
      );
    }

    test('every quarantined module still has members to reconcile', () {
      final stale = _memberListsPendingReconciliation
          .where((module) => _incompleteSectionsOf(module).isEmpty)
          .toList();
      expect(
        stale,
        isEmpty,
        reason:
            'These modules are quarantined but their class sections are now '
            'complete: ${stale.join(', ')}. Drop the entry and let the module '
            'be checked, or the quarantine grows into a list of modules '
            'nobody checks for a reason nobody remembers.',
      );
    });

    test('the sweep is reading the sections it claims to check', () {
      // Every assertion above passes when nothing is parsed, so the parse is
      // what has to be pinned. These are the counts the package has today.
      expect(
        _classSections.length,
        greaterThan(300),
        reason:
            'the summaries document three hundred-odd classes; if this drops, '
            'the checks above are asserting that nothing is missing from '
            'nothing',
      );
      final documented = _classSections.map((s) => s.type).toSet();
      // One class from each shape the heading reader has to cope with: a
      // generic headed with escaped type parameters, an abstract base filed at
      // a different depth, and the class this guard was written for.
      expect(documented, contains('TomOperator'));
      expect(documented, contains('MariadbPreparedStatement'));
      expect(documented, contains('TomSqlDatasourceRepository'));

      final operator = _classSections.singleWhere(
        (s) => s.type == 'TomOperator',
      );
      expect(operator.file, 'api_summary_datasources.md');
      expect(operator.mentions, containsAll(['children', 'operandChildren']));
    });

    test('a section is measured the way the summaries write one', () {
      final sections = _classSectionsOf('synthetic.md', [
        '## Classes',
        '',
        '### TomOperator&lt;R&gt;',
        '',
        'A node of the operator tree.',
        '',
        '#### Constructors',
        '',
        '```dart',
        // A constructor is listed, not tabulated, and a name that appears only
        // here is documented — so the listing counts as a mention.
        'const TomOperator.column(String name)',
        '```',
        '',
        '##### Properties',
        '',
        '| Property | Type | Description |',
        '| -------- | ---- | ----------- |',
        '| `children` | `List<TomOperator>` | The operands. |',
        '',
        // A split heading holds members too; read as neither it would close
        // the class and orphan every row beneath it.
        '##### Methods — rendering',
        '',
        '| `generate` | `String` | Renders SQL. |',
        '',
        // Not a class, so it closes the section: this row belongs to nothing.
        '### Global Functions',
        '',
        '| `tomStray` | `void` | Not a member of anything. |',
      ]);

      final section = sections.single;
      expect(section.type, 'TomOperator');
      expect(
        section.rows.map((r) => '${r.line}:${r.member}'),
        ['17:children', '21:generate'],
        reason:
            'the escaped type parameters are stripped, the two member '
            'sub-headings both keep the class open, and the row under the '
            'non-class heading is attributed to nothing',
      );
      expect(section.mentions, contains('column'));
      expect(section.mentions, isNot(contains('tomStray')));
    });
  });
}
