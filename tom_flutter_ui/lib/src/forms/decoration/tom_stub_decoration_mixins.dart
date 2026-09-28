library;

import '../tom_form.dart';

/// Reserved decoration mixins, one per field family that has no decoration of
/// its own.
///
/// Each is empty and **nothing in the package mixes any of them in**: the
/// sliders, checkboxes, switches, segmented buttons, radio groups, date and
/// time pickers, file pickers and chip fields they name all ship, and all of
/// them take `TomGenericFieldDecorationMixin` instead. They are an extension
/// point the catalogue did not need — the names are here so a family that
/// grows its own anatomy can acquire one without churning the declarations
/// that already exist.
///
/// See `TomStringInputDecorationMixin` / `TomDropdownDecorationMixin` for the
/// two families that do carry their own, and
/// `TomGenericFieldDecorationMixin` for what every other field uses.

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
