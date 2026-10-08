/// Every form-field dropdown must survive a constraint narrower than the
/// widest label it carries.
///
/// A form field is never laid out at its intrinsic width: it sits in a column
/// whose width the *form* decides — a responsive breakpoint, a two-column
/// section, a narrow drawer. Its content, on the other hand, comes from the
/// data: a country list, an enum's display names, a row loaded from the
/// server. So "the widest item is wider than the column" is an ordinary
/// runtime state, not a mis-configuration, and a dropdown that answers it with
/// a `RenderFlex overflowed by N pixels` is broken for every consumer at once.
///
/// The tests below pin exactly that: each of the four dropdown fields rendered
/// into a box far narrower than its longest label, asserting no exception was
/// raised. They live here — beside the widgets — rather than only in a
/// consumer's suite, because the same defect otherwise returns silently
/// through whichever consumer no one screenshots.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// A width no realistic label fits into, so the constraint — not the text —
/// decides the outcome.
const double _narrowWidth = 90;

/// Labels chosen to be unambiguously wider than [_narrowWidth] at the test
/// font, so a field that sizes itself to its content cannot accidentally pass.
const List<String> _longLabels = [
  'A considerably long option label that cannot fit',
  'Another equally long option label for contrast',
];

Widget _narrow(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: _narrowWidth, child: child),
      ),
    ),
  );
}

TomStaticSelectableSource<String> _stringSource() => TomStaticSelectableSource([
  for (var i = 0; i < _longLabels.length; i++)
    TomSelectableItem(value: 'v$i', label: _longLabels[i]),
]);

void main() {
  group('dropdown fields under a constraint narrower than their content', () {
    testWidgets('TomFormStringDropdown does not overflow', (tester) async {
      final field = TomFormStringDropdown(
        'country',
        'v0',
        source: _stringSource(),
        labelTextOverride: 'Country',
      );

      await tester.pumpWidget(_narrow(field.widget));
      await tester.pumpAndSettle();

      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TomFormEnumDropdown does not overflow', (tester) async {
      final field = TomFormEnumDropdown<String>(
        'status',
        'v0',
        source: _stringSource(),
        labelTextOverride: 'Status',
      );

      await tester.pumpWidget(_narrow(field.widget));
      await tester.pumpAndSettle();

      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TomFormObjectDropdown does not overflow', (tester) async {
      final field = TomFormObjectDropdown<String>(
        'owner',
        'v0',
        source: _stringSource(),
        labelTextOverride: 'Owner',
      );

      await tester.pumpWidget(_narrow(field.widget));
      await tester.pumpAndSettle();

      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TomFormNEnumDropdown does not overflow', (tester) async {
      final field = TomFormNEnumDropdown<String>(
        'category',
        'v0',
        source: _stringSource(),
        labelTextOverride: 'Category',
      );

      await tester.pumpWidget(_narrow(field.widget));
      await tester.pumpAndSettle();

      expect(find.byType(DropdownButtonFormField<String?>), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'the selected item is clipped to the column, not drawn past it',
      (tester) async {
        final field = TomFormStringDropdown(
          'country',
          'v0',
          source: _stringSource(),
          labelTextOverride: 'Country',
        );

        await tester.pumpWidget(_narrow(field.widget));
        await tester.pumpAndSettle();

        // The selected label renders inside the closed button; whatever
        // ellipsis strategy the theme applies, it must stay within the
        // column the form gave the field.
        final button = tester.getRect(
          find.byType(DropdownButtonFormField<String>),
        );
        expect(button.width, lessThanOrEqualTo(_narrowWidth));
        expect(tester.takeException(), isNull);
      },
    );
  });
}
