part of 'acl_demos.dart';

/// Exercises the `tom_flutter_ui` ACL feature: a typical form layout — a fixed
/// label column plus `expandX` fields with minimum widths, using
/// `setAclPadding` and a default row vertical alignment.
class FormLayoutDemo extends StatelessWidget {
  const FormLayoutDemo({super.key});

  static const double _lw = 110.0; // label column fixed width
  static const double _fMin = 120.0; // field minimum width

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Typical form layout — all fields use expandX with minimum size. '
          'Resize the window: every field grows/shrinks, labels stay fixed.',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ResizableBox(
          // The five rows plus their gaps and the 16 px padding need ~288 px of
          // content height, and the box spends 2 px on its border. 320 left no
          // slack at all: a font with wider glyphs wraps a label onto a second
          // line and the ACL column overflows the box it was given. 360 keeps
          // the frame snug around the form while absorbing that.
          initialHeight: 360,
          child: AclBuilder()
              .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.center)
              .setAclPadding(const EdgeInsets.all(16))
              // Date row
              .append(const SizedBox(width: _lw, child: Text('Date:')))
              .append(
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'YYYY-MM-DD',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              )
              .setMSize(_fMin, 36).setPSize(240, 36)
              .setAttr(AclFlags.expandX)
              // Name row
              .newRow(dist: 12)
              .append(const SizedBox(width: _lw, child: Text('Name:')))
              .append(
                const TextField(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              )
              .setMSize(_fMin, 36).setPSize(320, 36)
              .setAttr(AclFlags.expandX)
              // Cost Center row
              .newRow(dist: 12)
              .append(const SizedBox(width: _lw, child: Text('Cost Center:')))
              .append(
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'CC-XXX',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              )
              .setMSize(_fMin, 36).setPSize(240, 36)
              .setAttr(AclFlags.expandX)
              // Description row
              .newRow(dist: 12)
              .append(
                const SizedBox(
                  width: _lw,
                  child: Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Description:'),
                  ),
                ),
              )
              .append(
                const TextField(
                  maxLines: 3,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    alignLabelWithHint: true,
                  ),
                ),
              )
              .setMSize(_fMin, 72).setPSize(320, 72)
              .setAttr(AclFlags.expandX)
              // Buttons
              .newRow(dist: 20)
              .append(
                ElevatedButton(onPressed: () {}, child: const Text('Submit')),
              )
              .append(
                OutlinedButton(onPressed: () {}, child: const Text('Cancel')),
                dist: 10,
              )
              .setRowHorizontalAlignment(RowAlignment.center)
              .build(),
        ),
        const SizedBox(height: 8),
        const Text(
          'All fields use expandX + setMSize() so they grow with the container '
          'but never shrink past their minimum.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}

