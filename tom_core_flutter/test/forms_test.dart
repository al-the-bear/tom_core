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
}
