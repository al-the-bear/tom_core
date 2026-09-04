import 'dart:io';

import 'package:test/test.dart';

/// A group's `00_run_all_examples.dart` runs its samples back to back into one
/// continuous transcript, so a reader mapping a passage of it back to a source
/// file has only the ordinal to do it with.
///
/// Exactly one thing emits that ordinal: **the file's own banner**,
/// `=== 03: Shutdown Execution Example ===`, printed as the first thing `run()`
/// does. Renumbering a directory renames the files and does not touch the
/// string, so it drifts silently — the suite still passes and the transcript
/// simply points at the wrong source. Roughly a dozen files have carried a
/// stale or absent ordinal at one time or another, which is what makes this
/// worth a test rather than a periodic sweep.
///
/// "Exactly one" is itself a rule here, and a recent one. Group runners used to
/// print a label of their own before each call, so a file was named twice per
/// run by two strings written months apart; ten runners carried one and five
/// had drifted out of step with the sample they introduced, emitting two
/// different ordinals for one file in a single transcript. The labels are gone,
/// and a test below keeps them gone: the sample names itself, the runner names
/// the group, and there is one place to get the number wrong instead of two.
///
/// The complementary property — that the banner actually *reaches* the
/// transcript, rather than merely existing in the source — is not decidable
/// here and is checked by `tool/run_standalone_examples.sh`, which reads the
/// group runners' output after running them.
void main() {
  // ===========================================================================
  // Example numbering
  // ===========================================================================
  group('example numbering', () {
    test('every sample announces itself', () {
      expect(_silentSamples(), isEmpty, reason: _silentReason);
    });

    test('every sample banner announces the sample\'s own ordinal', () {
      expect(_bannerOrdinalMismatches(), isEmpty, reason: _bannerReason);
    });

    test('no group runner prints a per-file label of its own', () {
      expect(_runnerPerFileLabels(), isEmpty, reason: _labelReason);
    });

    test('every numbered sample is called by its group runner', () {
      expect(_uncalledSamples(), isEmpty, reason: _uncalledReason);
    });

    test('each suite numbers its samples from 01 without gap or repeat', () {
      expect(_ordinalSequenceDefects(), isEmpty, reason: _sequenceReason);
    });

    // A scan that silently matches nothing reports a clean tree, which is the
    // one failure this kind of test cannot survive: it would keep passing
    // through exactly the renumbering it exists to catch. The floors are well
    // under the present counts, so they fire on a broken pattern rather than
    // on the next sample somebody adds or deletes.
    test('the scan finds the artefacts it claims to check', () {
      expect(_suites(), hasLength(greaterThanOrEqualTo(15)));
      expect(_allSamples(), hasLength(greaterThanOrEqualTo(80)));
      expect(_announcements(), hasLength(greaterThanOrEqualTo(80)));
    });

    // The runner-label rule asserts an *absence*, so unlike the others its scan
    // cannot prove itself by finding something: a pattern that quietly stopped
    // matching would report a clean tree forever, and the labels it exists to
    // keep out would come back unremarked. So the pattern is run once against
    // the two shapes of the line it was written to catch.
    test('the runner-label pattern still matches a label', () {
      expect(
        _runnerLabel.hasMatch(r"  print('\n03: Shutdown Execution Example');"),
        isTrue,
      );
      expect(
        _runnerLabel.hasMatch("  print('03: Shutdown Execution Example');"),
        isTrue,
      );
    });
  });
}

// -----------------------------------------------------------------------------
// What an ordinal looks like, and where it is written
// -----------------------------------------------------------------------------

/// The sample tree: one directory per kernel module, each holding numbered
/// samples and the `00_run_all_examples.dart` that sequences them.
const _samplesRoot = 'example/samples';

/// A leading `01: ` on a banner or label, which is the ordinal itself.
final _leadingOrdinal = RegExp(r'^(\d+):\s*(.*)$');

/// The two-digit prefix a sample file carries in its name.
final _fileOrdinal = RegExp(r'^(\d+)_');

/// `print('=== 03: Title ===\n');` — the one banner shape, used by every
/// sample in the tree.
final _styleABanner = RegExp(r"""^\s*print\(\s*'===\s*(.*?)\s*===""");

/// `print('\n03: Shutdown Execution Example');` — the per-file label group
/// runners used to print, and must not print again.
final _runnerLabel = RegExp(
  r"""^\s*print\(\s*'(?:\\n)?\s*(\d+):\s*(.*?)\s*'\s*\)\s*;""",
);

/// `await shutdown_execution.run();` / `crypto.run();` in a group runner.
final _runCall = RegExp(r'(?:await\s+)?(\w+)\.run\(\)');

/// A commented-out line, which does not call anything.
///
/// Commenting a call out is the quietest way to drop a sample from the suite —
/// nothing fails, the transcript is simply shorter — so a scan that counted
/// those as calls would miss the case it most needs to catch.
final _commentedOut = RegExp(r'^\s*//');

/// `import '03_shutdown_execution_example.dart' as shutdown_execution;`
///
/// Matched against the whole source rather than line by line, because the
/// formatter wraps the longer ones before the `as` and a line-based pattern
/// would read those as unaliased — reporting the sample they name as one the
/// runner never calls.
final _aliasedImport = RegExp(r"""import\s+'([^']+\.dart)'\s+as\s+(\w+)\s*;""");

// -----------------------------------------------------------------------------
// The model
// -----------------------------------------------------------------------------

/// One numbered sample file: `03_shutdown_execution_example.dart`.
class _Sample {
  _Sample(this.file, this.suite, this.ordinal);

  final File file;
  final String suite;
  final String ordinal;

  String get name => file.uri.pathSegments.last;
  String get where => '$suite/$name';
}

/// A sample's self-announcement, in either banner form.
class _Announcement {
  _Announcement(this.sample, this.line, this.text);

  final _Sample sample;
  final int line;

  /// The banner with its decoration stripped: `03: Shutdown Execution Example`.
  final String text;
}

// -----------------------------------------------------------------------------
// Reading the tree
// -----------------------------------------------------------------------------

/// The per-module sample directories, each of which owns a group runner.
List<Directory> _suites() {
  final root = Directory(_samplesRoot);
  if (!root.existsSync()) return const [];
  return [
    for (final entity in root.listSync())
      if (entity is Directory &&
          File('${entity.path}/00_run_all_examples.dart').existsSync())
        entity,
  ]..sort((a, b) => a.path.compareTo(b.path));
}

/// Every numbered sample, runners excluded — they are the thing doing the
/// numbering, not a thing that carries an ordinal of its own.
List<_Sample> _allSamples() => [
  for (final suite in _suites()) ..._samplesOf(suite),
];

List<_Sample> _samplesOf(Directory suite) {
  final name = suite.uri.pathSegments.where((s) => s.isNotEmpty).last;
  final samples = <_Sample>[];
  for (final entity in suite.listSync()) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final file = entity.uri.pathSegments.last;
    final match = _fileOrdinal.firstMatch(file);
    if (match == null || match.group(1) == '00') continue;
    samples.add(_Sample(entity, name, match.group(1)!));
  }
  return samples..sort((a, b) => a.ordinal.compareTo(b.ordinal));
}

/// Every self-announcement in the tree.
///
/// One per sample, normally: the banner `run()` opens with. A sample may print
/// more than one — a long one sometimes re-announces itself partway — and each
/// is checked, since each is a place to write the wrong number.
List<_Announcement> _announcements() {
  final found = <_Announcement>[];

  for (final sample in _allSamples()) {
    final lines = sample.file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final styleA = _styleABanner.firstMatch(lines[i]);
      if (styleA == null) continue;
      found.add(_Announcement(sample, i + 1, styleA.group(1)!));
    }
  }

  return found;
}

// -----------------------------------------------------------------------------
// The four rules
// -----------------------------------------------------------------------------

/// Samples that carry no banner, and so contribute an unlabelled block to
/// their group's transcript — or, if they print nothing at all, no block.
///
/// Twenty-seven of them printed nothing: they ran, asserted, exited 0, and left
/// no trace, so a reader watching the transcript could not have told they were
/// there. The reasonable conclusion from a runner's heading followed by silence
/// is that the samples were skipped, which is the same wrong answer the stale
/// ordinals gave, arrived at from the other direction.
List<String> _silentSamples() {
  final announced = {for (final a in _announcements()) a.sample.where};
  return [
    for (final sample in _allSamples())
      if (!announced.contains(sample.where))
        '${sample.where} prints no "=== ${sample.ordinal}: … ===" banner',
  ];
}

/// Group runners printing a `NN: Title` label of their own.
///
/// A runner names the group; the samples name themselves. A runner that also
/// names each file writes a second title for it, in a second place, and the two
/// drift — ten runners carried such a label until five of them disagreed with
/// the sample they introduced, so one run of the suite announced a file under
/// two different ordinals.
///
/// Scanned as bare lines rather than paired with the call that follows: the
/// pairing was only needed to decide *which* sample a label belonged to, and
/// there is no longer a sample it may belong to.
List<String> _runnerPerFileLabels() {
  final offenders = <String>[];

  for (final suite in _suites()) {
    final name = suite.uri.pathSegments.where((s) => s.isNotEmpty).last;
    final lines = File(
      '${suite.path}/00_run_all_examples.dart',
    ).readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (_commentedOut.hasMatch(lines[i])) continue;
      final label = _runnerLabel.firstMatch(lines[i]);
      if (label == null) continue;
      offenders.add(
        '$name/00_run_all_examples.dart:${i + 1}: prints '
        '"${label.group(1)}: ${label.group(2)}"',
      );
    }
  }

  return offenders;
}

/// Banners whose ordinal is absent, or is not the one in the file's name.
List<String> _bannerOrdinalMismatches() {
  final offenders = <String>[];

  for (final announcement in _announcements()) {
    final where = '${announcement.sample.where}:${announcement.line}';
    final ordinal = _leadingOrdinal.firstMatch(announcement.text);
    if (ordinal == null) {
      offenders.add(
        '$where: banner carries no ordinal: '
        '"${announcement.text}"',
      );
      continue;
    }
    if (ordinal.group(1) != announcement.sample.ordinal) {
      offenders.add(
        '$where: banner says ${ordinal.group(1)}, '
        'file is ${announcement.sample.ordinal}',
      );
    }
  }

  return offenders;
}

/// Samples the group runner never calls, which therefore never run and quietly
/// rot.
List<String> _uncalledSamples() {
  final offenders = <String>[];

  for (final suite in _suites()) {
    final runner = File('${suite.path}/00_run_all_examples.dart');
    final text = runner.readAsStringSync();
    final called = {
      for (final line in runner.readAsLinesSync())
        if (!_commentedOut.hasMatch(line))
          if (_runCall.firstMatch(line) case final call?) call.group(1)!,
    };
    final calledFiles = {
      for (final import in _aliasedImport.allMatches(text))
        if (called.contains(import.group(2)!)) import.group(1)!,
    };

    for (final sample in _samplesOf(suite)) {
      if (calledFiles.contains(sample.name)) continue;
      offenders.add('${sample.where} is never called by the group runner');
    }
  }

  return offenders;
}

/// Suites whose ordinals skip a number or use one twice — either way the
/// transcript stops being a reliable index into the directory.
List<String> _ordinalSequenceDefects() {
  final offenders = <String>[];

  for (final suite in _suites()) {
    final samples = _samplesOf(suite);
    if (samples.isEmpty) continue;
    final name = suite.uri.pathSegments.where((s) => s.isNotEmpty).last;
    final ordinals = samples.map((s) => int.parse(s.ordinal)).toList();

    for (final ordinal in ordinals.toSet()) {
      final count = ordinals.where((o) => o == ordinal).length;
      if (count > 1) offenders.add('$name: $count samples numbered $ordinal');
    }
    for (var expected = 1; expected <= ordinals.reduce(_max); expected++) {
      if (!ordinals.contains(expected))
        offenders.add('$name: no sample $expected');
    }
  }

  return offenders;
}

int _max(int a, int b) => a > b ? a : b;

const _silentReason =
    'A sample opens without a "=== NN: Title ===" banner, so the block it '
    'contributes to its group transcript arrives attached to whichever sample '
    'last named itself — or, if the sample prints nothing at all, does not '
    'arrive, and the sample reads as skipped. Open run() with the banner, '
    'carrying the number the file is filed under.';

const _bannerReason =
    'A sample announces itself with an ordinal that is not the one in its own '
    'file name, or with no ordinal at all. The ordinal is what maps a passage '
    'of the suite transcript back to a source file, and it is the only thing '
    'that does.';

const _labelReason =
    'A group runner prints a per-file label. The sample already names itself, '
    'so this is a second title for one file written in a second place, and the '
    'two drift: of the ten runners that carried one, five had come to disagree '
    'with the sample they introduced. The runner names the group; the sample '
    'names itself.';

const _uncalledReason =
    'A numbered sample is not called by its group runner, so it never runs and '
    'nothing reports when it stops compiling or starts failing. Add the call, '
    'or delete the sample.';

const _sequenceReason =
    'A suite skips an ordinal or uses one twice. The numbering is what a reader '
    'follows from the transcript into the directory, so a gap reads as a '
    'missing sample and a repeat makes two files indistinguishable.';
