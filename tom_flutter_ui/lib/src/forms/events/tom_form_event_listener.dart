import 'tom_form_event.dart';

/// Mixin with default no-op handlers for each form event type.
///
/// Implement on a class and override the methods you're interested in:
/// ```dart
/// class MyFormLogger with TomFormEventListener {
///   @override
///   void onFieldValueChanged(TomFieldValueChangedEvent event) {
///     print('${event.source}: ${event.description}');
///   }
/// }
/// ```
mixin TomFormEventListener {
  void onFieldValueChanged(TomFieldValueChangedEvent event) {}
  void onFieldValidated(TomFieldValidatedEvent event) {}
  void onFieldAuthChanged(TomFieldAuthChangedEvent event) {}
  void onFieldBound(TomFieldBoundEvent event) {}
  void onFieldCommitted(TomFieldCommittedEvent event) {}
  void onFormBound(TomFormBoundEvent event) {}
  void onFormSaved(TomFormSavedEvent event) {}
  void onFormDiscarded(TomFormDiscardedEvent event) {}
  void onFormValidated(TomFormValidatedEvent event) {}

  // List form events
  void onListItemAdded(TomListItemAddedEvent event) {}
  void onListItemRemoved(TomListItemRemovedEvent event) {}
  void onListItemReordered(TomListItemReorderedEvent event) {}

  /// Dispatches an event to the appropriate typed handler.
  void handleEvent(TomFormEvent event) {
    switch (event) {
      case TomFieldValueChangedEvent e:
        onFieldValueChanged(e);
      case TomFieldValidatedEvent e:
        onFieldValidated(e);
      case TomFieldAuthChangedEvent e:
        onFieldAuthChanged(e);
      case TomFieldBoundEvent e:
        onFieldBound(e);
      case TomFieldCommittedEvent e:
        onFieldCommitted(e);
      case TomFormBoundEvent e:
        onFormBound(e);
      case TomFormSavedEvent e:
        onFormSaved(e);
      case TomFormDiscardedEvent e:
        onFormDiscarded(e);
      case TomFormValidatedEvent e:
        onFormValidated(e);
      case TomListItemAddedEvent e:
        onListItemAdded(e);
      case TomListItemRemovedEvent e:
        onListItemRemoved(e);
      case TomListItemReorderedEvent e:
        onListItemReordered(e);
      default:
        break;
    }
  }
}
