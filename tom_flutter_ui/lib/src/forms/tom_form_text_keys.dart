/// The text keys each form field, list form and list toolbar reads under its
/// resource path, as data: the forms' counterpart of [tomWrapperTextKeys].
///
/// A field reads its texts at `<field path>.<suffix>`, where the field path is
/// the form's path and the field's `tomId` (`customer.name.label`). Every form
/// key is optional: an explicit value given in code wins, and without either
/// the field shows no such text (a missing `label` shows the field's `tomId`
/// where a label is needed, as in an error list). A field key never falls back
/// to the bare suffix: `customer.name.label` is the only key a field's label
/// is read from.
///
/// Three kinds of key are not here, because they are not keys of one field:
///
/// - **The shared captions** of the form and file widgets ("Cancel", "Choose
///   file…"), read through `TomFormLabels` and `TomFileLabels`: each resolves
///   `<field path>.<key>`, then the global `<key>` (`form.cancel`,
///   `file.choose`), then the built-in English. Their keys are listed on
///   those two classes.
/// - **Validation messages**, read under the validator's error key
///   (`error.required`): `<field path>.<error key>`, then the global
///   `<error key>`, then the key itself.
/// - **Style and theme settings**, read under the style's own path.
///
/// `test/forms/form_text_keys_test.dart` holds the map to the forms: it builds
/// fields with a resource provider that records each key asked for, and reads
/// every class's literal reads from the sources, so the map cannot drift from
/// the code.
library;

import '../widget_base/tom_wrapper_text_keys.dart';

const _optional = TomTextKeyPresence.optional;

/// The text keys of every form field, list form and list toolbar of the
/// package, by class name.
///
/// Every concrete field class is listed: a field reads at least its `label`
/// and the `validators` setting, the resource-declared validators
/// (`required,minLength:8`), which `TomField` reads for every field.
const Map<String, List<TomTextKey>> tomFormFieldTextKeys = {
  'TomCupertinoFormBoolSwitch': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomCupertinoFormBoolToggle': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('onLabel', TomTextKeyKind.text, _optional),
    TomTextKey('offLabel', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomCupertinoFormCurrencyDoubleInput': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('hint', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomCupertinoFormDatePicker': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomCupertinoFormDateRangePicker': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomCupertinoFormDateTimePicker': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomCupertinoFormDoubleInput': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('hint', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomCupertinoFormDurationPicker': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomCupertinoFormEnumPicker': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomCupertinoFormEnumSegmented': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomCupertinoFormFileThumbnail': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomCupertinoFormFileUpload': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomCupertinoFormIntInput': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('hint', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomCupertinoFormIntPicker': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('hint', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomCupertinoFormLookupSheet': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomCupertinoFormNDateInput': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('hint', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('nullDisplay', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomCupertinoFormNDoubleInput': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('hint', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('nullDisplay', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomCupertinoFormNIntInput': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('hint', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('nullDisplay', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomCupertinoFormNStringInput': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('hint', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('nullDisplay', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomCupertinoFormNullableBoolToggle': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('onLabel', TomTextKeyKind.text, _optional),
    TomTextKey('offLabel', TomTextKeyKind.text, _optional),
    TomTextKey('nullLabel', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomCupertinoFormObjectPicker': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomCupertinoFormSearchInput': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('hint', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomCupertinoFormStringInput': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('hint', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomCupertinoFormStringListCheckedPicker': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('hint', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomCupertinoFormStringPicker': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('hint', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomCupertinoFormStringSearchInput': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('hint', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomCupertinoFormStringSegmented': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('hint', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomCupertinoFormTimePicker': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomExpandableListForm': [
    TomTextKey('empty', TomTextKeyKind.text, _optional),
    TomTextKey('policy', TomTextKeyKind.setting, _optional),
  ],
  'TomFormBoolCheckbox': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormBoolSwitch': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormBoolToggle': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('onLabel', TomTextKeyKind.text, _optional),
    TomTextKey('offLabel', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormCurrencyDoubleInput': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('hint', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormDateCalendar': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormDatePicker': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormDateRangePicker': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormDateTextInput': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('dateHint', TomTextKeyKind.text, _optional),
    TomTextKey('dateFormat', TomTextKeyKind.setting, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormDateTimePicker': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormDateTimeTextInput': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('dateTimeHint', TomTextKeyKind.text, _optional),
    TomTextKey('dateTimeFormat', TomTextKeyKind.setting, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormDoubleInput': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('hint', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormDoubleRangeSlider': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormDoubleSlider': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('hint', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormDurationInput': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormEnumDropdown': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormEnumFilterChips': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormEnumRadioGroup': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormEnumSegmented': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormFileDropzone': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormFileThumbnail': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormFileUpload': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormIntFilterChips': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormIntInput': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('hint', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormIntRangeSlider': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormIntSlider': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('hint', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormIntStepper': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('hint', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormLookupDialog': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormNDateInput': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('hint', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('nullDisplay', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormNDoubleInput': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('hint', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('nullDisplay', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormNEnumDropdown': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('hint', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('nullDisplay', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormNIntInput': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('hint', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('nullDisplay', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormNStringInput': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('hint', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('nullDisplay', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormNullableBoolCheckbox': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormObjectDropdown': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormObjectFilterChips': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormPercentDoubleInput': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('hint', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormSearchInput': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('hint', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormStringChoiceChips': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('hint', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormStringDropdown': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('hint', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormStringFilterChips': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormStringInput': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('hint', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormStringMultiCheckbox': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormStringRadioGroup': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('hint', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormStringSegmented': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('hint', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormTimePicker': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomFormTimeTextInput': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('description', TomTextKeyKind.text, _optional),
    TomTextKey('timeHint', TomTextKeyKind.text, _optional),
    TomTextKey('timeFormat', TomTextKeyKind.setting, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
  'TomInlineListForm': [TomTextKey('empty', TomTextKeyKind.text, _optional)],
  'TomListFormToolbar': [
    TomTextKey('add.label', TomTextKeyKind.text, _optional),
    TomTextKey('add.tooltip', TomTextKeyKind.text, _optional),
    TomTextKey('moveDown.label', TomTextKeyKind.text, _optional),
    TomTextKey('moveDown.tooltip', TomTextKeyKind.text, _optional),
    TomTextKey('moveUp.label', TomTextKeyKind.text, _optional),
    TomTextKey('moveUp.tooltip', TomTextKeyKind.text, _optional),
    TomTextKey('remove.label', TomTextKeyKind.text, _optional),
    TomTextKey('remove.tooltip', TomTextKeyKind.text, _optional),
  ],
  'TomListRowMoveButtons': [
    TomTextKey('moveDown.tooltip', TomTextKeyKind.text, _optional),
    TomTextKey('moveUp.tooltip', TomTextKeyKind.text, _optional),
  ],
  'TomMasterDetailListForm': [
    TomTextKey('empty', TomTextKeyKind.text, _optional),
  ],
  'TomReorderHandle': [TomTextKey('tooltip', TomTextKeyKind.text, _optional)],
  'TomTextFormFieldBase': [
    TomTextKey('label', TomTextKeyKind.text, _optional),
    TomTextKey('hint', TomTextKeyKind.text, _optional),
    TomTextKey('helper', TomTextKeyKind.text, _optional),
    TomTextKey('validators', TomTextKeyKind.setting, _optional),
  ],
};
