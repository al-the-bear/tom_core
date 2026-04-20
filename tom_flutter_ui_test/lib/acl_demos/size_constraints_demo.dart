part of 'acl_demos.dart';

class SizeConstraintsDemo extends StatelessWidget {
  const SizeConstraintsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resize the window left/right. Components shrink proportionally toward M: — they never go below it.',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'M = minimum  |  P = preferred  |  X = maximum. '
          'Labels in each box show the configured constraints.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 16),

        // ── Three panels grow proportionally to (P / M − 1), no expandX ──
        const Text(
          'Horizontal: three components grow by (P/M − 1) without expandX',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        ResizableBox(
          initialHeight: null,
          child: AclBuilder()
              // P/M − 1 = 200/80 − 1 = 1.5 → largest share of extra space
              .append(const DemoBox('Alpha\nM:80 P:200', Colors.teal))
              .setMSize(80, 40).setPSize(200, 40)
              // P/M − 1 = 160/60 − 1 ≈ 1.67 → middle (actually larger ratio)
              .append(const DemoBox('Beta\nM:60 P:160', Colors.indigo), dist: 6)
              .setMSize(60, 40).setPSize(160, 40)
              // P/M − 1 = 120/50 − 1 = 1.4 → smallest share
              .append(const DemoBox('Gamma\nM:50 P:120', Colors.orange), dist: 6)
              .setMSize(50, 40).setPSize(120, 40)
              .build(),
        ),
        const SizedBox(height: 4),
        const Text(
          'Extra space above the sum of M values is distributed by the '
          '(P/M − 1) growth factor; none of these use expandX.',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
        const SizedBox(height: 16),

        // ── Same thing but last component is fixed ──────────────────────
        const Text(
          'Horizontal: two growing components + one fixed (no expandX)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        ResizableBox(
          initialHeight: null,
          child: AclBuilder()
              // P/M − 1 = 360/120 − 1 = 2
              .append(const DemoBox('Wide\nM:120 P:360', Colors.purple))
              .setMSize(120, 40).setPSize(360, 40)
              // P/M − 1 = 200/80 − 1 = 1.5
              .append(const DemoBox('Medium\nM:80 P:200', Colors.blueGrey), dist: 6)
              .setMSize(80, 40).setPSize(200, 40)
              // M = P = X = 80 → never grows nor shrinks
              .append(const DemoBox('Fixed\nM=P=X=80', Colors.red), dist: 6)
              .setMSize(80, 40).setPSize(80, 40).setXSize(80, 40)
              .build(),
        ),
        const SizedBox(height: 4),
        const Text(
          'Fixed column keeps 80 px regardless of window width. Wide and Medium '
          'share the remaining extra width in the 240 : 120 = 2 : 1 ratio.',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
        const SizedBox(height: 16),

        // ── Mixed: one component has a max, others don't ─────────────────
        const Text(
          'Horizontal: mixed — one component has a max, the other two don\'t',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        ResizableBox(
          initialHeight: null,
          child: AclBuilder()
              // max > pref > min: grows up to 260 px, then drops out.
              .append(const DemoBox('Capped\nM:80 P:160 X:260', Colors.cyan))
              .setMSize(80, 40).setPSize(160, 40).setXSize(260, 40)
              // no max: keeps absorbing surplus after Capped saturates.
              .append(const DemoBox('Uncapped A\nM:60 P:140', Colors.indigo), dist: 6)
              .setMSize(60, 40).setPSize(140, 40)
              // no max: same, different (P/M − 1) ratio.
              .append(const DemoBox('Uncapped B\nM:50 P:120', Colors.orange), dist: 6)
              .setMSize(50, 40).setPSize(120, 40)
              .build(),
        ),
        const SizedBox(height: 4),
        const Text(
          'Capped grows up to its max (260) and then stops; Uncapped A/B '
          'continue absorbing the rest by (P/M − 1). No expandX anywhere.',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
        const SizedBox(height: 16),

        // ── Mixed + expandX ──────────────────────────────────────────────
        const Text(
          'Horizontal: same three + one expandX — non-expandX stop at preferred',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        ResizableBox(
          initialHeight: null,
          child: AclBuilder()
              .append(const DemoBox('Capped\nM:80 P:160 X:260', Colors.cyan))
              .setMSize(80, 40).setPSize(160, 40).setXSize(260, 40)
              .append(const DemoBox('Uncapped A\nM:60 P:140', Colors.indigo), dist: 6)
              .setMSize(60, 40).setPSize(140, 40)
              .append(const DemoBox('Uncapped B\nM:50 P:120', Colors.orange), dist: 6)
              .setMSize(50, 40).setPSize(120, 40)
              // expandX component: absorbs all remaining surplus when the
              // row grows and participates in proportional shrinking when
              // it narrows — but respects its own minimumSize floor.
              .append(const DemoBox('ExpandX\nM:120 P:240', Colors.lightGreen), dist: 6)
              .setMSize(120, 40).setPSize(240, 40)
              .setAttr(AclFlags.expandX)
              .build(),
        ),
        const SizedBox(height: 4),
        const Text(
          'Grow: the three non-expandX components sit at their preferred '
          'widths (160 / 140 / 120) and ExpandX eats the rest. '
          'Shrink: once the row narrows past the sum of preferred widths, '
          'all four components (including ExpandX) shrink proportionally '
          'by (pref − min) — ExpandX stops at its minimum of 120 px and '
          'never collapses past it.',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
        const SizedBox(height: 16),

        // ── expandX: one component fills all remaining space ──────────────
        const Text(
          'Horizontal + expandX: center component grows to fill remaining width',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        ResizableBox(
          initialHeight: null,
          child: AclBuilder()
              .append(const DemoBox('Fixed\nM:80 P:120 X:120', Colors.blueGrey))
              .setMSize(80, 40).setPSize(120, 40).setXSize(120, 40)
              .append(const DemoBox('ExpandX\nM:120 P:300 X:∞', Colors.lightGreen), dist: 6)
              .setMSize(120, 40).setPSize(300, 40)
              .setAttr(AclFlags.expandX)
              .append(const DemoBox('Fixed\nM:60 P:90 X:90', Colors.cyan), dist: 6)
              .setMSize(60, 40).setPSize(90, 40).setXSize(90, 40)
              .build(),
        ),
        const SizedBox(height: 16),

        // ── Vertical: expandY fills bounded height ────────────────────────
        const Text(
          'Vertical: expandY fills height — resize by dragging window taller/shorter',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        ResizableBox(
          initialHeight: 200,
          child: AclBuilder()
              .append(const DemoBox('Row 1 – fixed\nM:60 P:60', Colors.orange))
              .setMSize(0, 60).setPSize(400, 60)
              .setAttr(AclFlags.expandX)
              .newRow(dist: 4)
              .append(const DemoBox('Row 2 – expandY\nM:40 P:100', Colors.lightGreen))
              .setMSize(0, 40).setPSize(400, 100)
              .setAttr(AclFlags.expand)
              .newRow(dist: 4)
              .append(const DemoBox('Row 3 – fixed\nM:40 P:40', Colors.teal))
              .setMSize(0, 40).setPSize(400, 40)
              .setAttr(AclFlags.expandX)
              .build(),
        ),
        const SizedBox(height: 4),
        const Text(
          'Row 1 and Row 3 keep fixed height. Row 2 (expandY) absorbs all extra vertical space.',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
      ),
    );
  }
}

