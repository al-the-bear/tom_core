/// Runs the rendered ACL example and holds the two claims its own assertions
/// cannot make about themselves.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../../example/advanced_container_layout/advanced_container_layout_rendered_example.dart'
    as example;

void main() {
  group('advanced_container_layout rendered example', () {
    // The example installs an authorization adapter, which is process-wide.
    // Restoring it here as well means a failure part-way through — which skips
    // the example's own restore — cannot leak a policy into whatever runs next.
    tearDown(TomAuthorization.reset);

    testWidgets('runs end to end with its assertions', example.run);

    testWidgets('leaves no authorization adapter installed', (tester) async {
      await example.run(tester);
      expect(
        TomAuthorization.resolveAuth('order.actions.print'),
        TomAuthState.full,
        reason: 'the demo adapter is gone, so the default answer is back',
      );
    });

    test('every layout it demonstrates is one a reader can lift unchanged', () {
      // The widget-building functions take no tester and no context: they are
      // ordinary builder code, which is what makes the example copyable. A
      // helper that quietly needed the harness would still pass the run above.
      expect(example.buildVariantForm(), isA<Acl>());
      expect(example.buildBreakpointRow(), isA<Acl>());
      expect(example.buildSecuredRow(hideUnauthorized: true), isA<Acl>());
      expect(example.buildGrid(const ['A']), isA<AclFlowContainer>());
      expect(example.buildWrap(const ['A']), isA<AclFlowContainer>());
      expect(example.buildScopeReporter((_) {}, rowIdScope: true), isA<Acl>());
    });
  });
}
