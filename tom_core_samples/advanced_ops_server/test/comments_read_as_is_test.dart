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
/// copy this file into every sample package. It is the wrong step, and the two
/// existing copies are why: they no longer implement the same rule. This one
/// matches ids by [_identifier]'s *shape* because the kernel's list of known
/// quest prefixes let `csexd4` and `csexd6` — ids from the `webwork` quest —
/// open this package's authorization suite while the guard reported it clean.
/// That fix was made here and travelled nowhere: the kernel's copy still had the
/// blind spot, and so did the repo-wide gate, by which time the same family had
/// reached shipped `lib/` dartdoc in three other packages. Sixteen copies would
/// not be sixteen guards, only sixteen places for the next fix to fail to leave.
/// Coverage belongs to the gate, which has one implementation to fix.
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
/// standing as a whole word — `tcinc991`, `csexd4`, `woneprpc12`.
///
/// Matching the *shape* and exempting the legitimate tokens is the wrong way
/// round only until you count the two sets. Quest prefixes are minted ad hoc and
/// there are dozens of them across the workspace's quests, so a gate that lists
/// the ones it knows is permanently one prefix behind — and it fails silently,
/// because an unknown prefix looks exactly like no citation at all. The tokens
/// on the other side are names from published standards, a closed vocabulary
/// that changes when a standards body acts rather than when somebody opens a
/// todo. So the open set is matched and the closed one is enumerated, in
/// [_knownTechnicalTokens].
///
/// The word boundaries are load-bearing: they keep the rule off camelCase, where
/// a digit run is followed by more letters (`sha256Digest` does not match, the
/// standalone `sha256` does).
///
/// **The argument above is true of this package and false of the repository**,
/// which is why `tool/check_comments_read_as_is.py` enumerates prefixes instead.
/// It holds here because a back-office sample's vocabulary is small enough for
/// [_knownTechnicalTokens] to close. Repo-wide the same shape matches 397
/// further tokens across 4,582 lines and nearly every one is real — `demo01` and
/// twenty-seven siblings, `material3`, `black54`, `operant1`, `pass2` — so the
/// exemption list would have to grow without bound and would soon be exempting
/// things by accident. At that scale the sets swap places: the identifiers worth
/// catching are the enumerable ones, and the gate widens its prefix list when a
/// family leaks in, as it did for `cs`.
final _identifier = RegExp(r'\b[a-z]{2,10}\d+\b');

/// Tokens of [_identifier]'s shape that name something a reader can look up.
///
/// Add to this list only for a name defined by a published standard — an
/// encoding, a hash, a protocol version. An id minted for a work item never
/// qualifies, which is the whole distinction the list exists to draw.
const _knownTechnicalTokens = <String>{
  'base32',
  'base64',
  'crc32',
  'http2',
  'http3',
  'iso8601',
  'md5',
  'oauth2',
  'pbkdf2',
  'pkcs1',
  'pkcs8',
  'sha1',
  'sha224',
  'sha256',
  'sha384',
  'sha512',
  'utf8',
  'utf16',
  'x509',
};

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

/// True when [line] points at something only a quest document could resolve.
///
/// The two halves are judged separately on purpose. The section exemption is
/// necessarily line-wide — it asks whether a document is named *near* the number
/// — so folding the id check into it would let one valid citation excuse
/// everything else on its line, which is the failure the exemption is supposed
/// to prevent rather than cause.
bool _citesAWorkItem(String line) =>
    _identifier
        .allMatches(line)
        .any((m) => !_knownTechnicalTokens.contains(m[0])) ||
    (line.contains('§') && !_allowedSectionRefs.any((p) => p.hasMatch(line)));

/// True when [line] describes a previous state of the code.
bool _narratesHistory(String line) =>
    _narrationPatterns.any((p) => p.hasMatch(line));

/// Returns `'<path>:<line>: <text>'` for every line [offends] rejects.
List<String> _scan(bool Function(String line) offends) {
  final offenders = <String>[];

  for (final entity in _filesToScan()) {
    // Root entries arrive as './README.md'; the trees arrive as 'lib/…'. The
    // offender list is what a developer reads when this fires, so make the two
    // look the same.
    final path = entity.path.replaceFirst(RegExp(r'^\./'), '');
    final lines = entity.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (!offends(lines[i])) continue;
      offenders.add('$path:${i + 1}: ${lines[i].trim()}');
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
