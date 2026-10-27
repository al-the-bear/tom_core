import 'package:flutter/material.dart';

import 'example_h_a_master_detail.dart';
import 'example_h_b_expandable_rows.dart';
import 'example_h_c_editable_table.dart';
import 'example_h_d_customer_form.dart';
import 'example_h_e_read_only.dart';

/// Top-level "Examples" tab content.
///
/// Examples are stripped-down sample code intended for developers to read
/// and lift into their own apps. Each demo from H-A through H-E is shown
/// in two flavours — Material and Cupertino — to make the family-specific
/// idioms visible side-by-side.
class ExampleListScreen extends StatelessWidget {
  const ExampleListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Header(),
        const SizedBox(height: 12),
        _SectionHeader(label: 'H-A — Master / Detail'),
        _ExampleTile(
          icon: Icons.view_sidebar_outlined,
          title: 'Example H-A · Material',
          description:
              'Master-detail customer editor — Material field family. '
              'AclBuilder rows, breakpoint-aware master pane, static auth + '
              'resources from a constant map.',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  const ExampleHAMasterDetail(family: ExampleFamily.material),
            ),
          ),
        ),
        _ExampleTile(
          icon: Icons.phone_iphone,
          title: 'Example H-A · Cupertino',
          description: 'Same master-detail editor — Cupertino field family.',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  const ExampleHAMasterDetail(family: ExampleFamily.cupertino),
            ),
          ),
        ),
        _SectionHeader(label: 'H-B — Expandable rows'),
        _ExampleTile(
          icon: Icons.unfold_more,
          title: 'Example H-B · Material',
          description:
              'Customer orders rendered with TomExpandableListForm: '
              'collapsible rows, drag reorder, and an editable items '
              'list inside each open row.',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  const ExampleHBExpandableRows(family: ExampleFamily.material),
            ),
          ),
        ),
        _ExampleTile(
          icon: Icons.unfold_more,
          title: 'Example H-B · Cupertino',
          description: 'Same expandable orders list — Cupertino field family.',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ExampleHBExpandableRows(
                family: ExampleFamily.cupertino,
              ),
            ),
          ),
        ),
        _SectionHeader(label: 'H-C — Editable table'),
        _ExampleTile(
          icon: Icons.table_rows_outlined,
          title: 'Example H-C · Material',
          description:
              'Editable items table with int / double inputs, derived '
              'line totals, drag reorder, and a 720 px breakpoint that '
              'reflows columns into stacked cards on narrow viewports.',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  const ExampleHCEditableTable(family: ExampleFamily.material),
            ),
          ),
        ),
        _ExampleTile(
          icon: Icons.table_rows_outlined,
          title: 'Example H-C · Cupertino',
          description: 'Same editable items table — Cupertino field family.',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  const ExampleHCEditableTable(family: ExampleFamily.cupertino),
            ),
          ),
        ),
        _SectionHeader(label: 'H-D — Full customer form'),
        _ExampleTile(
          icon: Icons.person_outline,
          title: 'Example H-D · Material',
          description:
              'Rich customer form covering every field family: string, '
              'search, bool, int, double, date, plus address and order '
              'master-detail sub-lists. AclBuilder rows reflow at 700 px.',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  const ExampleHDCustomerForm(family: ExampleFamily.material),
            ),
          ),
        ),
        _ExampleTile(
          icon: Icons.person_outline,
          title: 'Example H-D · Cupertino',
          description: 'Same rich customer form — Cupertino field family.',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  const ExampleHDCustomerForm(family: ExampleFamily.cupertino),
            ),
          ),
        ),
        _SectionHeader(label: 'H-E — Read-only with edit dialogs'),
        _ExampleTile(
          icon: Icons.receipt_long_outlined,
          title: 'Example H-E · Material',
          description:
              'Same data graph as H-D rendered as compact read-only rows. '
              'Per-row Edit buttons open modal forms; Save commits, Cancel '
              'discards through the underlying observable.',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  const ExampleHEReadOnly(family: ExampleFamily.material),
            ),
          ),
        ),
        _ExampleTile(
          icon: Icons.receipt_long_outlined,
          title: 'Example H-E · Cupertino',
          description:
              'Same read-only customer + edit dialogs — Cupertino fields.',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  const ExampleHEReadOnly(family: ExampleFamily.cupertino),
            ),
          ),
        ),
      ],
    );
  }
}

/// Pedagogically-relevant build-time choice exposed by every example file.
///
/// Each example screen is constructed with a single [family] parameter, and
/// every field widget inside it is created via the matching
/// [TomFormFieldFamily] factory. Switching families is the *only* difference
/// between the Material and Cupertino versions of an example — the layout
/// code, the form definition, and the state binding are all family-agnostic.
enum ExampleFamily { material, cupertino }

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Examples', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Stripped-down sample code: no event log, no inspector, no '
              'control panels. Each example reads like the application code '
              'a developer would actually write. Resources, authorization, '
              'breakpoints, observable state and list forms are all '
              'demonstrated end-to-end.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _ExampleTile extends StatelessWidget {
  const _ExampleTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
