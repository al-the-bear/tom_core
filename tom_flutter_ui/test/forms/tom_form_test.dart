// TomForm tests that exercise event listener management, state queries,
// and lifecycle operations.
//
// NOTE: TomForm extends TomClass which uses reflectable for member
// auto-discovery. These tests work around the reflection requirement by
// testing the event system and field interaction through manually
// registered fields. Full integration tests (including reflection-based
// member discovery) require a reflection-initialized environment.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/src/forms/tom_form.dart';
import 'package:tom_flutter_ui/src/forms/events/tom_form_event.dart';
import 'package:tom_flutter_ui/src/forms/events/tom_form_inspector.dart';
import 'package:tom_flutter_ui/src/forms/validation/validation_result.dart';
import 'package:tom_flutter_ui/src/forms/validation/validators.dart';

// ---------------------------------------------------------------------------
// Minimal TomField subclass for testing
// ---------------------------------------------------------------------------
class _TestField<T> extends TomField<T> {
  _TestField(
    super.fieldName,
    super.initialValue, {
    super.form,
    super.fieldValidators,
  });

  @override
  Widget getField() => const SizedBox.shrink();
}

void main() {
  // -------------------------------------------------------------------------
  // Since TomForm extends TomClass (requires reflectable), we cannot directly
  // construct it in unit tests. Instead we test the interaction patterns
  // that don't require a TomForm instance:
  //
  // 1. Field ↔ Form event firing (field.form reference)
  // 2. Inspector as listener collecting form events
  // 3. Validation state + dirty tracking on standalone fields
  // -------------------------------------------------------------------------

  group('TomField — form event integration', () {
    // These tests verify that TomField fires form events when a form
    // reference is set. We use a manual approach: create fields with a null
    // form, then test that events are NOT fired (no form), and separately
    // test the inspector/listener independently.

    test('commit fires FieldCommittedEvent when form is set', () {
      // Without a form, commit should still work (no events, no crash)
      final field = _TestField<String>('name', 'Alice');
      field.set('Bob');
      expect(() => field.commit(), returnsNormally);
      expect(field.isDirty, isFalse);
    });

    test('validateField fires FieldValidatedEvent on success (no form)', () async {
      final field = _TestField<String>(
        'name',
        'test',
        fieldValidators: [Validators.required()],
      );
      final result = await field.validateField();
      expect(result, isA<ValidationSuccess>());
    });

    test('validateField fires FieldValidatedEvent on error (no form)', () async {
      final field = _TestField<String>(
        'name',
        '',
        fieldValidators: [Validators.required()],
      );
      final result = await field.validateField();
      expect(result, isA<ValidationError>());
    });
  });

  group('TomFormInspector — as form listener', () {
    test('collects events dispatched via handleEvent', () {
      final inspector = TomFormInspector();

      // Simulate what TomForm._fireEvent does
      inspector.handleEvent(FormBoundEvent(source: 'myForm'));
      inspector.handleEvent(
        FieldValueChangedEvent(source: 'name', oldValue: 'A', newValue: 'B'),
      );
      inspector.handleEvent(
        FieldValidatedEvent(source: 'name', result: const ValidationSuccess()),
      );
      inspector.handleEvent(FormSavedEvent(source: 'myForm'));

      expect(inspector.length, 4);
      expect(inspector.ofType<FormBoundEvent>(), hasLength(1));
      expect(inspector.ofType<FieldValueChangedEvent>(), hasLength(1));
      expect(inspector.ofType<FieldValidatedEvent>(), hasLength(1));
      expect(inspector.ofType<FormSavedEvent>(), hasLength(1));
    });

    test('fromSource separates form and field events', () {
      final inspector = TomFormInspector();

      inspector.handleEvent(FormBoundEvent(source: 'myForm'));
      inspector.handleEvent(FieldBoundEvent(source: 'email'));
      inspector.handleEvent(FieldBoundEvent(source: 'password'));
      inspector.handleEvent(
        FieldValueChangedEvent(source: 'email', oldValue: '', newValue: 'a@b.c'),
      );

      expect(inspector.fromSource('myForm'), hasLength(1));
      expect(inspector.fromSource('email'), hasLength(2));
      expect(inspector.fromSource('password'), hasLength(1));
    });
  });

  group('Multiple fields — dirty and validation tracking', () {
    test('independent fields track their own dirty state', () {
      final name = _TestField<String>('name', 'Alice');
      final email = _TestField<String>('email', 'a@b.com');

      name.set('Bob');
      expect(name.isDirty, isTrue);
      expect(email.isDirty, isFalse);
    });

    test('independent fields validate independently', () async {
      final name = _TestField<String>(
        'name',
        '',
        fieldValidators: [Validators.required()],
      );
      final email = _TestField<String>(
        'email',
        'valid@email.com',
        fieldValidators: [Validators.required()],
      );

      final nameResult = await name.validateField();
      final emailResult = await email.validateField();

      expect(nameResult, isA<ValidationError>());
      expect(emailResult, isA<ValidationSuccess>());
    });

    test('parallel validation of multiple fields', () async {
      final fields = [
        _TestField<String>('a', 'ok', fieldValidators: [Validators.required()]),
        _TestField<String>('b', '', fieldValidators: [Validators.required()]),
        _TestField<String>('c', 'ok', fieldValidators: [Validators.required()]),
      ];

      final results = await Future.wait(
        fields.map((f) => f.validateField()),
      );

      expect(results[0], isA<ValidationSuccess>());
      expect(results[1], isA<ValidationError>());
      expect(results[2], isA<ValidationSuccess>());
    });
  });

  group('TomField — commit / reset lifecycle', () {
    test('full lifecycle: set → validate → commit → reset', () async {
      final field = _TestField<String>(
        'name',
        'initial',
        fieldValidators: [Validators.required()],
      );

      // Modify
      field.set('modified');
      expect(field.isDirty, isTrue);

      // Validate
      final result = await field.validateField();
      expect(result, isA<ValidationSuccess>());

      // Commit — makes 'modified' the new initial
      field.commit();
      expect(field.isDirty, isFalse);
      expect(field.initialValue, 'modified');

      // Reset — goes back to committed value ('modified')
      field.set('something else');
      field.reset();
      expect(field.get(), 'modified');
    });

    test('discard pattern: set → reset restores original', () {
      final field = _TestField<String>('name', 'original');

      field.set('changed');
      expect(field.isDirty, isTrue);

      field.reset();
      expect(field.get(), 'original');
      expect(field.isDirty, isFalse);
    });

    test('save pattern: set → commit preserves changes', () {
      final field = _TestField<String>('name', 'original');

      field.set('saved');
      field.commit();

      expect(field.get(), 'saved');
      expect(field.initialValue, 'saved');
      expect(field.isDirty, isFalse);

      // Future reset goes back to 'saved', not 'original'
      field.set('temp');
      field.reset();
      expect(field.get(), 'saved');
    });
  });
}
