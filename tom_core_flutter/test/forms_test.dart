import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

/// Tests for the legacy forms module (`TomFieldOld`, `TomEmailField`,
/// `TomPasswordField`, `TomFormOld`).
///
/// Missing resource keys fall back to the key itself, so error messages are
/// asserted against their resource keys (e.g. `form.email.errors.validEmail`).
void main() {
  setUp(() {
    // Deterministic, empty resource/config providers so lookups resolve to the
    // key (and patterns are absent → no input-pattern validators).
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from({}),
    );
    TomConfigResourceProvider.setAppConfigProvider(
      TomConfigResourceProvider.from({}),
    );
  });

  group('TomEmailField.isValidEmail', () {
    test('accepts a well-formed address', () {
      expect(TomEmailField.isValidEmail('user@example.com'), isTrue);
      expect(TomEmailField.isValidEmail('a.b+tag@sub.domain.co'), isTrue);
    });

    test('rejects malformed addresses', () {
      expect(TomEmailField.isValidEmail('not-an-email'), isFalse);
      expect(TomEmailField.isValidEmail('missing@tld'), isFalse);
      expect(TomEmailField.isValidEmail(''), isFalse);
    });
  });

  group('TomEmailField validation', () {
    test('empty value fails with the required error key', () {
      final field = TomEmailField<String>('form', 'email', '');
      expect(field.validate(), isFalse);
      expect(field.errorText, 'form.email.errors.required');
    });

    test('malformed value fails with the validEmail error key', () {
      final field = TomEmailField<String>('form', 'email', '');
      field.set('not-an-email');
      expect(field.validate(), isFalse);
      expect(field.errorText, 'form.email.errors.validEmail');
    });

    test('valid value passes and clears the error', () {
      final field = TomEmailField<String>('form', 'email', '');
      field.set('user@example.com');
      expect(field.validate(), isTrue);
      expect(field.errorText, isNull);
    });
  });

  group('TomPasswordField validation', () {
    test('empty value fails with the required error key', () {
      final field = TomPasswordField<String>('form', 'password', '');
      expect(field.validate(), isFalse);
      expect(field.errorText, 'form.password.errors.required');
    });

    test('short value fails with the minimumLength error key', () {
      final field = TomPasswordField<String>('form', 'password', '');
      field.set('abc');
      expect(field.validate(), isFalse);
      expect(field.errorText, 'form.password.errors.minimumLength');
    });

    test('value of 4+ characters passes', () {
      final field = TomPasswordField<String>('form', 'password', '');
      field.set('secret');
      expect(field.validate(), isTrue);
      expect(field.errorText, isNull);
    });

    test('obscureText defaults to true', () {
      final field = TomPasswordField<String>('form', 'password', '');
      expect(field.obscureText, isTrue);
    });
  });

  group('TomFieldOld save & reset', () {
    test('save converts the current text to the field value', () {
      final field = TomEmailField<String>('form', 'email', 'a@b.com');
      field.set('user@example.com');
      expect(field.save(), 'user@example.com');
      expect(~field, 'user@example.com');
    });

    test('reset restores the initial value', () {
      final field = TomEmailField<String>('form', 'email', 'a@b.com');
      field.set('user@example.com');
      field.reset();
      expect(~field, 'a@b.com');
    });
  });

  group('TomFormOld', () {
    TomFormOld buildForm({String email = 'user@example.com', String pw = 'secret'}) {
      return TomFormOld({
        'email': TomEmailField<String>('form', 'email', email),
        'password': TomPasswordField<String>('form', 'password', pw),
      });
    }

    test('validate is true when all fields are valid', () {
      expect(buildForm().validate(), isTrue);
    });

    test('validate is false when any field is invalid', () {
      final form = buildForm(pw: 'no'); // too short
      expect(form.validate(), isFalse);
    });

    test('errors maps each field name to its error', () {
      final form = buildForm(email: '', pw: 'no');
      form.validate();
      final errors = form.errors();
      expect(errors['email'], 'form.email.errors.required');
      expect(errors['password'], 'form.password.errors.minimumLength');
    });

    test('save returns the converted values keyed by field name', () {
      final saved = buildForm().save();
      expect(saved['email'], 'user@example.com');
      expect(saved['password'], 'secret');
    });
  });

  group('TomFieldOld widget', () {
    testWidgets('getField renders a Material TextField', (tester) async {
      final field = TomEmailField<String>('form', 'email', '');
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: field.getField())),
      );
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('password field obscures its text', (tester) async {
      final field = TomPasswordField<String>('form', 'password', '');
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: field.getField())),
      );
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, isTrue);
    });
  });

  group('input-pattern validation (tests §38a)', () {
    // A `.pattern` resource installs an input validator that runs on every
    // keystroke. An invalid keystroke must (1) revert the editor to the last
    // valid text AND (2) keep the surfaced error message — the re-entrant
    // revert used to wipe its own error (bug §57). RED before the fix on the
    // message assertion (the revert already worked).
    void installPattern() {
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from({
          'form.code.pattern': r'^[0-9]*$',
          'form.code.errors.pattern': 'Digits only',
        }),
      );
    }

    testWidgets('an invalid keystroke reverts and keeps the error message',
        (tester) async {
      installPattern();
      final field = TomFieldOld<String>('form', 'code', '');
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: field.getField())),
      );

      await tester.enterText(find.byType(TextField), '123');
      await tester.pump();
      expect(field.errorText, isNull);

      await tester.enterText(find.byType(TextField), '12x');
      await tester.pump();
      // Reverted to the last valid text:
      expect(find.text('123'), findsOneWidget);
      expect(find.text('12x'), findsNothing);
      // ...and the failing message survived the revert (bug §57):
      expect(field.errorText, 'Digits only');
    });
  });

  group('set() of an input-invalid value (tests §38b)', () {
    // A programmatic set() of an input-invalid value must be rejected like a
    // keystroke: the stored value and editor text stay in sync (both keep the
    // previous valid state) and the error surfaces — the old set() stored the
    // invalid value while the editor reverted, so `~field` and `save()`
    // disagreed (bug §58). RED before the fix.
    setUp(() {
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from({
          'form.code.pattern': r'^[0-9]*$',
          'form.code.errors.pattern': 'Digits only',
        }),
      );
    });

    test('set() of an invalid value leaves value and text unchanged', () {
      final field = TomFieldOld<String>('form', 'code', '0');
      field.set('xx'); // violates the digits-only pattern
      expect(~field, '0', reason: 'stored value must not change');
      expect(field.save(), '0', reason: 'editor text must not change');
      expect(field.errorText, 'Digits only');
    });
  });

  group('TomFormOld.save() batch muting (tests §38c)', () {
    // save() mutes the fields across the batch so a form-level observer sees a
    // single consolidated notification rather than one per field. Edits go in
    // via the editor (changing text only); save() converts each to the field
    // value, which differs from the stored value and would notify per field if
    // not muted. Characterization of existing behaviour.
    testWidgets('a single form-level notification per save batch',
        (tester) async {
      final form = TomFormOld({
        'email': TomEmailField<String>('form', 'email', 'a@b.com'),
        'password': TomPasswordField<String>('form', 'password', 'old1'),
      });
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Column(children: form.getFields()))),
      );

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'user@example.com');
      await tester.enterText(fields.at(1), 'newpass');
      await tester.pump();

      final observer = _CountingObserver();
      form.addObserver(observer); // strong ref keeps the weak observer alive

      form.save();
      expect(observer.count, 1);
    });
  });
}

/// Counts the notifications delivered to a registered observer.
class _CountingObserver extends TomObserver<TomObservable> {
  int count = 0;

  @override
  void onNotify(TomObservable observable) => count++;
}
