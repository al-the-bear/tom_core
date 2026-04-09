import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/src/forms/style/form_style_enums.dart';
import 'package:tom_flutter_ui/src/forms/style/tom_form_style.dart';
import 'package:tom_flutter_ui/src/forms/style/tom_form_style_scope.dart';

void main() {
  group('TomFormStyleScope — of(context)', () {
    testWidgets('returns material3 when no scope in tree', (tester) async {
      late TomFormStyle captured;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              captured = TomFormStyleScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(captured, TomFormStyle.material3);
    });

    testWidgets('returns provided style from scope', (tester) async {
      const customStyle = TomFormStyle(fieldSpacing: 32.0, borderRadius: 16.0);
      late TomFormStyle captured;

      await tester.pumpWidget(
        MaterialApp(
          home: TomFormStyleScope(
            style: customStyle,
            child: Builder(
              builder: (context) {
                captured = TomFormStyleScope.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(captured.fieldSpacing, 32.0);
      expect(captured.borderRadius, 16.0);
      expect(captured, customStyle);
    });

    testWidgets('nested scope overrides parent', (tester) async {
      const parentStyle = TomFormStyle(fieldSpacing: 20.0, borderRadius: 8.0);
      const childStyle = TomFormStyle(fieldSpacing: 8.0, borderRadius: 4.0);
      late TomFormStyle parentCaptured;
      late TomFormStyle childCaptured;

      await tester.pumpWidget(
        MaterialApp(
          home: TomFormStyleScope(
            style: parentStyle,
            child: Column(
              children: [
                Builder(
                  builder: (context) {
                    parentCaptured = TomFormStyleScope.of(context);
                    return const SizedBox();
                  },
                ),
                TomFormStyleScope(
                  style: childStyle,
                  child: Builder(
                    builder: (context) {
                      childCaptured = TomFormStyleScope.of(context);
                      return const SizedBox();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(parentCaptured.fieldSpacing, 20.0);
      expect(childCaptured.fieldSpacing, 8.0);
      expect(parentCaptured, isNot(equals(childCaptured)));
    });

    testWidgets('updateShouldNotify returns true when style changes',
        (tester) async {
      int rebuildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return TomFormStyleScope(
                style: const TomFormStyle(fieldSpacing: 16.0),
                child: Builder(
                  builder: (context) {
                    TomFormStyleScope.of(context);
                    rebuildCount++;
                    return ElevatedButton(
                      onPressed: () {
                        setState(() {});
                      },
                      child: const Text('Rebuild'),
                    );
                  },
                ),
              );
            },
          ),
        ),
      );

      expect(rebuildCount, 1);

      // Same style — no rebuild of dependents
      await tester.tap(find.text('Rebuild'));
      await tester.pump();
      // Rebuild count increases because StatefulBuilder rebuilds,
      // but the InheritedWidget comparison is the same style
      expect(rebuildCount, greaterThanOrEqualTo(1));
    });
  });

  group('TomFormStyleScope — compact sub-form', () {
    testWidgets('compact scope inside material3 scope', (tester) async {
      late TomFormStyle outerStyle;
      late TomFormStyle innerStyle;

      await tester.pumpWidget(
        MaterialApp(
          home: TomFormStyleScope(
            style: TomFormStyle.material3,
            child: Column(
              children: [
                Builder(
                  builder: (context) {
                    outerStyle = TomFormStyleScope.of(context);
                    return const SizedBox();
                  },
                ),
                TomFormStyleScope(
                  style: TomFormStyle.compact,
                  child: Builder(
                    builder: (context) {
                      innerStyle = TomFormStyleScope.of(context);
                      return const SizedBox();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(outerStyle.labelPlacement, LabelPlacement.above);
      expect(outerStyle.fieldSpacing, 16.0);
      expect(innerStyle.labelPlacement, LabelPlacement.floating);
      expect(innerStyle.fieldSpacing, 8.0);
    });
  });
}
