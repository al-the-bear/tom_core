import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// For the `>>` observation operator, which the kernel supplies as an
// extension on TomObservable and so must be imported to be in scope.
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/src/forms/tom_form.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

/// A digits-only field: the input validator rejects anything else. Input
/// validators are keystroke-level, so a programmatic write must never be
/// subjected to them.
TomTextFormFieldBase<String> _digitsField(String initialValue) {
  return TomTextFormFieldBase<String>(
    'amount',
    initialValue,
    inputValidator: (value) =>
        RegExp(r'^[0-9]*$').hasMatch(value) ? null : 'error.onlyDigits',
  );
}

/// A field whose text form differs from its value form, so the round trip
/// `value -> text -> value` lands on a *different* value. This makes the
/// intermediate, text-derived value visible to observers if the programmatic
/// write leaks through the input listener.
TomTextFormFieldBase<String> _upperCasingField(String initialValue) {
  return TomTextFormFieldBase<String>(
    'code',
    initialValue,
    valueToTextConverter: (value) => value.toUpperCase(),
    valueConverter: (value) => value,
  );
}

void main() {
  // tcca15: `set()` and `reset()` wrote the controller without the
  // re-entrancy guard the revert path uses, so a programmatic write re-entered
  // `_onTextChanged` and was processed as if the user had typed it.
  group('TomTextFormFieldBase — programmatic writes are not keystrokes', () {
    test('set() does not run the input validators', () {
      final seen = <String>[];
      final field = TomTextFormFieldBase<String>(
        'amount',
        'a',
        inputValidator: (value) {
          seen.add(value);
          return null;
        },
      );
      addTearDown(field.dispose);

      field.set('b');

      expect(seen, isEmpty,
          reason: 'input validators judge keystrokes, not programmatic writes');
      expect(field.get(), 'b');
    });

    test('reset() does not run the input validators', () {
      final seen = <String>[];
      final field = TomTextFormFieldBase<String>(
        'amount',
        'a',
        inputValidator: (value) {
          seen.add(value);
          return null;
        },
      );
      addTearDown(field.dispose);

      field.set('b');
      seen.clear();
      field.reset();

      expect(seen, isEmpty);
      expect(field.get(), 'a');
      expect(field.isDirty, isFalse);
    });

    test('set() publishes the value that was set, and nothing else', () {
      final field = _upperCasingField('a');
      addTearDown(field.dispose);

      final observed = <String>[];
      // Observers are held weakly, so the returned observer must stay
      // referenced for the duration of the test.
      final observer = field >> (_) => observed.add(field.get());

      field.set('b');

      expect(observer, isNotNull);
      expect(observed, ['b'],
          reason: 'the text round trip ("B") must never reach observers');
      expect(field.get(), 'b', reason: 'byte-identical after the round trip');
    });

    test('reset() publishes the initial value, and nothing else', () {
      final field = _upperCasingField('a');
      addTearDown(field.dispose);
      field.set('b');

      final observed = <String>[];
      final observer = field >> (_) => observed.add(field.get());

      field.reset();

      expect(observer, isNotNull);
      expect(observed, ['a']);
      expect(field.isDirty, isFalse);
    });

    testWidgets(
        'set() leaves the controller showing the value, even when an input '
        'validator would have rejected it', (tester) async {
      final field = _digitsField('');
      addTearDown(field.dispose);
      await tester.pumpWidget(_wrap(field.widget));

      field.set('abc');
      await tester.pump();

      expect(field.get(), 'abc');
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'abc',
          reason: 'the controller must not diverge from the value');
      expect(field.errorText, isNull,
          reason: 'a programmatic write is not a keystroke');
    });

    testWidgets('set() clears an error left by an earlier keystroke',
        (tester) async {
      final field = _digitsField('');
      addTearDown(field.dispose);
      await tester.pumpWidget(_wrap(field.widget));

      await tester.enterText(find.byType(TextField), '12a');
      await tester.pump();
      expect(field.errorText, isNotNull);

      field.set('99');
      await tester.pump();

      expect(field.errorText, isNull,
          reason: 'the displayed error refers to text that is no longer shown');
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '99');
    });

    testWidgets('a rejected keystroke reverts to the last programmatic value',
        (tester) async {
      // Guards the fix: suppressing the listener means the programmatic write
      // must itself record the last-good raw text, or the revert path falls
      // back to a stale one.
      final field = _digitsField('');
      addTearDown(field.dispose);
      await tester.pumpWidget(_wrap(field.widget));

      field.set('456');
      await tester.pump();

      await tester.enterText(find.byType(TextField), '456a');
      await tester.pump();

      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '456',
          reason: 'the revert target is the last valid text, however it got '
              'there');
      expect(field.errorText, isNotNull);
    });

    testWidgets('reset() restores the controller to the initial text',
        (tester) async {
      final field = _digitsField('12');
      addTearDown(field.dispose);
      await tester.pumpWidget(_wrap(field.widget));

      await tester.enterText(find.byType(TextField), '345');
      await tester.pump();
      expect(field.get(), '345');

      field.reset();
      await tester.pump();

      expect(field.get(), '12');
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '12');
      expect(field.errorText, isNull);
    });
  });
}
