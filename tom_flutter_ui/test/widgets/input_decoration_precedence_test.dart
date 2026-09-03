import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// tccc1: the text inputs accept a whole `InputDecoration` *and* the plain
// `label` / `hint` strings the Tom resource layer resolves. The two used to be
// combined the wrong way round: the resource lookup ran unconditionally in the
// constructor and the result was written over the decoration at the end, so
//   * `decoration: InputDecoration(labelText: 'Name')` was silently discarded,
//     and
//   * a caller who passed a decoration but no `label` and no `tomId` got
//     `Bad state: Tom widget requires either an explicit label or a tomId` for
//     a string the decoration already carried.
//
// The precedence rule these tests pin is a chain, not a merge:
//     label ?? decoration.labelText ?? <resource>
// with the resource lookup last and therefore lazy — the same shape tccb2
// established for `TomDropdownButtonFormField`.
//
// Each widget gets both directions: a decoration alone must suffice, and a
// construction with no source at all must still fail loudly rather than
// degrade into a blank label.
//
// `TomInputDatePickerFormField` belongs to the second family only. It has no
// `decoration` parameter; its four strings are optional in Flutter (defaulted
// from `MaterialLocalizations`) yet were all required from resources, which is
// the tccb2 rule — an optional Flutter slot needs no resource.
//
// Note the throw is raised by the *constructor*, not by build — hence
// `expect(() => TomX(), throwsStateError)` rather than a pump assertion.

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

/// The decoration the framework actually laid out, not the one we passed in.
InputDecoration _rendered(WidgetTester tester) =>
    tester.widget<InputDecorator>(find.byType(InputDecorator)).decoration;

void main() {
  group('tccc1: an explicit decoration suffices and is honoured', () {
    testWidgets('tccc1-01: TomTextField keeps decoration.labelText', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          TomTextField(decoration: const InputDecoration(labelText: 'Name')),
        ),
      );
      expect(_rendered(tester).labelText, 'Name');
    });

    testWidgets('tccc1-02: TomTextField keeps decoration.hintText', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          TomTextField(
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. Ada',
            ),
          ),
        ),
      );
      expect(_rendered(tester).hintText, 'e.g. Ada');
    });

    testWidgets('tccc1-03: TomTextField label beats decoration.labelText', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          TomTextField(
            label: 'Explicit',
            decoration: const InputDecoration(labelText: 'From decoration'),
          ),
        ),
      );
      expect(_rendered(tester).labelText, 'Explicit');
    });

    testWidgets('tccc1-04: TomTextFormField keeps decoration.labelText', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          TomTextFormField(
            decoration: const InputDecoration(labelText: 'Name'),
          ),
        ),
      );
      expect(_rendered(tester).labelText, 'Name');
    });

    testWidgets('tccc1-05: TomTextFormField keeps decoration.hintText', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          TomTextFormField(
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. Ada',
            ),
          ),
        ),
      );
      expect(_rendered(tester).hintText, 'e.g. Ada');
    });

    testWidgets('tccc1-06: TomTextFormField label beats decoration.labelText', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          TomTextFormField(
            label: 'Explicit',
            decoration: const InputDecoration(labelText: 'From decoration'),
          ),
        ),
      );
      expect(_rendered(tester).labelText, 'Explicit');
    });

    testWidgets(
      'tccc1-07: TomInputDatePickerFormField needs no label/hint resource',
      (tester) async {
        await tester.pumpWidget(
          _host(
            TomInputDatePickerFormField(
              initialDate: DateTime(2026, 1, 1),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            ),
          ),
        );
        // Flutter falls back to MaterialLocalizations.dateInputLabel.
        expect(_rendered(tester).labelText, isNotNull);
      },
    );

    testWidgets(
      'tccc1-08: TomInputDatePickerFormField honours its own field strings',
      (tester) async {
        await tester.pumpWidget(
          _host(
            TomInputDatePickerFormField(
              initialDate: DateTime(2026, 1, 1),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              fieldLabelText: 'Due',
              fieldHintText: 'dd/mm/yyyy',
            ),
          ),
        );
        expect(_rendered(tester).labelText, 'Due');
        expect(_rendered(tester).hintText, 'dd/mm/yyyy');
      },
    );
  });

  group('tccc1: no label source still fails loudly', () {
    test(
      'tccc1-09: TomTextField without label, decoration or tomId throws',
      () {
        expect(() => TomTextField(), throwsStateError);
      },
    );

    test(
      'tccc1-10: TomTextFormField without label, decoration or tomId throws',
      () {
        expect(() => TomTextFormField(), throwsStateError);
      },
    );

    test('tccc1-11: TomTextField with a labelless decoration throws', () {
      expect(
        () => TomTextField(decoration: const InputDecoration(filled: true)),
        throwsStateError,
      );
    });

    test('tccc1-12: TomTextFormField with a labelless decoration throws', () {
      expect(
        () => TomTextFormField(decoration: const InputDecoration(filled: true)),
        throwsStateError,
      );
    });
  });
}
