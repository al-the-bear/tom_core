/// Every comment in this package must resolve for someone who has only this
/// package.
///
/// A sample is read more carefully than a library — that is what it is for — so
/// a pointer it cannot follow costs more here than almost anywhere else. Two
/// habits produce them, and both feel helpful while the work is fresh:
///
/// 1. **Work-item pointers** — `tcinc262`, or `bug` followed by a section
///    number. They resolve only against quest documents, which the reader of the
///    sample does not have. To them it is noise shaped like a reference.
/// 2. **Unattributed section numbers** — a section number with no document
///    beside it names a real section of a real specification and is still
///    unreachable, because nothing on the line says *which* specification.
///    `ops_identity.dart` cites `codespecs_mapping.md` §5.26 for the
///    authorization meet; this test is what keeps the document's name beside the
///    number.
///
/// Traceability is not lost, it points the other way: a todo lists the files it
/// touched, so the link runs todo → code and no shipped artefact has to carry an
/// identifier that outlives the work item.
///
/// **This guard is local; the rule is not.** `tool/check_comments_read_as_is.py`
/// and `tool/check_section_refs.py` apply the same two habits to every package
/// in the repository, and they are the authority. This test and its sibling in
/// `tom_core_kernel` exist for a different reason: they run inside
/// `testkit :test`, so a regression here surfaces in the ordinary test run
/// rather than at the gate, and they can be package-specific where the
/// repo-wide gate must be uniform — this one scans `bin/`, which most packages
/// do not have.
///
/// **Why there are two of these and not sixteen.** The obvious next step is to
/// copy this file into every sample package. It is the wrong step: a copy is one
/// more place for the next fix to fail to leave. That is not a hypothetical —
/// matching ids by [_identifier]'s *shape*, rather than by a list of known quest
/// prefixes, was worked out here first, and travelled nowhere for as long as the
/// copies disagreed. Coverage belongs to the gate, which has one implementation
/// to fix.
///
/// What made the disagreement survivable-looking was that each copy carried its
/// own *vocabulary* — a list of quest prefixes, which every copy had to be told
/// about separately, so a copy could be perfectly correct and still blind. None
/// does now: every copy matches the shape and exempts English and published
/// technical words, a closed set that a newly minted prefix cannot join. The
/// only thing a copy may still hold that its siblings do not is which words
/// *this package's own* prose uses, which is a fact about the package rather
/// than about the rule.
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('shipped artefacts read as-is', () {
    test('no comment points at a quest work item', () {
      expect(_scan(_citesAWorkItem), isEmpty, reason: _workItemReason);
    });

    test('no comment narrates what the code used to do', () {
      expect(_scan(_narratesHistory), isEmpty, reason: _narrationReason);
    });
  });
}

// -----------------------------------------------------------------------------
// What counts as a violation
// -----------------------------------------------------------------------------

/// The shape a quest id has: a run of lowercase letters followed by digits,
/// optionally carrying the date code the id generator appends — `tcinc991`,
/// `csexd4`, `tcincb154_ahzj`.
///
/// Matching the *shape* and exempting the legitimate tokens is the wrong way
/// round only until you count the two sets. Quest prefixes are minted ad hoc and
/// there are dozens of them across the workspace's quests, so a guard that lists
/// the ones it knows is permanently one prefix behind — and it fails silently,
/// because an unknown prefix looks exactly like no citation at all. `csexd4` and
/// `csexd6`, ids from the `webwork` quest, opened this package's authorization
/// suite while a prefix-listing guard reported it clean.
///
/// The tokens on the other side are English words and names from published
/// standards. That set is *closed*: minting `zzq7` does not make `zzq` a word.
/// So the open set is matched and the closed one is enumerated, in
/// [_knownStems], and the failure direction inverts with it — the prefix list
/// failed open and silently, this fails closed and loudly.
///
/// The word boundaries are load-bearing: they keep the rule off camelCase, where
/// a digit run is followed by more letters (`sha256Digest` does not match, the
/// standalone `sha256` does).
final _identifier = RegExp(r'\b([a-z]{2,12})\d+(_[a-zäñößü]{4})?\b');

/// Stems that take a numeric suffix in ordinary prose *in this package*.
/// Anything matching [_identifier] whose stem is not here is a work-item
/// pointer.
///
/// These are the words this package's own prose happens to use — a fact about
/// the package, not about the rule, which is why the sibling guard in
/// `tom_core_kernel` carries twenty-seven and no divergence follows from it.
///
/// **Empty, and correctly so.** A back-office server's comments name no hash,
/// encoding or protocol version; `sha256` and `utf8` appear in this package only
/// as *code*, which the prose boundary already excludes. Pre-loading them
/// against a future need would be exempting tokens nothing uses — the failure
/// this list exists to avoid, arrived at from the other side. A comment that
/// one day says `base64` costs one entry here, which is the cheap half of the
/// bargain.
const _knownStems = <String>{};

/// The same shape in capitals — `TCCA17`, `CSEXF1`, `RCK13`, `OT2`.
///
/// Case is a bypass: [_identifier] is lowercase, so an id written the way prose
/// usually writes one — shouted — walks straight past it.
///
/// Capitals are matched only as a *whole run*, never camelCase, and that is
/// what keeps [_knownCaps] short. A Dart identifier with a numeric suffix is
/// written `addressLine1`, `promptSha256`, `mBlue100`; a work-item id never is.
final _capsIdentifier = RegExp(r'\b([A-Z]{2,12})\d+\b');

/// ALL-CAPS names a reader can look up. Empty for the same reason
/// [_knownStems] is: this package's prose names no standard that carries a
/// numeric suffix.
const _knownCaps = <String>{};

/// The two shapes an id is written in, each with its own vocabulary.
final _shapes = <(RegExp, Set<String>)>[
  (_identifier, _knownStems),
  (_capsIdentifier, _knownCaps),
];

/// Phrasings that describe a previous state of the code rather than the rule.
///
/// Deliberately narrow. "used to" also means "used in order to" ("the lease is
/// used to arbitrate"), and "was removed"/"has since been" routinely describe
/// *runtime* events ("returns true when a row was removed"), so those bare forms
/// are excluded — a guard that cries wolf gets switched off.
final _narrationPatterns = <RegExp>[
  RegExp(
    r'\bused to (be|been|return|claim|carry|call|stand|reflect|throw|write|test|exercise|live|sit|happen)\b',
    caseSensitive: false,
  ),
  RegExp(r'\b(before|after|prior to) the fix\b', caseSensitive: false),
  RegExp(r'\bthe todo that\b', caseSensitive: false),
  RegExp(r'\bthis todo\b', caseSensitive: false),
];

/// The `§` uses that are *not* work-item pointers and must not be flagged.
///
/// A section number is allowed exactly when the reader can see what it is a
/// section *of*, because that is the whole difference between a citation and a
/// dangling number. The named thing has to be something the reader can reach:
///
/// - a published standard — `RFC 4226 §5.3`, `CWE-117`;
/// - a specification this package implements — `codespecs_mapping.md §5.26`;
/// - a sibling document — `audit.md § "Why the publisher is not a scheduled
///   job"`.
///
/// The name has to be **in view**: on the citation's own line, or on a
/// neighbouring line of the same comment block (in markdown, the same
/// paragraph). A wrapped sentence is one sentence, and the writer did not choose
/// where it broke — dartdoc renders the paragraph whole, so a citation wrapped
/// as `(§N) in` / `` `doc/acl_design_specification.md` `` reads as one line to
/// every reader of the generated page. What the window excludes is the case
/// that really does strand a reader: a document named forty lines up, outside
/// the paragraph that cites it. This is the rule `tool/check_section_refs.py`
/// applies across `tom_ai/core` (its `in_view`), stated once for both.
///
/// A list named in front of the sign — `bug §N`, `tests §N` — is refused
/// whatever is in view: it names a work item, not a document, and no document
/// nearby makes it resolvable.
///
/// There is deliberately no exemption for the *shape* of the number. Allowing
/// `§<digits>.<digits>` on the grounds that quest bug lists are flat tests where
/// a number came from rather than whether a reader can follow it — and a real
/// specification section is exactly the case that looks safe and is not.
final _allowedSectionRefs = <RegExp>[
  RegExp(r'RFC ?\d+'),
  RegExp(r'CWE-\d+'),
  RegExp(r'[\w./-]+\.md\b'),
];

// -----------------------------------------------------------------------------
// Where to look
// -----------------------------------------------------------------------------

/// Trees whose contents a reader of this package can open, scanned recursively.
///
/// `bin/` is here because the boot is the first file anyone opens in a server
/// sample, and `tool/` for its shell scripts: an unresolvable citation in
/// `run_ops_integration.sh` is exactly as unresolvable as one in a library.
/// `example/` because it is the file a reader copies from.
const _scannedDirectories = ['lib', 'bin', 'test', 'tool', 'example'];

/// The package root, scanned **non-recursively** for the documents beside
/// `pubspec.yaml` — `README.md` above all, which is where a reader starts.
///
/// Non-recursive on purpose: a recursive root scan would pull in `.dart_tool/`
/// and the generated reflection output.
const _scannedRoot = '.';

/// Files exempt from the scan, and why each one is.
///
/// - This file states the patterns it forbids, so it matches all of them.
/// - `*.reflection.dart` is generated: it carries whatever the sources carried
///   at generation time and is fixed by regenerating, never by editing.
bool _isExempt(String path) =>
    path.endsWith('comments_read_as_is_test.dart') ||
    path.endsWith('.reflection.dart');

/// Extensions carrying prose a reader is expected to believe.
const _scannedExtensions = ['.dart', '.md', '.sh'];

/// The parts of a line a reader reads as prose, which is the only place a
/// pointer at a work item can sit. In Dart that is comments and the descriptions
/// of tests and groups; in markdown and shell it is the line.
///
/// Not every string literal: widening it that far drowns the rule in fixture
/// data (`user1`, `task2`), which is data the test feeds to the code rather than
/// prose a reader is asked to understand.
final _dartComment = RegExp(r'//+(.*)$');
final _dartTestName = RegExp(
  '\\b(?:test|group|testWidgets)\\s*\\(\\s*([\'"])(.*?)\\1',
);

List<String> _proseOf(File file, String line) {
  if (!file.path.endsWith('.dart')) return [line];
  final found = <String>[];
  final comment = _dartComment.firstMatch(line);
  if (comment != null) found.add(comment.group(1)!);
  final name = _dartTestName.firstMatch(line);
  if (name != null) found.add(name.group(2)!);
  return found;
}

/// A testkit id in the leading `ID: description` position of a test or group
/// name (`aos3-05: purges expired rows`). That position becomes the ID column of
/// `testlog/baseline_*.csv` — an identifier in a live tracking system, not a
/// pointer into a finished work item — and renaming one discards that test's
/// whole result history.
///
/// Only the leading position: the same id in prose is a pointer like any other,
/// and exempting it anywhere on the line would let a work-item pointer ride
/// along on any line that also opened a test.
final _testkitIdPosition = RegExp('[\'"]\\s*[a-z]+\\d+(-(\\d+|\\\$\\w+))?:\\s');

/// True when [line] points at something only a quest document could resolve.
///
/// The two halves are judged separately on purpose. The section exemption is
/// necessarily line-wide — it asks whether a document is named *near* the number
/// — so folding the id check into it would let one valid citation excuse
/// everything else on its line, which is the failure the exemption is supposed
/// to prevent rather than cause.
bool _citesAWorkItem(File file, List<String> lines, int index) {
  final line = lines[index];
  for (final chunk in _proseOf(file, line)) {
    for (final (shape, known) in _shapes) {
      for (final match in shape.allMatches(chunk)) {
        if (!known.contains(match.group(1))) return true;
      }
    }
  }
  if (!line.contains('§')) return false;
  if (_workItemMarker.hasMatch(line)) return true;
  final view = _inView(file, lines, index);
  return !_allowedSectionRefs.any((p) => p.hasMatch(view));
}

/// A list named in front of the sign, which names a work item rather than a
/// document — see [_allowedSectionRefs].
final _workItemMarker = RegExp(
  r'\b(bugs?|tests?|gaps?|phases?|steps?|items?|plans?|todos?)\s*§',
  caseSensitive: false,
);

/// A line that is part of a Dart comment block.
final _commentLine = RegExp(r'^\s*///?');

/// [lines] at [index] plus each neighbour in the same block — the same comment
/// in Dart, the same paragraph elsewhere. See [_allowedSectionRefs].
String _inView(File file, List<String> lines, int index) {
  final prose = !file.path.endsWith('.dart');
  bool joins(String text) =>
      prose ? text.trim().isNotEmpty : _commentLine.hasMatch(text);
  final span = [lines[index]];
  if (joins(lines[index])) {
    for (final neighbour in [index - 1, index + 1]) {
      if (neighbour >= 0 &&
          neighbour < lines.length &&
          joins(lines[neighbour])) {
        span.add(lines[neighbour]);
      }
    }
  }
  return span.join(' ');
}

/// True when [line] describes a previous state of the code.
bool _narratesHistory(File _, List<String> lines, int index) =>
    _narrationPatterns.any((p) => p.hasMatch(lines[index]));

/// Returns `'<path>:<line>: <text>'` for every line [offends] rejects.
List<String> _scan(
  bool Function(File file, List<String> lines, int index) offends,
) {
  final offenders = <String>[];

  for (final entity in _filesToScan()) {
    // Root entries arrive as './README.md'; the trees arrive as 'lib/…'. The
    // offender list is what a developer reads when this fires, so make the two
    // look the same.
    final path = entity.path.replaceFirst(RegExp(r'^\./'), '');
    final lines = entity.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_testkitIdPosition.hasMatch(line)) continue;
      if (!offends(entity, lines, i)) continue;
      offenders.add('$path:${i + 1}: ${line.trim()}');
    }
  }

  return offenders;
}

/// Every file in scope: the recursive trees plus the root's own documents.
List<File> _filesToScan() {
  final entities = <FileSystemEntity>[
    for (final directory in _scannedDirectories)
      if (Directory(directory).existsSync())
        ...Directory(directory).listSync(recursive: true),
    ...Directory(_scannedRoot).listSync(),
  ];

  return [
    for (final entity in entities)
      if (entity is File &&
          _scannedExtensions.any(entity.path.endsWith) &&
          !_isExempt(entity.path))
        entity,
  ];
}

const _workItemReason =
    'A quest todo id or an unattributed section number reached a shipped '
    'artefact. Name the document on the same line as the section number, or '
    'state the rule instead and record the file in the todo\'s references list '
    'so the link runs todo -> code rather than code -> todo.';

const _narrationReason =
    'A comment describes a previous state of the code. Restate it as the rule '
    'that holds now — usually by turning the past tense into a conditional: '
    '"before the fix it threw" becomes "doing X instead would throw".';
