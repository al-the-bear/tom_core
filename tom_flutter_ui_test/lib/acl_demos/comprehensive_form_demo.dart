part of 'acl_demos.dart';

class ComprehensiveFormDemo extends StatelessWidget {
  const ComprehensiveFormDemo({super.key});

  static const double _lw = 110.0; // label column fixed width
  static const double _fMin = 100.0; // field minimum width

  @override
  Widget build(BuildContext context) {
    // Reference widgets — same widget instance used as child AND alignment ref
    final projectCodeField = const TextField(
      decoration: InputDecoration(
        labelText: 'PRJ-001',
        border: OutlineInputBorder(),
        isDense: true,
      ),
    );
    final budgetField = const TextField(
      decoration: InputDecoration(
        labelText: '0.00',
        border: OutlineInputBorder(),
        isDense: true,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Comprehensive Form — 2-column aligned layout, horizontal gap() slots, '
          'vertical gapRow() with separators, and cross-row right-edge alignment.',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Resize the window: all fields grow/shrink. '
          '"Duration" field right-aligns to "Code" field above it. '
          '"Approver" field right-aligns to "Budget" field above it.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        ResizableBox(
          initialHeight: 500,
          showBorder: false,
          child: AclBuilder(
            title: 'New Project Request',
            borderStyle: const AclBorderStyle.solid(
              color: Colors.blueGrey,
              lineWidth: 1.5,
              rounded: true,
              borderRadius: 8,
            ),
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
          )
              .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.center)
        // ── Section heading ────────────────────────────────────────────────
        .append(const Text(
          'Project Details',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.blueGrey),
        ))
        .gapRow(weight: 1)

        // ── Row: Project Name | Code ───────────────────────────────────────
        .append(const SizedBox(width: _lw, child: Text('Project Name')))
        .setPSize(_lw, 0).setMSize(70, 0)
        .append(const TextField(
          decoration: InputDecoration(
            labelText: 'Full project name',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ))
        .setMSize(_fMin, 36).setPSize(280, 36).setAttr(AclFlags.expandX)
        .append(const SizedBox(width: 70, child: Text('Code')), dist: 16)
        .setPSize(70, 0).setMSize(50, 0)
        .append(projectCodeField) // ← alignment reference
        .setPSize(120, 36).setMSize(80, 36).setXSize(150, 36)

        // ── Row: Department | Priority ─────────────────────────────────────
        .newRow(dist: 10)
        .append(const SizedBox(width: _lw, child: Text('Department')))
        .setPSize(_lw, 0).setMSize(70, 0)
        .append(const TextField(
          decoration: InputDecoration(
            labelText: 'e.g. Engineering',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ))
        .setMSize(_fMin, 36).setPSize(280, 36).setAttr(AclFlags.expandX)
        .append(const SizedBox(width: 70, child: Text('Priority')), dist: 16)
        .setPSize(70, 0).setMSize(50, 0)
        .append(DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
          hint: const Text('Select'),
          items: [
            TomDropdownMenuItem(tomId: 'priority.high', value: 'high', child: const Text('High')),
            TomDropdownMenuItem(tomId: 'priority.medium', value: 'medium', child: const Text('Medium')),
            TomDropdownMenuItem(tomId: 'priority.low', value: 'low', child: const Text('Low')),
          ],
          onChanged: (_) {},
        ))
        .sameWidthAs(projectCodeField) // same width as Code field

        // ── Gap row: single separator ─────────────────────────────────────
        .gapRow(
          weight: 4,
          separator: const AclSeparator(
            style: AclSeparatorStyle.single,
            alignment: AclSeparatorAlignment.middle,
          ),
        )

        // ── Row: Start Date | End Date | Duration (right-edge → Code) ─────
        .append(const SizedBox(width: _lw, child: Text('Start Date')))
        .setPSize(_lw, 0).setMSize(70, 0)
        .append(const TextField(
          decoration: InputDecoration(
            labelText: 'YYYY-MM-DD',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ))
        .setPSize(140, 36).setMSize(90, 36).setXSize(180, 36)
        .append(const SizedBox(width: 70, child: Text('End Date')), dist: 16)
        .setPSize(70, 0).setMSize(50, 0)
        .append(const TextField(
          decoration: InputDecoration(
            labelText: 'YYYY-MM-DD',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ))
        .setPSize(140, 36).setMSize(90, 36).setXSize(180, 36)
        // Extra field on same row: right edge aligns with Code field above
        .append(const SizedBox(width: 44, child: Text(' Days')), dist: 12)
        .setPSize(44, 0).setMSize(30, 0)
        .append(const TextField(
          decoration: InputDecoration(
            labelText: '#',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ))
        .setPSize(60, 36).setMSize(50, 36).setXSize(75, 36)
        .alignRightToRight(projectCodeField) // ← cross-row alignment

        // ── Row: Description (full width) ──────────────────────────────────
        .newRow(dist: 10)
        .append(
          const SizedBox(
            width: _lw,
            child: Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Description'),
            ),
          ),
        )
        .append(const TextField(
          maxLines: 3,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            alignLabelWithHint: true,
          ),
        ))
        .setMSize(_fMin, 72).setPSize(400, 72).setAttr(AclFlags.expandX)

        // ── Double-line separator: section divider ─────────────────────────
        .gapRow(
          weight: 6,
          separator: const AclSeparator(
            style: AclSeparatorStyle.doubleLine,
            alignment: AclSeparatorAlignment.middle,
          ),
        )
        .append(const Text(
          'Budget & Approval',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.blueGrey),
        ))
        .gapRow(weight: 1)

        // ── Row: Cost Center | Budget ──────────────────────────────────────
        .append(const SizedBox(width: _lw, child: Text('Cost Center')))
        .setPSize(_lw, 0).setMSize(70, 0)
        .append(const TextField(
          decoration: InputDecoration(
            labelText: 'CC-XXX',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ))
        .setMSize(_fMin, 36).setPSize(220, 36).setAttr(AclFlags.expandX)
        .append(const SizedBox(width: 90, child: Text('Budget (EUR)')), dist: 16)
        .setPSize(90, 0).setMSize(60, 0)
        .append(budgetField) // ← alignment reference for Approver
        .setPSize(130, 36).setMSize(80, 36).setXSize(160, 36)

        // ── Row: PO Number | Approver (right-edge → Budget) ───────────────
        .newRow(dist: 10)
        .append(const SizedBox(width: _lw, child: Text('PO Number')))
        .setPSize(_lw, 0).setMSize(70, 0)
        .append(const TextField(
          decoration: InputDecoration(
            labelText: 'PO-XXX',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ))
        .setMSize(_fMin, 36).setPSize(220, 36).setAttr(AclFlags.expandX)
        .append(const SizedBox(width: 90, child: Text('Approver')), dist: 8)
        .setPSize(90, 0).setMSize(60, 0)
        .append(const TextField(
          decoration: InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ))
        .setPSize(130, 36).setMSize(80, 36).setXSize(160, 36)
        .alignRightToRight(budgetField) // ← cross-row alignment

        // ── Final gap + footer buttons ──────────────────────────────────────
        .gapRow(weight: 4)
        .gap() // push buttons to center
        .append(const OutlinedButton(onPressed: null, child: Text('Cancel')))
        .append(
          ElevatedButton(onPressed: () {}, child: const Text('  Submit  ')),
          dist: 8,
        )
        .gap() // push buttons to center
        // Minimum container width prevents overflow at very narrow windows.
        .setAclMSize(550, 0)
        .build(),
        ),

        const SizedBox(height: 8),
        const Text(
          'gap() = elastic horizontal spacer  ·  gapRow() = elastic vertical spacer  ·  '
          'gapRow(separator:) = divider line  ·  alignRightToRight(ref) = cross-row alignment  ·  '
          'sameWidthAs(ref) = same width as another component.',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    );
  }
}

