import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../state/phase2a_state.dart';
import 'example_list_screen.dart';
import 'forms/example_customer_form.dart';
import 'shared/example_authorization.dart';
import 'shared/example_scaffold.dart';

// ---------------------------------------------------------------------------
// Example H-A — Master / Detail (Material + Cupertino in one file)
// ---------------------------------------------------------------------------
//
// This is example code, not a demo: no event log, no inspector, no control
// panel. Everything you see is what you would write in your own app to get
// a master-detail customer editor that:
//
//   * Pulls field labels and panel titles from a static resource map
//     (`example.customer.*`, see `shared/example_resources.dart`)
//   * Resolves per-field authorization through a static auth map
//     (`example.customer.email` is read-only, `example.customer.tier` is
//     disabled — see `shared/example_authorization.dart`)
//   * Reflows the layout at the 700 px breakpoint:
//       - The detail pane stacks `phone` + `company` vertically when narrow
//         and lays them out side-by-side when wide (driven by an
//         `AclBuilder` row with a breakpoint override).
//       - The master pane shows only the customer's name when narrow and
//         adds the company subtitle when wide.
//   * Binds the same `Customer` state class shared across all Phase 2a
//     master-detail demos — observable state at its simplest.
//
// The Material and Cupertino variants are the same file: switching the
// constructor's `family` parameter swaps every field widget through
// `FormFieldFamily`. The pedagogical point is that *application code* does
// not branch on family.
class ExampleHAMasterDetail extends StatefulWidget {
  const ExampleHAMasterDetail({super.key, required this.family});

  final ExampleFamily family;

  @override
  State<ExampleHAMasterDetail> createState() => _ExampleHAMasterDetailState();
}

class _ExampleHAMasterDetailState extends State<ExampleHAMasterDetail> {
  late final ExampleCustomerListForm _listForm;
  late final FormFieldFamily _family;

  @override
  void initState() {
    super.initState();
    // Install the static auth adapter so per-field auth (email, tier) takes
    // effect inside this screen. Other screens may install their own.
    installExampleAuthorization();

    _family = widget.family == ExampleFamily.cupertino
        ? FormFieldFamily.cupertino
        : FormFieldFamily.material;

    _listForm = ExampleCustomerListForm(family: _family);
    _listForm.bind(phase2aCustomers.customers);
  }

  @override
  void dispose() {
    _listForm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final familyLabel = widget.family == ExampleFamily.cupertino
        ? 'Cupertino'
        : 'Material';

    // Wrap the whole screen in a TomFormStyleScope so breakpoint overrides
    // resolve against the actual viewport width. The Cupertino variant pins
    // the style to the Cupertino preset so all fields render natively.
    return TomFormStyleScope(
      style: widget.family == ExampleFamily.cupertino
          ? TomCupertinoFormStyle.cupertino
          : null,
      child: ExampleScaffold(
        title: 'Example H-A · $familyLabel',
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: TomMasterDetailListForm<Customer, ExampleCustomerForm>(
            listForm: _listForm,
            masterPaneWidth: 240,
            draggableSplitter: true,
            minMasterPaneWidth: 160,
            maxMasterPaneWidth: 600,
            initialSelectedIndex: 0,
            masterBuilder: (context, listForm, selected, selectIndex) =>
                _MasterPane(
              listForm: listForm,
              selectedIndex: selected,
              selectIndex: selectIndex,
            ),
            detailBuilder: (context, _, rowForm) => _DetailPane(form: rowForm),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Master pane — list of customers + standard toolbar.
//
// Demonstrates a "more info as wider" master pane: the row's subtitle line
// is only shown when the master column is at least 220 px wide.
// ---------------------------------------------------------------------------
class _MasterPane extends StatelessWidget {
  const _MasterPane({
    required this.listForm,
    required this.selectedIndex,
    required this.selectIndex,
  });

  final TomListForm<Customer, ExampleCustomerForm> listForm;
  final int? selectedIndex;
  final Future<void> Function(int? index) selectIndex;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showSubtitle = constraints.maxWidth >= 220;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                  child: Text(
                    'Customers (${listForm.length})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const Divider(height: 8),
                Expanded(
                  child: TomInlineListForm<Customer, ExampleCustomerForm>(
                    listForm: listForm,
                    reorderable: true,
                    rowBuilder: (context, i, rowForm) => _CustomerListTile(
                      key: ValueKey('example-h-a-${rowForm.hashCode}'),
                      customer: rowForm.currentBinding,
                      index: i,
                      isSelected: i == selectedIndex,
                      showSubtitle: showSubtitle,
                      onTap: () => selectIndex(i),
                    ),
                  ),
                ),
                const Divider(height: 8),
                TomListFormToolbar<Customer, ExampleCustomerForm>(
                  listForm: listForm,
                  selectedIndex: selectedIndex,
                  onSelectionChanged: selectIndex,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CustomerListTile extends StatelessWidget {
  const _CustomerListTile({
    super.key,
    required this.customer,
    required this.index,
    required this.isSelected,
    required this.showSubtitle,
    required this.onTap,
  });

  final Customer? customer;
  final int index;
  final bool isSelected;
  final bool showSubtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = customer;
    if (c == null) return const ListTile(title: Text('(unbound)'));
    return TomMultiObservableBuilder(
      observables: [c.fullName, c.company],
      builder: (context) {
        return ListTile(
          dense: true,
          selected: isSelected,
          leading: TomReorderHandle(index: index),
          title: Text(
            c.fullName.get().isEmpty ? '(unnamed)' : c.fullName.get(),
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: showSubtitle
              ? Text(c.company.get(), overflow: TextOverflow.ellipsis)
              : null,
          onTap: onTap,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Detail pane — the row's own sub-form rendered through AclBuilder.
//
// The interesting line below is the row that holds `phone` + `company`: by
// default they sit side-by-side, but the breakpoint override tells the
// builder to stack them vertically when the available width drops below
// 700 px. This is the per-row breakpoint API at its smallest possible
// surface area.
// ---------------------------------------------------------------------------
class _DetailPane extends StatelessWidget {
  const _DetailPane({required this.form});

  final ExampleCustomerForm form;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ListenableBuilder(
          listenable: form.changes,
          builder: (context, _) {
            final acl = AclBuilder()
              ..setAclDefaultAppendGap(8)
              ..setAclExpandXDefault(true);

            acl.append(form.fullName.widget);

            acl.newRow();
            acl.append(form.email.widget);

            // Row that flips between side-by-side (>= 700 px) and stacked
            // (< 700 px). `addRowBreakpoint` records the split point on
            // the row currently under construction — when the container
            // width drops below `atWidth` the builder reflows the row so
            // each child sits on its own line.
            acl.newRow();
            acl.append(form.phone.widget);
            acl.append(form.company.widget);
            acl.addRowBreakpoint(atWidth: 700);

            acl.newRow();
            acl.append(form.tier.widget);

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Detail (formId: ${form.formId})',
                          style: Theme.of(context).textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (form.isDirty)
                        const Chip(
                          label: Text('Dirty'),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  acl.build(),
                  const SizedBox(height: 12),
                  TomErrorView(form: form, title: 'Detail form errors'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.icon(
                        icon: const Icon(Icons.save, size: 16),
                        label: const Text('Save'),
                        onPressed: () => form.save(),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.undo, size: 16),
                        label: const Text('Discard'),
                        onPressed: () => form.discard(),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
