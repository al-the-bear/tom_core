part of 'acl_demos.dart';

/// Exercises the `tom_flutter_ui` ACL feature: responsive panels combining
/// `expandX` with min/preferred sizing so components grow and shrink as the
/// container width changes.
class ResponsiveConvenienceDemo extends StatelessWidget {
  const ResponsiveConvenienceDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Panel A: expandX input flanked by fixed labels ──────────────────
        const Text(
          'Panel A — expandX input between fixed labels',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Label [pref 120, min 80] | Input [pref 200, min 100, expandX] | Status [pref 100, min 60]. '
          'Resize window: Input grows/shrinks; labels hold preferred until container forces them.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        ResizableBox(
          initialHeight: 60,
          child: AclBuilder()
              .append(const DemoBox('Label', Colors.lightBlue))
              .setPSize(120, 48)
              .setMSize(80, 48)
              .append(const DemoBox('Input [expandX]', Colors.lightGreen),
                  dist: 8)
              .setPSize(200, 48)
              .setMSize(100, 48)
              .setAttr(AclFlags.expandX)
              .append(const DemoBox('Status', Colors.orange), dist: 8)
              .setPSize(100, 48)
              .setMSize(60, 48)
              .build(),
        ),
        const SizedBox(height: 20),

        // ── Panel B: three proportional addRight panels, no expandX ─────────
        const Text(
          'Panel B — proportional shrink across three fixed-size panels',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Alpha [pref 240, min 80] | Beta [pref 160, min 80] | Gamma [pref 120, min 60]. '
          'Resize window: all three shrink proportionally toward their minimum sizes.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        ResizableBox(
          initialHeight: 60,
          child: AclBuilder()
              .append(const DemoBox('Alpha', Colors.purple))
              .setPSize(240, 48)
              .setMSize(80, 48)
              .append(const DemoBox('Beta', Colors.teal), dist: 8)
              .setPSize(160, 48)
              .setMSize(80, 48)
              .append(const DemoBox('Gamma', Colors.red), dist: 8)
              .setPSize(120, 48)
              .setMSize(60, 48)
              .build(),
        ),
        const SizedBox(height: 20),

        // ── Panel C: two-row responsive layout ──────────────────────────────
        const Text(
          'Panel C — two-row layout with responsive sizing',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Main [pref 300, min 120] in row 1, Sub [pref 160, min 80] in row 2. '
          'Resize window: both shrink proportionally toward their minimums.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        ResizableBox(
          initialHeight: 120,
          child: AclBuilder()
              .append(const DemoBox('Main', Colors.indigo))
              .setPSize(300, 64)
              .setMSize(120, 48)
              .newRow()
              .append(const DemoBox('Sub (below-left)', Colors.cyan))
              .setPSize(160, 40)
              .setMSize(80, 40)
              .build(),
        ),
      ],
    );
  }
}

double _measureWidthInChars(
  BuildContext context,
  int chars, {
  TextStyle? style,
}) {
  final painter = TextPainter(
    text: TextSpan(text: 'W' * chars, style: style),
    textDirection: Directionality.of(context),
    maxLines: 1,
  )..layout();
  return painter.width;
}

