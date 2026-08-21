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
/// `testkit :test`, which is the only kind of guard that actually holds.
void main() {
  // ===========================================================================
  // Comments read as-is
  // ===========================================================================
  group('shipped artefacts read as-is', () {
    test('no comment points at a quest work item', () {
      expect(_scan(_workItemPatterns), isEmpty, reason: _workItemReason);
    });

    test('no comment narrates what the code used to do', () {
      expect(_scan(_narrationPatterns), isEmpty, reason: _narrationReason);
    });
  });
}

// -----------------------------------------------------------------------------
// What counts as a violation
// -----------------------------------------------------------------------------

/// Quest todo ids (`tcinc262`, `tcopen44`, `tccc3`) and section pointers into
/// the quest's bug/test lists (`bug §50`, `tests §34a`, a bare `§45`).
///
/// The bare-`§` case is the interesting one, because three *legitimate* uses of
/// the character have to survive it — see [_allowedSectionRefs].
final _workItemPatterns = <RegExp>[
  RegExp(r'\b(tcinc|tcincb|tcopen|tcca|tccc|tcser|tcdocc|tcscan)\d+\b'),
  RegExp(r'§'),
];

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

/// Test names carry a testkit id (`tccc3-05: reports at ERROR level`) which
/// becomes the ID column of `testlog/baseline_*.csv`. That is an identifier in
/// a live tracking system, not a pointer into a finished work item, and
/// renaming one discards that test's whole result history.
final _testkitId = RegExp(r'\btccc\d+(-\d+)?\b');

// -----------------------------------------------------------------------------
// The scan
// -----------------------------------------------------------------------------

/// Extensions carrying prose a reader is expected to believe.
const _scannedExtensions = ['.dart', '.md', '.sh'];

/// Returns `'<path>:<line>: <text>'` for every line matching [patterns].
List<String> _scan(List<RegExp> patterns) {
  final offenders = <String>[];

  for (final entity in _filesToScan()) {
    // Root entries arrive as './README.md'; the trees arrive as 'lib/…'. The
    // offender list is what a developer reads when this fires, so make the two
    // look the same.
    final path = entity.path.replaceFirst(RegExp(r'^\./'), '');
    final lines = entity.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (!patterns.any((p) => p.hasMatch(line))) continue;
      if (_allowedSectionRefs.any((p) => p.hasMatch(line))) continue;
      if (_testkitId.hasMatch(line)) continue;
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
