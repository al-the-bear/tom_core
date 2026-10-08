import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Test listener that records which typed handler was called.
class _RecordingListener with TomFormEventListener {
  final List<String> calls = [];

  @override
  void onFieldValueChanged(TomFieldValueChangedEvent event) {
    calls.add('onFieldValueChanged:${event.source}');
  }

  @override
  void onFieldValidated(TomFieldValidatedEvent event) {
    calls.add('onFieldValidated:${event.source}');
  }

  @override
  void onFieldAuthChanged(TomFieldAuthChangedEvent event) {
    calls.add('onFieldAuthChanged:${event.source}');
  }

  @override
  void onFieldBound(TomFieldBoundEvent event) {
    calls.add('onFieldBound:${event.source}');
  }

  @override
  void onFieldCommitted(TomFieldCommittedEvent event) {
    calls.add('onFieldCommitted:${event.source}');
  }

  @override
  void onFormBound(TomFormBoundEvent event) {
    calls.add('onFormBound:${event.source}');
  }

  @override
  void onFormSaved(TomFormSavedEvent event) {
    calls.add('onFormSaved:${event.source}');
  }

  @override
  void onFormDiscarded(TomFormDiscardedEvent event) {
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

    test('handleEvent dispatches TomFieldValueChangedEvent', () {
      listener.handleEvent(TomFieldValueChangedEvent(source: 'name'));
      expect(listener.calls, ['onFieldValueChanged:name']);
    });

    test('handleEvent dispatches TomFieldValidatedEvent', () {
      listener.handleEvent(
        TomFieldValidatedEvent(source: 'email', result: 'ok'),
      );
      expect(listener.calls, ['onFieldValidated:email']);
    });

    test('handleEvent dispatches TomFieldAuthChangedEvent', () {
      listener.handleEvent(
        TomFieldAuthChangedEvent(source: 'x', oldState: 'a', newState: 'b'),
      );
      expect(listener.calls, ['onFieldAuthChanged:x']);
    });

    test('handleEvent dispatches TomFieldBoundEvent', () {
      listener.handleEvent(TomFieldBoundEvent(source: 'f'));
      expect(listener.calls, ['onFieldBound:f']);
    });

    test('handleEvent dispatches TomFieldCommittedEvent', () {
      listener.handleEvent(TomFieldCommittedEvent(source: 'f'));
      expect(listener.calls, ['onFieldCommitted:f']);
    });

    test('handleEvent dispatches TomFormBoundEvent', () {
      listener.handleEvent(TomFormBoundEvent(source: 'form'));
      expect(listener.calls, ['onFormBound:form']);
    });

    test('handleEvent dispatches TomFormSavedEvent', () {
      listener.handleEvent(TomFormSavedEvent(source: 'form'));
      expect(listener.calls, ['onFormSaved:form']);
    });

    test('handleEvent dispatches TomFormDiscardedEvent', () {
      listener.handleEvent(TomFormDiscardedEvent(source: 'form'));
      expect(listener.calls, ['onFormDiscarded:form']);
    });

    test('handleEvent dispatches multiple events in order', () {
      listener.handleEvent(TomFieldBoundEvent(source: 'f1'));
      listener.handleEvent(TomFieldValueChangedEvent(source: 'f1'));
      listener.handleEvent(TomFieldValidatedEvent(source: 'f1', result: 'ok'));
      listener.handleEvent(TomFormSavedEvent(source: 'myForm'));

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
        noOp.handleEvent(TomFieldValueChangedEvent(source: 'f'));
        noOp.handleEvent(TomFieldValidatedEvent(source: 'f', result: 'ok'));
        noOp.handleEvent(
          TomFieldAuthChangedEvent(source: 'f', oldState: 'a', newState: 'b'),
        );
        noOp.handleEvent(TomFieldBoundEvent(source: 'f'));
        noOp.handleEvent(TomFieldCommittedEvent(source: 'f'));
        noOp.handleEvent(TomFormBoundEvent(source: 'form'));
        noOp.handleEvent(TomFormSavedEvent(source: 'form'));
        noOp.handleEvent(TomFormDiscardedEvent(source: 'form'));
      }, returnsNormally);
    });
  });
}
