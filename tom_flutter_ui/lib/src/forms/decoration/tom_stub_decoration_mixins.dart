library;

import '../tom_form.dart';

/// Stub decoration mixins for field types whose widgets are not yet
/// implemented. Each mixin is empty — it exists as an explicit extension
/// point so future field classes can `with` it without churning their
/// existing declarations. The concrete anatomy implementation will be
/// filled in when the matching widget type lands.
///
/// See `TomStringInputDecorationMixin` / `TomDropdownDecorationMixin`
/// for the implemented pattern.

/// Stub — slider fields.
mixin TomSliderDecorationMixin<T> on TomField<T> {}

/// Stub — checkbox fields.
mixin TomCheckboxDecorationMixin on TomField<bool> {}

/// Stub — switch fields.
mixin TomSwitchDecorationMixin on TomField<bool> {}

/// Stub — segmented-button fields.
mixin TomSegmentedDecorationMixin<T> on TomField<T> {}

/// Stub — radio-group fields.
mixin TomRadioGroupDecorationMixin<T> on TomField<T> {}

/// Stub — date-picker fields.
mixin TomDatePickerDecorationMixin<T> on TomField<T> {}

/// Stub — time-picker fields.
mixin TomTimePickerDecorationMixin<T> on TomField<T> {}

/// Stub — file-picker fields.
mixin TomFilePickerDecorationMixin<T> on TomField<T> {}

/// Stub — chips / multi-select fields.
mixin TomChipsDecorationMixin<T> on TomField<T> {}

/// Stub — multiline-input fields.
mixin TomMultilineInputDecorationMixin<T> on TomField<T> {}
