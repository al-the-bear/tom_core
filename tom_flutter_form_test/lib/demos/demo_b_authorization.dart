import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_scaffold.dart';
import '../forms/customer_form.dart';
import '../panels/auth_control_panel.dart';
import '../panels/event_log_panel.dart';
import '../panels/field_state_table.dart';
import '../panels/info_panel.dart';
import '../state/phase1_state.dart';
import 'demo_widgets.dart';

// ---------------------------------------------------------------------------
// Demo B — Authorization & Events (Phase 1)
// ---------------------------------------------------------------------------

/// Two-column layout: customer form on the left; authorization controls and
/// event log on the right. Exercises every feature from §24b Demo B:
///
///   * Four auth states: `full`, `read`, `disabled`, `none` — toggled from
///     the right-hand panel.
///   * `TomAuthorizationGroup` with all three [AuthGroupMode]s — switching
///     modes rebuilds the form with newly-constructed groups (mode is
///     immutable on the group, so a swap is the clean way to demonstrate it).
///   * `TomAuthorizer` — narrows the `customerTier` field to read when the
///     "authorizer" switch is on (simulates a finalized-order lockdown).
///   * `TomUIStateController` — narrows the `email` field to disabled while
///     `notes` is empty (data-dependent build-time narrowing).
///   * Form-level auth ceiling — selecting `read` at the form level narrows
///     every field; the field-state table reflects this in real time.
///   * Event log streams every `TomFormEvent` including `FieldAuthChangedEvent`
///     when auth transitions fire (via `form.changes` rebuild).
class DemoBAuthorization extends StatefulWidget {
  const DemoBAuthorization({super.key});

  @override
  State<DemoBAuthorization> createState() => _DemoBAuthorizationState();
}

class _DemoBAuthorizationState extends State<DemoBAuthorization>
    with TomFormEventListener {
  // --- Auth adapter (owned by this demo) -----------------------------------
  late final _DemoBAdapter _adapter;

  // --- Form + inspector ----------------------------------------------------
  CustomerForm? _form;
  final _inspector = TomFormInspector();

  // --- Panel state ---------------------------------------------------------
  TomAuthState _formAuth = TomAuthState.full;
  AuthGroupMode _billingMode = AuthGroupMode.controlsWidest;
  AuthGroupMode _shippingMode = AuthGroupMode.controlsWidest;
  String _selectedGroupId = 'billing';

  // Per-field override tracking (for panel display).
  final Map<String, TomAuthState> _fieldOverrides = {
    'demoB.customer.fullName': TomAuthState.full,
    'demoB.customer.email': TomAuthState.full,
    'demoB.customer.phone': TomAuthState.full,
    'demoB.customer.customerTier': TomAuthState.full,
    'demoB.customer.billing': TomAuthState.full,
    'demoB.customer.shipping': TomAuthState.full,
  };

  bool _authorizerEnabled = false;
  bool _uiStateControllerEnabled = false;

  // Per-field FieldAuthChangedEvent tracking — we synthesise these events
  // manually since `resolveEffectiveAuth` is pull-based.
  final Map<String, TomAuthState> _lastAuthSeen = {};

  @override
  void initState() {
    super.initState();
    _adapter = _DemoBAdapter();
    TomAuthorization.adapter = _adapter;
    _rebuildForm();
  }

  @override
  void dispose() {
    _form?.removeListener(this);
    _form?.removeListener(_inspector);
    _form?.dispose();
    super.dispose();
  }

  // --- TomFormEventListener -------------------------------------------------
  //
  // Demo B listens for value-change events through the form's built-in
  // event system instead of wiring manual `>>` observers on individual
  // TomObservables. TomForm holds listeners by strong reference, so we
  // don't have to baby-sit them to keep them alive; the Classic-field
  // bypass problem also goes away because FieldValueChangedEvent is only
  // fired through `setValue`, which every spec-aligned field routes user
  // input through.

  @override
  void onFieldValueChanged(FieldValueChangedEvent event) {
    _snapshotAuthAndRebuild();
  }

  /// Rebuild the form (required whenever a group mode changes — the mode is
  /// final on [TomAuthorizationGroup], so we construct fresh groups).
  void _rebuildForm() {
    _form?.removeListener(this);
    _form?.removeListener(_inspector);
    _form?.dispose();

    final billingGroup =
        TomAuthorizationGroup('billing', mode: _billingMode);
    final shippingGroup =
        TomAuthorizationGroup('shipping', mode: _shippingMode);

    final form = TomScope.withScope(
      'demoB',
      () => CustomerForm(
        billingGroup: billingGroup,
        shippingGroup: shippingGroup,
      ),
    );
    _applyAuthorizer(form);
    _applyUIStateController(form);
    // Subscribe via the form's built-in event bus — addListener keeps a
    // strong reference, so we don't need to hand-baby-sit observers.
    form.addListener(this);
    form.addListener(_inspector);
    // TomForm.bind now recurses into every nested TomForm, so a single
    // call seeds billing + shipping lifecycle state too.
    form.bind(phase1CustomerState);

    _form = form;
    _snapshotAuthAndRebuild();
  }

  /// Emit `FieldAuthChangedEvent` entries for every field whose effective
  /// auth state changed since the last call. Keeps the event log in sync
  /// with auth transitions that happen outside the observable value stream.
  void _snapshotAuthAndRebuild() {
    final form = _form;
    if (form == null) return;
    void scanFields(TomForm f) {
      for (final field in f.fields.values) {
        final path = field.basePath;
        final newState = field.effectiveAuthState;
        final previous = _lastAuthSeen[path];
        if (previous != null && previous != newState) {
          _inspector.onFieldAuthChanged(FieldAuthChangedEvent(
            source: field.tomId,
            oldState: previous,
            newState: newState,
          ));
        }
        _lastAuthSeen[path] = newState;
      }
    }

    scanFields(form);
    scanFields(form.billing);
    scanFields(form.shipping);
    if (mounted) setState(() {});
  }

  /// Applies or removes the demo authorizer on billing + shipping fields in
  /// place. Mutating the existing form's fields (instead of rebuilding the
  /// whole form) preserves every field widget's State, so the TextField
  /// rebuilds with the new `enabled` value instead of remaining wired to a
  /// disposed field instance.
  void _applyAuthorizer(CustomerForm form) {
    if (_authorizerEnabled) {
      // "Finalized orders → read-only": when customerTier == 'platinum',
      // narrow the address sections to read via authorizerNarrowsOnly.
      final authorizer = TomAuthorizer(
        strategy: TomAuthorizerStrategy.authorizerNarrowsOnly,
        resolve: (resourceAuth) =>
            form.customerTier.get() == 'platinum'
                ? TomAuthState.read
                : resourceAuth,
      );
      for (final f in form.billing.fields.values) {
        f.authorizer = authorizer;
      }
      for (final f in form.shipping.fields.values) {
        f.authorizer = authorizer;
      }
    } else {
      for (final f in form.billing.fields.values) {
        f.authorizer = null;
      }
      for (final f in form.shipping.fields.values) {
        f.authorizer = null;
      }
    }
  }

  void _applyUIStateController(CustomerForm form) {
    if (_uiStateControllerEnabled) {
      // "Disable email while phone is empty" — contrived, but exercises
      // the build-time, data-dependent narrowing. The dependency on
      // `phone` (a spec-aligned TomFormStringInput) instead of the Classic
      // `notes` field keeps the observer chain clean: spec fields route
      // user input through setValue, which reliably fires
      // FieldValueChangedEvent + notifyObservers, whereas Classic fields
      // update their TomObject through a controller listener that has
      // timing quirks inside a nested form tree.
      form.email.uiStateController = TomUIStateController(
        resolve: (currentAuth, _) {
          if (form.phone.get().trim().isEmpty) {
            return TomAuthState.disabled;
          }
          return currentAuth;
        },
      );
    } else {
      form.email.uiStateController = null;
    }
  }

  // --- Control-panel callbacks ---------------------------------------------

  void _onFormAuthChanged(TomAuthState s) {
    setState(() => _formAuth = s);
    if (s == TomAuthState.full) {
      _adapter.removeRule('demoB.customer');
    } else {
      _adapter.setRule('demoB.customer', s);
    }
    _snapshotAuthAndRebuild();
  }

  void _onGroupSelected(String id) =>
      setState(() => _selectedGroupId = id);

  void _onGroupModeChanged(AuthGroupMode mode) {
    setState(() {
      if (_selectedGroupId == 'billing') {
        _billingMode = mode;
      } else {
        _shippingMode = mode;
      }
    });
    _rebuildForm();
  }

  void _onFieldOverrideChanged(String path, TomAuthState state) {
    setState(() => _fieldOverrides[path] = state);
    if (state == TomAuthState.full) {
      _adapter.removeRule(path);
    } else {
      _adapter.setRule(path, state);
    }
    _snapshotAuthAndRebuild();
  }

  void _onAuthorizerToggled(bool enabled) {
    setState(() => _authorizerEnabled = enabled);
    final form = _form;
    if (form != null) _applyAuthorizer(form);
    _snapshotAuthAndRebuild();
  }

  void _onUIStateControllerToggled(bool enabled) {
    setState(() => _uiStateControllerEnabled = enabled);
    final form = _form;
    if (form != null) _applyUIStateController(form);
    _snapshotAuthAndRebuild();
  }

  AuthGroupMode get _currentGroupMode =>
      _selectedGroupId == 'billing' ? _billingMode : _shippingMode;

  // --- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Demo B — Authorization & Events',
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
    final form = _form;
    if (form == null) return const SizedBox.shrink();

    final layout = TomAclBuilder(
      id: 'demoBLayout',
      elementProvider: form,
    )
        .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.top)
        .setAclExpandXDefault(true)
        .append((p) => p.fullName.widget)
        .newRow()
        .append((p) => p.email.widget)
        .append((p) => p.phone.widget, dist: 16)
        .newRow()
        .append((p) => p.customerTier.widget)
        .newRow()
        .append((p) => p.notes.widget)
        .build(context);

    final billingLayout = TomAclBuilder(
      id: 'demoBBilling',
      elementProvider: form.billing,
    )
        .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.top)
        .setAclExpandXDefault(true)
        .append((p) => p.street.widget)
        .newRow()
        .append((p) => p.city.widget)
        .append((p) => p.state.widget, dist: 16)
        .newRow()
        .append((p) => p.zipCode.widget)
        .append((p) => p.country.widget, dist: 16)
        .build(context);

    final shippingLayout = TomAclBuilder(
      id: 'demoBShipping',
      elementProvider: form.shipping,
    )
        .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.top)
        .setAclExpandXDefault(true)
        .append((p) => p.street.widget)
        .newRow()
        .append((p) => p.city.widget)
        .append((p) => p.state.widget, dist: 16)
        .newRow()
        .append((p) => p.zipCode.widget)
        .append((p) => p.country.widget, dist: 16)
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
              layout,
              const SizedBox(height: 12),
              _section(context, 'Billing address', billingLayout),
              const SizedBox(height: 12),
              _section(context, 'Shipping address', shippingLayout),
            ],
          ),
        ),
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
            const DemoBullet('Four auth states per field; form-level ceiling '
                'narrows everything at once.'),
            const DemoBullet('Billing and shipping live in dedicated '
                'TomAuthorizationGroups — pick a group on the right to '
                'toggle its mode (controlsAll / controlsWidest / controlsNarrowest).'),
            const DemoBullet('TomAuthorizer: when on, customer tier "platinum" '
                'narrows both address sections to read.'),
            const DemoBullet('TomUIStateController: when on, email is disabled '
                'until the phone field is non-empty.'),
            const DemoBullet('Every transition shows up in the event log — '
                'value changes, validations, and synthetic '
                'FieldAuthChangedEvent entries emitted on auth swaps.'),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, Widget child) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(BuildContext context) {
    final form = _form;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoPanel(
          title: 'Authorization controls',
          children: [
            AuthControlPanel(
              formAuth: _formAuth,
              onFormAuthChanged: _onFormAuthChanged,
              groupIds: const ['billing', 'shipping'],
              selectedGroupId: _selectedGroupId,
              onGroupSelected: _onGroupSelected,
              groupMode: _currentGroupMode,
              onGroupModeChanged: _onGroupModeChanged,
              fieldOverrides: _fieldOverrides,
              onFieldOverrideChanged: _onFieldOverrideChanged,
              authorizerEnabled: _authorizerEnabled,
              onAuthorizerToggled: _onAuthorizerToggled,
              uiStateControllerEnabled: _uiStateControllerEnabled,
              onUIStateControllerToggled: _onUIStateControllerToggled,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (form != null)
          InfoPanel(
            title: 'Field state',
            children: [
              FieldStateTable(forms: [form, form.billing, form.shipping]),
            ],
          ),
        const SizedBox(height: 12),
        if (form != null)
          InfoPanel(
            title: 'Event log',
            children: [
              EventLogPanel(
                inspector: _inspector,
                rebuildOn: Listenable.merge(
                  [form.changes, form.billing.changes, form.shipping.changes],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Local auth adapter — rules can be added / removed at runtime via the
// control panel. Parent-path matching means `demoB.customer` narrows every
// field beneath it, exercising the "form-level auth ceiling" from §24b.
// ---------------------------------------------------------------------------

class _DemoBAdapter extends TomAuthorizationAdapter {
  final Map<String, TomAuthState> _rules = {};

  @override
  TomAuthState resolveAuth(String resourceKeyPath) {
    if (_rules.containsKey(resourceKeyPath)) return _rules[resourceKeyPath]!;
    final parts = resourceKeyPath.split('.');
    for (var i = parts.length - 1; i > 0; i--) {
      final parent = parts.sublist(0, i).join('.');
      if (_rules.containsKey(parent)) return _rules[parent]!;
    }
    return TomAuthState.full;
  }

  void setRule(String path, TomAuthState state) => _rules[path] = state;
  void removeRule(String path) => _rules.remove(path);
}
