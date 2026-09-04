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

/// The triage. Ten programs, five explanations.
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
  _QuickStart.notRunnable(
    'preferences',
    _NotRunnable.needsReflection,
    reasonPrefix: "> **Needs your package's generated reflection, a live",
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

/// Runs [source] as a program and returns what it did.
///
/// Written under `.dart_tool/` for two reasons: it is gitignored, so a scratch
/// file cannot be committed by accident, and it is inside the package, so the
/// snippet's `package:tom_core_server` import resolves against the real
/// `package_config.json` rather than a synthesised one.
Future<({int exitCode, String output})> _run(
  String module,
  String source,
) async {
  final script = File(p.join('.dart_tool', 'quick_start_$module.dart'));
  script.writeAsStringSync(source);
  addTearDown(() {
    if (script.existsSync()) script.deleteSync();
  });

  final process = await Process.start(Platform.resolvedExecutable, [
    'run',
    script.path,
  ]);
  final out = StringBuffer();
  final drained = Future.wait([
    process.stdout.transform(utf8.decoder).forEach(out.write),
    process.stderr.transform(utf8.decoder).forEach(out.write),
  ]);

  // The watchdog is half the point of this file. The regression it catches is a
  // program that never returns, and without a deadline that is a suite that
  // never finishes — a hang reported as a hang says far less than a hang
  // reported as this failure. It fires well before the framework's own 30s
  // default, hence the explicit Timeout on each test.
  int exitCode;
  try {
    exitCode = await process.exitCode.timeout(const Duration(seconds: 25));
  } on TimeoutException {
    process.kill(ProcessSignal.sigkill);
    await process.exitCode;
    fail(
      "the $module readme's quick start did not terminate within 25s. A "
      'periodic timer, an open socket or a bound listener all keep an isolate '
      'alive, so a snippet that creates one has to release it — or say in the '
      'readme that it is not a program meant to be run.',
    );
  }
  await drained;
  return (exitCode: exitCode, output: out.toString());
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
