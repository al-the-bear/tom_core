/// Demo O — Cupertino search / lookup / file + nullable variants
/// (Phase 5c).
///
/// Renders the six remaining Phase 5c Cupertino concretes
/// (`TomCupertinoFormSearchInput`, `…LookupSheet`, `…FileUpload`,
/// `…NStringInput`, `…NIntInput`, `…NDoubleInput`, `…NDateInput`) inside a
/// page-root `TomFormStyleScope` pinned to
/// `TomCupertinoFormStyle.cupertino`. The form binds to
/// [Phase5cDemoState] for the four nullable rows; the search / lookup /
/// file rows stay form-local because their value types
/// (`City`, `Country`, `FileRef`) have no `TomObject<…>` wrapper.
///
/// A side panel reads back the live state via [TomMultiObservableBuilder]
/// so every row's value is visible without scrolling.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_scaffold.dart';
import '../forms/phase5_demo_forms.dart';
import '../panels/info_panel.dart';
import '../state/phase5_state.dart';

class DemoOCupertinoSearchLookupFile extends StatefulWidget {
  const DemoOCupertinoSearchLookupFile({super.key});

  @override
  State<DemoOCupertinoSearchLookupFile> createState() =>
      _DemoOCupertinoSearchLookupFileState();
}

class _DemoOCupertinoSearchLookupFileState
    extends State<DemoOCupertinoSearchLookupFile> {
  late final CupertinoPhase5cForm _form;

  @override
  void initState() {
    super.initState();
    _form = TomScope.withScope('demoO', CupertinoPhase5cForm.new);
    // Bind the four nullable rows. Search / lookup / file rows stay
    // form-local automatically — their property names don't appear on
    // Phase5cDemoState, so bind() leaves them untouched.
    _form.bind(phase5cDemoState);
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Demo O — Cupertino search / lookup / file (Phase 5c)',
      child: TomFormStyleScope(
        style: TomCupertinoFormStyle.cupertino,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _formColumn(context)),
                        const SizedBox(width: 16),
                        SizedBox(width: 300, child: _statePanel(context)),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _formColumn(context),
                        const SizedBox(height: 12),
                        _statePanel(context),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _formColumn(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionHeader(context, 'Search & lookup'),
            _form.citySearch.widget,
            const SizedBox(height: 8),
            _form.countryLookup.widget,
            const SizedBox(height: 16),
            _sectionHeader(context, 'File upload'),
            _form.upload.widget,
            const SizedBox(height: 16),
            _sectionHeader(context, 'Nullable variants'),
            _form.notes.widget,
            const SizedBox(height: 8),
            _form.age.widget,
            const SizedBox(height: 8),
            _form.score.widget,
            const SizedBox(height: 8),
            _form.birthday.widget,
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String label) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _statePanel(BuildContext context) {
    return InfoPanel(
      title: 'Form state (Phase5cDemoState + form-local)',
      children: [
        TomMultiObservableBuilder(
          observables: [
            _form.citySearch,
            _form.countryLookup,
            _form.upload,
            _form.notes,
            _form.age,
            _form.score,
            _form.birthday,
          ],
          builder: (context) {
            final theme = Theme.of(context);
            String dateStr(DateTime? d) {
              if (d == null) return '— null —';
              return '${d.year.toString().padLeft(4, '0')}-'
                  '${d.month.toString().padLeft(2, '0')}-'
                  '${d.day.toString().padLeft(2, '0')}';
            }

            final upload = _form.upload.get();
            final rows = <(String, String)>[
              ('citySearch', _form.citySearch.get().toString()),
              ('countryLookup', _form.countryLookup.get().toString()),
              (
                'upload',
                upload == null
                    ? '— null —'
                    : '${upload.name} (${upload.sizeBytes} B)',
              ),
              ('notes', _form.notes.get() ?? '— null —'),
              ('age', _form.age.get()?.toString() ?? '— null —'),
              ('score', _form.score.get()?.toStringAsFixed(2) ?? '— null —'),
              ('birthday', dateStr(_form.birthday.get())),
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (name, value) in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 110,
                          child: Text(name, style: theme.textTheme.bodySmall),
                        ),
                        Expanded(
                          child: Text(
                            value,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
