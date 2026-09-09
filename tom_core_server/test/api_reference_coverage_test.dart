/// The guard that keeps `doc/api_reference/` a mirror of `lib/`.
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
/// The last group goes one level finer again, for every documented class. A
/// summary's `#### Properties` table makes the same completeness claim about a
/// class's properties that the Overview table makes about a module's types, and
/// it drifts the same way. [TomBaseServerConfiguration] is the case that shows
/// what is at stake: 48 fields declared against 25 listed, so the whole server
/// self-login block, the whole outbound-mail block and the whole outbound-SMS
/// block — 23 deployment-facing settings, four of them secret-bearing — were
/// absent from the page a deployer reads to find out what can be configured.
/// An undocumented method can be found in the source by the developer calling
/// it; an undocumented setting is invisible to the person who needed to set it.
///
/// Every table is censused, in both directions and in source order, which takes
/// the reading the configuration class earned and applies it to the classes
/// nobody thought to single out. "Property" is a field or a getter,
/// because that is what the tables list — a getter row is marked `*(getter)*`
/// and sits among the fields. Statics are excluded, having a table of their
/// own. There is no quarantine: every table agrees today, and the only named
/// list is of the three heading spellings the census deliberately does not
/// read, itself checked in both directions so that a spelling which stops
/// being used stops being exempt.
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
/// reader runs.
///
/// Every guide satisfies it now, and settling the last twelve produced the
/// section this check was really asking for: each guide carries a
/// `## Verification` section saying what each of its suites settles, which of
/// them are `db`-tagged and skip without a server, and the command that runs
/// its example. Writing them found seven suite names that do not exist —
/// invented by pattern from a module's other filenames — which is what the
/// neighbouring "every suite and script a guide names exists" check is for, and
/// the reason attribution is worth demanding rather than merely encouraging:
/// an attribution nothing verifies is a sentence, not a pointer.
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
/// database driver, stores a date and a time in columns that cannot carry a
/// zone and runs XA with no recovery, and mentioned none of the three. Silence
/// reads as "no edges",
/// which is a stronger claim than any guide in this package can make. So the
/// per-module half requires the section to exist, and every guide now has one.
///
/// Writing the last seven is what the requirement was for. None of those
/// modules had recorded an edge, and none of them lacked one: a transaction
/// coordinator that does not catch a throwing `commit()`, a health endpoint
/// that answers 200 for every verdict, a preference upsert that reads and then
/// writes, a scheduler whose SQL is MariaDB's rather than a dialect's, an
/// authorization cache no revocation can reach. Each was legible in the source
/// to anyone who went looking; what was missing was the place to write it down,
/// which is the whole of what this rule supplies.
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
/// A third failure sits beside those two and was learned from them. The list
/// may be written in an abbreviated form — one full path, then bare file names
/// carrying the module over — and reading only full paths made those entries
/// invisible, so the check reported the files as *undocumented* when the
/// document named every one of them. That reading kept a module quarantined on
/// a defect it did not have. [_sourceListOf] now resolves a bare name the way a
/// reader does, and the abbreviation is reported separately, as a matter of
/// form: nineteen summaries write every entry in full, and a bare name is not a
/// path anyone can follow.
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
/// Both the `Source:` check and the index check carried a quarantine while that
/// debt was worked off, and neither does now. The index's last two entries were
/// `authentication`, one name short, and `object_persistence`, which was short
/// of three whole feature areas — grouped queries and their aggregates, paging
/// and sorting, and file-reference columns — none of which the module's table
/// mentioned at all. That is the shape the set's own comment predicted: a table
/// covering two of a unit's six sources looks complete, because it lists plenty
/// of types, so the number of missing names says nothing about how much of the
/// module is undescribed.
///
/// The index carries one further check the others do not need. Its alphabetical
/// table is the half an index exists for — the reader who has the name and not
/// the module — and 493 rows answer that only while they are in order. Every
/// check around it asks whether a row *exists*, and a row in the wrong place
/// exists; the reader is the one who finds out, by looking where the name
/// should be and concluding it is not there.
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
/// The group after it asks the same "is this section's *None* true" question of
/// enums, and has to ask it differently. A free function has exactly one place
/// it can be documented; an enum has two, because eleven of the nineteen in this
/// package are written up beside the type that carries them —
/// `TomSortDirection` belongs next to the `TomSortField` whose direction it is,
/// and the summaries that do this are right to. So the forward check is that the
/// summary gives every exported enum a section *somewhere*, at whatever depth,
/// and the `## Enums` section is checked separately for **accounting**: it may
/// document an enum or say where the enum is documented, but it may not leave
/// one out. `object_persistence` said "None — this module declares no enums"
/// while exporting `TomSortDirection` and documenting it two hundred lines
/// above, under Paging & Sorting — a reader who trusted the section was steered
/// away from a page that was there all along.
///
/// The obvious repair, giving the enum a second section under `## Enums`, is the
/// wrong one and was written and reverted here: it would have documented one
/// type in two places, and the pair a reader arrives holding is the direction
/// *and its sort term*, not the direction alone. A cross-reference is what the
/// section owes. That is also why this section is read for the names it
/// **mentions** rather than the subsections it heads — and why staleness, which
/// mentions cannot answer (prose names neighbouring types too), is read from the
/// headings instead.
///
/// The group after that is the first check in this file whose subject is the
/// document as a document rather than as a set of claims about code, and it is
/// the same
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
/// weakening the attribution check as well. Every module's summary satisfies it
/// now, and the last one to do so is worth keeping in view: `authentication`'s
/// two persisted entities listed their *column* names in place of their *field*
/// names — `principal_id` where a caller writes `principalId`, `pkce_verifier`
/// where a caller writes `pkceVerifier`. A section can read as a complete
/// account of a row while naming none of the identifiers the reader came for,
/// which is the case that most needs a check reading declarations rather than
/// trusting a list to be one.
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

/// The README's `## Features` section — its per-module tour — as raw text.
///
/// Scoped to that section rather than read from the whole file, because the
/// module names are ordinary English words and the rest of the README uses
/// them as such: `resources` occurs four times outside Features, every one of
/// them "YAML resources" or the kernel's, while the module itself went
/// unmentioned. A check counting occurrences file-wide would have reported the
/// one genuinely missing module as present.
String _readmeFeatures() {
  final text = File('README.md').readAsStringSync();
  final start = text.indexOf('\n## Features\n');
  if (start < 0) throw StateError('README.md has no ## Features section.');
  final end = text.indexOf('\n## ', start + 1);
  return end < 0 ? text.substring(start) : text.substring(start, end);
}

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

/// One heading of a guide: its depth, its text, and the fragment it defines.
typedef _Heading = ({int level, String text, String anchor});

/// The `##`, `###` and `####` headings of [guide] in document order, less its
/// own contents entry.
///
/// Three levels, not one. The contents list is how a reader decides whether a
/// document answers their question without reading it, and a list that shows
/// only the top level answers that question with a fraction of what is there —
/// `authentication.md` has fifty sub-sections behind sixteen chapters. Which is
/// the same failure the top-level check exists to prevent, one level down.
///
/// The anchors are computed over **every** heading in the file, `#` to
/// `######`, because that is the sequence GitHub's disambiguation counts
/// through: a repeated heading gets `-1`, `-2`, and skipping a level would
/// shift every suffix after it.
List<_Heading> _guideHeadings(String guide) {
  final seen = <String, int>{};
  final headings = <_Heading>[];
  for (final match in RegExp(
    r'^(#{1,6}) (.+)$',
    multiLine: true,
  ).allMatches(File('doc/$guide.md').readAsStringSync())) {
    final level = match.group(1)!.length;
    final text = match.group(2)!.trim();
    final base = _anchorBase(text);
    final ordinal = seen[base] ?? 0;
    seen[base] = ordinal + 1;
    final anchor = ordinal == 0 ? base : '$base-$ordinal';
    if (level >= 2 && level <= 4 && text != 'Table of Contents') {
      headings.add((level: level, text: text, anchor: anchor));
    }
  }
  return headings;
}

/// The `##` headings of [guide], as the checks that are about chapters read
/// them.
List<String> _guideSections(String guide) => [
  for (final heading in _guideHeadings(guide))
    if (heading.level == 2) heading.text,
];

/// The anchors [guide]'s table of contents links to, in document order, with
/// the indent depth each entry is written at.
///
/// `null` when the guide has no contents list at all, which is a different
/// finding from an incomplete one and is reported separately.
///
/// Indentation is read rather than ignored because it is the only thing that
/// says which chapter a sub-entry belongs to. Two spaces per level, which is
/// what every guide already writes and what a nested list renders from.
List<({int level, String anchor})>? _guideContentsEntries(String guide) {
  final text = File('doc/$guide.md').readAsStringSync();
  if (!text.contains('## Table of Contents')) return null;
  return [
    for (final match in RegExp(
      r'^( *)- \[[^\]]+\]\(#([^)]+)\)$',
      multiLine: true,
    ).allMatches(text))
      (level: 2 + match.group(1)!.length ~/ 2, anchor: match.group(2)!),
  ];
}

/// The fragment GitHub derives from a heading, before disambiguation.
///
/// Lower-cased, spaces to hyphens, and everything dropped but word characters,
/// hyphens and spaces — so an **underscore survives**. That is not a detail:
/// `scheduling.md` heads three sub-sections with table names, and
/// `### tom_job_run` defines `#tom_job_run`. A rule that dropped the
/// underscores would have reported those three live links as dangling and
/// invited someone to "fix" them into links that go nowhere.
String _anchorBase(String heading) => heading
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9_ \-]'), '')
    .replaceAll(' ', '-');

/// The fragment a heading defines, for a guide in which it does not repeat.
///
/// [_guideHeadings] is what the checks use, because only a walk of the whole
/// file can know a heading's ordinal. This is the same rule without that
/// context, kept for the assertions that drive it over a single string.
String _anchorOf(String heading) => _anchorBase(heading);

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

/// [source] with its **block comments** emptied, newlines kept.
///
/// A `/*` opens a block comment only where one can be opened: not inside a
/// `//` or `///` line, and not inside a string literal. That is the whole of
/// what this adds over deleting `/\*[\s\S]*?\*/`, and it is not a nicety.
/// A dartdoc line reading ``/// … `--`, `#` or `/*`.`` carries a marker that
/// opens nothing in Dart and everything to a regular expression, which then
/// runs forward to the next `*/` anywhere in the file — through however many
/// declarations lie between — and deletes them all.
///
/// Both directions of the resulting damage are silent in different ways. A
/// member swallowed this way is absent from the census, so the ownership check
/// reports its perfectly correct summary row as documenting something the
/// package does not declare: a *loud* failure with a false cause, which is the
/// worst kind to debug. And the reverse checks read the same census, so the
/// same member also stops being *required* to be documented — a documentation
/// hole that reports nothing at all. The module where `/*` is most likely to
/// appear in prose is the one whose subject is SQL comments, which is exactly
/// where the omission would matter.
///
/// A string literal is honoured on the **opening** side only, and `sql_lexer`
/// is why markers reach this package's code as data at all: it holds the
/// literal `'*/'`. An opener inside a string must not start a comment. A
/// *closer* inside one does end it, quotes and all, because a block comment
/// contains no string literals — that is the language's rule, verified against
/// the analyzer, and matching it is the point.
///
/// Newlines inside a removed comment are preserved, so line numbers survive the
/// blanking. The regular expression collapsed them, which cost nothing today
/// and would silently misreport a position the day anything records one.
String _withoutBlockComments(String source) {
  final out = StringBuffer();
  var index = 0;
  while (index < source.length) {
    final char = source[index];
    final next = index + 1 < source.length ? source[index + 1] : '';

    if (char == '/' && next == '/') {
      // Copied through rather than removed: the declaration walk recognises a
      // `///` line and skips it itself, and a `//` line is harmless.
      final end = source.indexOf('\n', index);
      out.write(source.substring(index, end < 0 ? source.length : end));
      index = end < 0 ? source.length : end;
      continue;
    }

    if (char == '/' && next == '*') {
      final close = source.indexOf('*/', index + 2);
      final end = close < 0 ? source.length : close + 2;
      // An unterminated block comment runs to the end of the file, which is
      // what Dart does with one. It cannot be reached by a phantom opener any
      // more, so a file that gets here does not compile either.
      out.write('\n' * '\n'.allMatches(source.substring(index, end)).length);
      index = end;
      continue;
    }

    if (char == "'" || char == '"') {
      // `r'…'` is raw, so a backslash in it escapes nothing. Checked behind
      // rather than ahead because the quote is what was matched.
      final raw = index > 0 && source[index - 1] == 'r';
      var cursor = index + 1;
      while (cursor < source.length && source[cursor] != char) {
        // A string does not span a line unless it is raw or escaped, and an
        // unterminated one would otherwise swallow the rest of the file.
        if (source[cursor] == '\n') break;
        // A single backslash, written escaped: `r'\'` is not a legal raw
        // string, and `r'\\'` is two characters and would match nothing.
        cursor += (!raw && source[cursor] == '\\') ? 2 : 1;
      }
      final end = cursor < source.length ? cursor + 1 : source.length;
      out.write(source.substring(index, end));
      index = end;
      continue;
    }

    out.write(char);
    index++;
  }
  return out.toString();
}

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

/// The type names `doc/<module>.md`'s Overview table carries, sorted — or
/// `null` when the guide has no such table.
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
  if (!lines.any((line) => _typeTableNameColumn(line) != null)) return null;
  return _typeTableNames(lines).toList()..sort();
}

/// The index of the column a type-table heading [line] carries names in, or
/// `null` when [line] is not such a heading.
///
/// A `Kind` column identifies the table, and the names sit immediately to its
/// left; where there is none, a **leading** `Type` or `Symbol` column does.
/// Three families of document use the shape and this one rule reads all of
/// them: the guides' Overview (`| Type | Kind | Purpose |`, `| Symbol | Kind |
/// Purpose |` where the module's surface is mostly free functions, and `| Layer
/// | Type | Kind | Purpose |` in `audit`, whose Overview is organised by the
/// four layers a type can belong to), the module readmes' Key types (`| Type |
/// Responsibility |`, `| Type | What it is |`, `| Type | Implements | Backing
/// |`), and the API index (`| Type | Kind | Description |`).
///
/// Anchoring on the *first* column alone instead cost more than it looks. It
/// missed `server`, `transactions` and `audit` — they fell out of the Overview
/// check entirely, which is exactly the silence the check exists to break.
///
/// The two clauses have to stay in that order, because `Type` in a *later*
/// column is the opposite of a name column: `| Setting | Type | What it decides
/// |` and `| Column | Type | Role |` tabulate the type *of* each row's subject,
/// so accepting a second-position `Type` unconditionally reads `String`, `int`
/// and `BIGINT` as types the module fails to export. Only `Kind` licenses
/// looking past the first column.
///
/// A heading cell holding a **backticked** name disqualifies the table
/// outright, which is how the export guide's `` | Type | `naturalWidth` |
/// Because | `` stays out. Its first column holds `TomColumnType` *values*, so
/// on the column test alone its five rows reached the orphan check as five
/// missing exports. The distinction is not a special case: a heading that
/// quotes an identifier is tabulating that identifier's values, not declaring a
/// column of types.
///
/// So does a first column headed `Dependency`. Every module guide's
/// `## Dependencies` section is `| Dependency | Kind | Imported by | For |`,
/// which satisfies the `Kind` clause exactly — and its first column holds
/// package names, `dart:` libraries and links to sibling modules, none of which
/// this module exports. Read as a type table it reports `crypto`, `path` and
/// `tom_core_kernel` as names the barrel has lost.
int? _typeTableNameColumn(String line) {
  final cells = line.split('|').map((cell) => cell.trim()).toList();
  if (cells.length < 4 || cells.first.isNotEmpty || cells.last.isNotEmpty) {
    return null;
  }
  if (cells.any((cell) => cell.contains('`'))) return null;
  if (cells[1] == 'Dependency') return null;
  final kind = cells.indexOf('Kind');
  if (kind >= 2) return kind - 1;
  return cells[1] == 'Type' || cells[1] == 'Symbol' ? 1 : null;
}

/// The type names the name column of an Overview table in [markdown] carries.
///
/// Extracted from the table text rather than from a path so both callers can
/// drive it: the guide's Overview table and the module readme's Key types
/// table make the same kind of claim in the same syntax, and reading them with
/// one function is what keeps the two checks measuring the same thing.
///
/// **Every** such table in the document counts, not just the first. A readme
/// may split its types across several tables — `db_migration` uses three, one
/// per half plus the model they share — and taking only the first would read a
/// deliberately sectioned document as a truncated one.
Set<String> _typeTableNames(List<String> markdown) =>
    _typeTableRows(markdown).toSet();

/// The same names as [_typeTableNames], in document order and **keeping
/// repeats**.
///
/// Splitting a type table into groups is what makes a repeat possible: one flat
/// table shows its own duplicate on the screen, whereas a name added to the
/// engine group and then to the checks group sits pages apart and reads as two
/// different types. Collapsing to a set — which every other caller wants — is
/// exactly what hides that, so the duplicate check needs the list underneath.
List<String> _typeTableRows(List<String> markdown) {
  final names = <String>[];
  for (var i = 0; i < markdown.length; i++) {
    final column = _typeTableNameColumn(markdown[i]);
    if (column == null) continue;
    // +2 skips the heading and the `| ---- |` separator beneath it.
    for (final line in markdown.skip(i + 2)) {
      if (!line.startsWith('|')) break;
      final cells = line.split('|');
      if (cells.length <= column) break;
      names.addAll(
        RegExp(
          r'`([A-Za-z_][A-Za-z0-9_]*)(?:<[^`]*>)?`',
        ).allMatches(cells[column]).map((match) => match.group(1)!),
      );
    }
  }
  return names;
}

/// The number of Overview tables [markdown] holds.
///
/// A guide that groups its Overview has more than one, and that is the property
/// [_typeTableRows] exists to read across. Counting them is how the sweep proves
/// it is reading a grouped document rather than passing because it found one
/// table and stopped.
int _typeTableCount(List<String> markdown) =>
    markdown.where((line) => _typeTableNameColumn(line) != null).length;

/// The type names [module]'s `readme.md` Key types table carries — or `null`
/// when the module has no readme, or one with no such table.
///
/// `null` and empty are different answers and the caller treats them
/// differently: a module with no readme is a separate, louder failure than a
/// module whose readme under-describes it, and collapsing the two would let the
/// louder one be reported as the quieter.
Set<String>? _readmeTableTypes(String module) {
  final readme = File('lib/src/tomserver/$module/readme.md');
  if (!readme.existsSync()) return null;
  final names = _typeTableNames(readme.readAsLinesSync());
  return names.isEmpty ? null : names;
}

/// Every backticked identifier anywhere in [module]'s `readme.md` — or `null`
/// when there is no readme.
///
/// Deliberately the **whole document**, not the Key types table. Coverage is
/// measured against what a reader can learn the module contains, and a name met
/// in the prose or in the quick-start snippet has been learned just as well as
/// one met in a row. Measuring against the table alone would also make the
/// check unsatisfiable for a file that declares only free functions — a `|
/// Type |` table has nowhere to put `jobRunTableDdl` — and a rule that cannot
/// be complied with gets suppressed rather than met.
Set<String>? _readmeNames(String module) {
  final readme = File('lib/src/tomserver/$module/readme.md');
  if (!readme.existsSync()) return null;
  return RegExp(r'`([A-Za-z_][A-Za-z0-9_]*)')
      .allMatches(readme.readAsStringSync())
      .map((match) => match.group(1)!)
      .toSet();
}

/// The exported files of [module] whose public names its readme mentions none
/// of, sorted.
///
/// The measure is deliberately **per file, not per name**. A table headed
/// "Key types" does not claim to be exhaustive, and holding it to that would
/// make the worst-affected readmes worse — `object_persistence` exports 83
/// types, and an 83-row table in a source-directory readme is not a document
/// anyone reads. What the heading cannot excuse is a whole file with no
/// representative at all, because that is not selection, it is a capability the
/// reader has no way to learn exists.
///
/// That is the shape the failure actually took. `db_migration`'s table listed
/// types from two of its seven files, so the entire convergence half — the
/// schema model, the DDL replay, both checks and the shared lexer — was absent
/// from the page a reader meets on arriving at the directory, and the module
/// read as what it had been before five of its files existed.
///
List<String> _unrepresentedFiles(String module) {
  final mentioned = _readmeNames(module) ?? const <String>{};
  return [
    for (final export in _exportedFiles(module))
      if (!_isRepresented(
        _declaredApi(File('lib/src/tomserver/$export').readAsStringSync()),
        mentioned,
      ))
        export,
  ]..sort();
}

/// Whether a file whose public API is [declared] is represented among the names
/// a readme [mentioned].
///
/// One name is enough — see [_unrepresentedFiles] for why the measure is per
/// file rather than per name.
///
/// A file that declares nothing is vacuously represented. It has no name it
/// could contribute, so requiring one would report an omission that cannot be
/// committed. No exported file is that shape today, which is precisely why the
/// branch is spelled out and pinned by a fixture rather than left implicit: a
/// file of nothing but top-level constants — the shape `messaging`'s
/// `tomMimeLineEnding` and `tomMimeMaxLineLength` are one extraction away from —
/// declares nothing by [_declaredApi]'s definition, and the day one appears the
/// rule must not fire on it.
bool _isRepresented(Set<String> declared, Set<String> mentioned) =>
    declared.isEmpty || declared.any(mentioned.contains);

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

/// The span of [summary] its `Source:` list occupies, or `null` when it has
/// none.
///
/// The list runs from the `Source:` line (some summaries write `Sources:`) to
/// the first blank line after it, which is how all twenty write it. Taking a
/// string rather than a module lets the shapes below be checked against a
/// fixture instead of only against the package.
String? _sourceListSpan(String summary) {
  final start = RegExp(r'^Sources?:', multiLine: true).firstMatch(summary);
  if (start == null) return null;
  final rest = summary.substring(start.start);
  final blank = rest.indexOf('\n\n');
  return blank < 0 ? rest : rest.substring(0, blank);
}

/// A backticked entry in a `Source:` list: either a full package path, or the
/// bare file name that abbreviates one.
final _sourceEntry = RegExp(
  r'`(?:lib/src/tomserver/([^/`]+)/)?([^/`]+\.dart)`',
);

/// The `<module>/<file>` pairs the `Source:` list at the top of [summary]
/// names, in the order given — or `null` when it has no such list.
///
/// A bare file name resolves against the module of the last full path before
/// it, which is what "`…/authorization/authorization_cache.dart`,
/// `graded_authorization.dart`" says to a reader and is the only thing it could
/// say. Reading only full paths was a blind spot of exactly the kind this
/// file's header warns about: the four abbreviated entries in the authorization
/// summary matched nothing, so the check reported four *undocumented* files —
/// naming a defect the document did not have, and hiding the one it did, for as
/// long as the module sat quarantined on the strength of that reading. A parser
/// that cannot see an entry reports its absence as an omission.
///
/// The abbreviation is a defect of its own — no other summary writes one, and a
/// bare name is not a path a reader can follow — but it is a defect about
/// *form*, and [_abbreviatedSourceEntries] is where it is reported, in those
/// terms. A bare name before any full path resolves against nothing and is
/// dropped here; it is caught there, where the message fits.
List<String>? _sourceListOf(String summary) {
  final span = _sourceListSpan(summary);
  if (span == null) return null;
  final entries = <String>[];
  String? module;
  for (final match in _sourceEntry.allMatches(span)) {
    module = match.group(1) ?? module;
    if (module != null) entries.add('$module/${match.group(2)}');
  }
  return entries;
}

/// The entries of [summary]'s `Source:` list written as a bare file name rather
/// than as a full package path, in the order given.
///
/// Nineteen of the twenty summaries write every entry in full, and the
/// twentieth is why this exists. A bare name is a path a reader cannot follow
/// and a tool cannot resolve without inferring the module from a neighbouring
/// line — an inference [_sourceListOf] now makes, deliberately, so that the
/// completeness check reports what is missing rather than what is merely
/// abbreviated. Making the inference is what makes reporting the abbreviation
/// separately worth doing: the two failures then name two different defects
/// instead of one cause raising two alarms.
List<String> _abbreviatedSourceEntries(String summary) {
  final span = _sourceListSpan(summary);
  if (span == null) return const [];
  return [
    for (final match in _sourceEntry.allMatches(span))
      if (match.group(1) == null) match.group(2)!,
  ];
}

/// The `Source:` list of `doc/api_reference/api_summary_<module>.md`.
List<String>? _summarySourceList(String module) => _sourceListOf(
  File('doc/api_reference/api_summary_$module.md').readAsStringSync(),
);

/// Whether [index] names [api] — as a bare `` `name` `` or as a generic
/// `` `name<T>` ``, which is how the index writes the type parameters.
bool _indexNames(String index, String api) =>
    RegExp('`${RegExp.escape(api)}[<`]').hasMatch(index);

/// The index's two claims about where a type lives: the per-module tables under
/// `## Modules`, and the flat `## Alphabetical Type Index` beneath them.
typedef _IndexTables = ({Map<String, Set<String>> byModule, Set<String> alpha});

/// [_IndexTables] read out of the index's own [lines].
///
/// Sliced by heading rather than read flat, because the flat reading is
/// precisely what [_indexNames] already does and precisely what it cannot see
/// through: a type listed under the wrong module's table, or present in the
/// alphabetical table and missing from its module's, satisfies "the index names
/// it" while telling a reader the wrong thing. Only the slice distinguishes
/// *named* from *filed correctly*.
///
/// The module key is taken from the directory the heading cites — `### Endpoints
/// (`lib/src/tomserver/endpoints/`)` — so the heading's prose title is free to
/// read as "Database Migration" while the key stays `db_migration`.
///
/// A line beginning `#` always ends the current slice, whether or not it opens a
/// new one. That is what keeps the alphabetical table out of `Transactions`,
/// the module directly above it.
_IndexTables _indexTablesOf(List<String> lines) {
  final heading = RegExp(r'^###\s+.*\(`lib/src/tomserver/(\w+)/`\)\s*$');
  final byModule = <String, List<String>>{};
  final alpha = <String>[];
  List<String>? current;
  for (final line in lines) {
    if (line.startsWith('#')) {
      final module = heading.firstMatch(line)?.group(1);
      current = module != null
          ? (byModule[module] ??= <String>[])
          : line.startsWith('## Alphabetical')
          ? alpha
          : null;
      continue;
    }
    current?.add(line);
  }
  return (
    byModule: {
      for (final entry in byModule.entries)
        entry.key: _typeTableRows(entry.value).toSet(),
    },
    alpha: _typeTableRows(alpha).toSet(),
  );
}

/// [_indexTablesOf] applied to the package's own index.
final _IndexTables _indexTables = _indexTablesOf(
  File('doc/api_reference/api_summary_index.md').readAsLinesSync(),
);

/// The types each per-module summary gives a section of its own, keyed by
/// module.
///
/// The **summary**, not the source directory, is what the index is measured
/// against. The two disagree, and the summary is right where they do:
/// `TomLoginException` is declared in `little_things/server_exception.dart` and
/// documented under `### TomLoginException` in `api_summary_authentication.md`,
/// because authentication is where a reader meets it. The index files it under
/// Authentication too, so index and summary agree — and a directory-driven
/// check would report that agreement as a defect.
///
/// It also keeps the two documents to one contract. An index is a finding aid
/// for the summaries; what it owes them is that every type they give a section
/// to can be found, not that it independently re-derives the package.
final Map<String, Set<String>> _sectionedTypes = () {
  final byModule = <String, Set<String>>{};
  for (final section in _classSections) {
    final module = section.file
        .replaceFirst('api_summary_', '')
        .replaceFirst('.md', '');
    (byModule[module] ??= <String>{}).add(section.type);
  }
  return byModule;
}();

/// The types [module]'s summary sections that its row in the index's module
/// table omits, sorted.
List<String> _missingFromIndexTable(String module) => [
  for (final type in _sectionedTypes[module] ?? const <String>{})
    if (!(_indexTables.byModule[module] ?? const <String>{}).contains(type))
      type,
]..sort();

/// The names the Alphabetical Type Index lists, in the order it lists them.
///
/// Document order, not a set: what this reads is the table's *sequence*, which
/// is the one property of it a membership test cannot see. [_indexTables]
/// collapses the same rows to a set, because every other check asks whether a
/// name is there.
List<String> _indexAlphaOrder() {
  final lines = File(
    'doc/api_reference/api_summary_index.md',
  ).readAsLinesSync();
  final start = lines.indexWhere(
    (l) => l.trim() == '## Alphabetical Type Index',
  );
  if (start < 0) return const [];
  final names = <String>[];
  final row = RegExp(r'^\|\s*`([A-Za-z_][A-Za-z0-9_]*)(?:<[^`]*>)?`\s*\|');
  for (final line in lines.skip(start + 1)) {
    if (line.startsWith('#')) break;
    final match = row.firstMatch(line);
    if (match != null) names.add(match.group(1)!);
  }
  return names;
}

/// The types [module]'s summary sections that the index's alphabetical table
/// omits, sorted.
List<String> _missingFromIndexAlpha(String module) => [
  for (final type in _sectionedTypes[module] ?? const <String>{})
    if (!_indexTables.alpha.contains(type)) type,
]..sort();

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

/// The public enums [source] declares.
///
/// Anchored at column zero, so a nested `enum` — there are none today, but the
/// language allows one — is not read as module surface.
Set<String> _declaredEnums(String source) => {
  for (final declaration in RegExp(
    r'^enum\s+([A-Za-z_]\w*)',
    multiLine: true,
  ).allMatches(_withoutMultilineStrings(source)))
    if (!declaration.group(1)!.startsWith('_')) declaration.group(1)!,
};

/// The public enums the barrel exports for [module], sorted.
List<String> _exportedEnums(String module) =>
    _overExportedSources(module, _declaredEnums).toList()..sort();

/// Every heading [summary] carries, with type parameters stripped.
///
/// Depth is not read, for the reason [_classSectionsOf] gives: the audit summary
/// files its types at `###` and the datasources summary at `####`, and eleven of
/// the nineteen enums in the package are filed under `## Classes` rather than
/// under `## Enums` at all. What makes an enum *documented* is that the summary
/// gives it a section a reader can reach from the table of contents — not which
/// heading it sits beneath.
Set<String> _headingNamesOf(String summary) => {
  for (final heading in RegExp(
    r'^#{2,6}\s+(.*?)\s*$',
    multiLine: true,
  ).allMatches(summary))
    heading.group(1)!.replaceAll(RegExp(r'&lt;.*&gt;|<[^<>]*>'), '').trim(),
};

/// Every identifier [summary]'s `## Enums` section names — or `null` when the
/// summary has no such section.
///
/// *Mentions* rather than headings, because the section's job is to account for
/// the module's enums, not to be the only place they may be documented. Eleven
/// of the nineteen enums in the package are written up beside the type that
/// carries them — `TomSortDirection` belongs next to the `TomSortField` whose
/// direction it is, and moving it under a heading of its own to satisfy a check
/// would separate the pair a reader arrives holding. A section that says "one:
/// `TomSortDirection`, documented under Paging & Sorting" has answered the
/// question; a section that says "None" has answered it wrongly.
///
/// The consequence is that staleness cannot be read from this — prose names
/// neighbouring types too. [_enumSectionHeadingsOf] carries that half.
Set<String>? _enumSectionMentionsOf(String summary) {
  final section = _enumSection(summary);
  if (section == null) return null;
  return RegExp(
    r'[A-Za-z_]\w*',
  ).allMatches(section).map((match) => match.group(0)!).toSet();
}

/// The names [summary]'s `## Enums` section heads a subsection with — or `null`
/// when the summary has no such section.
///
/// Headings only, deliberately: unlike [_globalFunctionNamesOf], the tables in
/// this section do not list *types*. Every summary that writes one gives the
/// enum a heading and then a table of its **values** — `missingTable`,
/// `unexpectedTable`, and so on. Reading first cells here would take every value
/// for a type the module does not declare, and the staleness check would fail on
/// the summaries that got the section right.
///
/// `###` only, which is the level every summary gives an enum. Deeper headings
/// inside the subsection are the enum's own member sections — a `####
/// Properties` for the getter an enum declares — and reading them would take
/// `Properties` for an enum the module fails to export.
List<String>? _enumSectionHeadingsOf(String summary) {
  final section = _enumSection(summary);
  if (section == null) return null;
  return [
    for (final heading in RegExp(
      r'^###\s+(.*?)\s*$',
      multiLine: true,
    ).allMatches(section))
      heading.group(1)!.replaceAll(RegExp(r'&lt;.*&gt;|<[^<>]*>'), '').trim(),
  ]..sort();
}

/// The text under [summary]'s `## Enums` heading, or `null` when it has none.
String? _enumSection(String summary) {
  final heading = RegExp(r'^## Enums$', multiLine: true).firstMatch(summary);
  if (heading == null) return null;
  final rest = summary.substring(heading.end);
  final next = RegExp(r'^## ', multiLine: true).firstMatch(rest);
  return next == null ? rest : rest.substring(0, next.start);
}

/// The summary text of [module].
String _summary(String module) =>
    File('doc/api_reference/api_summary_$module.md').readAsStringSync();

/// Every name [summary] puts in front of a reader — its headings, and every
/// identifier inside an inline code span outside a fenced block.
///
/// Both shapes count, because the package legitimately uses both and a rule
/// naming one would condemn documentation that is already right. A class gets a
/// section: `MariadbMigrationException` is a `####` heading with no backticks
/// anywhere near it. The thirty query operators of `object_persistence` get a
/// table instead — one row each, with type, constructor and purpose — which is
/// the better presentation for thirty variations on a theme, and demanding a
/// heading apiece would be demanding that it be made worse. Typedefs are the
/// same: `TomDataScopeResolver` is a row in a typedef table.
///
/// Fenced blocks are removed first because a name that appears only inside one
/// is not documented by it: a class-hierarchy diagram shows where a type sits,
/// and a code sample shows a call that mentions it, but neither tells a reader
/// what it is for. That is a judgement about meaning, not a workaround — across
/// today's twenty summaries the stripping changes the result for none of them,
/// because the span pattern below already refuses to cross a newline and so
/// never pairs one fence delimiter with another. It is kept, and pinned by a
/// test, so that the rule survives that pattern being loosened later: a summary
/// must not be able to discharge its duty to a type by mentioning it in a
/// sample.
Set<String> _namesIn(String summary) {
  final prose = summary.replaceAll(
    RegExp(r'^```[\s\S]*?^```', multiLine: true),
    '',
  );
  return {
    ..._headingNamesOf(summary),
    for (final span in RegExp(r'`([^`\n]+)`').allMatches(prose))
      for (final word in RegExp(r'[A-Za-z_]\w*').allMatches(span.group(1)!))
        word.group(0)!,
  };
}

/// Every name [module]'s summary puts in front of a reader.
Set<String> _summaryNames(String module) => _namesIn(_summary(module));

/// The exported API of [module] that its summary never names.
List<String> _unnamedApi(String module) {
  final named = _summaryNames(module);
  return _exportedApi(module).where((name) => !named.contains(name)).toList();
}

/// The body of the type named [className] in [path], from its header to the
/// `}` that closes it, with the constructs that would otherwise be misread
/// removed.
///
/// A multi-line default — the PEM certificate pair — is data whose lines would
/// be taken for declarations, and a block comment can hold anything at all.
/// Dartdoc is deliberately *kept*: [_secretBearingFields] reads it.
///
/// The closing brace is found by the package's own layout rather than by
/// counting: a top-level declaration closes with a `}` in column zero, and
/// nothing inside one is written there. Bounding matters — a body that ran to
/// the end of the file would carry every *later* class's members as if they
/// were this one's, which is invisible in a file that declares a single class
/// and wrong in the eighty that do not.
String _classBody(String path, String className) {
  // The same two blankers the declaration census uses, in the same order and
  // through the same helpers. This held its own copy of both expressions,
  // which meant it also held its own copy of the phantom-comment bug — and a
  // body that starts or ends at the wrong line carries the wrong members,
  // which is the failure this function's own bounding exists to prevent.
  final lines = _withoutBlockComments(
    _withoutMultilineStrings(File(path).readAsStringSync()),
  ).split('\n');

  final declared = lines.indexWhere(
    (line) => _ownerDeclaration.firstMatch(line)?.group(1) == className,
  );
  if (declared < 0) return '';

  // The header, not the body, when a long type-parameter list wraps it across
  // lines. Those lines are indented exactly like members and read as them —
  // `resultType extends Object` declares a field called `Object` — so the body
  // starts at the brace that ends the header rather than at the header.
  var start = declared;
  while (start < lines.length && !lines[start].contains('{')) {
    if (lines[start].contains(';')) return '';
    start++;
  }

  final body = <String>[];
  for (final line in lines.skip(start)) {
    body.add(line);
    if (body.length > 1 && line == '}') break;
  }
  return body.join('\n');
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

/// The fields [className] declares in [path] with no dartdoc above them, in
/// source order.
///
/// Reads the same body [_secretBearingFields] does and by the same rule: a
/// dartdoc belongs to the next declaration, and a blank line detaches it. An
/// annotation does not — `@TomDbColumn('x')` between a comment and its field is
/// still that field's comment.
List<String> _undocumentedFields(String path, String className) {
  final undocumented = <String>[];
  var documented = false;
  for (final line in _classBody(path, className).split('\n')) {
    final trimmed = line.trim();
    if (trimmed.startsWith('///')) {
      documented = true;
      continue;
    }
    if (trimmed.isEmpty) {
      documented = false;
      continue;
    }
    if (trimmed.startsWith('@')) continue;
    final name = _fieldNameOf(line);
    if (name != null && !documented) undocumented.add(name);
    documented = false;
  }
  return undocumented;
}

/// Whether [field] belongs to one of the four deployment-facing blocks the
/// configuration guide documents: JWT signing keys, server self-login, outbound
/// mail, outbound SMS.
///
/// Matched by name rather than by a listed set, so a tenth `smtp*` setting is
/// covered by the guard the day it is declared.
///
/// The `jwt*` block earns its place by the same test as the other three: its
/// value is chosen by whoever deploys the server, not by whoever wrote it. It is
/// also the block where an unset setting is least visible — the server still
/// signs, on keys published in the `tom_crypto` sources — which is exactly why
/// the guide has to name each one.
bool _isDeploymentSetting(String field) =>
    field.startsWith('jwt') ||
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

/// A getter's name, read from a declaration head.
///
/// `get` is matched as a whole word so that a field called `budget` or a method
/// called `getRow` is not read as one.
final RegExp _getterName = RegExp(r'(?:^|\s)get\s+([A-Za-z_][A-Za-z0-9_]*)');

/// The public instance property [line] declares — a field or a getter — or
/// `null` when it declares none.
///
/// Three kinds are excluded, each because the summaries put them somewhere
/// else or nowhere:
///
/// * **Statics**, which the summaries carry under `#### Static Properties`.
/// * **Setters**, which pair with a getter and are described in its row; a
///   `#### Properties` table has no `*(setter)*` marker anywhere in the
///   reference, so a table that named one would be inventing a convention.
/// * **Enum values**, which the summaries carry under `#### Values`.
///
/// Methods and constructors fall out on their parameter list, exactly as in
/// [_memberNameOf], with the same `Function` exception: `final DateTime
/// Function() clock;` is a field whose *type* spells a parameter list.
String? _propertyNameOf(String rawLine) {
  if (!rawLine.startsWith('  ') || rawLine.startsWith('   ')) return null;
  final line = _withoutLineComment(rawLine).trimRight();
  if (_continuationLine.hasMatch(line)) return null;
  if (_enumValue.hasMatch(line)) return null;

  final full = line.substring(0, _declarationEnd(line));
  final modifiers = _memberModifiers.matchAsPrefix(full)?.end ?? 0;
  if (full.substring(0, modifiers).contains('static')) return null;
  final head = full.substring(modifiers);

  final getter = _getterName.firstMatch(head);
  if (getter != null) {
    final name = getter.group(1)!;
    return name.startsWith('_') ? null : name;
  }

  for (final match in _parameterList.allMatches(head)) {
    if (match.group(1) != 'Function') return null;
  }

  var remainder = head.trimRight();
  if (remainder.endsWith(';')) {
    remainder = remainder.substring(0, remainder.length - 1).trimRight();
  }
  // A declaration has a type before its name; a lone identifier is the tail of
  // something this line does not begin.
  if (!remainder.trim().contains(RegExp(r'\s'))) return null;
  final name = _trailingIdentifier.firstMatch(remainder)?.group(1);
  return name == null || name.startsWith('_') ? null : name;
}

/// The public instance properties [className] declares in [path], in source
/// order.
///
/// "Property" is what a `#### Properties` table claims to list: the values a
/// reader reaches through a `.` and does not call. Fields and getters are both
/// that, and the summaries already treat them as one list — a getter row is
/// marked `*(getter)*` and sits among the fields rather than in a table of its
/// own.
List<String> _declaredProperties(String path, String className) {
  final body = _classBody(
    path,
    className,
  ).replaceAll(RegExp(r'^\s*///.*$', multiLine: true), '');

  final properties = <String>[];
  for (final line in body.split('\n')) {
    final name = _propertyNameOf(line);
    if (name != null && !properties.contains(name)) properties.add(name);
  }
  return properties;
}

/// One `#### Properties` table in the API reference, and the type it describes.
class _PropertyTable {
  _PropertyTable(this.module, this.type, this.line, this.properties);

  /// The module whose summary carries the table.
  final String module;

  /// The type the table's enclosing section names.
  final String type;

  /// The 1-based line of the `Properties` heading, so a failure can be opened.
  final int line;

  /// The names in the table's first column, in table order.
  final List<String> properties;

  /// The key a quarantine entry is written with.
  String get id => '$module/$type';
}

/// The type a summary heading names, or `null` when it names none.
///
/// The reference escapes type arguments for HTML — `TomEndpoint&lt;requestType,
/// resultType&gt;` — and a heading is the *type's* name whether or not it
/// carries them, so both spellings are stripped before the lookup. Membership
/// of the declaration census is what decides: a heading like `Operators &
/// Expressions` groups classes rather than naming one, and the tables beneath
/// it belong to the `####` headings inside it.
String? _headingType(String title) {
  final name = title
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll(RegExp(r'<[^<>]*>'), '')
      .replaceAll('`', '')
      .trim();
  return _declarations.containsKey(name) ? name : null;
}

/// Every `#### Properties` table in `doc/api_reference`, in document order.
///
/// A table belongs to the nearest heading above it that names a type, at any
/// level: most summaries put the class at `###`, while `datasources` and
/// `object_persistence` group classes under a topic and put the class at
/// `####`. A heading that names no type and is at or above the level of the
/// one in force ends that type's section, so a table can never be attributed
/// across a topic boundary to a class that a previous topic happened to end
/// with.
List<_PropertyTable> _propertyTables() {
  final tables = <_PropertyTable>[];
  for (final module in _modules()) {
    final lines = File(
      'doc/api_reference/api_summary_$module.md',
    ).readAsLinesSync();

    String? type;
    var typeLevel = 0;
    for (var index = 0; index < lines.length; index++) {
      final heading = RegExp(r'^(#+)\s+(.*)$').firstMatch(lines[index]);
      if (heading == null) continue;
      final level = heading.group(1)!.length;
      final title = heading.group(2)!.trim();

      if (title == 'Properties') {
        if (type != null) {
          tables.add(
            _PropertyTable(module, type, index + 1, _firstColumn(lines, index)),
          );
        }
        continue;
      }

      final named = _headingType(title);
      if (named != null) {
        type = named;
        typeLevel = level;
      } else if (level <= typeLevel) {
        type = null;
      }
    }
  }
  return tables;
}

/// The backticked names in the first column of the table that follows the
/// heading on [index], in table order.
///
/// *Every* name in the cell, not the first. The summaries share a row between
/// properties that are described by one sentence — `` `remoteIdPath` /
/// `errorCodePath` / `errorMessagePath` `` is one row and three properties —
/// and reading only the leading name reports the other two as undocumented
/// when they are documented in the same breath.
List<String> _firstColumn(List<String> lines, int index) {
  final heading = lines.indexWhere((line) => line.startsWith('| '), index);
  if (heading < 0) return const [];

  final names = <String>[];
  // +2 skips the column titles and the `| -------- |` separator beneath them.
  for (final line in lines.skip(heading + 2)) {
    if (!line.startsWith('|')) break;
    names.addAll(
      RegExp(
        r'`([A-Za-z_][A-Za-z0-9_]*)`',
      ).allMatches(line.split('|')[1]).map((match) => match.group(1)!),
    );
  }
  return names;
}

/// The property headings `api_summary_<module>.md` carries: each one's level
/// and its title.
///
/// Every heading whose title starts with `Properties`, plus `Static
/// Properties`. What this is for is the *titles the census does not read* — a
/// table headed anything else than `Properties` is checked by nothing, and the
/// only way that stays deliberate is for the set of such titles to be named.
List<(int, String)> _propertiesHeadingsOf(String module) => [
  for (final line in File(
    'doc/api_reference/api_summary_$module.md',
  ).readAsLinesSync())
    if (RegExp(r'^(#+)\s+((?:Static )?Properties\b.*)$').firstMatch(line)
        case final heading?)
      (heading.group(1)!.length, heading.group(2)!.trim()),
];

/// The property-heading titles the census deliberately does not read.
///
/// `Static Properties` is a table of statics, which a class's instance
/// declarations say nothing about. The other two are mixed tables whose first
/// column holds methods as well as properties, so "every name here is a
/// property" is not what they claim.
const Set<String> _uncensusedPropertyHeadings = {
  'Static Properties',
  'Properties (DbCol)',
  'Properties and Methods',
};

/// Parsed once: every test in the property-table group reads the same census.
final List<_PropertyTable> _propertyTableCensus = _propertyTables();

/// One type declared by the package, with what it declares and what it
/// inherits from.
class _Declaration {
  _Declaration(this.name, this.path);

  final String name;

  /// The file the type is declared in.
  ///
  /// Carried on the declaration rather than derived from the module, because a
  /// module is many files and a summary section names only the type. Without
  /// it every census that has to read a class's source can only be written for
  /// a module that happens to hold one class.
  final String path;

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
  ///
  /// Flattened on purpose: every check that reads this one asks whether a name
  /// is *reachable* from the class, and all three clauses answer that the same
  /// way. [superclass] and [interfaces] are for the one question where they
  /// differ.
  final Set<String> supertypes = {};

  /// The name in the `extends` clause, or `null` when the class extends
  /// nothing.
  ///
  /// Split out from [supertypes] because a summary's `**Extends:**` /
  /// `**Implements:**` line is a claim about *which* clause, and a reader acts
  /// on the difference: an interface hands over no behaviour, so a second
  /// implementation owes every member, while a base class may already answer
  /// some of them.
  String? superclass;

  /// The names in the `implements` clause. See [superclass].
  final Set<String> interfaces = {};

  /// The parameters of each constructor, keyed by constructor name — the empty
  /// string for the unnamed one.
  ///
  /// Separate from [members] because a parameter is not a member. Most are
  /// both, since `this.x` declares a field and takes it; the ones that are only
  /// parameters — `super.stack`, a plain `Type value` consumed in the body —
  /// belong to no member list and so are invisible to every check that reads
  /// one, while still being what a caller has to write.
  final Map<String, List<_Parameter>> constructorParameters = {};

  /// The parameters of each method, keyed by member name.
  ///
  /// Kept beside [constructorParameters] rather than merged into it because the
  /// two are reached by different names: a constructor is looked up by the
  /// constructor name (empty for the unnamed one), a method by its own. Merging
  /// them would collide a factory `TomX.of` with a method `of`.
  final Map<String, List<_Parameter>> memberParameters = {};

  /// The type parameters the declaration itself introduces — `T` of
  /// `class TomConfigValue<T extends Object>`.
  ///
  /// Held so that a resolved type can be recognised as one this parser cannot
  /// finish. `TomStringConfig extends TomConfigValue<String>` inherits
  /// `withDefault(T value)`, and the type a caller writes is `String`, not `T`;
  /// substituting it needs the type-argument binding of every `extends` in the
  /// chain, which is a real element model's job. So a type that mentions one of
  /// these is reported as unresolved rather than compared, and the summary's
  /// (correct) `String` is left alone.
  final Set<String> typeParameters = {};

  /// The declared type of each field, keyed by field name.
  ///
  /// This is where a `this.x` parameter's type comes from: the constructor
  /// states the name and the field states the type, and a summary that renders
  /// the parameter has to render the field's type or it renders a signature
  /// that will not compile.
  final Map<String, String> fieldTypes = {};
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

/// The `extends` clause on its own, and the `implements` clause on its own.
///
/// `implements` stops at a following `with` or at the body: the clause pattern
/// above is deliberately indifferent to which keyword a name arrived under, and
/// `[\w\s,]+` would run straight through `with` — which is harmless when every
/// name is going into one set and wrong when they are going into two.
final RegExp _extendsClause = RegExp(r'\bextends\s+([A-Z]\w*)');
final RegExp _implementsClause = RegExp(
  r'\bimplements\s+([\w\s,]+?)(?:\s+with\b|\s*[{;]|$)',
);

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

/// The text between the parentheses of the list opening at [open] in [text].
///
/// Depth-counted rather than read to the first `)`, because a parameter can be
/// function-typed — `void Function(Object error) onFailure` closes a
/// parenthesis that is not the list's own.
String _parenthesisBody(String text, int open) {
  var depth = 0;
  for (var i = open; i < text.length; i++) {
    if (text[i] == '(') depth++;
    if (text[i] == ')' && --depth == 0) return text.substring(open + 1, i);
  }
  return '';
}

/// One parameter of a declaration, as it is written.
///
/// Every shape a parameter is written in ends with its name — `this.slot`,
/// `super.stack`, `required TomApi api`, `Map<String, Object?>? parameters`,
/// `@deprecated int retries = 3` — so the name is the trailing identifier of
/// each comma-separated chunk once the default value is cut. The name is at a
/// fixed place in every shape; the *type* is not, which is why it is optional
/// here rather than a second `String`.
///
/// [type] is what precedes the name once the modifiers are stripped, and is
/// `null` in exactly the two shapes that state no type: `this.slot` and
/// `super.stack` name a field or an inherited parameter and take its type from
/// there. [forwarding] records which of the two it was, because the two resolve
/// in different directions — `this` to this class's field, `super` to the
/// superclass's constructor.
typedef _Parameter = ({String name, String? type, String? forwarding});

/// The modifiers that may precede a parameter's type.
///
/// Distinct from [_memberModifiers] because the two vocabularies barely
/// overlap: `required` appears only here and `static` only there. Sharing one
/// pattern would either let `required` through — making the type read
/// `required StackTrace?` and mismatching every source spelling of it — or
/// admit `static` into a parameter list, where it cannot occur.
final RegExp _parameterModifiers = RegExp(
  r'^\s*(?:@\w+(?:\s*\((?:[^()]|\([^()]*\))*\))?\s*|required\s+'
  r'|covariant\s+|final\s+|const\s+)*',
);

/// One parameter read from its declaration text, or `null` when the text holds
/// no name — an empty chunk from a trailing comma.
_Parameter? _parameterOf(String declaration) {
  final name = _trailingIdentifier.firstMatch(declaration.trim())?.group(1);
  if (name == null) return null;
  var head = declaration.trim();
  head = head.substring(0, head.length - name.length);
  head = head.substring(_parameterModifiers.matchAsPrefix(head)?.end ?? 0);
  head = head.trim();
  if (head.endsWith('this.')) {
    return (name: name, type: null, forwarding: 'this');
  }
  if (head.endsWith('super.')) {
    return (name: name, type: null, forwarding: 'super');
  }
  return (name: name, type: head.isEmpty ? null : head, forwarding: null);
}

/// The parameters declared in a parameter-list body, in source order.
List<_Parameter> _parameters(String body) {
  // The `{`/`[` that open the named and optional groups wrap the parameters
  // rather than belonging to one, so they are dropped before splitting; a `[`
  // inside a `const []` default goes with them, which costs nothing because the
  // default is cut below.
  final flattened = StringBuffer();
  var depth = 0;
  for (final character in body.split('')) {
    if (character == '(' || character == '<') depth++;
    if (character == ')' || character == '>') depth--;
    if (depth == 0 && '{}[]'.contains(character)) continue;
    flattened.write(character);
  }

  final chunks = <String>[];
  final chunk = StringBuffer();
  depth = 0;
  for (final character in flattened.toString().split('')) {
    if (character == '(' || character == '<') depth++;
    if (character == ')' || character == '>') depth--;
    if (character == ',' && depth == 0) {
      chunks.add(chunk.toString());
      chunk.clear();
      continue;
    }
    chunk.write(character);
  }
  chunks.add(chunk.toString());

  final parameters = <_Parameter>[];
  for (final raw in chunks) {
    var declaration = raw;
    var nesting = 0;
    for (var i = 0; i < declaration.length; i++) {
      final character = declaration[i];
      if (character == '(' || character == '<') nesting++;
      if (character == ')' || character == '>') nesting--;
      if (nesting == 0 && character == '=') {
        declaration = declaration.substring(0, i);
        break;
      }
    }
    final parameter = _parameterOf(declaration);
    if (parameter != null) parameters.add(parameter);
  }
  return parameters;
}

/// Matches the header of a constructor of [type], named or not, wherever it can
/// appear: at two-space indentation in source, or at the start of a line in a
/// summary's fenced listing.
RegExp _constructorHeader(String type) => RegExp(
  r'(?:^|\n)[ ]*(?:const\s+|factory\s+|external\s+)*'
  '${RegExp.escape(type)}'
  r'(?:\.(\w+))?\s*\(',
);

/// Every type declared under [root], keyed by name.
///
/// The multi-line string literals and block comments go first: their contents
/// are unindented prose, and a line of it at column zero would be read as the
/// end of the enclosing class, silently truncating the member list of whatever
/// class happened to contain one.
Map<String, _Declaration> _parseDeclarations(String root) {
  final declarations = <String, _Declaration>{};
  final directory = Directory(root);
  // A missing root yields an empty census rather than an exception, so that a
  // sibling package that is not checked out fails *once*, by name, in the test
  // that asserts it is there — instead of fifteen times, as a path error
  // thrown out of a top-level initialiser and reported against whichever test
  // touched it first.
  if (!directory.existsSync()) return declarations;
  final sources = directory
      .listSync(recursive: true)
      .whereType<File>()
      .where((entry) => entry.path.endsWith('.dart'));

  for (final file in sources) {
    // The two blankers in the order they have to run: triple-quoted strings
    // first, so a `/*` inside embedded DDL is gone before block comments are
    // read, and the shared helper rather than a second copy of its two
    // expressions, so the census and the API scans cannot disagree about what
    // a string is.
    final source = _withoutBlockComments(
      _withoutMultilineStrings(file.readAsStringSync()),
    );

    _Declaration? current;
    // Recomputed whenever the enclosing class changes rather than per line: the
    // pattern is built from the class name, and building one for every line of
    // every source file is the slowest thing this walk could do.
    RegExp? constructorHeader;
    // The declaration header, while it is still open. A long type parameter
    // list is wrapped across lines and closes with a `>` at column zero, which
    // read as the end of the class body and dropped every member of the four
    // classes declared that way — `TomEndpointBase` and `TomReference` among
    // them. So the header is accumulated until its `{`, and the supertypes are
    // read from the whole of it rather than from its first line.
    final header = <String>[];

    void readTypeParameters(String text) {
      // Anchored at the class's own name: the first `<` of
      // `class Foo extends Bar<Baz>` opens the *supertype's* argument list, and
      // reading it would give Foo a type parameter called `Baz`.
      final opening = RegExp(
        '\\b${RegExp.escape(current!.name)}'
        r'\s*<',
      ).firstMatch(text);
      if (opening == null) return;
      var depth = 0;
      var end = text.length;
      for (var i = opening.end - 1; i < text.length; i++) {
        if (text[i] == '<') depth++;
        if (text[i] == '>' && --depth == 0) {
          end = i;
          break;
        }
      }
      final body = text.substring(opening.end, end);
      depth = 0;
      final chunk = StringBuffer();
      final chunks = <String>[];
      for (final character in body.split('')) {
        if (character == '<') depth++;
        if (character == '>') depth--;
        if (character == ',' && depth == 0) {
          chunks.add(chunk.toString());
          chunk.clear();
          continue;
        }
        chunk.write(character);
      }
      chunks.add(chunk.toString());
      for (final raw in chunks) {
        final name = RegExp(r'^\s*([A-Za-z_]\w*)').firstMatch(raw)?.group(1);
        if (name != null) current.typeParameters.add(name);
      }
    }

    void readSupertypes(String text) {
      readTypeParameters(text);
      final flattened = _withoutTypeArguments(text);
      final clause = _supertypeClause.firstMatch(flattened);
      if (clause == null) return;
      current!.supertypes.addAll(
        _supertypeName.allMatches(clause.group(1)!).map((m) => m.group(1)!),
      );
      current.superclass = _extendsClause.firstMatch(flattened)?.group(1);
      final implemented = _implementsClause.firstMatch(flattened);
      if (implemented != null) {
        current.interfaces.addAll(
          _supertypeName
              .allMatches(implemented.group(1)!)
              .map((m) => m.group(1)!),
        );
      }
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
        current = declarations.putIfAbsent(
          name,
          () => _Declaration(name, file.path),
        );
        constructorHeader = _constructorHeader(name);
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
        _readMemberSignature(current, member, lines, index);
      }
      final value = _enumValue.firstMatch(line);
      if (value != null) current.members.add(value.group(1)!);

      // Exactly two spaces, the same test [_memberNameOf] makes, because a
      // deeper indent is a constructor *call* inside a method body — and a call
      // matches this pattern as readily as a declaration does. Reading one
      // would replace a constructor's parameters with some call site's
      // arguments, which is worse than not reading it at all.
      //
      // A wrapped parameter list runs past this line, so the constructor is
      // read from the lines that follow it as well. Forty is the same reach
      // [_endsWithoutBody] uses and comfortably clears the longest one here.
      final constructor = line.startsWith('  ') && !line.startsWith('   ')
          ? constructorHeader!.firstMatch('\n$line')
          : null;
      if (constructor != null) {
        final text = lines.skip(index).take(40).join('\n');
        current.constructorParameters[constructor.group(1) ?? ''] = _parameters(
          _parenthesisBody(text, text.indexOf('(', constructor.end - 2)),
        );
      }
    }
  }
  return declarations;
}

/// Records what [member], declared at [index], states about its own type: the
/// parameter list when it has one, the field type when it does not.
///
/// A getter is neither. `Object? get value => _value;` reaches the field type
/// through an expression body rather than declaring one, and reading the text
/// before the name would record `Object? get` as the type of a field that does
/// not exist. So only a line whose declaration ends at a `;` or an `=` — a real
/// field — contributes a type.
void _readMemberSignature(
  _Declaration owner,
  String member,
  List<String> lines,
  int index,
) {
  final line = _withoutLineComment(lines[index]).trimRight();
  final opening = _parameterList.firstMatch(line);
  if (opening != null && opening.group(1) == member) {
    final text = lines.skip(index).take(40).join('\n');
    owner.memberParameters[member] = _parameters(
      _parenthesisBody(text, text.indexOf('(', opening.end - 1)),
    );
    return;
  }
  if (opening != null) return;
  if (RegExp(
    r'\bget\s+'
    '$member'
    r'\b',
  ).hasMatch(line))
    return;

  final head = line.substring(0, _declarationEnd(line)).trimRight();
  if (!head.endsWith(member) && !head.endsWith('$member;')) return;
  final field = _parameterOf(
    head.endsWith(';') ? head.substring(0, head.length - 1) : head,
  );
  if (field != null && field.name == member && field.type != null) {
    owner.fieldTypes[member] = field.type!;
  }
}

/// Parsed once: every test in the attribution group reads the same census, and
/// re-walking the package per test would be the slowest thing in the suite.
final Map<String, _Declaration> _declarations = _parseDeclarations(
  'lib/src/tomserver',
);

/// The kernel's declarations, read for one purpose: a parameter this package
/// forwards with `super.` is *declared* there, so its type cannot be resolved
/// without them.
///
/// Kept out of [_declarations] rather than merged in. That map answers "does
/// this package declare the type this heading names", and a kernel name in it
/// would make a summary heading of `TomException` read as a class section this
/// package owes members to.
final Map<String, _Declaration> _kernelDeclarations = _parseDeclarations(
  '../tom_core_kernel/lib/src/tombase',
);

/// [type]'s declaration, from this package or else the kernel.
_Declaration? _declarationOf(String type) =>
    _declarations[type] ?? _kernelDeclarations[type];

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

/// The member headings under which a fenced block is a constructor signature
/// rather than an example.
const Set<String> _constructorSectionHeadings = {
  'Constructors',
  'Constructor',
  'Factory Constructors',
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
  List<_MemberRow> rows,
  Set<String> mentions,
  List<_ConstructorListing> constructors,
});

/// One member row: the name in its first cell, and the second cell verbatim.
///
/// The signature is carried because a `Static Methods` table renders whole
/// declarations — `static TomPermanentDeliveryException permanent(String key,
/// …)` — and those are signatures a reader copies exactly as a `Constructors`
/// block's listings are. A row's `Type` cell holds no parameter list and simply
/// yields nothing to check.
typedef _MemberRow = ({int line, String member, String signature});

/// One constructor as a summary's `Constructors` block writes it.
///
/// Read apart from [_ClassSection.mentions] although it sits inside them,
/// because the two answer different questions. A mention says the name occurs
/// somewhere under the class; a listing is a *signature*, and a signature is
/// read as the whole of what the caller passes.
typedef _ConstructorListing = ({
  int line,
  String name,
  List<_Parameter> parameters,
});

/// The constructors of [type] that [text] — the body of one fenced block —
/// lists, with the line each starts on given a block starting at [firstLine].
List<_ConstructorListing> _constructorListingsOf(
  String type,
  String text,
  int firstLine,
) => [
  for (final match in _constructorHeader(type).allMatches(text))
    (
      line: firstLine + '\n'.allMatches(text.substring(0, match.start)).length,
      name: match.group(1) ?? '',
      parameters: _parameters(_parenthesisBody(text, match.end - 1)),
    ),
];

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
  // A fenced block is a constructor listing only under a constructor heading —
  // the same class's `Methods` section fences example calls, and reading those
  // as signatures would compare a listing against whatever a sample happened to
  // pass.
  var underConstructors = false;
  var openedAt = -1;
  final fenced = <String>[];
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].trimLeft().startsWith('```')) {
      if (openedAt < 0) {
        openedAt = i + 2;
      } else {
        if (current != null && underConstructors) {
          current.constructors.addAll(
            _constructorListingsOf(current.type, fenced.join('\n'), openedAt),
          );
        }
        openedAt = -1;
        fenced.clear();
      }
    } else if (openedAt >= 0) {
      fenced.add(lines[i]);
    }

    final title = heading.firstMatch(lines[i])?.group(1);
    if (title != null) {
      if (_isMemberSection(title)) {
        underConstructors = _constructorSectionHeadings.contains(
          title.replaceFirst(_memberSectionQualifier, ''),
        );
        continue;
      }
      final type = title.replaceAll(typeParameters, '').trim();
      underConstructors = false;
      if (!typeName.hasMatch(type) || !_declarations.containsKey(type)) {
        current = null;
        continue;
      }
      current = (
        file: file,
        type: type,
        rows: [],
        mentions: {},
        constructors: [],
      );
      sections.add(current);
      continue;
    }
    if (current == null) continue;
    final row = memberRow.firstMatch(lines[i]);
    if (row != null) {
      current.rows.add((
        line: i + 1,
        member: row.group(1)!,
        signature: _signatureCell(lines[i]) ?? '',
      ));
    }
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

/// The types each summary documents, keyed by file name.
///
/// A type is documented where it has a section of its own. A row naming it, or
/// a sentence, is a *mention* — which is what [_mentionsByType] answers and is
/// deliberately a different question: `TomFileReference` appeared for months as
/// the type of a field in another class's table while nothing described it, and
/// a referral pointed at that appearance.
final Map<String, Set<String>> _documentedByFile = () {
  final byFile = <String, Set<String>>{};
  for (final section in _classSections) {
    (byFile[section.file] ??= <String>{}).add(section.type);
  }
  return byFile;
}();

/// A link from one summary to another, as the prose writes it.
final RegExp _summaryLink = RegExp(r'\]\((api_summary_\w+\.md)\)');

/// Every framework name a summary hands to another summary without either
/// documenting it — empty when every referral resolves.
///
/// A summary is one tier's reference and says so by pointing at the others:
/// `api_summary_endpoints.md` owns the HTTP half of file transfer and refers
/// the row-side contract to Object Persistence, which refers the bytes to File
/// Storage. Each of those sentences is a promise about a document the reader
/// has to open, and nothing had ever checked one. Both of the corpus's referrals
/// were broken at once — `TomFileRepository` and `TomFileReference` were sent to
/// a summary that documented neither, and the type the published signature of
/// `TomFileSlots.register` takes had no entry anywhere.
///
/// The unit is the paragraph and the test is "documented **here or in one of
/// the summaries this paragraph links to**". Both halves are needed. A referring
/// paragraph routinely names types belonging to two different tiers — "the bytes
/// live in a `TomBlobStore` … and the row-side contract (`TomFileRepository`) is
/// Object Persistence's" is one sentence with two destinations — so demanding
/// every name be in every linked summary would report the corpus's own idiom;
/// and a paragraph may name a type it documents itself while pointing elsewhere
/// for a different one.
List<String> _danglingReferrals() => [
  for (final entry in _summaryParagraphs())
    for (final name in entry.names)
      if (!(_documentedByFile[entry.file] ?? const <String>{}).contains(name))
        if (!entry.targets.any(
          (target) =>
              (_documentedByFile[target] ?? const <String>{}).contains(name),
        ))
          '${entry.file}:${entry.line} sends `$name` to '
              '${entry.targets.join(', ')}, which document it nowhere',
];

/// One paragraph that links to another summary: where it is, what it links to,
/// and the framework names it hands over.
typedef _Referral = ({
  String file,
  int line,
  Set<String> targets,
  List<String> names,
});

/// Every referring paragraph in `doc/api_reference/`.
List<_Referral> _summaryParagraphs() => [
  for (final file in Directory(
    'doc/api_reference',
  ).listSync().whereType<File>())
    if (file.uri.pathSegments.last.startsWith('api_summary_'))
      ..._referralsIn(file.uri.pathSegments.last, file.readAsLinesSync()),
];

/// The referring paragraphs of one summary [file] whose content is [lines].
///
/// A contents list and a table are skipped: both are full of links, and neither
/// is prose making a promise about where something is described — the contents
/// list *is* the map, and a table cell naming a type beside a link is a row of
/// an inventory that its own checks already hold to the source.
List<_Referral> _referralsIn(String file, List<String> lines) {
  final referrals = <_Referral>[];
  var openedAt = -1;
  final paragraph = <String>[];
  var fenced = false;

  void close() {
    if (paragraph.isNotEmpty) {
      final text = paragraph.join(' ');
      final targets = _summaryLink
          .allMatches(text)
          .map((match) => match.group(1)!)
          .toSet();
      if (targets.isNotEmpty) {
        referrals.add((
          file: file,
          line: openedAt,
          targets: targets,
          names: [
            for (final span in _backtickedSpan.allMatches(text))
              if (_dartName.firstMatch(span.group(1)!.trim()) case final name?)
                if (name.group(1)!.split('.').first case final head
                    when _caseHump.hasMatch(head) &&
                        head.startsWith(RegExp('[A-Z]')))
                  head,
          ],
        ));
      }
    }
    paragraph.clear();
    openedAt = -1;
  }

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trimLeft().startsWith('```')) {
      fenced = !fenced;
      close();
      continue;
    }
    if (fenced) continue;
    if (line.trim().isEmpty ||
        line.startsWith('#') ||
        line.startsWith('|') ||
        line.startsWith('- [')) {
      close();
      continue;
    }
    if (paragraph.isEmpty) openedAt = i + 1;
    paragraph.add(line);
  }
  close();
  return referrals;
}

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
///
/// Exempt from being *demanded*, not forbidden. The question the rule asks is
/// about the member; for a class whose `toString` returns something a caller
/// relies on, the answer changes, because then the *value* is the API and not
/// the member. `TomTextLocale` is the one such class in the package — its tag is
/// the bundle key, so `'$locale'` in a log names the key that was looked up —
/// and `api_summary_resources.md` lists it for that reason. See the test below
/// that pins the row, which exists because this comment reads as an absolute.
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

/// The second cell of a member row, unwrapped from its backticks — `null` when
/// the row has no second cell or it is not code.
///
/// Read on its own rather than by widening the row pattern, because the cell is
/// the only part of a table whose content is a *declaration*: the first cell is
/// a name and the third is prose, and neither is anything a reader copies.
String? _signatureCell(String line) {
  final cells = line.split('|');
  if (cells.length < 3) return null;
  final cell = cells[2].trim();
  if (!cell.startsWith('`') || !cell.endsWith('`') || cell.length < 3) {
    return null;
  }
  return cell.substring(1, cell.length - 1);
}

/// The type the source declares for [parameter] of [type]'s [member], or `null`
/// when the answer cannot be established.
///
/// Three shapes, resolved in the direction each one points. A parameter that
/// states its own type answers immediately. `this.x` takes the type of this
/// class's field. `super.x` takes the type of the parameter the *superclass*
/// constructor declares under the same name, which is the whole reason the
/// kernel is parsed: `TomException` is where `stack` is finally spelled, and
/// every exception in this package reaches it through a chain of `super.stack`.
///
/// `null` where the chain leaves both packages — a supertype from `tom_basics`,
/// say — so an unresolvable parameter is skipped rather than guessed at.
String? _declaredParameterType(
  String type,
  String member,
  String parameter, {
  bool constructor = true,
  Set<String>? visited,
}) {
  final seen = visited ?? <String>{};
  if (!seen.add('$type.$member.$parameter.$constructor')) return null;

  final declaration = _declarationOf(type);
  if (declaration == null) return null;

  final declared = constructor
      ? declaration.constructorParameters[member]
      : declaration.memberParameters[member];
  if (declared == null) {
    // A method is inherited; a constructor never is.
    if (constructor) return null;
    for (final parent in declaration.supertypes) {
      final inherited = _declaredParameterType(
        parent,
        member,
        parameter,
        constructor: false,
        visited: seen,
      );
      if (inherited != null) return inherited;
    }
    return null;
  }

  /// A type is an answer only when it is written in terms the caller shares.
  String? settled(String? type) =>
      type == null ||
          _typeIdentifier
              .allMatches(type)
              .any((m) => declaration.typeParameters.contains(m.group(0)))
      ? null
      : type;

  for (final candidate in declared) {
    if (candidate.name != parameter) continue;
    if (candidate.type != null) return settled(candidate.type);
    if (candidate.forwarding == 'this') {
      return settled(declaration.fieldTypes[parameter]);
    }
    if (candidate.forwarding == 'super') {
      // Every constructor of the superclass, not just the unnamed one: a class
      // whose `super.x` forwards to a named super constructor is rarer than the
      // plain case but declares the parameter just as truly.
      for (final parent in declaration.supertypes) {
        final ancestor = _declarationOf(parent);
        if (ancestor == null) continue;
        for (final name in ancestor.constructorParameters.keys) {
          final inherited = _declaredParameterType(
            parent,
            name,
            parameter,
            visited: seen,
          );
          if (inherited != null) return inherited;
        }
      }
    }
    return null;
  }
  return null;
}

/// An identifier inside a type, which is what a type parameter appears as.
final RegExp _typeIdentifier = RegExp(r'[A-Za-z_]\w*');

/// [type] with every run of whitespace removed, so `Map<String, dynamic>?` and
/// `Map<String,dynamic>?` compare equal — the two spellings are one type, and a
/// difference in spacing is not the drift being chased.
String _normalisedType(String type) => type.replaceAll(RegExp(r'\s+'), '');

/// Every signature in [module]'s summary that gives a parameter a type the
/// source does not — empty when the summary agrees with `lib/`.
///
/// Both places a signature appears are read: the fenced listings under
/// `Constructors`, and the `Signature` cell of a member table, which is where a
/// static factory is written because it has no constructor block to live in.
///
/// Only parameters the summary *types* are checked, and only where the source
/// type resolves. A summary is free to abbreviate — it may leave a parameter
/// out, which is [_underListedConstructorsOf]'s question, not this one. What it
/// may not do is state a type that is not the declared one, because that is the
/// one part of a summary a reader copies verbatim, and a copied parameter whose
/// type is wider than the one it forwards to does not compile.
List<String> _mistypedParametersOf(String module) => _mistypedParametersIn([
  for (final section in _classSections)
    if (section.file == 'api_summary_$module.md') section,
]);

/// [_mistypedParametersOf] over an explicit list of sections, so a synthetic
/// one can be measured the same way a summary's is.
List<String> _mistypedParametersIn(List<_ClassSection> sections) => [
  for (final section in sections) ...[
    for (final listing in section.constructors)
      for (final parameter in listing.parameters)
        if (parameter.type case final documented?)
          if (_declaredParameterType(section.type, listing.name, parameter.name)
              case final declared?)
            if (_normalisedType(declared) != _normalisedType(documented))
              '${section.file}:${listing.line} ${section.type}'
                  '${listing.name.isEmpty ? '' : '.${listing.name}'} '
                  'types ${parameter.name} as $documented, '
                  'declared $declared',
    for (final row in section.rows)
      for (final parameter in _signatureParameters(row))
        if (parameter.type case final documented?)
          if (_declaredParameterType(
                section.type,
                row.member,
                parameter.name,
                constructor: false,
              )
              case final declared?)
            if (_normalisedType(declared) != _normalisedType(documented))
              '${section.file}:${row.line} ${section.type}.${row.member} '
                  'types ${parameter.name} as $documented, '
                  'declared $declared',
  ],
];

/// The parameters [row]'s signature cell declares, empty when it declares none.
///
/// The list is found by [_MemberRow.member] rather than by the first `(` in the
/// cell, because a return type can carry one — `static (String, List<String>)
/// toPositionalStatement(…)` opens a parenthesis that belongs to the record
/// type and closes before the parameters begin.
List<_Parameter> _signatureParameters(_MemberRow row) {
  final opening = RegExp(
    '\\b${RegExp.escape(row.member)}'
    r'\s*(?:<[^<>]*>)?\s*\(',
  ).firstMatch(row.signature);
  if (opening == null) return const [];
  return _parameters(_parenthesisBody(row.signature, opening.end - 1));
}

/// Every constructor listing in [module]'s summary that names fewer parameters
/// than the constructor it claims to be — empty when the summary is complete.
///
/// One-directional on purpose. A listing that names a parameter the source does
/// not have is a different fault with a different cause, and the check for it
/// would have to know that a summary may legitimately abbreviate an inherited
/// parameter list. What is asserted here is the property a caller depends on:
/// a signature they can copy is a signature that is *whole*.
List<String> _underListedConstructorsOf(String module) => [
  for (final section in _classSections)
    if (section.file == 'api_summary_$module.md')
      for (final listing in section.constructors)
        if (_declarations[section.type]?.constructorParameters[listing.name]
            case final declared?)
          if (declared
                  .map((parameter) => parameter.name)
                  .where(
                    (parameter) => !listing.parameters.any(
                      (listed) => listed.name == parameter,
                    ),
                  )
                  .toList()
              case final missing when missing.isNotEmpty)
            '${section.file}:${listing.line} ${section.type}'
                '${listing.name.isEmpty ? '' : '.${listing.name}'} '
                'omits ${missing.join(', ')}',
];

/// `type: a, b, c` for every class documented in [module]'s summary that has
/// undocumented members — empty when the summary is complete.
List<String> _incompleteSectionsOf(String module) => [
  for (final section in _classSections)
    if (section.file == 'api_summary_$module.md')
      if (_undocumentedMembers(section.type) case final missing
          when missing.isNotEmpty)
        '${section.type}: ${missing.join(', ')}',
];

/// One `**Extends:**` / `**Implements:**` line as a summary presents it.
///
/// [denies] is the `none` form, which is a claim too — that the class extends
/// nothing — and is checked as one.
typedef _RelationshipClaim = ({
  String file,
  int line,
  String type,
  bool extending,
  bool denies,
  Set<String> named,
});

/// Every relationship line in `doc/api_reference/`, attributed to its class.
List<_RelationshipClaim> _relationshipClaims() => Directory('doc/api_reference')
    .listSync()
    .whereType<File>()
    .where((entry) => entry.path.endsWith('.md'))
    .expand(
      (file) => _relationshipClaimsOf(
        file.uri.pathSegments.last,
        file.readAsLinesSync(),
      ),
    )
    .toList();

/// The relationship lines of one summary, reported under [file].
///
/// Split from [_relationshipClaims] for the same reason [_listedMembersOf] is:
/// getting the attribution wrong files a claim under the wrong class, which
/// reads as a passing check rather than as an error.
List<_RelationshipClaim> _relationshipClaimsOf(
  String file,
  List<String> lines,
) {
  // Both backtick styles, and both generic spellings: a summary writes
  // `TomEndpointBase&lt;requestType, resultType&gt;` in a heading, and an
  // anchored pattern that does not expect the escape silently attributes every
  // one of that class's lines to nothing at all.
  final heading = RegExp(r'^#{3,4}\s+`?([A-Za-z_]\w*)');
  final claim = RegExp(r'^- \*\*(Extends|Implements):\*\*\s*(.+)$');
  // Backticks on one of these lines are not all supertypes. A line may cite the
  // module a type comes from or the summary that documents it — `**Implements:**
  // `TomResourceScopeSource` (this package's `object_persistence` module …)` —
  // so the names are filtered to those *shaped* like a type. Taking every
  // backticked token would demand that the class implement its own
  // documentation file.
  final quoted = RegExp(r'`([A-Z]\w*(?:&lt;[^`]*&gt;|<[^`]*>)?)`');

  final found = <_RelationshipClaim>[];
  String? current;
  for (var index = 0; index < lines.length; index++) {
    final title = heading.firstMatch(lines[index])?.group(1);
    if (title != null) {
      current = _declarations.containsKey(title) ? title : null;
      continue;
    }
    final match = claim.firstMatch(lines[index]);
    final type = current;
    if (match == null || type == null) continue;
    final text = match.group(2)!;
    found.add((
      file: file,
      line: index + 1,
      type: type,
      extending: match.group(1) == 'Extends',
      // Read before the quoted names, not after: `none (abstract). Annotated
      // `@tomReflector`.` carries a backticked token that names no supertype,
      // and taking it for one would demand a class the package never declares.
      denies: text.startsWith('none'),
      named: {
        for (final name in quoted.allMatches(text))
          name.group(1)!.split(RegExp('<|&lt;')).first.trim(),
      },
    ));
  }
  return found;
}

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
/// it, and nothing should. `doc/endpoints.md` shows `TickerService` the same
/// way, for the WebSocket example. Naming the exemption rather than skipping
/// every unresolvable class keeps the reach check able to say what it is for: a
/// listing whose class has quietly been renamed still fails, because the
/// rename produces a name that is not on this list.
///
/// An entry here exempts a class from *resolution*, not from being correct.
/// Each is checked by other means, which is the standard an illustration has to
/// meet before it earns a place on this list: the socket example is compiled as
/// `FixtureApiService.ticker`, and `GreetingService` — the guide's first worked
/// example — is compiled as the fixture pair
/// `GreetingService` / `GreetingServer`, mounted, served, and asserted verbatim
/// against the document, all in `endpoints_pipeline_test.dart`.
const Set<String> _illustrativeListings = {
  'AdminApi',
  'GreetingService',
  'TickerService',
};

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

/// The body of `doc/[module].md`'s limitations section — the lines between its
/// heading and the next `##`, empty when the guide has none.
List<({int line, String text})> _limitationsBodyOf(String module) {
  final lines = File('doc/$module.md').readAsLinesSync();
  final start = lines.indexWhere(_limitationsHeading.hasMatch);
  if (start < 0) return const [];
  var end = lines.length;
  for (var i = start + 1; i < lines.length; i++) {
    if (lines[i].startsWith('## ')) {
      end = i;
      break;
    }
  }
  return [for (var i = start + 1; i < end; i++) (line: i + 1, text: lines[i])];
}

/// A backticked span, and the shape of the one that is a Dart name rather than
/// some other literal token.
///
/// Backticks in these guides mark *any* literal: a JWT claim (`exp`, `iat`), a
/// SQL keyword (`DATE`, `LIMIT`), a locale tag (`de_AT`), a settings key, a
/// table name, an HTTP header (`Range`), a shell fragment. Sixteen per cent of
/// the identifier-shaped spans in these sections are one of those, so "a
/// backticked identifier must exist in the package" is not a rule about code —
/// it is a rule about vocabulary, and the only way to write it would be a list
/// of exempt words that grows whenever a guide names a new protocol.
///
/// What *is* a rule about code is the case hump. `TomFileSlots`,
/// `MariadbMigrationAdaptor`, `coercePrimitiveParameter`,
/// `globalSettingMaxFilePartBytes` all carry a lowercase-then-uppercase
/// transition, which is Dart's naming convention and no other vocabulary's
/// here: a SQL keyword is upper, a claim and a locale tag are lower or snake,
/// a single English word is neither. So the hump selects the names this
/// package could have declared and nothing else — 173 of the 365 spans, with
/// no exempt list at all.
final RegExp _backtickedSpan = RegExp(r'`([^`]+)`');
final RegExp _dartName = RegExp(
  r'^@?([A-Za-z_$][A-Za-z0-9_$]*(?:\.[A-Za-z_$][A-Za-z0-9_$]*)*)(?:\(\))?$',
);
final RegExp _caseHump = RegExp(r'[a-z0-9][A-Z]');

/// Every identifier that occurs in the package's own source, this one and the
/// kernel it is written against.
///
/// Comments are stripped and string literals are not, which is the level the
/// question needs. A renamed class disappears from the code entirely, so the
/// bar catches it; a name that lives only inside a literal —
/// `delegateTo` is a settings key, `errorType` an envelope field — is a real
/// name of this package all the same, and dropping literals would report both
/// as missing. Prose is excluded because a dartdoc sentence mentions everything
/// and would make the census answer "yes" to anything.
final Set<String> _packageVocabulary = {
  for (final root in const ['lib', '../tom_core_kernel/lib'])
    if (Directory(root).existsSync())
      for (final file in Directory(root).listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          ..._identifier
              .allMatches(
                _withoutBlockComments(
                  _withoutLineComments(file.readAsStringSync()),
                ),
              )
              .map((match) => match.group(0)!),
};

final RegExp _identifier = RegExp(r'[A-Za-z_$][A-Za-z0-9_$]*');

/// [source] with every `//` comment removed, line by line.
String _withoutLineComments(String source) =>
    source.split('\n').map(_withoutLineComment).join('\n');

/// The names [module]'s limitations section writes as code that the package
/// does not have — empty when every one of them resolves.
///
/// This is the half of "is the bullet still true" that a program can decide. A
/// limitation that was quietly fixed while its symbol survived still reads as
/// live and is not caught here; a limitation whose symbol was renamed or
/// deleted is, and renaming is what actually happens to a section nobody
/// re-reads.
List<String> _unresolvedNamesOf(String module) => [
  for (final (:line, :text) in _limitationsBodyOf(module))
    for (final report in _unresolvedNamesIn(text))
      'doc/$module.md:$line $report',
];

/// [_unresolvedNamesOf] over one line, so a synthetic bullet can be measured
/// the same way a guide's is.
List<String> _unresolvedNamesIn(String text) => [
  for (final span in _backtickedSpan.allMatches(text))
    if (_dartName.firstMatch(span.group(1)!.trim()) case final name?)
      if (name.group(1)!.split('.') case final parts
          when parts.any(_caseHump.hasMatch))
        for (final part in parts)
          if (!_packageVocabulary.contains(part))
            '`${span.group(1)}` — no $part in lib/',
];

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

/// Every surface whose prose cites a suite, a script or a test group.
///
/// The guides were the first, and for a long time the only one — but a pointer
/// rots wherever it is written, and the package writes them in five places. The
/// module readmes and the api summaries carry them, the suite headers carry
/// them by design (a header that says "not tested here" owes the reader the
/// place it is), and an example's dartdoc names the suite that proves it runs.
///
/// A `.dart` file contributes only its comment lines. Its code is full of paths
/// and quoted strings that are neither, and reading them would report a fixture
/// argument as a broken citation.
///
/// [_selfExcludedSuite] is left out, and it is the only exclusion: this file's
/// own fixtures spell deliberately-absent paths — `test/no_such_test.dart` is
/// what proves the check reports one — so it cannot be its own subject.
List<(String, List<String>)> _citingSurfaces() => [
  ..._guides().map((guide) => ('doc/${guide.$1}', guide.$2)),
  for (final directory in const ['doc/api_reference', 'lib', 'test', 'example'])
    for (final entry in Directory(directory).listSync(recursive: true))
      if (entry is File &&
          entry.path != _selfExcludedSuite &&
          !entry.path.endsWith('.reflection.dart'))
        if (entry.path.endsWith('.md'))
          (entry.path, entry.readAsLinesSync())
        else if (entry.path.endsWith('.dart'))
          (entry.path, _commentLinesOf(entry.readAsLinesSync())),
]..sort((a, b) => a.$1.compareTo(b.$1));

/// [lines] with every non-comment line blanked, so line numbers still line up.
List<String> _commentLinesOf(List<String> lines) => [
  for (final line in lines)
    if (line.trimLeft().startsWith('//')) line else '',
];

/// The sibling packages a citation may be relative to, as directory paths.
///
/// A pointer written `test/ops_anchor_test.dart` in a paragraph that also says
/// `advanced_ops_server` is a path relative to *that* package, and naming the
/// package is what makes it unambiguous. Resolving it there rather than
/// excusing it is the difference this check turns on: an excused reference is
/// one nothing reads, which is the state every rotted pointer was already in.
Map<String, String> _siblingPackages() => {
  for (final entry in Directory('..').listSync())
    if (entry is Directory) entry.path.split('/').last: entry.path,
  for (final entry in Directory('../tom_core_samples').listSync())
    if (entry is Directory) entry.path.split('/').last: entry.path,
};

/// A test suite or tool script a guide names, and where it names it.
typedef _NamedArtifact = ({String file, int line, String path});

/// A path to a suite, a shared test source or a script, as a guide writes one.
///
/// Matched anywhere on the line rather than only inside backticks, because the
/// reference that matters most is the runnable one — `tool/run_db_tests.sh` in
/// a fenced block is the line a reader will actually copy.
///
/// Any `.dart` file under a `test/` directory counts, not only a `_test.dart`.
/// A suite is not the only thing a document points at:
/// `test/contracts/scheduling_contract.dart` is the shared contract three
/// stores are held to and two documents name it, and it went unread for as long
/// as the pattern asked for a suite's spelling.
final RegExp _artifactReference = RegExp(
  r'[\w./-]*test/[\w./-]+\.dart\b|[\w./-]+(?:_test\.dart|\.sh)\b',
);

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
    for (final i in paragraph) {
      for (final match in _artifactReference.allMatches(lines[i])) {
        final path = match.group(0)!;
        // No exemption for naming a sibling package. Naming one used to *excuse*
        // the reference; it now *resolves* it, which is the difference between
        // a pointer nothing reads and one that fails when the suite moves.
        if (_resolveArtifact(path, context) != null) continue;
        missing.add((file: file, line: i + 1, path: path));
      }
    }
  }
  return missing;
}

/// [path] as a file, resolved the four ways a citation is legitimately written.
///
/// As written; as a bare basename the prose uses once the sentence has said
/// where it lives; anywhere under this package, which is how
/// `run_cluster_demo.sh` resolves from a paragraph that calls it by name; and
/// under whichever sibling package [context] names, which is how
/// `test/ops_anchor_test.dart` resolves against `advanced_ops_server` and
/// `test/contracts/scheduling_contract.dart` against `tom_core_kernel`.
///
/// The last is the one worth having. Both of those were previously *excused* —
/// the paragraph named a package, so the reference was waved through without
/// being read — and an excused pointer is exactly as unchecked as an unwritten
/// rule. Resolving it makes the sentence load-bearing: move the suite inside
/// that package and this fails.
File? _resolveArtifact(String path, String context) {
  final basename = path.split('/').last;
  for (final candidate in [File(path), File('test/$basename')]) {
    if (candidate.existsSync()) return candidate;
  }
  for (final root in const ['lib', 'test', 'example', 'tool', 'doc']) {
    // The package's own tree, and only the parts of it this package authors.
    // A recursive walk of `.` reaches `.dart_tool`, which holds copies of
    // whatever the resolver pulled in — and a citation resolving against a
    // dependency's copy of a file is a check that passes on anything.
    final directory = Directory(root);
    if (!directory.existsSync()) continue;
    for (final entry in directory.listSync(recursive: true)) {
      if (entry is File && entry.path.endsWith('/$basename')) return entry;
    }
  }
  final siblings = _siblingPackages();
  for (final name in siblings.keys) {
    // The package is named either in the sentence around the path or as the
    // path's own first segment. Both spellings occur, and the qualified one is
    // the better of the two — it needs no sentence to disambiguate it — so the
    // prefix is stripped rather than the reference being read as a sub-path of
    // the sibling.
    final qualified = path.startsWith('$name/');
    if (!qualified && !context.contains(name)) continue;
    for (final candidate in [
      if (qualified)
        File('${siblings[name]}/${path.substring(name.length + 1)}'),
      File('${siblings[name]}/$path'),
      File('${siblings[name]}/test/$basename'),
    ]) {
      if (candidate.existsSync()) return candidate;
    }
  }
  return null;
}

/// A test group a document or a header cites, written the one way that can be
/// read mechanically.
///
/// `group named `X`` and nothing else. The looser spellings the corpus reached
/// for cannot be told from ordinary prose: `groups `X` exposes` names three
/// *getters* in `api_summary_audit.md`, `their `title` group value` is a SQL
/// `GROUP BY` column, and ``object_persistence` group classes under a topic`
/// uses the word as a verb. Measured over every surface, the loose forms
/// produced twenty citations of which seven were none.
///
/// So the citation gets a spelling of its own, and the corpus was made to
/// conform. That is the cheaper half of the trade: a convention costs one word
/// per citation, an allowlist of exempt phrases costs a maintainer forever and
/// is the quarantine this repository refuses elsewhere.
final RegExp _groupCitation = RegExp(
  r'groups? named\s+((?:`[^`]+`(?:,\s*|\s+and\s+)?)+)',
);

/// The backticked names inside a [_groupCitation] match.
final RegExp _citedName = RegExp(r'`([^`]+)`');

/// Every `group('…')` declared in [file], for the literal case.
///
/// A group whose name is composed at runtime is invisible here, and that is a
/// stated limit rather than an oversight: a citation cannot name such a group
/// either, so a pointer that resolves to one was never writable.
Set<String> _declaredGroups(File file) {
  final source = file.readAsStringSync();
  return {
    for (final match in RegExp(
      r"""group\(\s*'((?:[^'\\]|\\.)*)'""",
    ).allMatches(source))
      match.group(1)!.replaceAll(r"\'", "'"),
    for (final match in RegExp(r'group\(\s*"([^"]*)"').allMatches(source))
      match.group(1)!,
  };
}

/// The group citations in [file] that name no group in the suite they point at.
///
/// The suite is the one named in the same paragraph — the citation idiom is
/// "asserted in `X_test.dart`, by the group named `G`" — and when a paragraph
/// names none, every suite this package and its siblings declare is searched,
/// because a citation that says only which group still says something checkable.
///
/// Groups are cited by name rather than by line number because a line number
/// rots silently while the file around it is edited: the pointer that started
/// this had drifted some seven hundred lines. A name only rots when somebody
/// renames the group, which is when this fails and puts them in front of the
/// prose.
List<_NamedArtifact> _missingGroups(String file, List<String> lines) {
  final missing = <_NamedArtifact>[];
  for (final paragraph in _paragraphsOf(lines, includeFenced: true)) {
    final context = paragraph
        .map((i) => lines[i].replaceFirst(RegExp(r'^\s*///?\s?'), ''))
        .join(' ');
    if (!_groupCitation.hasMatch(context)) continue;

    final suites = <File>{
      for (final match in _artifactReference.allMatches(context))
        if (match.group(0)!.endsWith('_test.dart'))
          if (_resolveArtifact(match.group(0)!, context) case final suite?)
            suite,
    };
    final declared = <String>{
      for (final suite in suites.isEmpty ? _everySuite() : suites)
        ..._declaredGroups(suite),
    };

    for (final citation in _groupCitation.allMatches(context)) {
      for (final name in _citedName.allMatches(citation.group(1)!)) {
        if (declared.contains(name.group(1))) continue;
        missing.add((
          file: file,
          line: paragraph.first + 1,
          path: '`${name.group(1)}`',
        ));
      }
    }
  }
  return missing;
}

/// Every suite in this package and in the siblings a citation may point at.
///
/// Read once: the fallback searches all of them, and re-reading several hundred
/// files per paragraph would be the slowest thing in this suite.
final List<File> _everySuiteCache = [
  for (final root in [
    Directory('test'),
    ...(_siblingPackages().values.map(Directory.new)),
  ])
    if (root.existsSync())
      for (final entry in root.listSync(recursive: true))
        if (entry is File &&
            entry.path.endsWith('_test.dart') &&
            !entry.path.endsWith('.reflection.dart'))
          entry,
];

List<File> _everySuite() => _everySuiteCache;

/// How a guide says a check needs a provisioned server.
///
/// Three spellings because all three are in use — `db`-tagged, tagged `db`, and
/// the `db` tag — and normalising the prose to one of them would be tidying the
/// symptom. What matters is catching the claim wherever it is made.
final RegExp _serverTagClaim = RegExp(
  r'`db`[- ]tagged|tagged `db`|the `db` tag',
);

/// The suite [path] names as a file in this package, or null if it is not one.
///
/// Null covers both halves of "not ours": a `.sh` script, and a path belonging
/// to a sibling sample package. Neither is evidence about this package's tags,
/// so neither should be read as an absent one.
File? _resolveSuite(String path) {
  if (!path.endsWith('_test.dart')) return null;
  // `test/x_test.dart` as written, or the bare `x_test.dart` the prose uses
  // once the surrounding sentence has already said where it lives.
  for (final candidate in [File(path), File('test/${path.split('/').last}')]) {
    if (candidate.existsSync()) return candidate;
  }
  return null;
}

/// Paragraphs of [guide] that claim a `db` tag while naming only suites that
/// do not carry one.
///
/// The split between a connection-free suite and its `_db_test.dart` sibling is
/// this package's convention, not an accident: it is why `testkit :test` runs
/// green on a machine with no MariaDB. Prose that folds the pair back into one
/// file — `framework_schema_test.dart` and "its `db`-tagged half" — costs a
/// reader who wants to run the provisioned check the worst kind of time. They
/// open the named file, look for a tag to enable, find none, and conclude the
/// check is unimplemented. It is; it is under a filename they were told not to
/// expect.
///
/// Checked per paragraph rather than per sentence because the claim and the
/// filename routinely sit in different sentences, and a paragraph is the unit a
/// reader takes the attribution from.
List<String> _untaggedTagClaims(String guide, List<String> lines) {
  final found = <String>[];
  for (final paragraph in _paragraphsOf(lines, includeFenced: false)) {
    final text = paragraph.map((i) => lines[i]).join(' ');
    if (!_serverTagClaim.hasMatch(text)) continue;
    final named = <String>[];
    var tagged = false;
    for (final match in _artifactReference.allMatches(text)) {
      final suite = _resolveSuite(match.group(0)!);
      if (suite == null) continue;
      named.add(match.group(0)!);
      if (suite.readAsStringSync().contains("@Tags(['db'])")) tagged = true;
    }
    // A paragraph naming nothing makes its claim about whatever the sentence
    // before it named — a back-reference this cannot resolve, and
    // `doc/scheduling.md` has one. Only an attribution that names something can
    // be held against it.
    if (named.isEmpty || tagged) continue;
    found.add('$guide:${paragraph.first + 1} ${named.join(', ')}');
  }
  return found;
}

/// The number words a heading is allowed to count in.
///
/// A closed set rather than a parser, for the same reason the suite-count guard
/// uses one: the check should fail loudly on "a handful" instead of quietly
/// reading it as zero.
const _countWords = {
  'two': 2,
  'three': 3,
  'four': 4,
  'five': 5,
  'six': 6,
  'seven': 7,
  'eight': 8,
  'nine': 9,
  'ten': 10,
  'eleven': 11,
  'twelve': 12,
};

/// The counts [heading] states, ignoring number words that name rather than
/// count.
///
/// A hyphen on either side means the word is part of a compound — the
/// *two-node* cluster demonstration, *Two-Factor* Authentication — which
/// describes a thing instead of counting the rows under it.
Set<int> _statedCounts(String heading) => {
  for (final entry in _countWords.entries)
    if (RegExp(
      '(?<![A-Za-z-])${entry.key}(?![A-Za-z-])',
      caseSensitive: false,
    ).hasMatch(heading))
      entry.value,
};

/// Headings in [document] that state a count and sit directly on a table whose
/// row count disagrees.
///
/// Only a table *immediately* beneath the heading is checked, and that
/// restriction is the rule rather than a simplification of it. A heading with
/// nothing between it and a table is a caption for that table, and a caption
/// that contradicts what it captions is read as a fact about it —
/// `## The three programs` sitting on five rows told a reader there were three
/// things here, and the row most easily skipped as a result was the one warning
/// that a stale reflection root fails the demo at its first query.
///
/// Prose in between changes the claim: `doc/export.md` heads "The Two Delivery
/// Channels" over a three-row table whose third row is `*(neither)*`, and
/// `doc/resources.md` heads "Two Ways to Read a Principal's Locale" over a
/// comparison matrix counting two *columns*. Both are correct, and both are
/// separated from their heading by a paragraph that says so.
List<String> _miscountedTableHeadings(String document, List<String> lines) {
  final found = <String>[];
  var fenced = false;
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].trimLeft().startsWith('```')) {
      fenced = !fenced;
      continue;
    }
    if (fenced) continue;
    final heading = RegExp(r'^#{1,6} (.*)$').firstMatch(lines[i]);
    if (heading == null) continue;
    final claimed = _statedCounts(heading.group(1)!);
    if (claimed.isEmpty) continue;
    var start = i + 1;
    while (start < lines.length && lines[start].trim().isEmpty) {
      start++;
    }
    if (start >= lines.length || !lines[start].startsWith('|')) continue;
    // The header row and its `| --- |` separator are not data.
    var rows = 0;
    for (var k = start + 2; k < lines.length && lines[k].startsWith('|'); k++) {
      rows++;
    }
    if (claimed.contains(rows)) continue;
    found.add('$document:${i + 1} states ${claimed.join('/')} over $rows rows');
  }
  return found;
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
///
/// The suite half is *every* name-matched suite, not merely one, because naming
/// one is the easy half and the misleading half. `doc/db_migration.md` named
/// three suites and none of them was its own: it cited the framework-table and
/// reference-migration suites while discussing convergence, and the reader who
/// checked whether the module was covered found three filenames and stopped
/// looking — with the two suites that actually exercise the orchestrator, and
/// the one that exercises the whole reading half, unmentioned. A guide that
/// names *a* suite reads exactly like a guide that names them all.
List<String> _unnamedVerification(String module) =>
    _unnamedVerificationIn(module, File('doc/$module.md').readAsStringSync());

/// [_unnamedVerification] over [text] rather than over the guide on disk.
///
/// Separated so the shapes this measurement distinguishes can be pinned against
/// a fixture rather than against whichever module happens to exhibit each one.
/// Pinning them to live modules makes a meta-test that fails on the day the
/// debt is paid off, and a guard that has to be rewritten every time the
/// package improves is one that gets weakened rather than understood. The
/// shapes are properties of the rule; the package is only where they were
/// first met.
List<String> _unnamedVerificationIn(String module, String text) {
  final examples = _exampleArtifacts(module);
  final unnamed = _moduleSuites(module).where((s) => !text.contains(s));
  return [
    if (_moduleSuites(module).isEmpty && !_suiteReference.hasMatch(text))
      'names no test suite',
    if (unnamed.isNotEmpty) 'does not name ${unnamed.join(', ')}',
    if (examples.isNotEmpty && !examples.any(text.contains))
      'names none of its examples (${examples.join(', ')})',
  ];
}

/// The suites whose filename identifies them as [module]'s, as basenames.
///
/// A **lower bound on the module's coverage, not the whole of it**, and
/// deliberately so. `test/schema_convergence_test.dart` exercises nothing but
/// `db_migration` and is not named after it, so no filename rule will find it;
/// inferring ownership from a suite's imports would, but it would also claim
/// every suite that touches a module in passing, and a guard that demands a
/// guide name thirty incidental suites gets switched off. The name is the one
/// signal that is unambiguous in the direction that matters: a file called
/// `db_migration_db_test.dart` is *certainly* this module's, so a guide that
/// does not name it has certainly left something out.
List<String> _moduleSuites(String module) =>
    Directory('test')
        .listSync()
        .whereType<File>()
        .map((entry) => entry.uri.pathSegments.last)
        .where((name) => name.startsWith(module) && name.endsWith('_test.dart'))
        .toList()
      ..sort();

/// The modules for which no `<module>*_test.dart` exists.
///
/// `preferences` is covered, and covered well, by six `user_preferences*`
/// suites named after the types rather than the directory. Whether that is a
/// naming fault to fix or an inventory rule to widen is a judgement, so the
/// entry sits here until it is made rather than being settled by whichever
/// answer was cheaper to write.
const Set<String> _suiteNamingPending = {'preferences'};

/// The modules whose `lib/src/tomserver/<module>/readme.md` still leaves at
/// least one exported file unmentioned.
/// A `Type  (module)` line in a summary's class-hierarchy diagram — a pointer
/// telling a reader which module to open for a type the diagram shows but does
/// not document.
typedef _ModulePointer = ({String file, int line, String type, String module});

/// Every hierarchy line whose parenthetical names a module of this package.
///
/// The parenthetical is overloaded, and deliberately so: it carries the kind
/// (`(abstract)`, `(enum)`, `(mixin)`), the relationship (`(implements)`), the
/// owning package for a foreign type (`(kernel)`), and — the case swept here —
/// the module that documents a type borrowed from elsewhere in this package.
/// They are told apart by the only test that cannot drift: whether the word
/// names a directory under `lib/src/tomserver`. That anchors the rule to the
/// code rather than to a list of kind-words someone has to remember to extend,
/// so a new module is policed the day it is created and a new kind-word needs
/// no change here at all.
///
/// A trailing `module` is stripped because `(server module)` and `(server)` are
/// the same claim written two ways, and the diagrams use both.
List<_ModulePointer> _modulePointers() {
  final modules = _modules().toSet();
  final pointers = <_ModulePointer>[];
  for (final file
      in Directory('doc/api_reference').listSync().whereType<File>()
      // The index carries no hierarchy diagrams; every other summary may.
      .where(
        (entry) => entry.uri.pathSegments.last.startsWith('api_summary_'),
      )) {
    final name = file.uri.pathSegments.last;
    final lines = file.readAsLinesSync();
    var fenced = false;
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      if (line.trimLeft().startsWith('```')) {
        fenced = !fenced;
        continue;
      }
      // Only inside a fence: the same shape in prose is an ordinary sentence.
      if (!fenced) continue;
      // The leading run allows the continuation bars a deep branch carries: a
      // third-level entry is indented past a `│` before its own `└──` begins.
      // Without them the sweep skips the most nested lines, which are the ones
      // a reader is least able to place unaided.
      final match = RegExp(
        r'^[\s│]*(?:[├└]──\s*)?([A-Z]\w*)\s\s+\(([^)]+)\)\s*$',
      ).firstMatch(line);
      if (match == null) continue;
      final module = match
          .group(2)!
          .trim()
          .replaceFirst(RegExp(r'\s+module$'), '');
      if (!modules.contains(module)) continue;
      pointers.add((
        file: name,
        line: index + 1,
        type: match.group(1)!,
        module: module,
      ));
    }
  }
  return pointers;
}

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

  group('the README\'s Status block states what it can hold true', () {
    // The block carries exactly one precise number, and that is the whole
    // point of these two tests. A version a reader acts on — it says which
    // release the document describes — so a wrong one misleads rather than
    // merely disappointing, and it costs one file read to hold true. A test
    // count costs a suite run to check and informs nobody: the choice between
    // this package and another is not made on the size of its suite. So the
    // block states the version and describes the suite, and the pair below
    // pins each half.
    //
    // `../tool/check_readme_status.py` applies the same rule across every
    // package under `tom_ai/core`. This suite is what runs when *this* package
    // changes, which is when its own README rots.

    test('the stated version is the one pubspec.yaml declares', () {
      final status = _sectionBody('README.md', 'Status').join('\n');
      final stated = RegExp(
        r'\*\*Version:\*\*\s*(\S+)',
      ).firstMatch(status)?.group(1);
      final declared = RegExp(
        r'^version:\s*(\S+)',
        multiLine: true,
      ).firstMatch(File('pubspec.yaml').readAsStringSync())?.group(1);

      expect(
        stated,
        isNotNull,
        reason:
            'The README\'s Status block states no version. It is the one '
            'number the block keeps, because it tells a reader which release '
            'the document describes.',
      );
      expect(
        stated,
        declared,
        reason:
            'README.md says version $stated; pubspec.yaml says $declared. A '
            'version is the claim in this block a reader acts on, so a wrong '
            'one misleads rather than merely disappointing.',
      );
    });

    test('the block states no test count', () {
      final counts = RegExp(r'\b[0-9][0-9,]+\s+(?:test cases|tests?|suites?)\b')
          .allMatches(_sectionBody('README.md', 'Status').join('\n'))
          .map((match) => match.group(0)!)
          .toList();

      expect(
        counts,
        isEmpty,
        reason:
            'The README\'s Status block states a test count '
            '(${counts.join(', ')}). Nothing connects that number to the '
            'suite, so every added test is a README edit nobody makes and the '
            'count drifts. Describe how the suite is run and what gates part '
            'of it — the `db` tag is operational and cannot go stale — and '
            'give no number.',
      );
    });
  });

  group('the README\'s feature tour names every module', () {
    test('no module is missing from the Features section', () {
      final features = _readmeFeatures();
      final unnamed = _modules()
          .where((module) => !features.contains('`$module`'))
          .toList();

      expect(
        unnamed,
        isEmpty,
        reason:
            'The README\'s Features section never names these modules: '
            '${unnamed.join(', ')}. Every section heading there lists the '
            'modules it covers, and the platform-services table gives one row '
            'per module, so the tour reads as an enumeration — a reader '
            'counting modules gets the wrong number rather than a hint that '
            'something is missing. Add the module to the appropriate heading '
            'and give it a row.',
      );
    });

    test('the tour names nothing that is not a module', () {
      // The other direction, for the same reason the summary checks run both
      // ways: a row for a module that was renamed or removed is worse than a
      // missing one, because a reader cannot tell a stale row from a current
      // one and will go looking for source that is not there.
      final modules = _modules();
      final named = RegExp(r'^\| `([a-z_]+)` \|', multiLine: true)
          .allMatches(_readmeFeatures())
          .map((match) => match.group(1)!)
          .where((name) => !modules.contains(name))
          .toList();

      expect(named, isEmpty, reason: 'Not modules: ${named.join(', ')}.');
    });
  });

  group('each guide\'s Overview table lists the module\'s exported API', () {
    for (final module in _modules()) {
      final table = _overviewTableTypes(module);
      if (table == null) continue;

      test(module, () {
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

        // The two sides are deliberately asymmetric. What the table *must*
        // carry is [_exportedApi]; what it *may* carry is [_exportedNames],
        // which adds the top-level constants. A guide that gives a row to
        // `defaultBlobManifestTable` is documenting the default a caller
        // overrides, not claiming a type — required rows would drag every
        // module's constants in behind it, and forbidding the row would
        // delete documentation the check has no business deleting.
        final nameable = _exportedNames(module);
        final orphaned = table.where((t) => !nameable.contains(t)).toList();
        expect(
          orphaned,
          isEmpty,
          reason:
              'doc/$module.md\'s Overview table names these, which the '
              'barrel does not export from $module: ${orphaned.join(', ')}. '
              'Either it was renamed or removed, or it belongs to another '
              'module\'s table.',
        );
      });
    }

    // The loop above can only check a guide that *has* an Overview table, so
    // the `continue` that skips one is the whole check's blind spot: a guide
    // whose table is deleted, or a new module whose guide never grows one,
    // leaves no failure behind — it leaves no test behind. This is what the
    // quarantine list used to hold open, and it outlives the quarantine,
    // because the escape it covers was never really "not reconciled yet" but
    // "not looked at at all".
    test('every module\'s guide has an Overview table', () {
      final tableless = _modules()
          .where((module) => _overviewTableTypes(module) == null)
          .toList();
      expect(
        tableless,
        isEmpty,
        reason:
            'These guides have no Overview table, so the check above generated '
            'no test for them: ${tableless.join(', ')}. An Overview table is '
            'recognised by its `Kind` column; give the guide one rather than '
            'letting the module fall out of the sweep in silence.',
      );
    });

    // The completeness check above unions every row before comparing, so a name
    // listed twice satisfies it exactly as well as a name listed once. That is
    // tolerable while an Overview is one table and a reader can see the repeat;
    // it stops being tolerable once the table is split into groups, because the
    // whole claim a grouped table makes is that each type belongs *somewhere* —
    // and a type in two groups says the opposite while looking tidy in both.
    test('no Overview table lists a name twice', () {
      final offenders = <String>[];
      for (final module in _modules()) {
        final rows = _typeTableRows(File('doc/$module.md').readAsLinesSync());
        final seen = <String>{};
        final repeated = rows.where((name) => !seen.add(name)).toSet();
        if (repeated.isNotEmpty) {
          offenders.add('$module (${(repeated.toList()..sort()).join(', ')})');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'These guides give a name more than one Overview row: '
            '${offenders.join('; ')}. Two rows for one type are two answers to '
            'the question the table exists to answer, and the reader has no way '
            'to tell which is current.',
      );
    });

    test('the sweep reads every table a grouped Overview splits into', () {
      // Anti-vacuity, and it needs a real document rather than a fixture: the
      // multi-table reading is only load-bearing while some guide actually
      // groups its Overview, and flattening one back would leave every check
      // above passing on a document that had quietly lost the structure.
      final lines = File('doc/db_migration.md').readAsLinesSync();
      expect(
        _typeTableCount(lines),
        greaterThan(1),
        reason:
            'db_migration.md is the guide whose Overview is split by half. If '
            'that is deliberately no longer true, move this assertion to '
            'whichever guide groups instead — do not simply delete it, or '
            'nothing exercises the multi-table reading against a real document.',
      );
      // The union really does span the groups: a name from the last table is
      // reached, which reading only the first would miss.
      expect(_overviewTableTypes('db_migration'), contains('TomSqlLexer'));
      expect(_overviewTableTypes('db_migration'), contains('TomDbMigrations'));
    });

    test(
      'the extractor reads every Type table in a document, not the first',
      () {
        // A readme that sections its types by concern is the shape this has to
        // survive; reading only the first table would score it as a truncated
        // document and send its author to delete the sections.
        final found = _typeTableNames(
          '''
| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomFirst` | class | in the opening table. |

## Another concern

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomSecond` | class | in a later table. |
| `TomThird` | class | and its neighbour. |
'''
              .split('\n'),
        );

        expect(found, {'TomFirst', 'TomSecond', 'TomThird'});
      },
    );

    test('a heading that quotes an identifier is not a type table', () {
      // The export guide's width table is the live example: `integer`,
      // `decimal`, `text`, `boolean` and `timestamp` are `TomColumnType`
      // *values*, and on the column test alone they arrived at the orphan
      // check as five types the module fails to export.
      final markdown =
          '''
| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomTabularColumn` | class | the module's own surface. |

## How wide a column is

| Type | `naturalWidth` | Because |
| ---- | -------------- | ------- |
| `integer` | 11 | a value of a type, not a type. |
'''
              .split('\n');

      expect(_typeTableNames(markdown), {'TomTabularColumn'});
      expect(_typeTableCount(markdown), 1);
    });

    test('a later Type column is the row\'s type, not the row\'s name', () {
      // `configuration` and `scheduling` are the live examples: a settings
      // table and a DDL column table both put `Type` second, and reading it as
      // the name column scores `String`, `int`, `BIGINT` and `LONGTEXT` as
      // types the module fails to export. Only a `Kind` column licenses looking
      // past the first — which is what makes `audit`'s `| Layer | Type | Kind |
      // Purpose |` readable without letting these two in behind it.
      final markdown =
          '''
| Layer | Type | Kind | Purpose |
| ----- | ---- | ---- | ------- |
| Sink | `TomAuditSink` | abstract class | where entries go. |

| Setting | Type | What it decides |
| ------- | ---- | --------------- |
| `authServerLoginUri` | `String?` | not a type of this module's. |

| Column | Type | Role |
| ------ | ---- | ---- |
| `seq` | `BIGINT AUTO_INCREMENT` | also not. |
'''
              .split('\n');

      expect(_typeTableNames(markdown), {'TomAuditSink'});
      expect(_typeTableCount(markdown), 1);
    });

    test('a companion table naming another module\'s types is not read', () {
      // Four guides name a sibling module's type because the reader's route
      // runs through it — `scheduling` cites `classifySqlFailure`,
      // `file_storage` the whole file stack above the blob contract. Those rows
      // are documentation the check has no business deleting, and they are also
      // not a claim about *this* module's exports, so they sit in a `| Name |
      // Module | Purpose |` table the extractor does not read.
      final markdown =
          '''
| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomOwn` | class | this module's surface. |

| Name | Module | Purpose |
| ---- | ------ | ------- |
| `TomElsewhere` | `datasources` | on the reader's route, but not ours. |
'''
              .split('\n');

      expect(_typeTableNames(markdown), {'TomOwn'});
      expect(_typeTableCount(markdown), 1);
    });

    test('the row reader keeps a repeat the name reader collapses', () {
      // No guide repeats a name today, so the duplicate check above has no live
      // example and would pass just as happily if the reader underneath it
      // silently de-duplicated. Only a fixture can hold the two readers apart:
      // the set is what every completeness check wants, the list is the one
      // thing that can still see the repeat.
      final markdown =
          '''
| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomFirst` | class | in the opening group. |

### A second group

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomFirst` | class | and again, pages away. |
'''
              .split('\n');

      expect(_typeTableRows(markdown), ['TomFirst', 'TomFirst']);
      expect(_typeTableNames(markdown), {'TomFirst'});
      expect(_typeTableCount(markdown), 2);
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

  // The same completeness question as the group above, asked of the other
  // document that answers it — and asked of the reader who is furthest from
  // `doc/`. A guide is something you go to; `lib/src/tomserver/<module>/
  // readme.md` is what a developer already inside the source tree meets, so it
  // is the first and often only description of the module they read.
  //
  // The question has to be asked differently here, because the claim is
  // different. An Overview table is headed `## Overview` and is checked
  // name-by-name; a readme's is headed **Key types**, which does not promise
  // exhaustiveness and should not be made to. `object_persistence` exports 83
  // types, and the honest response to that is a selection, not an 83-row table
  // nobody reads.
  //
  // What a selection may not do is leave a whole *file* unmentioned. That is
  // not choosing the important types, it is a capability with no entry point:
  // a reader cannot select against something they have not been told exists.
  // `db_migration` is the case that prompted this — its table drew from two of
  // seven files, so the module's entire convergence half was invisible, and the
  // readme described the module as it had been before five of its files
  // existed. Both halves are load-bearing and only one was on the page.
  //
  // So coverage is measured over the whole readme rather than over the table:
  // a name introduced in the prose or the quick-start has been introduced. That
  // is not a loophole but the only satisfiable form of the rule — `scheduling`
  // exports a file of nothing but free functions, and a `| Type |` table has
  // nowhere to put `jobRunTableDdl`, which is now introduced in its Schema
  // section beside the descriptor the DDL is rendered from.
  //
  // Four modules had no readme at all — `audit`, `export`, `file_storage` and
  // `resources` — which is the failure this check exists for and the one it
  // could least see: every other check here reads a table, and there was no
  // table to read. Writing them was the larger half of settling this, and what
  // it found is what the rule predicts. A module's unreached files are not
  // scattered: they cluster on whichever half of the module arrived after the
  // readme was written, so `endpoints` was missing all four of its transports
  // and `object_persistence` its column authorization, its file references and
  // the whole of grouping.
  group('each module readme reaches every exported file', () {
    for (final module in _modules()) {
      test(module, () {
        expect(
          _readmeTableTypes(module),
          isNotNull,
          reason:
              'lib/src/tomserver/$module/readme.md is missing, or has no '
              '`| Type |` table. The directory readme is what a developer '
              'already in the source tree reads first, and a module that '
              'answers that reader with nothing is documented only to '
              'whoever already knows to look in doc/.',
        );

        final unrepresented = _unrepresentedFiles(module);
        expect(
          unrepresented,
          isEmpty,
          reason:
              'lib/src/tomserver/$module/readme.md mentions no public name '
              'from these exported files: ${unrepresented.join(', ')}. A '
              '"Key types" table may select, but a file mentioned nowhere at '
              'all is not a selection — it is a capability the reader has no '
              'way to learn exists, so they conclude the module is what the '
              'readme shows.',
        );
      });
    }

    // Every module has a readme and every readme reaches every file its module
    // exports, so there is no quarantine. The two it carried were separate
    // because the fixes were different in kind — extending a table is an edit,
    // writing a missing readme is authoring a document — and the second set was
    // the worse half: an incomplete table under-describes a module, while a
    // missing readme is invisible to every check that reads a table, there
    // being no table to read.

    test('a file declaring nothing public is represented vacuously', () {
      // The three cases of the rule, pinned directly rather than through a
      // module: one mentioned name represents a file, no mentioned name does
      // not, and a file that declares nothing is excused. The last case has no
      // instance in the package today, so only a fixture can hold it — and
      // without one, deleting the excuse changes no result and the decision is
      // untested.
      expect(_isRepresented({'TomA'}, {'TomA', 'TomB'}), isTrue);
      expect(_isRepresented({'TomA'}, {'TomB'}), isFalse);
      expect(_isRepresented({'TomA'}, const {}), isFalse);
      expect(_isRepresented(const {}, const {}), isTrue);
    });
  });

  // A guide's contents list is how a reader finds out what the document covers
  // without reading it, so a section missing from it is a section most readers
  // never learn exists — the same failure as an unlisted type, one level up.
  // Nothing kept the two in step, and adding a section is exactly when the
  // omission happens, because the section is the part being thought about.
  group('each summary\'s Source list names every file it covers', () {
    for (final module in _modules()) {
      test(module, () {
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
      });
    }

    // Every module passes the check above, so it carries no quarantine — but
    // the last module to leave one did not leave because its documentation
    // improved. `authorization` named all five of its files and was reported as
    // naming one, because it wrote four of them as bare names and the parser
    // read only full paths. The quarantine held a documentation defect open for
    // as long as it took to notice that the defect was in the reading.
    //
    // So the form is now checked in its own right, and separately from
    // completeness: the parser resolves a bare name against the module of the
    // preceding full path, which is what a reader does, and the test below
    // reports the abbreviation as what it is.
    test('every Source list entry is a path, not a bare file name', () {
      final abbreviated = <String>[];
      for (final module in _modules()) {
        final entries = _abbreviatedSourceEntries(
          File('doc/api_reference/api_summary_$module.md').readAsStringSync(),
        );
        for (final entry in entries) {
          abbreviated.add('$module: $entry');
        }
      }
      expect(
        abbreviated,
        isEmpty,
        reason:
            'These Source list entries are written as bare file names: '
            '${abbreviated.join(', ')}. Nineteen of the twenty summaries write '
            'every entry as a full `lib/src/tomserver/<module>/<file>` path, '
            'which is a path the reader can follow and a tool can resolve '
            'without inferring the module from the line above it.',
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

      // The abbreviated shape, read the way its writer meant it: the module
      // carries over from the last full path. Pinned against a fixture rather
      // than against the package, because the package no longer contains one —
      // and a rule with no instance left to exercise it is a rule that quietly
      // stops holding.
      expect(
        _sourceListOf(
          'Sources: `lib/src/tomserver/authorization/authorization_cache.dart`,\n'
          '`graded_authorization.dart`.\n'
          '\n',
        ),
        [
          'authorization/authorization_cache.dart',
          'authorization/graded_authorization.dart',
        ],
      );
      expect(
        _abbreviatedSourceEntries(
          'Sources: `lib/src/tomserver/authorization/authorization_cache.dart`,\n'
          '`graded_authorization.dart`.\n'
          '\n',
        ),
        ['graded_authorization.dart'],
      );
      expect(
        _abbreviatedSourceEntries(
          'Source: `lib/src/tomserver/cache/server_cache.dart`.\n\n',
        ),
        isEmpty,
      );

      // A bare name with no full path before it resolves against nothing, so
      // it is dropped from the list and reported as an abbreviation instead.
      // Reporting it as a *missing file* is the failure this whole pair exists
      // to prevent, and it cannot be, because there is no module to name it
      // under.
      expect(_sourceListOf('Source: `orphan.dart`.\n\n'), isEmpty);
      expect(_abbreviatedSourceEntries('Source: `orphan.dart`.\n\n'), [
        'orphan.dart',
      ]);
    });
  });

  group('the index names every exported name', () {
    final index = File(
      'doc/api_reference/api_summary_index.md',
    ).readAsStringSync();

    for (final module in _modules()) {
      test(module, () {
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
      });
    }

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

  group('the index files every documented type under its own module', () {
    for (final module in _modules()) {
      test(module, () {
        final fromTable = _missingFromIndexTable(module);
        expect(
          fromTable,
          isEmpty,
          reason:
              'api_summary_$module.md gives each of these a section of its '
              'own, but the index\'s $module table has no row for them: '
              '${fromTable.join(', ')}. The check above only asks whether the '
              'index names them somewhere, so a type filed under the wrong '
              'module — or reachable only through the alphabetical table — '
              'passes it while still telling a reader the wrong thing.',
        );

        final fromAlpha = _missingFromIndexAlpha(module);
        expect(
          fromAlpha,
          isEmpty,
          reason:
              'The Alphabetical Type Index has no row for these, which '
              'api_summary_$module.md documents: ${fromAlpha.join(', ')}. '
              'That table is the one a reader uses who knows the name and '
              'not the module, which is the only case in which an index is '
              'the document they need.',
        );
      });
    }

    // The alphabetical table is the one an index is *for* — the reader who has
    // the name and not the module — and a table of 493 rows answers that only
    // while it is in order. Nothing else notices when it stops being: every
    // check around this one asks whether a row exists, and a row in the wrong
    // place exists. The reader is the one who finds out, by looking where the
    // name should be, not finding it, and concluding it is not there.
    test('the alphabetical table is in alphabetical order', () {
      final rows = _indexAlphaOrder();
      final sorted = [...rows]
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      final firstOutOfPlace = [
        for (var i = 0; i < rows.length; i++)
          if (rows[i] != sorted[i]) '${rows[i]} (expected ${sorted[i]})',
      ];
      expect(
        firstOutOfPlace.take(5),
        isEmpty,
        reason:
            'The Alphabetical Type Index is out of order at: '
            '${firstOutOfPlace.take(5).join(', ')}. Case is ignored, which is '
            'what puts `auditDiff` between `And` and `Between` — the order a '
            'reader scans in, not the order a byte comparison produces.',
      );
    });

    test('the tables are sliced per module, not read flat', () {
      // Every finding above is an emptiness assertion over a parse, so a
      // slicer that returned one merged bucket — or none — would pass in
      // silence while checking nothing.
      expect(_indexTables.byModule, hasLength(_modules().length));
      expect(_indexTables.byModule['endpoints'], contains('TomRedirect'));
      expect(_indexTables.byModule['endpoints'], contains('TomFileEndpoint'));
      // The property that flat reading cannot have: a name belonging to
      // another module is absent here, however prominent it is in the index.
      expect(
        _indexTables.byModule['endpoints'],
        isNot(contains('TomDataSource')),
      );
      // The alphabetical table is its own slice, and reaches free functions —
      // it is not a `| Type |` table of classes only.
      expect(_indexTables.alpha, contains('tomConsumesForm'));
      expect(_indexTables.alpha, contains('TomDataSource'));

      // A fixture, so the slicing is pinned by something that fails when the
      // heading shapes change rather than only by the package's own index.
      final fixture = _indexTablesOf([
        '## Modules',
        '',
        '### Alpha Module (`lib/src/tomserver/alpha/`)',
        '',
        '| Type | Kind | Description |',
        '| ---- | ---- | ----------- |',
        '| `TomAlpha` | class | One. |',
        '',
        '### Beta Module (`lib/src/tomserver/beta/`)',
        '',
        '| Type | Kind | Description |',
        '| ---- | ---- | ----------- |',
        '| `TomBeta` / `TomBetaToo` | class | Two in one cell. |',
        '',
        '## Alphabetical Type Index',
        '',
        '| Type | Module |',
        '| ---- | ------ |',
        '| `TomAlpha` | Alpha |',
        '| `TomBeta` | Beta |',
      ]);
      expect(fixture.byModule.keys, ['alpha', 'beta']);
      expect(fixture.byModule['alpha'], {'TomAlpha'});
      // Both names of a shared cell count — the index writes several types to
      // one row where they are variations on a theme, and taking only the
      // first would read `datasources` as half-documented.
      expect(fixture.byModule['beta'], {'TomBeta', 'TomBetaToo'});
      // The alphabetical table is not swept into the module above it.
      expect(fixture.alpha, {'TomAlpha', 'TomBeta'});
    });

    test('the sections being demanded are the summaries\' own', () {
      expect(_sectionedTypes, hasLength(_modules().length));
      expect(_sectionedTypes['endpoints'], contains('TomWebSocketConnection'));
      // The cross-module case the doc comment records: declared in
      // `little_things`, documented under Authentication, and filed there by
      // the index. Measured against the source directory this would be a
      // false positive, which is why the summary is the source of truth.
      expect(_sectionedTypes['authentication'], contains('TomLoginException'));
      expect(
        _sectionedTypes['little_things'],
        isNot(contains('TomLoginException')),
      );
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

  group('no summary omits a name its module exports', () {
    // The groups above each police one *shape* of documentation — the Source
    // list, the Overview table, the Global Functions section, the Enums
    // section, the per-class member tables. Each is exact within its shape,
    // and between them they leave a gap that is invisible precisely because
    // every individual check passes: a type that belongs to none of those
    // shapes — a plain exported class that never made it into the summary at
    // all — is not omitted from any list, because there is no list it was
    // supposed to be on. It is simply absent, and absence is what none of the
    // other rules can see.
    //
    // This is the file-name-set problem one level in. The opening group
    // establishes that a summary *exists* for every module; this one
    // establishes that the summary *accounts for* every name the module
    // exports. Deliberately the weakest possible statement of that — named
    // somewhere, in any shape — because the strong version is already carried
    // by the shape-specific groups, and a second strict rule laid over them
    // would start rejecting documentation they accept.
    //
    // Unlike its neighbours this group has no quarantine set, because no module
    // holds debt here. An empty quarantine is worse than none — it keeps a
    // `skip:` that can never fire and a staleness meta-test that can never
    // fail, which is the dead rule the next reader cannot recognise as dead.
    // Should a module need parking again, five siblings above show the shape.
    for (final module in _modules()) {
      test(module, () {
        final unnamed = _unnamedApi(module);
        expect(
          unnamed,
          isEmpty,
          reason:
              'api_summary_$module.md never names these, which the barrel '
              'exports from $module: ${unnamed.join(', ')}. Not "documents '
              'thinly" — never names, so a reader who has the type in hand '
              'and comes here to look it up finds nothing and concludes it '
              'is internal.',
        );
      });
    }

    test('the name reader sees both shapes the summaries use', () {
      // The finding above is an emptiness assertion over a set difference, so
      // a reader that over-collected would report every summary as complete.
      // These two are the shapes that matter, and they are checked against
      // real summaries rather than a fixture because the hazard is that the
      // documents drift away from what the reader expects, not that the
      // reader has a bug on invented input.
      expect(
        _summaryNames('db_migration'),
        contains('MariadbMigrationException'),
        reason: 'a `####` heading with no backticks is how a class is filed',
      );
      expect(
        _summaryNames('object_persistence'),
        contains('And'),
        reason:
            'a first-column table cell is how the query operators are '
            'filed, thirty of them, and none has a heading',
      );
    });

    test('a mention inside a fenced block does not count as naming', () {
      // Written against a fixture rather than a real summary, because no real
      // summary can show this: every type any of them mentions in a sample is
      // also documented properly, so none of them would change its verdict
      // either way. The rule still has to hold — a summary must not be able to
      // discharge its duty to a type by using it in a code sample — and a
      // fixture is the only place the two cases can be held apart.
      const document = '''
#### SectionedType

Prose that mentions `MentionedType` in passing.

```dart
final x = SampledType();
// see `BacktickedInsideFence` for the slow path
```
''';
      final names = _namesIn(document);
      expect(
        names,
        containsAll(<String>['SectionedType', 'MentionedType']),
        reason:
            'a heading and an inline mention are both ways a summary names '
            'a type, and the reader must see both',
      );
      expect(
        names,
        isNot(contains('SampledType')),
        reason: 'appearing in a code sample is not being documented by it',
      );
      expect(
        names,
        isNot(contains('BacktickedInsideFence')),
        reason:
            'nor is being backticked inside one — the fence is stripped '
            'before spans are read, so the span pattern never reaches in',
      );
    });
  });

  group('no summary denies an enum its module exports', () {
    for (final module in _modules()) {
      test(module, () {
        final summary = _summary(module);
        final exported = _exportedEnums(module);
        final headings = _headingNamesOf(summary);

        final undocumented = exported
            .where((name) => !headings.contains(name))
            .toList();
        expect(
          undocumented,
          isEmpty,
          reason:
              'api_summary_$module.md gives no section to these enums, which '
              'the barrel exports from $module: ${undocumented.join(', ')}. An '
              'enum is the one kind of type whose values are its whole '
              'contract, so a reader who cannot find its section has no way to '
              'learn what it can be.',
        );

        final mentioned = _enumSectionMentionsOf(summary);
        if (mentioned == null) return;

        final denied = exported
            .where((name) => !mentioned.contains(name))
            .toList();
        expect(
          denied,
          isEmpty,
          reason:
              'api_summary_$module.md has an Enums section that does not '
              'account for these, which the barrel exports from $module: '
              '${denied.join(', ')}. The section need not document them — it '
              'may say where they are written up — but it must not leave them '
              'out. A stated "None" is worse than an omission: an omission '
              'invites the reader to look, a "None" tells them not to.',
        );

        final stale = _enumSectionHeadingsOf(
          summary,
        )!.where((name) => !exported.contains(name)).toList();
        expect(
          stale,
          isEmpty,
          reason:
              'api_summary_$module.md\'s Enums section heads a subsection for '
              'these, which $module does not export as enums: '
              '${stale.join(', ')}.',
        );
      });
    }

    test('the sweep is reading the sections it claims to check', () {
      // All three findings above are emptiness assertions, so a parser that
      // read nothing would report every summary as agreeing.
      expect(_enumSectionHeadingsOf(_summary('db_migration')), [
        'TomSchemaDivergenceKind',
      ]);
      expect(
        _enumSectionHeadingsOf(_summary('datasources')),
        hasLength(_exportedEnums('datasources').length),
      );
      // The enums filed beside the type that carries them are found all the
      // same, which is what keeps the forward check about documentation rather
      // than layout — and the accounting check satisfiable without moving them.
      expect(_exportedEnums('messaging'), hasLength(6));
      expect(
        _headingNamesOf(_summary('messaging')),
        containsAll(_exportedEnums('messaging')),
      );
      expect(
        _enumSectionMentionsOf(_summary('object_persistence')),
        contains('TomSortDirection'),
      );
      expect(_enumSectionHeadingsOf(_summary('object_persistence')), isEmpty);
      // And a module with no Enums section is not silently exempted from the
      // forward check — it simply makes no claim to contradict.
      expect(_enumSectionMentionsOf(_summary('messaging')), isNull);
    });

    test('the parsers read the shapes the package writes', () {
      expect(_declaredEnums('enum TomFoo { a, b }'), contains('TomFoo'));
      expect(_declaredEnums('enum _Hidden { a }'), isEmpty);
      expect(_declaredEnums('  enum Nested { a }'), isEmpty);
      const withHeading = '''
## Enums

### TomKind

| Value | Meaning |
| ----- | ------- |
| `missingTable` | one |

## Next Section

### NotMine
''';
      // A value table under the enum's heading must not be read as naming
      // types, or the summaries that got this section right would fail.
      expect(_enumSectionHeadingsOf(withHeading), ['TomKind']);
      expect(_enumSectionMentionsOf(withHeading), isNot(contains('NotMine')));
      // A cross-reference accounts for the enum without heading a section.
      const withReference = '''
## Enums

One: `TomKind`, documented beside the type that carries it.
''';
      expect(_enumSectionMentionsOf(withReference), contains('TomKind'));
      expect(_enumSectionHeadingsOf(withReference), isEmpty);
      expect(
        _enumSectionMentionsOf('## Enums\n\nNone.\n'),
        isNot(contains('TomKind')),
      );
      expect(_enumSectionMentionsOf('## Something Else\n\ntext\n'), isNull);
      // Type parameters are stripped, however a heading escapes them.
      expect(
        _headingNamesOf('#### MariadbPreparedStatement&lt;T&gt;\n'),
        contains('MariadbPreparedStatement'),
      );
    });
  });

  group('every guide\'s table of contents matches its sections', () {
    for (final guide in _docs('doc')) {
      test(guide, () {
        final headings = _guideHeadings(guide);
        final entries = _guideContentsEntries(guide);

        expect(
          entries,
          isNotNull,
          reason:
              'doc/$guide.md has no "## Table of Contents". Every other guide '
              'has one, and a reader who has learned to look for it reads its '
              'absence as a short document rather than as a missing list.',
        );

        final anchors = {for (final h in headings) h.anchor: h};

        final unlisted = headings
            .where((h) => !entries!.any((e) => e.anchor == h.anchor))
            .map((h) => '${'#' * h.level} ${h.text}')
            .toList();
        expect(
          unlisted,
          isEmpty,
          reason:
              'doc/$guide.md has sections its contents list omits: '
              '${unlisted.join(', ')}. Add an entry, or the section is only '
              'reachable by scrolling.',
        );

        final dangling = entries!
            .where((e) => !anchors.containsKey(e.anchor))
            .map((e) => e.anchor)
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
          entries
              .where((e) => anchors.containsKey(e.anchor))
              .map((e) => e.anchor)
              .toList(),
          headings.map((h) => h.anchor).toList(),
          reason:
              'doc/$guide.md\'s contents list is not in document order. A list '
              'that does not match the order of the sections it names is worse '
              'than no list, because a reader uses it to judge distance.',
        );

        final misindented = [
          for (final entry in entries)
            if (anchors[entry.anchor] case final heading?)
              if (heading.level != entry.level)
                '${entry.anchor} is written at level ${entry.level}, and its '
                    'heading is ${'#' * heading.level}',
        ];
        expect(
          misindented,
          isEmpty,
          reason:
              'doc/$guide.md\'s contents list indents entries that do not '
              'match their headings: ${misindented.join('; ')}. The indent is '
              'the only thing saying which chapter a sub-entry belongs to, so '
              'a flat list of forty entries is a list nobody reads.',
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

      // An underscore is a word character and survives. `scheduling.md` heads
      // three sub-sections with table names and links to them by those exact
      // fragments, so a rule that dropped the underscores would report three
      // live links as dangling — and the repair someone made in response would
      // be to point them at anchors that do not exist.
      expect(_anchorOf('tom_job_run'), 'tom_job_run');
      expect(_anchorOf('tom_scheduler_node'), 'tom_scheduler_node');
    });

    test('a repeated heading takes the suffix GitHub gives it', () {
      // `authentication.md` heads two sections `Failure keys`, and the second
      // is reachable only as `#failure-keys-1`. Counted over *every* heading in
      // the file rather than over the ones the checks read, because that is the
      // sequence GitHub counts through — skipping a level would shift every
      // suffix after it.
      final repeated = _guideHeadings(
        'authentication',
      ).where((h) => h.text == 'Failure keys').map((h) => h.anchor).toList();
      expect(
        repeated,
        ['failure-keys', 'failure-keys-1'],
        reason:
            'if this stops holding, the guide gained or lost a `Failure keys` '
            'heading and every anchor after it moved',
      );
    });
  });

  // A `#### Properties` table is the same completeness claim the Overview table
  // makes about a module, one level down: it says "these are the class's
  // properties". A reader who finds eight of ten has no signal that two are
  // missing, and the two that are missing are the ones nobody thought about —
  // which is how a getter carrying a deployment's whole logging decision, and
  // the pair every unannotated endpoint is protected under, came to be absent
  // from the class's own table.
  //
  // Every table, censused in both directions and in source order. No
  // quarantine: all of them agree, and an empty quarantine is worse than none —
  // it reads as outstanding debt that is not there, and it is the kind of list
  // nobody revisits.
  group('every Properties table lists the properties its class declares', () {
    test('the census recovers the tables', () {
      // Neither a parser that finds nothing nor one that attributes a table to
      // no type can fail the comparisons below, because it gives them nothing
      // to disagree about. So the count is asserted first, against the number
      // of `Properties` headings the documents actually carry.
      final headings = [
        for (final module in _modules())
          ..._propertiesHeadingsOf(module).where((h) => h.$2 == 'Properties'),
      ];
      expect(headings, isNotEmpty, reason: 'no Properties headings were found');
      expect(
        _propertyTableCensus.length,
        headings.length,
        reason:
            'the census holds ${_propertyTableCensus.length} tables but the '
            'summaries carry ${headings.length} "Properties" headings. A '
            'heading the census misses is a table nothing checks, and it is '
            'missed by sitting under a section whose heading names no type — '
            'which is what happens when a class is renamed in the source and '
            'not in its section title.',
      );
    });

    for (final module in _modules()) {
      test(module, () {
        final complaints = <String>[];
        for (final table in _propertyTableCensus.where(
          (table) => table.module == module,
        )) {
          final declaration = _declarations[table.type]!;
          final declared = _declaredProperties(declaration.path, table.type);

          final missing = declared
              .where((property) => !table.properties.contains(property))
              .toList();
          if (missing.isNotEmpty) {
            complaints.add(
              '${table.type} (line ${table.line}) omits '
              '${missing.join(', ')}, which ${declaration.path} declares',
            );
          }

          // Resolved through the supertypes, because a subclass's table may
          // describe a property it inherits rather than declares. `false` is
          // the only verdict acted on: `null` means an ancestor is outside
          // this package, where a name this census cannot see may still live.
          final orphaned = table.properties
              .where(
                (property) => _resolveMember(table.type, property) == false,
              )
              .toList();
          if (orphaned.isNotEmpty) {
            complaints.add(
              '${table.type} (line ${table.line}) has rows for '
              '${orphaned.join(', ')}, which the class neither declares nor '
              'inherits',
            );
          }

          // Restricted to the declared properties on both sides, so a row for
          // a static — which the summaries mark in the type column and which
          // belongs to no instance-declaration order — does not read as a
          // reordering.
          final rows = table.properties.where(declared.contains).toList();
          final source = declared.where(table.properties.contains).toList();
          if ('$rows' != '$source') {
            complaints.add(
              '${table.type} (line ${table.line}) is complete but reordered: '
              'the table reads $rows where the source declares $source',
            );
          }
        }

        expect(
          complaints,
          isEmpty,
          reason:
              'api_summary_$module.md and the classes it documents disagree '
              'about their properties:\n  ${complaints.join('\n  ')}\n'
              'A table headed "Property" claims to be the class\'s property '
              'surface. Kept in declaration order it also stays diffable '
              'against the source, so a property inserted mid-block lands in '
              'the table where it lands in the class.',
        );
      });
    }

    test('every Properties heading is either censused or named here', () {
      // The census reads the heading `Properties` exactly. Three other
      // spellings exist, and each is deliberate: `Static Properties` is a
      // table of statics, which the summaries keep separate; `Properties
      // (DbCol)` and `Properties and Methods` are mixed tables. Naming them
      // here is what stops a *fourth* spelling — a table that would then be
      // checked by nothing — from arriving unnoticed.
      final unchecked = {
        for (final module in _modules())
          for (final heading in _propertiesHeadingsOf(module))
            if (heading.$2 != 'Properties') heading.$2,
      };
      expect(
        unchecked,
        _uncensusedPropertyHeadings,
        reason:
            'the summaries carry property headings this census does not read '
            'and this list does not name: '
            '${unchecked.difference(_uncensusedPropertyHeadings).join(', ')} — '
            'either spell such a heading `Properties` so it is checked, or '
            'name it here with the reason it cannot be. And this list names '
            'headings no summary writes any more: '
            '${_uncensusedPropertyHeadings.difference(unchecked).join(', ')} — '
            'an exemption with nothing left to exempt reads as a table the '
            'census is choosing not to check, and it quietly re-arms if the '
            'spelling ever comes back.',
      );
    });

    test('every table of properties sits under one of those headings', () {
      // Read from the tables rather than from the headings, which is the
      // direction that catches a heading spelt something else entirely: a
      // `#### Props` carries a `| Property |` column all the same, and the
      // check above — which enumerates headings — would never look at it.
      final stray = <String>[];
      for (final module in _modules()) {
        final lines = File(
          'doc/api_reference/api_summary_$module.md',
        ).readAsLinesSync();
        String title = '';
        for (var index = 0; index < lines.length; index++) {
          final heading = RegExp(r'^#+\s+(.*)$').firstMatch(lines[index]);
          if (heading != null) {
            title = heading.group(1)!.trim();
            continue;
          }
          if (!lines[index].startsWith('| Property |')) continue;
          if (title == 'Properties') continue;
          if (_uncensusedPropertyHeadings.contains(title)) continue;
          stray.add('api_summary_$module.md:${index + 1} under "$title"');
        }
      }
      expect(
        stray,
        isEmpty,
        reason:
            'these tables have a `Property` column but sit under a heading '
            'the census does not read: ${stray.join(', ')}. A table nothing '
            'reads makes the same completeness claim as one that is read, and '
            'nothing holds it to it.',
      );
    });

    test('the parser reads a declaration the way the package writes one', () {
      // The shapes that decide the census, pinned rather than trusted.
      expect(_propertyNameOf('  final String language;'), 'language');
      expect(
        _propertyNameOf('  late final bool declaresNoResult;'),
        'declaresNoResult',
      );
      expect(_propertyNameOf('  String get tag => language;'), 'tag');
      expect(_propertyNameOf('  Duration get validity {'), 'validity');
      expect(_propertyNameOf('  List<TomOperator> get children;'), 'children');
      // A field whose *type* spells a parameter list is still a field.
      expect(_propertyNameOf('  final DateTime Function() clock;'), 'clock');
      // A wrapped initialiser puts the name before the `=`, not before a `;`.
      expect(_propertyNameOf('  final Map<String, String> fields ='), 'fields');

      // Not properties, each for its own reason.
      expect(
        _propertyNameOf('  static int globalSettingCodeDigits = 6;'),
        isNull,
      );
      expect(_propertyNameOf('  set thing(String value) {}'), isNull);
      expect(
        _propertyNameOf('  String maskDestination(String d) => d;'),
        isNull,
      );
      expect(_propertyNameOf('  TomTextLocale(this.language);'), isNull);
      expect(_propertyNameOf('  final String _cached;'), isNull);
      expect(_propertyNameOf('  integer(int),'), isNull);
      expect(
        _propertyNameOf('  }) : id = id ?? const UuidV4().generate(),'),
        isNull,
      );
      // Two-space indent is the class's own level; deeper is a method body.
      expect(_propertyNameOf('    final String local = x;'), isNull);

      // The one shape this reader cannot tell from a field, and the reason
      // [_classBody] starts at the brace that closes the header rather than at
      // the header: a wrapped type-parameter list is indented exactly like a
      // member, and `resultType extends Object` reads as a field called
      // `Object`. Pinned so that a body which stopped skipping the header
      // fails here, where the cause is written down, rather than in four
      // module tests at once.
      expect(_propertyNameOf('  resultType extends Object'), 'Object');
      expect(
        _declaredProperties(
          'lib/src/tomserver/endpoints/endpoint_annotation.dart',
          'TomApiEndpointImplementation',
        ),
        isNot(contains('Object')),
      );
    });

    test('a class body stops at the class', () {
      // The bound is what makes the census per-class rather than per-file: a
      // body that ran to the end of the file would carry the next class's
      // properties as if they were this one's.
      const path = 'lib/src/tomserver/messaging/message.dart';
      expect(
        _declaredProperties(path, 'TomMessageChannel'),
        isNot(contains('address')),
        reason:
            'TomRecipient.address is a later class in the same file; a body '
            'that reaches it is unbounded',
      );
      expect(_declaredProperties(path, 'TomRecipient'), contains('address'));
    });
  });

  // The one class a deployment fills in to stand a server up. Every field is a
  // knob somebody has to set correctly without being able to read the code that
  // consumes it, and several are not self-describing from the name:
  // `logLevelExceptions` is a per-logger override list rather than a level for
  // exceptions, `listenToAnyIP` discards a configured host rather than adding
  // an address, and `isolateCount`, `preExecutionHandler` and
  // `postExecutionHandler` each carry a behaviour only `server.dart` reveals.
  //
  // A field is the smallest thing a document can omit and the easiest: adding
  // one is a single line, and nothing about writing it prompts for a comment.
  // So the rule is all-or-nothing rather than a count — the next field to
  // arrive undocumented fails here, where the class is, rather than being
  // noticed in a sweep some months later.
  group('every configurable field is documented where it is declared', () {
    const className = 'TomBaseServerConfiguration';
    const path =
        'lib/src/tomserver/configuration/base_server_configuration.dart';

    /// The Properties table for this class, from the census the whole
    /// api_reference is held to.
    List<String> tableRows() => _propertyTableCensus
        .firstWhere(
          (table) => table.module == 'configuration' && table.type == className,
        )
        .properties;

    test('the census reads the class', () {
      // A body that came back empty would pass the assertion below by finding
      // nothing to complain about. Held against the Properties table, which is
      // censused in both directions elsewhere in this file, so the two readers
      // of this class agree about what it declares — and the guard below
      // inherits that agreement rather than asserting a number of its own.
      expect(
        _declaredFields(path, className),
        tableRows(),
        reason:
            'the field census and the summary Properties table disagree about '
            'what $className declares; one of the two readers is wrong, and '
            'the check below is only as good as this one',
      );
    });

    test('no field is left to the reader to guess at', () {
      expect(
        _undocumentedFields(path, className),
        isEmpty,
        reason:
            'these fields on $className carry no dartdoc: '
            '${_undocumentedFields(path, className).join(', ')}. This class is '
            'the deployment interface — a field with no comment is a setting '
            'somebody has to get right by reading the framework, and the '
            'summary row alone cannot carry the reason a value matters.',
      );
    });

    test('the census sees the fields most easily skipped', () {
      // The two TLS fields are declared with a multi-line string default, so
      // their declaration line ends in `= '''` rather than a `;`. `_classBody`
      // replaces the literal before the scan, which is the only reason they
      // read as ordinary fields — a reader that skipped them would report this
      // class fully documented while leaving the credential pair uncommented,
      // and the guard above would be quiet about exactly the two fields a
      // deployment must not leave at their defaults.
      expect(
        _declaredFields(path, className),
        containsAll(<String>['certificateChain', 'privateKey']),
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

  // The census is built by blanking what is not code and then scanning what is
  // left, so its idea of "not code" is load-bearing for every check that reads
  // it. Deleting `/*` … `*/` with a regular expression got that wrong in the
  // one place the package is most likely to write the marker: a dartdoc line
  // about SQL comments. These tests drive the blanker over fixtures rather
  // than over the package, because the package is where the bug was *absent*
  // — it had one balanced pair per line, so it happened not to be bitten, and
  // a check that only reads the package would have gone on passing.
  group('the census blanker opens a comment only where Dart would', () {
    test('a `/*` inside a dartdoc line opens nothing', () {
      const source = '''
/// Whether a comment opens at [index] — `--`, `#` or `/*`.
static bool commentOpensAt(String sql, int index) => false;

/* A real block comment. */
class After {}
''';
      final blanked = _withoutBlockComments(source);
      expect(
        blanked,
        contains('commentOpensAt'),
        reason: 'the declaration under the dartdoc must survive',
      );
      expect(
        blanked,
        contains('class After'),
        reason:
            'and so must everything up to the next `*/`, which the regular '
            'expression consumed as the close of a comment that never opened',
      );
      expect(
        blanked,
        isNot(contains('A real block comment')),
        reason: 'the comment that did open is still removed',
      );
    });

    test('a `//` line comment does not open one either', () {
      const source = '// see /* below\nclass After {}\n/* gone */\n';
      expect(_withoutBlockComments(source), contains('class After'));
      expect(_withoutBlockComments(source), isNot(contains('gone')));
    });

    test('a `/*` inside a string literal opens nothing', () {
      // `sql_lexer` holds the literal `'*/'`, so markers do reach this
      // package's code as data. An opener in a string must not start a
      // comment.
      const source = "final a = '/*';\nclass After {}\n";
      expect(_withoutBlockComments(source), contains('class After'));
    });

    test('but a `*/` inside a comment closes it, quotes and all', () {
      // Not an oversight — it is what Dart does, verified against the
      // analyzer: there are no string literals *inside* a block comment, so
      // the first `*/` ends it wherever it sits. That asymmetry is why the
      // string handling above belongs on the opener alone; teaching the
      // closer about quotes would make this blanker disagree with the
      // language rather than with a regular expression.
      const source = "/* open\nfinal a = '*/';\nclass Inside {}\n";
      expect(_withoutBlockComments(source), contains('class Inside'));
    });

    test('an escaped quote does not end the string it is in', () {
      const source = "final a = 'it\\'s /*';\nclass After {}\n";
      expect(_withoutBlockComments(source), contains('class After'));
    });

    test('a raw string takes its backslash literally', () {
      // `r'\'` cannot be written, but `r'a\'` can, and treating its backslash
      // as an escape would swallow the closing quote and everything after it.
      const source =
          r"final a = r'a\';"
          "\nclass After {}\n";
      expect(_withoutBlockComments(source), contains('class After'));
    });

    test('a removed comment keeps its newlines', () {
      // So a position recorded against the blanked text still names the line
      // it came from. Nothing records one today; the regular expression made
      // that unrecoverable, and this makes it merely unused.
      const source = '/* one\ntwo\nthree */\nclass After {}\n';
      expect(_withoutBlockComments(source).split('\n').length, 5);
    });

    test('an unterminated block comment still runs to the end', () {
      // What Dart does with one. It is unreachable from a phantom opener now,
      // so a file that gets here does not compile either — but the blanker
      // must not quietly keep the text and let the census read a comment.
      const source = '/* open\nclass After {}\n';
      expect(_withoutBlockComments(source), isNot(contains('class After')));
    });

    test('the census holds the member the regular expression ate', () {
      // The end of it, against the package: `commentOpensAt` is declared after
      // a dartdoc line carrying a bare `/*`, and its dartdoc no longer has to
      // be phrased around the blanker to stay visible.
      expect(_declarations['TomSqlLexer']?.members, contains('commentOpensAt'));
      expect(
        File(
          'lib/src/tomserver/db_migration/sql_lexer.dart',
        ).readAsStringSync(),
        contains('`--`, `#` or `/*`'),
        reason:
            'the dartdoc is written the natural way; if it was rephrased '
            'again, the blanker is what to check first',
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

  group('every relationship line names the clause the source wrote', () {
    test('no summary turns an interface into a base class', () {
      // The two words are not synonyms to a reader deciding how to write a
      // second implementation. `implements` says the contract hands over no
      // behaviour, so the new class owes every member; `extends` says some of
      // them may already be answered. Getting it backwards sends that reader
      // looking for inherited helpers that do not exist — which is exactly what
      // happened to `TomSqlJobStore`, in prose that called it an extension of
      // `TomJobStore` while the source implemented it.
      //
      // The summaries were right in that instance and the narrative was wrong,
      // which is the reverse of this doc-set's usual failure. It is not a
      // reason to trust them: nothing was checking, and a line that is correct
      // only because nobody has edited it yet is not an invariant.
      final offenders = <String>[];
      for (final claim in _relationshipClaims()) {
        final declaration = _declarations[claim.type]!;
        if (claim.denies) {
          final actual = claim.extending
              ? declaration.superclass
              : (declaration.interfaces.isEmpty
                    ? null
                    : declaration.interfaces.join(', '));
          if (actual != null) {
            offenders.add(
              '${claim.file}:${claim.line} ${claim.type} documented as '
              '${claim.extending ? "extending" : "implementing"} nothing, '
              'source names $actual',
            );
          }
          continue;
        }
        // A line that names no type at all says nothing to disagree with. It is
        // not an error here — the sections that carry one describe the
        // relationship in prose — and the reach test below is what keeps that
        // from becoming a way to go quiet.
        if (claim.named.isEmpty) continue;
        final actual = claim.extending
            ? {if (declaration.superclass != null) declaration.superclass!}
            : declaration.interfaces;
        final missing = claim.named.where((n) => !actual.contains(n));
        if (missing.isEmpty) continue;
        offenders.add(
          '${claim.file}:${claim.line} ${claim.type} documented as '
          '${claim.extending ? "extending" : "implementing"} '
          '${missing.join(", ")}; source '
          '${claim.extending ? "extends" : "implements"} '
          '${actual.isEmpty ? "nothing" : actual.join(", ")}',
        );
      }
      expect(offenders, isEmpty);
    });

    test('the sweep reaches every line it is meant to police', () {
      // Attribution is what this sweep can get silently wrong: a claim whose
      // heading was not recognised is filed under no class and then checked
      // against nothing. So the count is pinned exactly rather than floored —
      // every relationship line in the directory must have found a class, and
      // an unrecognised heading fails here instead of quietly shrinking the
      // check above.
      final written = Directory('doc/api_reference')
          .listSync()
          .whereType<File>()
          .where((entry) => entry.path.endsWith('.md'))
          .expand((file) => file.readAsLinesSync())
          .where(
            (line) =>
                line.startsWith('- **Extends:**') ||
                line.startsWith('- **Implements:**'),
          )
          .length;
      final claims = _relationshipClaims();
      expect(written, greaterThan(100));
      expect(
        claims.length,
        written,
        reason:
            'every relationship line must be attributed to a class the '
            'package declares; a shortfall is a heading the parser missed, '
            'not a line that needed none',
      );

      // Both shapes present, or the comparison only ever exposes one of its two
      // possible mistakes — and the pair that prompted the guard by name, since
      // they are the package's clearest case of the distinction being real.
      expect(claims.any((c) => c.extending), isTrue);
      expect(claims.any((c) => !c.extending), isTrue);
      expect(claims.any((c) => c.denies), isTrue);
      expect(
        claims.singleWhere((c) => c.type == 'TomSqlJobStore').extending,
        isFalse,
        reason:
            '`TomSqlJobStore` implements `TomJobStore`; it inherits nothing',
      );
      expect(
        claims.singleWhere((c) => c.type == 'TomSqlLeaseLock').extending,
        isTrue,
        reason: '`TomSqlLeaseLock` really does extend `TomLeaseLock`',
      );
    });
  });

  group('every hierarchy pointer names the module that documents the type', () {
    test('the module a diagram sends a reader to has the type in it', () {
      // A hierarchy diagram shows a borrowed type without describing it — that
      // is the point of the parenthetical, which says where the description
      // lives. So the pointer is the whole of the diagram's promise about that
      // type, and a wrong one costs more than no pointer at all: a reader who
      // opens the named summary and does not find the type cannot tell whether
      // they misread the diagram or the type is undocumented, and the honest
      // answer — it is documented, one module over — is the one conclusion the
      // evidence rules out.
      //
      // `TomServerException` was the case in point. Six diagrams sent readers
      // to `little_things`, where it is declared and documented; five sent them
      // to `server`, which does not document it, and one to the package name,
      // which names no summary at all. The majority being right is not a
      // defence — nothing was comparing them, so the six were right by
      // coincidence and the five stayed wrong for as long as nobody checked.
      final offenders = <String>[];
      for (final pointer in _modulePointers()) {
        if (_summaryNames(pointer.module).contains(pointer.type)) continue;
        offenders.add(
          '${pointer.file}:${pointer.line} sends a reader to '
          '${pointer.module} for ${pointer.type}, which '
          'api_summary_${pointer.module}.md does not document',
        );
      }
      expect(offenders, isEmpty);
    });

    test('the sweep reaches the pointers it is meant to police', () {
      // The check above passes just as quietly on a regex that matches nothing,
      // and the shape it reads is punctuation — two spaces, a bracket, a
      // box-drawing character — every part of which a later reformat could
      // change without anyone thinking of this test. So pin what it found: the
      // cross-module pointers the diagrams actually carry today.
      // Floors rather than equalities, because a new module documenting a
      // borrowed type adds a pointer and that is not a regression. They sit at
      // today's true counts so that losing even one — the way the continuation
      // bar was lost, silently and only on the deepest branch — trips here.
      final pointers = _modulePointers();
      expect(pointers.length, greaterThanOrEqualTo(14));
      expect(
        pointers.where((p) => p.type == 'TomServerException').length,
        greaterThanOrEqualTo(12),
        reason: 'every module that subtypes it names where it is documented',
      );
      expect(
        pointers.every((p) => p.module != 'server'),
        isTrue,
        reason:
            '`TomServerException` lives in little_things; the server module '
            'documents neither it nor `TomTransactionParticipant`',
      );

      // A parenthetical that names a kind rather than a module must stay out,
      // or the check above starts demanding that `api_summary_abstract.md`
      // exist. These are the two shapes that share the line's punctuation.
      expect(pointers.any((p) => p.module == 'abstract'), isFalse);
      expect(pointers.any((p) => p.module == 'enum'), isFalse);

      // And a genuine cross-module pointer that was already right, so the sweep
      // is shown accepting one rather than only rejecting.
      expect(
        pointers.any(
          (p) =>
              p.file == 'api_summary_datasources.md' &&
              p.type == 'TomGroupedSelect' &&
              p.module == 'object_persistence',
        ),
        isTrue,
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
      test('$module says what it has not done', () {
        expect(
          _hasLimitationsSection(module),
          isTrue,
          reason:
              'The check above says a claim of unfinished work must live in '
              'the limitations section. A guide without one therefore has '
              'nowhere legal to say it, and the pressure is to leave the '
              'edge undocumented rather than to write it down: '
              '`doc/datasources.md` described a module that ships one '
              'database driver, stores a date and a time in columns that '
              'cannot carry a zone and runs XA with no recovery, and '
              'mentioned none of it. Silence '
              'reads as "no edges", which is a stronger claim than any of '
              'these guides can make.',
        );
      });
    }

    for (final module in _modules()) {
      test('$module names code that is still there', () {
        final unresolved = _unresolvedNamesOf(module);
        expect(
          unresolved,
          isEmpty,
          reason:
              'these names in doc/$module.md\'s limitations section are not in '
              'the package: ${unresolved.join('; ')}. A limitation reads as '
              'live however old it is, so the section is the one place in a '
              'guide where nothing goes stale visibly — a bullet naming a '
              'class that was renamed out from under it looks exactly like a '
              'bullet naming one that is still there.',
        );
      });
    }

    test('the census reads the section and nothing else', () {
      // Each assertion above passes on an empty read, so the read is pinned.
      // Twenty guides, 173 names — if either number collapses the checks are
      // agreeing that nothing is missing from nothing.
      final names = [
        for (final module in _modules())
          for (final (:line, :text) in _limitationsBodyOf(module))
            for (final span in _backtickedSpan.allMatches(text))
              if (_dartName.firstMatch(span.group(1)!.trim()) case final name?)
                if (name.group(1)!.split('.').any(_caseHump.hasMatch))
                  (line, span.group(1)!),
      ];
      expect(names, hasLength(greaterThan(150)));
      expect(
        _packageVocabulary,
        hasLength(greaterThan(5000)),
        reason: 'an empty vocabulary would report every name as missing',
      );
      expect(_packageVocabulary, contains('TomFileSlots'));
      // Two names that occur only inside string literals — a settings key and
      // an error-envelope field. Stripping literals reports both as missing.
      expect(_packageVocabulary, containsAll(['delegateTo', 'errorType']));
      // Prose is not vocabulary. `Within` appears in dartdoc and nowhere in
      // code, and a census built from raw text would answer "yes" to it.
      expect(_packageVocabulary, isNot(contains('Within')));
    });

    test('a renamed class in a bullet is reported', () {
      expect(
        _unresolvedNamesIn('- `TomFileSlots` is a process-wide registry.'),
        isEmpty,
      );
      expect(
        _unresolvedNamesIn('- `TomFileSlabs` is a process-wide registry.'),
        ['`TomFileSlabs` — no TomFileSlabs in lib/'],
      );
      expect(
        _unresolvedNamesIn('- `TomFileSlots.resat()` is process-wide.'),
        ['`TomFileSlots.resat()` — no resat in lib/'],
        reason: 'the member half of a dotted name is checked too',
      );
    });

    test('a token that is not a Dart name is not read as one', () {
      // The measurement behind the rule: of the 365 backticked spans in these
      // sections, 173 carry a case hump and 192 do not — JWT claims, SQL
      // keywords, locale tags, HTTP headers, shell fragments, values. None of
      // them is code, and a check that demanded they resolve would need a list
      // of exempt words rather than a rule.
      for (final token in const [
        '`exp`',
        '`iat`',
        '`id_token`',
        '`max_age`',
        '`DATE`',
        '`LIMIT`',
        '`LIKE`',
        '`REGEXP`',
        '`de_AT`',
        '`en`',
        '`Range`',
        '`GUEST`',
        '`tom_oauth_state`',
        '`--port=8080`',
        '`500`',
        '`{name}`',
        '`After`',
        '`Before`',
        '`Containing`',
        '`Exists`',
        '`Within`',
      ]) {
        expect(
          _unresolvedNamesIn('- a bullet naming $token'),
          isEmpty,
          reason: '$token is not a Dart name and must not be judged as one',
        );
      }
    });

    test('a bullet that names nothing at all is allowed', () {
      // Naming something is not required, and cannot be. 19 of the 119
      // bullets in these sections name no symbol whatever, and every one of
      // them describes a missing *feature* — "Inbound mail", "DKIM signing",
      // "Content addressing / deduplication", "Server-rendered forms". A
      // feature that does not exist has nothing to name, so a rule demanding
      // a name would be answered by inventing one.
      expect(
        _unresolvedNamesIn('- **Inbound mail.** This module sends only.'),
        isEmpty,
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
        for (final (name, lines) in _citingSurfaces())
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

    test('every group a document or a header cites still exists', () {
      final missing = [
        for (final (name, lines) in _citingSurfaces())
          ..._missingGroups(name, lines),
      ];
      expect(
        missing.map((a) => '${a.file}:${a.line} ${a.path}'),
        isEmpty,
        reason:
            'these citations name a group no suite declares. A group name is '
            'what a coverage pointer cites instead of a line number, because a '
            'line number rots while the file around it is edited and says '
            'nothing when it does. That trade is only safe while something '
            'reads the name.',
      );
    });

    test('a group citation is read, and read strictly', () {
      // Both directions. The corpus writes these a dozen-odd times, so an
      // expression matching none would leave the check above green over
      // nothing — and one matching loosely would report SQL.
      // Counted over paragraphs, not lines: these citations wrap, and the
      // check itself flattens before matching. A per-line count would report
      // none and prove nothing about the sweep that does the work.
      final cited = [
        for (final (_, lines) in _citingSurfaces())
          for (final paragraph in _paragraphsOf(lines, includeFenced: true))
            ..._groupCitation.allMatches(
              paragraph
                  .map((i) => lines[i].replaceFirst(RegExp(r'^\s*///?\s?'), ''))
                  .join(' '),
            ),
      ];
      expect(cited, hasLength(greaterThan(5)));

      expect(
        _groupCitation.hasMatch('by the group named `healthcheck GET /health`'),
        isTrue,
      );
      expect(
        _groupCitation.hasMatch('keyed by their `title` group value'),
        isFalse,
        reason: 'a SQL GROUP BY column is not a test group',
      );
      expect(
        _groupCitation.hasMatch('the three groups `TomX` exposes'),
        isFalse,
        reason: 'three getters are not three test groups',
      );
    });

    test('a citation naming a group that does not exist is reported', () {
      expect(
        _missingGroups('synthetic.md', const [
          'Asserted in `test/healthcheck_test.dart`, by the group named',
          '`no such group at all`.',
        ]).map((a) => a.path),
        ['`no such group at all`'],
      );
      expect(
        _missingGroups('synthetic.md', const [
          'Asserted in `test/endpoints_pipeline_test.dart`, by the group named',
          '`healthcheck GET /health route`.',
        ]),
        isEmpty,
      );
    });

    test('the sweep is looking at the references it claims to check', () {
      // Emptiness is also what a regex that matches nothing produces. The
      // guides really do name their suites — thirty-odd times — and that is
      // the fact this check stands on.
      final found = [
        for (final (_, lines) in _citingSurfaces())
          for (final line in lines) ..._artifactReference.allMatches(line),
      ];
      expect(
        found.length,
        greaterThan(200),
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
      test('$module names both', () {
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
      });
    }

    test('an unnamed artefact is what the sweep reports', () {
      // Emptiness across twenty modules is only worth something if the
      // measurement can see the debt at all, so each shape is driven over text
      // written to have it. `transactions` is the module named because it has
      // exactly one suite and one example, which keeps the expected strings
      // short; what is under test is the rule, not that module.
      expect(_unnamedVerification('transactions'), isEmpty);
      expect(
        _unnamedVerificationIn('transactions', 'A guide naming nothing.'),
        [
          'does not name transactions_test.dart',
          'names none of its examples '
              '(example/transactions/transactions_example.dart)',
        ],
      );
      // The fallback clause, which only a module with no name-matched suite can
      // reach: `preferences` has none, and its example directory holds nothing
      // runnable, so a guide naming nothing at all reports exactly one fault.
      expect(_moduleSuites('preferences'), isEmpty);
      expect(_exampleArtifacts('preferences'), isEmpty);
      expect(_unnamedVerificationIn('preferences', 'A guide naming nothing.'), [
        'names no test suite',
      ]);
      expect(
        _unnamedVerificationIn(
          'transactions',
          'Covered by `test/transactions_test.dart`.',
        ),
        [
          'names none of its examples '
              '(example/transactions/transactions_example.dart)',
        ],
      );
      expect(
        _unnamedVerificationIn(
          'transactions',
          'Run `dart run example/transactions/transactions_example.dart`.',
        ),
        ['does not name transactions_test.dart'],
      );

      // Reference migrations are not an example a reader runs, and `audit.md`
      // names some — so it is the case that separates citing data from
      // pointing at a program. Read off the directory, which is where that
      // distinction is actually made.
      expect(_exampleArtifacts('audit'), ['example/audit/audit_example.dart']);
    });

    test('naming one suite is not naming the module\'s suites', () {
      // The distinction the strengthened rule turns on. A guide may name
      // several suites and still own none of them — which is how one came to
      // cite three and leave its own unmentioned. The weak rule passes on this
      // text; the strengthened one does not, and nothing but naming the
      // module's own suite settles it.
      const citesAnother =
          'Covered by `test/datasources_test.dart` and '
          '`test/framework_schema_test.dart`, and by '
          '`dart run example/transactions/transactions_example.dart`.';
      expect(
        _suiteReference.hasMatch(citesAnother),
        isTrue,
        reason: 'the weak rule is satisfied — a suite is named',
      );
      expect(
        _unnamedVerificationIn('transactions', citesAnother),
        ['does not name transactions_test.dart'],
        reason: 'the strengthened rule is not: its own suite is missing',
      );
    });

    test('a module with no name-matched suite still has to name one', () {
      // The two clauses are alternatives, so the fallback has to keep working
      // or a module whose suites are all named for something else would be
      // exempted by the very rule meant to tighten the check. `preferences` is
      // that module — no `preferences*_test.dart` exists at all, and it
      // satisfies the check by naming the suite that does cover it.
      expect(_moduleSuites('preferences'), isEmpty);
      expect(
        _unnamedVerification('preferences'),
        isNot(contains('names no test suite')),
        reason: 'it does name a suite, just not one carrying its own name',
      );
      expect(_moduleSuites('db_migration'), [
        'db_migration_db_test.dart',
        'db_migration_test.dart',
      ]);
    });
  });

  group('a guide that says a check needs a server names the tagged suite', () {
    test('no guide hangs a `db`-tagged check off an untagged suite', () {
      final misattributed = [
        for (final (name, lines) in _guides())
          ..._untaggedTagClaims(name, lines),
      ];
      expect(
        misattributed,
        isEmpty,
        reason:
            'Every suite here that needs a provisioned server is a '
            '`_db_test.dart` sibling of a connection-free one — that split is '
            'what lets `testkit :test` run green without MariaDB. A guide that '
            'describes the provisioned check as a "half" of the file beside it '
            'sends a reader looking for a tag inside a file that has none, and '
            'the conclusion they reach is that the check does not exist. '
            '`doc/scheduling.md` said exactly that about '
            '`framework_schema_test.dart` for as long as the sentence stood, '
            'while the file\'s own header said the opposite three lines from '
            'the top.',
      );
    });

    test('the shape that went wrong is what the sweep reports', () {
      // `doc/scheduling.md` as it read before this guard. Checked in rather
      // than mutated by hand, because a guard nobody has watched fail is a
      // guard nobody knows works.
      expect(
        _untaggedTagClaims('synthetic.md', [
          '`test/framework_schema_test.dart` covers the wider guarantee that',
          'the three tables are declared once; its `db`-tagged half adds the',
          'same comparison against a provisioned `information_schema`.',
        ]),
        ['synthetic.md:1 test/framework_schema_test.dart'],
      );
      // Naming the sibling that carries the tag is what settles it — and it is
      // the *only* thing that does, so the fix cannot be a rewording.
      expect(
        _untaggedTagClaims('synthetic.md', [
          '`test/framework_schema_test.dart` needs no connection. The',
          '`db`-tagged `test/framework_schema_db_test.dart` is its sibling.',
        ]),
        isEmpty,
      );
      // A paragraph that names nothing is a back-reference, not a claim this
      // can resolve; `doc/scheduling.md` has one and it must stay legal.
      expect(
        _untaggedTagClaims('synthetic.md', [
          'It is tagged `db` and skips when no server is reachable.',
        ]),
        isEmpty,
      );
    });

    test('both sides of the sweep are read, not merely found absent', () {
      // The assertion above is an emptiness, which is also what a regex that
      // stopped matching produces. Pin the two facts it stands on: that the
      // claim is still made in the guides, and that a tag is still legible in
      // a suite.
      final claiming = [
        for (final (name, lines) in _guides())
          for (final paragraph in _paragraphsOf(lines, includeFenced: false))
            if (_serverTagClaim.hasMatch(
              paragraph.map((i) => lines[i]).join(' '),
            ))
              name,
      ];
      expect(
        claiming.length,
        greaterThan(3),
        reason:
            'the guides do say which checks need a server; if this drops, the '
            'sweep above is asserting that nothing matches nothing',
      );
      final tagged = _resolveSuite('test/framework_schema_db_test.dart');
      expect(tagged, isNotNull);
      expect(tagged!.readAsStringSync(), contains("@Tags(['db'])"));
      // The other half of the pair, which is what makes the check a check.
      expect(
        _resolveSuite('test/framework_schema_test.dart')!.readAsStringSync(),
        isNot(contains("@Tags(['db'])")),
      );
    });
  });

  group('a heading that counts agrees with the table under it', () {
    test('no shipped document heads a table with the wrong number', () {
      final miscounted = [
        for (final document in _handWrittenDocuments())
          ..._miscountedTableHeadings(
            document,
            File(document).readAsLinesSync(),
          ),
      ];
      expect(
        miscounted,
        isEmpty,
        reason:
            'A heading with nothing between it and a table is that table\'s '
            'caption, and a reader takes the count as a fact about the rows. '
            '`example/scheduling/cluster/readme.md` headed five rows "The '
            'three programs", and the two rows the heading wrote off were the '
            'shared library and the reflection root — the second of which is '
            'the one whose absence fails the demo at its first query rather '
            'than at its build. A count that undersells a table is an '
            'invitation to stop reading at the number.',
      );
    });

    test('the shape that went wrong is what the sweep reports', () {
      // The cluster readme as it read before this guard.
      expect(
        _miscountedTableHeadings('synthetic.md', [
          '## The three programs',
          '',
          '| File | Role |',
          '| ---- | ---- |',
          '| `a.dart` | one |',
          '| `b.dart` | two |',
          '| `c.dart` | three |',
          '| `d.dart` | four |',
          '| `e.dart` | five |',
        ]),
        ['synthetic.md:1 states 3 over 5 rows'],
      );
      // Correcting the number settles it — the table did not have to change.
      expect(
        _miscountedTableHeadings('synthetic.md', [
          '## The five Dart files',
          '',
          '| File | Role |',
          '| ---- | ---- |',
          '| `a.dart` | one |',
          '| `b.dart` | two |',
          '| `c.dart` | three |',
          '| `d.dart` | four |',
          '| `e.dart` | five |',
        ]),
        isEmpty,
      );
    });

    test('a number word that names rather than counts is left alone', () {
      // `# The two-node cluster demonstration` and `## Two-Factor
      // Authentication` are names. Reading them as counts would either force a
      // rewrite of correct prose or, worse, train whoever hit the failure to
      // treat this guard as noise.
      expect(_statedCounts('The two-node cluster demonstration'), isEmpty);
      expect(_statedCounts('Two-Factor Authentication'), isEmpty);
      expect(_statedCounts('The three programs'), {3});
      expect(_statedCounts('Two caps, deliberately'), {2});
    });

    test('the sweep reads documents, and reads past fences', () {
      // Emptiness is also what a sweep that visits nothing produces.
      final documents = _handWrittenDocuments();
      expect(documents, contains('example/scheduling/cluster/readme.md'));
      expect(documents.length, greaterThan(20));
      // A `# comment` inside a fenced Dart block is not a heading, and
      // `doc/authentication.md` has one that counts: `# The four templates`.
      // Reading it as a heading would attribute it to whatever table came next.
      expect(
        _miscountedTableHeadings('synthetic.md', [
          '```dart',
          '# The three templates',
          '```',
          '',
          '| File | Role |',
          '| ---- | ---- |',
          '| `a.dart` | one |',
        ]),
        isEmpty,
      );
    });
  });

  group('the cluster readme lists the files the demo has', () {
    const readme = 'example/scheduling/cluster/readme.md';
    const runner = 'example/scheduling/cluster/run_cluster_demo.sh';

    /// The `File` and `Kind` columns of the readme's file table.
    Map<String, String> tabledFiles() => {
      for (final line in File(readme).readAsLinesSync())
        if (RegExp(r'^\| `(\w+\.dart)` \| (\w+) \|').firstMatch(line)
            case final row?)
          row.group(1)!: row.group(2)!,
    };

    test('every Dart file in the directory has a row', () {
      final present =
          Directory('example/scheduling/cluster')
              .listSync()
              .whereType<File>()
              .map((entry) => entry.uri.pathSegments.last)
              .where((name) => name.endsWith('.dart'))
              .toList()
            ..sort();
      expect(
        tabledFiles().keys.toList()..sort(),
        present,
        reason:
            'The heading counts these rows, so a file added without one makes '
            'the count wrong and the reader short of a file at the same time. '
            'Tying the table to the directory is what keeps the number a fact '
            'rather than something to remember.',
      );
    });

    test('the rows marked invoked are the ones the runner runs', () {
      final script = File(runner).readAsStringSync();
      final run = RegExp(
        r'dart run \S*/(\w+\.dart)',
      ).allMatches(script).map((match) => match.group(1)!).toSet();
      final invoked = {
        for (final entry in tabledFiles().entries)
          if (entry.value == 'invoked') entry.key,
      };
      expect(
        invoked,
        run,
        reason:
            'The split between invoked and imported is what makes "three '
            'programs" true of a five-row table, so it has to be read off the '
            'runner rather than remembered. Marking a fourth row invoked would '
            'otherwise leave the count correct and the sentence false.',
      );
      // Everything else is imported — no third kind quietly appearing.
      final imported = {
        for (final entry in tabledFiles().entries)
          if (entry.value == 'imported') entry.key,
      };
      expect(invoked.union(imported), tabledFiles().keys.toSet());
    });

    test('the count guard actually reaches this readme', () {
      // Immediacy means a paragraph slipped between the heading and the table
      // exempts the document *silently* — which is exactly what the first
      // draft of this fix did, moving the one readme the guard was written for
      // into the exempt set without anything saying so. Swapping the number
      // has to produce a report, or the guard above is decorative here.
      final swapped = [
        for (final line in File(readme).readAsLinesSync())
          if (line == '## The five Dart files')
            '## The three Dart files'
          else
            line,
      ];
      expect(_miscountedTableHeadings(readme, swapped), [
        contains('states 3 over 5 rows'),
      ]);
    });

    test('both sides of the comparison are actually read', () {
      // Two empty sets compare equal, so pin that neither is empty and that
      // the runner is being parsed rather than merely opened.
      expect(tabledFiles(), hasLength(5));
      expect(File(runner).readAsStringSync(), contains('dart run'));
      expect(tabledFiles()['cluster_reflection.dart'], 'imported');
      expect(tabledFiles()['cluster_verify.dart'], 'invoked');
    });
  });

  group('a guide that counts what a suite asks agrees with the suite', () {
    /// The number words a doc or a suite header is allowed to count in.
    ///
    /// Words rather than digits because that is how both sides write it, and a
    /// closed set rather than a parser because the check should fail loudly on
    /// "a dozen" instead of quietly reading it as zero.
    const numbers = {
      'two': 2,
      'three': 3,
      'four': 4,
      'five': 5,
      'six': 6,
      'seven': 7,
      'eight': 8,
      'nine': 9,
      'ten': 10,
      'eleven': 11,
      'twelve': 12,
    };

    /// The count the guide claims, the count the suite header claims, and the
    /// number of sections the suite is actually divided into.
    ///
    /// Three separately-written numbers for one fact, which is exactly why they
    /// drift: the guide said "three" for a suite that had grown to five, and
    /// nothing connected the two sentences.
    ({int guide, int header, int sections, int enumerated}) counts() {
      final guide = File('doc/scheduling.md').readAsStringSync();
      final suite = File('test/scheduling_cluster_test.dart').readAsLinesSync();
      final claimed = RegExp(
        r'covers the (\w+) cluster questions',
      ).firstMatch(guide);
      final declared = RegExp(
        r'^/// (\w+) questions, none of which',
        multiLine: true,
      ).firstMatch(suite.join('\n'));
      return (
        guide: numbers[claimed?.group(1)?.toLowerCase()] ?? -1,
        header: numbers[declared?.group(1)?.toLowerCase()] ?? -1,
        sections: suite
            .where((line) => RegExp(r'^\s*// GAP \d+ —').hasMatch(line))
            .length,
        // The guide's list items, which is what a reader counts. A count that
        // agrees with the suite while the list beneath it is short is the same
        // defect wearing a correct number.
        enumerated: RegExp(
          r'^\d+\. \*\*',
          multiLine: true,
        ).allMatches(guide).length,
      );
    }

    test('the guide, the suite header and the suite agree on the number', () {
      final found = counts();
      expect(
        [found.guide, found.header, found.enumerated],
        everyElement(found.sections),
        reason:
            'doc/scheduling.md enumerates what '
            'test/scheduling_cluster_test.dart asks, and the suite header '
            'counts the same thing a third time. Adding a GAP section without '
            'touching the other two is how the guide came to advertise three '
            'questions for a suite that asked five — and the two it dropped '
            'included the group substantiating the module\'s central safety '
            'claim, so a reader auditing "what happens when the roll call '
            'breaks" was told it was uncovered when it was the best-covered '
            'claim in the unit.',
      );
    });

    test('the sections are numbered as the guide numbers them', () {
      // Contiguous from one, because the guide's list is, and because a
      // duplicated or skipped GAP number would keep the totals agreeing while
      // making the two enumerations impossible to read side by side.
      final suite = File('test/scheduling_cluster_test.dart').readAsLinesSync();
      final numbered = [
        for (final line in suite)
          if (RegExp(r'^\s*// GAP (\d+) —').firstMatch(line) case final m?)
            int.parse(m.group(1)!),
      ];
      expect(numbered, List.generate(numbered.length, (index) => index + 1));
    });

    test('each side is read, not merely found to be absent', () {
      // Every assertion above is an equality, and `-1 == -1` would satisfy one
      // of them: a regex that stopped matching on both sides would report
      // agreement between two numbers neither of which was read. Pin the
      // values, so the check fails when the shapes change rather than passing
      // vacuously.
      final found = counts();
      expect(found.sections, greaterThan(1));
      expect(found.guide, isNot(-1), reason: 'the guide still counts in words');
      expect(
        found.header,
        isNot(-1),
        reason: 'the suite header still opens with its count',
      );
      expect(found.enumerated, found.sections);
    });
  });

  group('every module has a suite that carries its name', () {
    // A filename is the only thing an inventory can read without running
    // anything, so it is what every coverage sweep over this package reads —
    // `_moduleSuites` above among them. A module with no name-matched file is
    // therefore reported as untested no matter how well tested it is, and the
    // report is not obviously wrong to anyone reading it.
    //
    // `resources` was in exactly that state: twenty-nine passing tests, all of
    // them filed inside `email_service_test.dart` under a header describing the
    // messaging module. The scan said "no tests found" and was believed.
    //
    // The quieter cost is what makes this worth a standing check rather than a
    // one-off move. Tests that live under another module's name are carried off
    // by any change to *that* module — a rewrite, a split, a deletion — and
    // nothing about the two modules' relationship makes that visibly wrong to
    // whoever is doing it. The loss would be silent in both directions: the
    // suite that vanished was never counted, so no total drops.

    for (final module in _modules()) {
      test(
        module,
        () {
          expect(
            _moduleSuites(module),
            isNotEmpty,
            reason:
                'No `$module*_test.dart` exists, so every inventory that '
                'matches on the name reports this module as untested — and '
                'whatever does cover it is filed under some other module\'s '
                'name, where an edit to that module can carry it off '
                'unnoticed. Name a suite after the module.',
          );
        },
        skip: _suiteNamingPending.contains(module)
            ? 'no name-matched suite yet.'
            : null,
      );
    }

    test('every quarantined module is still unnamed', () {
      final settled = [
        for (final module in _suiteNamingPending)
          if (_moduleSuites(module).isNotEmpty) module,
      ];
      expect(
        settled,
        isEmpty,
        reason:
            'a quarantine entry with nothing left to suppress turns a passing '
            'module back into an unchecked one; drop it from the set',
      );
    });
  });

  group('every class section names the members its class declares', () {
    for (final module in _modules()) {
      test(module, () {
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
      });
    }

    // Every module passes, so there is no quarantine. Its last entry was
    // `authentication`, and what it held open is worth keeping in view: two of
    // the three classes were persisted entities whose sections listed their
    // *column* names and not their *field* names. `principal_id` and
    // `pkce_verifier` are what the table holds; `principalId` and
    // `pkceVerifier` are what a caller writes, and only the second kind is a
    // member. A section can therefore look like a complete account of a row
    // while naming none of the identifiers a reader came for — which is why
    // this check reads declarations rather than trusting a list to be one.

    test('the one documented toString survives a consistency pass', () {
      // `_universalMembers` exempts `toString` from being demanded, and thirty-
      // five classes in this package override it without a row. `TomTextLocale`
      // carries one anyway: its `toString` returns the tag, the tag is the
      // bundle key, and so `'$locale'` in a log line or an exception message
      // names the exact key that was looked up. That is a fact about the value
      // rather than about the member, and there is no way to have it without
      // reading the source — which is precisely what a summary is for.
      //
      // Pinned rather than left to the prose, because the exemption reads as an
      // absolute and the row reads as an inconsistency. Somebody reconciling the
      // summaries against `_universalMembers` would delete it in good faith, and
      // the argument for keeping it would not be in the diff they were reading.
      expect(
        _summary('resources'),
        contains('| `toString` | `String toString()` |'),
        reason:
            'api_summary_resources.md must keep the `toString` row on '
            '`TomTextLocale`. It is not an oversight left over from a sweep: '
            'the value is the bundle key, so a reader who assumes the default '
            "rendering either spells `.tag` at every interpolation or stops "
            'interpolating and loses the diagnostic.',
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

  group('every constructor listing names every parameter it takes', () {
    for (final module in _modules()) {
      test(module, () {
        final underListed = _underListedConstructorsOf(module);
        expect(
          underListed,
          isEmpty,
          reason:
              'these constructor listings in '
              'doc/api_reference/api_summary_$module.md name fewer parameters '
              'than the constructor declares: ${underListed.join('; ')}. A '
              'signature is the one part of a summary a reader copies rather '
              'than reads, so an omitted parameter is not a thin description — '
              'it is a parameter the reader will not know exists.',
        );
      });
    }

    test('a parameter that is not also a member is still checked', () {
      // The reason this group exists rather than leaning on the member sweep.
      // `TomOAuthException` forwards to its supertype with `super.stack`: a
      // real parameter of the constructor, a member of no class, and therefore
      // invisible to every check that reads a member list.
      final oauth = _declarations['TomOAuthException']!;
      expect(
        oauth.constructorParameters['']!.map((parameter) => parameter.name),
        contains('stack'),
      );
      expect(oauth.members, isNot(contains('stack')));
    });

    test('the sweep is reading the listings it claims to check', () {
      // Each assertion above passes when nothing is parsed, so the parse is
      // what has to be pinned — on both sides, because a listing compared
      // against a constructor that was never read is also vacuously complete.
      final listings = _classSections
          .expand((section) => section.constructors)
          .length;
      expect(
        listings,
        greaterThan(200),
        reason:
            'the summaries list two hundred-odd constructors; if this drops, '
            'the checks above are asserting that nothing is missing from '
            'nothing',
      );
      expect(
        _declarations.values.where((d) => d.constructorParameters.isNotEmpty),
        hasLength(greaterThan(250)),
      );

      // The class this guard was written for, read end to end: the wrapped
      // parameter list, the named group, and the parameter that started it.
      expect(
        _declarations['TomMethodMetadata']!.constructorParameters['']!.map(
          (parameter) => parameter.name,
        ),
        [
          'endpoint',
          'methodMirror',
          'access',
          'transactionInfo',
          'audited',
          'webSocket',
          'apiEndpointImplementation',
          'apiImplementation',
          'api',
          'apiEndpoint',
        ],
      );
      final metadata = _classSections.singleWhere(
        (section) => section.type == 'TomMethodMetadata',
      );
      expect(
        metadata.constructors.single.parameters.map(
          (parameter) => parameter.name,
        ),
        contains('audited'),
      );
    });

    test('a listing is measured the way the summaries write one', () {
      final sections = _classSectionsOf('synthetic.md', [
        '### TomOperator',
        '',
        '#### Constructors',
        '',
        '```dart',
        'const TomOperator.column(',
        '  String name, {',
        // A function-typed parameter closes a parenthesis that is not the
        // list's own; a default value holds a comma inside type arguments.
        '  void Function(Object error) onFailure,',
        '  Map<String, int> seeds = const {},',
        '})',
        '```',
        '',
        '#### Methods',
        '',
        '```dart',
        // Under a non-constructor heading the same shape is an example call,
        // not a signature — reading it would compare the class against its own
        // sample arguments.
        'TomOperator.column("id", onFailure: report)',
        '```',
      ]);

      final listing = sections.single.constructors.single;
      expect(listing.name, 'column');
      expect(listing.parameters, [
        (name: 'name', type: 'String', forwarding: null),
        (
          name: 'onFailure',
          type: 'void Function(Object error)',
          forwarding: null,
        ),
        (name: 'seeds', type: 'Map<String, int>', forwarding: null),
      ]);
    });
  });

  group('a summary that refers the reader elsewhere refers them somewhere', () {
    test('every referral resolves in the summary it names', () {
      final dangling = _danglingReferrals();
      expect(
        dangling,
        isEmpty,
        reason:
            'these referrals name a summary that documents nothing of the '
            'kind: ${dangling.join('; ')}. A sentence sending the reader to '
            'another document is a promise about that document, and the reader '
            'finds out it was wrong only after opening it.',
      );
    });

    test('the sweep reads the referrals it claims to', () {
      // The corpus refers across summaries in exactly two places, and both are
      // about file transfer — the one feature split across three tiers. A
      // check over two paragraphs is worth having *because* of that: those two
      // paragraphs were both broken at once, and the type one of them names is
      // in the published signature of `TomFileSlots.register`.
      final referrals = _summaryParagraphs();
      expect(referrals, hasLength(greaterThanOrEqualTo(2)));
      expect(
        referrals.expand((referral) => referral.names),
        containsAll(<String>[
          'TomBlobStore',
          'TomFileRepository',
          'TomFileReference',
          'TomFileService',
          'TomFileSlots',
        ]),
      );
      expect(
        _documentedByFile['api_summary_object_persistence.md'],
        containsAll(<String>['TomFileRepository', 'TomFileReference']),
      );
    });

    test(
      'a referral to a summary that does not document the name is reported',
      () {
        expect(
          _referralsIn('synthetic.md', const [
            'The row-side contract (`TomFileRepository`) belongs to',
            '[File Storage](api_summary_file_storage.md).',
          ]).single.targets,
          {'api_summary_file_storage.md'},
        );
        // The same paragraph, judged: file storage documents no
        // `TomFileRepository`, so a referral pointing there resolves nowhere.
        expect(
          (_documentedByFile['api_summary_file_storage.md'] ??
              const <String>{}),
          isNot(contains('TomFileRepository')),
        );
      },
    );

    test('a paragraph with two destinations is judged against both', () {
      // The corpus's own idiom, and the reason the rule is "here or in one of
      // the summaries this paragraph links to" rather than "in all of them".
      final referral = _referralsIn('synthetic.md', const [
        'The bytes live in a `TomBlobStore` — see',
        '[File Storage](api_summary_file_storage.md) — and the row-side',
        'contract (`TomFileRepository`) belongs to',
        '[Object Persistence](api_summary_object_persistence.md).',
      ]).single;
      expect(referral.targets, hasLength(2));
      expect(referral.names, ['TomBlobStore', 'TomFileRepository']);
      for (final name in referral.names) {
        expect(
          referral.targets.any(
            (target) => _documentedByFile[target]!.contains(name),
          ),
          isTrue,
          reason: '$name is documented in one of the two, which is the test',
        );
      }
    });

    test('a contents list and a table are not referrals', () {
      // Both are full of links and neither promises anything about where a
      // type is described: the contents list *is* the map, and a table row is
      // an inventory its own checks already hold to the source.
      expect(
        _referralsIn('synthetic.md', const [
          '- [Endpoints](api_summary_endpoints.md)',
          '| `TomFileSlots` | see [Endpoints](api_summary_endpoints.md) | . |',
        ]),
        isEmpty,
      );
    });

    test('a fenced block is not a referral', () {
      expect(
        _referralsIn('synthetic.md', const [
          '```dart',
          '// see [Endpoints](api_summary_endpoints.md) for `TomFileSlots`',
          '```',
        ]),
        isEmpty,
      );
    });
  });

  group('every documented signature types its parameters as the source does', () {
    for (final module in _modules()) {
      test(module, () {
        final mistyped = _mistypedParametersOf(module);
        expect(
          mistyped,
          isEmpty,
          reason:
              'these signatures in doc/api_reference/api_summary_$module.md '
              'give a parameter a type the source does not: '
              '${mistyped.join('; ')}. A signature is copied rather than read, '
              'and a type copied wider than the declared one does not compile — '
              'the reader finds that out from the analyzer, not from the '
              'summary.',
        );
      });
    }

    test('a super-forwarded parameter resolves through the kernel', () {
      // The case the group exists for. Every exception in this package writes
      // `super.stack` and states no type; the type is `TomException`'s, three
      // packages' worth of `extends` away, and until it is resolved a summary
      // can render the parameter as anything at all.
      expect(
        _declarationOf('TomDeliveryException')!.constructorParameters['']!
            .firstWhere((parameter) => parameter.name == 'stack'),
        (name: 'stack', type: null, forwarding: 'super'),
      );
      expect(
        _declaredParameterType('TomDeliveryException', '', 'stack'),
        'StackTrace?',
      );
      expect(
        _declaredParameterType('TomPermanentDeliveryException', '', 'stack'),
        'StackTrace?',
      );
    });

    test('a this-forwarded parameter resolves to the field it names', () {
      expect(_declarationOf('TomCacheEntry')!.fieldTypes['value'], 'Object');
      expect(_declaredParameterType('TomCacheEntry', '', 'value'), 'Object');
    });

    test('a static factory in a member table is read as a signature', () {
      // The two `TomDeliveryException` factories have no constructor block to
      // live in — they are rows under `Static Methods` — so a check that read
      // only fenced listings could never see them.
      final section = _classSections.singleWhere(
        (section) =>
            section.file == 'api_summary_messaging.md' &&
            section.type == 'TomDeliveryException',
      );
      final row = section.rows.singleWhere((row) => row.member == 'permanent');
      expect(
        _signatureParameters(row).map((parameter) => parameter.name),
        containsAll(<String>['key', 'message', 'statusCode', 'stack']),
      );
      expect(
        _declaredParameterType(
          'TomDeliveryException',
          'permanent',
          'stack',
          constructor: false,
        ),
        'StackTrace?',
      );
    });

    test('a type cell holds no parameters and is not read as a signature', () {
      // A `Properties` row's second cell is a type, not a declaration, and the
      // member name does not appear in it at all.
      expect(
        _signatureParameters((
          line: 1,
          member: 'value',
          signature: 'Map<String, Object?>?',
        )),
        isEmpty,
      );
    });

    test('the kernel source the resolver depends on is present', () {
      // Without it every `super.`-forwarded parameter resolves to null and is
      // skipped, which is most of what this group exists to read: the twenty
      // constructor listings that widened `stack` are all `super.stack`, and a
      // parameter that resolves to nothing is compared against nothing. The
      // half that survives is the parameters the source types outright. So the
      // sentinel is what makes the silence audible.
      expect(
        Directory('../tom_core_kernel/lib/src/tombase').existsSync(),
        isTrue,
        reason:
            'the sibling package is where an inherited parameter is finally '
            'declared; without it this group is silently empty',
      );
      expect(_kernelDeclarations, contains('TomException'));
    });

    test('a parameter modifier is not read as part of the type', () {
      expect(
        _parameters('{required StackTrace? stack, covariant int retries = 3}'),
        [
          (name: 'stack', type: 'StackTrace?', forwarding: null),
          (name: 'retries', type: 'int', forwarding: null),
        ],
      );
    });

    test('a listing that widens an inherited parameter is reported', () {
      // The defect this group was written for, planted: the type of the field
      // `stack` eventually reaches is `Object?`, so writing the *field's* type
      // where the *constructor's* belongs is the mistake a careful author
      // makes. It does not compile at the call site and nothing else says so.
      expect(
        _mistypedParametersIn(
          _classSectionsOf('synthetic.md', [
            '### TomTransientDeliveryException',
            '',
            '#### Constructors',
            '',
            '```dart',
            'TomTransientDeliveryException(String key, String defaultUserMessage,',
            '    {int? statusCode, Object? stack})',
            '```',
          ]),
        ),
        [
          'synthetic.md:6 TomTransientDeliveryException types stack as '
              'Object?, declared StackTrace?',
        ],
      );
    });

    test('a listing that narrows a parameter is reported too', () {
      // The check is not a nullability check. A summary that drops the `?` is
      // as uncopyable as one that adds it — the caller passes null and the
      // analyzer, not the summary, explains why that was never allowed.
      expect(
        _mistypedParametersIn(
          _classSectionsOf('synthetic.md', [
            '### TomTransientDeliveryException',
            '',
            '#### Constructors',
            '',
            '```dart',
            'TomTransientDeliveryException(String key, String defaultUserMessage,',
            '    {int statusCode})',
            '```',
          ]),
        ),
        [
          'synthetic.md:6 TomTransientDeliveryException types statusCode as '
              'int, declared int?',
        ],
      );
    });

    test('a member row that mistypes a parameter is reported', () {
      expect(
        _mistypedParametersIn(
          _classSectionsOf('synthetic.md', [
            '### TomDeliveryException',
            '',
            '#### Static Methods',
            '',
            '| Method | Signature | Description |',
            '| ------ | --------- | ----------- |',
            '| `permanent` | `static TomPermanentDeliveryException '
                'permanent(String key, String message, {Object? stack})` | . |',
          ]),
        ),
        [
          'synthetic.md:7 TomDeliveryException.permanent types stack as '
              'Object?, declared StackTrace?',
        ],
      );
    });

    test('a listing agreeing with the source is reported by neither', () {
      // Both directions, or the two tests above pass on a census that reports
      // everything.
      expect(
        _mistypedParametersIn(
          _classSectionsOf('synthetic.md', [
            '### TomTransientDeliveryException',
            '',
            '#### Constructors',
            '',
            '```dart',
            'TomTransientDeliveryException(String key, String defaultUserMessage,',
            '    {int? statusCode, StackTrace? stack})',
            '```',
          ]),
        ),
        isEmpty,
      );
    });

    test('an inherited type parameter is left to the summary', () {
      // `TomStringConfig extends TomConfig<String>` forwards `super.value` to
      // `TomConfig.withDefault(String key, T value)`. The summary writes
      // `String`, which is right and is not what the source says; substituting
      // the argument needs a real element model. So the parameter resolves to
      // nothing and is skipped — the alternative being four false reports in
      // `configuration` alone.
      expect(_declarationOf('TomConfig')!.typeParameters, contains('T'));
      expect(
        _declarationOf('TomConfig')!.constructorParameters['withDefault'],
        contains((name: 'value', type: 'T', forwarding: null)),
      );
      expect(
        _declaredParameterType('TomStringConfig', 'withDefault', 'value'),
        isNull,
      );
    });

    test('a function-typed parameter keeps its whole type', () {
      expect(_parameters('void Function(Object error) onFailure').single, (
        name: 'onFailure',
        type: 'void Function(Object error)',
        forwarding: null,
      ));
    });
  });

  group('no documented entity declares an unsavable surrogate key', () {
    test('every `@TomEntityId` field in the documents is insertable', () {
      final broken = _documentedEntityKeys()
          .where((key) => key.initialiser == '0' || key.initialiser == '0.0')
          .toList();
      expect(
        broken,
        isEmpty,
        reason:
            'these documented entities declare a non-nullable numeric primary '
            'key initialised to zero, which `isUnsavedKey` does not treat as '
            'unsaved — the first save() issues an UPDATE that matches no row '
            'and persists nothing:\n'
            '${broken.map((k) => '  ${k.file}:${k.line}  ${k.declaration}').join('\n')}\n'
            'Declare `int? id;`, or `int id = -1;` for a non-nullable key.',
      );
    });

    test('the sweep found the entity declarations it claims to check', () {
      // The finding above is an emptiness assertion, so a sweep whose parser
      // stopped recovering declarations would pass by reading nothing. The
      // documents that map an entity are few and named, so this pins the count
      // being non-zero rather than the exact figure — a new guide that maps an
      // entity should not have to edit a number here.
      final keys = _documentedEntityKeys();
      expect(keys, isNotEmpty, reason: 'no `@TomEntityId` fields were found');
      expect(
        keys.map((k) => k.file).toSet(),
        contains('lib/src/tomserver/object_persistence/readme.md'),
        reason:
            'the module readme quick start is the shortest thing a newcomer '
            'reads and the one they copy — it is the declaration this guard '
            'exists for, and the sweep must be reaching it',
      );
    });

    test('the parser reads the shapes the documents actually write', () {
      // Each rule below decides whether a declaration is reported, so getting
      // one wrong either hides a real defect or fails a correct document.
      List<String?> initialisersOf(List<String> lines) => _entityKeysOf(
        'synthetic.md',
        lines,
      ).map((k) => k.initialiser).toList();

      expect(
        initialisersOf([
          '```dart',
          '  @TomEntityId()',
          "  @TomDbColumn(columnName: 'id')",
          '  int id = 0;',
          '```',
        ]),
        ['0'],
      );
      // A nullable key is never reported, whatever it is initialised to.
      expect(
        initialisersOf(['```dart', '  @TomEntityId()', '  int? id;', '```']),
        [null],
      );
      // Annotations and declaration on one line — `doc/object_persistence.md`
      // writes its scope example that way.
      expect(
        initialisersOf([
          '```dart',
          "  @TomEntityId() @TomDbColumn(columnName: 'id') int? id;",
          '```',
        ]),
        [null],
      );
      // Type arguments carry a comma and the argument list a nested paren;
      // neither may end the annotation early.
      expect(
        initialisersOf([
          '```dart',
          '  @TomEntityId()',
          '  @TomDbColumn<int, TomDbInt>(columnName: \'id\', isReadOnly: true)',
          '  int id = -1;',
          '```',
        ]),
        ['-1'],
      );
      // A key the constructor assigns has no initialiser to judge.
      expect(
        initialisersOf(['```dart', '  @TomEntityId()', '  int id;', '```']),
        [null],
      );
      // Outside a Dart fence the same text is prose about the annotation.
      expect(
        initialisersOf(['`@TomEntityId()` marks it.', '  int id = 0;']),
        isEmpty,
      );
      // A non-numeric key is a natural key, not a surrogate: `isUnsavedKey`
      // never calls one unsaved, so zero-versus-negative does not arise and a
      // string default is not evidence of this defect.
      expect(
        initialisersOf([
          '```dart',
          '  @TomEntityId()',
          "  String code = '';",
          '```',
        ]),
        isEmpty,
      );
    });
  });

  // `start()` logs the deployment in before it binds anything, and that order
  // is a security property rather than a preference: the server principal caps
  // every user's grant at `min(user, server)`, so a socket bound first would
  // serve requests uncapped for as long as the login took — the one direction
  // in which getting it wrong grants access rather than denying it. Two things
  // can rot. The order can be lost in an edit to `start()`, silently, because
  // nothing fails; and the documents can go on describing `start()` as though
  // binding were all it did, which is what left a reader who hit a failed login
  // with an unhandled asynchronous error at boot and nothing to search for.
  group('start() logs the deployment in before it binds', () {
    const source = 'lib/src/tomserver/server/server.dart';

    _StartSteps shipped() => _startStepsOf(File(source).readAsLinesSync());

    test('the self-login precedes the bind in source', () {
      final steps = shipped();
      expect(
        steps.loginLine,
        isNotNull,
        reason: '`start()` no longer performs the server self-login',
      );
      expect(
        steps.bindLine,
        isNotNull,
        reason: '`start()` no longer binds a socket',
      );
      expect(
        steps.loginLine!,
        lessThan(steps.bindLine!),
        reason:
            '`start()` binds the socket before installing the server principal, '
            'so requests arriving during the login are served with user grants '
            'uncapped',
      );
    });

    test('every server mirror says start() logs the deployment in', () {
      expect(_selfLoginComplaints(_shippedMirrorLines()), isEmpty);
    });

    test('every server mirror says a failed login binds nothing', () {
      // The capability alone is not the caller-visible part. What a reader
      // needs is that this is the one thing that can stop `start()`, and that
      // it stops it *silently* as far as the call site is concerned, because
      // `start()` returns nothing to hold a rejected future.
      expect(_failedLoginComplaints(_shippedMirrorLines()), isEmpty);
    });

    test('the parser found the steps it claims to order', () {
      // Both mirror findings are emptiness assertions and the ordering check
      // reads two line numbers: a parser that lost `start()` would report no
      // login, no bind, and nothing out of order.
      final steps = shipped();
      expect(steps.loginLine, isNotNull);
      expect(steps.bindLine, isNotNull);
      expect(steps.body, isNotEmpty);
      expect(_requestScopeMirrors, hasLength(3));
      // The body ends at `start()`'s closing brace: the same file declares
      // `_installServerPrincipal` further down, and a scan that ran to the end
      // of the class would find its `loginAndInstall` call and call the order
      // correct however `start()` had been rewritten.
      expect(
        steps.body.any((line) => line.contains('_installServerPrincipal()')),
        isTrue,
      );
      expect(
        steps.body.any((line) => line.contains('Future<void>')),
        isFalse,
        reason:
            'the body ran past the end of `start()` into the private methods '
            'below it',
      );
    });

    test('a start() that binds before logging in is reported', () {
      // The mutation the ordering exists to catch: both calls still present,
      // both still in `start()`, only their order swapped. Nothing about such a
      // server fails to compile or fails a functional test.
      final swapped = _startStepsOf(const [
        '  void start() async {',
        '    HttpServer server = await serve(handler, ip, port);',
        '    await _installServerPrincipal();',
        '  }',
      ]);
      expect(swapped.loginLine, greaterThan(swapped.bindLine!));
    });

    test('a mirror silent about the login or the abort is reported', () {
      const silent = {
        'silent.md': ['`start()` binds the socket and begins listening.'],
      };
      expect(_selfLoginComplaints(silent), [contains('silent.md')]);
      expect(_failedLoginComplaints(silent), [contains('silent.md')]);
      // Naming the login without naming what a failure costs is the halfway
      // state a partial edit lands in, and it is the half that leaves the
      // boot-time error unexplained — so it must still be reported.
      const halfway = {
        'halfway.md': ['`start()` calls TomServerSelfLogin, then binds.'],
      };
      expect(_selfLoginComplaints(halfway), isEmpty);
      expect(_failedLoginComplaints(halfway), [contains('halfway.md')]);
    });
  });

  // `TomServer.securityContext` was documented as holding the TLS context and
  // was never assigned: `start()` declared a local of the same name and built
  // the context into that. The field read `null` for the life of the server,
  // and the API summary mirrored the dartdoc's claim faithfully — the summary
  // had been checked against the dartdoc, and the dartdoc was what lied.
  //
  // Shadowing is what makes this class of defect invisible. A dead field with
  // no same-named local is easy to notice, because nothing anywhere writes it;
  // a shadowed one reads as thoroughly used, since the assignment is right
  // there in the method the dartdoc points at. That is also why the two checks
  // below are ordered rather than independent: `every field is assigned` cannot
  // tell an assignment to the field from an assignment to a local wearing its
  // name, so it is only worth anything while `no local shadows a field` holds.
  group('a field TomServer documents is a field TomServer assigns', () {
    const source = 'lib/src/tomserver/server/server.dart';

    _ServerFields shipped() =>
        _tomServerFieldsOf(File(source).readAsLinesSync());

    test('no local shadows a TomServer field', () {
      expect(_shadowedFieldComplaints(shipped()), isEmpty);
    });

    test('every TomServer field is assigned somewhere in the class', () {
      expect(_unassignedFieldComplaints(shipped()), isEmpty);
    });

    test('the parser found the fields it claims to check', () {
      // Both findings are emptiness assertions, so a parser that matched no
      // field at all would report a clean class. Pin the roster: these are
      // every instance field `TomServer` declares, and the set is small enough
      // that naming it costs less than the vacuity it removes.
      expect(shipped().names, [
        'configuration',
        'securityContext',
        'router',
        'errorHandler',
        'authenticationErrorHandler',
        'loggingMiddleware',
      ]);
      // Methods are declarations at the same indentation as fields; a parser
      // that took them for fields would then look for assignments to `start`.
      expect(shipped().names, isNot(contains('start')));
    });

    test('a local shadowing a field is reported', () {
      // The mutation is the defect verbatim: the field still declared, still
      // documented, and a local of the same name built inside the method the
      // dartdoc credits with building it.
      final shadowed = _tomServerFieldsOf(const [
        'class TomServer {',
        '  SecurityContext? securityContext;',
        '',
        '  void start() async {',
        '    SecurityContext? securityContext;',
        '    securityContext = SecurityContext();',
        '  }',
        '}',
      ]);
      expect(shadowed.names, ['securityContext']);
      expect(_shadowedFieldComplaints(shadowed), [contains('securityContext')]);
      // And the point of ordering the two checks: the shadowed class passes
      // the assignment check, because the local's assignment is indis-
      // tinguishable from the field's. Only the shadowing check sees it.
      expect(_unassignedFieldComplaints(shadowed), isEmpty);
    });

    test('a field nothing assigns is reported', () {
      final dead = _tomServerFieldsOf(const [
        'class TomServer {',
        '  Router? router;',
        '',
        '  void start() async {',
        '    doSomethingElse();',
        '  }',
        '}',
      ]);
      expect(_unassignedFieldComplaints(dead), [contains('router')]);
      // A field initialised where it is declared counts as assigned; several
      // of the real ones are, and a check that called those dead would be
      // reported around rather than fixed.
      final initialised = _tomServerFieldsOf(const [
        'class TomServer {',
        '  bool ready = false;',
        '}',
      ]);
      expect(_unassignedFieldComplaints(initialised), isEmpty);
      // As does one the constructor takes as `this.x`, which is the only way
      // `configuration` is ever written.
      final promoted = _tomServerFieldsOf(const [
        'class TomServer {',
        '  TomBaseServerConfiguration configuration;',
        '',
        '  TomServer(this.configuration) {',
        '    noop();',
        '  }',
        '}',
      ]);
      expect(_unassignedFieldComplaints(promoted), isEmpty);
    });
  });

  // `doc/server.md`'s "Not Yet Implemented" section named diagnostics,
  // monitoring and server-rendered forms as capabilities the module had not got
  // to yet, while the module's own record said the opposite — that there is no
  // diagnostics or monitoring surface here and forms are the endpoints
  // module's. That disagreement is not cosmetic, because the two readings
  // recommend opposite actions: wait for the framework to ship introspection,
  // or write it as an ordinary endpoint today.
  //
  // "Non-goal, not gap" is a judgement and no test can make it. So this group
  // pins the two facts the judgement rests on. A capability the guide disowns
  // has to leave no trace in the module — four placeholder files once suggested
  // otherwise, they were deleted, and nothing stops one coming back. And a
  // limitation the guide records has to still be the module's behaviour, so
  // that closing one turns this red instead of leaving the section advertising
  // a defect somebody already fixed.
  group("the server guide's Not Yet Implemented section matches the module", () {
    const guide = 'doc/server.md';
    const source = 'lib/src/tomserver/server/server.dart';
    const moduleDirectory = 'lib/src/tomserver/server';

    List<String> disowned() =>
        _disownedCapabilities(_sectionBody(guide, 'Not Yet Implemented'));

    _ServerLimitations shipped() =>
        _serverLimitationsOf(File(source).readAsLinesSync());

    List<String> moduleFiles() => [
      for (final entity in Directory(moduleDirectory).listSync())
        entity.path.split('/').last,
    ];

    test(
      'the guide disowns the capabilities this check knows how to look for',
      () {
        // Both findings below are emptiness assertions, so a parser that read
        // no bullet would pronounce the module clean. Pin the roster, and pin
        // that every bullet has a mapping — a fourth bullet with no entry in
        // `_capabilityFiles` is a bullet nothing checks, which is the failure
        // this group exists to prevent one level up.
        expect(disowned(), [
          'Diagnostics and monitoring',
          'Server-rendered forms',
          'WebSocket',
        ]);
        expect(_unmappedCapabilityComplaints(disowned()), isEmpty);
      },
    );

    test(
      'no file in the module is named for a capability the guide disowns',
      () {
        expect(_disownedFileComplaints(disowned(), moduleFiles()), isEmpty);
      },
    );

    test('every limitation the guide records is still the behaviour', () {
      final limitations = shipped();
      expect(
        limitations.defaultErrorHandlerAlwaysFails,
        isTrue,
        reason:
            'the guide says the default `errorHandler` answers 500 for '
            'everything; if it now chooses a status, say so there instead',
      );
      expect(
        limitations.logsBelowAuthentication,
        isTrue,
        reason:
            'the guide explains the missing access-log line by the logging '
            'middleware sitting below the authentication layer — move it above '
            'and the explanation is wrong as well as the limitation gone',
      );
      expect(
        limitations.startIsFireAndForget,
        isTrue,
        reason:
            'the guide says `start()` cannot be awaited and hands back no '
            'handle; a signature that returns one makes that paragraph stale',
      );
    });

    test('a module file matching a disowned capability is reported', () {
      // The mutation is the baseline verbatim: the placeholder file back, the
      // guide still disowning what it declares. It is worth checking because
      // this is the one direction the deletion did not make impossible.
      expect(
        _disownedFileComplaints(disowned(), const [
          'server.dart',
          'diagnostics.dart',
          'readme.md',
        ]),
        [contains('diagnostics.dart')],
      );
      // A file whose name merely contains a disowned word does not escape by
      // being longer, and one that shares no word does not get caught by being
      // near: `formatting.dart` is not `forms`.
      expect(
        _disownedFileComplaints(disowned(), const ['formatting.dart']),
        isEmpty,
      );
      expect(
        _disownedFileComplaints(disowned(), const ['websocket_upgrade.dart']),
        [contains('websocket_upgrade.dart')],
      );
    });

    test('a bullet the vocabulary does not know is reported', () {
      expect(_unmappedCapabilityComplaints(const ['Templating']), [
        contains('Templating'),
      ]);
    });

    test('a limitation the source has closed is reported', () {
      // Each of the three read independently, so a parser that answered
      // `false` to everything would pass the group above by accident. Feed it a
      // source in which all three are fixed and check it says so.
      final fixed = _serverLimitationsOf(const [
        'Response? Function(Request, Object, StackTrace) errorHandler =',
        '    (request, error, stacktrace) {',
        '      return Response(statusFor(error), body: body);',
        '    };',
        '',
        'Future<HttpServer> start() async {',
        '  final handler = Pipeline()',
        '      .addMiddleware(loggingMiddleware)',
        '      .addMiddleware(tomDefaultAuthenticationMiddleware())',
        '      .addHandler(routerHandler);',
        '  return await serve(handler, ip, port);',
        '}',
        '',
        '(TomPrincipal?, TomClientJwtToken?) '
            'extractAuthentication(Request r) {',
        '  return (principalOf(r), tokenOf(r));',
        '}',
      ]);
      expect(fixed.defaultErrorHandlerAlwaysFails, isFalse);
      expect(fixed.logsBelowAuthentication, isFalse);
      expect(fixed.startIsFireAndForget, isFalse);
    });
  });

  // The authentication middleware is where a request acquires everything the
  // code beneath it reads from the ambient zone rather than from an argument.
  // Three documents mirror that list, and a mirror that drifts from it is worse
  // than silence: a reader who replaces the middleware on the strength of an
  // incomplete list gets no compile error, only repository code quietly sharing
  // one isolate's transaction between concurrent requests.
  group('the request scope the middleware opens is the one documented', () {
    const source = 'lib/src/tomserver/server/server.dart';
    const guide = 'doc/server.md';
    const section = 'Request Context and Zone Values';

    _RequestScope shipped() => _requestScopeOf(File(source).readAsLinesSync());

    Map<String, List<String>> shippedMirrors() => {
      for (final mirror in _requestScopeMirrors)
        mirror: File(mirror).readAsLinesSync(),
    };

    test('every zone value the middleware publishes is named in the guide', () {
      final body = _sectionBody(guide, section).join('\n');
      final missing = [
        for (final type in shipped().zoneValueTypes)
          if (!RegExp('\\b$type\\b').hasMatch(body)) type,
      ];
      expect(
        missing,
        isEmpty,
        reason:
            'the "$section" section of `$guide` enumerates what a request '
            'carries, and these are established by `$source` without appearing '
            'in it: ${missing.join(', ')}',
      );
    });

    test('all three mirrors agree with source about the transaction scope', () {
      expect(_transactionScopeComplaints(shipped(), shippedMirrors()), isEmpty);
    });

    test('the parser found what it claims to read', () {
      // Both findings above pass vacuously on a parser that recovered nothing:
      // an empty type list has no missing member, and a scope that looks
      // wrapper-less agrees with three documents that never mention one.
      final scope = shipped();
      expect(
        scope.opensTransactionScope,
        isTrue,
        reason:
            'the middleware must keep wrapping the request in '
            '`TomTransactionManager.runInTransactionScope` — without it two '
            'requests interleaving in one isolate share a current transaction',
      );
      expect(
        scope.zoneValueTypes,
        containsAll(<String>['Request', 'TomPrincipal', 'TomRequestId']),
        reason: 'the `TomZoneValues` literal in `$source` was not read',
      );
      expect(
        _sectionBody(guide, section),
        isNotEmpty,
        reason: '`$guide` has no "$section" section to check against',
      );
      expect(_requestScopeMirrors, hasLength(3));
    });

    test('a mirror claiming a scope the middleware dropped is reported', () {
      final withoutWrapper = [
        for (final line in File(source).readAsLinesSync())
          if (!line.contains('TomTransactionManager.runInTransactionScope'))
            line,
      ];
      final scope = _requestScopeOf(withoutWrapper);
      expect(scope.opensTransactionScope, isFalse);
      // All three, because all three now say so — the point of the guard is
      // that removing the wrapper cannot leave the documents quietly wrong.
      expect(
        _transactionScopeComplaints(scope, shippedMirrors()),
        hasLength(3),
      );
    });

    test('a mirror omitting a scope the middleware opens is reported', () {
      expect(
        _transactionScopeComplaints(shipped(), {
          'silent.md': const ['Each request runs in its own zone.'],
        }),
        [contains('silent.md')],
      );
    });

    test('the zone value parser reads the literal the source writes', () {
      // The literal's keys are types, its values arbitrary expressions, and the
      // line after it assigns the bundle into itself — a parser that took every
      // `X:` in sight would report `TomZoneValues` as a published value and a
      // map argument as a zone value.
      final scope = _requestScopeOf(const [
        '      TomZoneValues zoneValues = TomZoneValues({',
        '        Request: request,',
        '        TomPrincipal: principal,',
        '        TomRequestId: TomRequestId(),',
        '      });',
        '      zoneValues[TomZoneValues] = zoneValues;',
        '      return runZoned(zoneValues: zoneValues.zoneValues, body);',
      ]);
      expect(scope.zoneValueTypes, ['Request', 'TomPrincipal', 'TomRequestId']);
      expect(scope.opensTransactionScope, isFalse);
    });
  });

  // Shipped text is read by people with no access to the workspace that
  // produced it. A dartdoc reaches the IDE and the generated API pages; `doc/`
  // is the package's published documentation. Neither reader can resolve a todo
  // id, an internal bug number, or "the quest completion steps" — so a sentence
  // built on one does not merely fail to inform, it costs a lookup and then
  // leaves the reader unable to tell whether the thing is planned, abandoned,
  // or already done elsewhere. Saying nothing would have been better. An open
  // end is stated outright or not at all.
  group('a suite that defers coverage names where it went', () {
    // A suite header saying "this is not tested here" owes the reader the
    // place it *is*, and four of them owed a template instead: "covered by
    // `doc/<module>.md` and integration tests, not here". Neither clause
    // located anything. A document covers no code path, and this package has
    // no integration suite — no integration directory, no such file, and
    // `tool/run_db_tests.sh` only starts the database the `@Tags(['db'])`
    // suites in `test/` already need.
    //
    // The cost is specific: coverage nobody can find is written a second time
    // by whoever adds the next assertion, and deleted by whoever reads its
    // group name as another module's.
    //
    // This is a phrase check and is worth being honest about. It cannot tell a
    // true pointer from a false one — only that the one phrase four headers
    // reached for is gone. Naming the covering file and its *group* is what
    // makes a pointer checkable by a reader, and no rule over the corpus can
    // enforce it: a backticked span in a comment means "a literal token", not
    // "a group name". Measured over `test/`, of 150 multi-word backticked
    // spans only nine name a group, and restricting to paragraphs that also
    // name a suite leaves 26 with 19 still not group names. A guard on that
    // would need a list of exempt phrases, which is the quarantine this
    // repository refuses elsewhere.
    final claim = RegExp(r'\bintegration tests?\b', caseSensitive: false);

    test('no test comment claims a suite this package does not have', () {
      final offenders = <String>[
        for (final path in _testSources())
          for (final hit in _flattenedLines(
            path,
          ).where((line) => claim.hasMatch(line.text)))
            '  $path:${hit.line}  ${hit.text.trim()}',
      ];
      expect(
        offenders,
        isEmpty,
        reason:
            'these comments defer coverage to an integration suite that does '
            'not exist:\n${offenders.join('\n')}\n'
            'Name the suite and group that does cover it, or — when the '
            'coverage really is outside this package — the sample script, as '
            '`test/server_test.dart` names '
            '`core_server_sample/tool/run_integration.sh`.',
      );
    });

    test('the sweep reads the test sources', () {
      // An emptiness check over a lister that found nothing reports a clean
      // package. Pinned by shape, not by count.
      expect(_testSources(), isNotEmpty);
      expect(_testSources(), contains('test/server_test.dart'));
      expect(
        _testSources(),
        isNot(contains('test/fixtures/reflection_fixture.reflection.dart')),
        reason: 'a generated artifact carries no prose to read',
      );

      // The one exclusion, still one. Every other suite in the package is
      // read, so the rule cannot be escaped by moving a claim next door.
      final all = [
        for (final entry in Directory('test').listSync(recursive: true))
          if (entry is File &&
              entry.path.endsWith('.dart') &&
              !entry.path.endsWith('.reflection.dart'))
            entry.path,
      ];
      expect(all.length - _testSources().length, 1);
      expect(_testSources(), isNot(contains(_selfExcludedSuite)));
    });

    test('a claim is found however it happens to wrap', () {
      // The original spanned three lines. Reflowed prose that still says the
      // same thing must still be reported, which is why the paragraphs are
      // flattened before matching rather than the lines matched one by one.
      final wrapped = _flattenLines([
        '/// so the listen path is covered by `doc/server.md` and',
        '/// integration tests, not here.',
      ]);
      expect(wrapped.any((line) => claim.hasMatch(line.text)), isTrue);
    });
  });

  group('shipped text stands on its own', () {
    final markers = <String, RegExp>{
      'quest references': RegExp(r'\bquests?\b', caseSensitive: false),
      'completion-steps pointers': RegExp(
        r'completion (steps|document)',
        caseSensitive: false,
      ),
      // Every prefix the quest that wrote this package has issued todos under.
      // A marker that names its own vocabulary is only as good as that list: a
      // prefix missing from it makes every sentence built on an id of that
      // shape invisible to this group, and the group stays green throughout. So
      // the list is widened whenever the vocabulary grows.
      'todo ids': RegExp(r'\b(tc(inc|open)b?|csexd)\d+', caseSensitive: false),
      // The whole build-plan vocabulary alongside the bug-list form, not just
      // the kernel plan's prefix: a prefix missing from this alternation makes
      // every id of that shape invisible, which is the same hole the todo-id
      // marker guards against one line above. The guideline, testkit and
      // concept prefixes are excluded on purpose — they index the framework's
      // published vocabularies, not a work item.
      'internal bug numbers': RegExp(
        r'\bbug\s+§|\b(RC[BCK]?\d+|RC-\d+|D-(?:RC)?[A-Z]?\d+)\b',
      ),
      // The indefinite article is the tell: an unnamed follow-up cannot be
      // followed, and naming it would breach the rule above anyway. Both roads
      // lead to stating the current state instead.
      'unnamed follow-ups': RegExp(r'tracked follow-up'),
    };

    final surfaces = <String, List<String> Function()>{
      'the library sources': _libSources,
      'the example sources': _exampleSources,
      'the hand-written documents': _handWrittenDocuments,
    };

    surfaces.forEach((what, files) {
      markers.forEach((kind, marker) {
        test('$what carry no $kind', () {
          final offenders = <String>[
            for (final path in files())
              for (final hit in _flattenedLines(
                path,
              ).where((line) => marker.hasMatch(line.text)))
                '  $path:${hit.line}  ${hit.text.trim()}',
          ];
          expect(
            offenders,
            isEmpty,
            reason:
                'these lines carry $kind, which resolve only inside the '
                'workspace that wrote them:\n'
                '${offenders.join('\n')}\n'
                'State the current behaviour and its reason instead.',
          );
        });
      });
    });

    test('the sweep reaches every surface', () {
      // Every assertion above is an emptiness check, so a lister that stopped
      // finding files would report the package clean. Pinned by shape rather
      // than by count: a module added later must not have to edit a number.
      expect(_libSources(), isNotEmpty);
      expect(_exampleSources(), isNotEmpty);
      expect(_handWrittenDocuments(), isNotEmpty);
      expect(
        _libSources(),
        contains(
          'lib/src/tomserver/object_persistence/persistence_annotations.dart',
        ),
      );
      // Nested, because `example/` is a tree and a non-recursive listing would
      // find the top-level examples and quietly miss every module directory.
      expect(
        _exampleSources(),
        contains('example/scheduling/cluster/cluster_verify.dart'),
      );
      expect(_handWrittenDocuments(), contains('doc/object_persistence.md'));
    });

    test('a marker is found however the source happens to wrap it', () {
      // A defect merely reflowed across two lines would otherwise read as
      // fixed, and that is the failure mode that matters most here: these
      // phrases sit in prose, and prose gets rewrapped.
      final wrapped = _flattenLines([
        '/// The layer does not yet apply this annotation (see the',
        '/// quest completion steps).',
        '',
        '/// An unrelated sentence.',
      ]);
      expect(wrapped, hasLength(2));
      expect(
        wrapped.first.text,
        contains('see the quest completion steps'),
        reason: 'a continuation line must join the paragraph it belongs to',
      );
      expect(wrapped.first.line, 1, reason: 'reported at the paragraph start');
      // A dartdoc block is not separated from the declaration it documents by a
      // blank line, so the marker change is what ends it. Without that the
      // report would quote a whole class body and name nothing in particular.
      final documented = _flattenLines([
        '/// A note about the type.',
        'class Thing {',
        '  final int field = 0;',
      ]);
      expect(documented.map((p) => p.text), [
        'A note about the type.',
        'class Thing { final int field = 0;',
      ]);
      // `request` and `question` both contain "quest"; the word boundary is
      // what keeps this package's several hundred uses of them out of the
      // report.
      expect(
        markers['quest references']!.hasMatch('the request in question'),
        isFalse,
      );
    });

    // The other way a shipped comment can send a reader nowhere. The markers
    // above catch a pointer at something outside the package; this catches one
    // at something *inside* it that is not there — a `doc/…` path that has
    // been renamed, moved into a subdirectory, or never existed.
    //
    // It is the same defect one level up, and the reason it needs its own
    // check is that the failure is silent in both directions: nothing compiles
    // a path inside a comment, and a document is renamed by someone reading the
    // document, not the source that names it. `@TomJoinTable` and
    // `@TomPersistenceEventHandler` each point at `doc/object_persistence.md`
    // for the section listing them beside their sibling, which is the pointer
    // this check exists to keep honest.
    test('every doc/ path named in a source is a file that exists', () {
      final missing = <String>[];
      final pattern = RegExp(r'`(doc/[A-Za-z0-9_/]+\.md)`');
      for (final path in _libSources()) {
        final lines = File(path).readAsLinesSync();
        for (var index = 0; index < lines.length; index++) {
          for (final match in pattern.allMatches(lines[index])) {
            if (File(match.group(1)!).existsSync()) continue;
            missing.add('$path:${index + 1}: ${match.group(1)}');
          }
        }
      }
      expect(
        missing,
        isEmpty,
        reason:
            'these sources point a reader at a document the package does not '
            'have: ${missing.join(', ')}. A path inside a comment is compiled '
            'by nothing, and a document is renamed by someone reading the '
            'document rather than the source that names it.',
      );
    });

    test('the doc-path reader finds a path and judges it', () {
      // Both verdicts, on the two shapes this package writes: the backticked
      // path a dartdoc uses, and a name no file answers to.
      final pattern = RegExp(r'`(doc/[A-Za-z0-9_/]+\.md)`');
      expect(
        pattern.firstMatch('/// (see `doc/cmdline.md`).')?.group(1),
        'doc/cmdline.md',
      );
      expect(File('doc/cmdline.md').existsSync(), isTrue);
      expect(File('doc/no_such_document.md').existsSync(), isFalse);
    });
  });
}

/// Every Dart source under `lib/`, as paths from the package root.
List<String> _libSources() => [
  for (final entry in Directory('lib').listSync(recursive: true))
    if (entry is File && entry.path.endsWith('.dart')) entry.path,
]..sort();

/// Every Dart file under `example/`.
///
/// An example's dartdoc is read by exactly the reader the markers protect —
/// someone outside the workspace, looking for the shortest complete thing that
/// runs — and it is the surface most likely to have been written while the
/// quest material was open on the other screen. `test/` is deliberately not
/// here: its allowlists cite todo ids on purpose, because a skip that cannot
/// name what would lift it is a skip nobody removes.
List<String> _exampleSources() => [
  for (final entry in Directory('example').listSync(recursive: true))
    if (entry is File && entry.path.endsWith('.dart')) entry.path,
]..sort();

/// Every Dart file under `test/`, generated artifacts excluded.
///
/// Listed for one marker rather than joining the surfaces above, and the
/// distinction is the one [_exampleSources] states: a test's allowlist cites a
/// todo id on purpose, because a skip that cannot name what would lift it is a
/// skip nobody removes. What a test may not do is send the reader to coverage
/// that is not there.
///
/// This file is excluded, and it is the only one. A checker cannot be its own
/// subject: the phrase has to appear here to define the rule and again in the
/// fixture that proves the matcher reads a wrapped one, and both would report
/// themselves. The exclusion is by name rather than by a pattern so that it
/// cannot quietly grow to cover a second file, and a test above asserts it is
/// still one.
const String _selfExcludedSuite = 'test/api_reference_coverage_test.dart';

List<String> _testSources() => [
  for (final entry in Directory('test').listSync(recursive: true))
    if (entry is File &&
        entry.path.endsWith('.dart') &&
        !entry.path.endsWith('.reflection.dart') &&
        entry.path != _selfExcludedSuite)
      entry.path,
]..sort();

/// One paragraph of comment or prose, with the line it starts on.
typedef _FlatLine = ({int line, String text});

/// The comment and prose of [path] as paragraphs, with the markers stripped.
List<_FlatLine> _flattenedLines(String path) =>
    _flattenLines(File(path).readAsLinesSync());

/// Joins [lines] into paragraphs after removing dartdoc, comment and blockquote
/// markers, so a phrase is found however it happens to be wrapped.
///
/// A paragraph ends at a blank line *or* where the marker changes, which is
/// what keeps a dartdoc block from running on into the declaration below it. A
/// paragraph carrying the whole class body would still find the phrase, but the
/// failure message has to name one identifiable place, and "the comment" is
/// that place.
///
/// Split from [_flattenedLines] so the joining can be exercised on input
/// written for the purpose.
List<_FlatLine> _flattenLines(List<String> lines) {
  final marker = RegExp(r'^[ \t]*(///|//|>)[ \t]?');
  final paragraphs = <_FlatLine>[];
  var buffer = <String>[];
  var kind = '';
  var start = 0;

  void flush() {
    if (buffer.isEmpty) return;
    paragraphs.add((line: start, text: buffer.join(' ')));
    buffer = <String>[];
  }

  for (var i = 0; i < lines.length; i++) {
    final match = marker.firstMatch(lines[i]);
    final text = (match == null ? lines[i] : lines[i].substring(match.end))
        .trim();
    if (text.isEmpty) {
      flush();
      continue;
    }
    final lineKind = match?.group(1) ?? '';
    if (lineKind != kind) flush();
    if (buffer.isEmpty) start = i + 1;
    kind = lineKind;
    buffer.add(text);
  }
  flush();
  return paragraphs;
}

/// One `@TomEntityId` field found in a documented entity.
///
/// [initialiser] is the field's default expression, or `null` when the key is
/// nullable or left to a constructor — the two shapes that cannot carry the
/// defect, so they are recorded as "nothing to judge" rather than filtered out,
/// which keeps the sweep's own reach measurable.
typedef _EntityKey = ({
  String file,
  int line,
  String declaration,
  String? initialiser,
});

/// The primary-key declaration of every entity mapped inside a Dart fence of a
/// hand-written document in this package.
///
/// Covers the module readmes, the guides and the API summaries, because the
/// defect this guards against is one a reader *copies*: the shape is legal
/// Dart, the analyzer is silent about it, and the first save fails by writing
/// nothing rather than by raising. Only a document can teach it.
List<_EntityKey> _documentedEntityKeys() => [
  for (final file in _handWrittenDocuments())
    ..._entityKeysOf(file, File(file).readAsLinesSync()),
];

/// The markdown this package maintains by hand, as paths from the package root.
List<String> _handWrittenDocuments() => [
  'README.md',
  for (final directory in ['doc', 'doc/api_reference'])
    ...Directory(directory)
        .listSync()
        .whereType<File>()
        .map((entry) => entry.path)
        .where((path) => path.endsWith('.md')),
  ...Directory('lib/src/tomserver')
      .listSync()
      .whereType<Directory>()
      .map((entry) => '${entry.path}/readme.md')
      .where((path) => File(path).existsSync()),
  // An example's readme is shipped hand-written text like any other, and
  // leaving it out is not a neutral omission: `example/scheduling/cluster`
  // headed a five-row table "The three programs" for as long as nothing read
  // it. A document nobody checks is a document that drifts.
  ...Directory('example')
      .listSync(recursive: true)
      .whereType<File>()
      .map((entry) => entry.path)
      .where((path) => path.endsWith('.md')),
]..sort();

/// The `@TomEntityId` declarations inside [lines], reported under [file].
///
/// Split from [_documentedEntityKeys] so the parsing can be exercised on
/// declarations written for the purpose.
List<_EntityKey> _entityKeysOf(String file, List<String> lines) {
  final found = <_EntityKey>[];
  var inDart = false;

  for (var i = 0; i < lines.length; i++) {
    if (lines[i].startsWith('```')) {
      inDart = lines[i].startsWith('```dart');
      continue;
    }
    if (!inDart) continue;

    final start = lines[i].indexOf('@TomEntityId');
    if (start < 0) continue;

    // The declaration may sit on the annotation's line or several below it, so
    // read forward to the first `;` rather than assuming a layout.
    final buffer = StringBuffer(lines[i].substring(start));
    var end = i;
    while (!buffer.toString().contains(';') && end + 1 < lines.length) {
      end++;
      if (lines[end].startsWith('```')) break;
      buffer.write(' ${lines[end].trim()}');
    }

    final declaration = _withoutAnnotations(buffer.toString()).trim();
    final match = _keyDeclaration.firstMatch(declaration);
    if (match == null) continue;
    // A natural key is out of scope — see the parser test.
    if (!const {'int', 'num', 'double'}.contains(match.group(1))) continue;

    found.add((
      file: file,
      line: i + 1,
      declaration: declaration,
      // A nullable key is always insertable, so it has nothing to judge even
      // when it carries a default.
      initialiser: match.group(2) == '?' ? null : match.group(3)?.trim(),
    ));
  }
  return found;
}

/// A field declaration: type, optional `?`, name, optional initialiser.
final RegExp _keyDeclaration = RegExp(
  r'^(\w+)(\?)?\s+\w+\s*(?:=\s*(.+?))?\s*;',
);

/// [text] with every leading `@Annotation(...)` removed.
///
/// Written as a paren scan rather than a regular expression because an
/// annotation's arguments nest — `@TomDbColumn<int, TomDbInt>(columnName: 'id',
/// isReadOnly: true)` — and a non-greedy `\)` stops at the first one, leaving
/// the rest of the argument list to be read as the field's type.
String _withoutAnnotations(String text) {
  var rest = text.trimLeft();
  while (rest.startsWith('@')) {
    final open = rest.indexOf('(');
    if (open < 0) break;
    var depth = 0;
    var i = open;
    for (; i < rest.length; i++) {
      if (rest[i] == '(') depth++;
      if (rest[i] == ')' && --depth == 0) break;
    }
    if (depth != 0) break;
    rest = rest.substring(i + 1).trimLeft();
  }
  return rest;
}

/// The sub-heading under which `doc/server.md` lists what is not its surface.
///
/// A `###` inside the limitations section rather than a `##` of its own,
/// deliberately: the package keeps exactly one `##` per guide for claims about
/// unfinished work, and a second one would be a second place such claims
/// collect — the arrangement `a claim of unfinished work lives where it gets
/// swept` exists to prevent.
const String _disownedHeading = '### What this module does not do at all';

/// The capabilities `doc/server.md` says are not this module's, in order.
///
/// Each is the bold lead-in of a bullet in [_disownedHeading]'s list, which is
/// the sentence a reader actually scans — so taking the name from there rather
/// than from a list in this file keeps the guide the input and the test the
/// judge, instead of the two agreeing with each other about a third thing.
List<String> _disownedCapabilities(List<String> sectionBody) {
  final leadIn = RegExp(r'^-\s+\*\*(.+?)\.?\*\*');
  final found = <String>[];
  var inSubsection = false;
  for (final line in sectionBody) {
    if (line.startsWith('### ')) {
      inSubsection = line.trim() == _disownedHeading;
      continue;
    }
    if (!inSubsection) continue;
    final match = leadIn.firstMatch(line);
    if (match != null) found.add(match.group(1)!);
  }
  return found;
}

/// The file basenames a capability would occupy if the module implemented it.
///
/// The guide's bullets are prose — "Diagnostics and monitoring" — and a file is
/// `diagnostics.dart`. Bridging the two is a judgement, so it is written down
/// rather than inferred from the words: inferring would make `Server-rendered
/// forms` look for `server.dart`, which is the module itself. The cost of
/// writing it down is that the map goes stale, which is what
/// [_unmappedCapabilityComplaints] is for.
const Map<String, List<String>> _capabilityFiles = {
  'Diagnostics and monitoring': ['diagnostics', 'monitoring'],
  'Server-rendered forms': ['forms'],
  'WebSocket': ['websocket'],
};

/// The capabilities in [capabilities] that [_capabilityFiles] cannot look up.
///
/// A bullet with no entry is not a harmless omission: it is a capability the
/// guide disowns and nothing checks, and the check would still report the
/// module clean. Failing on the unknown name is what makes adding a fourth
/// bullet cost one line here rather than silently narrowing the sweep.
List<String> _unmappedCapabilityComplaints(List<String> capabilities) => [
  for (final capability in capabilities)
    if (!_capabilityFiles.containsKey(capability))
      '`$capability` is disowned by the guide but absent from '
          '`_capabilityFiles`, so no file name is checked for it',
];

/// The files in [fileNames] named for a capability the guide disowns.
///
/// Substring rather than equality, because a capability that came back would
/// not necessarily come back under the placeholder's exact name — a
/// `websocket_upgrade.dart` contradicts the guide every bit as much as a
/// `websocket.dart` does.
List<String> _disownedFileComplaints(
  List<String> capabilities,
  List<String> fileNames,
) => [
  for (final capability in capabilities)
    for (final stem in _capabilityFiles[capability] ?? const <String>[])
      for (final name in fileNames)
        if (name.contains(stem))
          '`$name` implements `$capability`, which `doc/server.md` says is not '
              'this module\'s surface — either the file belongs elsewhere or '
              'the guide is disowning something the module ships',
];

/// The three limitations `doc/server.md` records, as the source still shows
/// them.
///
/// There were four. `extractAuthentication` could not report a bad token, and
/// now reports both of its failures; the guide says so where the bullet was,
/// and the flag that measured it went with the bullet.
typedef _ServerLimitations = ({
  bool defaultErrorHandlerAlwaysFails,
  bool logsBelowAuthentication,
  bool startIsFireAndForget,
});

/// Reads the three limitations out of [lines].
///
/// Each is read from the one construct that decides it, so that fixing a
/// limitation flips exactly the one flag: the status the default handler
/// builds, the order the two middlewares are added to the pipeline, and the
/// return type `start()` declares.
_ServerLimitations _serverLimitationsOf(List<String> lines) {
  final joined = lines.join('\n');

  final logging = joined.indexOf('.addMiddleware(loggingMiddleware)');
  final authentication = joined.indexOf('authenticationMiddleware ??');

  // The extractor's body, so an empty catch elsewhere in the file does not
  // stand in for the two that make a bad token unreportable.
  final extractor = <String>[];
  var inExtractor = false;
  for (final line in lines) {
    if (!inExtractor) {
      if (line.contains('extractAuthentication(Request')) inExtractor = true;
      continue;
    }
    if (line == '}') break;
    extractor.add(line);
  }

  return (
    // The default handler is a field initialiser, and `internalServerError` is
    // the constructor that fixes the status at 500. A handler that chose one
    // would call `Response(status, ...)` instead.
    defaultErrorHandlerAlwaysFails: joined.contains(
      'return Response.internalServerError(',
    ),
    // Both present and the logging one added later: shelf applies middleware in
    // the order it is added, so "later" is "further from the client" — which is
    // exactly why a response decided by the authentication layer never reaches
    // it.
    logsBelowAuthentication:
        logging >= 0 && authentication >= 0 && logging > authentication,
    startIsFireAndForget: joined.contains('void start() async'),
  );
}

/// `TomServer`'s instance fields, and the class body they were read from.
typedef _ServerFields = ({List<String> names, List<String> body});

/// The fields `class TomServer` declares, read from [lines].
///
/// Fields and methods are both declared at one indentation level inside the
/// class, so they are told apart by how the declaration ends: a method opens a
/// brace, a field ends in `;` or continues into an initialiser after `=`. The
/// field's name is the last identifier before that terminator, which is what
/// makes the function-typed fields here (`Response? Function(...)
/// errorHandler`) parse without special-casing their parentheses.
_ServerFields _tomServerFieldsOf(List<String> lines) {
  final body = <String>[];
  var inClass = false;
  for (final line in lines) {
    if (!inClass) {
      if (line.startsWith('class TomServer {')) inClass = true;
      continue;
    }
    if (line == '}') break;
    body.add(line);
  }
  // Member level is one indent in; anything deeper is inside a method body.
  // Comments sit at member level too, and prose punctuates: two of this class's
  // own dartdoc lines end a clause with a semicolon and would otherwise parse
  // as fields called `log` and `address`.
  final member = RegExp(r'^  (?!//|@)\S');
  // Everything up to the terminator: a `;`, or the `=` of an initialiser. The
  // `=` must not be an arrow, or an expression-bodied method would parse as a
  // field named after the method. Taking the name from that *prefix* rather
  // than from the end of the line is what stops `bool ready = false;` from
  // parsing as a field called `false`.
  final declaration = RegExp(r'^([^=;]*?)\s*(?:=(?!>)|;)');
  final trailingName = RegExp(r'(\w+)$');
  final names = [
    for (final line in body)
      if (member.hasMatch(line))
        ?trailingName
            .firstMatch(declaration.firstMatch(line)?.group(1) ?? '')
            ?.group(1),
  ];
  return (names: names, body: body);
}

/// The fields of [fields] that a local somewhere in the class re-declares.
///
/// A declaration carries a type (or `final`/`var`) before the name; a plain
/// assignment does not. That one difference is the whole check — and it is the
/// difference the defect hid behind, because the shadowed field's method
/// contained a line reading `securityContext = SecurityContext()` that looked
/// exactly like the field being populated.
List<String> _shadowedFieldComplaints(_ServerFields fields) => [
  for (final name in fields.names)
    if (fields.body.any(
      (line) => RegExp('^\\s{4,}\\S+\\s+$name\\s*[;=]').hasMatch(line),
    ))
      '`$name` is declared as a local inside the class as well as a field, so '
          'the field is never the thing being written and reads null however '
          'its dartdoc describes it',
];

/// The fields of [fields] that nothing in the class ever writes.
///
/// Three ways count as written: an initialiser on the declaration itself, a
/// constructor that takes it as `this.name`, and a bare assignment anywhere in
/// the class. Only meaningful while [_shadowedFieldComplaints] is empty — the
/// third form cannot distinguish the field from a local wearing its name.
List<String> _unassignedFieldComplaints(_ServerFields fields) => [
  for (final name in fields.names)
    if (!fields.body.any(
      (line) =>
          RegExp('^\\s+$name\\s*=').hasMatch(line) ||
          line.contains('this.$name') ||
          RegExp('^  .*\\s$name\\s*=').hasMatch(line),
    ))
      '`$name` is a documented field that nothing in `TomServer` assigns, so '
          'it holds its declared default for the life of the server',
];

/// Where `start()` logs in and where it binds, as offsets into its own body.
typedef _StartSteps = ({List<String> body, int? loginLine, int? bindLine});

/// The two ordered steps of `start()`, read from [lines].
///
/// The body is cut at `start()`'s closing brace. The same file declares
/// `_installServerPrincipal` further down, and a scan that ran to the end of the
/// class would find *its* `loginAndInstall` call and pronounce the order correct
/// however `start()` itself had been rewritten.
_StartSteps _startStepsOf(List<String> lines) {
  final body = <String>[];
  var inStart = false;
  for (final line in lines) {
    if (!inStart) {
      if (line.contains('void start()')) inStart = true;
      continue;
    }
    // `start()` is a method, so its closing brace is the first at method
    // indentation — two spaces inside the class.
    if (line == '  }') break;
    body.add(line);
  }
  int? firstWith(String needle) {
    final index = body.indexWhere((line) => line.contains(needle));
    return index < 0 ? null : index;
  }

  return (
    body: body,
    loginLine: firstWith('_installServerPrincipal()'),
    bindLine: firstWith('await serve('),
  );
}

/// The shipped text of the three documents that describe `TomServer.start()`.
Map<String, List<String>> _shippedMirrorLines() => {
  for (final mirror in _requestScopeMirrors)
    mirror: File(mirror).readAsLinesSync(),
};

/// [lines] as one whitespace-normalised string.
///
/// Every phrase below is a sentence fragment, and prose wraps: the module
/// readme writes "and **never binds the socket**" across a line break, which a
/// line-by-line `contains` misses while the sentence reads perfectly. A marker a
/// reflow can defeat reports a document that says the right thing, which teaches
/// the next author to reword around the guard instead of fixing the document.
String _flattened(List<String> lines) =>
    lines.join(' ').replaceAll(RegExp(r'\s+'), ' ');

/// The [mirrors] that never mention the deployment's own login.
List<String> _selfLoginComplaints(Map<String, List<String>> mirrors) => [
  for (final entry in mirrors.entries)
    if (!const [
      'TomServerSelfLogin',
      'self-login',
    ].any(_flattened(entry.value).contains))
      '${entry.key} never mentions the server self-login, though `start()` '
          'performs it before binding anything',
];

/// The [mirrors] that mention the login without saying what a failure costs.
///
/// Separate from [_selfLoginComplaints] because the two rot separately: naming
/// the capability is the easy half, and the half a reader can do without. The
/// half they cannot is that a refused credential is the one thing that stops
/// `start()`, and that it stops it without a future to catch.
List<String> _failedLoginComplaints(Map<String, List<String>> mirrors) => [
  for (final entry in mirrors.entries)
    if (!const [
      'never bind',
      'no socket is bound',
      'refusing to bind',
      'binds nothing',
      'socket is never bound',
    ].any(_flattened(entry.value).contains))
      '${entry.key} does not say that a failed self-login leaves the socket '
          'unbound, which is the only way `start()` can fail outright',
];

/// What the authentication middleware gives a request, read from its source.
typedef _RequestScope = ({
  List<String> zoneValueTypes,
  bool opensTransactionScope,
});

/// The documents that restate what a request carries.
///
/// The module guide is the prose a deployment reads, the API summary is what a
/// caller consults about the middleware, and the module readme is the shortest
/// of the three and therefore the one most often read alone. All three describe
/// the same middleware, so all three have to describe the same request.
const List<String> _requestScopeMirrors = [
  'doc/server.md',
  'doc/api_reference/api_summary_server.md',
  'lib/src/tomserver/server/readme.md',
];

/// The zone values and transaction scope established in [lines].
///
/// Takes lines rather than a path so the parsing can be exercised on a literal
/// written for the purpose, and so a mutation can be applied to the shipped
/// source without touching the file.
_RequestScope _requestScopeOf(List<String> lines) {
  final types = <String>[];
  var inLiteral = false;
  for (final line in lines) {
    if (line.contains('TomZoneValues({')) {
      inLiteral = true;
      continue;
    }
    if (!inLiteral) continue;
    if (line.contains('});')) break;
    // A key is a bare type name before the colon; anything else in the literal
    // — a comment, a continuation of a long value — is not an entry.
    final match = RegExp(r'^\s*(\w+)\s*:').firstMatch(line);
    if (match != null) types.add(match.group(1)!);
  }
  return (
    zoneValueTypes: types,
    opensTransactionScope: lines.any(
      (line) => line.contains('TomTransactionManager.runInTransactionScope'),
    ),
  );
}

/// Where [mirrors] and [scope] disagree about the per-request transaction.
///
/// Reported in both directions. A document that omits the scope walks a reader
/// into replacing the middleware without one; a document that keeps claiming a
/// scope the middleware no longer opens is the same defect arriving from the
/// other side, and is the likelier of the two — source moves, prose does not.
List<String> _transactionScopeComplaints(
  _RequestScope scope,
  Map<String, List<String>> mirrors,
) => [
  for (final entry in mirrors.entries)
    if (entry.value.any((line) => line.contains('TomTransactionManager')) !=
        scope.opensTransactionScope)
      scope.opensTransactionScope
          ? '${entry.key} never mentions `TomTransactionManager`, but the '
                'middleware opens a transaction scope for every request'
          : '${entry.key} mentions `TomTransactionManager`, but the middleware '
                'no longer opens a transaction scope',
];

/// The body of [path]'s `## [heading]` section, up to the next `##` heading.
List<String> _sectionBody(String path, String heading) {
  final body = <String>[];
  var inSection = false;
  for (final line in File(path).readAsLinesSync()) {
    if (line.startsWith('## ')) {
      if (inSection) break;
      inSection = line.substring(3).trim() == heading;
      continue;
    }
    if (inSection) body.add(line);
  }
  return body;
}
