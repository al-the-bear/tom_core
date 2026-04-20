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
///  * `TomFormStringInputClassic` and `TomFormEmailStringInputClassic` to
///    keep Classic ↔ new-spec coexistence exercised in the same tree.
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
    validators: [Validators.required(), Validators.minLength(3)],
  );
  late final title = TomFormStringInput(
    'title',
    '',
    form: this,
    validators: [Validators.required(), Validators.minLength(3)],
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
    validators: [Validators.required()],
  );
  late final priority = TomFormStringDropdown(
    'priority',
    'medium',
    form: this,
    source: _prioritySource,
    validators: [Validators.required()],
  );
  late final status = TomFormStringDropdown(
    'status',
    'draft',
    form: this,
    source: _statusSource,
    validators: [Validators.required()],
  );
  late final phase = TomFormStringDropdown(
    'phase',
    'plan',
    form: this,
    source: _phaseSource,
    validators: [Validators.required()],
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
  late final location = TomFormStringInput(
    'location',
    '',
    form: this,
  );

  // --- Classic-field targets — keep Classic coexistence live ------------

  // ignore: deprecated_member_use
  late final internalRef = TomFormStringInputClassic(
    'internalRef',
    '',
    form: this,
    labelText: 'Internal reference (Classic)',
    hintText: 'Free-form internal slug',
  );

  // ignore: deprecated_member_use
  late final contactEmail = TomFormEmailStringInputClassic(
    'contactEmail',
    '',
    form: this,
    labelText: 'Contact email (Classic email)',
    hintText: 'name@example.com',
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
    validators: [Validators.required()],
  );
  late final lastName = TomFormStringInput(
    'lastName',
    '',
    form: this,
    validators: [Validators.required()],
  );
  late final email = TomFormStringInput(
    'email',
    '',
    form: this,
    validators: [Validators.required(), Validators.email()],
    keyboardType: TextInputType.emailAddress,
  );
  late final phone = TomFormStringInput(
    'phone',
    '',
    form: this,
    keyboardType: TextInputType.phone,
  );
  late final title = TomFormStringInput(
    'title',
    '',
    form: this,
  );
}

// ---------------------------------------------------------------------------
// Selection sources for the classification dropdowns.
// ---------------------------------------------------------------------------

final _categorySource = StaticSelectableSource<String>([
  const SelectableItem(value: 'engineering', label: 'Engineering'),
  const SelectableItem(value: 'design', label: 'Design'),
  const SelectableItem(value: 'product', label: 'Product'),
  const SelectableItem(value: 'operations', label: 'Operations'),
  const SelectableItem(value: 'marketing', label: 'Marketing'),
]);

final _prioritySource = StaticSelectableSource<String>([
  const SelectableItem(value: 'low', label: 'Low'),
  const SelectableItem(value: 'medium', label: 'Medium'),
  const SelectableItem(value: 'high', label: 'High'),
  const SelectableItem(value: 'critical', label: 'Critical'),
]);

final _statusSource = StaticSelectableSource<String>([
  const SelectableItem(value: 'draft', label: 'Draft'),
  const SelectableItem(value: 'active', label: 'Active'),
  const SelectableItem(value: 'paused', label: 'Paused'),
  const SelectableItem(value: 'done', label: 'Done'),
]);

final _phaseSource = StaticSelectableSource<String>([
  const SelectableItem(value: 'plan', label: 'Planning'),
  const SelectableItem(value: 'build', label: 'Build'),
  const SelectableItem(value: 'review', label: 'Review'),
  const SelectableItem(value: 'ship', label: 'Ship'),
]);
