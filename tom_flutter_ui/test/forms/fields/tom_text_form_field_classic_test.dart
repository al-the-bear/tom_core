import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/src/forms/tom_form.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  // Classic-path input validators must keep their error message after an
  // invalid keystroke is reverted. The failure mode is that the controller
  // revert re-enters `_onTextChanged`, which re-validates the now valid
  // reverted text and wipes the error it had just set.
  group('TomTextFormFieldBase — input-validator revert', () {
    testWidgets(
        'keeps the input error after reverting an invalid keystroke',
        (tester) async {
      // ignore: deprecated_member_use
      final field = TomFormStringInputClassic(
        'amount',
        '',
        inputValidator: (value) =>
            RegExp(r'^[0-9]*$').hasMatch(value) ? null : 'error.onlyDigits',
      );
      addTearDown(field.dispose);

      await tester.pumpWidget(_wrap(field.widget));

      // A valid value is accepted and becomes the last-good raw value.
      await tester.enterText(find.byType(TextField), '123');
      await tester.pump();
      expect(field.errorText, isNull);

      // An invalid keystroke is rejected: the text reverts to the last good
      // value, but the error message must survive the revert.
      await tester.enterText(find.byType(TextField), '123a');
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, '123',
          reason: 'invalid input should revert to the last valid value');
      expect(field.errorText, isNotNull,
          reason: 'the input error must not be wiped by the revert');
      // `t()` resolves the validator's resource key (here through the empty
      // scope), so assert the key survives rather than pinning its prefix.
      expect(field.errorText, contains('error.onlyDigits'));
    });

    testWidgets('clears the error once a valid value is entered again',
        (tester) async {
      // ignore: deprecated_member_use
      final field = TomFormStringInputClassic(
        'amount',
        '',
        inputValidator: (value) =>
            RegExp(r'^[0-9]*$').hasMatch(value) ? null : 'error.onlyDigits',
      );
      addTearDown(field.dispose);

      await tester.pumpWidget(_wrap(field.widget));

      await tester.enterText(find.byType(TextField), '12a');
      await tester.pump();
      expect(field.errorText, isNotNull);

      await tester.enterText(find.byType(TextField), '45');
      await tester.pump();
      expect(field.errorText, isNull);
      expect(field.get(), '45');
    });
  });
}
