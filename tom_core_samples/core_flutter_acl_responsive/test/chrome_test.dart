// The showcase's own chrome - the parts a reader copies rather than reads about.
// Shared in shape with `core_flutter_acl_sample` / `core_flutter_form_showcase`,
// whose `test/chrome_test.dart` files test the same `CodeBlock`; the copies differ
// in the bundle and its keys.
//
// `CodeBlock`'s copy button is the app's only interactive affordance, and the two
// chrome strings are resources (G-RES-1): a key that failed to resolve would
// render as the raw key, which is the failure the resource rule exists to make
// visible, so each is asserted to resolve to the string the bundle declares.

import 'package:core_flutter_acl_responsive/common/chrome_texts.dart';
import 'package:core_flutter_acl_responsive/common/code_block.dart';
import 'package:core_flutter_acl_responsive/reflection_seed.dart';
import 'package:core_flutter_acl_responsive/showcase_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart' show TomCtr;

void main() {
  setUpAll(initializeReflection);
  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(showcaseTexts),
    );
  });

  testWidgets('the copy button puts the trimmed snippet on the clipboard', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: CodeBlock('\n  final x = 1;  \n'))),
    );
    // The tooltip is the resolved resource, so finding the button by it is
    // also the assertion that the key resolved.
    await tester.tap(find.byTooltip('Copy snippet'));
    await tester.pump();

    expect(copied, 'final x = 1;');
  });

  test('both chrome keys resolve to the strings the bundle declares', () {
    for (final key in [
      'showcase.app.title',
      'showcase.codeBlock.copyTooltip',
    ]) {
      expect(showcaseTexts, contains(key));
      expect(TomCtr.text(key), showcaseTexts[key], reason: key);
      expect(TomCtr.text(key), isNot(key), reason: '$key echoed, not resolved');
    }
  });

  testWidgets('the app bar shows the resolved app title', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ResponsiveApp());
    await tester.pump();

    expect(
      find.text(showcaseTexts['showcase.app.title']! as String),
      findsWidgets,
    );
    expect(find.text('showcase.app.title'), findsNothing);
  });
}
