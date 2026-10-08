import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../actions/form_actions.dart';
import '../common/demo_scaffold.dart';
import '../forms/validation_form.dart';
import '../panels/event_log_panel.dart';
import '../panels/field_state_table.dart';
import '../panels/info_panel.dart';
import '../state/phase1_state.dart';
import 'demo_widgets.dart';

// ---------------------------------------------------------------------------
// Demo A — Lifecycle & Validation (Phase 1)
// ---------------------------------------------------------------------------

/// Two-column layout: form on the left, field-state table + event log on the
/// right. Exercises:
///
///   * `bind()` / `save()` / `discard()` lifecycle on [ValidationForm]
///   * `setValue(T)` (programmatic AND user-driven via the text fields)
///   * Sync validators (`required`, `email`, `minLength`, `pattern`)
///   * Async validation (`TomSlowValidator` on `username`)
///   * Cross-field validation (`password == confirmPassword`)
///   * Debounced fast/slow validation (built into `TomField.setValue`)
///   * `TomValidationPristine` — errors hidden on initial bind
///   * `commit()` returns the form to pristine after a successful save
///   * `TomFormErrorBanner` surfaces cross-field errors
///   * Resource resolution for every label/hint/error (see `demo_resources.json`)
///   * `SaveFormAction`, `DiscardFormAction` plus a custom `Clear` action
class DemoALifecycle extends StatefulWidget {
  const DemoALifecycle({super.key});

  @override
  State<DemoALifecycle> createState() => _DemoALifecycleState();
}

class _DemoALifecycleState extends State<DemoALifecycle> {
  late final ValidationForm _form;
  final _inspector = TomFormInspector();
  final _status = TomString('Bound — pristine (no errors shown yet)');

  late final _controller = TomActionController(controllerId: 'demoA');
  late final _save = SaveFormAction(
    _controller,
    forms: [_form],
    status: _status,
  );
  late final _discard = DiscardFormAction(
    _controller,
    forms: [_form],
    status: _status,
  );

  @override
  void initState() {
    super.initState();
    _form = TomScope.withScope('demoA', () => ValidationForm());
    _form.addListener(_inspector);
    _form.bind(phase1ValidationState);
  }

  @override
  void dispose() {
    _form.removeListener(_inspector);
    _form.dispose();
    super.dispose();
  }

  // --- Demo-specific actions ------------------------------------------------

  /// Clears every field's value via `setValue('')` — programmatic entry
  /// demonstrates how field-level transitions fire value-change events
  /// exactly like user typing would.
  void _clearAll() {
    for (final field in _form.fields.values) {
      if (field is TomField<String>) field.setValue('');
    }
    _status | 'Cleared all fields programmatically via setValue("")';
  }

  /// Prefills a canonical test value set so async/cross-field validators
  /// can be observed without having to type. Uses `setValue` not `set` to
  /// keep the event stream consistent with user input.
  void _populateSamples() {
    _form.username.setValue('janedoe');
    _form.email.setValue('jane.doe@example.com');
    _form.password.setValue('strongpass1');
    _form.confirmPassword.setValue('strongpass1');
    _form.website.setValue('https://example.com');
    _status | 'Populated with sample values via setValue(...)';
  }

  // --- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Demo A — Lifecycle & Validation',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final form = _buildFormColumn(context);
          final info = _buildInfoColumn(context);
          if (isWide) {
            // Each column gets its own scroll view so tall content on one
            // side doesn't force the other to overflow.
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: SingleChildScrollView(child: form)),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: SingleChildScrollView(child: info)),
                ],
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [form, const SizedBox(height: 16), info],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFormColumn(BuildContext context) {
    final layout = TomAclBuilder(id: 'demoALayout', elementProvider: _form)
        .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.top)
        .setAclExpandXDefault(true)
        .append((p) => p.username.widget)
        .newRow()
        .append((p) => p.email.widget)
        .newRow()
        .append((p) => p.password.widget)
        .append((p) => p.confirmPassword.widget, dist: 16)
        .newRow()
        .append((p) => p.website.widget)
        .build(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildIntroCard(context),
        const SizedBox(height: 12),
        TomFormStyleScope(
          style: TomFormStyle.material3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TomFormErrorBanner(form: _form),
              layout,
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildActionRow(context),
        const SizedBox(height: 8),
        _buildStatusCard(context),
      ],
    );
  }

  Widget _buildIntroCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What this demo covers', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            const DemoBullet(
              'bind() / save() / discard() roundtrip against '
              'phase1ValidationState',
            ),
            const DemoBullet(
              'setValue(T) — "Clear" and "Populate" demonstrate '
              'programmatic entry alongside user typing',
            ),
            const DemoBullet(
              'Sync validators: required, email, minLength, '
              'pattern (username)',
            ),
            const DemoBullet(
              'Async validator: "admin*" usernames fail after ~800ms '
              '(pending spinner visible)',
            ),
            const DemoBullet(
              'Cross-field: password must equal confirmPassword — '
              'surfaced by the TomFormErrorBanner above the form',
            ),
            const DemoBullet(
              'Pristine: no errors on first bind — only after typing or '
              'attempting Save. commit() after a successful Save resets '
              'all fields to pristine again',
            ),
            const DemoBullet(
              'Resources: labels, hints, error messages all '
              'resolve against demoA.validationForm.* in demo_resources.json',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton.icon(
          onPressed: _clearAll,
          icon: const Icon(Icons.clear_all),
          label: const Text('Clear'),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: _populateSamples,
          icon: const Icon(Icons.edit_note),
          label: const Text('Populate'),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () => _discard.execute(
            TomActionContext(),
            TomActionTransaction(label: 'discard'),
          ),
          child: Text(_discard.label),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () => _save.execute(
            TomActionContext(),
            TomActionTransaction(label: 'save'),
          ),
          child: Text(_save.label),
        ),
      ],
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    return ListenableBuilder(
      listenable: _form.changes,
      builder: (context, _) => TomMultiObservableBuilder(
        observables: [_status],
        builder: (context) => Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status: ${_status.get()}'),
                const SizedBox(height: 4),
                Text('Dirty: ${_form.isDirty}   Valid: ${_form.isValid}'),
                Text(
                  'Dirty fields: '
                  '${_form.dirtyFields.map((f) => f.tomId).join(', ')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Fields with errors: '
                  '${_form.fieldsWithErrors.map((f) => f.tomId).join(', ')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoPanel(
          title: 'Field state',
          children: [
            FieldStateTable(forms: [_form]),
          ],
        ),
        const SizedBox(height: 12),
        InfoPanel(
          title: 'Event log',
          children: [
            EventLogPanel(inspector: _inspector, rebuildOn: _form.changes),
          ],
        ),
      ],
    );
  }
}
