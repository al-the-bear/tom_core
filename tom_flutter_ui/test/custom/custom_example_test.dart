/// Runs the `custom/` example and nothing else.
///
/// Deliberately not a smoke case per widget as well. Each widget's own
/// parameters and auth states are covered in the file that owns the widget,
/// where they are covered rather than sampled; a second, thinner copy here
/// would be two places answering the same question, and the thin one would go
/// stale unnoticed.
///
/// So the claim here is the example's own: that it runs and its assertions
/// hold. `custom_rendered_example_test.dart` does the same for the rendered
/// example beside it.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../example/custom/custom_example.dart' as example;

void main() {
  setUp(() {
    // `TomEmptyState` resolves its strings in the constructor, so a provider
    // has to be installed before the example builds one. No colours adapter:
    // nothing in `custom/` resolves a colour through `TomUIColors` — these
    // widgets take their appearance from the ambient `ThemeData`.
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(const {}),
    );
    TomAuthorization.reset();
  });
  tearDown(TomAuthorization.reset);

  test('the custom example runs end to end with its assertions', () {
    expect(example.run, returnsNormally);
  });
}
