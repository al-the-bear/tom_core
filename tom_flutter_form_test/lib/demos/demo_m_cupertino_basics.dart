/// Demo M — Cupertino string + selection + bool (Phase 5a).
///
/// Two-pane demo:
///
/// **Left pane** — Material concretes (`TomFormStringInput`,
/// `TomFormStringDropdown`, `TomFormStringSegmented`,
/// `TomFormStringFilterChips`, `TomFormStringSearchInput`,
/// `TomFormBoolSwitch`, `TomFormBoolToggle`).
///
/// **Right pane** — the matching Phase 5a Cupertino concretes:
/// `TomCupertinoFormStringInput`, `…StringPicker`, `…StringSegmented`,
/// `…StringListCheckedPicker`, `…StringSearchInput`, `…BoolSwitch`,
/// `…BoolToggle`.
///
/// Both panels bind to the same [Phase5DemoState] instance and are
/// synced pair-wise through observers — typing in either side flips
/// the other immediately, proving the Cupertino concretes carry the
/// same observable / authorization / validation semantics as their
/// Material peers.
///
/// A radio toggle at the top swaps the page-root
/// `TomFormStyleScope.style` between [TomFormStyle.material3] and
/// [TomCupertinoFormStyle.cupertino] — the entire decoration anatomy
/// (label/error/description gaps, radii, padding) flips for both
/// panels at once.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_scaffold.dart';
import '../forms/phase5_demo_forms.dart';
import '../panels/info_panel.dart';
import '../state/phase5_state.dart';

enum _StyleChoice { material, cupertino }

class DemoMCupertinoBasics extends StatefulWidget {
  const DemoMCupertinoBasics({super.key});

  @override
  State<DemoMCupertinoBasics> createState() => _DemoMCupertinoBasicsState();
}

class _DemoMCupertinoBasicsState extends State<DemoMCupertinoBasics> {
  late final MaterialPhase5Form _materialForm;
  late final CupertinoPhase5Form _cupertinoForm;

  /// Active scope style. Flipping this rebuilds the page-root
  /// `TomFormStyleScope` so both panels re-resolve their anatomy.
  _StyleChoice _styleChoice = _StyleChoice.material;

  /// Unregisters the pair-wise sync observers on dispose.
  ///
  /// Closures rather than bare observers: [_pair] is the only place that
  /// knows which observable each observer was attached to, so it captures
  /// the two together here instead of discarding the pairing. Retaining
  /// the closures is also what keeps the observers alive — [TomObservable]
  /// holds them by [WeakReference].
  final List<void Function()> _observerCancels = [];
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _materialForm = TomScope.withScope('demoMMat', MaterialPhase5Form.new);
    _cupertinoForm = TomScope.withScope('demoMCup', CupertinoPhase5Form.new);

    // Bind both forms to the same shared state instance.
    _materialForm.bind(phase5DemoState);
    _cupertinoForm.bind(phase5DemoState);

    // Pair-wise sync: edit on either side flows to the other.
    _pair(_materialForm.name, _cupertinoForm.name);
    _pair(_materialForm.color, _cupertinoForm.color);
    _pair(_materialForm.size, _cupertinoForm.size);
    _pairList(_materialForm.tags, _cupertinoForm.tags);
    _pair(_materialForm.search, _cupertinoForm.search);
    _pair(_materialForm.notifications, _cupertinoForm.notifications);
    _pair(_materialForm.darkMode, _cupertinoForm.darkMode);
  }

  void _pair<V>(TomField<V> a, TomField<V> b) {
    _observe(a, () {
      if (b.get() != a.get()) b.setValue(a.get());
    });
    _observe(b, () {
      if (a.get() != b.get()) a.setValue(b.get());
    });
  }

  void _pairList(TomField<List<String>> a, TomField<List<String>> b) {
    _observe(a, () {
      if (!_listEq(a.get(), b.get())) b.setValue([...a.get()]);
    });
    _observe(b, () {
      if (!_listEq(a.get(), b.get())) a.setValue([...b.get()]);
    });
  }

  /// Observes [source] and runs [propagate] on change, guarded against the
  /// re-entry the propagation itself causes: writing to the peer fires the
  /// peer's own observer, which would write straight back.
  void _observe(TomObservable source, void Function() propagate) {
    final observer =
        source >>
        (_) {
          if (_syncing) return;
          _syncing = true;
          try {
            propagate();
          } finally {
            _syncing = false;
          }
        };
    _observerCancels.add(() => source.removeObserver(observer));
  }

  bool _listEq(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    for (final cancel in _observerCancels) {
      cancel();
    }
    _observerCancels.clear();
    _materialForm.dispose();
    _cupertinoForm.dispose();
    super.dispose();
  }

  TomFormStyle get _activeStyle => switch (_styleChoice) {
    _StyleChoice.material => const TomFormStyle(),
    _StyleChoice.cupertino => TomCupertinoFormStyle.cupertino,
  };

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Demo M — Material vs Cupertino (Phase 5a)',
      child: TomFormStyleScope(
        style: _activeStyle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeaderBar(context),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 900;
                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _materialPanel(context)),
                          const SizedBox(width: 16),
                          Expanded(child: _cupertinoPanel(context)),
                          const SizedBox(width: 16),
                          SizedBox(width: 260, child: _statePanel(context)),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _materialPanel(context),
                        const SizedBox(height: 12),
                        _cupertinoPanel(context),
                        const SizedBox(height: 12),
                        _statePanel(context),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            'Page-root TomFormStyleScope.style:',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(width: 12),
          ...[_StyleChoice.material, _StyleChoice.cupertino].map(
            (choice) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(switch (choice) {
                  _StyleChoice.material => 'TomFormStyle.material3',
                  _StyleChoice.cupertino => 'TomCupertinoFormStyle.cupertino',
                }),
                selected: _styleChoice == choice,
                onSelected: (sel) {
                  if (sel) setState(() => _styleChoice = choice);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _materialPanel(BuildContext context) =>
      _panelCard(context, 'Material concretes', [
        _materialForm.name.widget,
        _materialForm.color.widget,
        _materialForm.size.widget,
        _materialForm.tags.widget,
        _materialForm.search.widget,
        _materialForm.notifications.widget,
        _materialForm.darkMode.widget,
      ]);

  Widget _cupertinoPanel(BuildContext context) =>
      _panelCard(context, 'Cupertino concretes', [
        _cupertinoForm.name.widget,
        _cupertinoForm.color.widget,
        _cupertinoForm.size.widget,
        _cupertinoForm.tags.widget,
        _cupertinoForm.search.widget,
        _cupertinoForm.notifications.widget,
        _cupertinoForm.darkMode.widget,
      ]);

  Widget _panelCard(BuildContext context, String title, List<Widget> children) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final w in children) ...[w, const SizedBox(height: 8)],
          ],
        ),
      ),
    );
  }

  Widget _statePanel(BuildContext context) {
    return InfoPanel(
      title: 'Shared state (Phase5DemoState)',
      children: [
        TomMultiObservableBuilder(
          observables: [
            _materialForm.name,
            _materialForm.color,
            _materialForm.size,
            _materialForm.tags,
            _materialForm.search,
            _materialForm.notifications,
            _materialForm.darkMode,
          ],
          builder: (context) {
            final theme = Theme.of(context);
            final rows = <(String, String)>[
              ('name', _materialForm.name.get()),
              ('color', _materialForm.color.get()),
              ('size', _materialForm.size.get()),
              ('tags', _materialForm.tags.get().join(', ')),
              ('search', _materialForm.search.get()),
              ('notifications', '${_materialForm.notifications.get()}'),
              ('darkMode', '${_materialForm.darkMode.get()}'),
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
                            value.isEmpty ? '—' : value,
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
