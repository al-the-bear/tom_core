import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../../example/widgets/widgets_example.dart' as example;

class _PathAuthAdapter extends TomAuthorizationAdapter {
  final Map<String, TomAuthState> rules;
  _PathAuthAdapter(this.rules);

  @override
  TomAuthState resolveAuth(String path) => rules[path] ?? TomAuthState.full;
}

void main() {
  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(const {}),
    );
    TomUIColors.adapter = AllColorsAdapter();
    TomAuthorization.reset();
  });
  tearDown(TomAuthorization.reset);

  group('widgets example', () {
    test('runs end to end with its assertions', () {
      expect(example.run, returnsNormally);
    });
  });

  group('family tagging', () {
    test('each wrapper reports its TomWidgetFamily', () {
      expect(
        TomElevatedButton(onPressed: () {}, child: TomText(text: 'x')).family,
        TomWidgetFamily.button,
      );
      expect(TomText(text: 'x').family, TomWidgetFamily.label);
      expect(TomCheckbox(value: false, onChanged: (_) {}).family,
          TomWidgetFamily.toggle);
      expect(TomContainer(child: const SizedBox()).family,
          TomWidgetFamily.container);
      expect(
        TomCircularProgressIndicator(semanticsLabel: 'busy').family,
        TomWidgetFamily.progress,
      );
    });

    test('isFamily / families reflect the primary family', () {
      final btn =
          TomElevatedButton(onPressed: () {}, child: TomText(text: 'x'));
      expect(btn.isFamily(TomWidgetFamily.button), isTrue);
      expect(btn.isFamily(TomWidgetFamily.label), isFalse);
      expect(btn.families, contains(TomWidgetFamily.button));
    });
  });

  group('basePath resolution', () {
    test('tomId becomes basePath at the top level', () {
      expect(TomText(tomId: 'greeting', text: 'x').basePath, 'greeting');
    });

    test('basePath is scope-prefixed inside a TomScope', () {
      TomScope.withScope('settings', () {
        expect(TomText(tomId: 'greeting', text: 'x').basePath,
            'settings.greeting');
      });
    });
  });

  group('effectiveAuthState resolution (no BuildContext)', () {
    test('resolves from resource auth and defaults to full', () {
      TomAuthorization.adapter =
          _PathAuthAdapter({'save': TomAuthState.read});
      final saveBtn = TomElevatedButton(
        tomId: 'save',
        onPressed: () {},
        child: TomText(text: 'Save'),
      );
      final freeLabel = TomText(tomId: 'greeting', text: 'Hello');
      expect(saveBtn.effectiveAuthState, TomAuthState.read);
      expect(freeLabel.effectiveAuthState, TomAuthState.full);
    });

    test('a group narrows the member to its ceiling', () {
      TomAuthorization.adapter =
          _PathAuthAdapter({'tools': TomAuthState.read});
      final tools = TomAuthorizationGroup('tools'); // controlsWidest
      final grouped = TomContainer(
        tomId: 'panel',
        tomGroup: tools,
        child: const SizedBox(),
      );
      expect(grouped.effectiveAuthState, TomAuthState.read);
    });
  });
}
