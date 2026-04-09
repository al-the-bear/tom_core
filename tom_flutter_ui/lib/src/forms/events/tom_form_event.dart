/// Base class for all form-related events.
///
/// Events are fired by [TomForm] and [TomField] during lifecycle operations.
/// Use [TomFormEventListener] to handle events, or [TomFormInspector] to
/// collect and inspect them.
class TomFormEvent {
  /// When the event occurred.
  final DateTime timestamp;

  /// Human-readable source identifier (e.g., field ID or form ID).
  final String source;

  /// Human-readable description of what happened.
  final String description;

  TomFormEvent({
    required this.source,
    required this.description,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => '$runtimeType($source: $description)';
}

// ---------------------------------------------------------------------------
// Field events
// ---------------------------------------------------------------------------

/// Fired when a field's value changes.
class FieldValueChangedEvent extends TomFormEvent {
  final Object? oldValue;
  final Object? newValue;

  FieldValueChangedEvent({
    required super.source,
    this.oldValue,
    this.newValue,
  }) : super(description: 'Value changed from $oldValue to $newValue');
}

/// Fired when a field completes validation.
class FieldValidatedEvent extends TomFormEvent {
  /// The validation result (success, error, or pending).
  final Object result;

  FieldValidatedEvent({
    required super.source,
    required this.result,
  }) : super(description: 'Validated: $result');
}

/// Fired when a field's effective authorization state changes.
class FieldAuthChangedEvent extends TomFormEvent {
  final Object oldState;
  final Object newState;

  FieldAuthChangedEvent({
    required super.source,
    required this.oldState,
    required this.newState,
  }) : super(description: 'Auth changed from $oldState to $newState');
}

/// Fired when a field is bound to data.
class FieldBoundEvent extends TomFormEvent {
  FieldBoundEvent({required super.source})
      : super(description: 'Field bound');
}

/// Fired when a field's current value is committed as the new initial value.
class FieldCommittedEvent extends TomFormEvent {
  FieldCommittedEvent({required super.source})
      : super(description: 'Field committed');
}

// ---------------------------------------------------------------------------
// Form events
// ---------------------------------------------------------------------------

/// Fired when a form is bound to a data object.
class FormBoundEvent extends TomFormEvent {
  FormBoundEvent({required super.source})
      : super(description: 'Form bound');
}

/// Fired when a form saves successfully.
class FormSavedEvent extends TomFormEvent {
  FormSavedEvent({required super.source})
      : super(description: 'Form saved');
}

/// Fired when a form discards its edits.
class FormDiscardedEvent extends TomFormEvent {
  FormDiscardedEvent({required super.source})
      : super(description: 'Form discarded');
}
