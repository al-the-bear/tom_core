import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/src/forms/events/tom_form_event.dart';

void main() {
  group('TomFormEvent', () {
    test('stores source and description', () {
      final event = TomFormEvent(source: 'myField', description: 'something');
      expect(event.source, 'myField');
      expect(event.description, 'something');
    });

    test('auto-generates timestamp when not provided', () {
      final before = DateTime.now();
      final event = TomFormEvent(source: 's', description: 'd');
      final after = DateTime.now();

      expect(event.timestamp.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(event.timestamp.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });

    test('accepts explicit timestamp', () {
      final ts = DateTime(2025, 1, 1);
      final event = TomFormEvent(
        source: 's',
        description: 'd',
        timestamp: ts,
      );
      expect(event.timestamp, ts);
    });

    test('toString includes runtimeType, source and description', () {
      final event = TomFormEvent(source: 'field1', description: 'changed');
      final str = event.toString();
      expect(str, contains('TomFormEvent'));
      expect(str, contains('field1'));
      expect(str, contains('changed'));
    });
  });

  group('FieldValueChangedEvent', () {
    test('stores old and new values', () {
      final event = FieldValueChangedEvent(
        source: 'name',
        oldValue: 'Alice',
        newValue: 'Bob',
      );
      expect(event.oldValue, 'Alice');
      expect(event.newValue, 'Bob');
      expect(event.source, 'name');
    });

    test('generates description from values', () {
      final event = FieldValueChangedEvent(
        source: 'age',
        oldValue: 25,
        newValue: 30,
      );
      expect(event.description, contains('25'));
      expect(event.description, contains('30'));
    });

    test('handles null values', () {
      final event = FieldValueChangedEvent(
        source: 'field',
        oldValue: null,
        newValue: 'hello',
      );
      expect(event.oldValue, isNull);
      expect(event.newValue, 'hello');
    });
  });

  group('FieldValidatedEvent', () {
    test('stores result', () {
      final event = FieldValidatedEvent(source: 'email', result: 'success');
      expect(event.result, 'success');
      expect(event.source, 'email');
    });

    test('description includes result', () {
      final event = FieldValidatedEvent(source: 'email', result: 'error');
      expect(event.description, contains('error'));
    });
  });

  group('FieldAuthChangedEvent', () {
    test('stores old and new states', () {
      final event = FieldAuthChangedEvent(
        source: 'secret',
        oldState: 'full',
        newState: 'read',
      );
      expect(event.oldState, 'full');
      expect(event.newState, 'read');
    });
  });

  group('FieldBoundEvent', () {
    test('creates with source', () {
      final event = FieldBoundEvent(source: 'name');
      expect(event.source, 'name');
      expect(event.description, contains('bound'));
    });
  });

  group('FieldCommittedEvent', () {
    test('creates with source', () {
      final event = FieldCommittedEvent(source: 'name');
      expect(event.source, 'name');
      expect(event.description, contains('committed'));
    });
  });

  group('FormBoundEvent', () {
    test('creates with source', () {
      final event = FormBoundEvent(source: 'loginForm');
      expect(event.source, 'loginForm');
      expect(event.description, contains('bound'));
    });
  });

  group('FormSavedEvent', () {
    test('creates with source', () {
      final event = FormSavedEvent(source: 'loginForm');
      expect(event.source, 'loginForm');
      expect(event.description, contains('saved'));
    });
  });

  group('FormDiscardedEvent', () {
    test('creates with source', () {
      final event = FormDiscardedEvent(source: 'loginForm');
      expect(event.source, 'loginForm');
      expect(event.description, contains('discarded'));
    });
  });

  group('event hierarchy', () {
    test('all events are TomFormEvent subtypes', () {
      expect(FieldValueChangedEvent(source: 's'), isA<TomFormEvent>());
      expect(FieldValidatedEvent(source: 's', result: 'ok'), isA<TomFormEvent>());
      expect(FieldAuthChangedEvent(source: 's', oldState: 'a', newState: 'b'), isA<TomFormEvent>());
      expect(FieldBoundEvent(source: 's'), isA<TomFormEvent>());
      expect(FieldCommittedEvent(source: 's'), isA<TomFormEvent>());
      expect(FormBoundEvent(source: 's'), isA<TomFormEvent>());
      expect(FormSavedEvent(source: 's'), isA<TomFormEvent>());
      expect(FormDiscardedEvent(source: 's'), isA<TomFormEvent>());
    });
  });
}
