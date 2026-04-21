/// Demo L — File upload + nullable input variants (Phase 4).
///
/// Two-pane demo:
///
/// **Top pane** — File fields side-by-side
///   * `TomFormFileUpload` — compact "Choose file…" affordance.
///   * `TomFormFileDropzone` — large drop-target affordance, same picker.
///   Both share an in-memory `demoFilePicker` so the demo runs without a
///   real file picker dependency.
///
/// **Bottom pane** — Nullable input subform bound to a `TomClass`
///   * `TomFormNStringInput`, `TomFormNIntInput`, `TomFormNDoubleInput`,
///     `TomFormNDateInput` all bind into `FileNullableDemoState`.
///   * The right column shows the live values — distinguishing the three
///     spec-mandated states:
///       1. **pristine** — never touched (form.isDirty == false, value
///          comes from initial state).
///       2. **set** — user typed / picked a value (non-null).
///       3. **explicitly null** — user typed text then cleared, or hit
///          the trailing × button on a date / numeric.
///   * A `TomFormInspector` collects every event and exposes the count
///     by type so the difference is observable.
library;

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_scaffold.dart';
import '../forms/file_nullable_demo_form.dart';
import '../panels/info_panel.dart';
import '../state/phase4_state.dart';

class DemoLFileNullable extends StatefulWidget {
  const DemoLFileNullable({super.key});

  @override
  State<DemoLFileNullable> createState() => _DemoLFileNullableState();
}

class _DemoLFileNullableState extends State<DemoLFileNullable> {
  late final FileNullableDemoForm _form;
  final TomFormInspector _inspector = TomFormInspector();

  @override
  void initState() {
    super.initState();
    _form = TomScope.withScope(
      'demoL',
      () => FileNullableDemoForm(picker: demoFilePicker),
    );
    _form.bind(phase4FileNullableState);
    _form.addListener(_inspector);
  }

  @override
  void dispose() {
    _form.removeListener(_inspector);
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Demo L — File + Nullable Variants',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1000;
          final form = _buildFormColumn(context);
          final info = _buildInfoColumn(context);
          if (isWide) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(child: form),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(child: info),
                  ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _intro(context),
        const SizedBox(height: 12),
        _fileSection(context),
        const SizedBox(height: 12),
        _nullableSection(context),
      ],
    );
  }

  Widget _intro(BuildContext context) {
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
            const Text(
                '• File fields — compact upload button vs. large drop-zone '
                'affordance, both wired to the same in-memory picker '
                'callback (so the demo runs deterministically).\n'
                '• Nullable input variants — String / Int / Double / Date — '
                'bound into a FileNullableDemoState TomClass.\n'
                '• The right column distinguishes pristine / set / '
                'explicitly-null states. Use the action buttons to drive '
                'the form into each state and watch the inspector counts '
                'change.'),
          ],
        ),
      ),
    );
  }

  Widget _fileSection(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('File fields — upload + dropzone',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final stack = constraints.maxWidth < 600;
                if (stack) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _form.upload.widget,
                      const SizedBox(height: 12),
                      _form.dropzone.widget,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _form.upload.widget),
                    const SizedBox(width: 16),
                    Expanded(child: _form.dropzone.widget),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _nullableSection(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nullable input variants',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _form.notes.widget,
            const SizedBox(height: 8),
            _form.age.widget,
            const SizedBox(height: 8),
            _form.score.widget,
            const SizedBox(height: 8),
            _form.birthday.widget,
            const SizedBox(height: 12),
            _stateActionsRow(context),
          ],
        ),
      ),
    );
  }

  Widget _stateActionsRow(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        OutlinedButton(
          onPressed: () {
            // Pristine: discard back to bound state's initial nulls + clear
            // the file fields too.
            _form.discard();
            _form.upload.setValue(null);
            _form.dropzone.setValue(null);
            setState(() => _inspector.clear());
          },
          child: const Text('Reset (pristine)'),
        ),
        OutlinedButton(
          onPressed: () {
            // Set: write a non-null value into every nullable field.
            _form.notes.setValue('Hello world');
            _form.age.setValue(42);
            _form.score.setValue(7.50);
            _form.birthday.setValue(DateTime(1990, 1, 1));
          },
          child: const Text('Set all (non-null)'),
        ),
        OutlinedButton(
          onPressed: () {
            // Explicitly null: drive every nullable to null.
            _form.notes.setValue(null);
            _form.age.setValue(null);
            _form.score.setValue(null);
            _form.birthday.setValue(null);
          },
          child: const Text('Set all → null'),
        ),
      ],
    );
  }

  // --- Info column -------------------------------------------------------

  Widget _buildInfoColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoPanel(
          title: 'File fields',
          children: [_buildFileTable(context)],
        ),
        const SizedBox(height: 12),
        InfoPanel(
          title: 'Nullable values + state',
          children: [_buildNullableTable(context)],
        ),
        const SizedBox(height: 12),
        InfoPanel(
          title: 'TomFormInspector',
          children: [_buildInspectorPanel(context)],
        ),
      ],
    );
  }

  Widget _buildFileTable(BuildContext context) {
    return TomMultiObservableBuilder(
      observables: [_form.upload, _form.dropzone],
      builder: (context) {
        final theme = Theme.of(context);
        final rows = [
          ('upload', _formatFile(_form.upload.get())),
          ('dropzone', _formatFile(_form.dropzone.get())),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (name, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(name, style: theme.textTheme.bodySmall),
                    ),
                    Expanded(
                      child: Text(
                        value,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildNullableTable(BuildContext context) {
    return TomMultiObservableBuilder(
      observables: [
        _form.notes,
        _form.age,
        _form.score,
        _form.birthday,
      ],
      builder: (context) {
        final theme = Theme.of(context);
        final rows = <(String, Object?)>[
          ('notes', _form.notes.get()),
          ('age', _form.age.get()),
          ('score', _form.score.get()),
          ('birthday', _form.birthday.get()),
        ];
        return ListenableBuilder(
          listenable: _form.changes,
          builder: (context, _) {
            final dirty = _form.isDirty;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (name, value) in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text(name, style: theme.textTheme.bodySmall),
                        ),
                        SizedBox(
                          width: 110,
                          child: Text(
                            _stateLabel(dirty, value),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _stateColor(theme, dirty, value),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            value == null ? 'null' : _formatValue(value),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontFamily: 'monospace'),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  'form.isDirty = $dirty',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _stateLabel(bool dirty, Object? value) {
    if (!dirty) return 'pristine';
    if (value == null) return 'explicit-null';
    return 'set';
  }

  Color _stateColor(ThemeData theme, bool dirty, Object? value) {
    if (!dirty) return theme.colorScheme.onSurfaceVariant;
    if (value == null) return theme.colorScheme.tertiary;
    return theme.colorScheme.primary;
  }

  String _formatValue(Object value) {
    if (value is DateTime) {
      return '${value.year.toString().padLeft(4, '0')}-'
          '${value.month.toString().padLeft(2, '0')}-'
          '${value.day.toString().padLeft(2, '0')}';
    }
    return value.toString();
  }

  Widget _buildInspectorPanel(BuildContext context) {
    return ListenableBuilder(
      listenable: _form.changes,
      builder: (context, _) {
        final theme = Theme.of(context);
        final total = _inspector.length;
        final fieldChanges =
            _inspector.ofType<FieldValueChangedEvent>().length;
        final fieldCommitted =
            _inspector.ofType<FieldCommittedEvent>().length;
        final formBound = _inspector.ofType<FormBoundEvent>().length;
        final formDiscarded =
            _inspector.ofType<FormDiscardedEvent>().length;
        final rows = [
          ('total events', '$total'),
          ('FieldValueChanged', '$fieldChanges'),
          ('FieldCommitted', '$fieldCommitted'),
          ('FormBound', '$formBound'),
          ('FormDiscarded', '$formDiscarded'),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (name, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 150,
                      child: Text(name, style: theme.textTheme.bodySmall),
                    ),
                    Expanded(
                      child: Text(
                        value,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => setState(() => _inspector.clear()),
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Clear inspector'),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatFile(FileRef? ref) {
    if (ref == null) return '— no file selected';
    final size = ref.sizeBytes < 1024
        ? '${ref.sizeBytes} B'
        : '${(ref.sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${ref.name} ($size)';
  }
}
