part of 'acl_demos.dart';

/// Exercises the `tom_flutter_ui` ACL feature: the cross-row alignment
/// convenience methods (`alignTopToTop`, `alignBottomToBottom`, …) that align
/// a component to an anchor component in another row.
class ConveniencePlacementDemo extends StatelessWidget {
  const ConveniencePlacementDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final tallRef = const SizedBox(
      width: 160,
      child: DemoBox('Tall Ref\n(h=80)', Colors.indigo),
    );
    final rowRef = const SizedBox(
      width: 200,
      child: DemoBox('Row-1 Anchor', Colors.deepPurple),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cross-row alignment — components in one row reference anchor components in another:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        // ── Group 1: same-row vertical alignment (Y only) ─────────────────
        const Text(
          'Same-row vertical alignment (Y only) — one alignment per component:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        ResizableBox(
          initialHeight: 100,
          child: AclBuilder()
              .append(tallRef)
              .setPSize(160, 80)
              // Top-align to Tall Ref
              .append(
                const SizedBox(
                  width: 100,
                  child: DemoBox('Top\nalign', Colors.teal),
                ),
                dist: 8,
              )
              .setPSize(100, 36)
              .alignTopToTop(tallRef)
              // Middle-align to Tall Ref
              .append(
                const SizedBox(
                  width: 120,
                  child: DemoBox('Middle\nalign', Colors.orange),
                ),
                dist: 8,
              )
              .setPSize(120, 36)
              .alignMiddleToMiddle(tallRef)
              // Bottom-align to Tall Ref
              .append(
                const SizedBox(
                  width: 100,
                  child: DemoBox('Bottom\nalign', Colors.green),
                ),
                dist: 8,
              )
              .setPSize(100, 36)
              .alignBottomToBottom(tallRef)
              .build(),
        ),
        const SizedBox(height: 4),
        const Text(
          'Each small box uses one alignY* call to snap its edge to the Tall Ref\'s corresponding edge.',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
        const SizedBox(height: 16),

        // ── Group 2: cross-row horizontal alignment (X only) ─────────────
        const Text(
          'Cross-row horizontal alignment (X only) — row 2 fields snap to row 1 anchor edges:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        ResizableBox(
          initialHeight: 100,
          child: AclBuilder()
              // Row 1: anchor
              .append(rowRef)
              .setPSize(200, 44)
              // Row 2: two fields cross-row aligned to anchor
              .newRow(dist: 8)
              .append(
                const SizedBox(
                  width: 90,
                  child: DemoBox('←Left to\nAnchor\'s left', Colors.lightBlue),
                ),
              )
              .setPSize(90, 44)
              .alignLeftToLeft(rowRef)
              .append(
                const SizedBox(
                  width: 90,
                  child: DemoBox('Right to\nAnchor\'s right→', Colors.pink),
                ),
                dist: 8,
              )
              .setPSize(90, 44)
              .alignRightToRight(rowRef)
              .build(),
        ),
        const SizedBox(height: 4),
        const Text(
          'Row 2 components each use one alignX* call. Left box\'s left edge == Anchor\'s left; '
          'Right box\'s right edge == Anchor\'s right.',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
        const SizedBox(height: 16),

        // ── Group 3: expandX ──────────────────────────────────────────────
        const Text(
          'expandX — two components share available row width:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        ResizableBox(
          initialHeight: 52,
          child: AclBuilder()
              .append(const DemoBox('Seventh expandX', Colors.green))
              .expandX()
              .append(const DemoBox('Eighth expandX', Colors.red), dist: 8)
              .expandX()
              .build(),
        ),
        const SizedBox(height: 4),
        const Text(
          'Rule: alignX* requires a different-row reference (cross-row horizontal); '
          'alignY* requires a same-row reference (same-row vertical). '
          'Both may be set on one component if each reference satisfies its row constraint.',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    );
  }
}
