/// Form-factor variants — phone / tablet / desktop layouts via addVariant.
///
/// `AclDeviceContext.resolveFormFactor(width)` maps a width onto the canonical
/// tiers (`phone` < 600, `tablet` < 1024, `desktop` ≥ 1024). `addVariant(name,
/// atWidth:, builder:)` registers an alternative whole-row layout that the ACL
/// engine selects below a width — so one builder chain carries a desktop default
/// plus a stacked phone variant. Each cell pins a width and reads back the
/// resolved form factor.
///
/// The two numbers are independent, which is why there is a cell per tier rather
/// than one per shape: the tier boundary (1024) and the variant threshold (600)
/// answer different questions, so the desktop and tablet cells render the *same*
/// row while reporting different tiers.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_box.dart';
import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';

/// Builds the same variant-carrying layout at a fixed [width], with a badge of
/// the resolved [AclFormFactor].
Widget _factorLayout(double width) {
  final factor = AclDeviceContext.resolveFormFactor(width);
  // G-UI-2: the readout and its column are Tom primitives, matching every other
  // group's badge. Only the width pin below stays a raw SizedBox — pure
  // geometry, and it is the constraint the cell exists to demonstrate.
  return TomColumn(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TomText(text: 'resolveFormFactor($width) → ${factor.name}'),
      TomSizedBox(height: 8),
      SizedBox(
        width: width,
        child: AclBuilder()
            .setAclExpandXDefault(true)
            .append(demoBox('Label', Colors.indigo))
            .append(demoBox('Value', Colors.cyan), dist: 12)
            .addVariant('phone', atWidth: 600, builder: (b) {
              b
                  .append(demoBox('Label', Colors.indigo))
                  .newRow(dist: 6)
                  .append(demoBox('Value', Colors.cyan));
            })
            .build(),
      ),
    ],
  );
}

/// The form-factor-variants mechanism group.
final ShowcaseGroup formFactorGroup = ShowcaseGroup(
  id: 'form_factor',
  title: 'Form-factor variants',
  summary: 'resolveFormFactor maps width to phone/tablet/desktop tiers; '
      'addVariant swaps in a stacked phone layout below 600px — one chain, two '
      'shapes.',
  icon: Icons.devices_outlined,
  // One cell per tier, in descending width. Each title names the tier its own
  // width resolves to, and the badge beside it prints what the resolver actually
  // returned — `form_factor_test.dart` requires the two to agree, so a cell
  // cannot be re-pinned to a width that contradicts its own title.
  cells: (context) => [
    ShowcaseCell(
      title: 'Desktop (1200px) — default row',
      note: 'At 1024px and above the tier is desktop. Being above the 600px '
          'phone variant too, the default side-by-side row applies.',
      code: 'AclBuilder()\n'
          "    .append(demoBox('Label', Colors.indigo))\n"
          "    .append(demoBox('Value', Colors.cyan), dist: 12)\n"
          "    .addVariant('phone', atWidth: 600, builder: (b) {\n"
          "      b.append(demoBox('Label', Colors.indigo))\n"
          '          .newRow(dist: 6)\n'
          "          .append(demoBox('Value', Colors.cyan));\n"
          '    })\n'
          '    .build()',
      child: _factorLayout(1200),
    ),
    ShowcaseCell(
      title: 'Tablet (900px) — the same default row',
      note: 'Below 1024px the tier is tablet, but the layout is unchanged: the '
          'variant threshold is 600, not the tier boundary. Same chain, same '
          'shape, different tier name.',
      code: '// Same chain as above — 900px is below the 1024px desktop\n'
          '// boundary but still above the 600px atWidth threshold, so the\n'
          '// tier changes and the shape does not.',
      child: _factorLayout(900),
    ),
    ShowcaseCell(
      title: 'Phone (400px) — stacked variant',
      note: 'Below 600px the registered phone variant replaces the default row '
          'with a stacked layout.',
      code: '// Same chain as above — the ACL engine picks the phone variant\n'
          '// because 400px < the 600px atWidth threshold.',
      child: _factorLayout(400),
    ),
  ],
);
