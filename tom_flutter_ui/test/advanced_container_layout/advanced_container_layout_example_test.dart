import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../../example/advanced_container_layout/advanced_container_layout_example.dart'
    as example;

void main() {
  group('advanced_container_layout example', () {
    test('runs end to end with its assertions', () {
      expect(example.run, returnsNormally);
    });
  });

  group('AclFlags', () {
    test('expand and otherDim compose from their axis bits', () {
      expect(AclFlags.expand, AclFlags.expandX | AclFlags.expandY);
      expect(AclFlags.otherDim, AclFlags.otherDimX | AclFlags.otherDimY);
    });
  });

  group('AclDeviceContext static resolvers', () {
    test('resolveFormFactor uses the 600/1024 width thresholds', () {
      expect(AclDeviceContext.resolveFormFactor(599), AclFormFactor.phone);
      expect(AclDeviceContext.resolveFormFactor(600), AclFormFactor.tablet);
      expect(AclDeviceContext.resolveFormFactor(1023), AclFormFactor.tablet);
      expect(AclDeviceContext.resolveFormFactor(1024), AclFormFactor.desktop);
    });

    test('resolveDensity averages the visual density axes', () {
      expect(
        AclDeviceContext.resolveDensity(
          const VisualDensity(horizontal: -2, vertical: -2),
        ),
        AclDensity.compact,
      );
      expect(
        AclDeviceContext.resolveDensity(
          const VisualDensity(horizontal: -1, vertical: -1),
        ),
        AclDensity.comfortable,
      );
      expect(
        AclDeviceContext.resolveDensity(VisualDensity.standard),
        AclDensity.standard,
      );
    });

    test('resolveInputMode maps mobile to touch, desktop to pointer', () {
      expect(
        AclDeviceContext.resolveInputMode(TargetPlatform.android),
        AclInputMode.touch,
      );
      expect(
        AclDeviceContext.resolveInputMode(TargetPlatform.linux),
        AclInputMode.pointer,
      );
    });

    test('buildConvenienceDetector returns null only for an empty spec', () {
      expect(AclDeviceContext.buildConvenienceDetector(), isNull);
      expect(
        AclDeviceContext.buildConvenienceDetector(
          formFactor: AclFormFactor.phone,
        ),
        isNotNull,
      );
    });
  });

  group('group-visibility controllers', () {
    test('AclBinaryVisibilityController toggles via its notifier', () {
      final ctrl = AclBinaryVisibilityController(
        initialMode: AclGroupVisibilityMode.hidden,
      );
      addTearDown(ctrl.dispose);
      expect(ctrl.mode, AclGroupVisibilityMode.hidden);
      expect(ctrl.modeNotifier.value, AclGroupVisibilityMode.hidden);
      ctrl.mode = AclGroupVisibilityMode.visible;
      expect(ctrl.modeNotifier.value, AclGroupVisibilityMode.visible);
    });

    test('AclCallbackVisibilityController derives mode from its source', () {
      final country = ValueNotifier<String>('DE');
      addTearDown(country.dispose);
      final ctrl = AclCallbackVisibilityController<String>(
        valueListenable: country,
        modeBuilder: (c) => c == 'US'
            ? AclGroupVisibilityMode.visible
            : AclGroupVisibilityMode.hidden,
      );
      addTearDown(ctrl.dispose);
      expect(ctrl.mode, AclGroupVisibilityMode.hidden);
      country.value = 'US';
      expect(ctrl.mode, AclGroupVisibilityMode.visible);
    });
  });

  group('AclBuilder', () {
    test('build() produces an Acl widget from a fluent chain', () {
      final acl = AclBuilder(title: 'Address')
          .append(const Text('Street'))
          .gap()
          .append(const Text('No.'))
          .newRow()
          .append(const Text('City'))
          .build();
      expect(acl, isA<Acl>());
    });

    test('appending the same widget instance twice is rejected', () {
      const shared = Text('shared');
      final builder = AclBuilder().append(shared);
      expect(() => builder.append(shared), throwsUnsupportedError);
    });
  });
}
