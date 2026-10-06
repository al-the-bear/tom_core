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
  - [FormFieldFamilyKind](#formfieldfamilykind)
  - [FormFieldFamily](#formfieldfamily)
- [Styling](#styling)
  - [TomFormStyle](#tomformstyle)
  - [TomCupertinoFormStyle](#tomcupertinoformstyle)
  - [TomFieldStyle](#tomfieldstyle)
  - [TomFieldPartialStyle](#tomfieldpartialstyle)
  - [TomStringInputStyle](#tomstringinputstyle)
  - [StringInputVariant](#stringinputvariant)
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
  - [LabelPlacement](#labelplacement)
  - [ErrorPlacement](#errorplacement)
  - [RequiredIndicator](#requiredindicator)
  - [DescriptionPlacement](#descriptionplacement)
  - [ActionIconPlacement](#actioniconplacement)
- [Decoration mixins](#decoration-mixins)
  - [TomStringInputDecorationMixin](#tomstringinputdecorationmixin)
  - [TomDropdownDecorationMixin](#tomdropdowndecorationmixin)
  - [TomGenericFieldDecorationMixin](#tomgenericfielddecorationmixin)
- [Validation](#validation)
  - [ValidationResult](#validationresult)
  - [ValidationPristine](#validationpristine)
  - [ValidationSuccess](#validationsuccess)
  - [ValidationError](#validationerror)
  - [ValidationPending](#validationpending)
  - [TomValidator](#tomvalidator)
  - [SlowValidator](#slowvalidator)
  - [Validators](#validators)
  - [TomValidatorFactory](#tomvalidatorfactory)
  - [TomValidatorRegistry](#tomvalidatorregistry)
  - [FormValidationError](#formvalidationerror)
- [Events](#events)
  - [TomFormEvent](#tomformevent)
  - [FieldValueChangedEvent](#fieldvaluechangedevent)
  - [FieldValidatedEvent](#fieldvalidatedevent)
  - [FieldAuthChangedEvent](#fieldauthchangedevent)
  - [FieldBoundEvent](#fieldboundevent)
  - [FieldCommittedEvent](#fieldcommittedevent)
  - [FormBoundEvent](#formboundevent)
  - [FormSavedEvent](#formsavedevent)
  - [FormDiscardedEvent](#formdiscardedevent)
  - [FormValidatedEvent](#formvalidatedevent)
  - [ListItemAddedEvent](#listitemaddedevent)
  - [ListItemRemovedEvent](#listitemremovedevent)
  - [ListItemReorderedEvent](#listitemreorderedevent)
  - [TomFormEventListener](#tomformeventlistener)
  - [TomFormEventSource](#tomformeventsource)
  - [TomFormInspector](#tomforminspector)
- [Selection sources](#selection-sources)
  - [TomSelectableSource](#tomselectablesource)
  - [SelectableItem](#selectableitem)
  - [StaticSelectableSource](#staticselectablesource)
  - [TomEnumSelectableSource](#tomenumselectablesource)
  - [TomEnumNameSelectableSource](#tomenumnameselectablesource)
  - [TomMutableSelectableSource](#tommutableselectablesource)
- [File fields and transfer](#file-fields-and-transfer)
  - [FileRef](#fileref)
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
  - [UnsavedChangesChoice](#unsavedchangeschoice)
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
  - [CurrencyFormatProfile](#currencyformatprofile)
  - [NumRange](#numrange)
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
  - [TimeRange](#timerange)
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

## Overview

Source: `lib/src/forms/`, barrelled by `tom_forms.dart`, which re-exports 71
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
`FormFieldFamily` is what picks between the two families at construction time,
so an application chooses once rather than at every call site. Appendix C of
`doc/tom_ui_widgets_forms.md` is the same catalogue arranged for reading;
this document is arranged for lookup.

Four support types are not fields but are exported beside them because they are
the value types the fields carry or the engines they use: `TimeRange`,
`NumRange`, `TomDateTimeFormat` and `CurrencyFormatProfile`.

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

ValidationResult (sealed)
├── ValidationPristine
├── ValidationSuccess
├── ValidationError
└── ValidationPending

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
returns `FormValidationError`s. `isDirty`, `isValid`, `dirtyFields`,
`fieldsWithErrors`, `getField`, `nestedForms` and `childContainers` are the
read surface; `fireEvent` is the write end of the event bus.

### TomField

`TomField<T>` — one value on a form. It implements `TomAuthorizable`, so
`effectiveAuthState` resolves through `TomAuthLayers` and drives `isEditable`
and `isVisible`. It holds `tomId`, `basePath`, `initialValue`, the validator
list, the debounced `validationListenable` / `validationState` pair (with a
separate, longer debounce for `SlowValidator`s), the optional action icon, and
`widget` — the one member every concrete field implements.

### TomTextFormFieldBase

`TomTextFormFieldBase<T>` — the base of every field whose input is a
`TextField`. It owns the `TextEditingController`, the raw-text mirror of the
typed value, the error-text notifier, and the split between validators that see
the parsed value and those that see the raw input.

### TomFormChildContainer

Marker interface for a non-`TomForm` child whose lifecycle the enclosing form
drives — the list containers implement it, which is how a `TomListForm` nested
in a form is disposed and snapshotted with it.

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

## Family selection

### FormFieldFamilyKind

`material` or `cupertino` — the identifier a family carries, and what an
application stores when it persists the choice.

### FormFieldFamily

The factory that constructs concrete field instances of one family. The two
instances are `FormFieldFamily.material` and `FormFieldFamily.cupertino`; a
form built through a family is written once and renders in either.

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

### TomCupertinoFormStyle

The Cupertino flavour of `TomFormStyle`, exposed as
`TomCupertinoFormStyle.cupertino`.

### TomFieldStyle

The shared, fully-populated base every field falls back to. Nothing on it is
nullable, so resolution always terminates.

### TomFieldPartialStyle

The base of the eleven partial overrides: the same properties as
`TomFieldStyle`, all nullable, plus the breakpoint-override lists.

### TomStringInputStyle

Partial override for text-input fields. Carries `StringInputVariant`.

### StringInputVariant

`material` or `bordered` — the decoration flavour a text input uses.

### TomDropdownStyle

Partial override for dropdown selection fields.

### TomSliderStyle

Partial override for slider fields.

### TomCheckboxStyle

Partial override for checkbox fields.

### TomSwitchStyle

Partial override for switch fields.

### TomSegmentedStyle

Partial override for segmented-button fields.

### TomRadioGroupStyle

Partial override for radio-group fields. Distinct from the `custom` module's
`TomChoiceGroup`, which takes no style object.

### TomDatePickerStyle

Partial override for date-picker fields.

### TomTimePickerStyle

Partial override for time-picker fields.

### TomFilePickerStyle

Partial override for file-picker fields.

### TomChipsStyle

Partial override for chips and multi-select fields.

### TomMultilineInputStyle

Partial override for multiline-input fields.

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

### LabelPlacement

`above`, `below`, `floating`, `inline` or `hidden`.

### ErrorPlacement

`below`, `above`, `tooltip`, `both` or `replaceDescription`.

### RequiredIndicator

`asterisk`, `text`, `none` or `custom`.

### DescriptionPlacement

`below`, `above` or `tooltip`.

### ActionIconPlacement

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

Decoration for string-input fields, including the `StringInputVariant` split.
Nine files mix it in.

### TomDropdownDecorationMixin

Decoration for dropdown selection fields. Four files mix it in.

### TomGenericFieldDecorationMixin

Decoration for non-text-input fields — checkboxes, switches, sliders, pickers,
chips and the rest. Twenty of the catalogue's files mix it in, which is every
field that is not a text input or a dropdown.

## Validation

### ValidationResult

The sealed result of validating one field value. Exhaustive over the four
states below, so a `switch` on it needs no default arm.

### ValidationPristine

The initial state, before the user has interacted with the field. Distinct from
success: a pristine field is not yet known to be valid.

### ValidationSuccess

The value is valid.

### ValidationError

The value is invalid; carries the message to display.

### ValidationPending

An async validation is in flight.

### TomValidator

`TomValidator<T>` — `FutureOr<ValidationResult> Function(T value)`. The
contract every validator satisfies, sync and async alike.

### SlowValidator

Wraps a validator to declare it slow — a remote call, typically. `TomField`
debounces slow validators separately and longer, and reports
`isSlowValidationPending` while one is outstanding.

### Validators

The built-in validators, all statics: `Validators.required` (and the shared
`Validators.requiredInstance`), `email`, `minLength`, `maxLength`, `pattern`,
`min`, `max`, `minItems`, `maxItems`, and `Validators.compose`, which runs a
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

### FormValidationError

A cross-field error produced by `TomForm.validateForm` — it belongs to the form
rather than to any one field, which is why it is not a `ValidationResult`.

## Events

Every form and field change is published as a `TomFormEvent` on the form's
event bus, so an application observes what happened without subclassing the
widget that did it.

### TomFormEvent

The base of every event below. Carries the form and the timestamp.

### FieldValueChangedEvent

A field's value changed.

### FieldValidatedEvent

A field finished validating; carries the resulting `ValidationResult`.

### FieldAuthChangedEvent

A field's effective authorization state changed.

### FieldBoundEvent

A field was bound to data.

### FieldCommittedEvent

A field's current value became its new initial value — what a successful save
does, and what resets `isDirty`.

### FormBoundEvent

A form was bound to a data object.

### FormSavedEvent

A form saved successfully.

### FormDiscardedEvent

A form discarded its edits.

### FormValidatedEvent

A form finished validating.

### ListItemAddedEvent

A sub-form was appended to or inserted into a `TomListForm`.

### ListItemRemovedEvent

A sub-form was removed from a `TomListForm`.

### ListItemReorderedEvent

A sub-form moved within a `TomListForm`.

### TomFormEventListener

The listener mixin, with a no-op default for each event type — so an
implementation overrides only the events it cares about.

### TomFormEventSource

The abstract source a form satisfies: register and unregister listeners.

### TomFormInspector

A collector that buffers events for inspection. Written for tests, and the
shortest way to assert that a sequence of interactions produced the sequence of
events it should have.

## Selection sources

### TomSelectableSource

`TomSelectableSource<T>` — the abstract source of options behind every
selection field: dropdowns, segmented buttons, radio groups, chips and the
lookup dialogs all read one.

### SelectableItem

`SelectableItem<T>` — one option: its value, its label, and its optional icon
and enabled flag.

### StaticSelectableSource

`StaticSelectableSource<T>` — a source backed by a fixed list.

### TomEnumSelectableSource

`TomEnumSelectableSource<E extends Enum>` — a source over an enum whose option
labels come from the resource bundle, so the labels localise without the field
knowing.

### TomEnumNameSelectableSource

The `Enum.name`-valued twin of `TomEnumSelectableSource`: the same labels,
carrying the name rather than the enum value, for a field whose bound property
is a `String`.

### TomMutableSelectableSource

`TomMutableSelectableSource<T>` — a source whose item set can be replaced at
runtime, which is what a dependent dropdown needs.

## File fields and transfer

### FileRef

The reference a file field carries as its value: the stored file's identity,
not its bytes.

### TomFilePicker

`TomFilePicker` — `Future<FileRef?> Function(BuildContext context)`. What a
file field calls to obtain a file; `null` means the user cancelled.

### TomPlatformFilePicker

The adaptor over a platform picker, returning what the user chose as a
`TomPickedFile`. Separating it from `TomFilePicker` is what keeps the platform
plugin out of this package.

### TomPickedFile

What a platform picker returned: the bytes or a path, plus the name and MIME
type.

### TomFilePickRequest

What a field wants picked — the kind, the accepted extensions and the size
limit — passed to the registered picker.

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
a `TomPickedFile` into the `FileRef` a field stores.

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

### TomFileTransferState

Where a transfer stands: its `phase`, its `kind`, the progress, the error, the
file metadata, and the client and slot it belongs to.

### TomTransferPhase

`idle`, `running`, `succeeded`, `cancelled` or `failed`.

### TomTransferKind

`none`, `upload`, `download` or `removal` — what the controller last ran.

### TomFileTransferIndicator

Renders the state of the transfer a `TomFileTransferController` is running.

## List forms

A `TomListForm` owns an ordered collection of sub-forms — one per item — and
the three container widgets render the same list differently. Each implements
`TomFormChildContainer`, so an enclosing form drives their lifecycle.

### TomListForm

`TomListForm<TItem extends TomClass, TForm extends TomForm<TItem>>` — the
container itself: the ordered sub-forms, and the add, insert, remove and
reorder operations that fire the three list events.

### TomInlineListForm

Renders the list as a vertically stacked sequence of inline sub-forms.

### TomExpandableListForm

Renders the list as a vertical sequence of expandable rows.

### TomExpandableListFormController

Controls expansion from outside the widget. The widget creates one when none is
supplied.

### TomExpansionPolicy

`singleOpen` or `multipleOpen`.

### TomMasterDetailListForm

A two-pane master-detail layout over a `TomListForm`: the row list on one side,
the selected sub-form on the other.

### TomListFormToolbar

The compact action bar carrying the standard list mutations — add, insert,
remove, and the move pair.

### TomListRowMoveButtons

A *Move up* / *Move down* pair bound to one row index of a `TomListForm`.

### TomRowMoveButtonsPosition

`leading` or `trailing` — which side of a row the move buttons attach to.

### TomReorderHandle

The standard drag handle for reordering rows in a `ReorderableListView`.

## Form-level widgets

### TomErrorView

A placement-flexible form-wide error display.

### TomFormErrorBanner

The Material banner for form-level, cross-field errors — the
`FormValidationError`s `TomForm.validateForm` returned.

### TomRowErrorStrip

The compact per-row error strip a list form uses, where a full banner would not
fit.

### TomMultiObservableBuilder

Observes several `TomObservable`s and rebuilds when any of them changes. The
one widget here that is not about errors: it is what a form-aware widget
outside the field tree uses to follow form state.

### TomUnsavedChangesGuard

Wraps a subtree in a `PopScope` that defers a route pop while its form is
dirty, and prompts.

### UnsavedChangesChoice

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

### TomFormBoolCheckbox

Checkbox rendering.

### TomFormBoolSwitch

Switch rendering.

### TomFormBoolToggle

Toggle-button rendering.

### TomFormNullableBoolField

Abstract base for `bool?` fields — the tri-state case, where null is
indeterminate rather than false.

### TomFormNullableBoolCheckbox

Material `Checkbox` with `tristate`.

### TomFormStringField

Abstract base for `String` fields.

### TomFormStringInput

Single- or multi-line text input.

### TomFormStringDropdown

Dropdown over a `TomSelectableSource<String>`.

### TomFormStringSegmented

`SegmentedButton` rendering of the same source.

### TomFormStringRadioGroup

Single-select radio-column rendering of the same source.

### TomFormStringChoiceChips

Single-select `ChoiceChip` row over the same source.

### TomFormStringListField

Abstract base for `List<String>` fields — multi-select.

### TomFormStringFilterChips

Filter-chip rendering of a multi-select.

### TomFormStringMultiCheckbox

Checkbox-column rendering of a multi-select.

### TomFormIntField

Abstract base for `int` fields.

### TomFormIntInput

Numeric text input.

### TomFormIntSlider

Slider rendering.

### TomFormIntStepper

Decrement / increment stepper rendering.

### TomFormIntListField

Abstract base for `List<int>` fields.

### TomFormIntFilterChips

Filter-chip rendering of a multi-select over integers.

### TomFormDoubleField

Abstract base for `double` fields.

### TomFormDoubleInput

Plain decimal text input.

### TomFormCurrencyDoubleInput

Locale-aware currency input, formatted through a `CurrencyFormatProfile`.

### TomFormPercentDoubleInput

Percentage input: the display runs 0–100, the value 0.0–1.0.

### TomFormDoubleSlider

Slider rendering, with divisions.

### CurrencyFormatProfile

The small built-in currency formatter, so the package does not depend on a
localisation library for the one thing it needs. `CurrencyFormatProfile.resolve`
picks the profile for a locale or currency code.

### NumRange

`NumRange<T extends num>` — a `(low, high)` pair, the value type of the range
fields.

### TomFormIntRangeField

Abstract base for `NumRange<int>` fields.

### TomFormIntRangeSlider

Two-thumb slider rendering.

### TomFormDoubleRangeField

Abstract base for `NumRange<double>` fields.

### TomFormDoubleRangeSlider

Two-thumb slider rendering.

### TomDateTimeFormat

The format-and-parse engine of the text-input date and time fields. Nine
ready-made patterns: `TomDateTimeFormat.isoDate`, `europeanDate`, `usDate`,
`germanDate`, `isoDateTime`, `europeanDateTime`, `usDateTime`, `time24` and
`time24WithSeconds`.

### TomFormDateField

Abstract base for date-only `DateTime` fields — the time portion is zero.

### TomFormDatePicker

Opens the Material date-picker dialog on tap.

### TomFormDateCalendar

Renders an inline calendar rather than a dialog.

### TomFormDateTextInput

Text field parsed by a `TomDateTimeFormat`, with a calendar icon that opens
the dialog.

### TomFormTimeField

Abstract base for `TimeOfDay` fields.

### TomFormTimePicker

Opens the Material time-picker dialog.

### TomFormTimeTextInput

Text field parsed by a `TomDateTimeFormat`, with a clock icon that opens the
dialog.

### TomFormDateTimeField

Abstract base for `DateTime` fields carrying both date and time.

### TomFormDateTimePicker

Date dialog followed by time dialog.

### TomFormDateTimeTextInput

Text field for both halves, with a calendar icon that opens the dialogs.

### TomFormDateRangeField

Abstract base for `DateTimeRange` fields.

### TomFormDateRangePicker

Opens the Material date-range dialog.

### TimeRange

A `(start, end)` pair of `TimeOfDay` values — the value type of
`TomFormTimeRangeField`, which Flutter provides no equivalent of.

### TomFormTimeRangeField

Abstract base for `TimeRange` fields.

### TomFormDateTimeRangeField

Abstract base for a `(start, end)` pair of full `DateTime` values.

### TomFormDurationField

Abstract base for `Duration` fields.

### TomFormDurationInput

`h:mm` segmented entry.

### TomFormEnumField

`TomFormEnumField<T>` — abstract base for single-value enum selection.

### TomFormEnumDropdown

Dropdown rendering.

### TomFormEnumSegmented

Segmented-button rendering.

### TomFormEnumRadioGroup

Radio-group rendering.

### TomFormEnumListField

`TomFormEnumListField<T>` — abstract base for multi-select over enum values.

### TomFormEnumFilterChips

Filter-chip rendering of the multi-select.

### TomFormObjectField

`TomFormObjectField<T>` — abstract base for single-value domain-object
selection. The same surface as `TomFormEnumField`, over objects rather than
enum values.

### TomFormObjectDropdown

Dropdown rendering.

### TomFormObjectListField

`TomFormObjectListField<T>` — abstract base for multi-select over domain
objects.

### TomFormObjectFilterChips

Filter-chip rendering of the multi-select.

### TomFormSearchField

`TomFormSearchField<T>` — abstract base for search-style single-pick fields,
where the option set is too large to render at once.

### TomFormSearchInput

`Autocomplete`-driven type-ahead rendering.

### TomFormLookupField

`TomFormLookupField<T>` — abstract base for modal-picker lookup fields.

### TomFormLookupDialog

A read-only field with a *Browse* dialog.

### TomFormNStringInput

Nullable `String?` text input — an empty field is null, not the empty string.

### TomFormNIntInput

Nullable `int?` input.

### TomFormNDoubleInput

Nullable `double?` input.

### TomFormNDateInput

Nullable `DateTime?` input.

### TomFormNEnumDropdown

`TomFormNEnumDropdown<T>` — nullable `T?` dropdown, with an explicit null
option.

### TomFormFileField

Abstract base for `FileRef?` fields.

### TomFormFileUpload

The compact *Choose file…* affordance, with the filename and transfer progress
beside it.

### TomFormFileDropzone

Drop-target rendering.

### TomFormFileThumbnail

Image-preview rendering.

### TomFileFieldStateMixin

The pick → validate → store → upload sequence and the transfer state behind it,
shared by the three file renderings.

### TomFileThumbnailStateMixin

The preview bytes behind a thumbnail, and the single fetch that obtains them.

## Cupertino fields

Twenty-eight types. Each extends the same abstract base as its Material twin —
so a form written against the bases renders in either family, and
`FormFieldFamily.cupertino` is the only thing that has to change.

### TomCupertinoFormBoolSwitch

`CupertinoSwitch` rendering of `TomFormBoolField`.

### TomCupertinoFormBoolToggle

`CupertinoSegmentedControl<bool>` rendering of `TomFormBoolField`.

### TomCupertinoFormNullableBoolToggle

Three-segment rendering of `TomFormNullableBoolField`.

### TomCupertinoFormStringInput

`CupertinoTextField` rendering of `TomFormStringField`.

### TomCupertinoFormStringPicker

`CupertinoPicker` sheet rendering of `TomFormStringField`.

### TomCupertinoFormStringSearchInput

Cupertino search-field rendering of `TomFormStringField`.

### TomCupertinoFormStringSegmented

`CupertinoSlidingSegmentedControl` rendering of `TomFormStringField`.

### TomCupertinoFormStringListCheckedPicker

Checked-list sheet rendering of `TomFormStringListField`.

### TomCupertinoFormIntInput

`CupertinoTextField` with a numeric keyboard, rendering `TomFormIntField`.

### TomCupertinoFormIntPicker

`CupertinoPicker` sheet over a discrete range, rendering `TomFormIntField`.

### TomCupertinoFormDoubleInput

`CupertinoTextField` with a decimal keyboard, rendering `TomFormDoubleField`.

### TomCupertinoFormCurrencyDoubleInput

Locale-aware currency input, rendering `TomFormDoubleField`.

### TomCupertinoFormNStringInput

Nullable `String?` Cupertino input.

### TomCupertinoFormNIntInput

Nullable `int?` Cupertino input.

### TomCupertinoFormNDoubleInput

Nullable `double?` Cupertino input.

### TomCupertinoFormNDateInput

Nullable `DateTime?` Cupertino input.

### TomCupertinoFormDatePicker

`CupertinoDatePicker` rendering of `TomFormDateField`.

### TomCupertinoFormTimePicker

`CupertinoDatePicker` in time mode, rendering `TomFormTimeField`.

### TomCupertinoFormDateTimePicker

`CupertinoDatePicker` in date-and-time mode, rendering `TomFormDateTimeField`.

### TomCupertinoFormDurationPicker

`CupertinoTimerPicker` rendering of `TomFormDurationField`.

### TomCupertinoFormDateRangePicker

Two `CupertinoDatePicker`s in one sheet, rendering `TomFormDateRangeField`.

### TomCupertinoFormEnumPicker

`CupertinoPicker` sheet rendering of `TomFormEnumField`.

### TomCupertinoFormEnumSegmented

Sliding segmented-control rendering of `TomFormEnumField`.

### TomCupertinoFormObjectPicker

`CupertinoPicker` sheet rendering of `TomFormObjectField`.

### TomCupertinoFormSearchInput

`Autocomplete` over a `CupertinoTextField`, rendering `TomFormSearchField`.

### TomCupertinoFormLookupSheet

A tile that opens a full Cupertino sheet, rendering `TomFormLookupField` — the
Cupertino answer to `TomFormLookupDialog`.

### TomCupertinoFormFileUpload

Cupertino rendering of `TomFormFileField` with upload progress.

### TomCupertinoFormFileThumbnail

Cupertino image-preview rendering of `TomFormFileField`.
