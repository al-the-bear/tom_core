part of 'acl_demos.dart';

/// Exercises the `tom_flutter_ui` ACL feature: dynamic resizing — an ACL
/// layout adapting to the available width/height (driven by `LayoutBuilder`).
class DynamicResizeDemo extends StatelessWidget {
  const DynamicResizeDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final widthText = constraints.hasBoundedWidth
            ? constraints.maxWidth.toStringAsFixed(0)
            : 'unbounded';
        final heightText = constraints.hasBoundedHeight
            ? constraints.maxHeight.toStringAsFixed(0)
            : 'unbounded';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current size: $widthText x $heightText',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Resize the window to see layouts adapt dynamically.'),
            const SizedBox(height: 16),
            ResizableBox(
              // Header and footer are fixed, so everything else is the middle
              // row's: at 300 it received 158 px, while the Navigation and
              // Content panels inside it need ~172 and ~220 once their labels
              // wrap. 380 gives the middle row enough that the nested panels
              // size to their content instead of overflowing it.
              initialHeight: 380,
              child: AclBuilder()
                  .setAclPadding(const EdgeInsets.all(8))
                  .append(
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.blue.shade100,
                      child: const Text(
                        'Header - Fixed Height',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                  .expandX()
                  .newRow(dist: 8)
                  .append(
                    AclBuilder(
                          title: 'Navigation',
                          borderStyle: const AclBorderStyle(
                            kind: AclBorderKind.solidDouble,
                            color: Colors.blueGrey,
                          ),
                        )
                        .append(const Text('Menu Item 1'))
                        .newRow(dist: 4)
                        .append(const Text('Menu Item 2'))
                        .newRow(dist: 4)
                        .append(const Text('Menu Item 3'))
                        .newRow(dist: 4)
                        .append(const Text('Menu Item 4'))
                        .build(),
                  )
                  .expandY()
                  .append(
                    AclBuilder(
                          title: 'Content',
                          borderStyle: const AclBorderStyle(
                            kind: AclBorderKind.solidDouble,
                            color: Colors.blueGrey,
                          ),
                        )
                        .append(
                          Text(
                            'Width: ${widthText}px',
                            style: const TextStyle(fontSize: 18),
                          ),
                        )
                        .newRow(dist: 8)
                        .append(
                          const Text(
                            'This area expands to fill available space. '
                            'Try resizing the window!',
                          ),
                        )
                        .build(),
                    dist: 8,
                  )
                  .expandX()
                  .expandY()
                  .append(
                    AclBuilder(
                          title: 'Details',
                          borderStyle: const AclBorderStyle(
                            kind: AclBorderKind.solidDouble,
                            color: Colors.blueGrey,
                          ),
                        )
                        .append(const Text('Detail 1'))
                        .newRow(dist: 4)
                        .append(const Text('Detail 2'))
                        .build(),
                    dist: 8,
                  )
                  .expandY()
                  .newRow(dist: 8)
                  .append(
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.grey.shade200,
                      child: const Text('Footer - Fixed Height'),
                    ),
                  )
                  .expandX()
                  .build(),
            ),
            const SizedBox(height: 16),
            const Text('Three-column layout that adapts:'),
            const SizedBox(height: 8),
            ResizableBox(
              initialHeight: 150,
              child: AclBuilder()
                  .append(
                    const ExpandingBox(
                      'Left\n(fixed width)',
                      Colors.red,
                      width: 100,
                    ),
                  )
                  .append(
                    const ExpandingBox('Center\n(EXPANDX)', Colors.green),
                    dist: 4,
                  )
                  .expandX()
                  .append(
                    const ExpandingBox(
                      'Right\n(fixed width)',
                      Colors.blue,
                      width: 100,
                    ),
                    dist: 4,
                  )
                  .build(),
            ),
          ],
        );
      },
    );
  }
}
