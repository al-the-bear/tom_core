part of 'acl_demos.dart';

/// Exercises the `tom_flutter_ui` ACL feature: a complex multi-feature layout
/// combining row alignment, min/preferred sizing, `expandY` fill regions, and
/// container padding in a single [AclBuilder].
class ComplexLayoutDemo extends StatelessWidget {
  const ComplexLayoutDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Complex layout combining multiple features:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ResizableBox(
            initialHeight: 400,
            child: AclBuilder()
                .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.center)
                // setAclScrollableY is intentionally NOT used here — it would
                // make the ACL's Column scrollable, which in turn disables
                // expandY (scrollable rows can't grow into unbounded vertical
                // space). The List Area + Details Panel below rely on expandY
                // to fill the 400 px viewport.
                .setAclPadding(const EdgeInsets.all(8))
                .append(
                  const Text(
                    'Application Form',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                )
                .setRowHorizontalAlignment(RowAlignment.center)
                .newRow(dist: 16)
                .append(const SizedBox(width: 80, child: Text('User:')))
                .setPSize(80, 36)
                .setMSize(50, 36)
                .append(
                  const TextField(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                )
                .setMSize(120, 36)
                .setPSize(200, 36)
                .gap(weight: 1)
                .append(const SizedBox(width: 80, child: Text('Role:')))
                .setPSize(80, 36)
                .setMSize(50, 36)
                .append(
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    hint: const Text('Select'),
                    items: [
                      TomDropdownMenuItem(
                        tomId: 'role.admin',
                        value: 'admin',
                        child: const Text('Admin'),
                      ),
                      TomDropdownMenuItem(
                        tomId: 'role.user',
                        value: 'user',
                        child: const Text('User'),
                      ),
                      TomDropdownMenuItem(
                        tomId: 'role.guest',
                        value: 'guest',
                        child: const Text('Guest'),
                      ),
                    ],
                    onChanged: (_) {},
                  ),
                )
                .setMSize(120, 36)
                .setPSize(180, 36)
                .newRow(dist: 16)
                .append(
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue),
                      color: Colors.blue.shade50,
                    ),
                    child: const Center(
                      child: Text('List Area\n(EXPANDX + EXPANDY)'),
                    ),
                  ),
                )
                .setAttr(AclFlags.expand)
                .append(
                  Container(
                    width: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green),
                      color: Colors.green.shade50,
                    ),
                    child: const Center(
                      child: Text('Details Panel\n(EXPANDY)'),
                    ),
                  ),
                  dist: 8,
                )
                .setAttr(AclFlags.expandY)
                .newRow(dist: 8)
                .append(const Text('Status: Ready'))
                .append(const SizedBox.shrink())
                .setAttr(AclFlags.expandX)
                .append(const Text('v1.0.0'))
                .setRowHorizontalAlignment(RowAlignment.left)
                .build(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Comprehensive Form Demo
// ─────────────────────────────────────────────────────────────────────────────
