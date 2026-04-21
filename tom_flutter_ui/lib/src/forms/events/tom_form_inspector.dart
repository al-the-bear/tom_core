import 'tom_form_event.dart';
import 'tom_form_event_listener.dart';

/// Convenience collector that buffers events for inspection.
///
/// Use for debugging, testing, or building event-log UIs:
/// ```dart
/// final inspector = TomFormInspector();
/// form.addListener(inspector);
/// // ... interact with form ...
/// print(inspector.events); // all collected events
/// print(inspector.ofType<FieldValueChangedEvent>()); // filtered
/// inspector.clear();
/// ```
class TomFormInspector with TomFormEventListener {
  final List<TomFormEvent> _events = [];

  /// All collected events (oldest first).
  List<TomFormEvent> get events => List.unmodifiable(_events);

  /// Events filtered by type.
  List<T> ofType<T extends TomFormEvent>() =>
      _events.whereType<T>().toList();

  /// Events filtered by source.
  List<TomFormEvent> fromSource(String source) =>
      _events.where((e) => e.source == source).toList();

  /// Number of collected events.
  int get length => _events.length;

  /// Whether any events have been collected.
  bool get isEmpty => _events.isEmpty;

  /// Clear all collected events.
  void clear() => _events.clear();

  // --- Override all handlers to collect events ---

  @override
  void onFieldValueChanged(FieldValueChangedEvent event) => _events.add(event);

  @override
  void onFieldValidated(FieldValidatedEvent event) => _events.add(event);

  @override
  void onFieldAuthChanged(FieldAuthChangedEvent event) => _events.add(event);

  @override
  void onFieldBound(FieldBoundEvent event) => _events.add(event);

  @override
  void onFieldCommitted(FieldCommittedEvent event) => _events.add(event);

  @override
  void onFormBound(FormBoundEvent event) => _events.add(event);

  @override
  void onFormSaved(FormSavedEvent event) => _events.add(event);

  @override
  void onFormDiscarded(FormDiscardedEvent event) => _events.add(event);

  @override
  void onFormValidated(FormValidatedEvent event) => _events.add(event);

  @override
  void onListItemAdded(ListItemAddedEvent event) => _events.add(event);

  @override
  void onListItemRemoved(ListItemRemovedEvent event) => _events.add(event);

  @override
  void onListItemReordered(ListItemReorderedEvent event) => _events.add(event);
}
