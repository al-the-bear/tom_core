import 'dart:io';

import 'package:test/test.dart';

/// An assertion that cannot fail is worse than no assertion at all.
///
/// The samples verify themselves with `assert` and nothing else — roughly 1800
/// of them, no `expect` anywhere. So a sample's credibility rests entirely on
/// each of those conditions being *capable* of being false. One that is not
/// still prints its section, still reports "✓ … passed", and still exits 0
/// while checking nothing, which is indistinguishable from a sample that
/// works.
///
/// `unnecessary_null_comparison` is the analyzer telling you it found one:
/// `x != null` on an expression the type system already guarantees is
/// non-null. Suppressing it silences the report and keeps the tautology, and
/// because the suppression is an `ignore_for_file` at the top of the file it
/// then covers every later comparison too — including ones added afterwards by
/// someone who never saw the line.
///
/// Nothing in this package needs the lint suppressed. When it fires, the fix is
/// to assert something that could have gone the other way — that the value the
/// call produced is the one that was asked for, that a second call hands back a
/// different instance, that the resource the shutdown was supposed to close is
/// now closed.
///
/// The second rule catches the same emptiness in a shape the analyzer has no
/// lint for, so nothing has to be suppressed to hide it:
///
/// ```dart
/// registrationComplete = true;
/// assert(registrationComplete, 'Registration should complete');
/// ```
///
/// With the assignment on the straight-line path of the enclosing function, the
/// condition cannot be false. What the assertion reports is that the lines above
/// it did not throw — which the absence of a crash had already said — and
/// nothing whatever about what the API produced.
void main() {
  // ===========================================================================
  // Assertions that can fail
  // ===========================================================================
  group('assertions can fail', () {
    test('no file suppresses unnecessary_null_comparison', () {
      expect(
        _nullComparisonSuppressions(),
        isEmpty,
        reason: _suppressionReason,
      );
    });

    test('no file asserts a flag it assigned on the straight-line path', () {
      expect(_straightLineFlags(), isEmpty, reason: _straightLineReason);
    });

    // A scan that matches nothing reports a clean tree, which is the one
    // failure this kind of test cannot survive — it would keep passing through
    // exactly the suppression it exists to catch. The floor is far below the
    // present count, so it fires on a broken scan rather than on the next file
    // somebody adds or deletes.
    test('the scan reaches the files it claims to check', () {
      expect(_filesToScan(), hasLength(greaterThanOrEqualTo(200)));
    });

    // The same floor for the second rule, and it has to be measured on the
    // pairs the rule *exempts* rather than on the ones it reports. The reported
    // set is empty when the tree is clean, so it can tell a working scan from a
    // broken one only while the tree is dirty — which is the wrong way round.
    // The exempted set is the population the rule is deciding about, and it does
    // not go to zero.
    test('the straight-line rule still finds the idioms it exempts', () {
      expect(_exemptedFlags(), hasLength(greaterThanOrEqualTo(25)));
    });
  });

  // ===========================================================================
  // The straight-line rule, on sources written for it
  // ===========================================================================
  //
  // A rule whose only evidence is a green tree is a rule that might match
  // nothing at all. These four sources pin the decision at its edges: one that
  // must be reported, and the three shapes that must not be — each of which is
  // load-bearing somewhere in `example/`, so an over-eager rule would be
  // "fixed" by deleting assertions that do their job.
  group('the straight-line rule', () {
    test('fires on a flag assigned and asserted in the same block', () {
      expect(
        _flagsIn('''
static void example1Something() {
  var registrationComplete = false;
  final user = register('ada');
  registrationComplete = true;
  assert(registrationComplete, 'Registration should complete');
}
'''),
        [isVacuousAt(4)],
      );
    });

    test('spares a flag assigned in a catch block', () {
      // The idiom `preferences/01` is built on: asserting the flag afterwards
      // is what separates "threw as documented" from "silently accepted".
      expect(
        _flagsIn('''
static void example2Rejects() {
  var rejected = false;
  try {
    codec.decode('nonsense');
  } on TomUserPreferenceCodecException {
    rejected = true;
  }
  assert(rejected, 'Nonsense should be rejected');
}
'''),
        isEmpty,
      );
    });

    test('spares a flag assigned inside a callback', () {
      // The flag is the only evidence the zone body ran at all; the enclosing
      // function reaches the assertion whether it did or not.
      expect(
        _flagsIn('''
static void example3Zone() {
  var zoneExecuted = false;
  context.runInContext(() {
    zoneExecuted = true;
  });
  assert(zoneExecuted, 'The zone body should run');
}
'''),
        isEmpty,
      );
    });

    test('spares a flag assigned under a condition', () {
      expect(
        _flagsIn('''
static void example4Lookup() {
  var found = false;
  final bean = locator.getBean<MetricsService>();
  if (bean != null && bean is MetricsService) {
    found = true;
  }
  assert(found, 'The bean should be found by type');
}
'''),
        isEmpty,
      );
    });

    test('spares an assertion whose polarity disagrees with the assignment', () {
      // `flag = false` then `assert(flag)` is not this pattern — it is either a
      // real check of something that reassigns the flag, or a bug. Either way
      // the rule has no business reporting it.
      expect(
        _flagsIn('''
static void example5Initialised() {
  var closed = false;
  resource.close();
  assert(closed, 'The resource should be closed');
}
'''),
        isEmpty,
      );
    });
  });
}

/// Matches a [_StraightLineFlag] whose assignment is on [line].
Matcher isVacuousAt(int line) =>
    isA<_StraightLineFlag>().having((f) => f.assignedAt, 'assignedAt', line);

// -----------------------------------------------------------------------------
// The rule
// -----------------------------------------------------------------------------

/// An `ignore` or `ignore_for_file` comment naming `unnecessary_null_comparison`.
///
/// Both forms are matched: the file-wide one is the shape that actually occurs,
/// but a single-line `// ignore:` hides the same tautology and is no more
/// defensible for being narrower.
final _suppression = RegExp(
  r'//\s*ignore(_for_file)?\s*:[^\n]*unnecessary_null_comparison',
);

/// Returns `'<path>:<line>: <text>'` for every line matching [_suppression].
List<String> _nullComparisonSuppressions() {
  final offenders = <String>[];

  for (final file in _filesToScan()) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (!_suppression.hasMatch(lines[i])) continue;
      offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
    }
  }

  return offenders;
}

// -----------------------------------------------------------------------------
// The straight-line rule
// -----------------------------------------------------------------------------

/// What the block enclosing the assignment turned out to be.
///
/// Only [straight] is reported. The other three are the shapes in which the
/// flag carries real information: the enclosing function reaches the assertion
/// whether or not the assignment ran, so the assertion decides something.
enum _FlagKind {
  /// The assignment is on the path the function always takes.
  straight,

  /// `} on SomeException {` or `} catch (e) {` — the flag separates "threw as
  /// documented" from "silently accepted".
  caught,

  /// `if` / `else` / `for` / … — the flag records that the condition held.
  branch,

  /// A function literal passed as an argument — the flag is the only evidence
  /// the callback body ran at all.
  closure,
}

/// A `flag = <bool literal>` paired with a later `assert` of the same flag.
class _StraightLineFlag {
  const _StraightLineFlag({
    required this.path,
    required this.name,
    required this.assignedAt,
    required this.assertedAt,
    required this.kind,
  });

  final String path;
  final String name;

  /// One-based line of the assignment.
  final int assignedAt;

  /// One-based line of the assertion.
  final int assertedAt;

  final _FlagKind kind;

  @override
  String toString() =>
      '$path:$assignedAt: `$name` is assigned here and asserted at line '
      '$assertedAt, with nothing in between that could change it';
}

/// `flag = true;`, with or without a declaration keyword.
final _assignment = RegExp(
  r'^(\s*)(?:(?:final|var|bool)\s+)?(\w+)\s*=\s*(true|false)\s*;\s*$',
);

/// `assert(flag` or `assert(!flag`, as the first thing on the line.
final _assertion = RegExp(r'^\s*assert\(\s*(!?)(\w+)\s*[,)]');

/// The opener of a `catch` or `on <Type>` block.
final _caughtOpener = RegExp(r'\b(?:catch|on\s+[\w<>.]+)\b');

/// The opener of a conditional or looping block.
final _branchOpener = RegExp(
  r'^\s*\}?\s*(?:if|else|for|while|do|switch|case|try)\b',
);

/// An open paren immediately followed by another one — a function literal
/// passed as an argument, `runInContext(() {`.
///
/// The naive test for a callback is `'() {'`, which also matches every method
/// declaration in the tree and so exempts the whole package. What separates the
/// two is the *second* paren: a declaration is `name(args) {`, a closure
/// argument is `name((closureArgs) {`.
final _closureOpener = RegExp(r'\(\s*\(');

/// How far below an assignment an assertion still counts as the same thought.
const _pairWindow = 30;

/// Every assignment/assertion pair in [source], classified.
List<_StraightLineFlag> _classifiedFlags(String source, String path) {
  final lines = source.split('\n');
  final flags = <_StraightLineFlag>[];

  for (var i = 0; i < lines.length; i++) {
    final assigned = _assignment.firstMatch(lines[i]);
    if (assigned == null) continue;

    final indent = assigned.group(1)!.length;
    final name = assigned.group(2)!;
    final value = assigned.group(3) == 'true';

    final assertedAt = _assertionOf(name, value, lines, i);
    if (assertedAt == null) continue;

    flags.add(
      _StraightLineFlag(
        path: path,
        name: name,
        assignedAt: i + 1,
        assertedAt: assertedAt + 1,
        kind: _kindOfBlockAbove(lines, i, indent),
      ),
    );
  }

  return flags;
}

/// The index of the first assertion of [name] below [from] whose polarity
/// agrees with [value], or `null` when there is none within [_pairWindow].
///
/// The scan deliberately does not stop at a dedent: in the catch idiom the
/// assignment sits *inside* the catch block and the assertion *after* the whole
/// try/catch, so a scan that stopped when the indentation fell would never form
/// those pairs — and the rule would have no exempted population to measure
/// itself against.
int? _assertionOf(String name, bool value, List<String> lines, int from) {
  final limit = (from + _pairWindow).clamp(0, lines.length - 1);

  for (var j = from + 1; j <= limit; j++) {
    final asserted = _assertion.firstMatch(lines[j]);
    if (asserted == null || asserted.group(2) != name) continue;

    // `flag = false` then `assert(flag)` is not this pattern — it is either a
    // real check of something that reassigns the flag, or a bug.
    final negated = asserted.group(1) == '!';
    return negated == !value ? j : null;
  }

  return null;
}

/// Classifies the block that encloses the assignment on line [at].
///
/// The opener is the nearest line above with strictly smaller indentation.
_FlagKind _kindOfBlockAbove(List<String> lines, int at, int indent) {
  for (var j = at - 1; j >= 0; j--) {
    final line = lines[j];
    if (line.trim().isEmpty) continue;
    if (line.length - line.trimLeft().length >= indent) continue;

    if (_caughtOpener.hasMatch(line)) return _FlagKind.caught;
    if (_branchOpener.hasMatch(line)) return _FlagKind.branch;
    if (_closureOpener.hasMatch(line)) return _FlagKind.closure;
    return _FlagKind.straight;
  }

  return _FlagKind.straight;
}

/// The straight-line flags in a single source, for the tests that pin the rule.
List<_StraightLineFlag> _flagsIn(String source) => _classifiedFlags(
  source,
  '<source>',
).where((flag) => flag.kind == _FlagKind.straight).toList();

List<_StraightLineFlag> _packageFlags() => [
  for (final file in _filesToScan())
    ..._classifiedFlags(file.readAsStringSync(), file.path),
];

/// Every flag the rule reports.
List<_StraightLineFlag> _straightLineFlags() =>
    _packageFlags().where((flag) => flag.kind == _FlagKind.straight).toList();

/// Every flag the rule decided *not* to report, which is the population it has
/// to keep finding for its verdict on the rest to mean anything.
List<_StraightLineFlag> _exemptedFlags() =>
    _packageFlags().where((flag) => flag.kind != _FlagKind.straight).toList();

// -----------------------------------------------------------------------------
// The scan
// -----------------------------------------------------------------------------

/// Trees holding Dart this package is responsible for.
const _scannedDirectories = ['lib', 'test', 'example', 'tool'];

/// Generated sources carry whatever the generator emits, and are corrected by
/// regenerating rather than by editing.
bool _isGenerated(String path) =>
    path.endsWith('.reflection.dart') || path.endsWith('.g.dart');

List<File> _filesToScan() => [
  for (final directory in _scannedDirectories)
    if (Directory(directory).existsSync())
      for (final entity in Directory(directory).listSync(recursive: true))
        if (entity is File &&
            entity.path.endsWith('.dart') &&
            !_isGenerated(entity.path) &&
            // This file states the pattern it refuses, so it matches it.
            !entity.path.endsWith('assertions_can_fail_test.dart'))
          entity,
];

const _suppressionReason =
    'A file suppresses unnecessary_null_comparison. The analyzer only reports '
    'that lint for a comparison the type system has already decided, so the '
    'suppression is preserving an assertion that cannot fail. Assert something '
    'that could have gone the other way instead — what the call produced, not '
    'that it produced anything.';

const _straightLineReason =
    'A flag is assigned a bool literal on the straight-line path of its '
    'function and then asserted, so the condition cannot be false. The '
    'assertion reports that the lines above it did not throw, which the absence '
    'of a crash already said. Assert what the call produced — the value that '
    'came back, the size the pool was built at, the fields the object carries — '
    'or delete the flag if the surrounding lines already check it.';
