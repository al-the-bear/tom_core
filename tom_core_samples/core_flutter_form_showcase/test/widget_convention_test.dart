// G-UI-1 tests: the sample lays out exclusively with Tom widgets, on both of
// the surfaces a reader learns from — the source it ships and the snippets it
// displays.
//
// The rule has real teaching weight here. This sample's documented job includes
// modelling the convention, so one raw `SizedBox` in `lib/` is not a style nit:
// it is the sample contradicting the thing it is demonstrating, in the file a
// reader is most likely to copy. And because every snippet claims to be
// verbatim, a snippet naming `Row` is wrong twice — it misdescribes the child it
// stands beside, and it teaches against the surrounding code.
//
// Both surfaces are checked against ONE vocabulary ([rawFlutterWidgets] below).
// Splitting the list in two is how the two halves would drift apart.

import 'dart:io';

import 'package:core_flutter_form_showcase/common/chrome_texts.dart';
import 'package:core_flutter_form_showcase/reflection_seed.dart';
import 'package:core_flutter_form_showcase/showcase_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  setUpAll(initializeReflection);

  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(showcaseTexts),
    );
  });

  test('no library file builds a raw Flutter widget that has a Tom equivalent',
      () {
    // `MaterialApp` is the sole exemption, and it is a real one rather than a
    // grandfathered case: `tom_flutter_ui` ships no `TomMaterialApp`, because
    // the Tom widgets live *inside* an app rather than replacing its root. The
    // sample switches to Tom immediately below it, at `TomScaffold`.
    const exempt = {'MaterialApp'};

    final lib = Directory('lib');
    expect(lib.existsSync(), isTrue,
        reason: 'tests must run from the package root');

    final offenders = <String>[];
    var filesScanned = 0;

    for (final file in lib
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        // Generated code is the generator's output, not the sample's prose.
        .where((f) => !f.path.endsWith('.reflection.dart'))) {
      filesScanned++;
      final lines = _executableText(file.readAsStringSync()).split('\n');

      for (var i = 0; i < lines.length; i++) {
        for (final match in _rawWidgetCall.allMatches(lines[i])) {
          final name = match.group(1)!;
          if (exempt.contains(name)) continue;
          offenders.add('${file.path}:${i + 1} builds $name, not Tom$name');
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'the sample lays out exclusively with Tom widgets (G-UI-1):\n'
            '${offenders.join("\n")}');

    // A sweep that scans nothing passes trivially; the package has ~20 library
    // files, so anything near zero means the walk broke rather than the code
    // being clean.
    expect(filesScanned, greaterThanOrEqualTo(15));
  });

  testWidgets('no snippet teaches a raw Flutter widget over its Tom equivalent',
      (tester) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    for (final group in showcaseGroups) {
      for (final cell in group.cells(capturedContext)) {
        final hits =
            _rawWidgetCall.allMatches(cell.code).map((m) => m.group(1)).toSet();
        expect(hits, isEmpty,
            reason: 'group "${group.id}", cell "${cell.title}": snippet uses '
                'raw Flutter ${hits.join(", ")} instead of the Tom '
                'equivalent(s)');
      }
    }
  });
}

/// The Flutter widgets this sample never builds directly, because
/// `tom_flutter_ui` ships a `Tom`-prefixed counterpart for each.
///
/// Names only — the regex that uses them adds the boundary and call syntax.
const rawFlutterWidgets = <String>[
  'Row', 'Column', 'Expanded', 'Flexible', 'SizedBox', 'Padding', 'Card',
  'Divider', 'InkWell', 'ListView', 'ListTile', 'Wrap', 'SingleChildScrollView',
  'Stack', 'Positioned', 'DecoratedBox', 'Chip', 'Text', 'Icon', 'IconButton',
  'SelectableText', 'ElevatedButton', 'FilledButton', 'OutlinedButton',
  'TextButton', 'Container', 'Align', 'Scaffold', 'AppBar',
];

/// Matches a direct construction of one of [rawFlutterWidgets].
///
/// The look-behind is what keeps `TomSizedBox(` and `SizedBox.shrink()` out: a
/// preceding identifier character means this is a different name, and a
/// preceding `.` means it is a named constructor or a member access.
final _rawWidgetCall = RegExp(
  r'(?<![A-Za-z0-9_$.])(' + rawFlutterWidgets.join('|') + r')\s*\(',
);

final _commentOrString = RegExp(
  r'/\*[\s\S]*?\*/' // block comment
  r"|//[^\n]*" // line comment
  r'|"(?:[^"\\]|\\.)*"' // double-quoted string
  r"|'(?:[^'\\]|\\.)*'", // single-quoted string
);
final _newline = RegExp(r'[^\n]');

/// [source] reduced to the code that actually runs: comments and string
/// literals blanked out, with every newline kept so reported line numbers still
/// point at the offending line.
///
/// Both removals matter. A `// Why: TomSizedBox, not SizedBox` comment explains
/// the rule and must not be read as breaking it, and a cell's `code` snippet is
/// a string literal whose contents are the *other* test's business.
String _executableText(String source) => source.replaceAllMapped(
    _commentOrString, (m) => m.group(0)!.replaceAll(_newline, ' '));
