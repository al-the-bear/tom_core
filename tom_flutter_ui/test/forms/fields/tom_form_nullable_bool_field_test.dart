import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// ---------------------------------------------------------------------------
// The tristate boolean field — a toggle whose third state is "unanswered".
//
// TomFormBoolField binds a `bool` and so cannot express the indeterminate
// state at all. These tests pin the nullable sibling: that `null` is a real,
// reachable third value, that `tristate` is declarable in code and in
// resources, and that both families render it.
// ---------------------------------------------------------------------------

Widget _material(Widget child) => MaterialApp(home: Scaffold(body: child));

Widget _cupertino(Widget child) =>
    CupertinoApp(home: CupertinoPageScaffold(child: child));

void main() {
  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from({}),
    );
  });

  tearDown(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from({}),
    );
  });

  group('TomFormNullableBoolField — the third state', () {
    test('holds null as a value distinct from false', () {
      final field = TomFormNullableBoolCheckbox('answer', null);
      expect(field.get(), isNull);
      expect(field.isDirty, isFalse);

      field.setValue(false);
      expect(field.get(), isFalse);
      expect(field.isDirty, isTrue);

      // Returning to the indeterminate state is a real transition, not a
      // reset — the baseline happens to be null here, so dirty clears.
      field.setValue(null);
      expect(field.get(), isNull);
      expect(field.isDirty, isFalse);
    });

    test('a field that starts answered becomes dirty when cleared to null', () {
      final field = TomFormNullableBoolCheckbox('answer', true);
      field.setValue(null);
      expect(field.get(), isNull);
      expect(field.isDirty, isTrue);

      field.commit();
      expect(field.isDirty, isFalse);
      expect(field.initialValue, isNull);
    });

    test('reset restores the indeterminate baseline', () {
      final field = TomFormNullableBoolCheckbox('answer', null);
      field.setValue(true);
      field.reset();
      expect(field.get(), isNull);
    });
  });

  group('TomFormNullableBoolField — the tristate attribute', () {
    test('defaults to true — the third state is why the field exists', () {
      expect(TomFormNullableBoolCheckbox('answer', null).tristate, isTrue);
    });

    test('an explicit override wins', () {
      final field = TomFormNullableBoolCheckbox(
        'answer',
        null,
        tristateOverride: false,
      );
      expect(field.tristate, isFalse);
    });

    test('resources declare it when no override is given', () {
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from({'answer.tristate': 'false'}),
      );
      expect(TomFormNullableBoolCheckbox('answer', null).tristate, isFalse);
      // An override still beats the resource.
      expect(
        TomFormNullableBoolCheckbox(
          'answer',
          null,
          tristateOverride: true,
        ).tristate,
        isTrue,
      );
    });
  });

  group('TomFormNullableBoolCheckbox — rendering', () {
    testWidgets('renders an indeterminate Checkbox for a null value', (
      tester,
    ) async {
      final field = TomFormNullableBoolCheckbox('answer', null);
      await tester.pumpWidget(_material(field.widget));

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.tristate, isTrue);
      expect(checkbox.value, isNull);
    });

    testWidgets('a two-state control renders an unset field as unchecked', (
      tester,
    ) async {
      // Checkbox asserts `tristate || value != null`, so the widget must not
      // hand the raw null through — this would throw if it did.
      final field = TomFormNullableBoolCheckbox(
        'answer',
        null,
        tristateOverride: false,
      );
      await tester.pumpWidget(_material(field.widget));

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.tristate, isFalse);
      expect(checkbox.value, isFalse);
    });

    testWidgets('tapping cycles false → true → null → false', (tester) async {
      final field = TomFormNullableBoolCheckbox('answer', false);
      await tester.pumpWidget(_material(field.widget));

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(field.get(), isTrue);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(field.get(), isNull, reason: 'the third state is reachable');

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(field.get(), isFalse);

      // setValue schedules a validation debounce; let it fire before the
      // test tears the tree down.
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('a read-only field does not accept taps', (tester) async {
      final field = TomFormNullableBoolCheckbox(
        'answer',
        null,
        uiStateController: TomUIStateController(
          resolve: (_, _) => TomAuthState.read,
        ),
      );
      await tester.pumpWidget(_material(field.widget));

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.onChanged, isNull);
    });
  });

  group('TomCupertinoFormNullableBoolToggle — rendering', () {
    testWidgets('offers three segments and selects the unset one', (
      tester,
    ) async {
      final field = TomCupertinoFormNullableBoolToggle('answer', null);
      await tester.pumpWidget(_cupertino(field.widget));

      expect(find.text('Off'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(find.text('On'), findsOneWidget);
    });

    testWidgets('drops the unset segment when tristate is off', (tester) async {
      final field = TomCupertinoFormNullableBoolToggle(
        'answer',
        null,
        tristateOverride: false,
      );
      await tester.pumpWidget(_cupertino(field.widget));

      expect(find.text('Off'), findsOneWidget);
      expect(find.text('—'), findsNothing);
      expect(find.text('On'), findsOneWidget);
    });

    testWidgets('tapping the unset segment returns the field to null', (
      tester,
    ) async {
      final field = TomCupertinoFormNullableBoolToggle('answer', true);
      await tester.pumpWidget(_cupertino(field.widget));

      await tester.tap(find.text('—'));
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      expect(field.get(), isNull);
    });

    testWidgets('segment labels resolve from resources', (tester) async {
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from({
          'answer.onLabel': 'Yes',
          'answer.offLabel': 'No',
          'answer.nullLabel': 'Not answered',
        }),
      );
      final field = TomCupertinoFormNullableBoolToggle('answer', null);
      await tester.pumpWidget(_cupertino(field.widget));

      expect(find.text('Yes'), findsOneWidget);
      expect(find.text('No'), findsOneWidget);
      expect(find.text('Not answered'), findsOneWidget);
    });
  });

  group('FormFieldFamily.nullableBoolToggle', () {
    test('resolves to the Material or Cupertino concrete', () {
      final material = FormFieldFamily.material.nullableBoolToggle(
        'answer',
        null,
      );
      final cupertino = FormFieldFamily.cupertino.nullableBoolToggle(
        'answer',
        null,
      );

      expect(material, isA<TomFormNullableBoolCheckbox>());
      expect(cupertino, isA<TomCupertinoFormNullableBoolToggle>());
      // Both are the shared abstract type, so a caller codes against one.
      expect(material, isA<TomFormNullableBoolField>());
      expect(cupertino, isA<TomFormNullableBoolField>());
    });

    test('threads tristate through to either family', () {
      expect(
        FormFieldFamily.material
            .nullableBoolToggle('answer', null, tristate: false)
            .tristate,
        isFalse,
      );
      expect(
        FormFieldFamily.cupertino
            .nullableBoolToggle('answer', null, tristate: false)
            .tristate,
        isFalse,
      );
    });
  });
}
