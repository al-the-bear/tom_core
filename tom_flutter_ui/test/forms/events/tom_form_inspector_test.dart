import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

void main() {
  late TomFormInspector inspector;

  setUp(() {
    inspector = TomFormInspector();
  });

  group('TomFormInspector', () {
    test('starts empty', () {
      expect(inspector.isEmpty, isTrue);
      expect(inspector.length, 0);
      expect(inspector.events, isEmpty);
    });

    test('collects field value changed events', () {
      final event = FieldValueChangedEvent(
        source: 'name',
        oldValue: 'A',
        newValue: 'B',
      );
      inspector.onFieldValueChanged(event);

      expect(inspector.length, 1);
      expect(inspector.isEmpty, isFalse);
      expect(inspector.events.first, same(event));
    });

    test('collects all event types', () {
      inspector.onFieldValueChanged(
        FieldValueChangedEvent(source: 'f1', oldValue: 'a', newValue: 'b'),
      );
      inspector.onFieldValidated(
        FieldValidatedEvent(source: 'f1', result: 'ok'),
      );
      inspector.onFieldAuthChanged(
        FieldAuthChangedEvent(source: 'f1', oldState: 'full', newState: 'read'),
      );
      inspector.onFieldBound(FieldBoundEvent(source: 'f1'));
      inspector.onFieldCommitted(FieldCommittedEvent(source: 'f1'));
      inspector.onFormBound(FormBoundEvent(source: 'form1'));
      inspector.onFormSaved(FormSavedEvent(source: 'form1'));
      inspector.onFormDiscarded(FormDiscardedEvent(source: 'form1'));

      expect(inspector.length, 8);
    });

    test('ofType filters by event type', () {
      inspector.onFieldValueChanged(
        FieldValueChangedEvent(source: 'f1'),
      );
      inspector.onFieldValidated(
        FieldValidatedEvent(source: 'f1', result: 'ok'),
      );
      inspector.onFieldValueChanged(
        FieldValueChangedEvent(source: 'f2'),
      );
      inspector.onFormSaved(FormSavedEvent(source: 'form'));

      final valueChanges = inspector.ofType<FieldValueChangedEvent>();
      expect(valueChanges, hasLength(2));
      expect(valueChanges[0].source, 'f1');
      expect(valueChanges[1].source, 'f2');

      final saves = inspector.ofType<FormSavedEvent>();
      expect(saves, hasLength(1));
    });

    test('ofType returns empty for unrecorded types', () {
      inspector.onFieldValueChanged(
        FieldValueChangedEvent(source: 'f1'),
      );

      expect(inspector.ofType<FormDiscardedEvent>(), isEmpty);
    });

    test('fromSource filters by source', () {
      inspector.onFieldValueChanged(
        FieldValueChangedEvent(source: 'name', oldValue: 'A', newValue: 'B'),
      );
      inspector.onFieldValidated(
        FieldValidatedEvent(source: 'name', result: 'ok'),
      );
      inspector.onFieldValueChanged(
        FieldValueChangedEvent(source: 'email', oldValue: '', newValue: 'x'),
      );

      final nameEvents = inspector.fromSource('name');
      expect(nameEvents, hasLength(2));

      final emailEvents = inspector.fromSource('email');
      expect(emailEvents, hasLength(1));

      final unknownEvents = inspector.fromSource('unknown');
      expect(unknownEvents, isEmpty);
    });

    test('clear removes all events', () {
      inspector.onFieldValueChanged(
        FieldValueChangedEvent(source: 'f1'),
      );
      inspector.onFormSaved(FormSavedEvent(source: 'form'));
      expect(inspector.length, 2);

      inspector.clear();

      expect(inspector.isEmpty, isTrue);
      expect(inspector.length, 0);
      expect(inspector.events, isEmpty);
    });

    test('events returns unmodifiable list', () {
      inspector.onFieldBound(FieldBoundEvent(source: 'f1'));

      expect(
        () => inspector.events.add(FormSavedEvent(source: 'x')),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('events maintain insertion order', () {
      inspector.onFieldBound(FieldBoundEvent(source: 'first'));
      inspector.onFieldCommitted(FieldCommittedEvent(source: 'second'));
      inspector.onFormSaved(FormSavedEvent(source: 'third'));

      expect(inspector.events[0].source, 'first');
      expect(inspector.events[1].source, 'second');
      expect(inspector.events[2].source, 'third');
    });
  });
}
