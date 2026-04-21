import 'validation/form_validation_error.dart';

/// Marker interface for non-`TomForm` form children whose lifecycle a
/// parent [TomForm] should fan out into.
///
/// `TomForm` already discovers nested `TomForm` instances reflectively
/// (`nestedForms`) and propagates `bind` / `validate` / `save` / `discard`
/// / `isDirty` / `isValid` into them. List-of-sub-forms containers like
/// [TomListForm] are not themselves `TomForm`s, so they would otherwise
/// be invisible to that fan-out — which is why `_form.validate()` would
/// historically miss list-level errors and `_form.isDirty` would ignore
/// structural changes inside an embedded list.
///
/// Anything that participates in the form lifecycle but isn't a
/// `TomForm` (today: `TomListForm`; tomorrow: maps, sets, etc.) should
/// implement this interface so `TomForm` can pick it up uniformly via
/// `getMembers().values.whereType<TomFormChildContainer>()`.
abstract interface class TomFormChildContainer {
  /// Aggregate validation. Implementations are expected to fire their
  /// own `FormValidatedEvent` through whatever event bus they're wired
  /// into; the returned list lets the parent merge errors into a single
  /// combined event from the parent form.
  Future<List<FormValidationError>> validate();

  /// Aggregate save. Returns `false` when validation or any nested save
  /// fails so the parent form can short-circuit its own commit.
  Future<bool> save();

  /// Aggregate discard — restore last bound / saved state.
  void discard();

  /// Detach from any bound underlying state.
  void unbind();

  /// `true` when there are unsaved edits in this container or any of
  /// its sub-forms.
  bool get isDirty;

  /// `true` when every sub-form / row currently passes validation.
  bool get isValid;
}
