import 'dart:io';

import 'package:test/test.dart';

/// Every artefact this package ships must read as a statement of what the code
/// does *now*.
///
/// Two habits break that, and both are easy to reintroduce because both feel
/// helpful while the work is fresh:
///
/// 1. **Work-item pointers** — `bug §50`, `tests §34a`, `tcinc262`. They
///    resolve only against quest documents, which nobody reading the published
///    package has. To that reader they are noise that looks like it means
///    something.
/// 2. **History narration** — "used to be", "before the fix". A reader needs
///    the *rule*, not the changelog: "a legitimate domain scope whose local id
///    happens to be 'default' is not the sentinel" carries the whole reason,
///    while "before the fix it was treated as the sentinel" makes them
///    reconstruct it.
///
/// Traceability still exists — it just points the other way. A todo names the
/// files it touched in its own `references` list, so the link survives without
/// the code carrying an identifier that outlives the work item.
///
/// This is a test rather than a shell script on purpose: it runs on every
/// `testkit :test`, so a regression surfaces in the ordinary test run.
///
/// **It covers this package only, and it is not the rule.**
/// `tool/check_comments_read_as_is.py` and `tool/check_section_refs.py` apply
/// the same two habits to every package in the repository and are the
/// authority; this test is the fast half of the same convention. Keeping the
/// coverage in one repo-wide gate rather than in a copy of this file per
/// package is a decision the existing copies earned: a fix to the id rule was
/// once made in the `advanced_ops_server` copy and never travelled back here.
///
/// What made that possible was that each copy carried its own *vocabulary* —
/// a list of quest prefixes, which every copy had to be told about separately.
/// None does now. The rule is a shape plus a list of English words, so the
/// only thing a copy can hold that its siblings do not is which words that
/// package's own examples use.
void main() {
  // ===========================================================================
  // Comments read as-is
  // ===========================================================================
  group('shipped artefacts read as-is', () {
    test('no comment points at a quest work item', () {
      expect(_scan(_pointsAtAWorkItem), isEmpty, reason: _workItemReason);
    });

    test('no comment narrates what the code used to do', () {
      expect(
        _scan((_, line) => _narrationPatterns.any((p) => p.hasMatch(line))),
        isEmpty,
        reason: _narrationReason,
      );
    });
  });
}

// -----------------------------------------------------------------------------
// What counts as a violation
// -----------------------------------------------------------------------------

/// The shape of a quest todo id: letters, then digits, optionally followed by
/// the date code the id generator appends (`tcincb154_ahzj`).
final _idShape = RegExp(r'\b([a-z]{2,12})\d+(_[a-zäñößü]{4})?\b');

/// Stems that take a numeric suffix in ordinary prose *in this package*.
/// Anything matching [_idShape] whose stem is not here is a work-item pointer.
///
/// **This list is English, not quest vocabulary, and that is what makes it
/// safe.** The rule used to enumerate quest prefixes — `tcinc`, `tcca`, `tccc`
/// and five more. That is an *open* set: it grows whenever anyone mints a
/// prefix, and until someone adds the new one the guard reports the package
/// clean. It failed exactly that way; `qrc1` and `tfca4` were shipping in
/// `tom_core_server` dartdoc while every copy of this guard passed.
///
/// Enumerating words instead closes the set — minting `zzq7` does not make
/// `zzq` a word — so the failure direction inverts with it: the prefix list
/// failed open and silently, this fails closed and loudly. A new worked
/// example naming `widget1` costs one entry here, which is the cheap half.
///
/// **Why the per-package copies may differ here and nowhere else.** These are
/// the words *this* package's examples happen to use. There is no quest
/// vocabulary left in any copy, so the copies cannot drift apart on the rule —
/// only on which English words they need, which is a fact about each package.
const _knownStems = <String>{
  'abc', 'api', 'avc', 'base', 'command', 'data', 'db', 'element', 'field',
  'image', 'iso', 'level', 'list', 'map', 'march', 'mp', 'names', 'person',
  'pkcs', 'scores', 'sha', 'sigusr', 'step', 'tz', 'utf', 'value', 'wrap',
};

/// The same shape in capitals — `TCCA17`, `CSEXF1`, `RCK13`, `OT2`.
///
/// Case is a bypass: [_idShape] is lowercase, so an id written the way prose
/// usually writes one — shouted — walks straight past it.
///
/// Capitals are matched only as a *whole run*, never camelCase, and that is
/// what keeps [_knownCaps] short. A Dart identifier with a numeric suffix is
/// written `addressLine1`, `promptSha256`, `mBlue100`; a work-item id never is.
final _capsShape = RegExp(r'\b([A-Z]{2,12})\d+\b');

/// ALL-CAPS names a reader can look up — hash and cipher families, media and
/// encoding standards, signal names.
const _knownCaps = <String>{
  'ISO', 'MP', 'PKCS', 'RFC', 'SHA', 'SIGUSR', 'SKU', 'USR', 'UTF',
};

/// The two shapes an id is written in, each with its own vocabulary. Kept
/// apart so neither list has to carry the other's words: exempting `SHA` on
/// the lowercase side would exempt `sha` for free, and vice versa.
final _shapes = <(RegExp, Set<String>)>[
  (_idShape, _knownStems),
  (_capsShape, _knownCaps),
];

/// The parts of a line a reader reads as prose, which is the only place a
/// pointer at a work item can sit. In Dart that is comments and the
/// descriptions of tests and groups; in markdown and shell it is the line.
///
/// Not every string literal: widening it that far drowns the rule in fixture
/// data (`user1`, `task2`), which is data the test feeds to the code rather
/// than prose a reader is asked to understand.
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

/// A quest todo id, or a section pointer into a quest's bug/test lists
/// (`bug §50`, `tests §34a`, a bare `§45`).
///
/// The bare-`§` case is the interesting one, because three *legitimate* uses of
/// the character have to survive it — see [_allowedSectionRefs].
bool _pointsAtAWorkItem(File file, String line) {
  for (final chunk in _proseOf(file, line)) {
    for (final (shape, known) in _shapes) {
      for (final match in shape.allMatches(chunk)) {
        if (!known.contains(match.group(1))) return true;
      }
    }
  }
  return line.contains('§') &&
      !_allowedSectionRefs.any((p) => p.hasMatch(line));
}

/// Phrasings that describe a previous state of the code rather than the rule.
///
/// Deliberately narrow. "used to" also means "used in order to" ("an Exception
/// used to fail a command"), and "was removed"/"has since been" routinely
/// describe *runtime* events ("returns true when an entry was removed"), so
/// those bare forms are excluded — a guard that cries wolf gets switched off.
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
/// A section number is allowed exactly when the line says what it is a section
/// *of*, because that is the whole difference between a citation and a dangling
/// number. The named thing has to be something the reader can reach:
///
/// - a published standard — `RFC 4226 §5.3`, `CWE-117`;
/// - a specification this package implements — `CE-ER §7`,
///   `codespecs_mapping.md §5.26`;
/// - a sibling document — `doc/logging/logging.md § "What the collector does"`.
///
/// The naming is required on the same line, not merely somewhere in the file.
/// Dartdoc is read one member at a time — in the generated API docs a member's
/// paragraph appears with nothing around it — so a document named forty lines
/// up is not available to the person reading the citation. The practical
/// consequence is that a citation may not be broken across a wrap: reflow the
/// paragraph so the document and its section number stay on one line.
///
/// There is deliberately no exemption for the *shape* of the number. Allowing
/// `§<digits>.<digits>` on the grounds that quest bug lists are flat tests
/// where a number came from rather than whether a reader can follow it, and it
/// let three unattributed `§5.26` citations sit in `access_controls.dart` —
/// real spec sections, unreachable all the same.
final _allowedSectionRefs = <RegExp>[
  RegExp(r'RFC ?\d+'),
  RegExp(r'CWE-\d+'),
  RegExp(r'CE-ER'),
  RegExp(r'\.md" *§|\.md` *§|\.md *§'),
];

// -----------------------------------------------------------------------------
// Where to look
// -----------------------------------------------------------------------------

/// Trees whose contents a package consumer can read, scanned recursively.
///
/// `tool/` is here for its shell scripts: a `bug §52` in a comment is exactly
/// as unresolvable to the reader of a script as to the reader of a library.
const _scannedDirectories = ['lib', 'test', 'example', 'doc', 'tool'];

/// The package root, scanned **non-recursively** for the documents that sit
/// beside `pubspec.yaml` — `README.md` above all, which is the pub.dev landing
/// page and so the most-read artefact the package has.
///
/// Non-recursive on purpose. A recursive root scan would pull in
/// `_copilot_guidelines/` — development docs, where naming the work item is
/// the correct thing to do — along with build and log directories.
const _scannedRoot = '.';

/// Files exempt from the scan, and why each one is.
///
/// - This file states the patterns it forbids, so it matches all of them.
/// - `CHANGELOG.md` is a history document by definition; naming the work item
///   behind an entry is what a changelog is *for*. It sits in [_scannedRoot],
///   so this exemption is what actually keeps it out.
/// - `doc/analyzer_analysis.json` is generated: it snapshots dartdoc text, so
///   it carries whatever the sources carried at generation time and is fixed by
///   regenerating, never by editing.
bool _isExempt(String path) =>
    path.endsWith('comments_read_as_is_test.dart') ||
    path.endsWith('CHANGELOG.md') ||
    path.endsWith('analyzer_analysis.json');

/// A testkit id in the leading `ID: description` position of a test or group
/// name (`tccc3-05: reports at ERROR level`). That position becomes the ID
/// column of `testlog/baseline_*.csv` — an identifier in a live tracking
/// system, not a pointer into a finished work item — and renaming one discards
/// that test's whole result history.
///
/// Only the leading position. The same id in prose is a pointer like any
/// other; exempting it anywhere on the line, as this guard once did, let a
/// work-item pointer ride along on any line that also opened a test.
final _testkitIdPosition = RegExp('[\'"]\\s*[a-z]+\\d+(-(\\d+|\\\$\\w+))?:\\s');

// -----------------------------------------------------------------------------
// The scan
// -----------------------------------------------------------------------------

/// Extensions carrying prose a reader is expected to believe.
const _scannedExtensions = ['.dart', '.md', '.sh'];

/// Returns `'<path>:<line>: <text>'` for every line [isFault] accepts.
List<String> _scan(bool Function(File file, String line) isFault) {
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
      if (!isFault(entity, line)) continue;
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
    'A quest todo id or bug/test section number reached a shipped artefact. '
    'State the rule instead, and record the file in the todo\'s references '
    'list so the link runs todo -> code rather than code -> todo.';

const _narrationReason =
    'A comment describes a previous state of the code. Restate it as the rule '
    'that holds now — usually by turning the past tense into a conditional: '
    '"before the fix it threw" becomes "doing X instead would throw".';
