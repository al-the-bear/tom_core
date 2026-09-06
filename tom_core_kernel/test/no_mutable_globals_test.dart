/// The package declares no reassignable top-level variable.
///
/// A public `var` at the top level is shared, writable state with no owner:
/// every importer sees the same slot, any one of them may replace it, and the
/// replacement is immediately visible to all the others. Nothing announces the
/// swap and nothing can prevent it, so the coupling exists whether or not
/// anybody uses it.
///
/// This has been swept by hand twice — once across the `json` module
/// (`indentEncoder`, `_namePattern`, and a merger singleton) and once for
/// `tomExecutionContext`, the ambient context in `context/`. A third sweep is
/// what a test is for. `dart analyze` does not report it: a mutable global is
/// legal Dart, and none of the lint rules this package enables covers it.
///
/// The rule is deliberately about *reassignment*, not about mutation. A `final`
/// holding a growable collection is still mutable content, and several here are
/// — `TomExecutionContext.contextMap` is filled after construction. Those are a
/// different question, decided per type by whoever owns it; what this file
/// refuses is the slot itself being swapped.
library;

import 'dart:io';

import 'package:test/test.dart';

/// A top-level declaration that binds a name to a value.
///
/// Anchored at column 0, because that is what makes it top-level — a field
/// inside a class is indented and is the class's business. The name is the
/// captured group.
final _topLevelBinding = RegExp(
  r'^(?:late\s+)?(?!final\b|const\b|typedef\b)'
  r'(?:var\b|[A-Za-z_][\w<>,\s?\[\]]*?\s)\s*(\w+)\s*=',
);

/// Declarations that bind a name at column 0 but are not variables.
///
/// A getter and an expression-bodied function both read as `Type name =>`, and
/// an annotation or directive can start a line that later contains `=`.
bool _isNotAVariable(String line) =>
    line.contains('=>') ||
    line.contains('(') && line.indexOf('(') < line.indexOf('=') ||
    RegExp(
      r'^(import|export|library|part|enum|class|mixin|extension|'
      r'abstract|sealed|base|interface|@|//|/\*|\*)',
    ).hasMatch(line);

/// Every `(file, line, source)` in `lib/` that binds a reassignable global.
List<(String, int, String)> mutableGlobals() {
  final found = <(String, int, String)>[];
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      // Generated mirrors are machine-written and not edited by hand; the
      // convention is about what an author declares.
      .where((f) => !f.path.endsWith('.reflection.dart'));

  for (final file in files) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty || line.startsWith(' ')) continue;
      if (_isNotAVariable(line)) continue;
      if (_topLevelBinding.hasMatch(line)) {
        found.add((file.path, i + 1, line.trim()));
      }
    }
  }
  return found;
}

void main() {
  group('no reassignable top-level state', () {
    test('lib/ declares no mutable global', () {
      final found =
          mutableGlobals().map((f) => '${f.$1}:${f.$2}  ${f.$3}').toList()
            ..sort();

      expect(
        found,
        isEmpty,
        reason:
            'these top-level bindings are neither final nor const, so any '
            'importer can replace them for every other importer. Make them '
            'final, or — if a swap point is genuinely wanted — give it an '
            'explicit named setter that says so: $found',
      );
    });

    test('the scan reads the files it claims to', () {
      // A scan that matched nothing would satisfy the check above while
      // proving nothing, which is the failure mode a zero-result test has.
      // So: the scanner must find a deliberately planted global, and must
      // still pass over the shapes that merely look like one.
      final planted = File('lib/src/zz_mutable_global_probe.dart')
        ..writeAsStringSync('''
var plantedMutableGlobal = 1;
final plantedFinal = 2;
const plantedConst = 3;
typedef PlantedAlias = void Function();
int get plantedGetter => 4;
int plantedFunction(int a) => a;
''');
      addTearDown(() => planted.deleteSync());

      final names = mutableGlobals()
          .where((f) => f.$1.contains('zz_mutable_global_probe'))
          .map((f) => f.$3)
          .toList();

      expect(
        names,
        equals(['var plantedMutableGlobal = 1;']),
        reason:
            'the scanner must catch the planted `var` and nothing else in '
            'that file — a final, a const, a typedef, a getter and a function '
            'all bind a name at column 0 without being reassignable state',
      );
    });
  });
}
