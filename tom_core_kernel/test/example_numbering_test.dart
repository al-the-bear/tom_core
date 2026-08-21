import 'dart:io';

import 'package:test/test.dart';

/// The sample suite prints one long transcript, and a reader mapping a passage
/// of it back to a source file has only the ordinal to do it with.
///
/// Two places emit that ordinal, and they are written months apart by different
/// hands:
///
/// 1. **The file's own banner** — `=== 03: Shutdown Execution Example ===`, or
///    the boxed `03: ADVANCED ACCESS CONTROL EXAMPLE` between two rules.
/// 2. **The group runner's label** — `00_run_all_examples.dart` printing
///    `03: Shutdown Execution Example` immediately before the call.
///
/// Renumbering a directory renames the files but touches neither string, so
/// both drift silently: the suite still passes, and the transcript simply
/// points at the wrong source. Roughly a dozen files have carried a stale or
/// absent ordinal at one time or another, which is what makes this worth a
/// test rather than a periodic sweep.
///
/// Where a runner prints no per-example label — `security`, `timezoned`,
/// `observable` and friends call `run()` in bare sequence — the banner is the
/// *only* label the output carries, so an absent ordinal there leaves a
/// hundred lines of output attributed to whatever ran before.
void main() {
  // ===========================================================================
  // Example numbering
  // ===========================================================================
  group('example numbering', () {
    test('every sample banner announces the sample\'s own ordinal', () {
      expect(_bannerOrdinalMismatches(), isEmpty, reason: _bannerReason);
    });

    test('every runner label agrees with the file it introduces', () {
      expect(_runnerLabelMismatches(), isEmpty, reason: _labelReason);
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
      expect(_announcements(), hasLength(greaterThanOrEqualTo(50)));
      expect(_runnerLabels(), hasLength(greaterThanOrEqualTo(35)));
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

/// `print('=== 03: Title ===\n');` — the form 50-odd samples use.
final _styleABanner = RegExp(r"""^\s*print\(\s*'===\s*(.*?)\s*===""");

/// A horizontal rule, in either the ASCII or the box-drawing character. The
/// boxed banners print one, then their title, then another.
final _rule = RegExp(r"""^\s*print\(\s*'[=═]{5,}""");

/// A `print` of a single string literal and nothing else.
final _printLiteral = RegExp(r"""^\s*print\(\s*'(.*?)'\s*\)\s*;""");

/// `print('\n03: Shutdown Execution Example');` in a group runner.
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

/// A `NN: Title` line a group runner prints before calling a sample.
class _RunnerLabel {
  _RunnerLabel(this.runner, this.ordinal, this.title, this.target);

  final String runner;
  final String ordinal;
  final String title;

  /// The sample the label introduces, resolved through the runner's imports.
  final _Sample? target;
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
/// A sample that prints nothing at all — the assert-driven ones, of which
/// there are dozens — announces nothing and is correct not to. What this
/// collects is the samples that *do* announce themselves, so the ordinal they
/// use can be checked.
List<_Announcement> _announcements() {
  final found = <_Announcement>[];

  for (final sample in _allSamples()) {
    final lines = sample.file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final styleA = _styleABanner.firstMatch(lines[i]);
      if (styleA != null) {
        found.add(_Announcement(sample, i + 1, styleA.group(1)!));
        continue;
      }
      // A boxed banner is the title line between two rules; recognising it
      // structurally rather than by its wording keeps the check working when
      // somebody rewords a title.
      if (i == 0 || !_rule.hasMatch(lines[i - 1])) continue;
      final literal = _printLiteral.firstMatch(lines[i]);
      if (literal == null) continue;
      found.add(_Announcement(sample, i + 1, literal.group(1)!));
    }
  }

  return found;
}

/// Every `NN: Title` label a group runner prints before a sample call.
///
/// Roughly half the runners print these; the rest call `run()` in bare
/// sequence and leave the labelling to the samples' own banners.
List<_RunnerLabel> _runnerLabels() {
  final labels = <_RunnerLabel>[];

  for (final suite in _suites()) {
    final runner = File('${suite.path}/00_run_all_examples.dart');
    final byName = {for (final s in _samplesOf(suite)) s.name: s};

    final lines = runner.readAsLinesSync();
    final targets = {
      for (final import in _aliasedImport.allMatches(runner.readAsStringSync()))
        import.group(2)!: byName[import.group(1)!],
    };

    // A label binds to the next `run()` call, which is the sample it
    // introduces. Anything else printed in between (the rule under the
    // heading) is not a label and does not break the pairing.
    ({String ordinal, String title})? pending;
    for (final line in lines) {
      if (_commentedOut.hasMatch(line)) continue;
      final label = _runnerLabel.firstMatch(line);
      if (label != null) {
        pending = (ordinal: label.group(1)!, title: label.group(2)!);
        continue;
      }
      final call = _runCall.firstMatch(line);
      if (call == null || pending == null) continue;
      labels.add(
        _RunnerLabel(
          '${suite.uri.pathSegments.where((s) => s.isNotEmpty).last}/'
          '00_run_all_examples.dart',
          pending.ordinal,
          pending.title,
          targets[call.group(1)!],
        ),
      );
      pending = null;
    }
  }

  return labels;
}

// -----------------------------------------------------------------------------
// The four rules
// -----------------------------------------------------------------------------

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

/// Runner labels that name an ordinal the file does not carry, or a title the
/// file's own banner spells differently.
List<String> _runnerLabelMismatches() {
  final offenders = <String>[];
  final bannerTitles = {
    for (final a in _announcements())
      a.sample.where: _leadingOrdinal.firstMatch(a.text)?.group(2),
  };

  for (final label in _runnerLabels()) {
    final target = label.target;
    if (target == null) {
      offenders.add(
        '${label.runner}: label ${label.ordinal} introduces a '
        'call whose import resolves to no numbered sample',
      );
      continue;
    }
    if (label.ordinal != target.ordinal) {
      offenders.add(
        '${label.runner}: label says ${label.ordinal}, '
        'introduces ${target.name}',
      );
    }
    final banner = bannerTitles[target.where];
    // Only the plain banners are comparable: the boxed ones shout their title
    // in capitals, which is a styling choice rather than a different name.
    if (banner == null || banner.toUpperCase() == banner) continue;
    if (banner != label.title) {
      offenders.add(
        '${target.where}: runner calls it "${label.title}", '
        'the banner calls it "$banner"',
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

const _bannerReason =
    'A sample announces itself with an ordinal that is not the one in its own '
    'file name, or with no ordinal at all. The ordinal is what maps a passage '
    'of the suite transcript back to a source file, and where the group runner '
    'prints no label it is the only thing that does.';

const _labelReason =
    'A group runner introduces a sample under an ordinal or a title the sample '
    'itself does not use, so one run of the suite emits two different names '
    'for the same file.';

const _uncalledReason =
    'A numbered sample is not called by its group runner, so it never runs and '
    'nothing reports when it stops compiling or starts failing. Add the call, '
    'or delete the sample.';

const _sequenceReason =
    'A suite skips an ordinal or uses one twice. The numbering is what a reader '
    'follows from the transcript into the directory, so a gap reads as a '
    'missing sample and a repeat makes two files indistinguishable.';
