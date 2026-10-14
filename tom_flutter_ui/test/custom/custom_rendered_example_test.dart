/// Runs the rendered `custom/` example and holds the claim its own assertions
/// cannot make about themselves.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../../example/custom/custom_rendered_example.dart' as example;

void main() {
  group('custom rendered example', () {
    // The example installs an authorization adapter, which is process-wide.
    // Restoring it here as well means a failure part-way through — which skips
    // the example's own tear-down — cannot leak a policy into whatever runs
    // next.
    tearDown(TomAuthorization.reset);

    testWidgets('renders all eight and checks each one', example.run);

    test('every widget it shows is built by a plain function', () {
      // What makes the example copyable: each builder takes no tester and no
      // `BuildContext`, so a reader can lift it as it stands. A helper that
      // quietly came to need the harness would still pass the run above.
      expect(example.buildGuards(), isA<Widget>());
      expect(example.buildTree(), isA<Widget>());
      expect(example.buildChoiceGroup(), isA<Widget>());
      expect(example.buildEmptyState(), isA<Widget>());
      expect(example.buildErrorBoundary(), isA<Widget>());
      expect(example.buildInfiniteScroll(), isA<Widget>());
      expect(example.buildLoadingOverlay(), isA<Widget>());
      expect(example.buildSkeletons(), isA<Widget>());
      expect(example.buildPrincipalPicker(), isA<Widget>());
      expect(example.buildGallery(), isA<Widget>());
    });

    test('the gallery leaves none of the nine out', () {
      // The example's assertions each name one widget, so none of them notices
      // a section dropped from the gallery — the run would simply stop
      // asserting about it. This counts the types the gallery contains.
      final gallery = example.buildGallery() as ListView;
      final labels = <String>[
        for (final child
            in (gallery.childrenDelegate as SliverChildListDelegate).children)
          if (child is Text && child.data != null) child.data!,
      ];
      expect(labels, containsAll(<String>['TomAuthGuard', 'TomAuthTreeView']));
      expect(
        labels.where((l) => l.startsWith('Tom')).toSet(),
        hasLength(9),
        reason: 'nine widgets, nine sections: $labels',
      );
    });
  });
}
