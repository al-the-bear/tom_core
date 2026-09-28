/// Holds the launch instructions in `README.md` to what `lib/main.dart` reads.
///
/// **Shared in shape with `advanced_authadmin_client`**, whose
/// `test/documented_launch_test.dart` asks the same questions of the
/// administrator console, so a fix worth making here is worth making there.
///
/// **Why this package has no `example/`, and why that needs a guard.** Every
/// other package in this quest is a library whose `example/` is where a reader
/// sees it used. This one *is* the example: it is one of the eight
/// `advanced_*` packages that together form the full-stack sample, and
/// `flutter run` on the package itself is the demonstration. An `example/`
/// here would either duplicate `lib/main.dart` or isolate a fragment the app
/// already shows in context.
///
/// That makes the README's launch section the thing a reader acts on, and it
/// names a `--dart-define` by literal string. `main.dart` reads that name with
/// `bool.fromEnvironment`, also by literal string, and the two are connected by
/// nothing: renaming the define would leave the documented command silently
/// selecting the default mode — the live stack — instead of the offline one it
/// claims to select. A reader would meet connection errors and no explanation.
///
/// So the name is derived from both sides here and compared, rather than
/// written out: the test cannot drift with the thing it checks.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The `--dart-define=NAME=true` the README tells a reader to pass.
final _documentedDefine = RegExp(r'--dart-define=(\w+)=true');

/// The `bool.fromEnvironment('NAME')` the entry point actually reads.
final _readDefine = RegExp(r"bool\.fromEnvironment\('(\w+)'\)");

void main() {
  final readme = File('README.md').readAsStringSync();
  final entryPoint = File('lib/main.dart').readAsStringSync();

  group('the documented launch matches the code', () {
    test('the package has an entry point to run', () {
      // The claim the missing `example/` rests on: this package is run
      // directly. Without a `lib/main.dart` the README's `flutter run` is an
      // instruction to nowhere.
      expect(File('lib/main.dart').existsSync(), isTrue);
      expect(
        RegExp(
          r'^(?:Future<void>|void)\s+main\(',
          multiLine: true,
        ).hasMatch(entryPoint),
        isTrue,
        reason: 'lib/main.dart declares no entry point',
      );
    });

    test('the README documents both run modes', () {
      expect(
        readme,
        contains('flutter run'),
        reason: 'the live-stack command a reader is told to use',
      );
      expect(
        _documentedDefine.hasMatch(readme),
        isTrue,
        reason:
            'the offline mode is opt-in by a dart-define, and the README '
            'must name it',
      );
    });

    test('the define the README names is the one main.dart reads', () {
      final documented = _documentedDefine
          .allMatches(readme)
          .map((m) => m.group(1)!)
          .toSet();
      final read = _readDefine
          .allMatches(entryPoint)
          .map((m) => m.group(1)!)
          .toSet();

      expect(read, isNotEmpty, reason: 'main.dart reads no dart-define');
      expect(
        documented,
        equals(read),
        reason:
            'README documents $documented; lib/main.dart reads $read. A '
            'documented define that the code does not read selects nothing, '
            'and the run silently falls back to the default mode.',
      );
    });

    test('the README says the package is itself the runnable example', () {
      // The statement this guard exists beside. A reader arriving from a
      // sibling package that *does* ship `example/` cannot otherwise tell a
      // deliberate absence from a missing folder.
      expect(
        readme.toLowerCase(),
        contains('runnable example'),
        reason: 'README.md must say why there is no example/ directory',
      );
      expect(Directory('example').existsSync(), isFalse);
    });

    test('neither deliberately-absent folder has quietly appeared', () {
      // `example/` and `doc/` are both absent on purpose, and the README says
      // so. Adding either would make that sentence wrong, so the sentence and
      // the tree are held together: whichever is added, this fails and the
      // explanation has to be revisited in the same change.
      //
      // The claim is stated once for all fifteen sample packages in
      // `tom_core_samples/README.md`; this asserts only the one package it
      // lives in, which is what a package's own suite can honestly check.
      expect(Directory('doc').existsSync(), isFalse);
      expect(
        readme,
        contains('no `doc/` folder'),
        reason: 'README.md must say why there is no doc/ directory',
      );
    });
  });
}
