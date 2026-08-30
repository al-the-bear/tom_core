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
/// `tom_core_kernel/test/comments_read_as_is_test.dart` guards the same two
/// habits over the kernel — including the three `codespecs_mapping.md` §5.26
/// citations in `access_controls.dart` that this package's one was written
/// alongside. The rule is duplicated rather than shared because a test cannot be
/// imported
/// across packages, and because the two packages disagree about scope: this one
/// scans `bin/`, which the kernel does not have.
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
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

/// Quest todo ids (`tcinc991`, `tcincb2`) and bare section pointers.
///
/// The bare-`§` case is the interesting one, because legitimate uses of the
/// character have to survive it — see [_allowedSectionRefs].
final _workItemPatterns = <RegExp>[
  RegExp(r'\b(tcinc|tcincb|tcopen|tcca|tccc|tcser|tcdocc|tcscan)\d+\b'),
  RegExp('§'),
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
/// A section number is allowed exactly when the line says what it is a section
/// *of*, because that is the whole difference between a citation and a dangling
/// number. The named thing has to be something the reader can reach:
///
/// - a published standard — `RFC 4226 §5.3`, `CWE-117`;
/// - a specification this package implements — `codespecs_mapping.md §5.26`;
/// - a sibling document — `audit.md § "Why the publisher is not a scheduled
///   job"`.
///
/// The naming is required on the same line, not merely somewhere in the file.
/// Dartdoc is read one member at a time — in the generated API docs a member's
/// paragraph appears with nothing around it — so a document named forty lines up
/// is not available to the person reading the citation. The practical
/// consequence is that a citation may not be broken across a wrap: reflow the
/// paragraph so the document and its section number stay on one line.
///
/// There is deliberately no exemption for the *shape* of the number. Allowing
/// `§<digits>.<digits>` on the grounds that quest bug lists are flat tests where
/// a number came from rather than whether a reader can follow it — and a real
/// specification section is exactly the case that looks safe and is not.
final _allowedSectionRefs = <RegExp>[
  RegExp(r'RFC ?\d+'),
  RegExp(r'CWE-\d+'),
  RegExp(r'\.md" *§|\.md` *§|\.md *§'),
];

// -----------------------------------------------------------------------------
// Where to look
// -----------------------------------------------------------------------------

/// Trees whose contents a reader of this package can open, scanned recursively.
///
/// `bin/` is here because the boot is the first file anyone opens in a server
/// sample, and `tool/` for its shell scripts: an unresolvable citation in
/// `run_ops_integration.sh` is exactly as unresolvable as one in a library.
const _scannedDirectories = ['lib', 'bin', 'test', 'tool'];

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
