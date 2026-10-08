import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

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

      expect(
        event.timestamp.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        event.timestamp.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('accepts explicit timestamp', () {
      final ts = DateTime(2025, 1, 1);
      final event = TomFormEvent(source: 's', description: 'd', timestamp: ts);
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

  group('TomFieldValueChangedEvent', () {
    test('stores old and new values', () {
      final event = TomFieldValueChangedEvent(
        source: 'name',
        oldValue: 'Alice',
        newValue: 'Bob',
      );
      expect(event.oldValue, 'Alice');
      expect(event.newValue, 'Bob');
      expect(event.source, 'name');
    });

    test('generates description from values', () {
      final event = TomFieldValueChangedEvent(
        source: 'age',
        oldValue: 25,
        newValue: 30,
      );
      expect(event.description, contains('25'));
      expect(event.description, contains('30'));
    });

    test('handles null values', () {
      final event = TomFieldValueChangedEvent(
        source: 'field',
        oldValue: null,
        newValue: 'hello',
      );
      expect(event.oldValue, isNull);
      expect(event.newValue, 'hello');
    });
  });

  group('TomFieldValidatedEvent', () {
    test('stores result', () {
      final event = TomFieldValidatedEvent(source: 'email', result: 'success');
      expect(event.result, 'success');
      expect(event.source, 'email');
    });

    test('description includes result', () {
      final event = TomFieldValidatedEvent(source: 'email', result: 'error');
      expect(event.description, contains('error'));
    });
  });

  group('TomFieldAuthChangedEvent', () {
    test('stores old and new states', () {
      final event = TomFieldAuthChangedEvent(
        source: 'secret',
        oldState: 'full',
        newState: 'read',
      );
      expect(event.oldState, 'full');
      expect(event.newState, 'read');
    });
  });

  group('TomFieldBoundEvent', () {
    test('creates with source', () {
      final event = TomFieldBoundEvent(source: 'name');
      expect(event.source, 'name');
      expect(event.description, contains('bound'));
    });
  });

  group('TomFieldCommittedEvent', () {
    test('creates with source', () {
      final event = TomFieldCommittedEvent(source: 'name');
      expect(event.source, 'name');
      expect(event.description, contains('committed'));
    });
  });

  group('TomFormBoundEvent', () {
    test('creates with source', () {
      final event = TomFormBoundEvent(source: 'loginForm');
      expect(event.source, 'loginForm');
      expect(event.description, contains('bound'));
    });
  });

  group('TomFormSavedEvent', () {
    test('creates with source', () {
      final event = TomFormSavedEvent(source: 'loginForm');
      expect(event.source, 'loginForm');
      expect(event.description, contains('saved'));
    });
  });

  group('TomFormDiscardedEvent', () {
    test('creates with source', () {
      final event = TomFormDiscardedEvent(source: 'loginForm');
      expect(event.source, 'loginForm');
      expect(event.description, contains('discarded'));
    });
  });

  group('event hierarchy', () {
    test('all events are TomFormEvent subtypes', () {
      expect(TomFieldValueChangedEvent(source: 's'), isA<TomFormEvent>());
      expect(
        TomFieldValidatedEvent(source: 's', result: 'ok'),
        isA<TomFormEvent>(),
      );
      expect(
        TomFieldAuthChangedEvent(source: 's', oldState: 'a', newState: 'b'),
        isA<TomFormEvent>(),
      );
      expect(TomFieldBoundEvent(source: 's'), isA<TomFormEvent>());
      expect(TomFieldCommittedEvent(source: 's'), isA<TomFormEvent>());
      expect(TomFormBoundEvent(source: 's'), isA<TomFormEvent>());
      expect(TomFormSavedEvent(source: 's'), isA<TomFormEvent>());
      expect(TomFormDiscardedEvent(source: 's'), isA<TomFormEvent>());
    });
  });
}
