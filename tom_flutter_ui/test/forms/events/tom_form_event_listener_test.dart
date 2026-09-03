import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Test listener that records which typed handler was called.
class _RecordingListener with TomFormEventListener {
  final List<String> calls = [];

  @override
  void onFieldValueChanged(FieldValueChangedEvent event) {
    calls.add('onFieldValueChanged:${event.source}');
  }

  @override
  void onFieldValidated(FieldValidatedEvent event) {
    calls.add('onFieldValidated:${event.source}');
  }

  @override
  void onFieldAuthChanged(FieldAuthChangedEvent event) {
    calls.add('onFieldAuthChanged:${event.source}');
  }

  @override
  void onFieldBound(FieldBoundEvent event) {
    calls.add('onFieldBound:${event.source}');
  }

  @override
  void onFieldCommitted(FieldCommittedEvent event) {
    calls.add('onFieldCommitted:${event.source}');
  }

  @override
  void onFormBound(FormBoundEvent event) {
    calls.add('onFormBound:${event.source}');
  }

  @override
  void onFormSaved(FormSavedEvent event) {
    calls.add('onFormSaved:${event.source}');
  }

  @override
  void onFormDiscarded(FormDiscardedEvent event) {
    calls.add('onFormDiscarded:${event.source}');
  }
}

/// Listener with default (no-op) handlers to verify no crashes.
class _NoOpListener with TomFormEventListener {}

void main() {
  group('TomFormEventListener', () {
    late _RecordingListener listener;

    setUp(() {
      listener = _RecordingListener();
    });

    test('handleEvent dispatches FieldValueChangedEvent', () {
      listener.handleEvent(FieldValueChangedEvent(source: 'name'));
      expect(listener.calls, ['onFieldValueChanged:name']);
    });

    test('handleEvent dispatches FieldValidatedEvent', () {
      listener.handleEvent(FieldValidatedEvent(source: 'email', result: 'ok'));
      expect(listener.calls, ['onFieldValidated:email']);
    });

    test('handleEvent dispatches FieldAuthChangedEvent', () {
      listener.handleEvent(
        FieldAuthChangedEvent(source: 'x', oldState: 'a', newState: 'b'),
      );
      expect(listener.calls, ['onFieldAuthChanged:x']);
    });

    test('handleEvent dispatches FieldBoundEvent', () {
      listener.handleEvent(FieldBoundEvent(source: 'f'));
      expect(listener.calls, ['onFieldBound:f']);
    });

    test('handleEvent dispatches FieldCommittedEvent', () {
      listener.handleEvent(FieldCommittedEvent(source: 'f'));
      expect(listener.calls, ['onFieldCommitted:f']);
    });

    test('handleEvent dispatches FormBoundEvent', () {
      listener.handleEvent(FormBoundEvent(source: 'form'));
      expect(listener.calls, ['onFormBound:form']);
    });

    test('handleEvent dispatches FormSavedEvent', () {
      listener.handleEvent(FormSavedEvent(source: 'form'));
      expect(listener.calls, ['onFormSaved:form']);
    });

    test('handleEvent dispatches FormDiscardedEvent', () {
      listener.handleEvent(FormDiscardedEvent(source: 'form'));
      expect(listener.calls, ['onFormDiscarded:form']);
    });

    test('handleEvent dispatches multiple events in order', () {
      listener.handleEvent(FieldBoundEvent(source: 'f1'));
      listener.handleEvent(FieldValueChangedEvent(source: 'f1'));
      listener.handleEvent(FieldValidatedEvent(source: 'f1', result: 'ok'));
      listener.handleEvent(FormSavedEvent(source: 'myForm'));

      expect(listener.calls, [
        'onFieldBound:f1',
        'onFieldValueChanged:f1',
        'onFieldValidated:f1',
        'onFormSaved:myForm',
      ]);
    });

    test('handleEvent ignores unknown TomFormEvent subtype', () {
      // Base TomFormEvent — falls through the switch/default
      listener.handleEvent(TomFormEvent(source: 'x', description: 'base'));
      expect(listener.calls, isEmpty);
    });

    test('default handlers do not throw', () {
      final noOp = _NoOpListener();
      expect(() {
        noOp.handleEvent(FieldValueChangedEvent(source: 'f'));
        noOp.handleEvent(FieldValidatedEvent(source: 'f', result: 'ok'));
        noOp.handleEvent(
          FieldAuthChangedEvent(source: 'f', oldState: 'a', newState: 'b'),
        );
        noOp.handleEvent(FieldBoundEvent(source: 'f'));
        noOp.handleEvent(FieldCommittedEvent(source: 'f'));
        noOp.handleEvent(FormBoundEvent(source: 'form'));
        noOp.handleEvent(FormSavedEvent(source: 'form'));
        noOp.handleEvent(FormDiscardedEvent(source: 'form'));
      }, returnsNormally);
    });
  });
}
