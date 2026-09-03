/// Pins `AclFlags` against the two things that can make it lie: the engine
/// that is supposed to read each flag, and the reference table that documents
/// them.
///
/// **The failures this exists to stop.** `AclFlags` is a public vocabulary — a
/// caller ORs a constant into `AclComponent.flags` and expects the container to
/// act on it. Nothing enforces that expectation. Two flags, `panelBackground`
/// and `charDim`, were declared with dartdoc describing real behaviour ("follow
/// the parent container background", "sizes are in character units") and listed
/// in the reference's flag table with their bit values — and the container
/// never read either one. A caller could set them, read them back, and see
/// nothing happen, with both the source and the documentation insisting they
/// worked.
///
/// The mirror-image failure is the table drifting from the class: a flag added
/// to `AclFlags` and never documented is invisible, and a documented bit value
/// that no longer matches the constant is worse than no table at all, because
/// bit arithmetic done from it produces a silently wrong mask.
///
/// So all three sides are derived and compared: the constants come from
/// [_flagsSource], the bits the engine reads come from grepping `lib/`, and the
/// documented bits come from the reference's own table.
///
/// **Why "is it read" is the load-bearing check.** It is the only one of the
/// three that catches a flag which is *consistently* documented and completely
/// inert — the exact shape of the `panelBackground` defect, where source and
/// document agreed with each other and both disagreed with the engine.
///
/// **`gapElement` is checked behaviourally, not just textually.** It is the one
/// flag whose meaning is destructive: a component carrying it is replaced by a
/// spacer and its `child` is never built. The dartdoc, the module reference and
/// the design specification all now say so, and a claim that specific deserves
/// a test that actually renders rather than one that greps for the sentence.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// The flag declarations, the reference that documents them, and the library
/// whose sources must contain a read of each one. Paths are package-relative;
/// `flutter test` runs with the package root as its working directory.
const _flagsSource = 'lib/src/advanced_container_layout/acl_flags.dart';
const _docPath = 'doc/advanced_container_layout.md';
const _libDir = 'lib';

/// The heading of the reference section holding the flag table.
const _flagsHeading = 'Layout attribute flags';

/// A flag as declared: its name and its resolved integer value.
///
/// Composites (`otherDim = otherDimX | otherDimY`) are resolved against the
/// literals already parsed, so the table is checked against the value the
/// constant really has rather than against a second hand-maintained number.
Map<String, int> _declaredFlags() {
  final source = File(_flagsSource).readAsStringSync();
  final decl = RegExp(
    r'^\s*static const int\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*([^;]+);',
    multiLine: true,
  );
  final flags = <String, int>{};
  for (final m in decl.allMatches(source)) {
    final name = m.group(1)!;
    final expr = m.group(2)!.trim();
    final literal = int.tryParse(expr);
    if (literal != null) {
      flags[name] = literal;
      continue;
    }
    // A composite: OR together terms that must already be known.
    var value = 0;
    for (final term in expr.split('|').map((t) => t.trim())) {
      final resolved = flags[term];
      expect(
        resolved,
        isNotNull,
        reason:
            '$_flagsSource declares `$name = $expr`, and `$term` is '
            'neither an integer literal nor a flag declared above it — this '
            'test cannot resolve the value the constant actually has',
      );
      value |= resolved!;
    }
    flags[name] = value;
  }
  return flags;
}

/// The dartdoc comment block immediately preceding each flag declaration.
Map<String, String> _flagDartdoc() {
  final lines = File(_flagsSource).readAsStringSync().split('\n');
  final decl = RegExp(r'^\s*static const int\s+([A-Za-z_][A-Za-z0-9_]*)\s*=');
  final docs = <String, String>{};
  for (var i = 0; i < lines.length; i++) {
    final m = decl.firstMatch(lines[i]);
    if (m == null) continue;
    final buffer = <String>[];
    for (var j = i - 1; j >= 0; j--) {
      final line = lines[j].trim();
      if (line.startsWith('///')) {
        buffer.insert(0, line.substring(3).trim());
        continue;
      }
      break;
    }
    docs[m.group(1)!] = buffer.join(' ');
  }
  return docs;
}

/// Source with comments removed, so that a flag *mentioned* in prose is not
/// mistaken for a flag the engine acts on.
///
/// Without this the check below would accept a dartdoc reference as evidence
/// of use, which is exactly the sort of paper agreement it exists to reject.
String _withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .split('\n')
    .map((line) {
      final start = line.indexOf('//');
      return start < 0 ? line : line.substring(0, start);
    })
    .join('\n');

/// Every `AclFlags.<name>` read in the executable text of `lib/`, excluding the
/// declaration file itself — a constant referring to its own siblings is not
/// the engine acting on it.
Set<String> _flagsReadByEngine() {
  final read = <String>{};
  final use = RegExp(r'\bAclFlags\.([A-Za-z_][A-Za-z0-9_]*)\b');
  for (final entity in Directory(_libDir).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.path.endsWith('acl_flags.dart')) continue;
    final code = _withoutComments(entity.readAsStringSync());
    for (final m in use.allMatches(code)) {
      read.add(m.group(1)!);
    }
  }
  return read;
}

/// The `## [heading]` section body, up to the next `## ` heading.
String _section(String heading) {
  final doc = File(_docPath).readAsStringSync();
  final start = doc.indexOf('\n## $heading\n');
  if (start < 0) return '';
  final end = doc.indexOf('\n## ', start + 4);
  return doc.substring(start, end < 0 ? doc.length : end);
}

/// The flag table parsed to name → documented bit.
///
/// Rows pair related flags — ``​`expandX` / `expandY` | 1 / 2​`` — so both cells
/// are split on `/` and zipped. A row whose two cells disagree in length is a
/// malformed row and is reported as such rather than silently half-read.
Map<String, int> _documentedFlags() {
  final documented = <String, int>{};
  for (final line in _section(_flagsHeading).split('\n')) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('|')) continue;
    final cells = trimmed.split('|');
    if (cells.length < 3) continue;
    final names = RegExp(
      r'`([A-Za-z_][A-Za-z0-9_]*)`',
    ).allMatches(cells[1]).map((m) => m.group(1)!).toList();
    if (names.isEmpty) continue; // header or separator row
    final bits = RegExp(
      r'\d+',
    ).allMatches(cells[2]).map((m) => int.parse(m.group(0)!)).toList();
    expect(
      bits.length,
      names.length,
      reason:
          'the flag table row for ${names.join(" / ")} lists '
          '${bits.length} bit value(s) for ${names.length} flag(s), so the '
          'row cannot be read unambiguously',
    );
    for (var i = 0; i < names.length; i++) {
      documented[names[i]] = bits[i];
    }
  }
  return documented;
}

void main() {
  group('every declared flag is one the container acts on', () {
    test('no flag is declared and never read', () {
      // The defect that actually shipped: a flag a caller can set, whose
      // dartdoc and table entry describe behaviour, and which the layout
      // never consults.
      final inert =
          _declaredFlags().keys
              .where((name) => !_flagsReadByEngine().contains(name))
              .toList()
            ..sort();
      expect(
        inert,
        isEmpty,
        reason:
            'these flags are declared in $_flagsSource but read nowhere '
            'in $_libDir/, so setting one does nothing while both the '
            'dartdoc and the reference table imply it works:\n'
            '${inert.map((f) => '  $f').join('\n')}',
      );
    });
  });

  group('the reference table matches the declarations', () {
    test('every declared flag is documented, with its real bit value', () {
      final declared = _declaredFlags();
      final documented = _documentedFlags();
      expect(
        documented,
        isNotEmpty,
        reason:
            '$_docPath has no readable flag table under '
            '"## $_flagsHeading"',
      );

      final problems = <String>[];
      for (final entry in declared.entries) {
        final shown = documented[entry.key];
        if (shown == null) {
          problems.add('${entry.key} (= ${entry.value}) is not in the table');
        } else if (shown != entry.value) {
          problems.add(
            '${entry.key} is documented as $shown but declared as '
            '${entry.value}',
          );
        }
      }
      expect(
        problems,
        isEmpty,
        reason:
            'the flag table in $_docPath disagrees with $_flagsSource:\n'
            '${problems.map((p) => '  $p').join('\n')}',
      );
    });

    test('the table documents no flag that does not exist', () {
      // The drift a rename or a removal produces, and what keeps the check
      // above from being satisfiable by padding the table.
      final declared = _declaredFlags().keys.toSet();
      final invented =
          _documentedFlags().keys.where((f) => !declared.contains(f)).toList()
            ..sort();
      expect(
        invented,
        isEmpty,
        reason:
            'the flag table names these flags, which $_flagsSource does '
            'not declare:\n${invented.map((f) => '  $f').join('\n')}',
      );
    });
  });

  group('no flag disclaims itself as internal', () {
    // AclFlags has a private constructor and is exported from the package
    // barrel, so every constant on it is public by construction. A dartdoc
    // calling one "internal" tells a reader not to touch a value the model
    // hands them back through AclComponent — and leaves the gap components
    // the documents describe unexplained.
    test('no flag dartdoc marks a public constant as internal', () {
      final disclaimed =
          _flagDartdoc().entries
              .where(
                (e) => RegExp(
                  r'\b(internal|private|do not use)\b',
                  caseSensitive: false,
                ).hasMatch(e.value),
              )
              .map((e) => e.key)
              .toList()
            ..sort();
      expect(
        disclaimed,
        isEmpty,
        reason:
            'these flags are exported publicly but their dartdoc warns '
            'the reader off, which contradicts both the reference table and '
            'the getters on AclComponent that read them back:\n'
            '${disclaimed.map((f) => '  $f').join('\n')}',
      );
    });
  });

  group('gapElement means what all three descriptions now say', () {
    test('gap() marks its slot with gapElement', () {
      // The link between the builder call and the flag. Without it, the
      // render test below could pass for some unrelated reason.
      final acl = AclBuilder().append(const Text('content')).gap().build();
      final components = acl.rows.single.components;
      expect(components.map((c) => c.isGap), [false, true]);
      expect(components.last.flags & AclFlags.gapElement, AclFlags.gapElement);
    });

    testWidgets('a component carrying gapElement does not render its child', (
      tester,
    ) async {
      // The destructive part of the meaning, and the reason the dartdoc tells
      // callers to reach for gap() instead of setAttr.
      final acl = AclBuilder()
          .append(const Text('kept'))
          .append(const Text('swallowed'))
          .setAttr(AclFlags.gapElement)
          .build();

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: acl)));

      expect(find.text('kept'), findsOneWidget);
      expect(
        find.text('swallowed'),
        findsNothing,
        reason:
            'a component flagged gapElement is replaced by a spacer; '
            'its child is never built',
      );
    });

    testWidgets('a gap slot pushes content apart', (tester) async {
      // The constructive half: the slot is not merely a hole, it absorbs the
      // row's surplus width, which is what gapWeight distributes.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              child: AclBuilder()
                  .append(const Text('left'))
                  .gap()
                  .append(const Text('right'))
                  .build(),
            ),
          ),
        ),
      );

      final left = tester.getTopLeft(find.text('left')).dx;
      final right = tester.getTopLeft(find.text('right')).dx;
      expect(
        right - left,
        greaterThan(200),
        reason:
            'the gap slot should have absorbed the row surplus and '
            'driven the two labels apart',
      );
    });
  });
}
