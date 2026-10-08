# Tom Flutter UI API Reference: Forms Module

The declarative forms framework: form and field bases, the Material and
Cupertino field catalogues, styling, validation, events, selection sources,
file transfer, and the list-form containers.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Form and field core](#form-and-field-core)
  - [TomForm](#tomform)
  - [TomField](#tomfield)
  - [TomTextFormFieldBase](#tomtextformfieldbase)
  - [TomFormChildContainer](#tomformchildcontainer)
  - [TomFormLabels](#tomformlabels)
  - [TomFieldWidgetAdapter](#tomfieldwidgetadapter)
- [Family selection](#family-selection)
  - [TomFormFieldFamilyKind](#tomformfieldfamilykind)
  - [TomFormFieldFamily](#tomformfieldfamily)
- [Styling](#styling)
  - [TomFormStyle](#tomformstyle)
  - [TomCupertinoFormStyle](#tomcupertinoformstyle)
  - [TomFieldStyle](#tomfieldstyle)
  - [TomFieldPartialStyle](#tomfieldpartialstyle)
  - [TomStringInputStyle](#tomstringinputstyle)
  - [TomStringInputVariant](#tomstringinputvariant)
  - [TomDropdownStyle](#tomdropdownstyle)
  - [TomSliderStyle](#tomsliderstyle)
  - [TomCheckboxStyle](#tomcheckboxstyle)
  - [TomSwitchStyle](#tomswitchstyle)
  - [TomSegmentedStyle](#tomsegmentedstyle)
  - [TomRadioGroupStyle](#tomradiogroupstyle)
  - [TomDatePickerStyle](#tomdatepickerstyle)
  - [TomTimePickerStyle](#tomtimepickerstyle)
  - [TomFilePickerStyle](#tomfilepickerstyle)
  - [TomChipsStyle](#tomchipsstyle)
  - [TomMultilineInputStyle](#tommultilineinputstyle)
  - [TomFormStyleScope](#tomformstylescope)
  - [TomBreakpoint](#tombreakpoint)
  - [TomThemeSpec](#tomthemespec)
  - [TomLabelPlacement](#tomlabelplacement)
  - [TomErrorPlacement](#tomerrorplacement)
  - [TomRequiredIndicator](#tomrequiredindicator)
  - [TomDescriptionPlacement](#tomdescriptionplacement)
  - [TomActionIconPlacement](#tomactioniconplacement)
- [Decoration mixins](#decoration-mixins)
  - [TomStringInputDecorationMixin](#tomstringinputdecorationmixin)
  - [TomDropdownDecorationMixin](#tomdropdowndecorationmixin)
  - [TomGenericFieldDecorationMixin](#tomgenericfielddecorationmixin)
- [Validation](#validation)
  - [TomValidationResult](#tomvalidationresult)
  - [TomValidationPristine](#tomvalidationpristine)
  - [TomValidationSuccess](#tomvalidationsuccess)
  - [TomValidationError](#tomvalidationerror)
  - [TomValidationPending](#tomvalidationpending)
  - [TomValidator](#tomvalidator)
  - [TomSlowValidator](#tomslowvalidator)
  - [TomValidators](#tomvalidators)
  - [TomValidatorFactory](#tomvalidatorfactory)
  - [TomValidatorRegistry](#tomvalidatorregistry)
  - [TomFormValidationError](#tomformvalidationerror)
- [Events](#events)
  - [TomFormEvent](#tomformevent)
  - [TomFieldValueChangedEvent](#tomfieldvaluechangedevent)
  - [TomFieldValidatedEvent](#tomfieldvalidatedevent)
  - [TomFieldAuthChangedEvent](#tomfieldauthchangedevent)
  - [TomFieldBoundEvent](#tomfieldboundevent)
  - [TomFieldCommittedEvent](#tomfieldcommittedevent)
  - [TomFormBoundEvent](#tomformboundevent)
  - [TomFormSavedEvent](#tomformsavedevent)
  - [TomFormDiscardedEvent](#tomformdiscardedevent)
  - [TomFormValidatedEvent](#tomformvalidatedevent)
  - [TomListItemAddedEvent](#tomlistitemaddedevent)
  - [TomListItemRemovedEvent](#tomlistitemremovedevent)
  - [TomListItemReorderedEvent](#tomlistitemreorderedevent)
  - [TomFormEventListener](#tomformeventlistener)
  - [TomFormEventSource](#tomformeventsource)
  - [TomFormInspector](#tomforminspector)
- [Selection sources](#selection-sources)
  - [TomSelectableSource](#tomselectablesource)
  - [TomSelectableItem](#tomselectableitem)
  - [TomStaticSelectableSource](#tomstaticselectablesource)
  - [TomEnumSelectableSource](#tomenumselectablesource)
  - [TomEnumNameSelectableSource](#tomenumnameselectablesource)
  - [TomMutableSelectableSource](#tommutableselectablesource)
- [File fields and transfer](#file-fields-and-transfer)
  - [TomFileRef](#tomfileref)
  - [TomFilePicker](#tomfilepicker)
  - [TomPlatformFilePicker](#tomplatformfilepicker)
  - [TomPickedFile](#tompickedfile)
  - [TomFilePickRequest](#tomfilepickrequest)
  - [TomFilePickKind](#tomfilepickkind)
  - [TomFilePickerRegistry](#tomfilepickerregistry)
  - [TomFilePickers](#tomfilepickers)
  - [TomFileLabels](#tomfilelabels)
  - [TomFileTransferController](#tomfiletransfercontroller)
  - [TomFileTransferState](#tomfiletransferstate)
  - [TomTransferPhase](#tomtransferphase)
  - [TomTransferKind](#tomtransferkind)
  - [TomFileTransferIndicator](#tomfiletransferindicator)
- [List forms](#list-forms)
  - [TomListForm](#tomlistform)
  - [TomInlineListForm](#tominlinelistform)
  - [TomExpandableListForm](#tomexpandablelistform)
  - [TomExpandableListFormController](#tomexpandablelistformcontroller)
  - [TomExpansionPolicy](#tomexpansionpolicy)
  - [TomMasterDetailListForm](#tommasterdetaillistform)
  - [TomListFormToolbar](#tomlistformtoolbar)
  - [TomListRowMoveButtons](#tomlistrowmovebuttons)
  - [TomRowMoveButtonsPosition](#tomrowmovebuttonsposition)
  - [TomReorderHandle](#tomreorderhandle)
- [Form-level widgets](#form-level-widgets)
  - [TomErrorView](#tomerrorview)
  - [TomFormErrorBanner](#tomformerrorbanner)
  - [TomRowErrorStrip](#tomrowerrorstrip)
  - [TomMultiObservableBuilder](#tommultiobservablebuilder)
  - [TomUnsavedChangesGuard](#tomunsavedchangesguard)
  - [TomUnsavedChangesChoice](#tomunsavedchangeschoice)
- [Material fields](#material-fields)
  - [TomFormBoolField](#tomformboolfield)
  - [TomFormBoolCheckbox](#tomformboolcheckbox)
  - [TomFormBoolSwitch](#tomformboolswitch)
  - [TomFormBoolToggle](#tomformbooltoggle)
  - [TomFormNullableBoolField](#tomformnullableboolfield)
  - [TomFormNullableBoolCheckbox](#tomformnullableboolcheckbox)
  - [TomFormStringField](#tomformstringfield)
  - [TomFormStringInput](#tomformstringinput)
  - [TomFormStringDropdown](#tomformstringdropdown)
  - [TomFormStringSegmented](#tomformstringsegmented)
  - [TomFormStringRadioGroup](#tomformstringradiogroup)
  - [TomFormStringChoiceChips](#tomformstringchoicechips)
  - [TomFormStringListField](#tomformstringlistfield)
  - [TomFormStringFilterChips](#tomformstringfilterchips)
  - [TomFormStringMultiCheckbox](#tomformstringmulticheckbox)
  - [TomFormIntField](#tomformintfield)
  - [TomFormIntInput](#tomformintinput)
  - [TomFormIntSlider](#tomformintslider)
  - [TomFormIntStepper](#tomformintstepper)
  - [TomFormIntListField](#tomformintlistfield)
  - [TomFormIntFilterChips](#tomformintfilterchips)
  - [TomFormDoubleField](#tomformdoublefield)
  - [TomFormDoubleInput](#tomformdoubleinput)
  - [TomFormCurrencyDoubleInput](#tomformcurrencydoubleinput)
  - [TomFormPercentDoubleInput](#tomformpercentdoubleinput)
  - [TomFormDoubleSlider](#tomformdoubleslider)
  - [TomCurrencyFormatProfile](#tomcurrencyformatprofile)
  - [TomNumRange](#tomnumrange)
  - [TomFormIntRangeField](#tomformintrangefield)
  - [TomFormIntRangeSlider](#tomformintrangeslider)
  - [TomFormDoubleRangeField](#tomformdoublerangefield)
  - [TomFormDoubleRangeSlider](#tomformdoublerangeslider)
  - [TomDateTimeFormat](#tomdatetimeformat)
  - [TomFormDateField](#tomformdatefield)
  - [TomFormDatePicker](#tomformdatepicker)
  - [TomFormDateCalendar](#tomformdatecalendar)
  - [TomFormDateTextInput](#tomformdatetextinput)
  - [TomFormTimeField](#tomformtimefield)
  - [TomFormTimePicker](#tomformtimepicker)
  - [TomFormTimeTextInput](#tomformtimetextinput)
  - [TomFormDateTimeField](#tomformdatetimefield)
  - [TomFormDateTimePicker](#tomformdatetimepicker)
  - [TomFormDateTimeTextInput](#tomformdatetimetextinput)
  - [TomFormDateRangeField](#tomformdaterangefield)
  - [TomFormDateRangePicker](#tomformdaterangepicker)
  - [TomTimeOfDayRange](#tomtimeofdayrange)
  - [TomFormTimeRangeField](#tomformtimerangefield)
  - [TomFormDateTimeRangeField](#tomformdatetimerangefield)
  - [TomFormDurationField](#tomformdurationfield)
  - [TomFormDurationInput](#tomformdurationinput)
  - [TomFormEnumField](#tomformenumfield)
  - [TomFormEnumDropdown](#tomformenumdropdown)
  - [TomFormEnumSegmented](#tomformenumsegmented)
  - [TomFormEnumRadioGroup](#tomformenumradiogroup)
  - [TomFormEnumListField](#tomformenumlistfield)
  - [TomFormEnumFilterChips](#tomformenumfilterchips)
  - [TomFormObjectField](#tomformobjectfield)
  - [TomFormObjectDropdown](#tomformobjectdropdown)
  - [TomFormObjectListField](#tomformobjectlistfield)
  - [TomFormObjectFilterChips](#tomformobjectfilterchips)
  - [TomFormSearchField](#tomformsearchfield)
  - [TomFormSearchInput](#tomformsearchinput)
  - [TomFormLookupField](#tomformlookupfield)
  - [TomFormLookupDialog](#tomformlookupdialog)
  - [TomFormNStringInput](#tomformnstringinput)
  - [TomFormNIntInput](#tomformnintinput)
  - [TomFormNDoubleInput](#tomformndoubleinput)
  - [TomFormNDateInput](#tomformndateinput)
  - [TomFormNEnumDropdown](#tomformnenumdropdown)
  - [TomFormFileField](#tomformfilefield)
  - [TomFormFileUpload](#tomformfileupload)
  - [TomFormFileDropzone](#tomformfiledropzone)
  - [TomFormFileThumbnail](#tomformfilethumbnail)
  - [TomFileFieldStateMixin](#tomfilefieldstatemixin)
  - [TomFileThumbnailStateMixin](#tomfilethumbnailstatemixin)
- [Cupertino fields](#cupertino-fields)
  - [TomCupertinoFormBoolSwitch](#tomcupertinoformboolswitch)
  - [TomCupertinoFormBoolToggle](#tomcupertinoformbooltoggle)
  - [TomCupertinoFormNullableBoolToggle](#tomcupertinoformnullablebooltoggle)
  - [TomCupertinoFormStringInput](#tomcupertinoformstringinput)
  - [TomCupertinoFormStringPicker](#tomcupertinoformstringpicker)
  - [TomCupertinoFormStringSearchInput](#tomcupertinoformstringsearchinput)
  - [TomCupertinoFormStringSegmented](#tomcupertinoformstringsegmented)
  - [TomCupertinoFormStringListCheckedPicker](#tomcupertinoformstringlistcheckedpicker)
  - [TomCupertinoFormIntInput](#tomcupertinoformintinput)
  - [TomCupertinoFormIntPicker](#tomcupertinoformintpicker)
  - [TomCupertinoFormDoubleInput](#tomcupertinoformdoubleinput)
  - [TomCupertinoFormCurrencyDoubleInput](#tomcupertinoformcurrencydoubleinput)
  - [TomCupertinoFormNStringInput](#tomcupertinoformnstringinput)
  - [TomCupertinoFormNIntInput](#tomcupertinoformnintinput)
  - [TomCupertinoFormNDoubleInput](#tomcupertinoformndoubleinput)
  - [TomCupertinoFormNDateInput](#tomcupertinoformndateinput)
  - [TomCupertinoFormDatePicker](#tomcupertinoformdatepicker)
  - [TomCupertinoFormTimePicker](#tomcupertinoformtimepicker)
  - [TomCupertinoFormDateTimePicker](#tomcupertinoformdatetimepicker)
  - [TomCupertinoFormDurationPicker](#tomcupertinoformdurationpicker)
  - [TomCupertinoFormDateRangePicker](#tomcupertinoformdaterangepicker)
  - [TomCupertinoFormEnumPicker](#tomcupertinoformenumpicker)
  - [TomCupertinoFormEnumSegmented](#tomcupertinoformenumsegmented)
  - [TomCupertinoFormObjectPicker](#tomcupertinoformobjectpicker)
  - [TomCupertinoFormSearchInput](#tomcupertinoformsearchinput)
  - [TomCupertinoFormLookupSheet](#tomcupertinoformlookupsheet)
  - [TomCupertinoFormFileUpload](#tomcupertinoformfileupload)
  - [TomCupertinoFormFileThumbnail](#tomcupertinoformfilethumbnail)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Sources: `lib/src/forms/decoration/tom_dropdown_decoration_mixin.dart`, `lib/src/forms/decoration/tom_field_anatomy.dart`, `lib/src/forms/decoration/tom_generic_field_decoration_mixin.dart`, `lib/src/forms/decoration/tom_string_input_decoration_mixin.dart`, `lib/src/forms/events/tom_form_event.dart`, `lib/src/forms/events/tom_form_event_listener.dart`, `lib/src/forms/events/tom_form_event_source.dart`, `lib/src/forms/events/tom_form_inspector.dart`, `lib/src/forms/fields/cupertino/tom_cupertino_form_bool_fields.dart`, `lib/src/forms/fields/cupertino/tom_cupertino_form_date_time_fields.dart`, `lib/src/forms/fields/cupertino/tom_cupertino_form_enum_object_fields.dart`, `lib/src/forms/fields/cupertino/tom_cupertino_form_file_field.dart`, `lib/src/forms/fields/cupertino/tom_cupertino_form_nullable_inputs.dart`, `lib/src/forms/fields/cupertino/tom_cupertino_form_numeric_fields.dart`, `lib/src/forms/fields/cupertino/tom_cupertino_form_search_lookup_fields.dart`, `lib/src/forms/fields/cupertino/tom_cupertino_form_string_fields.dart`, `lib/src/forms/fields/cupertino/tom_cupertino_form_string_list_field.dart`, `lib/src/forms/fields/tom_date_time_format.dart`, `lib/src/forms/fields/tom_field_widget_adapter.dart`, `lib/src/forms/fields/tom_form_bool_field.dart`, `lib/src/forms/fields/tom_form_date_time_fields.dart`, `lib/src/forms/fields/tom_form_double_field.dart`, `lib/src/forms/fields/tom_form_duration_field.dart`, `lib/src/forms/fields/tom_form_enum_object_fields.dart`, `lib/src/forms/fields/tom_form_file_field.dart`, `lib/src/forms/fields/tom_form_int_field.dart`, `lib/src/forms/fields/tom_form_int_list_field.dart`, `lib/src/forms/fields/tom_form_nullable_bool_field.dart`, `lib/src/forms/fields/tom_form_nullable_inputs.dart`, `lib/src/forms/fields/tom_form_range_fields.dart`, `lib/src/forms/fields/tom_form_search_lookup_fields.dart`, `lib/src/forms/fields/tom_form_string_field.dart`, `lib/src/forms/fields/tom_form_string_list_field.dart`, `lib/src/forms/fields/tom_form_string_selection.dart`, `lib/src/forms/files/file_ref.dart`, `lib/src/forms/files/tom_file_labels.dart`, `lib/src/forms/files/tom_file_picker_registry.dart`, `lib/src/forms/files/tom_file_transfer_controller.dart`, `lib/src/forms/files/tom_file_transfer_indicator.dart`, `lib/src/forms/form_field_family.dart`, `lib/src/forms/list/tom_expandable_list_form.dart`, `lib/src/forms/list/tom_inline_list_form.dart`, `lib/src/forms/list/tom_list_form.dart`, `lib/src/forms/list/tom_list_form_toolbar.dart`, `lib/src/forms/list/tom_list_row_move_buttons.dart`, `lib/src/forms/list/tom_master_detail_list_form.dart`, `lib/src/forms/list/tom_reorder_handle.dart`, `lib/src/forms/selection/static_selectable_source.dart`, `lib/src/forms/selection/tom_enum_selectable_source.dart`, `lib/src/forms/selection/tom_mutable_selectable_source.dart`, `lib/src/forms/selection/tom_selectable_source.dart`, `lib/src/forms/style/form_style_enums.dart`, `lib/src/forms/style/tom_breakpoint.dart`, `lib/src/forms/style/tom_color_tokens.dart`, `lib/src/forms/style/tom_cupertino_form_style.dart`, `lib/src/forms/style/tom_form_style.dart`, `lib/src/forms/style/tom_form_style_scope.dart`, `lib/src/forms/style/tom_theme_spec.dart`, `lib/src/forms/tom_form.dart`, `lib/src/forms/tom_form_child_container.dart`, `lib/src/forms/tom_form_labels.dart`, `lib/src/forms/tom_forms.dart`, `lib/src/forms/validation/form_validation_error.dart`, `lib/src/forms/validation/validation_result.dart`, `lib/src/forms/validation/validator_registry.dart`, `lib/src/forms/validation/validators.dart`, `lib/src/forms/widgets/tom_error_view.dart`, `lib/src/forms/widgets/tom_form_error_banner.dart`, `lib/src/forms/widgets/tom_multi_observable_builder.dart`, `lib/src/forms/widgets/tom_row_error_strip.dart`, `lib/src/forms/widgets/tom_unsaved_changes_guard.dart`.

The module `lib/src/forms/` is barrelled by `tom_forms.dart`, which re-exports 71
libraries: five at the module root, and the rest under the nine sub-folders
(`fields/` has a `cupertino/` sub-folder of its own).

A form is a class, not a widget tree. An application subclasses `TomForm<T>`,
declares its fields in `createFormElements()`, and binds a reflected domain
object to it; each field is a `TomField<V>` that owns its value, its validation
state, its authorization state and the widget that renders it. Nothing here
extends `TomFamilyBase` — the module composes the kernel's authorization,
resource and observable systems directly.

Headings in this document carry the bare type name; generic parameters are
given in the section body. That keeps every anchor a plain identifier, which is
what the two navigation gates and the cross-document links rely on.

The catalogue is the bulk of the surface and is parallel by construction: for
most value types there is an abstract `TomForm<Value>Field` naming the
contract, one or more Material renderings, and a `TomCupertinoForm…` twin.
`TomFormFieldFamily` is what picks between the two families at construction time,
so an application chooses once rather than at every call site. Appendix C of
`doc/tom_ui_widgets_forms.md` is the same catalogue arranged for reading;
this document is arranged for lookup.

Four support types are not fields but are exported beside them because they are
the value types the fields carry or the engines they use: `TomTimeOfDayRange`,
`TomNumRange`, `TomDateTimeFormat` and `TomCurrencyFormatProfile`.

## Class Hierarchy

```
TomClass (tom_core_kernel)
└── TomForm<T extends TomClass>
TomObject<T> (tom_core_kernel)
└── TomField<T>  (implements TomAuthorizable)
    ├── TomTextFormFieldBase<T>
    ├── TomFormBoolField / TomFormNullableBoolField
    ├── TomFormStringField / TomFormStringListField
    ├── TomFormIntField / TomFormIntListField / TomFormIntRangeField
    ├── TomFormDoubleField / TomFormDoubleRangeField
    ├── TomFormDateField / TomFormTimeField / TomFormDateTimeField
    ├── TomFormDateRangeField / TomFormTimeRangeField
    │   / TomFormDateTimeRangeField
    ├── TomFormDurationField
    ├── TomFormEnumField<T> / TomFormEnumListField<T>
    ├── TomFormObjectField<T> / TomFormObjectListField<T>
    ├── TomFormSearchField<T> / TomFormLookupField<T>
    └── TomFormFileField

TomFormStyle
└── TomCupertinoFormStyle
TomFieldPartialStyle
└── eleven per-family partial styles

TomValidationResult (sealed)
├── TomValidationPristine
├── TomValidationSuccess
├── TomValidationError
└── TomValidationPending

TomFormEvent
├── five field events
├── four form events
└── three list events
```

## Form and field core

### TomForm

`TomForm<T extends TomClass>` — the form itself, and the unit an application
subclasses. It owns a `TomScope`, a `basePath` for resource and authorization
resolution, the `fields` map, the bound object (`currentBinding`), the initial
snapshot used for dirty tracking, and the `changes` listenable. Subclasses
implement `createFormElements()`; `validateForm()` is the cross-field hook and
returns `TomFormValidationError`s. `isDirty`, `isValid`, `dirtyFields`,
`fieldsWithErrors`, `getField`, `nestedForms` and `childContainers` are the
read surface; `fireEvent` is the write end of the event bus.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `addListener` | `void addListener(TomFormEventListener listener)` |  |
| `attachToEnclosingForm` | `void attachToEnclosingForm(TomForm? enclosingForm)` | Records that this form is owned by a list-form (or other child container) whose own owner is [enclosingForm]. |
| `bind` | `void bind(T target)` | Bind to a TomClass instance. |
| `discard` | `void discard()` | Discard edits — resets every field in this form, every nested form, and every child container (e.g. |
| `dispose` | `void dispose()` |  |
| `formId` | `late final String formId` |  |
| `hasFormAncestor` | `bool get hasFormAncestor` | `true` when this form is wired below another form in the form tree — either via an explicit [parentForm] passed at construction, or via a child container (e.g. |
| `initialSnapshot` | `Map<String, dynamic>? get initialSnapshot` | Get the initial snapshot (values at bind time / last save). |
| `onBound` | `void onBound()` |  |
| `onDiscarded` | `void onDiscarded()` |  |
| `onDiscarding` | `void onDiscarding()` |  |
| `onSaved` | `void onSaved()` |  |
| `onSaving` | `void onSaving()` |  |
| `onUnbinding` | `void onUnbinding()` |  |
| `parentForm` | `late final TomForm? parentForm` |  |
| `prepareForSelfObservation` | `void prepareForSelfObservation()` |  |
| `registerChildContainer` | `void registerChildContainer(TomFormChildContainer container)` | Register a non-`TomForm` lifecycle child (today: `TomListForm`) so the parent form's [validate] / [save] / [discard] / [unbind] / [isDirty] / [isValid] include it. |
| `removeListener` | `void removeListener(TomFormEventListener listener)` |  |
| `save` | `Future<bool> save({bool? commitBaselines}) async` | Save form values back to bound state. |
| `unbind` | `void unbind()` | Detach from the bound state object. |
| `validate` | `Future<List<TomFormValidationError>> validate() async` | Validate every field in this form, every nested form, and every child container (e.g. |

### TomField

`TomField<T>` — one value on a form. It implements `TomAuthorizable`, so
`effectiveAuthState` resolves through `TomAuthLayers` and drives `isEditable`
and `isVisible`. It holds `tomId`, `basePath`, `initialValue`, the validator
list, the debounced `validationListenable` / `validationState` pair (with a
separate, longer debounce for `TomSlowValidator`s), the optional action icon, and
`widget` — the one member every concrete field implements.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `actionIcon` | `final Widget? actionIcon` | Optional icon rendered in the field's action slot (trailing by default, configurable per-style via `actionIconPlacement`). |
| `actionIconTooltip` | `final String? actionIconTooltip` | Optional tooltip used when [actionIcon] is a plain icon and the anatomy needs to wrap it with an [IconButton] / [Tooltip]. |
| `authorizer` | `TomAuthorizer? authorizer` | Per-field authorizer (optional). |
| `autoValidate` | `final bool autoValidate` | Whether this field validates immediately on bind without waiting for user interaction. |
| `commit` | `void commit()` | Commit current value as the new initial value. |
| `constructionScope` | `late final TomScope constructionScope` | The frame this field resolves in: its form's [TomForm.constructionScope], or the ambient scope when it has no form. |
| `dispose` | `void dispose()` | Dispose resources (timers, controllers, listeners). |
| `hasSlowValidators` | `bool get hasSlowValidators` | Whether this field has any slow validators. |
| `isDirty` | `bool get isDirty` | Whether the field value differs from initial. |
| `isSlowValidationPending` | `bool get isSlowValidationPending` |  |
| `obscureText` | `bool obscureText` |  |
| `onActionIconPressed` | `final VoidCallback? onActionIconPressed` | Callback invoked when the action icon is tapped. |
| `reset` | `void reset()` | Reset to initial value and reset validation to pristine. |
| `resolveEffectiveAuth` | `TomAuthState resolveEffectiveAuth()` | Resolve the effective authorization state for this field. |
| `resolvedErrorMessage` | `String get resolvedErrorMessage` | Translates the field's current [TomValidationError] to a human-readable string, or returns an empty string when the field has no error. |
| `resolvedLabel` | `String get resolvedLabel` | Human-readable label for this field. |
| `scope` | `late String scope` | The path prefix [basePath] is built on: `<frame>.<formId>` for a field that has a form, the frame alone for one that does not. |
| `setValue` | `void setValue(T newValue)` | Set a new value from user interaction. |
| `slowValidationDebounce` | `Duration get slowValidationDebounce` | Debounce duration for slow validation. |
| `tomGroup` | `TomAuthorizationGroup? tomGroup` |  |
| `uiStateController` | `TomUIStateController? uiStateController` | Build-time UI state controller (optional). |
| `validate` | `Future<TomValidationResult> validate() async` | Validate the current value. |
| `validationDebounce` | `Duration get validationDebounce` | Debounce duration for fast validation. |
| `validators` | `late final List<Object> validators = [ ..._codeValidators, ..._resolveResourceDeclaredValidators()]` | TomValidators applied to this field: the code-declared validators followed by any resource-declared validators (C-11). |

### TomTextFormFieldBase

`TomTextFormFieldBase<T>` — the base of every field whose input is a
`TextField`. It owns the `TextEditingController`, the raw-text mirror of the
typed value, the error-text notifier, and the split between validators that see
the parsed value and those that see the raw input.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `currentRawValue` | `String currentRawValue = ""` |  |
| `enabled` | `final bool? enabled` |  |
| `errorText` | `String? get errorText` |  |
| `helperText` | `final String? helperText` |  |
| `hintText` | `final String? hintText` |  |
| `labelText` | `final String? labelText` |  |
| `prefixIcon` | `final Widget? prefixIcon` |  |
| `set` | `T set(T value)` |  |
| `suffixIcon` | `final Widget? suffixIcon` |  |
| `t` | `String t(String key)` | Returns translated text with scope prefix applied. |
| `tOrNull` | `String? tOrNull(String key)` | Returns translated text or `null` if no resource exists. |

### TomFormChildContainer

Marker interface for a non-`TomForm` child whose lifecycle the enclosing form
drives — the list containers implement it, which is how a `TomListForm` nested
in a form is disposed and snapshotted with it.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `discard` | `void discard()` | Aggregate discard — restore last bound / saved state. |
| `isDirty` | `bool get isDirty` | `true` when there are unsaved edits in this container or any of its sub-forms. |
| `isValid` | `bool get isValid` | `true` when every sub-form / row currently passes validation. |
| `save` | `Future<bool> save({bool? commitBaselines})` | Aggregate save. |
| `unbind` | `void unbind()` | Detach from any bound underlying state. |
| `validate` | `Future<List<TomFormValidationError>> validate()` | Aggregate validation. |

### TomFormLabels

The user-visible strings of the form widgets, each resolved from the resource
bundle with a code fallback. One static per string: `TomFormLabels.cancel`,
`done`, `save`, `discard`, `choose`, `search`, `searchHint`, `typeToSearch`,
`filter`, `lookupTitle`, `nullDisplay`, `clearToNull`, `rangeStart`,
`rangeEnd`, `openDatePicker`, `openTimePicker`, `openDateTimePicker`,
`formatHint`, `requiredSuffix`, `errorBannerTitle`, `rowErrors`,
`masterDetailEmpty`, `unsavedTitle` and `unsavedMessage`. All of them go
through `TomFormLabels.resolve`, which takes the base path, the key and the
built-in default — so an application overrides one string by adding one
resource key, and overrides none by adding nothing.

### TomFieldWidgetAdapter

A `StatelessWidget` that implements `TomAuthorizable` on behalf of the field it
wraps, so a field's rendered widget participates in the authorization tree at
the position the widget occupies rather than the position the field was
declared at.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `build` | `Widget build(BuildContext context)` |  |
| `child` | `final Widget child` | The actual rendered content (the field's own widget). |
| `effectiveAuthState` | `TomAuthState get effectiveAuthState` |  |
| `tomGroup` | `TomAuthorizationGroup? get tomGroup` |  |
| `tomId` | `String? get tomId` |  |

## Family selection

### TomFormFieldFamilyKind

`material` or `cupertino` — the identifier a family carries, and what an
application stores when it persists the choice.

### TomFormFieldFamily

The factory that constructs concrete field instances of one family. The two
instances are `TomFormFieldFamily.material` and `TomFormFieldFamily.cupertino`; a
form built through a family is written once and renders in either.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `boolSwitch` | `TomFormBoolField boolSwitch( String tomId, bool initialValue, { String? labelTextOverride, String? descriptionTextOverride, TomForm? form, List<Object>? validators, bool autoValidate = true, TomAuthorizationGroup? tomGroup, TomAuthorizer? authorizer, TomUIStateController? uiStateController})` | Boolean switch. |
| `boolToggle` | `TomFormBoolField boolToggle( String tomId, bool initialValue, { String? onLabelOverride, String? offLabelOverride, String? labelTextOverride, String? descriptionTextOverride, TomForm? form, List<Object>? validators, bool autoValidate = true, TomAuthorizationGroup? tomGroup, TomAuthorizer? authorizer, TomUIStateController? uiStateController})` | Boolean rendered as a two-segment Off / On control rather than a switch — Material `SegmentedButton` vs `CupertinoSlidingSegmentedControl`. |
| `currencyInput` | `TomFormDoubleField currencyInput( String tomId, double initialValue, { String? locale, String? currencyCode, String? labelTextOverride, String? hintTextOverride, String? descriptionTextOverride, double? minValue, double? maxValue, TomForm? form, List<Object>? validators, bool autoValidate = true, TomAuthorizationGroup? tomGroup, TomAuthorizer? authorizer, TomUIStateController? uiStateController})` | Decimal input formatted as money. |
| `datePicker` | `TomFormDateField datePicker( String tomId, DateTime initialValue, { required DateTime firstDate, required DateTime lastDate, String? labelTextOverride, String? descriptionTextOverride, TomForm? form, List<Object>? validators, bool autoValidate = true, TomAuthorizationGroup? tomGroup, TomAuthorizer? authorizer, TomUIStateController? uiStateController})` | Date picker — Material calendar dialog vs Cupertino wheel sheet. |
| `dateRangePicker` | `TomFormDateRangeField dateRangePicker( String tomId, DateTimeRange initialValue, { required DateTime firstDate, required DateTime lastDate, String? labelTextOverride, String? descriptionTextOverride, TomForm? form, List<Object>? validators, bool autoValidate = true, TomAuthorizationGroup? tomGroup, TomAuthorizer? authorizer, TomUIStateController? uiStateController})` | Start/end date range — Material `showDateRangePicker` vs a Cupertino sheet holding one wheel per endpoint. |
| `dateTimePicker` | `TomFormDateTimeField dateTimePicker( String tomId, DateTime initialValue, { required DateTime firstDate, required DateTime lastDate, String? labelTextOverride, String? descriptionTextOverride, TomForm? form, List<Object>? validators, bool autoValidate = true, TomAuthorizationGroup? tomGroup, TomAuthorizer? authorizer, TomUIStateController? uiStateController})` | Combined date-and-time picker. |
| `doubleInput` | `TomFormDoubleField doubleInput( String tomId, double initialValue, { String? labelTextOverride, String? hintTextOverride, String? descriptionTextOverride, int? decimals, TomForm? form, List<Object>? validators, bool autoValidate = true, TomAuthorizationGroup? tomGroup, TomAuthorizer? authorizer, TomUIStateController? uiStateController})` | Decimal text input. |
| `durationPicker` | `TomFormDurationField durationPicker( String tomId, Duration initialValue, { String? labelTextOverride, String? descriptionTextOverride, TomForm? form, List<Object>? validators, bool autoValidate = true, TomAuthorizationGroup? tomGroup, TomAuthorizer? authorizer, TomUIStateController? uiStateController})` | Duration entry. |
| `enumPicker` | `TomFormEnumField<T> enumPicker<T>( String tomId, T initialValue, { required TomSelectableSource<T> source, String? labelTextOverride, String? descriptionTextOverride, TomForm? form, List<Object>? validators, bool autoValidate = true, TomAuthorizationGroup? tomGroup, TomAuthorizer? authorizer, TomUIStateController? uiStateController})` | Single-select enum picker — Material `DropdownButton` vs Cupertino wheel sheet. |
| `enumPickerFor` | `TomFormEnumField<E> enumPickerFor<E extends Enum>( String tomId, E initialValue, { required List<E> values, String? labelTextOverride, String? descriptionTextOverride, TomForm? form, List<Object>? validators, bool autoValidate = true, TomAuthorizationGroup? tomGroup, TomAuthorizer? authorizer, TomUIStateController? uiStateController})` | Single-select enum picker whose option labels come from the text bundle — the resource-keyed form of [enumPicker]. |
| `enumSegmented` | `TomFormEnumField<T> enumSegmented<T extends Object>( String tomId, T initialValue, { required TomSelectableSource<T> source, String? labelTextOverride, String? descriptionTextOverride, TomForm? form, List<Object>? validators, bool autoValidate = true, TomAuthorizationGroup? tomGroup, TomAuthorizer? authorizer, TomUIStateController? uiStateController})` | Single-select enum laid out inline — Material `SegmentedButton` vs `CupertinoSlidingSegmentedControl`. |
| `fileThumbnail` | `TomFormFileField fileThumbnail( String tomId, TomFileRef? initialValue, { TomFilePicker? picker, TomFilePickKind pickKind = TomFilePickKind.image, TomFileTransferClient? transferClient, String? storageSlot, void Function(TomFileRef ref, Uint8List bytes)? onDownload, double thumbnailSize = 96.0, String? labelTextOverride, String? descriptionTextOverride, List<String>? allowedExtensions, int? maxSizeBytes, TomForm? form, List<Object>? validators, bool autoValidate = true, TomAuthorizationGroup? tomGroup, TomAuthorizer? authorizer, TomUIStateController? uiStateController})` | File control that shows the file rather than describing it — a square preview of the file's own content, falling back to the file-kind icon for anything Flutter has no codec for. |
| `fileUpload` | `TomFormFileField fileUpload( String tomId, TomFileRef? initialValue, { required TomFilePicker picker, String? labelTextOverride, String? descriptionTextOverride, List<String>? allowedExtensions, int? maxSizeBytes, TomForm? form, List<Object>? validators, bool autoValidate = true, TomAuthorizationGroup? tomGroup, TomAuthorizer? authorizer, TomUIStateController? uiStateController})` | File upload control. |
| `intInput` | `TomFormIntField intInput( String tomId, int initialValue, { String? labelTextOverride, String? hintTextOverride, String? descriptionTextOverride, TomForm? form, List<Object>? validators, bool autoValidate = true, TomAuthorizationGroup? tomGroup, TomAuthorizer? authorizer, TomUIStateController? uiStateController})` | Integer text input. |
| `isCupertino` | `bool get isCupertino` | Convenience: `true` when this family resolves to Cupertino concretes. |
| `kind` | `final TomFormFieldFamilyKind kind` | Which family this factory resolves to. |
| `lookup` | `TomFormLookupField<T> lookup<T>( String tomId, T initialValue, { required TomSelectableSource<T> source, String Function(T value)? labelOf, String? title, String? labelTextOverride, String? descriptionTextOverride, TomForm? form, List<Object>? validators, bool autoValidate = true, TomAuthorizationGroup? tomGroup, TomAuthorizer? authorizer, TomUIStateController? uiStateController})` | Modal lookup. |
| `nDateInput` | `TomField<DateTime?> nDateInput( String tomId, DateTime? initialValue, { required DateTime firstDate, required DateTime lastDate, String? labelTextOverride, String? hintTextOverride, String? descriptionTextOverride, TomForm? form, List<Object>? validators, bool autoValidate = true, TomAuthorizationGroup? tomGroup, TomAuthorizer? authorizer, TomUIStateController? uiStateController})` | Nullable date input. |
| `nDoubleInput` | `TomField<double?> nDoubleInput( String tomId, double? initialValue, { String? labelTextOverride, String? hintTextOverride, String? descriptionTextOverride, int? decimals, TomForm? form, List<Object>? validators, bool autoValidate = true, TomAuthorizationGroup? tomGroup, TomAuthorizer? authorizer, TomUIStateController? uiStateController})` | Nullable double input. |
| `nIntInput` | `TomField<int?> nIntInput( String tomId, int? initialValue, { String? labelTextOverride, String? hintTextOverride, String? descriptionTextOverride, TomForm? form, List<Object>? validators, bool autoValidate = true, TomAuthorizationGroup? tomGroup, TomAuthorizer? authorizer, TomUIStateController? uiStateController})` | Nullable integer input. |
| `nStringInput` | `TomField<String?> nStringInput( String tomId, String? initialValue, { String? labelTextOverride, String? hintTextOverride, String? descriptionTextOverride, int? maxLength, TomForm? form, bool obscureText = false, List<Object>? validators, bool autoValidate = true, TomAuthorizationGroup? tomGroup, TomAuthorizer? authorizer, TomUIStateController? uiStateController})` | Nullable text input. |
| `nullableBoolToggle` | `TomFormNullableBoolField nullableBoolToggle( String tomId, bool? initialValue, { bool? tristate, String? labelTextOverride, String? descriptionTextOverride, TomForm? form, List<Object>? validators, bool autoValidate = true, TomAuthorizationGroup? tomGroup, TomAuthorizer? authorizer, TomUIStateController? uiStateController})` | Tristate boolean. |
| `objectPicker` | `TomFormObjectField<T> objectPicker<T>( String tomId, T initialValue, { required TomSelectableSource<T> source, String? labelTextOverride, String? descriptionTextOverride, TomForm? form, List<Object>? validators, bool autoValidate = true, TomAuthorizationGroup? tomGroup, TomAuthorizer? authorizer, TomUIStateController? uiStateController})` | Object dropdown / picker for arbitrary objects with a label resolver. |
| `searchInput` | `TomFormSearchField<T> searchInput<T>( String tomId, T initialValue, { required TomSelectableSource<T> source, bool Function(String query, TomSelectableItem<T> item)? searchPredicate, String Function(T value)? labelOf, String? labelTextOverride, String? hintTextOverride, String? descriptionTextOverride, TomForm? form, List<Object>? validators, bool autoValidate = true, TomAuthorizationGroup? tomGroup, TomAuthorizer? authorizer, TomUIStateController? uiStateController})` | Autocomplete search input. |
| `stringInput` | `TomFormStringField stringInput( String tomId, String initialValue, { String? labelTextOverride, String? hintTextOverride, String? descriptionTextOverride, int? maxLength, TomForm? form, bool obscureText = false, List<Object>? validators, bool autoValidate = true, TomAuthorizationGroup? tomGroup, TomAuthorizer? authorizer, TomUIStateController? uiStateController})` | Plain text input. |
| `stringMultiSelect` | `TomFormStringListField stringMultiSelect( String tomId, List<String> initialValue, { required TomSelectableSource<String> source, String? labelTextOverride, String? descriptionTextOverride, TomForm? form, List<Object>? validators, bool autoValidate = true, TomAuthorizationGroup? tomGroup, TomAuthorizer? authorizer, TomUIStateController? uiStateController})` | Pick any number of strings — Material filter chips vs a Cupertino modal sheet of checked rows. |
| `stringPicker` | `TomFormStringField stringPicker( String tomId, String initialValue, { required TomSelectableSource<String> source, String? labelTextOverride, String? hintTextOverride, String? descriptionTextOverride, TomForm? form, List<Object>? validators, bool autoValidate = true, TomAuthorizationGroup? tomGroup, TomAuthorizer? authorizer, TomUIStateController? uiStateController})` | Pick one string from a list of options — Material `DropdownButton` vs Cupertino wheel sheet. |
| `stringSegmented` | `TomFormStringField stringSegmented( String tomId, String initialValue, { required TomSelectableSource<String> source, String? labelTextOverride, String? descriptionTextOverride, TomForm? form, List<Object>? validators, bool autoValidate = true, TomAuthorizationGroup? tomGroup, TomAuthorizer? authorizer, TomUIStateController? uiStateController})` | Pick one string from a short option set laid out inline — Material `SegmentedButton` vs `CupertinoSlidingSegmentedControl`. |
| `timePicker` | `TomFormTimeField timePicker( String tomId, TimeOfDay initialValue, { String? labelTextOverride, String? descriptionTextOverride, TomForm? form, List<Object>? validators, bool autoValidate = true, TomAuthorizationGroup? tomGroup, TomAuthorizer? authorizer, TomUIStateController? uiStateController})` | Time-of-day picker — Material `showTimePicker` vs Cupertino wheel. |

## Styling

A field's appearance comes from one `TomFormStyle` published by a
`TomFormStyleScope`. The style is a fully-populated `TomFieldStyle` base plus
up to eleven optional per-family partial overrides, each a
`TomFieldPartialStyle` whose every property is nullable — so a partial says
only what differs and inherits the rest.

Most spacing and placement properties carry a breakpoint-override list
alongside them (`labelPlacementBpOverrides`, `labelFieldGapBpOverrides`, and
the same pattern for the error and description gaps), which is what makes one
style responsive without a second style object.

### TomFormStyle

The umbrella — one instance per `TomFormStyleScope`. Holds `defaults` and the
eleven nullable family styles, and resolves the two into a fully-populated
`TomFieldStyle` at a given width. Three presets: `TomFormStyle.material3` (the
Material-3 defaults), `TomFormStyle.compact` (floating labels, reduced gaps)
and `TomFormStyle.bordered` (floating labels on an outlined border, with the
error border and trailing error icon enabled).

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `checkboxStyle` | `final TomCheckboxStyle? checkboxStyle` |  |
| `chipsStyle` | `final TomChipsStyle? chipsStyle` |  |
| `copyWith` | `TomFormStyle copyWith({ TomFieldStyle? defaults, TomStringInputStyle? stringInputStyle, TomDropdownStyle? dropdownStyle, TomSliderStyle? sliderStyle, TomCheckboxStyle? checkboxStyle, TomSwitchStyle? switchStyle, TomSegmentedStyle? segmentedStyle, TomRadioGroupStyle? radioGroupStyle, TomDatePickerStyle? datePickerStyle, TomTimePickerStyle? timePickerStyle, TomFilePickerStyle? filePickerStyle, TomChipsStyle? chipsStyle, TomMultilineInputStyle? multilineInputStyle})` |  |
| `datePickerStyle` | `final TomDatePickerStyle? datePickerStyle` |  |
| `dropdownStyle` | `final TomDropdownStyle? dropdownStyle` |  |
| `filePickerStyle` | `final TomFilePickerStyle? filePickerStyle` |  |
| `multilineInputStyle` | `final TomMultilineInputStyle? multilineInputStyle` |  |
| `radioGroupStyle` | `final TomRadioGroupStyle? radioGroupStyle` |  |
| `resolveFieldStyle` | `TomFieldStyle resolveFieldStyle(TomFieldPartialStyle? over, double width)` | Resolves [defaults] + a per-widget [over] partial override down to a fully-populated [TomFieldStyle] at the given [width]. |
| `segmentedStyle` | `final TomSegmentedStyle? segmentedStyle` |  |
| `sliderStyle` | `final TomSliderStyle? sliderStyle` |  |
| `stringInputStyle` | `final TomStringInputStyle? stringInputStyle` |  |
| `switchStyle` | `final TomSwitchStyle? switchStyle` |  |
| `timePickerStyle` | `final TomTimePickerStyle? timePickerStyle` |  |
| `withTheme` | `TomFormStyle withTheme(ThemeData theme)` | Returns a derivative populated from [theme]'s color scheme and text theme. |

### TomCupertinoFormStyle

The Cupertino flavour of `TomFormStyle`, exposed as
`TomCupertinoFormStyle.cupertino`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `withTheme` | `TomCupertinoFormStyle withTheme(ThemeData theme)` | Returns a derivative populated from [theme]'s color scheme and text theme, then applies Cupertino-flavour error tinting. |

### TomFieldStyle

The shared, fully-populated base every field falls back to. Nothing on it is
nullable, so resolution always terminates.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `actionIconPlacement` | `final TomActionIconPlacement actionIconPlacement` |  |
| `borderRadius` | `final double borderRadius` |  |
| `borderWidth` | `final double? borderWidth` | When non-null, overrides the border-stroke width of the enabled / default state border. |
| `copyWith` | `TomFieldStyle copyWith({ TomLabelPlacement? labelPlacement, List<(double, TomLabelPlacement)>? labelPlacementBpOverrides, TomErrorPlacement? errorPlacement, TomRequiredIndicator? requiredIndicator, TomRequiredIndicator? requiredIndicatorOnHint, TomRequiredIndicator? requiredIndicatorOnDescription, TomDescriptionPlacement? descriptionPlacement, TomActionIconPlacement? actionIconPlacement, double? labelFieldGap, List<(double, double)>? labelFieldGapBpOverrides, double? errorFieldGap, List<(double, double)>? errorFieldGapBpOverrides, double? descriptionFieldGap, List<(double, double)>? descriptionFieldGapBpOverrides, EdgeInsets? fieldContentPadding, double? borderRadius, double? borderWidth, bool borderWidthSet = false, double? focusedBorderWidth, bool focusedBorderWidthSet = false, InputBorder? fieldBorder, InputBorder? focusedBorder, InputBorder? errorBorder, TextStyle? inputStyle, TextStyle? labelStyle, List<(double, TextStyle)>? labelStyleBpOverrides, TextStyle? hintStyle, List<(double, TextStyle)>? hintStyleBpOverrides, FontWeight? hintFontWeight, bool hintFontWeightSet = false, double? hintOpacity, bool hintOpacitySet = false, TextStyle? errorStyle, TextStyle? descriptionStyle, double? disabledOpacity, double? readOnlyOpacity, WidgetStateProperty<Color>? readOnlyBackground, WidgetStateProperty<Color>? focusedBackground, bool? errorBorderEnabled,` |  |
| `descriptionFieldGap` | `final double descriptionFieldGap` | Gap between the description text and whatever sits above it — the input box when error placement is `above`/`none`, or the error message when placement is `below`/`both`. |
| `descriptionFieldGapBpOverrides` | `final List<(double, double)> descriptionFieldGapBpOverrides` |  |
| `descriptionPlacement` | `final TomDescriptionPlacement descriptionPlacement` |  |
| `descriptionStyle` | `final TextStyle? descriptionStyle` |  |
| `disabledOpacity` | `final double disabledOpacity` | Opacity applied to the whole field when the effective auth state is [TomAuthState.disabled]. |
| `errorBorder` | `final InputBorder? errorBorder` |  |
| `errorBorderEnabled` | `final bool errorBorderEnabled` |  |
| `errorBorderEnabledBpOverrides` | `final List<(double, bool)> errorBorderEnabledBpOverrides` |  |
| `errorFieldGap` | `final double errorFieldGap` |  |
| `errorFieldGapBpOverrides` | `final List<(double, double)> errorFieldGapBpOverrides` |  |
| `errorIconEnabled` | `final bool errorIconEnabled` |  |
| `errorIconEnabledBpOverrides` | `final List<(double, bool)> errorIconEnabledBpOverrides` |  |
| `errorPlacement` | `final TomErrorPlacement errorPlacement` |  |
| `errorStyle` | `final TextStyle? errorStyle` |  |
| `fieldBorder` | `final InputBorder? fieldBorder` |  |
| `fieldContentPadding` | `final EdgeInsets fieldContentPadding` |  |
| `focusedBackground` | `final WidgetStateProperty<Color>? focusedBackground` |  |
| `focusedBorder` | `final InputBorder? focusedBorder` |  |
| `focusedBorderWidth` | `final double? focusedBorderWidth` | Like [borderWidth] but for the focused-state border. |
| `hintFontWeight` | `final FontWeight? hintFontWeight` | Forced font weight for the hint (placeholder). |
| `hintOpacity` | `final double? hintOpacity` | Alpha multiplier applied to the hint's effective color, rendering it visually subordinate to the label. |
| `hintStyle` | `final TextStyle? hintStyle` |  |
| `hintStyleBpOverrides` | `final List<(double, TextStyle)> hintStyleBpOverrides` |  |
| `inputStyle` | `final TextStyle? inputStyle` | Style for the user-entered text inside the field (TextField value, Dropdown selected label). |
| `labelFieldGap` | `final double labelFieldGap` |  |
| `labelFieldGapBpOverrides` | `final List<(double, double)> labelFieldGapBpOverrides` |  |
| `labelPlacement` | `final TomLabelPlacement labelPlacement` |  |
| `labelPlacementBpOverrides` | `final List<(double, TomLabelPlacement)> labelPlacementBpOverrides` |  |
| `labelStyle` | `final TextStyle? labelStyle` |  |
| `labelStyleBpOverrides` | `final List<(double, TextStyle)> labelStyleBpOverrides` |  |
| `leadingGap` | `final double leadingGap` | Horizontal gap between [leadingWidget] and the editable area. |
| `leadingWidget` | `final Widget? leadingWidget` | Optional widget rendered inside the field, before the editable area. |
| `pickPair` | `T pickPair<T>( double width, T? overValue, List<(double, T)> overOverrides, T baseValue, List<(double, T)> baseOverrides)` | Per-pair atomic pick: if [overValue] is non-null, resolve ([overValue], [overOverrides]) against [width]; otherwise resolve ([baseValue], [baseOverrides]). |
| `readOnlyBackground` | `final WidgetStateProperty<Color>? readOnlyBackground` |  |
| `readOnlyOpacity` | `final double readOnlyOpacity` | Opacity applied to the whole field when the effective auth state is [TomAuthState.read]. |
| `requiredIndicator` | `final TomRequiredIndicator requiredIndicator` |  |
| `requiredIndicatorOnDescription` | `final TomRequiredIndicator requiredIndicatorOnDescription` |  |
| `requiredIndicatorOnHint` | `final TomRequiredIndicator requiredIndicatorOnHint` |  |
| `resolveForBp` | `T resolveForBp<T>(double width, T defaultValue, List<(double, T)> overrides)` | Resolves a breakpointed `(value, overrides)` pair against [width]. |
| `trailingGap` | `final double trailingGap` | Horizontal gap between the editable area and [trailingWidget]. |
| `trailingWidget` | `final Widget? trailingWidget` | Optional widget rendered inside the field, after the editable area. |

### TomFieldPartialStyle

The base of the eleven partial overrides: the same properties as
`TomFieldStyle`, all nullable, plus the breakpoint-override lists.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `actionIconPlacement` | `final TomActionIconPlacement? actionIconPlacement` |  |
| `borderRadius` | `final double? borderRadius` |  |
| `borderWidth` | `final double? borderWidth` |  |
| `descriptionFieldGap` | `final double? descriptionFieldGap` |  |
| `descriptionFieldGapBpOverrides` | `final List<(double, double)> descriptionFieldGapBpOverrides` |  |
| `descriptionPlacement` | `final TomDescriptionPlacement? descriptionPlacement` |  |
| `descriptionStyle` | `final TextStyle? descriptionStyle` |  |
| `disabledOpacity` | `final double? disabledOpacity` |  |
| `errorBorder` | `final InputBorder? errorBorder` |  |
| `errorBorderEnabled` | `final bool? errorBorderEnabled` |  |
| `errorBorderEnabledBpOverrides` | `final List<(double, bool)> errorBorderEnabledBpOverrides` |  |
| `errorFieldGap` | `final double? errorFieldGap` |  |
| `errorFieldGapBpOverrides` | `final List<(double, double)> errorFieldGapBpOverrides` |  |
| `errorIconEnabled` | `final bool? errorIconEnabled` |  |
| `errorIconEnabledBpOverrides` | `final List<(double, bool)> errorIconEnabledBpOverrides` |  |
| `errorPlacement` | `final TomErrorPlacement? errorPlacement` |  |
| `errorStyle` | `final TextStyle? errorStyle` |  |
| `fieldBorder` | `final InputBorder? fieldBorder` |  |
| `fieldContentPadding` | `final EdgeInsets? fieldContentPadding` |  |
| `focusedBackground` | `final WidgetStateProperty<Color>? focusedBackground` |  |
| `focusedBorder` | `final InputBorder? focusedBorder` |  |
| `focusedBorderWidth` | `final double? focusedBorderWidth` |  |
| `hintFontWeight` | `final FontWeight? hintFontWeight` | Per-widget override for [TomFieldStyle.hintFontWeight]. |
| `hintOpacity` | `final double? hintOpacity` | Per-widget override for [TomFieldStyle.hintOpacity]. |
| `hintStyle` | `final TextStyle? hintStyle` |  |
| `hintStyleBpOverrides` | `final List<(double, TextStyle)> hintStyleBpOverrides` |  |
| `inputStyle` | `final TextStyle? inputStyle` |  |
| `labelFieldGap` | `final double? labelFieldGap` |  |
| `labelFieldGapBpOverrides` | `final List<(double, double)> labelFieldGapBpOverrides` |  |
| `labelPlacement` | `final TomLabelPlacement? labelPlacement` |  |
| `labelPlacementBpOverrides` | `final List<(double, TomLabelPlacement)> labelPlacementBpOverrides` |  |
| `labelStyle` | `final TextStyle? labelStyle` |  |
| `labelStyleBpOverrides` | `final List<(double, TextStyle)> labelStyleBpOverrides` |  |
| `leadingGap` | `final double? leadingGap` | Per-widget override for [TomFieldStyle.leadingGap]. |
| `leadingWidget` | `final Widget? leadingWidget` | Per-widget override for [TomFieldStyle.leadingWidget]. |
| `readOnlyBackground` | `final WidgetStateProperty<Color>? readOnlyBackground` |  |
| `readOnlyOpacity` | `final double? readOnlyOpacity` |  |
| `requiredIndicator` | `final TomRequiredIndicator? requiredIndicator` |  |
| `requiredIndicatorOnDescription` | `final TomRequiredIndicator? requiredIndicatorOnDescription` |  |
| `requiredIndicatorOnHint` | `final TomRequiredIndicator? requiredIndicatorOnHint` |  |
| `trailingGap` | `final double? trailingGap` | Per-widget override for [TomFieldStyle.trailingGap]. |
| `trailingWidget` | `final Widget? trailingWidget` | Per-widget override for [TomFieldStyle.trailingWidget]. |

### TomStringInputStyle

Partial override for text-input fields. Carries `TomStringInputVariant`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `variant` | `final TomStringInputVariant? variant` | Which text-input look to render. |

### TomStringInputVariant

`material` or `bordered` — the decoration flavour a text input uses.

### TomDropdownStyle

Partial override for dropdown selection fields.

### TomSliderStyle

Partial override for slider fields.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `activeColor` | `final WidgetStateProperty<Color>? activeColor` |  |
| `thumbColor` | `final WidgetStateProperty<Color>? thumbColor` |  |
| `trackColor` | `final WidgetStateProperty<Color>? trackColor` |  |

### TomCheckboxStyle

Partial override for checkbox fields.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `checkColor` | `final WidgetStateProperty<Color>? checkColor` |  |
| `fillColor` | `final WidgetStateProperty<Color>? fillColor` |  |

### TomSwitchStyle

Partial override for switch fields.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `thumbColor` | `final WidgetStateProperty<Color>? thumbColor` |  |
| `trackColor` | `final WidgetStateProperty<Color>? trackColor` |  |

### TomSegmentedStyle

Partial override for segmented-button fields.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `selectedColor` | `final WidgetStateProperty<Color>? selectedColor` |  |
| `unselectedColor` | `final WidgetStateProperty<Color>? unselectedColor` |  |

### TomRadioGroupStyle

Partial override for radio-group fields. Distinct from the `custom` module's
`TomChoiceGroup`, which takes no style object.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `selectedColor` | `final WidgetStateProperty<Color>? selectedColor` |  |

### TomDatePickerStyle

Partial override for date-picker fields.

### TomTimePickerStyle

Partial override for time-picker fields.

### TomFilePickerStyle

Partial override for file-picker fields.

### TomChipsStyle

Partial override for chips and multi-select fields.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `deletableColor` | `final WidgetStateProperty<Color>? deletableColor` |  |
| `selectedColor` | `final WidgetStateProperty<Color>? selectedColor` |  |

### TomMultilineInputStyle

Partial override for multiline-input fields.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `maxLines` | `final int? maxLines` |  |
| `minLines` | `final int? minLines` |  |

### TomFormStyleScope

The carrier: a `StatelessWidget` that measures the available width with a
`LayoutBuilder` and publishes it, with the resolved `TomFormStyle`, through a
private `InheritedWidget`. `TomFormStyleScope.of` reads the style — falling
back to `TomFormStyle.material3` when there is no scope —
and `TomFormStyleScope.widthOf` the width, falling back to the `MediaQuery`
size. Between them they are what a field needs to apply a breakpoint override.
`TomFormStyleScope.invalidateResourceCache` forgets every cached resource
parse, which an application calls after mutating a resource map in place;
installing a fresh provider does not need it.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `build` | `Widget build(BuildContext context)` |  |
| `child` | `final Widget child` |  |
| `styleBpOverrides` | `final List<(double, TomFormStyle)> styleBpOverrides` | Scope-level breakpoint variants of the programmatic style. |
| `theme` | `final ThemeData? theme` | Programmatic [ThemeData]. |
| `themeBpOverrides` | `final List<(double, ThemeData)> themeBpOverrides` | Breakpoint variants of [theme]. |
| `themeSpec` | `final TomThemeSpec? themeSpec` | Programmatic [TomThemeSpec]. |
| `themeSpecBpOverrides` | `final List<(double, TomThemeSpec)> themeSpecBpOverrides` | Breakpoint variants of [themeSpec]. |
| `themeSpecTheme` | `final ThemeData? themeSpecTheme` | Base [ThemeData] handed to every `TomThemeSpec.toThemeData(base)` call (programmatic or resource-driven). |
| `tomId` | `final String? tomId` | Optional Tom identifier. |

### TomBreakpoint

The named widths shared across the form system and the rest of the kit.
`TomBreakpoint.mobile`, `tablet` and `desktop` read the current values (600,
900 and 1200 by default); `TomBreakpoint.configure` retunes them at startup and
`TomBreakpoint.reset` restores the defaults. `TomBreakpoint.resolve` maps a
name to its width and `TomBreakpoint.names` is the list of valid names — the
pair a resource-declared breakpoint is parsed with.

### TomThemeSpec

A small serialisable view of `ThemeData` covering the properties a form style
needs. `TomThemeSpec.fromResources` builds one from a resource bundle, so a
theme can be declared in resources rather than in code.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `bodySize` | `final double? bodySize` |  |
| `bodyWeight` | `final FontWeight? bodyWeight` |  |
| `brightness` | `final Brightness? brightness` | `null` means "inherit from base". |
| `density` | `final VisualDensity? density` | `null` means "inherit from base". |
| `error` | `final Color? error` |  |
| `fontFamily` | `final String? fontFamily` |  |
| `labelWeight` | `final FontWeight? labelWeight` |  |
| `primary` | `final Color? primary` |  |
| `secondary` | `final Color? secondary` |  |
| `seed` | `final Color? seed` |  |
| `toThemeData` | `ThemeData toThemeData([ThemeData? base])` | Materialises the spec into a [ThemeData], deriving from [base] when provided so the app's component themes and other customisations stay intact. |

### TomLabelPlacement

`above`, `below`, `floating`, `inline` or `hidden`.

### TomErrorPlacement

`below`, `above`, `tooltip`, `both` or `replaceDescription`.

### TomRequiredIndicator

`asterisk`, `text`, `none` or `custom`.

### TomDescriptionPlacement

`below`, `above` or `tooltip`.

### TomActionIconPlacement

`trailing`, `leading` or `above`.

## Decoration mixins

Two mixins apply their family's resolved style to the widget a field builds,
and `TomGenericFieldDecorationMixin` does it for everything else — so
placement, gaps and borders are implemented three times rather than once per
field.

The other ten are **empty, and nothing in the package mixes them in**. Each
names a family that ships and takes the generic mixin instead. They are a
reserved extension point, not a layer a field passes through, and a reader
should not conclude from the name that a slider or a chip field is decorated by
one.

### TomStringInputDecorationMixin

Decoration for string-input fields, including the `TomStringInputVariant` split.
Nine files mix it in.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `applyErrorVisualsTo` | `InputDecoration applyErrorVisualsTo( BuildContext context, InputDecoration decoration)` | Applies error visuals (error border + red icon) to a base [InputDecoration] when the field is in error, per the resolved style's `errorBorderEnabled` / `errorIconEnabled` toggles. |
| `decorateField` | `Widget decorateField(BuildContext context, Widget innerWidget)` | Wraps [innerWidget] with the standard field anatomy. |
| `descriptionText` | `String? get descriptionText` | Description/helper text — resolved from resources or set explicitly. |
| `hasRequiredValidator` | `bool get hasRequiredValidator` | Whether this field has a required validator. |
| `labelText` | `String? get labelText` | Label text — resolved from resources or set explicitly. |
| `requiredIndicatorSuffix` | `String requiredIndicatorSuffix(TomRequiredIndicator kind)` | Text suffix for the required indicator, suitable for appending to plain-text slots such as `InputDecoration.labelText` or `hintText`. |
| `resolveOver` | `TomStringInputStyle? resolveOver(BuildContext context)` | Resolves the underlying [TomStringInputStyle] override (may be null). |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` | Resolves the per-width [TomFieldStyle] for this widget type. |
| `resolveValidationErrorMessage` | `String? resolveValidationErrorMessage()` | Resolves the current validation-error message through the resource system, or `null` when the field is not in error. |

### TomDropdownDecorationMixin

Decoration for dropdown selection fields. Four files mix it in.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `applyErrorVisualsTo` | `InputDecoration applyErrorVisualsTo( BuildContext context, InputDecoration decoration)` | Applies error visuals (error border + red icon) to a base [InputDecoration] when the field is in error, per the resolved style's `errorBorderEnabled` / `errorIconEnabled` toggles. |
| `decorateField` | `Widget decorateField(BuildContext context, Widget innerWidget)` | Wraps [innerWidget] with the standard field anatomy. |
| `descriptionText` | `String? get descriptionText` | Description/helper text — resolved from resources or set explicitly. |
| `dropdownFillsColumnWidth` | `bool get dropdownFillsColumnWidth` | A dropdown *field* always fills the width its column gives it — the value to pass as [DropdownButton.isExpanded]. |
| `dropdownItemLabel` | `Widget dropdownItemLabel(String label, TextStyle? style)` | Renders a menu-item label so that it elides rather than reflows. |
| `hasRequiredValidator` | `bool get hasRequiredValidator` | Whether this field has a required validator. |
| `labelText` | `String? get labelText` | Label text — resolved from resources or set explicitly. |
| `requiredIndicatorSuffix` | `String requiredIndicatorSuffix(TomRequiredIndicator kind)` | Text suffix for the required indicator. |
| `resolveOver` | `TomDropdownStyle? resolveOver(BuildContext context)` | Resolves the underlying [TomDropdownStyle] override (may be null). |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` | Resolves the per-width [TomFieldStyle] for this widget type. |
| `resolveValidationErrorMessage` | `String? resolveValidationErrorMessage()` | Resolves the current validation-error message, or `null`. |

### TomGenericFieldDecorationMixin

Decoration for non-text-input fields — checkboxes, switches, sliders, pickers,
chips and the rest. Twenty of the catalogue's files mix it in, which is every
field that is not a text input or a dropdown.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `decorateField` | `Widget decorateField(BuildContext context, Widget innerWidget)` | Wraps [innerWidget] with the standard field anatomy. |
| `descriptionText` | `String? get descriptionText` | Description/helper text — resolved from resources or set explicitly. |
| `hasRequiredValidator` | `bool get hasRequiredValidator` | Whether this field has a required validator. |
| `labelText` | `String? get labelText` | Label text — resolved from resources or set explicitly. |
| `requiredIndicatorSuffix` | `String requiredIndicatorSuffix(TomRequiredIndicator kind)` | Text suffix for the required indicator, suitable for appending to plain-text slots. |
| `resolveFullStyle` | `TomFormStyle resolveFullStyle(BuildContext context)` | Returns the form-style resolved for the ambient width — concretes call this when they need the full style (e.g. |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` | Resolves the per-width [TomFieldStyle] for this widget type. |
| `resolveValidationErrorMessage` | `String? resolveValidationErrorMessage()` | Resolves the current validation-error message through the resource system, or `null` when the field is not in error. |
| `scopeWidth` | `double scopeWidth(BuildContext context)` | Reads the captured scope width for [context] — call it when a concrete widget wants to pick per-breakpoint visuals without duplicating `TomFormStyleScope.widthOf(context)`. |

## Validation

### TomValidationResult

The sealed result of validating one field value. Exhaustive over the four
states below, so a `switch` on it needs no default arm.

### TomValidationPristine

The initial state, before the user has interacted with the field. Distinct from
success: a pristine field is not yet known to be valid.

### TomValidationSuccess

The value is valid.

### TomValidationError

The value is invalid; carries the message to display.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `errorKey` | `final String errorKey` |  |
| `interpolate` | `String interpolate(String template)` | Substitutes this error's [params] into a resolved message [template], replacing each `{name}` placeholder with its value. |
| `params` | `final Map<String, dynamic>? params` |  |

### TomValidationPending

An async validation is in flight.

### TomValidator

`TomValidator<T>` — `FutureOr<TomValidationResult> Function(T value)`. The
contract every validator satisfies, sync and async alike.

### TomSlowValidator

Wraps a validator to declare it slow — a remote call, typically. `TomField`
debounces slow validators separately and longer, and reports
`isSlowValidationPending` while one is outstanding.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `validate` | `final TomValidator<T> validate` |  |

### TomValidators

The built-in validators, all statics: `TomValidators.required` (and the shared
`TomValidators.requiredInstance`), `email`, `minLength`, `maxLength`, `pattern`,
`min`, `max`, `minItems`, `maxItems`, and `TomValidators.compose`, which runs a
list in order and returns the first failure.

### TomValidatorFactory

`TomValidatorFactory` — `TomValidator<Object?> Function(List<String> args)`.
Produces a validator from the argument list parsed out of a resource-declared
validator spec.

### TomValidatorRegistry

Resolves named validators declared in a field's resource bundle into callable
validators. `TomValidatorRegistry.instance` is the ambient registry and
`TomValidatorRegistry.resetInstance` replaces it with a fresh one, which is what
a test uses to avoid leaking registrations. `TomValidatorRegistry.parseSpec`
splits a spec string into its name and argument list.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `has` | `bool has(String name)` | Whether a validator named [name] is registered. |
| `names` | `Iterable<String> get names` | The registered validator names, in insertion order. |
| `register` | `void register(String name, TomValidatorFactory factory)` | Registers [factory] under [name], replacing any existing factory. |
| `resolve` | `TomValidator<Object?>? resolve(String name, [List<String> args = const []])` | Resolves the validator [name] with optional [args], or `null` when the name is unknown. |
| `resolveDeclaration` | `List<TomValidator<Object?>> resolveDeclaration(String declaration)` | Resolves a comma-separated [declaration] (the raw `<basePath>.validators` resource value, e.g. |
| `resolveOrThrow` | `TomValidator<Object?> resolveOrThrow( String name, [ List<String> args = const []])` | Resolves the validator [name] with optional [args], throwing [ArgumentError] (listing the known names) when [name] is unregistered. |
| `resolveSpec` | `TomValidator<Object?> resolveSpec(String spec)` | Resolves a single validator spec of the form `name[:arg[:arg…]]` (e.g. |
| `static` | `static` | Splits a validator [spec] into its name and colon-separated arguments. |

### TomFormValidationError

A cross-field error produced by `TomForm.validateForm` — it belongs to the form
rather than to any one field, which is why it is not a `TomValidationResult`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `errorKey` | `final String errorKey` | The primary error key (for the form-level error message). |
| `fieldErrorKeys` | `final Map<TomField, String>? fieldErrorKeys` | Per-field error keys (optional; use different resource keys per field). |
| `fields` | `final List<TomField> fields` | Field references involved in this cross-field error. |
| `params` | `final Map<String, dynamic>? params` | Optional parameters for message interpolation. |
| `tomIds` | `List<String> get tomIds` | Field IDs involved in this error (convenience getter). |

## Events

Every form and field change is published as a `TomFormEvent` on the form's
event bus, so an application observes what happened without subclassing the
widget that did it.

### TomFormEvent

The base of every event below. Carries the form and the timestamp.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `description` | `final String description` | Human-readable description of what happened. |
| `source` | `final String source` | Human-readable source identifier (e.g., field ID or form ID). |

### TomFieldValueChangedEvent

A field's value changed.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `newValue` | `final Object? newValue` |  |
| `oldValue` | `final Object? oldValue` |  |

### TomFieldValidatedEvent

A field finished validating; carries the resulting `TomValidationResult`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `result` | `final Object result` | The validation result (success, error, or pending). |

### TomFieldAuthChangedEvent

A field's effective authorization state changed.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `newState` | `final Object newState` |  |
| `oldState` | `final Object oldState` |  |

### TomFieldBoundEvent

A field was bound to data.

### TomFieldCommittedEvent

A field's current value became its new initial value — what a successful save
does, and what resets `isDirty`.

### TomFormBoundEvent

A form was bound to a data object.

### TomFormSavedEvent

A form saved successfully.

### TomFormDiscardedEvent

A form discarded its edits.

### TomFormValidatedEvent

A form finished validating.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `errors` | `final List<Object> errors` | The validation errors (empty list = success). |

### TomListItemAddedEvent

A sub-form was appended to or inserted into a `TomListForm`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `index` | `final int index` | Index at which the new sub-form sits after insertion. |
| `itemFormId` | `final String itemFormId` | Stable id of the newly added sub-form (its `formId`). |

### TomListItemRemovedEvent

A sub-form was removed from a `TomListForm`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `index` | `final int index` | Index the sub-form occupied before removal. |
| `itemFormId` | `final String itemFormId` | Stable id of the removed sub-form. |

### TomListItemReorderedEvent

A sub-form moved within a `TomListForm`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `fromIndex` | `final int fromIndex` | Original index of the sub-form before the move. |
| `itemFormId` | `final String itemFormId` | Stable id of the moved sub-form. |
| `toIndex` | `final int toIndex` | Final index of the sub-form after the move. |

### TomFormEventListener

The listener mixin, with a no-op default for each event type — so an
implementation overrides only the events it cares about.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `handleEvent` | `void handleEvent(TomFormEvent event)` | Dispatches an event to the appropriate typed handler. |
| `onFieldAuthChanged` | `void onFieldAuthChanged(TomFieldAuthChangedEvent event)` |  |
| `onFieldBound` | `void onFieldBound(TomFieldBoundEvent event)` |  |
| `onFieldCommitted` | `void onFieldCommitted(TomFieldCommittedEvent event)` |  |
| `onFieldValidated` | `void onFieldValidated(TomFieldValidatedEvent event)` |  |
| `onFieldValueChanged` | `void onFieldValueChanged(TomFieldValueChangedEvent event)` |  |
| `onFormBound` | `void onFormBound(TomFormBoundEvent event)` |  |
| `onFormDiscarded` | `void onFormDiscarded(TomFormDiscardedEvent event)` |  |
| `onFormSaved` | `void onFormSaved(TomFormSavedEvent event)` |  |
| `onFormValidated` | `void onFormValidated(TomFormValidatedEvent event)` |  |
| `onListItemAdded` | `void onListItemAdded(TomListItemAddedEvent event)` |  |
| `onListItemRemoved` | `void onListItemRemoved(TomListItemRemovedEvent event)` |  |
| `onListItemReordered` | `void onListItemReordered(TomListItemReorderedEvent event)` |  |

### TomFormEventSource

The abstract source a form satisfies: register and unregister listeners.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `addListener` | `void addListener(TomFormEventListener listener)` | Register a listener for form events. |
| `fireEvent` | `void fireEvent(TomFormEvent event)` | Dispatch an event to all registered listeners. |
| `removeListener` | `void removeListener(TomFormEventListener listener)` | Remove a previously registered listener. |

### TomFormInspector

A collector that buffers events for inspection. Written for tests, and the
shortest way to assert that a sequence of interactions produced the sequence of
events it should have.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `clear` | `void clear()` | Clear all collected events. |
| `fromSource` | `List<TomFormEvent> fromSource(String source)` | Events filtered by source. |
| `isEmpty` | `bool get isEmpty` | Whether any events have been collected. |
| `length` | `int get length` | Number of collected events. |
| `ofType` | `List<T> ofType<T extends TomFormEvent>()` | Events filtered by type. |
| `onFieldAuthChanged` | `void onFieldAuthChanged(TomFieldAuthChangedEvent event)` |  |
| `onFieldBound` | `void onFieldBound(TomFieldBoundEvent event)` |  |
| `onFieldCommitted` | `void onFieldCommitted(TomFieldCommittedEvent event)` |  |
| `onFieldValidated` | `void onFieldValidated(TomFieldValidatedEvent event)` |  |
| `onFieldValueChanged` | `void onFieldValueChanged(TomFieldValueChangedEvent event)` |  |
| `onFormBound` | `void onFormBound(TomFormBoundEvent event)` |  |
| `onFormDiscarded` | `void onFormDiscarded(TomFormDiscardedEvent event)` |  |
| `onFormSaved` | `void onFormSaved(TomFormSavedEvent event)` |  |
| `onFormValidated` | `void onFormValidated(TomFormValidatedEvent event)` |  |
| `onListItemAdded` | `void onListItemAdded(TomListItemAddedEvent event)` |  |
| `onListItemRemoved` | `void onListItemRemoved(TomListItemRemovedEvent event)` |  |
| `onListItemReordered` | `void onListItemReordered(TomListItemReorderedEvent event)` |  |

## Selection sources

### TomSelectableSource

`TomSelectableSource<T>` — the abstract source of options behind every
selection field: dropdowns, segmented buttons, radio groups, chips and the
lookup dialogs all read one.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `getItems` | `Future<List<TomSelectableItem<T>>> getItems()` | Fetches the current list of selectable items. |
| `itemsStream` | `Stream<List<TomSelectableItem<T>>>? get itemsStream` | Optional stream of item updates. |

### TomSelectableItem

`TomSelectableItem<T>` — one option: its value, its label, and its optional icon
and enabled flag.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `description` | `final String? description` |  |

### TomStaticSelectableSource

`TomStaticSelectableSource<T>` — a source backed by a fixed list.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `getItems` | `Future<List<TomSelectableItem<T>>> getItems() async` |  |
| `itemsStream` | `Stream<List<TomSelectableItem<T>>>? get itemsStream` |  |

### TomEnumSelectableSource

`TomEnumSelectableSource<E extends Enum>` — a source over an enum whose option
labels come from the resource bundle, so the labels localise without the field
knowing.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `of` | `TomEnumSelectableSource.of(TomObservableEnum<E> cell, {super.isEnabled})` | Creates a source offering the values of [cell], in [cell]'s scope. |
| `valueOf` | `E valueOf(E value)` |  |

### TomEnumNameSelectableSource

The `Enum.name`-valued twin of `TomEnumSelectableSource`: the same labels,
carrying the name rather than the enum value, for a field whose bound property
is a `String`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `valueOf` | `String valueOf(E value)` |  |

### TomMutableSelectableSource

`TomMutableSelectableSource<T>` — a source whose item set can be replaced at
runtime, which is what a dependent dropdown needs.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `dispose` | `void dispose()` | Closes the stream. |
| `getItems` | `Future<List<TomSelectableItem<T>>> getItems() async` |  |
| `isDisposed` | `bool get isDisposed` | Whether [dispose] has closed the underlying broadcast controller. |
| `items` | `List<TomSelectableItem<T>> get items` | The current item set. |
| `itemsStream` | `Stream<List<TomSelectableItem<T>>> get itemsStream` |  |
| `setItems` | `void setItems(List<TomSelectableItem<T>> next)` | Replaces the item set and notifies every listening field. |

## File fields and transfer

### TomFileRef

The reference a file field carries as its value: the stored file's identity,
not its bytes.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `copyWith` | `TomFileRef copyWith({ String? name, int? sizeBytes, String? mimeType, Uint8List? bytes, TomFileSource? source, String? storageKey})` | A copy with the given fields replaced. |
| `extension` | `String get extension` | The lowercase extension without its dot, or `''` when there is none. |
| `hasLocalContent` | `bool get hasLocalContent` | Whether this reference can produce the file's bytes without a download. |
| `isStored` | `bool get isStored` | Whether this reference points at a file the server holds. |
| `mimeType` | `final String? mimeType` | The media type, when the picker or server reported one. |
| `name` | `final String name` | The file name as the user knows it, including its extension. |
| `sizeBytes` | `final int sizeBytes` | The file's size in bytes. |
| `source` | `final TomFileSource? source` | Optional re-openable byte source, for files streamed from disk. |
| `storageKey` | `final String? storageKey` | The server-generated storage key, once the file has been stored. |
| `toSource` | `TomFileSource toSource()` | The bytes to upload, as a re-openable source. |

### TomFilePicker

`TomFilePicker` — `Future<TomFileRef?> Function(BuildContext context)`. What a
file field calls to obtain a file; `null` means the user cancelled.

### TomPlatformFilePicker

The adaptor over a platform picker, returning what the user chose as a
`TomPickedFile`. Separating it from `TomFilePicker` is what keeps the platform
plugin out of this package.

### TomPickedFile

What a platform picker returned: the bytes or a path, plus the name and MIME
type.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `mimeType` | `final String? mimeType` | The media type, when the picker reported one. |
| `open` | `final Stream<List<int>> Function()? open` | A re-openable byte stream, when the picker offered streamed reads. |
| `sizeBytes` | `final int? sizeBytes` | The size in bytes, when the picker reported one. |

### TomFilePickRequest

What a field wants picked — the kind, the accepted extensions and the size
limit — passed to the registered picker.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `allowedExtensions` | `final List<String>? allowedExtensions` | Allowed extensions without a dot, lowercase, or `null` for no limit. |
| `maxSizeBytes` | `final int? maxSizeBytes` | The inclusive maximum size the field will accept, when it has one. |

### TomFilePickKind

`any`, `image`, `video` or `audio`, so an adaptor can open the right dialog.

### TomFilePickerRegistry

Holds the application's platform picker. `TomFilePickerRegistry.register`
installs it, `TomFilePickerRegistry.clear` removes it,
`TomFilePickerRegistry.hasPicker` reports whether one is installed, and
`TomFilePickerRegistry.pick` runs it for a request.

### TomFilePickers

Ready-made `TomFilePicker` callbacks: `TomFilePickers.registered` builds one
that goes through the registry, `TomFilePickers.fixed` one that always returns
the same reference (what a test uses), and `TomFilePickers.toFileRef` converts
a `TomPickedFile` into the `TomFileRef` a field stores.

### TomFileLabels

The user-visible strings of the file widgets, resolved the same way
`TomFormLabels` is and through the same `TomFileLabels.resolve`:
`TomFileLabels.choose`, `none`, `dropzoneHint`, `selected`, `download`,
`clear`, `cancel`, `retry`, `progress`, `progressBusy`, `uploaded`,
`downloaded`, `removed`, `done`, `cancelled`, `rejectedTitle`,
`rejectedDismiss` and `rejection`.

### TomFileTransferController

Drives one file slot's transfers and publishes their state as a
`ValueNotifier<TomFileTransferState>`: `upload`, `download`, `downloadTo`,
`describe`, `remove`, `cancel`, `retry` and `reset`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `canRetry` | `bool get canRetry` | Whether [retry] has something to repeat. |
| `client` | `final TomFileTransferClient client` | The transport moving the bytes. |
| `dispose` | `void dispose()` |  |
| `isRunning` | `bool get isRunning` | Whether a transfer is in flight. |

### TomFileTransferState

Where a transfer stands: its `phase`, its `kind`, the progress, the error, the
file metadata, and the client and slot it belongs to.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `copyWith` | `TomFileTransferState copyWith({ TomTransferPhase? phase, TomTransferKind? kind, TomTransferProgress? progress, Object? error, TomFileMetadata? metadata, bool clearProgress = false, bool clearError = false, bool clearMetadata = false})` | A copy with the given fields replaced. |
| `errorKey` | `String? get errorKey` | The error key when the failure came from the transfer layer, else `null`. |
| `fraction` | `double? get fraction` | The completed fraction, or `null` when it cannot be known. |
| `isRunning` | `bool get isRunning` | Whether a transfer is in flight. |

### TomTransferPhase

`idle`, `running`, `succeeded`, `cancelled` or `failed`.

### TomTransferKind

`none`, `upload`, `download` or `removal` — what the controller last ran.

### TomFileTransferIndicator

Renders the state of the transfer a `TomFileTransferController` is running.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `basePath` | `final String? basePath` | The resource path this indicator's wording is scoped to — a field's `basePath` when it sits inside one. |
| `build` | `Widget build(BuildContext context)` |  |
| `controller` | `final TomFileTransferController controller` | The transfer to display. |
| `onCancel` | `final VoidCallback? onCancel` | Called when the user cancels a running transfer. |
| `onDownload` | `final VoidCallback? onDownload` | Called when the user asks to download the stored file. |
| `onRetry` | `final VoidCallback? onRetry` | Called when the user retries a failed or cancelled transfer. |
| `showSuccess` | `final bool showSuccess` | Whether a completed transfer leaves a confirmation line behind. |

## List forms

A `TomListForm` owns an ordered collection of sub-forms — one per item — and
the three container widgets render the same list differently. Each implements
`TomFormChildContainer`, so an enclosing form drives their lifecycle.

### TomListForm

`TomListForm<TItem extends TomClass, TForm extends TomForm<TItem>>` — the
container itself: the ordered sub-forms, and the add, insert, remove and
reorder operations that fire the three list events.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `addListener` | `void addListener(TomFormEventListener listener)` |  |
| `bind` | `void bind(TomList<TItem> items)` | Bind this list to a [TomList] of [TItem]. |
| `createItem` | `TItem createItem()` | Override in subclasses to produce a fresh [TItem] when [add] / [insert] is called against a bound list. |
| `discard` | `void discard()` | Discard edits in every sub-form AND restore the original list order / membership captured at bind / save time. |
| `dispose` | `void dispose()` | Dispose every sub-form and clear listeners. |
| `fireEvent` | `void fireEvent(TomFormEvent event)` |  |
| `hasStructuralChanges` | `bool get hasStructuralChanges` | `true` when at least one add / remove / reorder happened since the last [bind] / [save]. |
| `isDirty` | `bool get isDirty` | `true` when any sub-form is dirty OR the list membership / order has changed since the last [bind] / [save]. |
| `isEmpty` | `bool get isEmpty` |  |
| `isNotEmpty` | `bool get isNotEmpty` |  |
| `isValid` | `bool get isValid` | `true` when every sub-form currently passes its own validation. |
| `length` | `int get length` | Number of sub-forms (== bound list length). |
| `listId` | `final String listId` | Stable resource / event id for the list. |
| `move` | `void move(int from, int to)` | Move the sub-form from index [from] to index [to]. |
| `onAfterReset` | `void onAfterReset(TomList list)` | Called by [TomList.resetWith] immediately after new elements are installed. |
| `onBeforeClear` | `void onBeforeClear(TomList list)` | Called by [TomList.resetWith] immediately before elements are removed. |
| `parentForm` | `TomForm? get parentForm` |  |
| `removeAt` | `void removeAt(int index)` | Remove the sub-form at [index] from this list and from the bound underlying list (if any). |
| `removeListener` | `void removeListener(TomFormEventListener listener)` |  |
| `save` | `Future<bool> save({bool? commitBaselines}) async` | Save every sub-form. |
| `unbind` | `void unbind()` | Detach from the bound list. |
| `validate` | `Future<List<TomFormValidationError>> validate() async` | Validate every sub-form plus this list's own [validateList] hook. |
| `validateList` | `Future<List<String>> validateList() async` | Optional list-level validation. |

### TomInlineListForm

Renders the list as a vertically stacked sequence of inline sub-forms.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `crossAxisAlignment` | `final CrossAxisAlignment crossAxisAlignment` | Cross-axis alignment of the inner [Column]. |
| `emptyBuilder` | `final Widget Function(BuildContext context)? emptyBuilder` | Optional widget shown in place of any rows when the list is empty. |
| `footerBuilder` | `footerBuilder` |  |
| `headerBuilder` | `headerBuilder` |  |
| `listForm` | `final TomListForm<TItem, TForm> listForm` | The list whose rows are rendered inline. |
| `onReorder` | `final void Function(int from, int to)? onReorder` | Optional reorder hook. |
| `proxyDecorator` | `proxyDecorator` |  |
| `reorderable` | `final bool reorderable` | When `true`, rows are rendered inside a [ReorderableListView] and can be reordered via long-press or by dragging a [TomReorderHandle] embedded in the row body. |
| `rowBuilder` | `rowBuilder` |  |
| `rowMoveButtonsPosition` | `final TomRowMoveButtonsPosition rowMoveButtonsPosition` | Whether the auto-rendered move buttons appear before or after the user's row body. |
| `rowSeparatorBuilder` | `final Widget Function(BuildContext context, int index)? rowSeparatorBuilder` | Optional separator inserted between consecutive rows. |
| `showRowMoveButtons` | `final bool showRowMoveButtons` | When `true`, the inline list automatically prepends or appends a pair of [TomListRowMoveButtons] to every row built by [rowBuilder]. |
| `toolbarBuilder` | `toolbarBuilder` |  |

### TomExpandableListForm

Renders the list as a vertical sequence of expandable rows.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `bodyBuilder` | `bodyBuilder` |  |
| `controller` | `controller` |  |
| `crossAxisAlignment` | `crossAxisAlignment` |  |
| `emptyBuilder` | `emptyBuilder` |  |
| `footerBuilder` | `footerBuilder` |  |
| `headerBuilder` | `headerBuilder` |  |
| `initialExpanded` | `initialExpanded` |  |
| `listForm` | `listForm` |  |
| `onBeforeChange` | `onBeforeChange` |  |
| `onExpansionChanged` | `onExpansionChanged` |  |
| `onReorder` | `onReorder` |  |
| `proxyDecorator` | `proxyDecorator` |  |
| `reorderable` | `reorderable` |  |
| `rowSeparatorBuilder` | `rowSeparatorBuilder` |  |
| `summaryBuilder` | `summaryBuilder` |  |
| `toolbarBuilder` | `toolbarBuilder` |  |

### TomExpandableListFormController

Controls expansion from outside the widget. The widget creates one when none is
supplied.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `collapse` | `void collapse(int index)` | Programmatically collapse [index]. |
| `collapseAll` | `void collapseAll()` | Programmatically collapse every row. |
| `expand` | `void expand( int index, { TomExpansionPolicy policy = TomExpansionPolicy.singleOpen})` | Programmatically expand [index] under [policy]. |
| `expanded` | `Set<int> get expanded` | Read-only view of the currently expanded indices. |
| `isExpanded` | `bool isExpanded(int index)` | Whether [index] is currently expanded. |

### TomExpansionPolicy

`singleOpen` or `multipleOpen`.

### TomMasterDetailListForm

A two-pane master-detail layout over a `TomListForm`: the row list on one side,
the selected sub-form on the other.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `detailBuilder` | `detailBuilder` |  |
| `draggableSplitter` | `draggableSplitter` |  |
| `emptyDetailBuilder` | `emptyDetailBuilder` |  |
| `guardUnsavedSelectionChange` | `guardUnsavedSelectionChange` |  |
| `initialSelectedIndex` | `initialSelectedIndex` |  |
| `listForm` | `listForm` |  |
| `masterBuilder` | `masterBuilder` |  |

### TomListFormToolbar

The compact action bar carrying the standard list mutations — add, insert,
remove, and the move pair.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `afterActions` | `final List<Widget>? afterActions` | Optional extra buttons appended after the standard action set. |
| `alignment` | `final WrapAlignment alignment` | Horizontal alignment of the [Wrap]'s rows. |
| `beforeActions` | `final List<Widget>? beforeActions` | Optional extra buttons inserted before the standard action set. |
| `beforeAdd` | `final Future<bool> Function()? beforeAdd` | Optional veto fired before an Add. |
| `beforeMove` | `final Future<bool> Function(int from, int to)? beforeMove` | Optional veto fired before a Move. |
| `beforeRemove` | `final Future<bool> Function(int index)? beforeRemove` | Optional veto fired before a Remove. |
| `dense` | `final bool dense` | When `true` (default), uses small icons + tonal buttons. |
| `iconSize` | `final double iconSize` |  |
| `listForm` | `final TomListForm<TItem, TForm> listForm` | The list whose membership / order is mutated by the buttons. |
| `onSelectionChanged` | `final Future<void> Function(int? index)? onSelectionChanged` | Optional callback invoked whenever this toolbar changes selection (after Add, Remove, or Move). |
| `runSpacing` | `final double runSpacing` | Spacing between wrapped rows (vertical). |
| `selectedIndex` | `final int? selectedIndex` | Currently selected row index. |
| `showAdd` | `final bool showAdd` |  |
| `showMoveDown` | `final bool showMoveDown` |  |
| `showMoveUp` | `final bool showMoveUp` |  |
| `showRemove` | `final bool showRemove` |  |
| `spacing` | `final double spacing` | Spacing between buttons (horizontal). |

### TomListRowMoveButtons

A *Move up* / *Move down* pair bound to one row index of a `TomListForm`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `axis` | `axis` |  |
| `beforeMove` | `beforeMove` |  |
| `dense` | `dense` |  |
| `listForm` | `listForm` |  |
| `onReorder` | `onReorder` |  |

### TomRowMoveButtonsPosition

`leading` or `trailing` — which side of a row the move buttons attach to.

### TomReorderHandle

The standard drag handle for reordering rows in a `ReorderableListView`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `index` | `final int index` | The row's index inside the host [ReorderableListView]. |

## Form-level widgets

### TomErrorView

A placement-flexible form-wide error display.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `emptyState` | `final Widget? emptyState` | Optional widget shown when there are no errors. |
| `includeFieldErrors` | `final bool includeFieldErrors` | Whether per-field validation errors are included alongside cross- field ones. |
| `onErrorTap` | `final void Function(TomFormValidationError error)? onErrorTap` | Optional handler invoked when an error row is tapped — useful for "focus this field" affordances. |
| `padding` | `final EdgeInsetsGeometry padding` |  |
| `title` | `final String? title` | Optional title shown above the list. |

### TomFormErrorBanner

The Material banner for form-level, cross-field errors — the
`TomFormValidationError`s `TomForm.validateForm` returned.

### TomRowErrorStrip

The compact per-row error strip a list form uses, where a full banner would not
fit.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `crossAxisAlignment` | `final CrossAxisAlignment crossAxisAlignment` | Horizontal alignment for both the column children and text. |

### TomMultiObservableBuilder

Observes several `TomObservable`s and rebuilds when any of them changes. The
one widget here that is not about errors: it is what a form-aware widget
outside the field tree uses to follow form state.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `builder` | `final WidgetBuilder builder` | Builder called when any observed value changes. |
| `observables` | `final List<TomObservable> observables` | The observables to watch for changes. |

### TomUnsavedChangesGuard

Wraps a subtree in a `PopScope` that defers a route pop while its form is
dirty, and prompts.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `child` | `final Widget child` |  |
| `message` | `final String? message` | Body of the prompt; `null` resolves it through [TomFormLabels]. |
| `title` | `final String? title` | Heading of the prompt; `null` resolves it through [TomFormLabels]. |

### TomUnsavedChangesChoice

`save`, `discard` or `cancel` — the result of that prompt. `save` runs the
form's save before allowing the pop.

## Material fields

Seventy-five types: an abstract base per value type, the Material renderings of
each, and the four support types the fields carry or use. Every concrete field
below extends the abstract base named above it, so the base is where the value
contract, the validators and the authorization state live, and the concrete
class is only a rendering.

### TomFormBoolField

Abstract base for `bool` fields.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionTextOverride` | `final String? descriptionTextOverride` | Explicit description text (overrides resource lookup). |
| `labelTextOverride` | `final String? labelTextOverride` | Explicit label text (overrides resource lookup). |

### TomFormBoolCheckbox

Checkbox rendering.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `labelText` | `String? get labelText` |  |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |

### TomFormBoolSwitch

Switch rendering.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `labelText` | `String? get labelText` |  |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |

### TomFormBoolToggle

Toggle-button rendering.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `labelText` | `String? get labelText` |  |
| `offLabel` | `String get offLabel` |  |
| `offLabelOverride` | `final String? offLabelOverride` | Label for the `false` segment. |
| `onLabel` | `String get onLabel` |  |
| `onLabelOverride` | `final String? onLabelOverride` | Label for the `true` segment. |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |

### TomFormNullableBoolField

Abstract base for `bool?` fields — the tri-state case, where null is
indeterminate rather than false.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `descriptionTextOverride` | `final String? descriptionTextOverride` | Explicit description text (overrides resource lookup). |
| `labelText` | `String? get labelText` |  |
| `labelTextOverride` | `final String? labelTextOverride` | Explicit label text (overrides resource lookup). |
| `tristate` | `bool get tristate` | Whether the user can reach the indeterminate state by interacting with the control. |
| `tristateOverride` | `final bool? tristateOverride` | Explicit [tristate] value (overrides resource lookup). |

### TomFormNullableBoolCheckbox

Material `Checkbox` with `tristate`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `labelText` | `String? get labelText` |  |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |

### TomFormStringField

Abstract base for `String` fields.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` | Resolved description: explicit → resource → null. |
| `descriptionTextOverride` | `final String? descriptionTextOverride` | Explicit description text (overrides resource lookup). |
| `hintText` | `String? get hintText` | Resolved hint: explicit → resource → null. |
| `hintTextOverride` | `final String? hintTextOverride` | Explicit hint text (overrides resource lookup). |
| `labelText` | `String? get labelText` | Resolved label: explicit → resource → tomId. |
| `labelTextOverride` | `final String? labelTextOverride` | Explicit label text (overrides resource lookup). |
| `maxLength` | `final int? maxLength` | Maximum allowed character length (optional). |
| `resolveErrorMessage` | `String resolveErrorMessage(String errorKey)` | Resolve an error message for the given error key. |
| `resolvedLabel` | `String get resolvedLabel` | Overrides [TomField.resolvedLabel] to surface the explicit [labelTextOverride] at the highest priority, matching the resolution order already used by [labelText]. |

### TomFormStringInput

Single- or multi-line text input.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `keyboardType` | `final TextInputType? keyboardType` | The keyboard type for the input. |
| `labelText` | `String? get labelText` |  |
| `maxLines` | `final int? maxLines` | Maximum number of lines for the input. |
| `prefixIcon` | `final Widget? prefixIcon` | Optional prefix icon for the input. |
| `suffixIcon` | `final Widget? suffixIcon` | Optional suffix icon for the input. |

### TomFormStringDropdown

Dropdown over a `TomSelectableSource<String>`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `labelText` | `String? get labelText` |  |
| `source` | `final TomSelectableSource<String> source` | The source of selectable items. |

### TomFormStringSegmented

`SegmentedButton` rendering of the same source.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |

### TomFormStringRadioGroup

Single-select radio-column rendering of the same source.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |

### TomFormStringChoiceChips

Single-select `ChoiceChip` row over the same source.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `chipGap` | `final double chipGap` | Gap between chips. |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |

### TomFormStringListField

Abstract base for `List<String>` fields — multi-select.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` | Resolved description: explicit → resource → null. |
| `descriptionTextOverride` | `final String? descriptionTextOverride` | Explicit description text (overrides resource lookup). |
| `labelText` | `String? get labelText` | Resolved label: explicit → resource → null. |
| `labelTextOverride` | `final String? labelTextOverride` | Explicit label text (overrides resource lookup). |
| `toggleItem` | `void toggleItem(String value, bool include)` | Toggle an item in the current selection without mutating the list in place (always allocate a fresh list so `TomField.setValue` can detect the change and fire its notifier). |

### TomFormStringFilterChips

Filter-chip rendering of a multi-select.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `chipGap` | `final double chipGap` | Gap between chips. |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |
| `source` | `final TomSelectableSource<String> source` |  |

### TomFormStringMultiCheckbox

Checkbox-column rendering of a multi-select.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |
| `source` | `final TomSelectableSource<String> source` |  |

### TomFormIntField

Abstract base for `int` fields.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `descriptionTextOverride` | `final String? descriptionTextOverride` |  |
| `hintText` | `String? get hintText` |  |
| `hintTextOverride` | `final String? hintTextOverride` |  |
| `labelText` | `String? get labelText` |  |
| `labelTextOverride` | `final String? labelTextOverride` |  |
| `maxValue` | `final int? maxValue` | Optional inclusive maximum. |
| `minValue` | `final int? minValue` | Optional inclusive minimum. |

### TomFormIntInput

Numeric text input.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `labelText` | `String? get labelText` |  |
| `prefixIcon` | `final Widget? prefixIcon` |  |
| `suffixIcon` | `final Widget? suffixIcon` |  |

### TomFormIntSlider

Slider rendering.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `divisions` | `final int? divisions` | Number of discrete divisions; defaults to `max - min`. |
| `max` | `final int max` | Upper end of the track, forwarded to the base field's `maxValue`. |
| `min` | `final int min` | Lower end of the track. |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |
| `showValueLabel` | `final bool showValueLabel` | Whether the current value is shown as a label above the thumb. |

### TomFormIntStepper

Decrement / increment stepper rendering.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |
| `step` | `final int step` |  |

### TomFormIntListField

Abstract base for `List<int>` fields.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `descriptionTextOverride` | `final String? descriptionTextOverride` | Explicit description text (overrides resource lookup). |
| `labelText` | `String? get labelText` |  |
| `labelTextOverride` | `final String? labelTextOverride` | Explicit label text (overrides resource lookup). |
| `toggleItem` | `void toggleItem(int value, bool include)` | Toggle a value in/out of the selection. |

### TomFormIntFilterChips

Filter-chip rendering of a multi-select over integers.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `chipGap` | `final double chipGap` | Gap between chips. |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |
| `source` | `final TomSelectableSource<int> source` |  |

### TomFormDoubleField

Abstract base for `double` fields.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `descriptionTextOverride` | `final String? descriptionTextOverride` |  |
| `hintText` | `String? get hintText` |  |
| `hintTextOverride` | `final String? hintTextOverride` |  |
| `labelText` | `String? get labelText` |  |
| `labelTextOverride` | `final String? labelTextOverride` |  |
| `maxValue` | `final double? maxValue` | Optional inclusive maximum. |
| `minValue` | `final double? minValue` | Optional inclusive minimum. |

### TomFormDoubleInput

Plain decimal text input.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `decimals` | `final int? decimals` | Number of decimals shown / accepted. |
| `descriptionText` | `String? get descriptionText` |  |
| `labelText` | `String? get labelText` |  |
| `prefixIcon` | `final Widget? prefixIcon` |  |
| `suffixIcon` | `final Widget? suffixIcon` |  |

### TomFormCurrencyDoubleInput

Locale-aware currency input, formatted through a `TomCurrencyFormatProfile`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `currencyCode` | `final String? currencyCode` | ISO 4217 currency code (e.g. |
| `descriptionText` | `String? get descriptionText` |  |
| `formatProfile` | `TomCurrencyFormatProfile get formatProfile` | Currency formatting profile derived from [locale] / [currencyCode]. |
| `labelText` | `String? get labelText` |  |
| `locale` | `final String? locale` | IETF locale (e.g. |
| `symbolIsLeading` | `bool get symbolIsLeading` | Returns true when the currency symbol sits *before* the amount (USD, GBP, JPY) — used by the widget to decide whether the symbol becomes the field's prefixIcon (leading) or suffixIcon (trailing). |

### TomFormPercentDoubleInput

Percentage input: the display runs 0–100, the value 0.0–1.0.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `decimals` | `final int decimals` | Decimals shown in the percent string (e.g. |
| `descriptionText` | `String? get descriptionText` |  |
| `labelText` | `String? get labelText` |  |

### TomFormDoubleSlider

Slider rendering, with divisions.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `max` | `final double max` |  |
| `min` | `final double min` |  |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |
| `valueLabelDecimals` | `final int valueLabelDecimals` |  |

### TomCurrencyFormatProfile

The small built-in currency formatter, so the package does not depend on a
localisation library for the one thing it needs. `TomCurrencyFormatProfile.resolve`
picks the profile for a locale or currency code.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `decimalSeparator` | `final String decimalSeparator` |  |
| `decimals` | `final int decimals` |  |
| `format` | `String format(double value)` |  |
| `groupSeparator` | `final String groupSeparator` |  |
| `parse` | `double? parse(String text)` |  |
| `symbol` | `final String symbol` |  |
| `symbolBeforeAmount` | `final bool symbolBeforeAmount` |  |

### TomNumRange

`TomNumRange<T extends num>` — a `(low, high)` pair, the value type of the range
fields.

### TomFormIntRangeField

Abstract base for `TomNumRange<int>` fields.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `descriptionTextOverride` | `final String? descriptionTextOverride` |  |
| `labelText` | `String? get labelText` |  |
| `labelTextOverride` | `final String? labelTextOverride` |  |
| `max` | `final int max` |  |
| `min` | `final int min` |  |

### TomFormIntRangeSlider

Two-thumb slider rendering.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `divisions` | `final int? divisions` |  |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |

### TomFormDoubleRangeField

Abstract base for `TomNumRange<double>` fields.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `descriptionTextOverride` | `final String? descriptionTextOverride` |  |
| `labelText` | `String? get labelText` |  |
| `labelTextOverride` | `final String? labelTextOverride` |  |
| `max` | `final double max` |  |
| `min` | `final double min` |  |

### TomFormDoubleRangeSlider

Two-thumb slider rendering.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `divisions` | `final int? divisions` |  |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |
| `valueLabelDecimals` | `final int valueLabelDecimals` |  |

### TomDateTimeFormat

The format-and-parse engine of the text-input date and time fields. Nine
ready-made patterns: `TomDateTimeFormat.isoDate`, `europeanDate`, `usDate`,
`germanDate`, `isoDateTime`, `europeanDateTime`, `usDateTime`, `time24` and
`time24WithSeconds`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `displayPattern` | `final String? displayPattern` | Optional localised display pattern shown to the user as a hint in the text field. |
| `formatDate` | `String formatDate(DateTime d)` | Formats [d] using the date tokens in [pattern]. |
| `formatDateTime` | `String formatDateTime(DateTime d)` | Formats [d] using all tokens in [pattern]. |
| `formatTime` | `String formatTime(TimeOfDay t)` | Formats [t] using the time tokens in [pattern]. |
| `hintText` | `String get hintText` | The placeholder hint shown to the user in empty text fields. |
| `parseDate` | `DateTime? parseDate( String text, { required DateTime firstDate, required DateTime lastDate})` | Parses a date string. |
| `parseDateTime` | `DateTime? parseDateTime( String text, { required DateTime firstDate, required DateTime lastDate})` | Parses a date+time string. |
| `parseTime` | `TimeOfDay? parseTime(String text)` | Parses a time string. |
| `pattern` | `final String pattern` | The format pattern string (machine-readable, used for parsing and formatting). |

### TomFormDateField

Abstract base for date-only `DateTime` fields — the time portion is zero.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `descriptionTextOverride` | `final String? descriptionTextOverride` |  |
| `firstDate` | `final DateTime firstDate` |  |
| `formatDate` | `String formatDate(DateTime d)` |  |
| `labelText` | `String? get labelText` |  |
| `labelTextOverride` | `final String? labelTextOverride` |  |
| `lastDate` | `final DateTime lastDate` |  |

### TomFormDatePicker

Opens the Material date-picker dialog on tap.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `labelText` | `String? get labelText` |  |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |

### TomFormDateCalendar

Renders an inline calendar rather than a dialog.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `labelText` | `String? get labelText` |  |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |

### TomFormDateTextInput

Text field parsed by a `TomDateTimeFormat`, with a calendar icon that opens
the dialog.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `format` | `final TomDateTimeFormat? format` | Optional explicit format. |
| `labelText` | `String? get labelText` |  |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |
| `resolvedFormat` | `TomDateTimeFormat get resolvedFormat` | Resolves the effective format: resource → constructor param → ISO default. |
| `resolvedHintText` | `String get resolvedHintText` | Resolves the hint text shown in the text field placeholder and error message. |

### TomFormTimeField

Abstract base for `TimeOfDay` fields.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `descriptionTextOverride` | `final String? descriptionTextOverride` |  |
| `formatTime` | `String formatTime(TimeOfDay t)` |  |
| `labelText` | `String? get labelText` |  |
| `labelTextOverride` | `final String? labelTextOverride` |  |

### TomFormTimePicker

Opens the Material time-picker dialog.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `labelText` | `String? get labelText` |  |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |

### TomFormTimeTextInput

Text field parsed by a `TomDateTimeFormat`, with a clock icon that opens the
dialog.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `format` | `final TomDateTimeFormat? format` | Optional explicit format. |
| `labelText` | `String? get labelText` |  |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |
| `resolvedFormat` | `TomDateTimeFormat get resolvedFormat` | Resolves the effective format: resource → constructor param → 24 h default. |
| `resolvedHintText` | `String get resolvedHintText` | Resolves the hint text shown in the text field placeholder and error message. |

### TomFormDateTimeField

Abstract base for `DateTime` fields carrying both date and time.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `descriptionTextOverride` | `final String? descriptionTextOverride` |  |
| `firstDate` | `final DateTime firstDate` |  |
| `formatDateTime` | `String formatDateTime(DateTime d)` |  |
| `labelText` | `String? get labelText` |  |
| `labelTextOverride` | `final String? labelTextOverride` |  |
| `lastDate` | `final DateTime lastDate` |  |

### TomFormDateTimePicker

Date dialog followed by time dialog.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `labelText` | `String? get labelText` |  |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |

### TomFormDateTimeTextInput

Text field for both halves, with a calendar icon that opens the dialogs.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `format` | `final TomDateTimeFormat? format` | Optional explicit format. |
| `labelText` | `String? get labelText` |  |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |
| `resolvedFormat` | `TomDateTimeFormat get resolvedFormat` | Resolves the effective format: resource → constructor param → ISO default. |
| `resolvedHintText` | `String get resolvedHintText` | Resolves the hint text shown in the text field placeholder and error message. |

### TomFormDateRangeField

Abstract base for `DateTimeRange` fields.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `descriptionTextOverride` | `final String? descriptionTextOverride` |  |
| `firstDate` | `final DateTime firstDate` |  |
| `formatRange` | `String formatRange(DateTimeRange r)` |  |
| `labelText` | `String? get labelText` |  |
| `labelTextOverride` | `final String? labelTextOverride` |  |
| `lastDate` | `final DateTime lastDate` |  |

### TomFormDateRangePicker

Opens the Material date-range dialog.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `labelText` | `String? get labelText` |  |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |

### TomTimeOfDayRange

A `(start, end)` pair of `TimeOfDay` values — the value type of
`TomFormTimeRangeField`, which Flutter provides no equivalent of.

### TomFormTimeRangeField

Abstract base for `TomTimeOfDayRange` fields.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `descriptionTextOverride` | `final String? descriptionTextOverride` |  |
| `formatRange` | `String formatRange(TomTimeOfDayRange r)` |  |
| `formatTime` | `String formatTime(TimeOfDay t)` |  |
| `labelText` | `String? get labelText` |  |
| `labelTextOverride` | `final String? labelTextOverride` |  |

### TomFormDateTimeRangeField

Abstract base for a `(start, end)` pair of full `DateTime` values.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `descriptionTextOverride` | `final String? descriptionTextOverride` |  |
| `firstDate` | `final DateTime firstDate` |  |
| `formatDateTime` | `String formatDateTime(DateTime d)` |  |
| `formatRange` | `String formatRange(DateTimeRange r)` |  |
| `labelText` | `String? get labelText` |  |
| `labelTextOverride` | `final String? labelTextOverride` |  |
| `lastDate` | `final DateTime lastDate` |  |

### TomFormDurationField

Abstract base for `Duration` fields.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `descriptionTextOverride` | `final String? descriptionTextOverride` |  |
| `labelText` | `String? get labelText` |  |
| `labelTextOverride` | `final String? labelTextOverride` |  |

### TomFormDurationInput

`h:mm` segmented entry.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `maxHours` | `final int maxHours` | Maximum hours allowed (display + clamp). |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |

### TomFormEnumField

`TomFormEnumField<T>` — abstract base for single-value enum selection.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `descriptionTextOverride` | `final String? descriptionTextOverride` |  |
| `labelText` | `String? get labelText` |  |
| `labelTextOverride` | `final String? labelTextOverride` |  |

### TomFormEnumDropdown

Dropdown rendering.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `source` | `final TomSelectableSource<T> source` |  |

### TomFormEnumSegmented

Segmented-button rendering.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |
| `source` | `final TomSelectableSource<T> source` |  |

### TomFormEnumRadioGroup

Radio-group rendering.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |
| `source` | `final TomSelectableSource<T> source` |  |

### TomFormEnumListField

`TomFormEnumListField<T>` — abstract base for multi-select over enum values.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `descriptionTextOverride` | `final String? descriptionTextOverride` |  |
| `labelText` | `String? get labelText` |  |
| `labelTextOverride` | `final String? labelTextOverride` |  |
| `toggleItem` | `void toggleItem(T value, bool include)` |  |

### TomFormEnumFilterChips

Filter-chip rendering of the multi-select.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `chipGap` | `final double chipGap` |  |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |
| `source` | `final TomSelectableSource<T> source` |  |

### TomFormObjectField

`TomFormObjectField<T>` — abstract base for single-value domain-object
selection. The same surface as `TomFormEnumField`, over objects rather than
enum values.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `descriptionTextOverride` | `final String? descriptionTextOverride` |  |
| `labelText` | `String? get labelText` |  |
| `labelTextOverride` | `final String? labelTextOverride` |  |

### TomFormObjectDropdown

Dropdown rendering.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `source` | `final TomSelectableSource<T> source` |  |

### TomFormObjectListField

`TomFormObjectListField<T>` — abstract base for multi-select over domain
objects.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `descriptionTextOverride` | `final String? descriptionTextOverride` |  |
| `labelText` | `String? get labelText` |  |
| `labelTextOverride` | `final String? labelTextOverride` |  |
| `toggleItem` | `void toggleItem(T value, bool include)` |  |

### TomFormObjectFilterChips

Filter-chip rendering of the multi-select.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `chipGap` | `final double chipGap` |  |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |
| `source` | `final TomSelectableSource<T> source` |  |

### TomFormSearchField

`TomFormSearchField<T>` — abstract base for search-style single-pick fields,
where the option set is too large to render at once.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `descriptionTextOverride` | `final String? descriptionTextOverride` |  |
| `hintText` | `String? get hintText` |  |
| `hintTextOverride` | `final String? hintTextOverride` |  |
| `labelText` | `String? get labelText` |  |
| `labelTextOverride` | `final String? labelTextOverride` |  |

### TomFormSearchInput

`Autocomplete`-driven type-ahead rendering.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `labelOf` | `final String Function(T value)? labelOf` | Map from selected value → display string. |
| `labelText` | `String? get labelText` |  |
| `searchPredicate` | `final bool Function(String query, TomSelectableItem<T> item)? searchPredicate` | Custom search predicate. |
| `source` | `final TomSelectableSource<T> source` |  |

### TomFormLookupField

`TomFormLookupField<T>` — abstract base for modal-picker lookup fields.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `descriptionTextOverride` | `final String? descriptionTextOverride` |  |
| `labelText` | `String? get labelText` |  |
| `labelTextOverride` | `final String? labelTextOverride` |  |

### TomFormLookupDialog

A read-only field with a *Browse* dialog.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `dialogTitle` | `final String? dialogTitle` | Title for the lookup dialog. |
| `labelOf` | `final String Function(T value)? labelOf` | Display string for the selected value. |
| `labelText` | `String? get labelText` |  |
| `source` | `final TomSelectableSource<T> source` |  |

### TomFormNStringInput

Nullable `String?` text input — an empty field is null, not the empty string.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionTextOverride` | `final String? descriptionTextOverride` |  |
| `hintTextOverride` | `final String? hintTextOverride` |  |
| `labelTextOverride` | `final String? labelTextOverride` |  |
| `maxLength` | `final int? maxLength` |  |
| `nullDisplayOverride` | `final String? nullDisplayOverride` |  |
| `prefixIcon` | `final Widget? prefixIcon` |  |

### TomFormNIntInput

Nullable `int?` input.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionTextOverride` | `final String? descriptionTextOverride` |  |
| `hintTextOverride` | `final String? hintTextOverride` |  |
| `labelTextOverride` | `final String? labelTextOverride` |  |
| `nullDisplayOverride` | `final String? nullDisplayOverride` |  |
| `prefixIcon` | `final Widget? prefixIcon` |  |

### TomFormNDoubleInput

Nullable `double?` input.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `decimals` | `final int? decimals` |  |
| `descriptionTextOverride` | `final String? descriptionTextOverride` |  |
| `hintTextOverride` | `final String? hintTextOverride` |  |
| `labelTextOverride` | `final String? labelTextOverride` |  |
| `nullDisplayOverride` | `final String? nullDisplayOverride` |  |

### TomFormNDateInput

Nullable `DateTime?` input.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionTextOverride` | `final String? descriptionTextOverride` |  |
| `firstDate` | `final DateTime firstDate` |  |
| `hintTextOverride` | `final String? hintTextOverride` |  |
| `labelTextOverride` | `final String? labelTextOverride` |  |
| `lastDate` | `final DateTime lastDate` |  |
| `nullDisplayOverride` | `final String? nullDisplayOverride` |  |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |

### TomFormNEnumDropdown

`TomFormNEnumDropdown<T>` — nullable `T?` dropdown, with an explicit null
option.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `descriptionTextOverride` | `final String? descriptionTextOverride` |  |
| `hintTextOverride` | `final String? hintTextOverride` |  |
| `labelText` | `String? get labelText` |  |
| `labelTextOverride` | `final String? labelTextOverride` |  |
| `nullDisplayOverride` | `final String? nullDisplayOverride` |  |
| `source` | `final TomSelectableSource<T> source` |  |

### TomFormFileField

Abstract base for `TomFileRef?` fields.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `allowedExtensions` | `final List<String>? allowedExtensions` | Optional list of allowed file extensions (without dot, lowercase). |
| `autoUpload` | `final bool autoUpload` | Whether picking a file immediately uploads it. |
| `canPick` | `bool get canPick` | Whether this field can open a picker at all. |
| `canTransfer` | `bool get canTransfer` | Whether this field is wired for upload and download. |
| `checkFile` | `String? checkFile(TomFileRef ref)` | Validate the picked file against `allowedExtensions` / `maxSizeBytes`. |
| `createTransferController` | `TomFileTransferController? createTransferController()` | Creates the controller for this field's slot, or `null` when the field is not wired for transfer. |
| `descriptionTextOverride` | `final String? descriptionTextOverride` |  |
| `labelTextOverride` | `final String? labelTextOverride` |  |
| `maxSizeBytes` | `final int? maxSizeBytes` | Optional inclusive maximum file size in bytes. |
| `onDownload` | `final void Function(TomFileRef ref, Uint8List bytes)? onDownload` | Called with the bytes of a stored file when the user downloads it. |
| `pickKind` | `final TomFilePickKind pickKind` | What kind of file this field is after, passed to the registered picker so it can open the right dialog. |
| `picker` | `final TomFilePicker? picker` | Optional picker callback, overriding the application's registered picker. |
| `resolvedDescriptionText` | `String? get resolvedDescriptionText` | The field's helper line: the explicit override, else `<basePath>.description`. |
| `resolvedLabelText` | `String? get resolvedLabelText` | The field's label: the explicit override, else `<basePath>.label` from resources. |
| `runPicker` | `Future<TomFileRef?> runPicker(BuildContext context)` | Opens the picker, honouring this field's constraints. |
| `storageSlot` | `final String? storageSlot` | The application-owned slot this field's file is stored in. |
| `transferClient` | `final TomFileTransferClient? transferClient` | The transport used to upload and download this field's file. |

### TomFormFileUpload

The compact *Choose file…* affordance, with the filename and transfer progress
beside it.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `labelText` | `String? get labelText` |  |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |

### TomFormFileDropzone

Drop-target rendering.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `height` | `final double height` | Height of the drop-zone surface. |
| `labelText` | `String? get labelText` |  |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |

### TomFormFileThumbnail

Image-preview rendering.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `labelText` | `String? get labelText` |  |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |
| `thumbnailSize` | `final double thumbnailSize` | Edge length of the square preview surface. |

### TomFileFieldStateMixin

The pick → validate → store → upload sequence and the transfer state behind it,
shared by the three file renderings.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `canDownload` | `bool get canDownload` | Whether the download affordance should be offered. |
| `cancelTransfer` | `void cancelTransfer()` | Cancels the transfer in flight. |
| `clear` | `Future<void> clear() async` | Clears the field, and the stored file with it when there is one. |
| `dispose` | `void dispose()` |  |
| `download` | `Future<void> download() async` | Downloads the stored file and hands its bytes to the field's `onDownload` callback. |
| `field` | `TomFormFileField get field` |  |
| `humanSize` | `String humanSize(int bytes)` |  |
| `initState` | `void initState()` |  |
| `onFieldValueChanged` | `void onFieldValueChanged()` | Called after the field's value changed and the rebuild was scheduled. |
| `rejectionMessage` | `String rejectionMessage(String errorKey)` | The sentence to show for a file [TomFormFileField.checkFile] refused. |
| `retryTransfer` | `Future<void> retryTransfer() async` | Retries the last failed or cancelled transfer. |
| `selectedCaption` | `String selectedCaption(TomFileRef ref)` | The caption naming [ref] and its size, resolved from resources. |
| `showFileRejected` | `Future<void> showFileRejected(String errorKey)` | Reports a rejected file to the user. |
| `transferController` | `TomFileTransferController? transferController` | The controller for this field's slot, or `null` when the field is picker-only. |

### TomFileThumbnailStateMixin

The preview bytes behind a thumbnail, and the single fetch that obtains them.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `ensurePreview` | `Future<void> ensurePreview() async` | Reads the bytes of a stored, renderable file that carries none locally. |
| `initState` | `void initState()` |  |
| `onFieldValueChanged` | `void onFieldValueChanged()` |  |
| `previewBytes` | `Uint8List? get previewBytes` | The bytes to paint, or `null` when there is nothing paintable yet. |
| `previewOrFallback` | `Widget previewOrFallback({required double size, required Widget fallback})` | The inline preview, or [fallback] when there is nothing to paint. |

## Cupertino fields

Twenty-eight types. Each extends the same abstract base as its Material twin —
so a form written against the bases renders in either family, and
`TomFormFieldFamily.cupertino` is the only thing that has to change.

### TomCupertinoFormBoolSwitch

`CupertinoSwitch` rendering of `TomFormBoolField`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `labelText` | `String? get labelText` |  |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |

### TomCupertinoFormBoolToggle

`CupertinoSegmentedControl<bool>` rendering of `TomFormBoolField`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `labelText` | `String? get labelText` |  |
| `offLabel` | `String get offLabel` |  |
| `offLabelOverride` | `final String? offLabelOverride` | Label for the `false` segment. |
| `onLabel` | `String get onLabel` |  |
| `onLabelOverride` | `final String? onLabelOverride` | Label for the `true` segment. |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |

### TomCupertinoFormNullableBoolToggle

Three-segment rendering of `TomFormNullableBoolField`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `labelText` | `String? get labelText` |  |
| `nullLabel` | `String get nullLabel` |  |
| `nullLabelOverride` | `final String? nullLabelOverride` | Label for the indeterminate segment. |
| `offLabel` | `String get offLabel` |  |
| `offLabelOverride` | `final String? offLabelOverride` | Label for the `false` segment. |
| `onLabel` | `String get onLabel` |  |
| `onLabelOverride` | `final String? onLabelOverride` | Label for the `true` segment. |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |

### TomCupertinoFormStringInput

`CupertinoTextField` rendering of `TomFormStringField`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `keyboardType` | `final TextInputType? keyboardType` | Keyboard type for the input. |
| `labelText` | `String? get labelText` |  |
| `maxLines` | `final int? maxLines` | Maximum number of lines. |
| `prefix` | `final Widget? prefix` | Optional prefix widget shown inside the field box. |
| `suffix` | `final Widget? suffix` | Optional suffix widget shown inside the field box. |

### TomCupertinoFormStringPicker

`CupertinoPicker` sheet rendering of `TomFormStringField`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `labelText` | `String? get labelText` |  |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |
| `sheetHeight` | `final double sheetHeight` | Height of the picker sheet. |
| `source` | `final TomSelectableSource<String> source` | Source of the selectable items. |

### TomCupertinoFormStringSearchInput

Cupertino search-field rendering of `TomFormStringField`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `labelText` | `String? get labelText` |  |

### TomCupertinoFormStringSegmented

`CupertinoSlidingSegmentedControl` rendering of `TomFormStringField`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `labelText` | `String? get labelText` |  |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |
| `source` | `final TomSelectableSource<String> source` |  |

### TomCupertinoFormStringListCheckedPicker

Checked-list sheet rendering of `TomFormStringListField`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `hintText` | `String? get hintText` |  |
| `hintTextOverride` | `final String? hintTextOverride` | Optional placeholder text shown in the closed tile when nothing is selected. |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |
| `sheetHeight` | `final double sheetHeight` | Height of the picker sheet body (action area sits above this). |
| `source` | `final TomSelectableSource<String> source` | Source of the selectable items. |

### TomCupertinoFormIntInput

`CupertinoTextField` with a numeric keyboard, rendering `TomFormIntField`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `labelText` | `String? get labelText` |  |
| `prefix` | `final Widget? prefix` | Optional prefix widget shown inside the field box. |
| `suffix` | `final Widget? suffix` | Optional suffix widget shown inside the field box. |

### TomCupertinoFormIntPicker

`CupertinoPicker` sheet over a discrete range, rendering `TomFormIntField`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `format` | `final String Function(int value)? format` | Optional formatter for the row label (defaults to `value.toString()`). |
| `labelText` | `String? get labelText` |  |
| `max` | `final int max` | Inclusive maximum shown in the picker (uses [maxValue] if not set). |
| `min` | `final int min` | Inclusive minimum shown in the picker (uses [minValue] if not set). |
| `renderLabel` | `String renderLabel(int v)` |  |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |
| `sheetHeight` | `final double sheetHeight` | Height of the picker sheet (excluding the Cancel/Done bar). |
| `step` | `final int step` | Step between consecutive values (defaults to 1). |
| `values` | `List<int> get values` | All values produced by the picker, inclusive of [min] and [max] when reachable from [step]. |

### TomCupertinoFormDoubleInput

`CupertinoTextField` with a decimal keyboard, rendering `TomFormDoubleField`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `decimals` | `final int? decimals` | Number of decimals shown / accepted. |
| `descriptionText` | `String? get descriptionText` |  |
| `labelText` | `String? get labelText` |  |
| `prefix` | `final Widget? prefix` |  |
| `suffix` | `final Widget? suffix` |  |

### TomCupertinoFormCurrencyDoubleInput

Locale-aware currency input, rendering `TomFormDoubleField`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `currencyCode` | `final String? currencyCode` | ISO 4217 currency code (e.g. |
| `descriptionText` | `String? get descriptionText` |  |
| `formatProfile` | `TomCurrencyFormatProfile get formatProfile` | Reuses the same lightweight `TomCurrencyFormatProfile` shipped with [TomFormCurrencyDoubleInput] so Cupertino renders identical numbers. |
| `labelText` | `String? get labelText` |  |
| `locale` | `final String? locale` | IETF locale (e.g. |
| `symbolIsLeading` | `bool get symbolIsLeading` | See [TomFormCurrencyDoubleInput.symbolIsLeading] — same convention. |

### TomCupertinoFormNStringInput

Nullable `String?` Cupertino input.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionTextOverride` | `final String? descriptionTextOverride` |  |
| `hintTextOverride` | `final String? hintTextOverride` |  |
| `labelTextOverride` | `final String? labelTextOverride` |  |
| `maxLength` | `final int? maxLength` |  |
| `prefix` | `final Widget? prefix` |  |

### TomCupertinoFormNIntInput

Nullable `int?` Cupertino input.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionTextOverride` | `final String? descriptionTextOverride` |  |
| `hintTextOverride` | `final String? hintTextOverride` |  |
| `labelTextOverride` | `final String? labelTextOverride` |  |
| `prefix` | `final Widget? prefix` |  |

### TomCupertinoFormNDoubleInput

Nullable `double?` Cupertino input.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `decimals` | `final int? decimals` |  |
| `descriptionTextOverride` | `final String? descriptionTextOverride` |  |
| `hintTextOverride` | `final String? hintTextOverride` |  |
| `labelTextOverride` | `final String? labelTextOverride` |  |

### TomCupertinoFormNDateInput

Nullable `DateTime?` Cupertino input.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionTextOverride` | `final String? descriptionTextOverride` |  |
| `firstDate` | `final DateTime firstDate` |  |
| `hintTextOverride` | `final String? hintTextOverride` |  |
| `labelTextOverride` | `final String? labelTextOverride` |  |
| `lastDate` | `final DateTime lastDate` |  |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |
| `sheetHeight` | `final double sheetHeight` | Height of the picker sheet (excluding the Cancel/Done bar). |

### TomCupertinoFormDatePicker

`CupertinoDatePicker` rendering of `TomFormDateField`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `labelText` | `String? get labelText` |  |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |

### TomCupertinoFormTimePicker

`CupertinoDatePicker` in time mode, rendering `TomFormTimeField`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `labelText` | `String? get labelText` |  |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |

### TomCupertinoFormDateTimePicker

`CupertinoDatePicker` in date-and-time mode, rendering `TomFormDateTimeField`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `labelText` | `String? get labelText` |  |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |

### TomCupertinoFormDurationPicker

`CupertinoTimerPicker` rendering of `TomFormDurationField`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `formatDuration` | `String formatDuration(Duration d)` |  |
| `labelText` | `String? get labelText` |  |
| `minuteInterval` | `final int minuteInterval` | Minute interval for the picker (must divide 60 evenly). |
| `mode` | `final CupertinoTimerPickerMode mode` | Picker mode (defaults to hour + minute). |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |

### TomCupertinoFormDateRangePicker

Two `CupertinoDatePicker`s in one sheet, rendering `TomFormDateRangeField`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `labelText` | `String? get labelText` |  |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |

### TomCupertinoFormEnumPicker

`CupertinoPicker` sheet rendering of `TomFormEnumField`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `labelText` | `String? get labelText` |  |
| `placeholder` | `final String? placeholder` | Optional placeholder shown when the bound value isn't present in the current source snapshot. |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |
| `sheetHeight` | `final double sheetHeight` | Height of the picker sheet (excluding the Cancel/Done bar). |
| `source` | `final TomSelectableSource<T> source` |  |

### TomCupertinoFormEnumSegmented

Sliding segmented-control rendering of `TomFormEnumField`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `labelText` | `String? get labelText` |  |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |
| `source` | `final TomSelectableSource<T> source` |  |

### TomCupertinoFormObjectPicker

`CupertinoPicker` sheet rendering of `TomFormObjectField`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `labelText` | `String? get labelText` |  |
| `placeholder` | `final String? placeholder` |  |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |
| `sheetHeight` | `final double sheetHeight` |  |
| `source` | `final TomSelectableSource<T> source` |  |

### TomCupertinoFormSearchInput

`Autocomplete` over a `CupertinoTextField`, rendering `TomFormSearchField`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `labelOf` | `final String Function(T value)? labelOf` | Display-label resolver. |
| `labelText` | `String? get labelText` |  |
| `searchPredicate` | `final bool Function(String query, TomSelectableItem<T> item)? searchPredicate` | Custom predicate. |
| `source` | `final TomSelectableSource<T> source` |  |

### TomCupertinoFormLookupSheet

A tile that opens a full Cupertino sheet, rendering `TomFormLookupField` — the
Cupertino answer to `TomFormLookupDialog`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `labelOf` | `final String Function(T value)? labelOf` | Display-label resolver. |
| `labelText` | `String? get labelText` |  |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |
| `sheetTitle` | `final String? sheetTitle` | Title for the lookup sheet. |
| `source` | `final TomSelectableSource<T> source` |  |

### TomCupertinoFormFileUpload

Cupertino rendering of `TomFormFileField` with upload progress.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `labelText` | `String? get labelText` |  |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |

### TomCupertinoFormFileThumbnail

Cupertino image-preview rendering of `TomFormFileField`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `descriptionText` | `String? get descriptionText` |  |
| `labelText` | `String? get labelText` |  |
| `resolveStyle` | `TomFieldStyle resolveStyle(BuildContext context)` |  |
| `thumbnailSize` | `final double thumbnailSize` | Edge length of the square preview surface. |

## Global Functions and Constants

None — this module exports types only.

| Name | Declaration | Description |
| ---- | ----------- | ----------- |
| `applyBorderRadius` | `InputBorder? applyBorderRadius(InputBorder? border, double radius)` | Returns [border] with its [BorderRadius] replaced by [radius], when the border is one of Flutter's built-in rounded input-border types. |
| `applyBorderWidth` | `InputBorder? applyBorderWidth(InputBorder? border, double? width)` | Returns [border] with its stroke width replaced by [width]. |
| `applyErrorVisuals` | `InputDecoration applyErrorVisuals({ required InputDecoration decoration, required TomFieldStyle style, required bool hasError})` | Applies style-driven decoration add-ons to an [InputDecoration] — the fixed leading / trailing slots and (if the field is in error) the error border switch + trailing error icon. |
| `buildFieldAnatomy` | `Widget buildFieldAnatomy({ required BuildContext context, required TomFieldStyle style, required Widget innerWidget, required TomAuthState effectiveAuth, required String? labelText, required String? descriptionText, required String? errorMessage, required bool hasRequired, required bool isEditable, required bool isSlowPending, Widget? actionIcon})` | Builds the field's anatomy column around [innerWidget] using the fully-resolved [style] for the current width. |
| `composeCupertinoLeading` | `Widget? composeCupertinoLeading(Widget? fieldPrefix, TomFieldStyle style)` | Composes [CupertinoTextField.prefix] with [TomFieldStyle.leadingWidget]. |
| `composeCupertinoTrailing` | `Widget? composeCupertinoTrailing(Widget? fieldSuffix, TomFieldStyle style)` | Mirror of [composeCupertinoLeading] for the trailing slot. |
| `composeHintStyle` | `TextStyle? composeHintStyle(TomFieldStyle style, ThemeData theme)` | Composes the effective hint [TextStyle] by layering [TomFieldStyle.hintFontWeight] and [TomFieldStyle.hintOpacity] on top of [TomFieldStyle.hintStyle]. |
| `cupertinoFieldDecoration` | `BoxDecoration cupertinoFieldDecoration({ required BuildContext context, required double borderRadius, Color? fillColor, bool focused = false})` | Tiny helper that resolves the ambient `CupertinoThemeData` and returns a `BoxDecoration` suitable for Cupertino field surfaces — honouring [TomFieldStyle.borderRadius] and the field's auth-state background hint. |
| `fieldHasRequiredValidator` | `bool fieldHasRequiredValidator(List<Object> validators)` | True when [validators] contains the canonical Required validator. |
| `guardUnsavedChanges` | `Future<TomUnsavedChangesChoice> guardUnsavedChanges({ required BuildContext context, required TomForm form, required Future<void> Function() action, String? title, String? message, String? saveLabel, String? discardLabel, String? cancelLabel}) async` | Prompts the user to save / discard / cancel when [form] is dirty, then performs [action] only if the choice doesn't abort. |
| `isColorSchemeToken` | `bool isColorSchemeToken(String raw)` | Returns true when [raw] looks like a `cs.*` color-scheme token. |
| `requiredIndicatorSuffixFor` | `String requiredIndicatorSuffixFor( TomRequiredIndicator kind, { required bool hasRequired, required bool isEditable, String? basePath})` | Text suffix for the required indicator in plain-text slots such as `InputDecoration.labelText` or `hintText`. |
| `resolveAnyColor` | `Color? resolveAnyColor( String raw, ColorScheme cs, Color? Function(String) fallback)` | Resolves [raw] using [cs] if it is a `cs.*` token, otherwise delegates to [fallback] (e.g. |
| `resolveColorSchemeToken` | `Color? resolveColorSchemeToken(String token, ColorScheme cs)` | Resolves a `cs.*` token string to a concrete [Color] from the supplied [ColorScheme]. |
| `resolveFieldValidationMessage` | `String? resolveFieldValidationMessage({ required TomValidationResult validationState, required String basePath, required String scope})` | Resolves a validation-error message through the TomCtr resource chain. |
| `resolveFormValidationMessage` | `String resolveFormValidationMessage(TomFormValidationError error)` | Resolves a form-level [TomFormValidationError] to the text a user reads. |
| `tomFileIsRenderableImage` | `bool tomFileIsRenderableImage(TomFileRef ref, TomFilePickKind pickKind)` | Whether [ref] names a file [TomFormFileThumbnail] can paint inline. |
| `tomHumanFileSize` | `String tomHumanFileSize(int bytes)` | A human-readable rendering of a byte count. |
| `tomTransferErrorMessage` | `String tomTransferErrorMessage(TomFileTransferState state, {String? basePath})` | A user-facing message for a failed transfer. |

