part of 'acl_demos.dart';

class SizeConstraintsDemo extends StatelessWidget {
  const SizeConstraintsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
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

        // ── Three proportional panels (no expandX) ────────────────────────
        const Text(
          'Horizontal: three panels shrink proportionally (no expandX)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        ResizableBox(
          initialHeight: 52,
          child: AclBuilder()
              .append(const DemoBox('Alpha\nM:80 P:200 X:280', Colors.teal))
              .setMSize(80, 40).setPSize(200, 40).setXSize(280, 40)
              .append(const DemoBox('Beta\nM:60 P:160 X:220', Colors.indigo), dist: 6)
              .setMSize(60, 40).setPSize(160, 40).setXSize(220, 40)
              .append(const DemoBox('Gamma\nM:50 P:120 X:160', Colors.orange), dist: 6)
              .setMSize(50, 40).setPSize(120, 40).setXSize(160, 40)
              .build(),
        ),
        const SizedBox(height: 4),
        const Text(
          'All three shrink proportionally toward M:. Once any hits M: only the others continue shrinking.',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
        const SizedBox(height: 16),

        // ── Wide + narrow + fixed (asymmetric ranges) ─────────────────────
        const Text(
          'Horizontal: asymmetric panels — one fixed, others proportional',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        ResizableBox(
          initialHeight: 52,
          child: AclBuilder()
              .append(const DemoBox('Wide\nM:120 P:360 X:460', Colors.purple))
              .setMSize(120, 40).setPSize(360, 40).setXSize(460, 40)
              .append(const DemoBox('Medium\nM:80 P:200 X:240', Colors.blueGrey), dist: 6)
              .setMSize(80, 40).setPSize(200, 40).setXSize(240, 40)
              .append(const DemoBox('Fixed\nM:80 P:80 X:80', Colors.red), dist: 6)
              .setMSize(80, 40).setPSize(80, 40).setXSize(80, 40)
              .build(),
        ),
        const SizedBox(height: 4),
        const Text(
          'Fixed (M=P=X=80) never shrinks. Wide and Medium share remaining shrink proportionally.',
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
          initialHeight: 52,
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
    );
  }
}

