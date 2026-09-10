/// Demonstrates extending the stack-trace fold with an application's own
/// framework layer, through the process-wide `tomStackTraceNoise`.
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/little_things/05_stack_trace_noise_example.dart
/// ```
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

/// A trace as an application would see it: two frames from a framework the
/// application depends on, then the application's own handler, then a layer
/// compiled into the application itself, then `main`.
///
/// Written out rather than captured, because a sample has to show the same
/// frames on every machine — a captured trace names the test runner and the
/// paths of whoever ran it.
final StackTrace _incomingTrace = StackTrace.fromString(
  '#0      MyFramework.dispatch (package:my_framework/dispatch.dart:10:5)\n'
  '#1      MyFramework.route (package:my_framework/dispatch.dart:20:5)\n'
  '#2      appHandler (package:my_app/handler.dart:22:7)\n'
  '#3      MyPipeline.run (package:my_app/pipeline.dart:5:3)\n'
  '#4      main (package:my_app/main.dart:3:3)\n',
);

// =============================================================================
// EXAMPLE 1: The default fold leaves a consumer's own layers alone
// =============================================================================

class DefaultFoldExample {
  static List<String> frames = const [];

  static void example1DefaultFold() {
    tomStackTraceNoise.clear();
    frames = tomGetStackTraceAsList(_incomingTrace);

    // The built-in set names core frames, `shelf`, `TomLogger.*` and this
    // library's own formatters. Nothing here is any of those, so all five
    // frames survive — including two that only say the request went through a
    // dispatcher.
    assert(frames.length == 5, 'Every frame should survive the default fold');
    assert(
      frames.first.contains('MyFramework.dispatch'),
      'The dispatcher frame should still be there',
    );
  }
}

// =============================================================================
// EXAMPLE 2: Folding a package the application depends on
// =============================================================================

class PackageFoldExample {
  static List<String> frames = const [];
  static String summaryFrame = '';

  static void example2FoldAPackage() {
    tomStackTraceNoise.clear();
    tomStackTraceNoise.addPackage('my_framework');

    frames = tomGetStackTraceAsList(_incomingTrace);
    summaryFrame = frames.first;

    // Folding *collapses* a contiguous run into one summary frame; it does not
    // delete it. The summary keeps the outermost member of the run and drops
    // the line and column, because it no longer stands for one line of source
    // — exactly what the built-in `shelf` rule does to a fifteen-frame run.
    assert(frames.length == 4, 'The two framework frames become one');
    assert(
      summaryFrame.contains('MyFramework.route'),
      'The summary carries the outermost member of the run',
    );
    assert(
      !summaryFrame.contains('dispatch.dart'),
      'A summary frame has no single source line to point at',
    );
    assert(
      frames[1].contains('handler.dart 22:7'),
      "The application's own frames are untouched",
    );
  }
}

// =============================================================================
// EXAMPLE 3: Folding a layer that has no package of its own
// =============================================================================

class MemberPrefixFoldExample {
  static List<String> frames = const [];

  static void example3FoldAMemberPrefix() {
    tomStackTraceNoise.clear();
    tomStackTraceNoise.addMemberPrefix('MyPipeline.');

    frames = tomGetStackTraceAsList(_incomingTrace);

    // Code compiled into the application shares the application's package
    // name, so there is nothing to match on but the member. Include the
    // trailing `.` so a class whose name merely starts the same way is left
    // alone.
    assert(frames.length == 5, 'A single frame folds to a single summary');
    assert(
      !frames[3].contains('pipeline.dart 5:3'),
      'The pipeline frame should be a summary',
    );
    assert(
      frames[2].contains('handler.dart 22:7'),
      'The fold is per frame, not per trace',
    );
  }
}

// =============================================================================
// EXAMPLE 4: The registration reaches formatters the caller never calls
// =============================================================================

class ReachesTheFrameworkExample {
  static String loggedTrace = '';

  static void example4ReachesTheFramework() {
    tomStackTraceNoise.clear();
    tomStackTraceNoise.addPackage('my_framework');

    final recorder = _RecordingLogOutput();
    final previousOutput = tomLog.logOutput;
    tomLog.logOutput = recorder;
    try {
      // Nothing here passes the classification in — that is the point. The
      // list is process-wide because the traces worth trimming are mostly
      // formatted by the framework, not from the application's call sites.
      tomPrintStackTrace(_incomingTrace, message: 'request failed');
    } finally {
      tomLog.logOutput = previousOutput;
    }

    loggedTrace = recorder.messages.last;
    assert(
      loggedTrace.contains('MyFramework.route'),
      'The summary frame should be in the logged trace',
    );
    assert(
      !loggedTrace.contains('dispatch.dart 10:5'),
      'The folded frame should not be',
    );
  }
}

// =============================================================================
// EXAMPLE 5: A predicate that throws costs a fold, never the report
// =============================================================================

class BrokenPredicateExample {
  static List<String> frames = const [];

  static void example5BrokenPredicate() {
    tomStackTraceNoise.clear();
    tomStackTraceNoise.addPredicate(
      (Frame frame) => throw StateError('this predicate is broken'),
    );
    tomStackTraceNoise.addPackage('my_framework');

    // These functions run while some *other* failure is being reported.
    // Letting a predicate's failure out would lose that report in order to
    // complain about the machinery describing it, so a throwing predicate is
    // read as "not noise" and the ones after it are still asked.
    frames = tomGetStackTraceAsList(_incomingTrace);

    assert(frames.length == 4, 'The later registration still folds');
    assert(
      frames.first.contains('MyFramework.route'),
      'The broken predicate cost nothing but its own fold',
    );

    tomStackTraceNoise.clear();
  }
}

/// Records every logged message so the sample can assert on what was logged
/// rather than on what reached the console.
class _RecordingLogOutput extends TomLogOutput {
  final List<String> messages = <String>[];

  @override
  void output(
    TomLogLevel loggerLevel,
    TomLogLevel logLevel,
    String level,
    Object message,
    String isolateName,
    DateTime timeStamp, [
    String? origin,
  ]) {
    messages.add(convertToString(message));
  }
}

/// Runs the stack-trace noise examples.
void run() {
  print('=== 05: Stack Trace Noise Example ===\n');

  DefaultFoldExample.example1DefaultFold();
  print('1. The default fold leaves a consumer\'s own layers alone:');
  print('   frames kept      : ${DefaultFoldExample.frames.length}');
  print('   first frame      : ${DefaultFoldExample.frames.first}');
  print('');

  PackageFoldExample.example2FoldAPackage();
  print('2. addPackage collapses a run of one package into a summary frame:');
  print('   frames kept      : ${PackageFoldExample.frames.length}');
  print('   summary frame    : ${PackageFoldExample.summaryFrame}');
  print('');

  MemberPrefixFoldExample.example3FoldAMemberPrefix();
  print('3. addMemberPrefix reaches a layer with no package of its own:');
  print('   folded frame     : ${MemberPrefixFoldExample.frames[3]}');
  print('');

  ReachesTheFrameworkExample.example4ReachesTheFramework();
  print('4. The registration reaches formatters the caller never calls:');
  print(
    '   logged trace     : '
    '${ReachesTheFrameworkExample.loggedTrace.split('\n').first}',
  );
  print('');

  BrokenPredicateExample.example5BrokenPredicate();
  print('5. A predicate that throws costs its own fold, never the report:');
  print('   frames kept      : ${BrokenPredicateExample.frames.length}');
  print('   first frame      : ${BrokenPredicateExample.frames.first}');
  print('');
}

void main() {
  prepareSampleProcess();
  run();
}
