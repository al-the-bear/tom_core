part of 'acl_demos.dart';

class ReferenceConstraintsDemo extends StatefulWidget {
  const ReferenceConstraintsDemo({super.key});

  @override
  State<ReferenceConstraintsDemo> createState() =>
      _ReferenceConstraintsDemoState();
}

class _ReferenceConstraintsDemoState extends State<ReferenceConstraintsDemo> {
  @override
  Widget build(BuildContext context) {
    final anchorLabel = const SizedBox(width: 140, child: Text('Anchor Label'));
    final anchorField = const SizedBox(
      width: 280,
      child: TextField(
        decoration: InputDecoration(
          labelText: 'Anchor Field',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
    final anchorButton = ElevatedButton(
      onPressed: () {},
      child: const Text('Anchor Action'),
    );
    final centerAnchor = const SizedBox(
      width: 320,
      child: DemoBox('Anchor (center)', Colors.indigo),
    );
    final verticalAnchor = const SizedBox(
      width: 220,
      child: DemoBox('Anchor Y', Colors.deepPurple),
    );
    final topBottomAnchor = const SizedBox(
      width: 220,
      child: DemoBox('Anchor (top->bottom)', Colors.deepOrange),
    );
    final bottomTopAnchor = const SizedBox(
      width: 220,
      child: DemoBox('Anchor (bottom->top)', Colors.blueGrey),
    );
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        const Text(
          'Old + new reference constraints: anchors in the first row define width/edges; later rows link size and alignment.',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ResizableBox(
          initialHeight: 280,
          child: AclBuilder()
              .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.center)
              .append(anchorLabel)
              .append(anchorField, dist: 12)
              .newRow(dist: 10)
              .append(const SizedBox(child: Text('Linked Label A')))
              .sameWidthAs(anchorLabel)
              .alignLeftToLeft(anchorLabel)
              .append(
                const SizedBox(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Aligned to right anchor',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                dist: 12,
              )
              .sameWidthAs(anchorField)
              .sameHeightAs(anchorField)
              .alignRightToRight(anchorField)
              .newRow(dist: 10)
              .append(const SizedBox(child: Text('Linked Label B')))
              .sameWidthAs(anchorLabel)
              .alignLeftToLeft(anchorLabel)
              .append(
                const SizedBox(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Aligned to anchor + 16px',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                dist: 12,
              )
              .sameWidthAs(anchorField)
              .sameHeightAs(anchorField)
              .alignRightToRight(anchorField, gap: 16)
              .newRow(dist: 14)
              .append(anchorButton)
              .setPSize(220, 40)
              .newRow(dist: 8)
              .append(
                OutlinedButton(
                  onPressed: () {},
                  child: const Text('Same Size Button'),
                ),
              )
              .sameWidthAs(anchorButton)
              .sameHeightAs(anchorButton)
              .build(),
        ),
        const SizedBox(height: 10),
        const Text(
          'Expected: labels match anchor label width; first linked field right-edge matches anchor field; second linked field is offset by +16 from that edge; last button mirrors anchor action size.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 20),
        const Text(
          'Center-to-center reference alignment:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ResizableBox(
          initialHeight: 100,
          child: AclBuilder()
              .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.center)
              .append(centerAnchor)
              .setPSize(320, 48)
              .setMSize(50, 48)
              .setXSize(320, 48)
              .newRow(dist: 10)
              .append(const DemoBox('Follower', Colors.cyan))
              .setPSize(140, 40)
              .alignCenterToCenter(centerAnchor)
              .build(),
        ),
        const SizedBox(height: 8),
        const Text(
          'Expected: follower center X equals anchor field center X.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 20),
        const Text(
          'Vertical reference alignment (single-row, center Y to center Y):',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ResizableBox(
          initialHeight: 80,
          child: AclBuilder()
              .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.center)
              .append(verticalAnchor)
              .setPSize(220, 70)
              .append(const SizedBox(width: 24))
              .append(
                const SizedBox(
                  width: 220,
                  child: DemoBox('Follower Y', Colors.teal),
                ),
              )
              .setPSize(220, 40)
              .alignMiddleToMiddle(verticalAnchor)
              .build(),
        ),
        const SizedBox(height: 8),
        const Text(
          'Expected: follower center Y aligns with anchor Y center without jumping.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 20),
        const Text(
          'Vertical alignTopToBottom reference alignment:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ResizableBox(
          initialHeight: null,
          child: AclBuilder()
              .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.center)
              .append(topBottomAnchor)
              .setPSize(220, 64)
              .append(const SizedBox(width: 24))
              .append(
                const SizedBox(
                  width: 220,
                  child: DemoBox('Follower top->anchor bottom', Colors.green),
                ),
              )
              .setPSize(220, 36)
              .alignTopToBottom(topBottomAnchor)
              .build(),
        ),
        const SizedBox(height: 8),
        const Text(
          'Expected: follower top edge aligns to anchor bottom edge.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 20),
        const Text(
          'Vertical alignBottomToTop reference alignment:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ResizableBox(
          initialHeight: null,
          child: AclBuilder()
              .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.center)
              .append(bottomTopAnchor)
              .setPSize(220, 64)
              .append(const SizedBox(width: 24))
              .append(
                const SizedBox(
                  width: 220,
                  child: DemoBox('Follower bottom->anchor top', Colors.purple),
                ),
              )
              .setPSize(220, 36)
              .alignBottomToTop(bottomTopAnchor)
              .build(),
        ),
        const SizedBox(height: 8),
        const Text(
          'Expected: follower bottom edge aligns to anchor top edge.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 20),
        const Text(
          'alignTopToBottom / alignBottomToTop with gap parameter:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Positive gap pushes the follower further away from the anchor edge; '
          'negative gap pulls it into the anchor (overlap). Not offered on '
          'center-to-center alignments.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        Builder(builder: (_) {
          final tbAnchor = const SizedBox(
            width: 160,
            child: DemoBox('Anchor T→B', Colors.deepOrange),
          );
          return ResizableBox(
            initialHeight: null,
            child: AclBuilder()
              .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.center)
                .append(tbAnchor)
                .setPSize(160, 56)
                .append(const SizedBox(width: 12))
                .append(const SizedBox(
                  width: 160,
                  child: DemoBox('gap: 12 (push)', Colors.green),
                ))
                .setPSize(160, 32)
                .alignTopToBottom(tbAnchor, gap: 12)
                .append(const SizedBox(width: 12))
                .append(const SizedBox(
                  width: 160,
                  child: DemoBox('gap: -12 (overlap)', Colors.teal),
                ))
                .setPSize(160, 32)
                .alignTopToBottom(tbAnchor, gap: -12)
                .build(),
          );
        }),
        const SizedBox(height: 4),
        const Text(
          'Left green block sits 12 px below anchor bottom; right teal block '
          'overlaps the bottom 12 px of anchor.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 16),
        Builder(builder: (_) {
          final btAnchor = const SizedBox(
            width: 160,
            child: DemoBox('Anchor B→T', Colors.blueGrey),
          );
          return ResizableBox(
            initialHeight: null,
            child: AclBuilder()
              .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.center)
                .append(btAnchor)
                .setPSize(160, 56)
                .append(const SizedBox(width: 12))
                .append(const SizedBox(
                  width: 160,
                  child: DemoBox('gap: 12 (push)', Colors.purple),
                ))
                .setPSize(160, 32)
                .alignBottomToTop(btAnchor, gap: 12)
                .append(const SizedBox(width: 12))
                .append(const SizedBox(
                  width: 160,
                  child: DemoBox('gap: -12 (overlap)', Colors.brown),
                ))
                .setPSize(160, 32)
                .alignBottomToTop(btAnchor, gap: -12)
                .build(),
          );
        }),
        const SizedBox(height: 4),
        const Text(
          'Left purple block sits 12 px above anchor top; right brown block '
          'overlaps the top 12 px of anchor.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 20),
        const Text(
          'Row constraint rules for alignX* and alignY*:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(color: Colors.red.shade300)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '✗  INVALID — alignX* with same-row reference (throws):',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
              ),
              const SizedBox(height: 4),
              const Text(
                '  // anchor and follower are in the SAME row\n'
                '  .append(follower)\n'
                '  .alignLeftToLeft(anchor)   // ERROR: anchor is in same row',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              const SizedBox(height: 6),
              const Text(
                '✗  INVALID — alignY* with different-row reference (throws):',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
              ),
              const SizedBox(height: 4),
              const Text(
                '  // anchor is in row 0, follower is in row 1\n'
                '  .append(follower)\n'
                '  .alignTopToTop(anchor)     // ERROR: anchor is in a different row',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              const SizedBox(height: 10),
              const Text(
                '✓  VALID — alignX* with different-row reference:',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green),
              ),
              const SizedBox(height: 4),
              const Text(
                '  // anchor in row 0, follower in row 1\n'
                '  .append(follower)\n'
                '  .alignLeftToLeft(anchor)   // OK: anchor is in a different row',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              const SizedBox(height: 10),
              const Text(
                '✓  VALID — alignY* with same-row reference:',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green),
              ),
              const SizedBox(height: 4),
              const Text(
                '  // tallRef and follower are in the SAME row\n'
                '  .append(follower)\n'
                '  .alignTopToTop(tallRef)    // OK: tallRef is in the same row',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              const SizedBox(height: 10),
              const Text(
                '✓  VALID — both alignX* and alignY* on the same component:',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green),
              ),
              const SizedBox(height: 4),
              const Text(
                '  // xAnchor in row 0, yRef in same row as follower (row 1)\n'
                '  .append(follower)\n'
                '  .alignLeftToLeft(xAnchor)  // X ref in different row — OK\n'
                '  .alignTopToTop(yRef)        // Y ref in same row — OK',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Summary: alignX* requires a different-row reference; alignY* requires a same-row reference. '
          'Both can be set on the same component as long as each reference satisfies its row constraint.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        ],
      ),
    );
  }
}

