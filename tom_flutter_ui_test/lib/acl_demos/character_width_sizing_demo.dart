part of 'acl_demos.dart';

class CharacterWidthSizingDemo extends StatelessWidget {
  const CharacterWidthSizingDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final monoStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace');
    final charWidth = _measureWidthInChars(context, 1, style: monoStyle);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Character-based width sizing (setPWidthInChars-style):',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Using setPWidthInChars + setMWidthInChars + setXWidthInChars. Each row has a different min/preferred/max so you can see fields resize as you change the window width.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        ResizableBox(
          initialHeight: 180,
          child: AclBuilder()
              .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.center)
              .append(const SizedBox(width: 90, child: Text('12 chars:')))
              .setPSize(90, 40)
              .append(
                TextField(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  style: monoStyle,
                ),
                dist: 8,
              )
              .setPWidthInChars(12, charWidth: charWidth, height: 40)
              .setMWidthInChars(6, charWidth: charWidth)
              .setXWidthInChars(24, charWidth: charWidth)
              .newRow(dist: 10)
              .append(const SizedBox(width: 90, child: Text('24 chars:')))
              .setPSize(90, 40)
              .append(
                TextField(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  style: monoStyle,
                ),
                dist: 8,
              )
              .setPWidthInChars(24, charWidth: charWidth, height: 40)
              .setMWidthInChars(12, charWidth: charWidth)
              .setXWidthInChars(48, charWidth: charWidth)
              .newRow(dist: 10)
              .append(const SizedBox(width: 90, child: Text('36 chars:')))
              .setPSize(90, 40)
              .append(
                TextField(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  style: monoStyle,
                ),
                dist: 8,
              )
              .setPWidthInChars(36, charWidth: charWidth, height: 40)
              .setMWidthInChars(18, charWidth: charWidth)
              .setXWidthInChars(72, charWidth: charWidth)
              .build(),
        ),
        const SizedBox(height: 12),
        const Text('Code:', style: TextStyle(fontWeight: FontWeight.bold)),
        const CodeBlock('''
    final charWidth = measureWidthInChars(context, 1, style: monospaceStyle);

AclBuilder()
              .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.center)
    .append(TextField(style: monospaceStyle))
      .setPWidthInChars(24, charWidth: charWidth, height: 40)  // preferred
      .setMWidthInChars(12, charWidth: charWidth)              // min = 12 chars
      .setXWidthInChars(48, charWidth: charWidth)              // max = 48 chars
    .build();
// No expandX needed: surplus space is automatically distributed up to max.
// expandX only needed to claim ALL remaining surplus exclusively.
'''),
      ],
    );
  }
}

