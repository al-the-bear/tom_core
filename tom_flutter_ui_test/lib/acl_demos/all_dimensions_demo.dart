part of 'acl_demos.dart';

/// Exercises the `tom_flutter_ui` ACL feature: the `AclFlags.expandX`,
/// `expandY`, and `expand` expansion flags combined in one full-window layout.
class AllDimensionsDemo extends StatelessWidget {
  const AllDimensionsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: AclBuilder()
          // ── Row 1: single ExpandX — fixed left, expand centre, fixed right ──
          .append(const DemoBox('Fixed L\n(140)', Colors.blueGrey))
          .setPSize(140, 44)
          .append(const DemoBox('ExpandX — fills remaining width', Colors.lightGreen))
          .setPSize(200, 44)
          .setAttr(AclFlags.expandX)
          .append(const DemoBox('Fixed R\n(100)', Colors.blueGrey))
          .setPSize(100, 44)
          // ── Row 2: three equal ExpandX panels ────────────────────────────
          .newRow(dist: 4)
          .append(const DemoBox('ExpandX #1', Colors.red))
          .setPSize(100, 40)
          .setAttr(AclFlags.expandX)
          .append(const DemoBox('ExpandX #2', Colors.green))
          .setPSize(100, 40)
          .setAttr(AclFlags.expandX)
          .append(const DemoBox('ExpandX #3', Colors.blue))
          .setPSize(100, 40)
          .setAttr(AclFlags.expandX)
          // ── Row 3: expandY — fills all remaining height ───────────────────
          // Left sidebar and right panel: fixed width, expandY (fill row height).
          // Centre: expandX + expandY (fills remaining width AND height).
          .newRow(dist: 4)
          .append(
            Container(
              color: Colors.indigo.withAlpha(50),
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.all(8),
              child: const Text(
                'Left Sidebar\n(fixed width,\nexpandY)',
                textAlign: TextAlign.center,
              ),
            ),
          )
          .setPSize(140, 200)
          .setMSize(80, 100)
          .setAttr(AclFlags.expandY)
          .append(
            Container(
              color: Colors.lightBlue.withAlpha(60),
              alignment: Alignment.center,
              child: const Text(
                'ExpandX + ExpandY\n(fills remaining width AND height)',
                textAlign: TextAlign.center,
              ),
            ),
          )
          .setPSize(200, 200)
          .setMSize(100, 100)
          .setAttr(AclFlags.expand)
          .append(
            Container(
              color: Colors.deepOrange.withAlpha(50),
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.all(8),
              child: const Text(
                'Right Panel\n(fixed width,\nexpandY)',
                textAlign: TextAlign.center,
              ),
            ),
          )
          .setPSize(120, 200)
          .setMSize(60, 100)
          .setAttr(AclFlags.expandY)
          .build(),
    );
  }
}

