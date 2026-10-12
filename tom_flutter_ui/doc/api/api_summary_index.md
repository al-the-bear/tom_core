# Tom Flutter UI API Reference: Index

Symbol-level API summaries for this package's larger modules, one file per
module, under `doc/api/`. Each lists every public type its module's barrel
exports, with a section per type, and names every public static member. Which
modules get one is a stated rule, below.

`test/module_readme_inventory_test.dart` holds that claim: it discovers the
summaries from this directory, derives the required set from each module's
barrel, and fails on a type that has no section or a static that is never
named. So a summary that exists is complete, and one that falls behind the code
fails rather than misleading.

## Summaries

| Module | Summary | Covers |
| ------ | ------- | ------ |
| `advanced_container_layout` | [api_summary_advanced_container_layout.md](api_summary_advanced_container_layout.md) | The row-based layout engine: the fluent builder, the row and component model, and the widgets that render them. |
| `actions` | [api_summary_actions.md](api_summary_actions.md) | Business logic as typed, stateless, authorizable objects with undo and redo. |
| `custom` | [api_summary_custom.md](api_summary_custom.md) | The eight composites that are not form fields: authorization guards, list states, and loading affordances. |
| `groups` | [api_summary_groups.md](api_summary_groups.md) | The authorization groups widgets share and the mixin that lets a widget extending Flutter directly take part in them. |
| `forms` | [api_summary_forms.md](api_summary_forms.md) | The declarative forms framework: form and field bases, the Material and Cupertino field catalogues, styling, validation, events, selection sources, file transfer, and the list containers. |
| `resource_auth` | [api_summary_resource_auth.md](api_summary_resource_auth.md) | Resource resolution: colour and icon names to Flutter objects, and the environment and platform configuration they resolve against. |
| `theme` | [api_summary_theme.md](api_summary_theme.md) | Tom's theme extensions over Flutter's `ThemeData`, the scope that provides them, and the serialisable root theme spec. |
| `widgets` | [api_summary_widgets.md](api_summary_widgets.md) | The 299 Tom wrappers over Material, Cupertino and the widget layer, and the family bases they extend. |
| `widget_base` | [api_summary_widget_base.md](api_summary_widget_base.md) | The foundation every Tom widget stands on: the node chain carrying identity and authorization, the family bases, and the two static resolvers. |

## Which modules get one

**Every module has a summary.** The repository's
`tom_ai/core/tool/check_api_reference.py` asks for one per module, and each is
held there to its barrel: Source list, index rows, every exported name and
every public member.

**A module owes one at ten exported public types**, which is the floor this
package's own suite enforces. Below it the module's `lib/src/<module>/readme.md`
is a mirror too — an inventory readme is held to every public type and every
public static by the same test — so `groups` and `theme` are each checked
twice. Types, not lines: `resource_auth` declares 13 types across 11,352 lines
and `theme` 4 across 365, and a line threshold would be measuring the generated
tables inside one of them.

**`tom_core_agentic` states the same threshold over members**, and
deliberately so: its units concentrate their surface in a few types with many
members — `placeholders` is 6 types and 35 members — so a type count there puts
a unit beside the two-constant ones that its size says it is not. Here the
opposite holds: a widget is the unit of surface, most of the 299 are a
constructor and no more, and a member count would measure the base class's
parameter list rather than the kit. The two rules disagree because the packages
have different shapes, not because one is stale — so the number is the same and
what it counts is not, and a reader who has met one index should not assume the
other.

A **catalogue** module is outside that floor, and `widgets` shows why the
exemption is not a shortcut. Its summary is generated from the source; the
claims a reader most relies on are held by suites a markdown mirror cannot
match:

- **The names.** `test/widgets/widget_census.dart` derives them from the
  sources; `widget_conformance_test.dart` asserts that
  `widget_conformance_registry.dart` holds precisely that set, in both
  directions.
- **The signatures.** The registry *constructs* every one of the 299, so a
  wrapper whose constructor changed shape fails to compile rather than fails to
  match a document. The parameters they share are derived from the base itself
  by `test/widget_base/base_parameter_claims_test.dart`, which fails the
  documents that describe a different list.
- **The counts and the family catalogue.** `widget_family_claims_test.dart`
  asserts every three-digit number the kit's documents quote against the
  census, and checks each catalogue row against the class declarations it
  names.

The threshold is a constant in `test/module_readme_inventory_test.dart`, which
derives each module's type count from its barrel and fails when a module
reaches it without a summary. So the rule is enforced rather than described,
and lowering it is a code change somebody has to make deliberately.

### Actions (`lib/src/actions/`)

Summary: [api_summary_actions.md](api_summary_actions.md)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomAction` | abstract class | Base class for all Tom actions. |
| `TomActionContext` | class | Base context available to all actions. |
| `TomActionController` | class | Container for a group of related actions. |
| `TomActionTransaction` | class | Groups sub-actions into an atomic unit for undo purposes. |
| `TomActionTrigger` | class | Connects a [TomAction] to a widget's callback (e.g., onPressed). |
| `TomActionUndo` | abstract interface class | Tag interface for undo state objects. |
| `TomCompositeAction` | class | Adapter action that executes multiple actions sequentially. |
| `TomCompositeStep` | class | A single step in a [TomCompositeAction]. |
| `TomRedoAction` | class | Action that drives [TomUndoHistory.redo]. |
| `TomSimpleAction` | abstract class | A [TomAction] that does not produce undo state. |
| `TomUndoAction` | class | Action that undoes the most recent transaction in the undo history. |
| `TomUndoHistory` | class | Application-level undo/redo history. |
| `TomUndoRedoContext` | class | Context for undo/redo coordinator actions. |

### Custom (`lib/src/custom/`)

Summary: [api_summary_custom.md](api_summary_custom.md)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomAuthGuard` | class | Inline wrapper that hides or disables its [child] based on the resolved [TomAuthState] for the given [tomId] (resource key path). |
| `TomAuthTreeNode` | class | Data model for a node inside a [TomAuthTreeView]. |
| `TomAuthTreeView` | class | Tree view that resolves authorization independently per node. |
| `TomChoiceGroup` | class | Radio group with group-level authorization. |
| `TomChoiceGroupItem` | class | One radio entry in a [TomChoiceGroup]. |
| `TomEmptyState` | class | Standard placeholder for empty data views. |
| `TomErrorBoundary` | class | Inline error boundary — catches build errors inside [child] and renders a fallback UI. |
| `TomErrorBoundaryFallbackBuilder` | typedef | Builder signature for the fallback UI rendered when an error is caught. |
| `TomInfiniteScroll` | class | List wrapper with pagination, observable page fetcher, and empty / error / loading-state hooks. |
| `TomInfiniteScrollErrorBuilder` | typedef | Builds the report for a page that failed. |
| `TomInfiniteScrollErrorPlacement` | enum | Where a page failure is being reported. |
| `TomInfiniteScrollItemBuilder` | typedef | Builds a single list tile from an item. |
| `TomInfiniteScrollState` | class | Public state for [TomInfiniteScroll]. |
| `TomLoadingOverlay` | class | Full-surface loading indicator overlay. |
| `TomPageFetcher` | typedef | Fetches one page of items. |
| `TomSkeletonLoader` | class | Shimmering skeleton placeholder for async-loading surfaces. |

### Forms (`lib/src/forms/`)

Summary: [api_summary_forms.md](api_summary_forms.md)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomField` | abstract class |  |
| `TomForm` | abstract class |  |
| `TomFormChildContainer` | abstract interface class | Marker interface for non-`TomForm` form children whose lifecycle a parent [TomForm] should fan out into. |
| `TomFormFieldFamily` | class | Factory that constructs concrete field instances of either the Material or Cupertino family while exposing the shared abstract types as the return value. |
| `TomFormFieldFamilyKind` | enum | Family identifier — picks Material or Cupertino concrete implementations. |
| `TomFormLabels` | abstract final class | The user-visible strings of the form widgets. |
| `TomTextFormFieldBase` | class | Base class for text-based form fields with TextEditingController support. |
| `TomActionIconPlacement` | enum | Controls where action icons appear relative to the field input. |
| `TomBreakpoint` | class | Named breakpoint values shared across the form system (and the rest of the app, if you want). |
| `TomCheckboxStyle` | class | Partial override for checkbox fields. |
| `TomChipsStyle` | class | Partial override for chips / multi-select fields. |
| `TomCupertinoFormBoolSwitch` | class | Renders the boolean as a [CupertinoSwitch] inside the standard field anatomy. |
| `TomCupertinoFormBoolToggle` | class | Renders the boolean as a two-segment [CupertinoSegmentedControl] (Off / On). |
| `TomCupertinoFormCurrencyDoubleInput` | class |  |
| `TomCupertinoFormDatePicker` | class |  |
| `TomCupertinoFormDateRangePicker` | class |  |
| `TomCupertinoFormDateTimePicker` | class |  |
| `TomCupertinoFormDoubleInput` | class |  |
| `TomCupertinoFormDurationPicker` | class |  |
| `TomCupertinoFormEnumPicker` | class |  |
| `TomCupertinoFormEnumSegmented` | class |  |
| `TomCupertinoFormFileThumbnail` | class | The Cupertino sibling of `TomFormFileThumbnail`. |
| `TomCupertinoFormFileUpload` | class |  |
| `TomCupertinoFormIntInput` | class |  |
| `TomCupertinoFormIntPicker` | class |  |
| `TomCupertinoFormLookupSheet` | class |  |
| `TomCupertinoFormNDateInput` | class |  |
| `TomCupertinoFormNDoubleInput` | class |  |
| `TomCupertinoFormNIntInput` | class |  |
| `TomCupertinoFormNStringInput` | class |  |
| `TomCupertinoFormNullableBoolToggle` | class | The Cupertino face of the tristate boolean field. |
| `TomCupertinoFormObjectPicker` | class |  |
| `TomCupertinoFormSearchInput` | class |  |
| `TomCupertinoFormStringInput` | class |  |
| `TomCupertinoFormStringListCheckedPicker` | class |  |
| `TomCupertinoFormStringPicker` | class |  |
| `TomCupertinoFormStringSearchInput` | class |  |
| `TomCupertinoFormStringSegmented` | class |  |
| `TomCupertinoFormStyle` | class | Cupertino flavour of [TomFormStyle]. |
| `TomCupertinoFormTimePicker` | class |  |
| `TomCurrencyFormatProfile` | class | Tiny built-in currency formatter, so the package need not depend on `intl`. |
| `TomDatePickerStyle` | class | Partial override for date-picker fields. |
| `TomDateTimeFormat` | class | Format and parse engine for text-input date/time fields. |
| `TomDescriptionPlacement` | enum | Controls where the description/helper text appears. |
| `TomDropdownDecorationMixin` | mixin | Decoration mixin for dropdown selection fields. |
| `TomDropdownStyle` | class | Partial override for dropdown selection fields. |
| `TomEnumNameSelectableSource` | class | The [Enum.name]-valued twin of [TomEnumSelectableSource]: same bundle-resolved labels, but each option is worth the enum's name. |
| `TomEnumSelectableSource` | class | A [TomSelectableSource] over an enum whose option labels come from the application text bundle instead of a Dart-side label table. |
| `TomErrorPlacement` | enum | Controls where validation error messages appear. |
| `TomErrorView` | class | Placement-flexible form-wide error display. |
| `TomExpandableListForm` | class | Renders a [TomListForm] as a vertical sequence of expandable rows — each row collapsed shows a builder-supplied summary, expanded shows a builder-supplied editor for the row's [TForm]. |
| `TomExpandableListFormController` | class | Controls expansion state from outside the widget. |
| `TomExpansionPolicy` | enum | Expansion policy for [TomExpandableListForm]. |
| `TomFieldAuthChangedEvent` | class | Fired when a field's effective authorization state changes. |
| `TomFieldBoundEvent` | class | Fired when a field is bound to data. |
| `TomFieldCommittedEvent` | class | Fired when a field's current value is committed as the new initial value. |
| `TomFieldPartialStyle` | class |  |
| `TomFieldStyle` | class | The shared, **fully-populated** base of a [TomFormStyle]. |
| `TomFieldValidatedEvent` | class | Fired when a field completes validation. |
| `TomFieldValueChangedEvent` | class | Fired when a field's value changes. |
| `TomFieldWidgetAdapter` | class | A thin [StatelessWidget] wrapper that lets a widget rendered by a [TomField] participate in [TomAuthorizable] protocols. |
| `TomFileFieldStateMixin` | mixin | The pick → validate → store → upload sequence and the transfer state that goes with it, shared by every file-field widget in both families. |
| `TomFileLabels` | abstract final class | The user-visible strings of the file widgets. |
| `TomFilePickKind` | enum | The kind of file a field wants, so an adaptor can pick the right dialog. |
| `TomFilePickRequest` | class | What a field is asking the picker for. |
| `TomFilePicker` | typedef | Picker callback contract. |
| `TomFilePickerRegistry` | class | Holds the application's platform picker. |
| `TomFilePickerStyle` | class | Partial override for file-picker fields. |
| `TomFilePickers` | class | Ready-made [TomFilePicker] callbacks and the [TomPickedFile] → [TomFileRef] conversion they share. |
| `TomFileRef` | class | Lightweight, framework-agnostic file reference. |
| `TomFileThumbnailStateMixin` | mixin | The preview bytes behind a thumbnail, and the one fetch that gets them. |
| `TomFileTransferController` | class | Drives one file slot's transfers and publishes their state. |
| `TomFileTransferIndicator` | class | Shows the state of the transfer [controller] is running. |
| `TomFileTransferState` | class | A snapshot of a transfer, as a widget needs to render it. |
| `TomFormBoolCheckbox` | class | Renders the boolean as a Material [Checkbox] with the standard field anatomy wrapped around it. |
| `TomFormBoolField` | abstract class | Abstract base for boolean form fields. |
| `TomFormBoolSwitch` | class | Renders the boolean as a Material [Switch]. |
| `TomFormBoolToggle` | class | Renders the boolean as a two-segment [SegmentedButton] (Off/On). |
| `TomFormBoundEvent` | class | Fired when a form is bound to a data object. |
| `TomFormCurrencyDoubleInput` | class |  |
| `TomFormDateCalendar` | class |  |
| `TomFormDateField` | abstract class |  |
| `TomFormDatePicker` | class |  |
| `TomFormDateRangeField` | abstract class |  |
| `TomFormDateRangePicker` | class |  |
| `TomFormDateTextInput` | class |  |
| `TomFormDateTimeField` | abstract class |  |
| `TomFormDateTimePicker` | class |  |
| `TomFormDateTimeRangeField` | abstract class | Abstract field for a `(start, end)` pair of full [DateTime] values. |
| `TomFormDateTimeTextInput` | class |  |
| `TomFormDiscardedEvent` | class | Fired when a form discards its edits. |
| `TomFormDoubleField` | abstract class |  |
| `TomFormDoubleInput` | class |  |
| `TomFormDoubleRangeField` | abstract class |  |
| `TomFormDoubleRangeSlider` | class |  |
| `TomFormDoubleSlider` | class |  |
| `TomFormDurationField` | abstract class |  |
| `TomFormDurationInput` | class |  |
| `TomFormEnumDropdown` | class |  |
| `TomFormEnumField` | abstract class | Abstract base for single-value enum selection. |
| `TomFormEnumFilterChips` | class |  |
| `TomFormEnumListField` | abstract class | Abstract multi-select list of enum values. |
| `TomFormEnumRadioGroup` | class |  |
| `TomFormEnumSegmented` | class |  |
| `TomFormErrorBanner` | class | Material-style banner that displays form-level (cross-field) errors. |
| `TomFormEvent` | class | Base class for all form-related events. |
| `TomFormEventListener` | mixin | Mixin with default no-op handlers for each form event type. |
| `TomFormEventSource` | abstract class | Abstract event source for form events. |
| `TomFormFileDropzone` | class |  |
| `TomFormFileField` | abstract class |  |
| `TomFormFileThumbnail` | class | A file field that shows the file rather than describing it. |
| `TomFormFileUpload` | class |  |
| `TomFormInspector` | class | Convenience collector that buffers events for inspection. |
| `TomFormIntField` | abstract class | Abstract base for integer-typed form fields. |
| `TomFormIntFilterChips` | class |  |
| `TomFormIntInput` | class |  |
| `TomFormIntListField` | abstract class |  |
| `TomFormIntRangeField` | abstract class |  |
| `TomFormIntRangeSlider` | class |  |
| `TomFormIntSlider` | class |  |
| `TomFormIntStepper` | class |  |
| `TomFormLookupDialog` | class |  |
| `TomFormLookupField` | abstract class | Abstract base for modal-picker lookup fields. |
| `TomFormNDateInput` | class |  |
| `TomFormNDoubleInput` | class |  |
| `TomFormNEnumDropdown` | class |  |
| `TomFormNIntInput` | class |  |
| `TomFormNStringInput` | class |  |
| `TomFormNullableBoolCheckbox` | class | Renders the tristate boolean as a Material [Checkbox] inside the standard field anatomy. |
| `TomFormNullableBoolField` | abstract class | Abstract base for boolean fields that can hold the indeterminate state. |
| `TomFormObjectDropdown` | class |  |
| `TomFormObjectField` | abstract class | Abstract base for single-value domain-object selection. |
| `TomFormObjectFilterChips` | class |  |
| `TomFormObjectListField` | abstract class | Abstract multi-select list of domain objects. |
| `TomFormPercentDoubleInput` | class |  |
| `TomFormSavedEvent` | class | Fired when a form saves successfully. |
| `TomFormSearchField` | abstract class | Abstract base for search-style single-pick fields. |
| `TomFormSearchInput` | class |  |
| `TomFormStringChoiceChips` | class |  |
| `TomFormStringDropdown` | class | A concrete dropdown selection field that renders as a [DropdownButtonFormField] wrapped with [TomDropdownDecorationMixin] anatomy. |
| `TomFormStringField` | abstract class | Abstract base for all string-typed form fields. |
| `TomFormStringFilterChips` | class |  |
| `TomFormStringInput` | class | A concrete text-input field that renders as a plain [TextField] wrapped with [TomStringInputDecorationMixin] anatomy (label, error, description). |
| `TomFormStringListField` | abstract class | Abstract base for multi-select string form fields. |
| `TomFormStringMultiCheckbox` | class |  |
| `TomFormStringRadioGroup` | class |  |
| `TomFormStringSegmented` | class |  |
| `TomFormStyle` | class | The umbrella style class — one instance per [TomFormStyleScope]. |
| `TomFormStyleScope` | class | Provides a [TomFormStyle] plus the current available width to descendant fields via an `InheritedWidget`, and optionally wraps its [child] in a [Theme] derived from a [ThemeData] / [TomThemeSpec] / resources. |
| `TomFormTimeField` | abstract class |  |
| `TomFormTimePicker` | class |  |
| `TomFormTimeRangeField` | abstract class |  |
| `TomFormTimeTextInput` | class |  |
| `TomFormValidatedEvent` | class | Fired when a form completes validation. |
| `TomFormValidationError` | class | A cross-field validation error produced by [TomForm.validateForm]. |
| `TomGenericFieldDecorationMixin` | mixin | Decoration mixin for non-text-input fields (checkboxes, switches, segmented buttons, chips, radio groups, etc.). |
| `TomInlineListForm` | class | Renders a [TomListForm] as a vertically stacked sequence of inline per-row sub-forms — each row is its row's [TForm] rendered in place (no master-detail split, no expansion/collapse). |
| `TomLabelPlacement` | enum | Controls where the label appears relative to the field input. |
| `TomListForm` | class | Container that manages an ordered collection of sub-forms — one per list element of the bound business object. |
| `TomListFormToolbar` | class | Compact action bar with the standard list-form mutations: **Add**, **Remove**, **Move up**, **Move down**. |
| `TomListItemAddedEvent` | class | Fired when a sub-form is appended or inserted into a [TomListForm]. |
| `TomListItemRemovedEvent` | class | Fired when a sub-form is removed from a [TomListForm]. |
| `TomListItemReorderedEvent` | class | Fired when an existing sub-form is moved within a [TomListForm]. |
| `TomListRowMoveButtons` | class | A pair of *Move up* / *Move down* buttons bound to row [index] of a [TomListForm]. |
| `TomMasterDetailListForm` | class | Two-pane master-detail layout that consumes a [TomListForm] directly — no separate "detail form" instance is needed. |
| `TomMultiObservableBuilder` | class | A widget that observes one or more [TomObservable] instances and rebuilds when any of them change. |
| `TomMultilineInputStyle` | class | Partial override for multiline-input fields. |
| `TomMutableSelectableSource` | class | A [TomSelectableSource] whose item set can be replaced at runtime. |
| `TomNumRange` | class | A simple `(low, high)` pair used as the value type for the range slider fields. |
| `TomPickedFile` | class | What a platform picker returned, in the shape every picker package uses. |
| `TomPlatformFilePicker` | typedef | An adaptor over a platform picker, returning what the user chose. |
| `TomRadioGroupStyle` | class | Partial override for radio-group fields. |
| `TomReorderHandle` | class | A standard drag handle for reordering rows in a [ReorderableListView]. |
| `TomRequiredIndicator` | enum | Controls how the required indicator is displayed. |
| `TomRowErrorStrip` | class |  |
| `TomRowMoveButtonsPosition` | enum | Where to attach the per-row Move-up / Move-down buttons that [TomInlineListForm] auto-prepends or auto-appends when [TomInlineListForm.showRowMoveButtons] is `true`. |
| `TomSegmentedStyle` | class | Partial override for segmented-button fields. |
| `TomSelectableItem` | class | A single item that can be selected from a [TomSelectableSource]. |
| `TomSelectableSource` | abstract class | Abstract source of selectable items for selection-based form fields. |
| `TomSliderStyle` | class | Partial override for slider fields. |
| `TomSlowValidator` | class | Wraps a validator to mark it as "slow" (e.g., remote API call). |
| `TomStaticSelectableSource` | class | A [TomSelectableSource] backed by a fixed list of items. |
| `TomStringInputDecorationMixin` | mixin | Decoration mixin for string-input fields. |
| `TomStringInputStyle` | class | Partial override for text-input fields. |
| `TomStringInputVariant` | enum | Variant flavor for text-input decoration. |
| `TomSwitchStyle` | class | Partial override for switch fields. |
| `TomThemeSpec` | class | A tiny, serialisable view of [ThemeData] covering the ~90% of theme-setup apps actually configure at their root: colour-scheme seed, brightness, font family, base size, weights, and visual density. |
| `TomTimeOfDayRange` | class | A `(start, end)` pair of [TimeOfDay] values, used as the value type for time-range fields. |
| `TomTimePickerStyle` | class | Partial override for time-picker fields. |
| `TomTransferKind` | enum | What kind of transfer the controller last ran. |
| `TomTransferPhase` | enum | Where a transfer has got to. |
| `TomUnsavedChangesChoice` | enum | Result of an unsaved-changes prompt. |
| `TomUnsavedChangesGuard` | class | Wraps a subtree with a [PopScope] that defers route pops while [form] is dirty. |
| `TomValidationError` | class | Indicates the field value is invalid. |
| `TomValidationPending` | class | Indicates that an async validation is in progress. |
| `TomValidationPristine` | class | Initial state of every field before the user has interacted with it. |
| `TomValidationResult` | sealed class | Result of validating a field value. |
| `TomValidationSuccess` | class | Indicates the field value is valid. |
| `TomValidator` | typedef | A function that validates a value of type [T]. |
| `TomValidatorFactory` | typedef | Produces a [TomValidator] from the argument list parsed out of a resource declaration (C-11). |
| `TomValidatorRegistry` | class | Resolves **named validators** declared in a field's resource bundle into concrete [TomValidator] instances (C-11). |
| `TomValidators` | class | Built-in validators for common field validation scenarios. |
| `applyBorderRadius` | function | Returns [border] with its [BorderRadius] replaced by [radius], when the border is one of Flutter's built-in rounded input-border types. |
| `applyBorderWidth` | function | Returns [border] with its stroke width replaced by [width]. |
| `applyErrorVisuals` | function | Applies style-driven decoration add-ons to an [InputDecoration] — the fixed leading / trailing slots and (if the field is in error) the error border switch + trailing error icon. |
| `buildFieldAnatomy` | function | Builds the field's anatomy column around [innerWidget] using the fully-resolved [style] for the current width. |
| `composeCupertinoLeading` | function | Composes [CupertinoTextField.prefix] with [TomFieldStyle.leadingWidget]. |
| `composeCupertinoTrailing` | function | Mirror of [composeCupertinoLeading] for the trailing slot. |
| `composeHintStyle` | function | Composes the effective hint [TextStyle] by layering [TomFieldStyle.hintFontWeight] and [TomFieldStyle.hintOpacity] on top of [TomFieldStyle.hintStyle]. |
| `cupertinoFieldDecoration` | function | Tiny helper that resolves the ambient `CupertinoThemeData` and returns a `BoxDecoration` suitable for Cupertino field surfaces — honouring [TomFieldStyle.borderRadius] and the field's auth-state background hint. |
| `fieldHasRequiredValidator` | function | True when [validators] contains the canonical Required validator. |
| `guardUnsavedChanges` | function | Prompts the user to save / discard / cancel when [form] is dirty, then performs [action] only if the choice doesn't abort. |
| `isColorSchemeToken` | function | Returns true when [raw] looks like a `cs.*` color-scheme token. |
| `requiredIndicatorSuffixFor` | function | Text suffix for the required indicator in plain-text slots such as `InputDecoration.labelText` or `hintText`. |
| `resolveAnyColor` | function | Resolves [raw] using [cs] if it is a `cs.*` token, otherwise delegates to [fallback] (e.g. |
| `resolveColorSchemeToken` | function | Resolves a `cs.*` token string to a concrete [Color] from the supplied [ColorScheme]. |
| `resolveFieldValidationMessage` | function | Resolves a validation-error message through the TomCtr resource chain. |
| `resolveFormValidationMessage` | function | Resolves a form-level [TomFormValidationError] to the text a user reads. |
| `tomFileIsRenderableImage` | function | Whether [ref] names a file [TomFormFileThumbnail] can paint inline. |
| `tomHumanFileSize` | function | A human-readable rendering of a byte count. |
| `tomTransferErrorMessage` | function | A user-facing message for a failed transfer. |

### Groups (`lib/src/groups/`)

Summary: [api_summary_groups.md](api_summary_groups.md)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomAuthGate` | class | Applies Tom authorization to a subtree that cannot apply it itself. |
| `TomWidgetMixin` | mixin | Mixin for Tom widgets that extend Flutter widgets directly. |
| `TomGroupMemberElement` | mixin | Keeps the element's widget registered with its [TomAuthorizable.tomGroup] for exactly as long as the element is active. |
| `TomParentDataGroupMemberElement` | class | The element of a parent-data Tom widget (`TomExpanded`, `TomFlexible`): a [ParentDataElement] that keeps its widget's group membership — see [TomGroupMemberElement]. |
| `TomStatefulGroupMemberElement` | class | The element of a stateful Tom widget: a [StatefulElement] that keeps its widget's group membership — see [TomGroupMemberElement]. |
| `TomStatelessGroupMemberElement` | class | The element of a stateless Tom widget: a [StatelessElement] that keeps its widget's group membership — see [TomGroupMemberElement]. |

### Resource Auth (`lib/src/resource_auth/`)

Summary: [api_summary_resource_auth.md](api_summary_resource_auth.md)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomAllColorsAdapter` | class | Default adapter using all generated Flutter colors (Material + Cupertino). |
| `TomAllIconsAdapter` | class | Default adapter using all generated Flutter icons (Material + Cupertino). |
| `TomConfigEnvironment` | enum | Application deployment environment. |
| `TomConfigPlatform` | enum | Application target platform (logical, not physical). |
| `TomConfigProvider` | class | Global configuration provider for environment and platform behavior. |
| `TomCupertinoOnlyColorAdapter` | class | Adapter that only includes Cupertino colors. |
| `TomCupertinoOnlyIconAdapter` | class | Adapter that only includes Cupertino icons. |
| `TomMaterialOnlyColorAdapter` | class | Adapter that only includes Material colors. |
| `TomMaterialOnlyIconAdapter` | class | Adapter that only includes Material icons. |
| `TomUIColorAdapter` | abstract class | Adapter that resolves colors by name. |
| `TomUIColors` | class | Global color provider singleton. |
| `TomUIIconAdapter` | abstract class | Adapter that resolves icons by name. |
| `TomUIIcons` | class | Global icon provider singleton. |

### Theme (`lib/src/theme/`)

Summary: [api_summary_theme.md](api_summary_theme.md)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomButtonVariants` | class | Convenience factories that produce standard [ButtonStyle] objects for semantic action variants (primary, secondary, destructive, auxiliary). |
| `TomStateStyle` | class | Controls the visual treatment of a non-interactive authorization state. |
| `TomTheme` | class | Tom-specific theme extensions that layer on top of Flutter's [ThemeData]. |
| `TomThemeScope` | class | Provides a [TomTheme] to descendant widgets. |

### Widget Base (`lib/src/widget_base/`)

Summary: [api_summary_widget_base.md](api_summary_widget_base.md)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomAnimatedBase` | abstract class | Base for the Animated family (implicit animations). |
| `TomAuthLayers` | class | Composes the authorization layers into one effective [TomAuthState]. |
| `TomBuilderBase` | abstract class | Base for the Builder family (stream, future, value listenable builders). |
| `TomButtonBase` | abstract class | Base for the Button family. |
| `TomChipBase` | abstract class | Base for the Chip family (filter, choice, action chips). |
| `TomContainerBase` | abstract class | Base for the Container family (structural wrapper widgets). |
| `TomCtr` | class | Single entry point for all resource resolution in Tom UI. |
| `TomDialogBase` | abstract class | Base for the Dialog family. |
| `TomEffectBase` | abstract class | Base for the Effect family (visual effects, filters, backdrops). |
| `TomFamilyBase` | abstract class | Base class for every Tom widget that belongs to a widget family. |
| `TomImageBase` | abstract class | Base for the Image family (icons, avatars, images). |
| `TomInputBase` | abstract class | Base for the Input family (single-line text inputs). |
| `TomInteractionBase` | abstract class | Base for the Interaction family (gesture detectors, drag targets). |
| `TomLabelBase` | abstract class | Base for the Label family (text, rich text, selectable text). |
| `TomListBase` | abstract class | Base for the List family (list views, list tiles). |
| `TomNavigationBase` | abstract class | Base for the Navigation family (tab bars, drawers, rails). |
| `TomNodeBase` | abstract class | Base class for all Tom UI elements (widgets, actions, containers). |
| `TomPolicyNodeBase` | abstract class | Authorization enforcement layer for Tom UI elements. |
| `TomProgressBase` | abstract class | Base for the Progress family (indicators, spinners). |
| `TomScopePath` | class | Builds canonical resource paths from a [TomScope] and a widget id. |
| `TomScreenElementsProvider` | abstract interface class | Interface for screen element providers. |
| `TomScreenElementsProviderBase` | class | Base class for screen element providers that is itself a [TomScope]. |
| `TomSelectBase` | abstract class | Base for the Select family (dropdowns, popup menus). |
| `TomSliderBase` | abstract class | Base for the Slider family. |
| `TomSliverBase` | abstract class | Base for the Sliver family (sliver-based scrolling widgets). |
| `TomState` | abstract class | A [State] subclass that re-enters the widget's construction-time scope during [build]. |
| `TomStatefulWidget` | abstract class | A [StatefulWidget] that captures the [TomScope] at construction time and makes it available to its [TomState]. |
| `TomStatelessWidget` | abstract class | A [StatelessWidget] that captures the [TomScope] at construction time and re-enters it during [build]. |
| `TomStyleResolvers` | class | Complex style resolution helpers for Tom UI widgets. |
| `TomTableBase` | abstract class | Base for the Table family (data tables, paginated tables). |
| `TomToggleBase` | abstract class | Base for the Toggle family (switches, checkboxes, radios). |
| `TomTreeBase` | abstract class | Base for the Tree family (tree views). |
| `TomWidgetSurface` | abstract interface class | The surface every Tom widget adds on top of the Flutter widget it wraps. |

### Widgets (`lib/src/widgets/`)

Summary: [api_summary_widgets.md](api_summary_widgets.md)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomAboutDialog` | class | Tom wrapper for [AboutDialog]. |
| `TomAboutListTile` | class | Tom wrapper for [AboutListTile]. |
| `TomAbsorbPointer` | class | Tom wrapper for [AbsorbPointer]. |
| `TomAclBuilder` | class | A delegating wrapper around [AclBuilder] that adds Tom UI concerns: - **Element provider** — typed access to screen elements via `(T p) => p.field`. |
| `TomActionChip` | class | Tom wrapper for [ActionChip]. |
| `TomAlertDialog` | class | Tom wrapper for [AlertDialog]. |
| `TomAlign` | class | Tom wrapper for [Align]. |
| `TomAnimatedAlign` | class | Tom wrapper for [AnimatedAlign]. |
| `TomAnimatedBuilder` | class | Tom wrapper for [AnimatedBuilder]. |
| `TomAnimatedContainer` | class | Tom wrapper for [AnimatedContainer]. |
| `TomAnimatedCrossFade` | class | Tom wrapper for [AnimatedCrossFade]. |
| `TomAnimatedDefaultTextStyle` | class | Tom wrapper for [AnimatedDefaultTextStyle]. |
| `TomAnimatedFractionallySizedBox` | class | Tom wrapper for [AnimatedFractionallySizedBox]. |
| `TomAnimatedIcon` | class | Tom wrapper for [AnimatedIcon]. |
| `TomAnimatedList` | class | Tom wrapper for [AnimatedList]. |
| `TomAnimatedOpacity` | class | Tom wrapper for [AnimatedOpacity]. |
| `TomAnimatedPadding` | class | Tom wrapper for [AnimatedPadding]. |
| `TomAnimatedPhysicalModel` | class | Tom wrapper for [AnimatedPhysicalModel]. |
| `TomAnimatedPositioned` | class | Tom wrapper for [AnimatedPositioned] with construction-time resource resolution. |
| `TomAnimatedPositionedDirectional` | class | Tom wrapper for [AnimatedPositionedDirectional] with construction-time resource resolution. |
| `TomAnimatedRotation` | class | Tom wrapper for [AnimatedRotation]. |
| `TomAnimatedScale` | class | Tom wrapper for [AnimatedScale]. |
| `TomAnimatedSize` | class | Tom wrapper for [AnimatedSize]. |
| `TomAnimatedSlide` | class | Tom wrapper for [AnimatedSlide]. |
| `TomAnimatedSwitcher` | class | Tom wrapper for [AnimatedSwitcher]. |
| `TomAppBar` | class | Tom wrapper for [AppBar]. |
| `TomAspectRatio` | class | Tom wrapper for [AspectRatio]. |
| `TomAssetImage` | class | Tom wrapper for [Image] that uses [AssetImage] as its provider. |
| `TomAutocomplete` | class | Tom wrapper for [Autocomplete]. |
| `TomBackButton` | class | Tom wrapper for [BackButton]. |
| `TomBackdropFilter` | class | Tom wrapper for [BackdropFilter]. |
| `TomBadge` | class | Tom wrapper for [Badge]. |
| `TomBanner` | class | Tom wrapper for [Banner]. |
| `TomBaseline` | class | Tom wrapper for [Baseline]. |
| `TomBottomAppBar` | class | Tom wrapper for [BottomAppBar]. |
| `TomBottomNavigationBar` | class | Tom wrapper for [BottomNavigationBar]. |
| `TomBottomSheet` | class | Tom wrapper for [BottomSheet]. |
| `TomBreadcrumb` | class | Tom wrapper for a custom Breadcrumb navigation widget. |
| `TomCalendarDatePicker` | class | Tom wrapper for [CalendarDatePicker]. |
| `TomCard` | class | Tom wrapper for [Card]. |
| `TomCarouselView` | class | Tom wrapper for [CarouselView]. |
| `TomCenter` | class | Tom wrapper for [Center]. |
| `TomCheckbox` | class | Tom wrapper for [Checkbox]. |
| `TomCheckboxListTile` | class | Tom wrapper for [CheckboxListTile]. |
| `TomCheckboxMenuButton` | class | Tom wrapper for [CheckboxMenuButton]. |
| `TomCheckedPopupMenuItem` | class | Tom widget that EXTENDS [CheckedPopupMenuItem] with authorization. |
| `TomChip` | class | Tom wrapper for [Chip] (as label display). |
| `TomChoiceChip` | class | Tom wrapper for [ChoiceChip]. |
| `TomCircleAvatar` | class | Tom wrapper for [CircleAvatar]. |
| `TomCircularProgressIndicator` | class | Tom wrapper for [CircularProgressIndicator]. |
| `TomClipOval` | class | Tom wrapper for [ClipOval]. |
| `TomClipPath` | class | Tom wrapper for [ClipPath]. |
| `TomClipRRect` | class | Tom wrapper for [ClipRRect]. |
| `TomClipRSuperellipse` | class | Tom wrapper for [ClipRSuperellipse]. |
| `TomClipRect` | class | Tom wrapper for [ClipRect]. |
| `TomCloseButton` | class | Tom wrapper for [CloseButton]. |
| `TomColorFiltered` | class | Tom wrapper for [ColorFiltered]. |
| `TomColoredBox` | class | Tom wrapper for [ColoredBox]. |
| `TomColumn` | class | Tom wrapper for [Column]. |
| `TomConstrainedBox` | class | Tom wrapper for [ConstrainedBox]. |
| `TomConstraintsTransformBox` | class | Tom wrapper for [ConstraintsTransformBox]. |
| `TomContainer` | class | Tom wrapper for [Container]. |
| `TomCupertinoActionSheet` | class | Tom wrapper for [CupertinoActionSheet]. |
| `TomCupertinoActionSheetAction` | class | Tom wrapper for [CupertinoActionSheetAction]. |
| `TomCupertinoActivityIndicator` | class | Tom wrapper for [CupertinoActivityIndicator]. |
| `TomCupertinoAlertDialog` | class | Tom wrapper for [CupertinoAlertDialog]. |
| `TomCupertinoButton` | class | Tom wrapper for [CupertinoButton]. |
| `TomCupertinoCheckbox` | class | Tom wrapper for [CupertinoCheckbox]. |
| `TomCupertinoContextMenu` | class | Tom wrapper for [CupertinoContextMenu]. |
| `TomCupertinoContextMenuAction` | class | Tom wrapper for [CupertinoContextMenuAction]. |
| `TomCupertinoDatePicker` | class | Tom wrapper for [CupertinoDatePicker]. |
| `TomCupertinoDialogAction` | class | Tom wrapper for [CupertinoDialogAction]. |
| `TomCupertinoExpansionTile` | class | Tom wrapper for [CupertinoExpansionTile]. |
| `TomCupertinoFormRow` | class | Tom wrapper for [CupertinoFormRow]. |
| `TomCupertinoFormSection` | class | Tom wrapper for [CupertinoFormSection]. |
| `TomCupertinoLinearActivityIndicator` | class | Tom wrapper for [CupertinoActivityIndicator.partiallyRevealed]. |
| `TomCupertinoListSection` | class | Tom wrapper for [CupertinoListSection]. |
| `TomCupertinoListTile` | class | Tom wrapper for [CupertinoListTile]. |
| `TomCupertinoNavigationBar` | class | Tom wrapper for [CupertinoNavigationBar]. |
| `TomCupertinoNavigationBarBackButton` | class | Tom wrapper for [CupertinoNavigationBarBackButton]. |
| `TomCupertinoPageScaffold` | class | Tom wrapper for [CupertinoPageScaffold]. |
| `TomCupertinoPicker` | class | Tom wrapper for [CupertinoPicker]. |
| `TomCupertinoRadio` | class | Tom wrapper for [CupertinoRadio]. |
| `TomCupertinoScrollbar` | class | Tom wrapper for [CupertinoScrollbar]. |
| `TomCupertinoSearchTextField` | class | Tom wrapper for [CupertinoSearchTextField]. |
| `TomCupertinoSegmentedControl` | class | Tom wrapper for [CupertinoSegmentedControl]. |
| `TomCupertinoSlider` | class | Tom wrapper for [CupertinoSlider]. |
| `TomCupertinoSlidingSegmentedControl` | class | Tom wrapper for [CupertinoSlidingSegmentedControl]. |
| `TomCupertinoSliverNavigationBar` | class | Tom wrapper for [CupertinoSliverNavigationBar]. |
| `TomCupertinoSliverRefreshControl` | class | Tom wrapper for [CupertinoSliverRefreshControl]. |
| `TomCupertinoSwitch` | class | Tom wrapper for [CupertinoSwitch]. |
| `TomCupertinoTabBar` | class | Tom wrapper for [CupertinoTabBar]. |
| `TomCupertinoTabScaffold` | class | Tom wrapper for [CupertinoTabScaffold]. |
| `TomCupertinoTabView` | class | Tom wrapper for [CupertinoTabView] (extension pattern). |
| `TomCupertinoTextField` | class | Tom wrapper for [CupertinoTextField]. |
| `TomCupertinoTextFormFieldRow` | class | Tom wrapper for [CupertinoTextFormFieldRow]. |
| `TomCupertinoTimerPicker` | class | Tom wrapper for [CupertinoTimerPicker]. |
| `TomCustomMultiChildLayout` | class | Tom wrapper for [CustomMultiChildLayout]. |
| `TomCustomPaint` | class | Tom wrapper for [CustomPaint]. |
| `TomCustomScrollView` | class | Tom wrapper for [CustomScrollView]. |
| `TomCustomSingleChildLayout` | class | Tom wrapper for [CustomSingleChildLayout]. |
| `TomDataCell` | class | Tom extension of [DataCell] with built-in authorization and resource resolution. |
| `TomDataColumn` | class | Tom extension of [DataColumn] with built-in authorization and resource resolution. |
| `TomDataRow` | class | Tom extension of [DataRow] with built-in authorization. |
| `TomDataTable` | class | Tom wrapper for [DataTable]. |
| `TomDatePickerDialog` | class | Tom wrapper for [DatePickerDialog]. |
| `TomDateRangePickerDialog` | class | Tom wrapper for [DateRangePickerDialog]. |
| `TomDecoratedBox` | class | Tom wrapper for [DecoratedBox]. |
| `TomDecoratedSliver` | class | Tom wrapper for [DecoratedSliver]. |
| `TomDefaultTextStyle` | class | Tom wrapper for [DefaultTextStyle]. |
| `TomDialog` | class | Tom wrapper for [Dialog]. |
| `TomDialogs` | class | Tom-prefixed static wrappers for Flutter's function-based dialog APIs. |
| `TomDismissible` | class | Tom wrapper for [Dismissible]. |
| `TomDivider` | class | Tom wrapper for [Divider]. |
| `TomDragTarget` | class | Tom wrapper for [DragTarget]. |
| `TomDraggable` | class | Tom wrapper for [Draggable]. |
| `TomDraggableScrollableSheet` | class | Tom wrapper for [DraggableScrollableSheet]. |
| `TomDrawer` | class | Tom wrapper for [Drawer]. |
| `TomDrawerHeader` | class | Tom wrapper for [DrawerHeader]. |
| `TomDropdownButton` | class | Tom wrapper for [DropdownButton]. |
| `TomDropdownButtonFormField` | class | Tom wrapper for [DropdownButtonFormField]. |
| `TomDropdownMenu` | class | Tom wrapper for [DropdownMenu]. |
| `TomDropdownMenuEntry` | class | Tom wrapper for [DropdownMenuEntry] used as an action button. |
| `TomDropdownMenuFormField` | class | Tom wrapper for [DropdownMenuFormField]. |
| `TomDropdownMenuItem` | class | Tom widget that EXTENDS [DropdownMenuItem] with authorization. |
| `TomEditableText` | class | Tom wrapper for [EditableText]. |
| `TomElevatedButton` | class | Tom wrapper for [ElevatedButton]. |
| `TomExpandIcon` | class | Tom wrapper for [ExpandIcon]. |
| `TomExpanded` | class | Tom widget that EXTENDS [Expanded] with authorization and resource resolution. |
| `TomExpansionPanel` | class | Tom equivalent for [ExpansionPanel] (non-widget data class). |
| `TomExpansionPanelList` | class | Tom wrapper for [ExpansionPanelList]. |
| `TomExpansionTile` | class | Tom wrapper for [ExpansionTile]. |
| `TomFadeInImage` | class | Tom wrapper for [FadeInImage]. |
| `TomFadeTransition` | class | Tom wrapper for [FadeTransition]. |
| `TomFileImage` | class | Tom wrapper for [Image] that uses [FileImage] as its provider. |
| `TomFilledButton` | class | Tom wrapper for [FilledButton]. |
| `TomFilterChip` | class | Tom wrapper for [FilterChip]. |
| `TomFittedBox` | class | Tom wrapper for [FittedBox]. |
| `TomFlexible` | class | Tom widget that EXTENDS [Flexible] with authorization and resource resolution. |
| `TomFlexibleSpaceBar` | class | Tom wrapper for [FlexibleSpaceBar]. |
| `TomFloatingActionButton` | class | Tom wrapper for [FloatingActionButton]. |
| `TomFlow` | class | Tom wrapper for [Flow]. |
| `TomFormClassic` | class | Tom wrapper for [Form]. |
| `TomFractionalTranslation` | class | Tom wrapper for [FractionalTranslation]. |
| `TomFractionallySizedBox` | class | Tom wrapper for [FractionallySizedBox]. |
| `TomFutureBuilder` | class | Tom-aware wrapper for [FutureBuilder]. |
| `TomGestureDetector` | class | Tom wrapper for [GestureDetector]. |
| `TomGridTile` | class | Tom wrapper for [GridTile]. |
| `TomGridTileBar` | class | Tom wrapper for [GridTileBar]. |
| `TomGridView` | class | Tom wrapper for [GridView]. |
| `TomHero` | class | Tom wrapper for [Hero]. |
| `TomIcon` | class | Tom wrapper for [Icon]. |
| `TomIconButton` | class | Tom wrapper for [IconButton]. |
| `TomIgnorePointer` | class | Tom wrapper for [IgnorePointer]. |
| `TomImage` | class | Tom wrapper for [Image]. |
| `TomImageFiltered` | class | Tom wrapper for [ImageFiltered]. |
| `TomImageIcon` | class | Tom wrapper for [ImageIcon]. |
| `TomIndexedStack` | class | Tom wrapper for [IndexedStack]. |
| `TomInk` | class | Tom wrapper for [Ink]. |
| `TomInkImage` | class | Tom wrapper for [Ink.image]. |
| `TomInkResponse` | class | Tom wrapper for [InkResponse]. |
| `TomInkWell` | class | Tom wrapper for [InkWell]. |
| `TomInputChip` | class | Tom wrapper for [InputChip]. |
| `TomInputDatePickerFormField` | class | Tom wrapper for [InputDatePickerFormField]. |
| `TomInteractiveViewer` | class | Tom wrapper for [InteractiveViewer]. |
| `TomIntrinsicHeight` | class | Tom wrapper for [IntrinsicHeight]. |
| `TomIntrinsicWidth` | class | Tom wrapper for [IntrinsicWidth]. |
| `TomLayoutBuilder` | class | Tom-aware wrapper for [LayoutBuilder]. |
| `TomLicensePage` | class | Tom wrapper for [LicensePage]. |
| `TomLimitedBox` | class | Tom wrapper for [LimitedBox]. |
| `TomLinearProgressIndicator` | class | Tom wrapper for [LinearProgressIndicator]. |
| `TomListBody` | class | Tom wrapper for [ListBody]. |
| `TomListTile` | class | Tom wrapper for [ListTile] (as display label). |
| `TomListView` | class | Tom wrapper for [ListView]. |
| `TomListWheelScrollView` | class | Tom wrapper for [ListWheelScrollView]. |
| `TomListenableBuilder` | class | Tom-aware wrapper for [ListenableBuilder]. |
| `TomLongPressDraggable` | class | Tom wrapper for [LongPressDraggable]. |
| `TomMaterial` | class | Tom wrapper for [Material]. |
| `TomMaterialBanner` | class | Tom wrapper for [MaterialBanner]. |
| `TomMenuAcceleratorLabel` | class | Tom wrapper for [MenuAcceleratorLabel]. |
| `TomMenuAnchor` | class | Tom wrapper for [MenuAnchor]. |
| `TomMenuBar` | class | Tom wrapper for [MenuBar]. |
| `TomMenuItemButton` | class | Tom wrapper for [MenuItemButton]. |
| `TomMessenger` | abstract final class | Tom-native presenter for transient messages (snack bars). |
| `TomModalBottomSheet` | class | Tom wrapper for the material modal bottom sheet shown by [showModalBottomSheet]. |
| `TomMouseRegion` | class | Tom wrapper for [MouseRegion]. |
| `TomNavigationBar` | class | Tom wrapper for [NavigationBar]. |
| `TomNavigationDestination` | class | Tom widget that EXTENDS [NavigationDestination] with authorization and resources. |
| `TomNavigationDrawer` | class | Tom wrapper for [NavigationDrawer]. |
| `TomNavigationDrawerDestination` | class | Tom widget that EXTENDS [NavigationDrawerDestination] with authorization. |
| `TomNavigationRail` | class | Tom wrapper for [NavigationRail]. |
| `TomNestedScrollView` | class | Tom wrapper for [NestedScrollView]. |
| `TomNetworkImage` | class | Tom wrapper for [Image] that uses [NetworkImage] as its provider. |
| `TomOffstage` | class | Tom wrapper for [Offstage]. |
| `TomOpacity` | class | Tom wrapper for [Opacity]. |
| `TomOrientationBuilder` | class | Tom-aware wrapper for [OrientationBuilder]. |
| `TomOutlinedButton` | class | Tom wrapper for [OutlinedButton]. |
| `TomOverflowBar` | class | Tom wrapper for [OverflowBar]. |
| `TomOverflowBox` | class | Tom wrapper for [OverflowBox]. |
| `TomPadding` | class | Tom wrapper for [Padding]. |
| `TomPageRoute` | class | A [MaterialPageRoute] that propagates the active [TomScope] across navigation. |
| `TomPageView` | class | Tom wrapper for [PageView]. |
| `TomPaginatedDataTable` | class | Tom wrapper for [PaginatedDataTable]. |
| `TomPhysicalModel` | class | Tom wrapper for [PhysicalModel]. |
| `TomPhysicalShape` | class | Tom wrapper for [PhysicalShape]. |
| `TomPinnedHeaderSliver` | class | Tom wrapper for [PinnedHeaderSliver]. |
| `TomPopupMenuButton` | class | Tom wrapper for [PopupMenuButton]. |
| `TomPopupMenuDivider` | class | Tom widget that EXTENDS [PopupMenuDivider] with authorization. |
| `TomPopupMenuItem` | class | Tom widget that EXTENDS [PopupMenuItem] with authorization and resources. |
| `TomPositioned` | class | Tom wrapper for [Positioned] with authorization and resource resolution. |
| `TomPositionedDirectional` | class | Tom wrapper for [PositionedDirectional] with authorization and resource resolution. |
| `TomRadio` | class | Tom wrapper for [Radio]. |
| `TomRadioListTile` | class | Tom wrapper for [RadioListTile]. |
| `TomRadioMenuButton` | class | Tom wrapper for [RadioMenuButton]. |
| `TomRangeSlider` | class | Tom wrapper for [RangeSlider]. |
| `TomRawChip` | class | Tom wrapper for [RawChip]. |
| `TomRefreshIndicator` | class | Tom wrapper for [RefreshIndicator]. |
| `TomRefreshProgressIndicator` | class | Tom wrapper for [RefreshProgressIndicator] with construction-time resource resolution. |
| `TomReorderableList` | class | Tom wrapper for [ReorderableList]. |
| `TomReorderableListView` | class | Tom wrapper for [ReorderableListView]. |
| `TomRichText` | class | Tom wrapper for [RichText]. |
| `TomRotatedBox` | class | Tom wrapper for [RotatedBox]. |
| `TomRotationTransition` | class | Tom wrapper for [RotationTransition]. |
| `TomRow` | class | Tom wrapper for [Row]. |
| `TomSafeArea` | class | Tom wrapper for [SafeArea]. |
| `TomScaffold` | class | Tom wrapper for [Scaffold]. |
| `TomScaleTransition` | class | Tom wrapper for [ScaleTransition]. |
| `TomScrollbar` | class | Tom wrapper for [Scrollbar]. |
| `TomSearchAnchor` | class | Tom wrapper for [SearchAnchor]. |
| `TomSearchBar` | class | Tom wrapper for [SearchBar]. |
| `TomSegmentedButton` | class | Tom wrapper for [SegmentedButton]. |
| `TomSelectableRegion` | class | Tom wrapper for [SelectableRegion]. |
| `TomSelectableText` | class | Tom wrapper for [SelectableText]. |
| `TomSelectionArea` | class | Tom wrapper for [SelectionArea]. |
| `TomSensitiveContent` | class | Tom wrapper for [SensitiveContent]. |
| `TomShaderMask` | class | Tom wrapper for [ShaderMask]. |
| `TomSimpleDialog` | class | Tom wrapper for [SimpleDialog]. |
| `TomSimpleDialogOption` | class | Tom wrapper for [SimpleDialogOption]. |
| `TomSingleChildScrollView` | class | Tom wrapper for [SingleChildScrollView]. |
| `TomSizedBox` | class | Tom wrapper for [SizedBox]. |
| `TomSizedOverflowBox` | class | Tom wrapper for [SizedOverflowBox]. |
| `TomSlider` | class | Tom wrapper for [Slider]. |
| `TomSliverAppBar` | class | Tom wrapper for [SliverAppBar]. |
| `TomSliverConstrainedCrossAxis` | class | Tom wrapper for [SliverConstrainedCrossAxis]. |
| `TomSliverCrossAxisExpanded` | class | Tom wrapper for [SliverCrossAxisExpanded]. |
| `TomSliverCrossAxisGroup` | class | Tom wrapper for [SliverCrossAxisGroup]. |
| `TomSliverFillRemaining` | class | Tom wrapper for [SliverFillRemaining]. |
| `TomSliverFillViewport` | class | Tom wrapper for [SliverFillViewport]. |
| `TomSliverFixedExtentList` | class | Tom wrapper for [SliverFixedExtentList]. |
| `TomSliverFloatingHeader` | class | Tom wrapper for [SliverFloatingHeader]. |
| `TomSliverGrid` | class | Tom wrapper for [SliverGrid]. |
| `TomSliverList` | class | Tom wrapper for [SliverList]. |
| `TomSliverMainAxisGroup` | class | Tom wrapper for [SliverMainAxisGroup]. |
| `TomSliverOffstage` | class | Tom wrapper for [SliverOffstage]. |
| `TomSliverOpacity` | class | Tom wrapper for [SliverOpacity]. |
| `TomSliverPadding` | class | Tom wrapper for [SliverPadding]. |
| `TomSliverPersistentHeader` | class | Tom wrapper for [SliverPersistentHeader]. |
| `TomSliverPrototypeExtentList` | class | Tom wrapper for [SliverPrototypeExtentList]. |
| `TomSliverReorderableList` | class | Tom wrapper for [SliverReorderableList]. |
| `TomSliverResizingHeader` | class | Tom wrapper for [SliverResizingHeader]. |
| `TomSliverSafeArea` | class | Tom wrapper for [SliverSafeArea]. |
| `TomSliverToBoxAdapter` | class | Tom wrapper for [SliverToBoxAdapter]. |
| `TomSliverVariedExtentList` | class | Tom wrapper for [SliverVariedExtentList]. |
| `TomSliverVisibility` | class | Tom wrapper for [SliverVisibility]. |
| `TomSnackBar` | class | Tom wrapper for [SnackBar] with construction-time resource resolution. |
| `TomSnackBarAction` | class | Tom wrapper for [SnackBarAction] with construction-time resource resolution. |
| `TomSpacer` | class | Tom widget that EXTENDS [Spacer] with authorization. |
| `TomStack` | class | Tom wrapper for [Stack]. |
| `TomStatefulBuilder` | class | Tom-aware wrapper for [StatefulBuilder]. |
| `TomStepper` | class | Tom wrapper for [Stepper]. |
| `TomStreamBuilder` | class | Tom-aware wrapper for [StreamBuilder]. |
| `TomSubmenuButton` | class | Tom wrapper for [SubmenuButton]. |
| `TomSwitch` | class | Tom wrapper for [Switch]. |
| `TomSwitchListTile` | class | Tom wrapper for [SwitchListTile]. |
| `TomTab` | class | Tom widget that EXTENDS [Tab] with authorization and resources. |
| `TomTabBar` | class | Tom wrapper for [TabBar]. |
| `TomTabBarView` | class | Tom wrapper for [TabBarView]. |
| `TomTabPageSelector` | class | Tom wrapper for [TabPageSelector]. |
| `TomTable` | class | Tom wrapper for [Table]. |
| `TomTableCell` | class | Tom widget that EXTENDS [TableCell] with authorization and resource resolution. |
| `TomText` | class | Tom wrapper for [Text]. |
| `TomTextButton` | class | Tom wrapper for [TextButton]. |
| `TomTextField` | class | Tom wrapper for [TextField]. |
| `TomTextFormField` | class | Tom wrapper for [TextFormField]. |
| `TomTimePickerDialog` | class | Tom wrapper for [TimePickerDialog]. |
| `TomToggleButtons` | class | Tom wrapper for [ToggleButtons]. |
| `TomTooltip` | class | Tom wrapper for [Tooltip]. |
| `TomTransform` | class | Tom wrapper for [Transform]. |
| `TomTreeNode` | class | Data model for a tree node used by [TomTreeView]. |
| `TomTreeSliver` | class | Tom wrapper for [TreeSliver]. |
| `TomTreeView` | class | Tom custom TreeView widget. |
| `TomTweenAnimationBuilder` | class | Tom-aware wrapper for [TweenAnimationBuilder]. |
| `TomUnconstrainedBox` | class | Tom wrapper for [UnconstrainedBox]. |
| `TomUserAccountsDrawerHeader` | class | Tom wrapper for [UserAccountsDrawerHeader]. |
| `TomValueListenableBuilder` | class | Tom-aware wrapper for [ValueListenableBuilder]. |
| `TomVerticalDivider` | class | Tom wrapper for [VerticalDivider]. |
| `TomVisibility` | class | Tom wrapper for [Visibility]. |
| `TomWrap` | class | Tom wrapper for [Wrap]. |
| `TomYearPicker` | class | Tom wrapper for [YearPicker]. |

### Advanced Container Layout (`lib/src/advanced_container_layout/`)

Summary: [api_summary_advanced_container_layout.md](api_summary_advanced_container_layout.md)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `Acl` | class |  |
| `AclAxisPointX` | enum | Axis point on the X axis. |
| `AclAxisPointY` | enum | Axis point on the Y axis. |
| `AclBinaryVisibilityController` | class | Simple binary toggle controller for group visibility. |
| `AclBorderKind` | enum | Defines the visual shape of a container border. |
| `AclBorderStyle` | class |  |
| `AclBuilder` | class | Fluent builder for [Acl] layout containers. |
| `AclBuilderAlignment` | extension | Aligning components: a component inside its row, a component to one in another row or the same row, and a whole row within the container. |
| `AclBuilderChrome` | extension | The container's defaults and its chrome: default flags, gaps, row heights and alignments, the unauthorized-component policy, border, padding, background and title. |
| `AclBuilderIdentity` | extension | Naming and grouping: ids for the container, rows and components, the groups they belong to, and the controller that shows or hides groups. |
| `AclBuilderResponsive` | extension | Responding to the space available: alternative layouts, row breakpoints and inline component variants. |
| `AclBuilderSizing` | extension | Sizing a component and the container: the preferred, minimum and maximum size hints, sizes taken from another component, the growth shorthands, and the container's own size and scrolling. |
| `AclCallbackVisibilityController` | class | Callback-based controller that derives visibility from an external [ValueListenable]. |
| `AclComponent` | class | One appended widget of a layout: the child with its flags, gaps and sizes, as the builder recorded them. |
| `AclContainer` | class |  |
| `AclDensity` | enum | Visual density category for variant detection. |
| `AclDeviceContext` | class | Snapshot of the current device and layout environment used by [AclVariantDetector] to decide which inline variant is active. |
| `AclDirection` | enum | Layout direction for ACL containers: the order in which a row places its components along the horizontal axis. |
| `AclDirectionScope` | class | Provides an [AclDirection] to descendant [AclContainer] widgets. |
| `AclFlags` | class | Layout attribute flags for the components inside an `AclContainer`. |
| `AclFlowContainer` | class | A widget whose rows are **generated** from a flat child list by an [AclFlowKind] rule, then rendered through a composed [AclContainer]. |
| `AclFlowKind` | enum | The container kinds that flow a **flat** ordered child list into rows, rather than having the rows authored directly. |
| `AclFormFactor` | enum | Derived form factor for variant detection. |
| `AclGroupVisibilityController` | abstract class | Base class for controlling the visibility of a named group within an ACL container. |
| `AclGroupVisibilityMode` | enum | Controls whether a group of components is visible, hidden, or disabled. |
| `AclInputMode` | enum | Input mode for variant detection. |
| `AclLayout` | class |  |
| `AclRow` | class | One row of a layout: its components in order, and the row's alignment. |
| `AclRowAlignment` | enum | Alignment for rows in an AclContainer. |
| `AclRowBreakpoint` | class | A row breakpoint that splits a row after [splitAfter] components when the container's available width drops below [atWidth]. |
| `AclRowCrossAlignment` | enum | Per-component vertical placement within its row when [AclComponent.alignYToKey] is null. |
| `AclScope` | class | Provides ID and group metadata to widgets inside an ACL layout. |
| `AclSeparator` | class | Horizontal divider drawn inside a gap row. |
| `AclSeparatorAlignment` | enum |  |
| `AclSeparatorStyle` | enum |  |
| `AclTitleBorderAlign` | enum | Controls how the title label is vertically positioned relative to the border line of a titled [Acl] container. |
| `AclTitlePosition` | enum |  |
| `AclVariant` | class | A responsive layout variant that replaces the default row tree when the container's available width drops below [atWidth]. |
| `AclVariantDetector` | typedef | Determines whether an inline variant block should be active. |
| `aclEffectiveGapBefore` | function | Returns the effective gapBefore for [comp] inside [row] at the given [availableWidth], honouring the row's breakpointed default when the component did not carry an explicit distance. |
| `aclFlowItemWidth` | function | The width [aclWrapRows] uses when deciding whether [comp] still fits. |
| `aclGridRows` | function | Flows [components] into rows of [columns] equal-width cells. |
| `aclResolveBreakpointed` | function | Resolves a value carrying `(minWidth, value)` breakpoint overrides. |
| `aclResolveRowHeight` | function | Resolves a breakpointed row height. |
| `aclWrapRows` | function | Flows [components] into rows, breaking whenever the next component would overflow [availableWidth]. |
