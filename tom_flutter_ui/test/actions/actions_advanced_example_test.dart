import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../example/actions/actions_advanced_example.dart' as example;

void main() {
  group('actions advanced example', () {
    // The example installs its own authorization adapter and text bundle and
    // puts both back. Restoring them here as well means a failure part-way
    // through — which skips the example's own restore — cannot leak a policy
    // or a caption bundle into whatever runs next.
    tearDown(() {
      TomAuthorization.reset();
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from(const {}),
      );
    });

    test('runs end to end with its assertions', () {
      expect(example.run, returnsNormally);
    });

    test('leaves no authorization adapter or caption bundle installed', () {
      // The example is process-wide in two ways a reader would not expect from
      // a demonstration, so it cleans up after itself — and that is a claim
      // worth holding, not a comment worth trusting.
      example.run();
      expect(
        TomAuthorization.resolveAuth('admin.purge'),
        TomAuthState.full,
        reason: 'the demo adapter is gone, so the default answer is back',
      );
      expect(
        TomTextResourceProvider.getAppResources().getTextOrNull(
          'admin.purge.label',
        ),
        isNull,
        reason: 'the demo captions are gone',
      );
    });
  });
}
