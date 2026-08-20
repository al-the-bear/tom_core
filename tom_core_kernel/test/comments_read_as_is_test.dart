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
/// - Published standards a reader can look up: `RFC 4226 §5.3`, `CWE-117`.
/// - Sections of a specification the package is implementing: `§5.26`,
///   `CE-ER §7`, `codespecs_mapping.md §7`. A subsection number
///   (`§<digits>.<digits>`) is the giveaway — quest bug lists are flat.
/// - A named section of a sibling document: `doc/logging/logging.md § "What
///   the collector does"`.
final _allowedSectionRefs = <RegExp>[
  RegExp(r'RFC ?\d+'),
  RegExp(r'CWE-\d+'),
  RegExp(r'§ ?\d+\.\d+'),
  RegExp(r'CE-ER'),
  RegExp('codespecs'),
  RegExp(r'\.md" *§|\.md` *§|\.md *§'),
];

// -----------------------------------------------------------------------------
// Where to look
// -----------------------------------------------------------------------------

/// Trees whose contents a package consumer can read.
const _scannedDirectories = ['lib', 'test', 'example', 'doc'];

/// Files exempt from the scan, and why each one is.
///
/// - This file states the patterns it forbids, so it matches all of them.
/// - `CHANGELOG.md` is a history document by definition; naming the work item
///   behind an entry is what a changelog is *for*. It is not under [_scannedDirectories]
///   and is listed here only to record that the exemption is deliberate.
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

/// Returns `'<path>:<line>: <text>'` for every line matching [patterns].
List<String> _scan(List<RegExp> patterns) {
  final offenders = <String>[];

  for (final directory in _scannedDirectories) {
    final dir = Directory(directory);
    if (!dir.existsSync()) continue;

    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File) continue;
      final path = entity.path;
      if (!path.endsWith('.dart') && !path.endsWith('.md')) continue;
      if (_isExempt(path)) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (!patterns.any((p) => p.hasMatch(line))) continue;
        if (_allowedSectionRefs.any((p) => p.hasMatch(line))) continue;
        if (_testkitId.hasMatch(line)) continue;
        offenders.add('$path:${i + 1}: ${line.trim()}');
      }
    }
  }

  return offenders;
}

const _workItemReason =
    'A quest todo id or bug/test section number reached a shipped artefact. '
    'State the rule instead, and record the file in the todo\'s references '
    'list so the link runs todo -> code rather than code -> todo.';

const _narrationReason =
    'A comment describes a previous state of the code. Restate it as the rule '
    'that holds now — usually by turning the past tense into a conditional: '
    '"before the fix it threw" becomes "doing X instead would throw".';
