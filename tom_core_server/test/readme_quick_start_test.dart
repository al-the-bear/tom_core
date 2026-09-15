import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Why a module's quick start cannot simply be run.
///
/// A quick start is the first code a reader of a module sees, and most of them
/// are complete programs — so the guard for those is to run them. The rest are
/// complete for a *reader* and incomplete for a compiler, and running them is
/// not a thing that can be asked. What can be asked is that they say so: a
/// reader who copies a snippet and gets `Reflection has not been initialized`
/// is owed the sentence that predicted it.
enum _NotRunnable {
  /// Names an identifier the reader supplies — a token, a configuration
  /// subclass, a principal. It does not compile as written, deliberately.
  fragment,

  /// Imports the reader's own generated `main.reflection.dart`.
  needsReflection,

  /// Opens a socket to a database this suite does not require.
  needsDatabase,

  /// Binds a listener and is correct not to return.
  longRunning,
}

/// A module readme's quick start, and what the suite is entitled to ask of it.
///
/// The table below is the module list, not a sample of it: the first test
/// requires it to name every readme in `lib/src/tomserver` that has a "Quick
/// start" heading, so a new module cannot join the package with an unclassified
/// snippet, and a snippet cannot be deleted while its row stays behind.
class _QuickStart {
  const _QuickStart.runnable(this.module, {required this.prints})
    : reason = null,
      reasonPrefix = null;

  const _QuickStart.notRunnable(
    this.module,
    this.reason, {
    required this.reasonPrefix,
  }) : prints = const [];

  /// The directory under `lib/src/tomserver` whose `readme.md` this is.
  final String module;

  /// `null` for a snippet the suite runs.
  final _NotRunnable? reason;

  /// The opening of the blockquote the readme must carry under the snippet.
  ///
  /// Held to a prefix rather than the whole note: the sentence explaining a
  /// snippet belongs to whoever writes the module, and a test that pinned it
  /// word for word would be a test of the prose rather than of its presence.
  /// The prefix is enough to establish that the note is the *right* one — that
  /// it is about being unrunnable and not about something else.
  final String? reasonPrefix;

  /// Fragments the program must print. Empty is not allowed for a runnable
  /// snippet: exit 0 is also what a program that does nothing returns.
  final List<String> prints;

  bool get isRunnable => reason == null;

  String get readmePath =>
      p.join('lib', 'src', 'tomserver', module, 'readme.md');
}

/// The triage. Fourteen programs, five explanations.
const _quickStarts = <_QuickStart>[
  _QuickStart.runnable('authentication', prints: ['alice', 'TomPrincipal']),
  _QuickStart.runnable('cache', prints: ['hello']),
  _QuickStart.runnable('cmdline', prints: ['8080', 'localhost', 'true']),
  _QuickStart.runnable('configuration', prints: ['8080', 'localhost']),
  _QuickStart.runnable('db_migration', prints: ['1', 'create todo tables']),
  _QuickStart.runnable('healthcheck', prints: ['OK']),
  _QuickStart.runnable(
    'little_things',
    prints: ['error.order.not-found', 'true'],
  ),
  _QuickStart.runnable('messaging', prints: ['email', 'delivered']),
  _QuickStart.runnable('object_persistence', prints: ['write the readme']),
  _QuickStart.runnable('transactions', prints: ['true']),
  _QuickStart.runnable('audit', prints: ['Invoice', 'true']),
  _QuickStart.runnable('export', prints: ['true']),
  _QuickStart.runnable('file_storage', prints: ['12', 'total: 19.99']),
  _QuickStart.runnable('resources', prints: ['Ihre Rechnung', 'null']),

  _QuickStart.notRunnable(
    'authorization',
    _NotRunnable.fragment,
    reasonPrefix: '> **A fragment, not a program.**',
  ),
  _QuickStart.notRunnable(
    'datasources',
    _NotRunnable.needsDatabase,
    reasonPrefix: '> **Needs a live database.**',
  ),
  _QuickStart.notRunnable(
    'endpoints',
    _NotRunnable.needsReflection,
    reasonPrefix: "> **Needs your package's generated reflection.**",
  ),
  // The snippet is the *deployment* sequence, so it still opens a socket and
  // still needs the consuming package's generated reflection. What changed is
  // that there is now a program to point at: the blockquote's job is no longer
  // to explain an absence but to send the reader to
  // `example/preferences/preferences_example.dart`, which runs the same
  // sequence with the table substituted.
  _QuickStart.notRunnable(
    'preferences',
    _NotRunnable.needsDatabase,
    reasonPrefix: '> **This is the deployment sequence, and it opens a real',
  ),
  _QuickStart.notRunnable(
    'scheduling',
    _NotRunnable.needsReflection,
    reasonPrefix:
        "> **Needs your package's generated reflection and a live database.**",
  ),
  _QuickStart.notRunnable(
    'server',
    _NotRunnable.longRunning,
    reasonPrefix: '> **A long-running service, and a fragment.**',
  ),
];

/// The `dart` block under a readme's "Quick start" heading, plus the first
/// non-blank line after it — which is where the not-runnable note goes.
({String source, String? noteLine}) _quickStartOf(String readmePath) {
  final lines = File(readmePath).readAsLinesSync();
  final heading = lines.indexWhere((l) => l.trim() == '## Quick start');
  expect(heading, greaterThanOrEqualTo(0), reason: '$readmePath: no heading');
  final open = lines.indexWhere((l) => l.trim() == '```dart', heading);
  expect(open, greaterThan(heading), reason: '$readmePath: no dart block');
  final close = lines.indexWhere((l) => l.trim() == '```', open + 1);
  expect(close, greaterThan(open), reason: '$readmePath: unterminated block');

  final after = lines
      .sublist(close + 1)
      .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
  return (source: lines.sublist(open + 1, close).join('\n'), noteLine: after);
}

/// What compiling `package:tom_core_server` is allowed to cost.
///
/// Deliberately generous, because it is not measuring anything. It exists so a
/// pathological compile fails as a compile instead of hanging the suite, and
/// the number can be loose precisely because nothing is being inferred from it.
/// Measured on this package: ~2.5s on an unloaded machine, 14.5s with the
/// machine oversubscribed twelve-fold.
const _compileDeadline = Duration(seconds: 60);

/// What the snippet itself is allowed to cost, once it is already compiled.
///
/// This is the deadline that means something, and it is tight because the work
/// it bounds is small and barely load-sensitive: ~0.35s unloaded, 0.63s with
/// the machine oversubscribed twelve-fold. Fifteen seconds is more than twenty
/// times the worst measurement, so a breach is a snippet that does not return,
/// not a machine having a bad minute.
const _runDeadline = Duration(seconds: 15);

/// Starts `dart [arguments]`, collects both its streams, and waits for it.
///
/// Returns `null` if it had not exited within [deadline]. The child is killed
/// on that path, so a snippet that never returns cannot outlive the test that
/// started it.
Future<({int exitCode, String output})?> _awaitProcess(
  List<String> arguments,
  Duration deadline,
) async {
  final process = await Process.start(Platform.resolvedExecutable, arguments);
  final out = StringBuffer();
  final drained = Future.wait([
    process.stdout.transform(utf8.decoder).forEach(out.write),
    process.stderr.transform(utf8.decoder).forEach(out.write),
  ]);
  try {
    final exitCode = await process.exitCode.timeout(deadline);
    await drained;
    return (exitCode: exitCode, output: out.toString());
  } on TimeoutException {
    process.kill(ProcessSignal.sigkill);
    await process.exitCode;
    return null;
  }
}

/// Compiles [source] to a kernel snapshot, runs the snapshot, and returns what
/// running it did.
///
/// Written under `.dart_tool/` for two reasons: it is gitignored, so a scratch
/// file cannot be committed by accident, and it is inside the package, so the
/// snippet's `package:tom_core_server` import resolves against the real
/// `package_config.json` rather than a synthesised one.
///
/// **Why two phases and not `dart run snippet.dart`.** The regression this file
/// catches is a snippet that never returns, and a deadline is the only way to
/// catch it. But `dart run` on a source file compiles the whole
/// `package:tom_core_server` graph *and then* executes it under one deadline,
/// and those two costs are wildly asymmetric: ~2.5s to compile against ~0.35s
/// to run, so seven-eighths of a single deadline is spent on the part nobody is
/// asking about. Only that part is load-sensitive, too. Measured with the
/// machine saturated, compilation stretched to 14.5s while execution stayed at
/// 0.63s, and `dart run` on the source took 26.7s — past the 25s this file used
/// to allow, failing with a message that said the snippet did not terminate
/// about a program that terminates in half a second.
///
/// That is not a threshold that wants raising. Raising it buys a slower true
/// failure and leaves the two causes indistinguishable, which is the actual
/// damage: a reader who has seen this test cry wolf discounts it the day it is
/// right. Giving compilation its own budget and its own message leaves the
/// termination deadline measuring termination — and lets it be *tighter* than
/// the one it replaces rather than looser.
Future<({int exitCode, String output})> _run(
  String module,
  String source,
) async {
  final script = File(p.join('.dart_tool', 'quick_start_$module.dart'));
  final snapshot = File(p.join('.dart_tool', 'quick_start_$module.dill'));
  script.writeAsStringSync(source);
  addTearDown(() {
    if (script.existsSync()) script.deleteSync();
    if (snapshot.existsSync()) snapshot.deleteSync();
  });

  final compiled = await _awaitProcess([
    'compile',
    'kernel',
    script.path,
    '-o',
    snapshot.path,
  ], _compileDeadline);
  if (compiled == null) {
    fail(
      "compiling the $module readme's quick start did not finish within "
      '${_compileDeadline.inSeconds}s. That is the cost of the '
      '`package:tom_core_server` graph on a busy machine and says nothing '
      'about whether the snippet terminates — which has not been tested yet.',
    );
  }
  if (compiled.exitCode != 0) {
    fail(
      "the $module readme's quick start does not compile:\n${compiled.output}",
    );
  }

  // Only this phase is timed against the snippet's own behaviour, and only its
  // output is returned — so what the caller matches against `prints` is the
  // program's output alone, with none of the compiler's chatter in it.
  final ran = await _awaitProcess(['run', snapshot.path], _runDeadline);
  if (ran == null) {
    fail(
      "the $module readme's quick start did not terminate within "
      '${_runDeadline.inSeconds}s of being started. It was already compiled by '
      'then, so this is the snippet: a periodic timer, an open socket or a '
      'bound listener all keep an isolate alive, so a snippet that creates one '
      'has to release it — or say in the readme that it is not a program meant '
      'to be run.',
    );
  }
  return ran;
}

void main() {
  group('Every module readme quick start', () {
    test('is classified by the table in this file', () {
      // The guard the rest of the file rests on. Running ten snippets proves
      // nothing about an eleventh nobody remembered to add, so the set of
      // readmes carrying a "Quick start" heading is read off disk and required
      // to be exactly the set this table names.
      final onDisk =
          Directory(p.join('lib', 'src', 'tomserver'))
              .listSync()
              .whereType<Directory>()
              .map((d) => p.basename(d.path))
              .where((m) {
                final readme = File(
                  p.join('lib', 'src', 'tomserver', m, 'readme.md'),
                );
                return readme.existsSync() &&
                    readme.readAsLinesSync().any(
                      (l) => l.trim() == '## Quick start',
                    );
              })
              .toList()
            ..sort();

      final classified = _quickStarts.map((q) => q.module).toList()..sort();
      expect(
        classified,
        onDisk,
        reason:
            'a module readme grew or lost a "Quick start" heading without the '
            'table in test/readme_quick_start_test.dart following it. Add a '
            'row: either the snippet is a program the suite runs, or the '
            'readme says why it is not one.',
      );
    });

    for (final quickStart in _quickStarts.where((q) => q.isRunnable)) {
      test(
        'that is a program terminates: ${quickStart.module}',
        () async {
          final source = _quickStartOf(quickStart.readmePath).source;
          final result = await _run(quickStart.module, source);

          expect(
            result.exitCode,
            0,
            reason:
                "the ${quickStart.module} readme's quick start failed:\n"
                '${result.output}',
          );
          // Exit 0 alone is also what a snippet that printed nothing returns,
          // so pin the output its own `// comment` annotations promise. That is
          // what makes the snippet's *claims* checkable and not just its
          // compilation.
          for (final fragment in quickStart.prints) {
            expect(result.output, contains(fragment));
          }
        },
        // Has to outlast both of _run's own deadlines together (60s + 15s), so
        // that whichever of them is breached gets to report what happened. If
        // the framework's timeout fired first the test would say only "timed
        // out", which is the undiagnosable failure this file exists to avoid.
        timeout: const Timeout(Duration(minutes: 2)),
      );
    }

    for (final quickStart in _quickStarts.where((q) => !q.isRunnable)) {
      test('that is not a program says so: ${quickStart.module}', () {
        // A snippet a reader cannot run is fine; one that does not admit it is
        // not. The note is required directly under the block, where someone
        // about to copy the code is looking, rather than further down the page
        // where it would be read after the failure it was meant to prevent.
        final note = _quickStartOf(quickStart.readmePath).noteLine;
        expect(
          note,
          startsWith(quickStart.reasonPrefix!),
          reason:
              'the ${quickStart.module} readme is classified '
              '${quickStart.reason!.name} in test/readme_quick_start_test.dart, '
              'so the line under its quick start must be the blockquote saying '
              'so. Found: ${note!.isEmpty ? '(nothing)' : note}',
        );
      });
    }
  });

  test('the endpoints quick start matches the fixture the suite serves', () {
    // The endpoints readme claims its `TodoApi` / `TodoApiServer` pair is
    // verbatim identical to the fixture that `endpoints_pipeline_test.dart`
    // compiles, mounts and serves — which is what lets the readme say the
    // snippet works despite being one of the five the suite cannot run. That
    // claim carries the whole module's quick start, so it is worth more than
    // the reader's willingness to believe it.
    //
    // Compared without comments or blank lines: the fixture carries dartdoc the
    // readme has no room for, and requiring those to match too would make the
    // pair impossible to keep identical rather than merely required to be.
    List<String> code(String source) => source
        .split('\n')
        .map((l) => l.trimRight())
        .where((l) => l.isNotEmpty && !l.trimLeft().startsWith('//'))
        .toList();

    const opening = '@tomReflector\n@tomService\nabstract class TodoApi';

    final readme = _quickStartOf(
      p.join('lib', 'src', 'tomserver', 'endpoints', 'readme.md'),
    ).source;
    final fixture = File(
      p.join('test', 'fixtures', 'reflection_fixture.dart'),
    ).readAsStringSync();

    // The readme's pair is everything from the declaration's first line up to
    // its `main`; the fixture's is the same many lines from the same opening.
    final fromReadme = code(
      readme.substring(readme.indexOf(opening)),
    ).takeWhile((l) => l != 'void main() {').toList();
    final fromFixture = code(
      fixture.substring(fixture.indexOf(opening)),
    ).take(fromReadme.length).toList();

    expect(fromReadme, isNotEmpty, reason: 'no TodoApi pair in the readme');
    expect(
      fromFixture,
      fromReadme,
      reason:
          'the endpoints readme and test/fixtures/reflection_fixture.dart have '
          'drifted apart. The readme tells a reader the pair it shows is the '
          'one the suite serves; keep them identical, or stop claiming it.',
    );
  });
}
