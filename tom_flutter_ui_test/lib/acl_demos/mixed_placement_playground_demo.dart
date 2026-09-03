part of 'acl_demos.dart';

/// Exercises the `tom_flutter_ui` ACL feature: combined placement — cross-row
/// alignment, regular rows, and `sameSize()` mirroring together in one layout.
class MixedPlacementPlaygroundDemo extends StatelessWidget {
  const MixedPlacementPlaygroundDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final formAnchor = const SizedBox(
      width: 220,
      child: DemoBox('Form Anchor\n(ref)', Colors.deepPurple),
    );
    const regularBox = DemoBox('Regular (+dist:12)', Colors.orange);
    final tallBox = const SizedBox(
      width: 140,
      child: DemoBox('Tall\n(h=70)', Colors.blueGrey),
    );
    // Row 4 buttons — captured so Row 5 can mirror them via sameSize().
    final primaryAction = ElevatedButton(
      onPressed: () {},
      child: const Text('Primary Action'),
    );
    final secondaryAction = OutlinedButton(
      onPressed: () {},
      child: const Text('Secondary'),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Multi-row layout combining cross-row alignment, regular rows, and sameSize():',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ResizableBox(
          initialHeight: 300,
          child: AclBuilder()
              // Row 1: anchor (pref=220, min=140, no max) + regular (pref=120, min=70, no max)
              // Both resize freely — note intentionally different min/pref values.
              .append(formAnchor)
              .setPSize(220, 50)
              .setMSize(140, 40)
              .append(regularBox, dist: 12)
              .setPSize(120, 40)
              .setMSize(70, 40)
              // Row 2: two components each using cross-row X alignment (no overlap)
              //   Right→Right: right edge of box aligns to formAnchor's right
              //   Left→Regular: left edge of box aligns to regularBox's left
              .newRow(dist: 8)
              .append(
                const SizedBox(
                  width: 160,
                  child: DemoBox('Right→Right\n(formAnchor)', Colors.indigo),
                ),
              )
              .setPSize(160, 40)
              .alignRightToRight(formAnchor)
              .append(
                const SizedBox(
                  width: 120,
                  child: DemoBox('Left→Regular\n(+dist:12)', Colors.teal),
                ),
                dist: 8,
              )
              .setPSize(120, 40)
              .alignLeftToLeft(regularBox)
              // Row 3: same-row vertical Y alignment (Y only per component)
              .newRow(dist: 8)
              .append(tallBox)
              .setPSize(140, 70)
              .append(
                const SizedBox(
                  width: 120,
                  child: DemoBox('Top↑align', Colors.green),
                ),
                dist: 8,
              )
              .setPSize(120, 36)
              .alignTopToTop(tallBox)
              .append(
                const SizedBox(
                  width: 120,
                  child: DemoBox('Bot↓align', Colors.red),
                ),
                dist: 8,
              )
              .setPSize(120, 36)
              .alignBottomToBottom(tallBox)
              // Row 4: two buttons with intentionally different min/pref/max sizes.
              .newRow(dist: 12)
              .append(primaryAction)
              .setPSize(180, 40)
              .setMSize(100, 40)
              .setXSize(260, 40)
              .append(secondaryAction, dist: 12)
              .setPSize(120, 40)
              .setMSize(70, 40)
              .setXSize(180, 40)
              // Row 5: mirrors of Row 4 using cross-row sameSize().
              // sameSize() on the same row is disallowed by the engine.
              .newRow(dist: 8)
              .append(
                OutlinedButton(
                  onPressed: () {},
                  child: const Text('Mirror Primary'),
                ),
              )
              .sameSize(primaryAction)
              .append(
                OutlinedButton(
                  onPressed: () {},
                  child: const Text('Mirror Secondary'),
                ),
                dist: 12,
              )
              .sameSize(secondaryAction)
              .build(),
        ),
        const SizedBox(height: 8),
        const Text(
          'Row 2 uses two cross-row X alignments: Right→Right aligns to formAnchor; '
          'Left→Regular aligns to regularBox (no overlap). Row 3 uses same-row alignY. '
          'Row 4 has two buttons with different min/pref/max. '
          'Row 5 mirrors both via cross-row sameSize() — same-row mirroring is disallowed.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Responsive Convenience Demo
// Shows shrink/grow behaviour when preferred > min sizes are set.
// ─────────────────────────────────────────────────────────────────────────────
