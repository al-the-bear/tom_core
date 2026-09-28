/// `resolveInputMode` answers from the platform, and from nothing else.
///
/// Flutter web on a phone reports `TargetPlatform.iOS` or `.android`, so a
/// resolver that returns early on `kIsWeb` calls every mobile browser a mouse.
/// The platform is the information already in hand, and it is right for the
/// device class where touch accuracy matters most.
///
/// The behavioural half of that cannot be written here: `kIsWeb` is a
/// compile-time constant and is `false` under `flutter test` on the VM, so a
/// reinstated short-circuit would be invisible to every assertion about what
/// the function returns. The source-shape case at the bottom is what closes
/// that, and it is the only thing standing between the fix and a one-line
/// revert nobody's tests would notice.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

const _source = 'lib/src/advanced_container_layout/acl_device_context.dart';

void main() {
  group('input mode comes from the platform', () {
    const touch = {TargetPlatform.iOS, TargetPlatform.android};

    for (final platform in TargetPlatform.values) {
      test('$platform', () {
        expect(
          AclDeviceContext.resolveInputMode(platform),
          touch.contains(platform) ? AclInputMode.touch : AclInputMode.pointer,
        );
      });
    }

    test('every platform is covered, and both answers occur', () {
      // Guards the loop above: a switch that returned one value for everything
      // would pass a table with only one answer in it, and an enum that gained
      // a member would silently stop being tested.
      final answers = TargetPlatform.values
          .map(AclDeviceContext.resolveInputMode)
          .toSet();
      expect(answers, {AclInputMode.touch, AclInputMode.pointer});
      expect(TargetPlatform.values.length, greaterThanOrEqualTo(6));
    });
  });

  group('a web target reporting a mobile platform resolves to touch', () {
    test('iOS and Android answer touch whatever the target', () {
      // The function reads only its argument, so this holds on web as it does
      // here — which is the whole claim, and why the shape case below exists.
      expect(
        AclDeviceContext.resolveInputMode(TargetPlatform.iOS),
        AclInputMode.touch,
      );
      expect(
        AclDeviceContext.resolveInputMode(TargetPlatform.android),
        AclInputMode.touch,
      );
    });

    test('resolveInputMode does not read kIsWeb', () {
      final source = File(_source).readAsLinesSync();
      final start = source.indexWhere(
        (l) => l.contains('static AclInputMode resolveInputMode('),
      );
      expect(start, isNot(-1), reason: 'resolveInputMode is gone or renamed');

      // To the end of the method: the next declaration at member indentation.
      final end = source.indexWhere(
        (l) => RegExp(r'^  [A-Za-z_@]').hasMatch(l),
        start + 1,
      );
      final body = source
          .sublist(start, end == -1 ? source.length : end)
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');

      expect(
        body,
        isNot(contains('kIsWeb')),
        reason:
            'the web is not a platform: a kIsWeb branch here classifies every '
            'phone browser as a pointer device, and no assertion about the '
            'return value can see it, because kIsWeb is false under the VM',
      );
    });

    testWidgets('the context still reports whether it is on the web', (
      tester,
    ) async {
      // The other half of the change: `isWeb` is kept as its own field, so a
      // variant that genuinely means "in a browser" is still expressible. It
      // is the *inference* from web to pointer that is gone, not the fact.
      final source = File(_source).readAsStringSync();
      expect(source, contains('isWeb: kIsWeb'));
      final detector = AclDeviceContext.buildConvenienceDetector(
        input: AclInputMode.pointer,
        isWeb: true,
      );
      expect(detector, isNotNull);

      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(
        detector!(
          _context(platform: TargetPlatform.macOS, isWeb: true),
          null,
          context,
        ),
        isTrue,
        reason: 'a desktop browser is still nameable',
      );
      expect(
        detector(
          _context(platform: TargetPlatform.iOS, isWeb: true),
          null,
          context,
        ),
        isFalse,
        reason: 'and a phone browser is no longer caught by it',
      );
    });
  });
}

/// A device context with everything but the two fields under test held fixed.
AclDeviceContext _context({
  required TargetPlatform platform,
  required bool isWeb,
}) => AclDeviceContext(
  width: 400,
  inputMode: AclDeviceContext.resolveInputMode(platform),
  formFactor: AclDeviceContext.resolveFormFactor(400),
  orientation: Orientation.portrait,
  platform: platform,
  isWeb: isWeb,
  density: AclDensity.standard,
  textDirection: TextDirection.ltr,
  accessibilityScale: 1.0,
);
