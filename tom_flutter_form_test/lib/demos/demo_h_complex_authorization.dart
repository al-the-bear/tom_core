import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_scaffold.dart';
import '../forms/customer_form.dart';
import '../panels/event_log_panel.dart';
import '../panels/field_state_table.dart';
import '../panels/info_panel.dart';
import '../state/phase1_state.dart';

// ---------------------------------------------------------------------------
// Demo H — Complex Authorization Scenarios (Phase 2)
// ---------------------------------------------------------------------------

/// Two-column layout exercising the Phase 2 complex-authorization
/// scenarios described in the spec. Focuses on auth features that Demo B
/// only introduced individually — here they're combined so cross-feature
/// interactions are visible.
///
///   * **Group modes (all three)** — billing / shipping / payments each
///     attached to a group with a distinct mode (controlsAll, controlsWidest,
///     controlsNarrowest). A dropdown on the right sets each group's state;
///     the field-state table on the right makes the mode's effect on each
///     member visible.
///   * **UIStateController closures** — email narrows to disabled when
///     phone is empty; phone narrows to read when `lockPhone` is on.
///     Demonstrates build-time, data-dependent auth narrowing from two
///     different sources stacked on the same field.
///   * **Subform auth as ceiling** — a parent-form auth override (set via
///     the panel) narrows every field inside billing and shipping, even
///     when the per-field resource auth is still `full`.
///   * **Event log** — every value / auth transition lights up the log so
///     the interactions are traceable.
///
/// Phase 2 will extend this demo with the ActionAuth hide-unauthorized
/// re-use and bool / multi-select-aware groups. The scaffold already has
/// room for both in the controls column.
class DemoHComplexAuthorization extends StatefulWidget {
  const DemoHComplexAuthorization({super.key});

  @override
  State<DemoHComplexAuthorization> createState() =>
      _DemoHComplexAuthorizationState();
}

class _DemoHComplexAuthorizationState extends State<DemoHComplexAuthorization>
    with TomFormEventListener {
  late final _DemoHAdapter _adapter;

  CustomerForm? _form;
  final _inspector = TomFormInspector();

  // Group-state dropdown controls — one per group.
  TomAuthState _billingAuth = TomAuthState.full;
  TomAuthState _shippingAuth = TomAuthState.full;
  TomAuthState _formAuth = TomAuthState.full;

  bool _lockPhone = false;
  bool _uiStateControllerOn = false;

  @override
  void initState() {
    super.initState();
    _adapter = _DemoHAdapter();
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

  @override
  void onFieldValueChanged(FieldValueChangedEvent event) {
    if (mounted) setState(() {});
  }

  void _rebuildForm() {
    _form?.removeListener(this);
    _form?.removeListener(_inspector);
    _form?.dispose();

    // Billing — controlsAll: group state replaces every member.
    // Shipping — controlsWidest (default): group state is the ceiling.
    final billingGroup =
        TomAuthorizationGroup('billing', mode: AuthGroupMode.controlsAll);
    final shippingGroup = TomAuthorizationGroup('shipping',
        mode: AuthGroupMode.controlsWidest);

    final form = TomScope.withScope(
      'demoH',
      () => CustomerForm(
        billingGroup: billingGroup,
        shippingGroup: shippingGroup,
      ),
    );
    _applyUIStateControllers(form);
    form.addListener(this);
    form.addListener(_inspector);
    form.bind(phase1CustomerState);
    form.billing.bind(phase1CustomerState.billing);
    form.shipping.bind(phase1CustomerState.shipping);

    _form = form;
    setState(() {});
  }

  void _applyUIStateControllers(CustomerForm form) {
    if (_uiStateControllerOn) {
      // email narrows to disabled while phone is empty.
      form.email.uiStateController = TomUIStateController(
        resolve: (currentAuth, _) =>
            form.phone.get().trim().isEmpty
                ? TomAuthState.disabled
                : currentAuth,
      );
      // phone narrows to read while the _lockPhone toggle is on.
      form.phone.uiStateController = TomUIStateController(
        resolve: (currentAuth, _) =>
            _lockPhone ? TomAuthState.read : currentAuth,
      );
    } else {
      form.email.uiStateController = null;
      form.phone.uiStateController = null;
    }
  }

  // --- Panel callbacks ------------------------------------------------------

  void _setAuth(String path, TomAuthState state) {
    if (state == TomAuthState.full) {
      _adapter.removeRule(path);
    } else {
      _adapter.setRule(path, state);
    }
    setState(() {});
  }

  void _onBillingAuthChanged(TomAuthState s) {
    setState(() => _billingAuth = s);
    _setAuth('demoH.customer.billing', s);
  }

  void _onShippingAuthChanged(TomAuthState s) {
    setState(() => _shippingAuth = s);
    _setAuth('demoH.customer.shipping', s);
  }

  void _onFormAuthChanged(TomAuthState s) {
    setState(() => _formAuth = s);
    _setAuth('demoH.customer', s);
  }

  void _onLockPhoneToggled(bool v) {
    setState(() => _lockPhone = v);
    final form = _form;
    if (form != null) _applyUIStateControllers(form);
  }

  void _onUIStateToggled(bool v) {
    setState(() => _uiStateControllerOn = v);
    final form = _form;
    if (form != null) _applyUIStateControllers(form);
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Demo H — Complex Authorization Scenarios',
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
              _section(
                context,
                'Customer (top-level fields)',
                _buildTopFields(context, form),
              ),
              const SizedBox(height: 12),
              _section(
                context,
                'Billing — group mode: controlsAll',
                _buildBillingFields(context, form),
              ),
              const SizedBox(height: 12),
              _section(
                context,
                'Shipping — group mode: controlsWidest',
                _buildShippingFields(context, form),
              ),
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
            const _Bullet('Three group modes active side-by-side — billing '
                'controlsAll, shipping controlsWidest. Each group has its '
                'own dropdown in the controls column on the right.'),
            const _Bullet('UIStateController stack: email disables while '
                'phone is empty; phone narrows to read while "lockPhone" '
                'is on. Both controllers wired through the same form.'),
            const _Bullet('Subform auth as ceiling — the "form-level auth" '
                'dropdown narrows every field beneath "demoH.customer", '
                'even though per-resource auth stays full.'),
            const _Bullet('Field-state table on the right surfaces the '
                'computed effectiveAuthState per field in real time.'),
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

  Widget _buildTopFields(BuildContext context, CustomerForm form) {
    return TomAclBuilder(id: 'demoHTop', elementProvider: form)
        .setAclExpandXDefault(true)
        .append((p) => p.fullName.widget)
        .newRow()
        .append((p) => p.email.widget)
        .append((p) => p.phone.widget, dist: 16)
        .build(context);
  }

  Widget _buildBillingFields(BuildContext context, CustomerForm form) {
    return TomAclBuilder(id: 'demoHBilling', elementProvider: form.billing)
        .setAclExpandXDefault(true)
        .append((p) => p.street.widget)
        .newRow()
        .append((p) => p.city.widget)
        .append((p) => p.zipCode.widget, dist: 16)
        .build(context);
  }

  Widget _buildShippingFields(BuildContext context, CustomerForm form) {
    return TomAclBuilder(id: 'demoHShipping', elementProvider: form.shipping)
        .setAclExpandXDefault(true)
        .append((p) => p.street.widget)
        .newRow()
        .append((p) => p.city.widget)
        .append((p) => p.zipCode.widget, dist: 16)
        .build(context);
  }

  Widget _buildInfoColumn(BuildContext context) {
    final form = _form;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoPanel(
          title: 'Group / form controls',
          children: [
            const InfoPanelHeading('Form-level auth (ceiling)'),
            _authDropdown(_formAuth, _onFormAuthChanged),
            const InfoPanelHeading('Billing group (controlsAll)'),
            _authDropdown(_billingAuth, _onBillingAuthChanged),
            const InfoPanelHeading('Shipping group (controlsWidest)'),
            _authDropdown(_shippingAuth, _onShippingAuthChanged),
            const InfoPanelHeading('UIStateController stack'),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Controllers on'),
              subtitle: const Text(
                'email disables while phone empty; phone narrows to read '
                'while lockPhone is on',
                style: TextStyle(fontSize: 11),
              ),
              value: _uiStateControllerOn,
              onChanged: _onUIStateToggled,
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('lockPhone'),
              value: _lockPhone,
              onChanged: _uiStateControllerOn ? _onLockPhoneToggled : null,
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

  Widget _authDropdown(
      TomAuthState current, ValueChanged<TomAuthState> onChanged) {
    return DropdownButton<TomAuthState>(
      isExpanded: true,
      value: current,
      items: [
        for (final s in TomAuthState.values)
          DropdownMenuItem(value: s, child: Text(s.name)),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Local adapter — parent-path matching so setting `demoH.customer` narrows
// every field beneath it (form-level auth ceiling).
// ---------------------------------------------------------------------------

class _DemoHAdapter extends TomAuthorizationAdapter {
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

  void setRule(String path, TomAuthState s) => _rules[path] = s;
  void removeRule(String path) => _rules.remove(path);
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text('• $text'),
    );
  }
}
