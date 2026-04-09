import 'tom_form_event.dart';

/// Mixin with default no-op handlers for each form event type.
///
/// Implement on a class and override the methods you're interested in:
/// ```dart
/// class MyFormLogger with TomFormEventListener {
///   @override
///   void onFieldValueChanged(FieldValueChangedEvent event) {
///     print('${event.source}: ${event.description}');
///   }
/// }
/// ```
mixin TomFormEventListener {
  void onFieldValueChanged(FieldValueChangedEvent event) {}
  void onFieldValidated(FieldValidatedEvent event) {}
  void onFieldAuthChanged(FieldAuthChangedEvent event) {}
  void onFieldBound(FieldBoundEvent event) {}
  void onFieldCommitted(FieldCommittedEvent event) {}
  void onFormBound(FormBoundEvent event) {}
  void onFormSaved(FormSavedEvent event) {}
  void onFormDiscarded(FormDiscardedEvent event) {}

  /// Dispatches an event to the appropriate typed handler.
  void handleEvent(TomFormEvent event) {
    switch (event) {
      case FieldValueChangedEvent e:
        onFieldValueChanged(e);
      case FieldValidatedEvent e:
        onFieldValidated(e);
      case FieldAuthChangedEvent e:
        onFieldAuthChanged(e);
      case FieldBoundEvent e:
        onFieldBound(e);
      case FieldCommittedEvent e:
        onFieldCommitted(e);
      case FormBoundEvent e:
        onFormBound(e);
      case FormSavedEvent e:
        onFormSaved(e);
      case FormDiscardedEvent e:
        onFormDiscarded(e);
      default:
        break;
    }
  }
}
