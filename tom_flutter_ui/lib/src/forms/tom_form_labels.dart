/// The wording of the form widgets, as resource keys rather than literals.
///
/// The fields, the list toolbars and the error surfaces between them show a few
/// dozen short strings — "Cancel", "Choose…", "Open date picker", "Row has 3
/// validation errors:" — and every one of them is user-visible. Written inline
/// they are English forever: an application that localises its labels and its
/// validation messages still ships a translated form whose modal sheet has
/// English buttons, because the caption never had a key to translate.
///
/// So the strings live here, behind [TomFormLabels], resolved through [TomCtr]
/// with the built-in wording as the fallback, so a form with no resources
/// renders that wording — but every string *has* a key, which is the difference between "not
/// translated yet" and "not translatable".
///
/// This is the same façade `TomFileLabels` is for the file widgets, and the
/// division between them is by vocabulary rather than by widget: a caption that
/// only ever appears beside a file (`file.choose`, `file.uploading`) belongs
/// there, a caption any field might show (`form.cancel`, `form.done`) belongs
/// here.
///
/// ## Resolution order
///
/// Each label resolves scoped-then-global-then-literal, the same order
/// [TomField.resolvedErrorMessage] uses for validation messages:
///
///  1. `<basePath>.<key>` — this one field's override (the country picker says
///     "Pick a country" while every other picker says "Choose…").
///  2. `<key>` — the application-wide wording, set once. This tier is what
///     makes the shared captions worth centralising: `form.cancel` is written
///     once and every modal sheet in every field family follows it.
///  3. The built-in English, so an unconfigured application is never blank.
///
/// ## Keys
///
/// | Key | Default | Parameters |
/// | --- | --- | --- |
/// | `form.cancel` | `Cancel` | — |
/// | `form.done` | `Done` | — |
/// | `form.save` | `Save` | — |
/// | `form.discard` | `Discard` | — |
/// | `form.choose` | `Choose…` | — |
/// | `form.search` | `Search` | — |
/// | `form.searchHint` | `Search…` | — |
/// | `form.typeToSearch` | `Type to search…` | — |
/// | `form.filter` | `Filter…` | — |
/// | `form.lookupTitle` | `Lookup` | — |
/// | `form.nullDisplay` | `— null —` | — |
/// | `form.clearToNull` | `Clear (set to null)` | — |
/// | `form.rangeStart` | `Start` | — |
/// | `form.rangeEnd` | `End` | — |
/// | `form.openDatePicker` | `Open date picker` | — |
/// | `form.openTimePicker` | `Open time picker` | — |
/// | `form.openDateTimePicker` | `Open date + time picker` | — |
/// | `form.formatHint` | `Format: {pattern}` | `pattern` |
/// | `form.requiredSuffix` | ` (required)` | — |
/// | `form.errorBannerTitle` | `Form Errors` | — |
/// | `form.rowErrorsOne` | `Row has 1 validation error:` | — |
/// | `form.rowErrorsMany` | `Row has {count} validation errors:` | `count` |
/// | `form.masterDetailEmpty` | `Select an item from the list to edit it.` | — |
/// | `form.unsavedTitle` | `Unsaved changes` | — |
/// | `form.unsavedMessage` | `You have unsaved edits. What would you like to do?` | — |
///
/// Three near-identical search captions have three keys rather than one
/// (`form.search`, `form.searchHint`, `form.typeToSearch`) because the widgets
/// that show them word them differently — a bare `Search` on a Cupertino search
/// field, an elliptical `Search…` on its lookup sheet, an instructional `Type
/// to search…` on the Material autocomplete. Collapsing them to one key would
/// pick a winner among three deliberate wordings; keeping them separate lets an
/// application collapse them itself by giving all three the same text.
///
/// The one-error and many-errors row captions are split instead of
/// interpolating a count into one template, for the reason `TomFileLabels`
/// splits its progress captions: a language whose plural rule differs from
/// English cannot be served by a single string with a number in it.
///
/// Captions that already carry a key of their own are *not* routed through
/// here. A list toolbar's "Add" resolves under `<listPath>.add.label` and a
/// reorder handle's tooltip under `<handlePath>.tooltip`, because those are
/// per-instance affordances whose wording differs between two lists on the same
/// page — a global tier would be the wrong default for them.
library;

import '../widget_base/tom_construction_helpers.dart';

/// The user-visible strings of the form widgets.
///
/// Every method takes the field's `basePath` so a single field can override a
/// word without the application changing it everywhere; pass `null` when there
/// is no field in view (a modal sheet opened stand-alone) and resolution starts
/// at the global key.
abstract final class TomFormLabels {
  /// The dismiss-without-applying affordance on a modal picker sheet.
  static String cancel(String? basePath) =>
      _text(basePath, 'form.cancel', 'Cancel');

  /// The apply-and-close affordance on a modal picker sheet.
  static String done(String? basePath) => _text(basePath, 'form.done', 'Done');

  /// The save affordance on the unsaved-changes prompt.
  static String save(String? basePath) => _text(basePath, 'form.save', 'Save');

  /// The discard affordance on the unsaved-changes prompt.
  static String discard(String? basePath) =>
      _text(basePath, 'form.discard', 'Discard');

  /// The placeholder shown by a picker field with nothing selected.
  static String choose(String? basePath) =>
      _text(basePath, 'form.choose', 'Choose…');

  /// The placeholder on a plain search input.
  static String search(String? basePath) =>
      _text(basePath, 'form.search', 'Search');

  /// The placeholder on a lookup field's search input.
  static String searchHint(String? basePath) =>
      _text(basePath, 'form.searchHint', 'Search…');

  /// The hint on an autocomplete that has not been typed into yet.
  static String typeToSearch(String? basePath) =>
      _text(basePath, 'form.typeToSearch', 'Type to search…');

  /// The placeholder on the filter box inside a lookup sheet or dialog.
  static String filter(String? basePath) =>
      _text(basePath, 'form.filter', 'Filter…');

  /// The heading of a lookup sheet or dialog with no title of its own.
  static String lookupTitle(String? basePath) =>
      _text(basePath, 'form.lookupTitle', 'Lookup');

  /// The sentinel rendered in place of a `null` value.
  ///
  /// This is the last tier of the nullable fields' own resolution — an explicit
  /// override and a field-scoped `nullDisplay` resource are consulted first —
  /// so it is reached only by a field that has said nothing about how it wants
  /// its emptiness shown.
  static String nullDisplay(String? basePath) =>
      _text(basePath, 'form.nullDisplay', '— null —');

  /// The tooltip on a nullable field's clear button.
  static String clearToNull(String? basePath) =>
      _text(basePath, 'form.clearToNull', 'Clear (set to null)');

  /// The caption over the lower bound of a range picker.
  static String rangeStart(String? basePath) =>
      _text(basePath, 'form.rangeStart', 'Start');

  /// The caption over the upper bound of a range picker.
  static String rangeEnd(String? basePath) =>
      _text(basePath, 'form.rangeEnd', 'End');

  /// The tooltip on a date field's picker button.
  static String openDatePicker(String? basePath) =>
      _text(basePath, 'form.openDatePicker', 'Open date picker');

  /// The tooltip on a time field's picker button.
  static String openTimePicker(String? basePath) =>
      _text(basePath, 'form.openTimePicker', 'Open time picker');

  /// The tooltip on a date-and-time field's picker button.
  static String openDateTimePicker(String? basePath) =>
      _text(basePath, 'form.openDateTimePicker', 'Open date + time picker');

  /// The message shown when typed text does not match the expected [pattern].
  static String formatHint(String? basePath, String pattern) => _text(
    basePath,
    'form.formatHint',
    'Format: {pattern}',
    params: {'pattern': pattern},
  );

  /// The suffix marking a required field when the style asks for words rather
  /// than an asterisk.
  ///
  /// The default has a leading space because it is appended to a label; a
  /// translation that omits it will run into the label.
  static String requiredSuffix(String? basePath) =>
      _text(basePath, 'form.requiredSuffix', ' (required)');

  /// The heading of the form-level error banner.
  static String errorBannerTitle(String? basePath) =>
      _text(basePath, 'form.errorBannerTitle', 'Form Errors');

  /// The heading of a row error strip reporting [count] errors.
  static String rowErrors(String? basePath, int count) => count == 1
      ? _text(basePath, 'form.rowErrorsOne', 'Row has 1 validation error:')
      : _text(
          basePath,
          'form.rowErrorsMany',
          'Row has {count} validation errors:',
          params: {'count': count},
        );

  /// The placeholder shown by a master-detail form with no row selected.
  static String masterDetailEmpty(String? basePath) => _text(
    basePath,
    'form.masterDetailEmpty',
    'Select an item from the list to edit it.',
  );

  /// The heading of the unsaved-changes prompt.
  static String unsavedTitle(String? basePath) =>
      _text(basePath, 'form.unsavedTitle', 'Unsaved changes');

  /// The body of the unsaved-changes prompt.
  static String unsavedMessage(String? basePath) => _text(
    basePath,
    'form.unsavedMessage',
    'You have unsaved edits. What would you like to do?',
  );

  /// Resolves [key] scoped to [basePath], then globally, then [fallback],
  /// interpolating `{name}` placeholders from [params] at whichever level won.
  ///
  /// Public so a widget outside this package can add a caption to the same
  /// vocabulary without a second, subtly different copy of the order.
  static String resolve(
    String? basePath,
    String key,
    String fallback, {
    Map<String, Object?>? params,
  }) => _text(basePath, key, fallback, params: params);

  static String _text(
    String? basePath,
    String key,
    String fallback, {
    Map<String, Object?>? params,
  }) {
    final resolved =
        TomCtr.textOrNull(basePath, key) ?? TomCtr.textOrNull(key) ?? fallback;
    if (params == null || params.isEmpty) return resolved;
    var out = resolved;
    params.forEach((name, value) => out = out.replaceAll('{$name}', '$value'));
    return out;
  }
}
