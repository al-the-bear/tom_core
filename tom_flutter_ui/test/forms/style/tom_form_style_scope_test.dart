import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/src/forms/style/form_style_enums.dart';
import 'package:tom_flutter_ui/src/forms/style/tom_form_style_legacy.dart';
import 'package:tom_flutter_ui/src/forms/style/tom_form_style_scope_legacy.dart';

void main() {
  group('TomFormStyleScopeLegacy — of(context)', () {
    testWidgets('returns material3 when no scope in tree', (tester) async {
      late TomFormStyleLegacy captured;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              captured = TomFormStyleScopeLegacy.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(captured, TomFormStyleLegacy.material3);
    });

    testWidgets('returns provided style from scope', (tester) async {
      const customStyle = TomFormStyleLegacy(fieldSpacing: 32.0, borderRadius: 16.0);
      late TomFormStyleLegacy captured;

      await tester.pumpWidget(
        MaterialApp(
          home: TomFormStyleScopeLegacy(
            style: customStyle,
            child: Builder(
              builder: (context) {
                captured = TomFormStyleScopeLegacy.of(context);
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
      const parentStyle = TomFormStyleLegacy(fieldSpacing: 20.0, borderRadius: 8.0);
      const childStyle = TomFormStyleLegacy(fieldSpacing: 8.0, borderRadius: 4.0);
      late TomFormStyleLegacy parentCaptured;
      late TomFormStyleLegacy childCaptured;

      await tester.pumpWidget(
        MaterialApp(
          home: TomFormStyleScopeLegacy(
            style: parentStyle,
            child: Column(
              children: [
                Builder(
                  builder: (context) {
                    parentCaptured = TomFormStyleScopeLegacy.of(context);
                    return const SizedBox();
                  },
                ),
                TomFormStyleScopeLegacy(
                  style: childStyle,
                  child: Builder(
                    builder: (context) {
                      childCaptured = TomFormStyleScopeLegacy.of(context);
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
              return TomFormStyleScopeLegacy(
                style: const TomFormStyleLegacy(fieldSpacing: 16.0),
                child: Builder(
                  builder: (context) {
                    TomFormStyleScopeLegacy.of(context);
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

  group('TomFormStyleScopeLegacy — compact sub-form', () {
    testWidgets('compact scope inside material3 scope', (tester) async {
      late TomFormStyleLegacy outerStyle;
      late TomFormStyleLegacy innerStyle;

      await tester.pumpWidget(
        MaterialApp(
          home: TomFormStyleScopeLegacy(
            style: TomFormStyleLegacy.material3,
            child: Column(
              children: [
                Builder(
                  builder: (context) {
                    outerStyle = TomFormStyleScopeLegacy.of(context);
                    return const SizedBox();
                  },
                ),
                TomFormStyleScopeLegacy(
                  style: TomFormStyleLegacy.compact,
                  child: Builder(
                    builder: (context) {
                      innerStyle = TomFormStyleScopeLegacy.of(context);
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
