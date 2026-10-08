import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// ---------------------------------------------------------------------------
// ProjectBriefForm — drives Demo G (breakpoints) and Demo H (auth)
// ---------------------------------------------------------------------------

/// Large, intentionally heterogeneous form wiring up every field
/// implementation we have today:
///
///  * `TomFormStringInput` for every free-text field — validated on a
///    handful, multiline on summary/description/riskNotes.
///  * `TomFormStringDropdown` for category / priority / status / phase so
///    breakpoint-driven dropdown ↔ segmented swaps have real dropdowns.
///  * One of each shipped boolean rendering — `TomFormBoolSwitch`,
///    `TomFormBoolCheckbox`, `TomFormBoolToggle`. Three different
///    renderings rather than three switches because Demo G's subject is
///    the style/theme swap across four width bands, and the three resolve
///    their style through three different `TomFormStyle` slots
///    (`switchStyle`, `checkboxStyle`, `segmentedStyle`) — so one row
///    proves the swap reaches all three anatomies.
///  * `TomTextFormFieldBase<String>` used directly, twice, to keep the
///    Classic ↔ new-spec coexistence exercised in the same tree.
///  * Nested `PersonSubform` for `lead` and `reviewer` so the form is a
///    proper tree, not a flat bag. Both are built in `createFormElements`
///    for correct scope; top-level fields pass `form: this` so their
///    basePath anchors on `<outer>.projectBrief.*`.
@tomReflector
class ProjectBriefForm extends TomForm<TomClass> {
  ProjectBriefForm() : super(formId: 'projectBrief');

  // --- Identity -----------------------------------------------------------

  late final code = TomFormStringInput(
    'code',
    '',
    form: this,
    validators: [TomValidators.required(), TomValidators.minLength(3)],
  );
  late final title = TomFormStringInput(
    'title',
    '',
    form: this,
    validators: [TomValidators.required(), TomValidators.minLength(3)],
  );
  late final summary = TomFormStringInput(
    'summary',
    '',
    form: this,
    maxLines: 2,
  );

  // --- Classification (dropdown-backed) ----------------------------------

  late final category = TomFormStringDropdown(
    'category',
    'engineering',
    form: this,
    source: _categorySource,
    validators: [TomValidators.required()],
  );
  late final priority = TomFormStringDropdown(
    'priority',
    'medium',
    form: this,
    source: _prioritySource,
    validators: [TomValidators.required()],
  );
  late final status = TomFormStringDropdown(
    'status',
    'draft',
    form: this,
    source: _statusSource,
    validators: [TomValidators.required()],
  );
  late final phase = TomFormStringDropdown(
    'phase',
    'plan',
    form: this,
    source: _phaseSource,
    validators: [TomValidators.required()],
  );

  // --- Flags --------------------------------------------------------------
  //
  // These bind to `ProjectBrief`'s three `TomBool` members by name, like
  // every other field here: a `TomField<bool>` takes the serialized `bool`
  // straight off `getValues()`, so no demo-side plumbing is involved.

  late final isPublic = TomFormBoolSwitch('isPublic', false, form: this);
  late final needsReview = TomFormBoolCheckbox(
    'needsReview',
    false,
    form: this,
  );
  late final notifySubscribers = TomFormBoolToggle(
    'notifySubscribers',
    false,
    form: this,
    onLabelOverride: 'Notify',
    offLabelOverride: 'Silent',
  );

  // The brief's tags bind the same way: `ProjectBrief.tags` is a
  // `TomList<TomString>`, which `getValues()` serializes as a plain list, and
  // `setValues` re-types it into the `List<String>` a multi-select holds.
  late final tags = TomFormStringFilterChips(
    'tags',
    const [],
    source: _tagSource,
    form: this,
    labelTextOverride: 'Tags',
    descriptionTextOverride: 'Free-form labels used by the portfolio filters.',
  );

  // --- Scope --------------------------------------------------------------

  late final budget = TomFormStringInput(
    'budget',
    '',
    form: this,
    keyboardType: TextInputType.number,
  );
  late final hoursEstimate = TomFormStringInput(
    'hoursEstimate',
    '',
    form: this,
    keyboardType: TextInputType.number,
  );
  late final deadline = TomFormStringInput(
    'deadline',
    '',
    form: this,
    hintTextOverride: 'YYYY-MM-DD',
  );
  late final location = TomFormStringInput('location', '', form: this);

  // --- Classic-field targets — keep Classic coexistence live ------------

  late final internalRef = TomTextFormFieldBase<String>(
    'internalRef',
    '',
    form: this,
    labelText: 'Internal reference (Classic)',
    hintText: 'Free-form internal slug',
  );

  // The Classic path validates with a plain `String? Function(String)` that
  // returns a resource key, rather than with the `TomValidators` pipeline the
  // spec-conforming fields use — so the shape check lives here at the call
  // site. New code wanting a validated email writes a `TomFormStringInput`
  // with `TomValidators.email()`, as `CustomerForm.email` does.
  late final contactEmail = TomTextFormFieldBase<String>(
    'contactEmail',
    '',
    form: this,
    labelText: 'Contact email (Classic email)',
    hintText: 'name@example.com',
    valueValidator: (value) =>
        value.isEmpty || RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)
        ? null
        : 'contactEmail.errors.validEmail',
  );

  // --- Long-form ---------------------------------------------------------

  late final description = TomFormStringInput(
    'description',
    '',
    form: this,
    maxLines: 4,
  );
  late final riskNotes = TomFormStringInput(
    'riskNotes',
    '',
    form: this,
    maxLines: 3,
  );

  // --- Nested Person subforms -------------------------------------------

  late PersonSubform lead;
  late PersonSubform reviewer;

  @override
  void createFormElements() {
    lead = PersonSubform(tomId: 'lead');
    reviewer = PersonSubform(tomId: 'reviewer');
  }
}

// ---------------------------------------------------------------------------
// PersonSubform — small nested form reused for lead / reviewer
// ---------------------------------------------------------------------------

@tomReflector
class PersonSubform extends TomForm<TomClass> {
  PersonSubform({required String tomId}) : super(formId: tomId);

  @override
  void createFormElements() {}

  late final firstName = TomFormStringInput(
    'firstName',
    '',
    form: this,
    validators: [TomValidators.required()],
  );
  late final lastName = TomFormStringInput(
    'lastName',
    '',
    form: this,
    validators: [TomValidators.required()],
  );
  late final email = TomFormStringInput(
    'email',
    '',
    form: this,
    validators: [TomValidators.required(), TomValidators.email()],
    keyboardType: TextInputType.emailAddress,
  );
  late final phone = TomFormStringInput(
    'phone',
    '',
    form: this,
    keyboardType: TextInputType.phone,
  );
  late final title = TomFormStringInput('title', '', form: this);
}

// ---------------------------------------------------------------------------
// Selection sources for the classification dropdowns.
// ---------------------------------------------------------------------------

final _categorySource = TomStaticSelectableSource<String>([
  const TomSelectableItem(value: 'engineering', label: 'Engineering'),
  const TomSelectableItem(value: 'design', label: 'Design'),
  const TomSelectableItem(value: 'product', label: 'Product'),
  const TomSelectableItem(value: 'operations', label: 'Operations'),
  const TomSelectableItem(value: 'marketing', label: 'Marketing'),
]);

final _prioritySource = TomStaticSelectableSource<String>([
  const TomSelectableItem(value: 'low', label: 'Low'),
  const TomSelectableItem(value: 'medium', label: 'Medium'),
  const TomSelectableItem(value: 'high', label: 'High'),
  const TomSelectableItem(value: 'critical', label: 'Critical'),
]);

final _statusSource = TomStaticSelectableSource<String>([
  const TomSelectableItem(value: 'draft', label: 'Draft'),
  const TomSelectableItem(value: 'active', label: 'Active'),
  const TomSelectableItem(value: 'paused', label: 'Paused'),
  const TomSelectableItem(value: 'done', label: 'Done'),
]);

final _phaseSource = TomStaticSelectableSource<String>([
  const TomSelectableItem(value: 'plan', label: 'Planning'),
  const TomSelectableItem(value: 'build', label: 'Build'),
  const TomSelectableItem(value: 'review', label: 'Review'),
  const TomSelectableItem(value: 'ship', label: 'Ship'),
]);

/// Item set behind the brief's `tags` multi-select.
final _tagSource = TomStaticSelectableSource<String>([
  const TomSelectableItem(value: 'dashboard', label: 'dashboard'),
  const TomSelectableItem(value: 'metrics', label: 'metrics'),
  const TomSelectableItem(value: 'sla', label: 'sla'),
  const TomSelectableItem(value: 'incident', label: 'incident'),
  const TomSelectableItem(value: 'frontend', label: 'frontend'),
]);
