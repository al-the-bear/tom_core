import 'package:flutter/material.dart';
// `>>` (observer registration) is an extension on TomObservable, so the
// declaring library has to be imported even though no type is named from it.
// import 'package:tom_core_kernel/tom_core_kernel.dart';
// Not imported: tom_flutter_ui re-exports every kernel type this file uses
// through its kernel bridge (tom_flutter_ui/lib/src/kernel_types.dart).
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_scaffold.dart';
import '../panels/info_panel.dart';
import 'demo_widgets.dart';

// ---------------------------------------------------------------------------
// Demo F — Boolean Variants
// ---------------------------------------------------------------------------

/// The spec's Phase 2 boolean-variants demo, exercising the three concrete
/// boolean fields that ship in `tom_flutter_ui`:
///
///   * [TomFormBoolCheckbox], [TomFormBoolSwitch] and [TomFormBoolToggle]
///     rendered side-by-side, each holding its own value so the three can
///     diverge.
///   * A second row of the same three fields kept in lock-step, so flipping
///     any one flips the other two.
///   * All six carry the same label / description / error anatomy, supplied
///     by `TomGenericFieldDecorationMixin` rather than by this demo.
///
/// Why lock-step rather than one shared observable: [TomField] *is* the
/// observable (`TomField<T> extends TomObject<T>`), so three fields cannot
/// point at a single `TomBool` the way three bare Material widgets could.
/// Propagating through an observer is what "shared state" means for fields,
/// and it demonstrates the point that matters — every rendering exposes the
/// same `setValue` contract.
class DemoFBooleanVariants extends StatefulWidget {
  const DemoFBooleanVariants({super.key});

  @override
  State<DemoFBooleanVariants> createState() => _DemoFBooleanVariantsState();
}

class _DemoFBooleanVariantsState extends State<DemoFBooleanVariants> {
  // Independent — one field per rendering, no coupling between them.
  late final TomFormBoolCheckbox _checkbox;
  late final TomFormBoolSwitch _switch;
  late final TomFormBoolToggle _toggle;

  // Lock-step trio — the same three renderings, kept in agreement.
  late final TomFormBoolCheckbox _sharedCheckbox;
  late final TomFormBoolSwitch _sharedSwitch;
  late final TomFormBoolToggle _sharedToggle;

  /// Guards [_syncShared] against re-entry: propagating to a peer calls
  /// `setValue`, which fires this same observer again. Without the guard the
  /// first tap would recurse through the trio.
  bool _syncing = false;

  late final List<TomField<bool>> _independent = [_checkbox, _switch, _toggle];
  late final List<TomField<bool>> _shared = [
    _sharedCheckbox,
    _sharedSwitch,
    _sharedToggle,
  ];

  /// Unregisters the lock-step observers on dispose. Observers are held
  /// weakly, so retaining the cancellers is also what keeps them alive.
  final List<void Function()> _observerCancels = [];

  @override
  void initState() {
    super.initState();

    _checkbox = TomFormBoolCheckbox(
      'checkboxFlag',
      false,
      labelTextOverride: 'TomFormBoolCheckbox (checkboxFlag)',
    );
    _switch = TomFormBoolSwitch(
      'switchFlag',
      false,
      labelTextOverride: 'TomFormBoolSwitch (switchFlag)',
    );
    _toggle = TomFormBoolToggle(
      'toggleFlag',
      false,
      labelTextOverride: 'TomFormBoolToggle (toggleFlag)',
    );

    _sharedCheckbox = TomFormBoolCheckbox(
      'sharedCheckbox',
      false,
      labelTextOverride: 'Checkbox ↔ shared',
    );
    _sharedSwitch = TomFormBoolSwitch(
      'sharedSwitch',
      false,
      labelTextOverride: 'Switch ↔ shared',
    );
    _sharedToggle = TomFormBoolToggle(
      'sharedToggle',
      false,
      labelTextOverride: 'Toggle ↔ shared',
    );

    for (final field in _shared) {
      final observer = field >> (_) => _syncShared(field.get());
      _observerCancels.add(() => field.removeObserver(observer));
    }
  }

  /// Propagates [value] to every member of the lock-step trio.
  void _syncShared(bool value) {
    if (_syncing) return;
    _syncing = true;
    try {
      for (final field in _shared) {
        if (field.get() != value) field.setValue(value);
      }
    } finally {
      _syncing = false;
    }
  }

  @override
  void dispose() {
    for (final cancel in _observerCancels) {
      cancel();
    }
    _observerCancels.clear();
    for (final field in [..._independent, ..._shared]) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Demo F — Boolean Variants',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final form = _buildFormColumn(context);
          final info = _buildInfoColumn(context);
          if (isWide) {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildIntroCard(context),
        const SizedBox(height: 12),
        _variantCard(
          context,
          title: 'Independent (one field per rendering)',
          children: _independent.map(_fieldRow).toList(),
        ),
        const SizedBox(height: 12),
        _variantCard(
          context,
          title: 'Lock-step trio — flip any, flip all',
          children: _shared.map(_fieldRow).toList(),
        ),
      ],
    );
  }

  /// Renders one field, keyed by its `tomId`.
  ///
  /// Why the key: the three renderings repeat the same inner Material
  /// widgets (and the toggle repeats the segment captions "On"/"Off"), so a
  /// widget test needs a stable per-field anchor to scope its finders to one
  /// row. The key is the only thing here that exists for the tests.
  Widget _fieldRow(TomField<bool> field) => Padding(
    key: ValueKey('field-${field.tomId}'),
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: field.widget,
  );

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
              'The three concrete boolean fields — TomFormBoolCheckbox, '
              'TomFormBoolSwitch and TomFormBoolToggle — side-by-side, '
              'each holding its own value so they can diverge.',
            ),
            const DemoBullet(
              'A second row of the same three kept in '
              'lock-step: flipping any one propagates to the other two '
              'through the observable channel, no setState in this demo.',
            ),
            const DemoBullet(
              'Every row draws its label from the field, not '
              'from the demo — all three renderings share one label / '
              'description / error anatomy via '
              'TomGenericFieldDecorationMixin.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _variantCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(BuildContext context) {
    final fields = [..._independent, ..._shared];
    return InfoPanel(
      title: 'Bound values',
      children: [
        TomMultiObservableBuilder(
          observables: fields,
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final field in fields)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text(
                          field.tomId,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${field.get()}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
