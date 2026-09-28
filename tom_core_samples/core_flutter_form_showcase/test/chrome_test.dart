// The showcase's own chrome - the parts a reader copies rather than reads about.
// Shared in shape with `core_flutter_acl_sample` / `core_flutter_acl_responsive`,
// whose `test/chrome_test.dart` files test the same `CodeBlock`; the copies differ
// in the bundle and its keys.
//
// `CodeBlock`'s copy button writes to the clipboard, and the two chrome
// strings are resources (G-RES-1): a key that failed to resolve would render as
// the raw key with every other test green, so each is asserted to resolve to the
// string the bundle declares.

import 'package:core_flutter_form_showcase/showcase_app.dart';
import 'package:core_flutter_form_showcase/common/chrome_texts.dart';
import 'package:core_flutter_form_showcase/common/code_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart' show TomCtr;

const _chromeKeys = ['showcase.app.title', 'showcase.codeBlock.copyTooltip'];

void main() {
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
      MaterialApp(home: Scaffold(body: CodeBlock('\n  AclBuilder()  \n'))),
    );
    await tester.tap(find.byTooltip('Copy snippet'));
    await tester.pump();

    expect(copied, 'AclBuilder()');
  });

  test('every chrome key resolves to the string the bundle declares', () {
    for (final key in _chromeKeys) {
      expect(chromeTexts, contains(key));
      expect(TomCtr.text(key), chromeTexts[key], reason: key);
      expect(TomCtr.text(key), isNot(key), reason: '$key echoed, not resolved');
    }
  });

  testWidgets('the home app bar shows the resolved app title', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ShowcaseApp());
    await tester.pump();

    expect(
      find.text(chromeTexts['showcase.app.title'] as String),
      findsWidgets,
    );
    expect(find.text('showcase.app.title'), findsNothing);
  });
}
