/// A rebuilt `AclRow` keeps every field the original had.
///
/// Three passes rebuild rows during layout — hide-unauthorized, the breakpoint
/// split and the inline-variant filter — and each needs to change two or three
/// fields out of sixteen. Written as a fresh `AclRow(...)` that means restating
/// the other thirteen, and the failure mode is the worst kind: a field added to
/// `AclRow` later is silently absent from whichever pass forgot it, so the row
/// keeps all its properties at the width the developer tested and loses some at
/// the width their user has.
///
/// `AclRow.copyWith` is the answer, and it takes two claims to make it stick.
/// That it names every field is asserted in
/// `acl_component_copy_with_test.dart`, beside the same claim for
/// `AclComponent` — one mechanism, two classes. What is asserted here is the
/// other half: **no pass constructs an `AclRow` directly**, without which
/// `copyWith` could be complete and simply unused.
///
/// The structural claim reads the source, because the property is about *how*
/// the rows are built rather than what any one of them contains. The
/// behavioural group below shows what omitting a field looked like — a geometry
/// test alone cannot see it, which is how four fields went missing: the
/// existing breakpoint and variant tests pass straight through the loss.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

void main() {
  final source = File(
    'lib/src/advanced_container_layout/acl_container.dart',
  ).readAsStringSync();

  group('AclRow.copyWith is the only way a pass rebuilds a row', () {
    test('no layout pass constructs an AclRow directly', () {
      // `copyWith` being complete is worth nothing if a pass goes around it.
      // The constructor belongs to the builder and to `copyWith` itself; a
      // call anywhere else is a list of fields that will fall behind.
      final offenders = <String>[];
      final lines = source.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trimLeft();
        // Prose names the constructor to explain why nothing should call it.
        if (line.startsWith('//') || line.startsWith('*')) continue;
        if (!RegExp(r'(^|[^.\w])AclRow\(').hasMatch(lines[i])) continue;
        // The declaration's own constructor, and `copyWith`'s single call.
        final context = lines.sublist((i - 40).clamp(0, i), i).join('\n');
        if (context.contains('AclRow copyWith({')) continue;
        if (lines[i].trimLeft().startsWith('const AclRow(') ||
            lines[i].trimLeft().startsWith('AclRow({')) {
          continue;
        }
        offenders.add('line ${i + 1}: ${lines[i].trim()}');
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'these build an AclRow by naming fields instead of going through '
            'copyWith, so a field added to AclRow will not reach them: '
            '$offenders',
      );
    });
  });

  group('a field survives the passes that rebuild the row', () {
    // `defaultRowCrossAlignment` is the field both passes were dropping, and
    // the one of the four whose loss is visible: the other three
    // (`gapRowWeight`, `separator`, `gapRowMinSize`) describe gap rows, and a
    // gap row never reaches the split. So this is the behavioural half — the
    // structural assertions above say the rebuild cannot omit a field, and
    // this says what omitting one looked like.
    const tall = 60.0;
    const short = 20.0;

    Widget rowWith({required double width, required bool split}) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          child: AclBuilder()
              .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.bottom)
              .append(const SizedBox(width: 100, height: tall))
              .append(
                const SizedBox(width: 100, height: short, child: Text('probe')),
              )
              .addRowBreakpoint(atWidth: split ? 10000 : 1, splitRowDist: 0)
              .build(),
        ),
      ),
    );

    Future<double> probeTopIn(WidgetTester tester, Widget w) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(w);
      await tester.pumpAndSettle();
      final probe = tester.getRect(find.text('probe'));
      final row = tester.getRect(find.byType(SizedBox).first);
      return probe.top - row.top;
    }

    testWidgets('bottom alignment offsets the short component unsplit', (
      tester,
    ) async {
      // The control: without it the split assertion passes for a layout that
      // never aligned anything in the first place.
      final offset = await probeTopIn(
        tester,
        rowWith(width: 1000, split: false),
      );
      expect(
        offset,
        greaterThan(0),
        reason:
            'bottom alignment must push the short component down beside the '
            'tall one; it did not, so this test is not measuring alignment',
      );
    });

    testWidgets('and still does after a breakpoint split', (tester) async {
      // Before the rebuild went through copyWith, the fragments were built by
      // naming fields and this one was not among them — so the row aligned to
      // the bottom above the breakpoint and to the top below it. Correct at
      // the width the developer tests at, wrong at the width their user has.
      final unsplit = await probeTopIn(
        tester,
        rowWith(width: 1000, split: false),
      );
      final afterSplit = await probeTopIn(
        tester,
        rowWith(width: 1000, split: true),
      );
      expect(
        afterSplit,
        unsplit,
        reason:
            'the split fragments lost defaultRowCrossAlignment, so the short '
            'component moved to the top of its row',
      );
    });
  });
}
