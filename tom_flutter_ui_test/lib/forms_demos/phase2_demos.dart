/// Phase 2 Demos — Selection Variants, Boolean Variants,
/// Complex Breakpoint Scenarios, Complex Authorization Scenarios.
///
/// Mirrors the Phase 2 section of the forms spec in
/// `_doc/tom/tom_ui_widgets_forms.md` — each demo focuses on one
/// concern so nothing is overloaded.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// ===========================================================================
// Helpers
// ===========================================================================

Widget _sectionTitle(BuildContext context, String text) {
  return Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 4),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}

/// Minimal mutable [TomSelectableSource] used by Demo E to toggle the
/// item list at runtime. The default [StaticSelectableSource] is
/// immutable so the demo rolls its own.
///
/// Public (rather than library-private) so that
/// `test/forms_dispose_test.dart` can assert the owning demo state closes
/// it on unmount — [isDisposed] is the observable signal for that.
class SwappableSource<T> extends TomSelectableSource<T> {
  SwappableSource(List<SelectableItem<T>> initial) : _items = List.of(initial);

  List<SelectableItem<T>> _items;
  final _controller = StreamController<List<SelectableItem<T>>>.broadcast();

  void setItems(List<SelectableItem<T>> next) {
    _items = List.of(next);
    _controller.add(List.unmodifiable(_items));
  }

  @override
  Future<List<SelectableItem<T>>> getItems() async =>
      List.unmodifiable(_items);

  @override
  Stream<List<SelectableItem<T>>> get itemsStream => _controller.stream;

  /// Whether [dispose] has closed the underlying broadcast controller.
  bool get isDisposed => _controller.isClosed;

  void dispose() => _controller.close();
}

Widget _panel({required String title, required List<Widget> children}) {
  return Card(
    margin: const EdgeInsets.symmetric(vertical: 8),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              )),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );
}

// ===========================================================================
// Demo E — Selection Variants
// ===========================================================================

class SelectionVariantsDemo extends StatefulWidget {
  const SelectionVariantsDemo({super.key});

  @override
  State<SelectionVariantsDemo> createState() => SelectionVariantsDemoState();
}

/// Public so `test/forms_dispose_test.dart` can type the `@visibleForTesting`
/// disposal hooks ([debugSharedSource], [debugObserverCount]).
class SelectionVariantsDemoState extends State<SelectionVariantsDemo> {
  // All three single-select concretes share a single source. Each writes
  // to its own field, so the inspector can show every binding side-by-side.
  late final SwappableSource<String> _sharedSource;
  late final TomFormStringSegmented _segmented;
  late final TomFormStringRadioGroup _radio;
  late final TomFormStringChoiceChips _chips;
  late final TomFormStringFilterChips _filter;
  late final TomFormStringMultiCheckbox _multiCheck;

  /// Every field this state owns, for batched disposal.
  late final List<TomField> _fields = [
    _segmented,
    _radio,
    _chips,
    _filter,
    _multiCheck,
  ];

  /// Cancellers for the `>>` observers registered in [initState]. Each
  /// removes one observer from its field; retaining them keeps the
  /// (weakly-held) observers alive and lets [dispose] unregister them.
  final List<void Function()> _observerCancels = [];

  bool _filtered = false;

  static const _fullItems = [
    SelectableItem(value: 'apple', label: 'Apple'),
    SelectableItem(value: 'banana', label: 'Banana'),
    SelectableItem(value: 'cherry', label: 'Cherry'),
    SelectableItem(value: 'date', label: 'Date'),
  ];

  static const _filteredItems = [
    SelectableItem(value: 'apple', label: 'Apple'),
    SelectableItem(value: 'cherry', label: 'Cherry'),
  ];

  @override
  void initState() {
    super.initState();
    _sharedSource = SwappableSource<String>(_fullItems);

    _segmented = TomFormStringSegmented(
      'seg',
      'apple',
      source: _sharedSource,
      labelTextOverride: 'Segmented',
    );
    _radio = TomFormStringRadioGroup(
      'radio',
      'apple',
      source: _sharedSource,
      labelTextOverride: 'RadioGroup',
    );
    _chips = TomFormStringChoiceChips(
      'choice',
      'apple',
      source: _sharedSource,
      labelTextOverride: 'ChoiceChips',
    );
    _filter = TomFormStringFilterChips(
      'filter',
      const ['apple'],
      source: _sharedSource,
      labelTextOverride: 'FilterChips',
    );
    _multiCheck = TomFormStringMultiCheckbox(
      'multi',
      const ['apple'],
      source: _sharedSource,
      labelTextOverride: 'MultiCheckbox',
    );

    // Re-render the value-inspector panel whenever any field fires.
    for (final field in _fields) {
      final observer = field >> (_) => setState(() {});
      _observerCancels.add(() => field.removeObserver(observer));
    }
  }

  /// Owned shared source — exposed for `forms_dispose_test.dart` to assert
  /// it is closed on unmount.
  @visibleForTesting
  SwappableSource<String> get debugSharedSource => _sharedSource;

  /// Number of live `>>` observer registrations — `0` once [dispose] has
  /// unregistered them.
  @visibleForTesting
  int get debugObserverCount => _observerCancels.length;

  @override
  void dispose() {
    for (final cancel in _observerCancels) {
      cancel();
    }
    _observerCancels.clear();
    for (final field in _fields) {
      field.dispose();
    }
    _sharedSource.dispose();
    super.dispose();
  }

  void _toggleFilter() {
    setState(() {
      _filtered = !_filtered;
      _sharedSource.setItems(_filtered ? _filteredItems : _fullItems);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Demo E — Selection Variants',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'All five selection concretes bound to the same '
                    'TomSelectableSource<String>. Single-select writes '
                    'to TomString, multi-select writes to '
                    'TomList<TomString>.',
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    FilledButton.icon(
                      onPressed: _toggleFilter,
                      icon: const Icon(Icons.filter_alt),
                      label: Text(_filtered
                          ? 'Show all items'
                          : 'Show filtered source'),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          _sectionTitle(context, 'Single-select'),
          _panel(title: 'Segmented', children: [_segmented.widget]),
          _panel(title: 'RadioGroup', children: [_radio.widget]),
          _panel(title: 'ChoiceChips', children: [_chips.widget]),
          _sectionTitle(context, 'Multi-select'),
          _panel(title: 'FilterChips', children: [_filter.widget]),
          _panel(title: 'MultiCheckbox', children: [_multiCheck.widget]),
          _sectionTitle(context, 'Bound values'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('segmented → ${_segmented.get()}'),
                  Text('radio → ${_radio.get()}'),
                  Text('chips → ${_chips.get()}'),
                  Text('filter → ${_filter.get()}'),
                  Text('multiCheck → ${_multiCheck.get()}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Demo F — Boolean Variants
// ===========================================================================

class BooleanVariantsDemo extends StatefulWidget {
  const BooleanVariantsDemo({super.key});

  @override
  State<BooleanVariantsDemo> createState() => _BooleanVariantsDemoState();
}

class _BooleanVariantsDemoState extends State<BooleanVariantsDemo> {
  // First trio: each bool concrete bound to its own state.
  late final TomFormBoolCheckbox _acceptTerms;
  late final TomFormBoolSwitch _notifications;
  late final TomFormBoolToggle _mode;

  // Second trio: all three concretes rendered against different instances
  // but kept in lock-step via a shared observer — demonstrates that each
  // flavor exposes the same setValue contract.
  late final TomFormBoolCheckbox _sharedCheckbox;
  late final TomFormBoolSwitch _sharedSwitch;
  late final TomFormBoolToggle _sharedToggle;
  bool _syncing = false;

  // "Settings" layout: booleans mixed with a string input and dropdown.
  late final TomFormStringInput _displayName;
  late final TomFormStringDropdown _language;
  late final TomFormBoolCheckbox _darkMode;
  late final TomFormBoolSwitch _analytics;

  /// Every field this state owns, for batched disposal.
  late final List<TomField> _fields = [
    _acceptTerms,
    _notifications,
    _mode,
    _sharedCheckbox,
    _sharedSwitch,
    _sharedToggle,
    _displayName,
    _language,
    _darkMode,
    _analytics,
  ];

  /// Cancellers for the `>>` observers registered in [initState].
  final List<void Function()> _observerCancels = [];

  @override
  void initState() {
    super.initState();

    _acceptTerms = TomFormBoolCheckbox('acceptTerms', false,
        labelTextOverride: 'Accept terms');
    _notifications = TomFormBoolSwitch('notify', false,
        labelTextOverride: 'Enable notifications');
    _mode = TomFormBoolToggle('mode', true,
        labelTextOverride: 'Mode',
        onLabelOverride: 'Dark',
        offLabelOverride: 'Light');

    _sharedCheckbox = TomFormBoolCheckbox('shared1', false,
        labelTextOverride: 'Shared (Checkbox)');
    _sharedSwitch = TomFormBoolSwitch('shared2', false,
        labelTextOverride: 'Shared (Switch)');
    _sharedToggle = TomFormBoolToggle('shared3', false,
        labelTextOverride: 'Shared (Toggle)',
        onLabelOverride: 'On',
        offLabelOverride: 'Off');

    void sync(bool v) {
      if (_syncing) return;
      _syncing = true;
      try {
        if (_sharedCheckbox.get() != v) _sharedCheckbox.setValue(v);
        if (_sharedSwitch.get() != v) _sharedSwitch.setValue(v);
        if (_sharedToggle.get() != v) _sharedToggle.setValue(v);
      } finally {
        _syncing = false;
      }
      setState(() {});
    }

    for (final field in <TomField<bool>>[
      _sharedCheckbox,
      _sharedSwitch,
      _sharedToggle,
    ]) {
      final observer = field >> (_) => sync(field.get());
      _observerCancels.add(() => field.removeObserver(observer));
    }

    _displayName = TomFormStringInput('displayName', 'Alexis',
        labelTextOverride: 'Display name');
    _language = TomFormStringDropdown(
      'language',
      'en',
      source: StaticSelectableSource(const [
        SelectableItem(value: 'en', label: 'English'),
        SelectableItem(value: 'fr', label: 'Français'),
        SelectableItem(value: 'de', label: 'Deutsch'),
      ]),
      labelTextOverride: 'Language',
    );
    _darkMode =
        TomFormBoolCheckbox('darkMode', true, labelTextOverride: 'Dark mode');
    _analytics = TomFormBoolSwitch('analytics', false,
        labelTextOverride: 'Anonymous analytics');
  }

  @override
  void dispose() {
    for (final cancel in _observerCancels) {
      cancel();
    }
    _observerCancels.clear();
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(context, 'Independent bool fields'),
          _panel(title: 'Checkbox', children: [_acceptTerms.widget]),
          _panel(title: 'Switch', children: [_notifications.widget]),
          _panel(title: 'Toggle (SegmentedButton<bool>)',
              children: [_mode.widget]),
          _sectionTitle(context,
              'Three concretes kept in lock-step via observer sync'),
          _panel(title: 'Checkbox / Switch / Toggle', children: [
            _sharedCheckbox.widget,
            const SizedBox(height: 4),
            _sharedSwitch.widget,
            const SizedBox(height: 4),
            _sharedToggle.widget,
          ]),
          _sectionTitle(context, 'Settings layout — strings + booleans'),
          _panel(title: 'Profile', children: [
            _displayName.widget,
            const SizedBox(height: 8),
            _language.widget,
            const SizedBox(height: 8),
            _darkMode.widget,
            const SizedBox(height: 8),
            _analytics.widget,
          ]),
        ],
      ),
    );
  }
}

// ===========================================================================
// Demo G — Complex Breakpoint Scenarios
// ===========================================================================

class ComplexBreakpointsDemo extends StatefulWidget {
  const ComplexBreakpointsDemo({super.key});

  @override
  State<ComplexBreakpointsDemo> createState() =>
      _ComplexBreakpointsDemoState();
}

class _ComplexBreakpointsDemoState extends State<ComplexBreakpointsDemo> {
  late final TomFormStringInput _name;
  late final TomFormStringInput _email;
  late final TomFormBoolCheckbox _subscribed;

  @override
  void initState() {
    super.initState();
    _name = TomFormStringInput('name', '', labelTextOverride: 'Name');
    _email = TomFormStringInput('email', '', labelTextOverride: 'Email');
    _subscribed = TomFormBoolCheckbox('subscribed', false,
        labelTextOverride: 'Subscribe to newsletter');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _subscribed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Outer scope — style breakpoints (compact < 480 < comfortable < 900 <
    // spacious).
    return TomFormStyleScope(
      style: _comfortable,
      styleBpOverrides: const [
        (0.0, _compact),
        (480.0, _comfortable),
        (900.0, _spacious),
      ],
      child: LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Demo G — Complex Breakpoint Scenarios.\n'
                    'Current width: ${width.toStringAsFixed(0)}px — '
                    '${_bpLabel(width)} style.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
              _sectionTitle(context, 'Outer-scope breakpoints'),
              _panel(title: 'Fields react to style breakpoints', children: [
                _name.widget,
                const SizedBox(height: 8),
                _email.widget,
                const SizedBox(height: 8),
                _subscribed.widget,
              ]),
              _sectionTitle(context, 'Nested scope — theme-only override'),
              TomFormStyleScope(
                // style: null → fall through to the enclosing scope's style,
                // only apply a theme override here.
                style: null,
                themeSpec: const TomThemeSpec(
                  primary: Color(0xFF2E7D32),
                  secondary: Color(0xFF1B5E20),
                ),
                child: _panel(
                  title: 'Recoloured subtree (same form style)',
                  children: [
                    _name.widget,
                    const SizedBox(height: 8),
                    _subscribed.widget,
                  ],
                ),
              ),
              _sectionTitle(context, 'Two-column → one-column collapse'),
              _panel(title: 'Collapses under 600px', children: [
                _collapseRow(width, _name.widget, _email.widget),
              ]),
            ],
          ),
        );
      }),
    );
  }

  Widget _collapseRow(double width, Widget a, Widget b) {
    if (width < 600) {
      return Column(children: [a, const SizedBox(height: 8), b]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: 12),
        Expanded(child: b),
      ],
    );
  }

  String _bpLabel(double w) {
    if (w < 480) return 'compact';
    if (w < 900) return 'comfortable';
    return 'spacious';
  }
}

const _compact = TomFormStyle(
  defaults: TomFieldStyle(labelFieldGap: 2, errorFieldGap: 2),
);
const _comfortable = TomFormStyle(
  defaults: TomFieldStyle(labelFieldGap: 6, errorFieldGap: 4),
);
const _spacious = TomFormStyle(
  defaults: TomFieldStyle(labelFieldGap: 12, errorFieldGap: 8),
);

// ===========================================================================
// Demo H — Complex Authorization Scenarios
// ===========================================================================

class ComplexAuthDemo extends StatefulWidget {
  const ComplexAuthDemo({super.key});

  @override
  State<ComplexAuthDemo> createState() => _ComplexAuthDemoState();
}

class _ComplexAuthDemoState extends State<ComplexAuthDemo> {
  // Panel 1 — action-icon trigger gated by auth.
  late final TomFormStringInput _search;
  bool _searchFull = true;

  // Panel 2 — UIStateController closures cross-referencing fields.
  late final TomFormStringInput _emailLive;
  late final TomFormStringInput _phoneLive;
  late final TomFormBoolCheckbox _phoneVerified;

  // Panel 3 — three auth groups with different modes.
  late final TomAuthorizationGroup _groupAll;
  late final TomAuthorizationGroup _groupWidest;
  late final TomAuthorizationGroup _groupNarrowest;
  late final List<TomFormStringInput> _groupFields;
  TomAuthState _groupAllState = TomAuthState.full;
  TomAuthState _groupWidestState = TomAuthState.full;
  TomAuthState _groupNarrowestState = TomAuthState.full;

  // Panel 4 — subform auth-as-ceiling.
  TomAuthState _parentAuth = TomAuthState.full;
  late final TomFormStringInput _addrStreet;
  late final TomFormStringInput _addrCity;

  /// Cancellers for the `>>` observers registered in [initState].
  final List<void Function()> _observerCancels = [];

  @override
  void initState() {
    super.initState();

    _search = TomFormStringInput(
      'search',
      '',
      labelTextOverride: 'Search',
      actionIcon: const Icon(Icons.search),
      actionIconTooltip: 'Run search',
      onActionIconPressed: () {},
      authorizer: TomAuthorizer.fixed(TomAuthState.full),
    );

    _emailLive = TomFormStringInput(
      'emailLive',
      '',
      labelTextOverride: 'Email',
      uiStateController: TomUIStateController(resolve: (current, _) {
        // Disable the field when the value doesn't look like an email.
        final v = _emailLive.get();
        if (v.isEmpty) return current;
        return v.contains('@') ? current : TomAuthState.disabled;
      }),
    );
    _phoneVerified = TomFormBoolCheckbox('phoneVerified', false,
        labelTextOverride: 'Phone verified');
    _phoneLive = TomFormStringInput(
      'phoneLive',
      '',
      labelTextOverride: 'Phone',
      uiStateController: TomUIStateController(resolve: (current, _) {
        return _phoneVerified.get() ? TomAuthState.read : current;
      }),
    );
    // Rebuild when either field changes so the controller re-runs.
    for (final field in <TomField>[_emailLive, _phoneLive, _phoneVerified]) {
      final observer = field >> (_) => setState(() {});
      _observerCancels.add(() => field.removeObserver(observer));
    }

    _groupAll = TomAuthorizationGroup('groupAll',
        mode: AuthGroupMode.controlsAll);
    _groupWidest = TomAuthorizationGroup('groupWidest',
        mode: AuthGroupMode.controlsWidest);
    _groupNarrowest = TomAuthorizationGroup('groupNarrowest',
        mode: AuthGroupMode.controlsNarrowest);
    _groupFields = [
      TomFormStringInput('fAll1', '',
          labelTextOverride: 'controlsAll #1', tomGroup: _groupAll),
      TomFormStringInput('fAll2', '',
          labelTextOverride: 'controlsAll #2', tomGroup: _groupAll),
      TomFormStringInput('fW1', '',
          labelTextOverride: 'controlsWidest #1', tomGroup: _groupWidest),
      TomFormStringInput('fW2', '',
          labelTextOverride: 'controlsWidest #2', tomGroup: _groupWidest),
      TomFormStringInput('fN1', '',
          labelTextOverride: 'controlsNarrowest #1',
          tomGroup: _groupNarrowest),
      TomFormStringInput('fN2', '',
          labelTextOverride: 'controlsNarrowest #2',
          tomGroup: _groupNarrowest),
    ];

    _addrStreet = TomFormStringInput(
      'street',
      '',
      labelTextOverride: 'Street',
      authorizer: TomAuthorizer(resolve: (_) => _parentAuth),
    );
    _addrCity = TomFormStringInput(
      'city',
      '',
      labelTextOverride: 'City',
      authorizer: TomAuthorizer(resolve: (_) => _parentAuth),
    );
  }

  @override
  void dispose() {
    for (final cancel in _observerCancels) {
      cancel();
    }
    _observerCancels.clear();
    for (final field in <TomField>[
      _search,
      _emailLive,
      _phoneLive,
      _phoneVerified,
      ..._groupFields,
      _addrStreet,
      _addrCity,
    ]) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(context, 'Action-icon gated by auth'),
          _panel(title: 'Search field', children: [
            Row(children: [
              Checkbox(
                value: _searchFull,
                onChanged: (v) {
                  setState(() {
                    _searchFull = v ?? true;
                    _search.authorizer = TomAuthorizer.fixed(
                      _searchFull ? TomAuthState.full : TomAuthState.read,
                    );
                  });
                },
              ),
              const Text('auth = full (uncheck for read-only)'),
            ]),
            const SizedBox(height: 8),
            _search.widget,
          ]),
          _sectionTitle(context, 'UIStateController cross-field dependency'),
          _panel(
            title: 'Email disables on bad format; phone goes read-only when '
                'verified',
            children: [
              _emailLive.widget,
              const SizedBox(height: 8),
              _phoneVerified.widget,
              const SizedBox(height: 8),
              _phoneLive.widget,
            ],
          ),
          _sectionTitle(context, 'Group controls — all three modes'),
          _panel(title: 'Toggle group auth', children: [
            for (final (label, current, setter) in [
              (
                'controlsAll',
                _groupAllState,
                (TomAuthState s) => setState(() => _groupAllState = s),
              ),
              (
                'controlsWidest',
                _groupWidestState,
                (TomAuthState s) => setState(() => _groupWidestState = s),
              ),
              (
                'controlsNarrowest',
                _groupNarrowestState,
                (TomAuthState s) => setState(() => _groupNarrowestState = s),
              ),
            ])
              Row(children: [
                SizedBox(width: 170, child: Text(label)),
                DropdownButton<TomAuthState>(
                  value: current,
                  onChanged: (state) {
                    if (state == null) return;
                    setter(state);
                    TomAuthorization.adapter =
                        _GroupStateAdapter({
                      _groupAll.groupId: _groupAllState,
                      _groupWidest.groupId: _groupWidestState,
                      _groupNarrowest.groupId: _groupNarrowestState,
                    });
                  },
                  items: const [
                    DropdownMenuItem(
                      value: TomAuthState.full,
                      child: Text('full'),
                    ),
                    DropdownMenuItem(
                      value: TomAuthState.read,
                      child: Text('read'),
                    ),
                    DropdownMenuItem(
                      value: TomAuthState.disabled,
                      child: Text('disabled'),
                    ),
                    DropdownMenuItem(
                      value: TomAuthState.none,
                      child: Text('none'),
                    ),
                  ],
                ),
              ]),
            const SizedBox(height: 8),
            for (final f in _groupFields) ...[
              f.widget,
              const SizedBox(height: 4),
            ],
          ]),
          _sectionTitle(context, 'Subform auth as ceiling'),
          _panel(title: 'Parent narrows child', children: [
            DropdownButton<TomAuthState>(
              value: _parentAuth,
              onChanged: (s) => setState(() => _parentAuth = s!),
              items: const [
                DropdownMenuItem(
                    value: TomAuthState.full, child: Text('Parent: full')),
                DropdownMenuItem(
                    value: TomAuthState.read, child: Text('Parent: read')),
                DropdownMenuItem(
                    value: TomAuthState.disabled,
                    child: Text('Parent: disabled')),
              ],
            ),
            const SizedBox(height: 8),
            _addrStreet.widget,
            const SizedBox(height: 8),
            _addrCity.widget,
          ]),
        ],
      ),
    );
  }
}

/// Routes group ids to auth states for the `TomAuthorizationGroup` demo.
class _GroupStateAdapter extends TomAuthorizationAdapter {
  _GroupStateAdapter(this._states);
  final Map<String, TomAuthState> _states;

  @override
  TomAuthState resolveAuth(String resourceKeyPath) {
    return _states[resourceKeyPath] ?? TomAuthState.full;
  }
}
