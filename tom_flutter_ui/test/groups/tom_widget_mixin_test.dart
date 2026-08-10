import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// tests §24: TomWidgetMixin is the render contract every direct-extension Tom
// widget shares — `getAuth()` (resource → group → authorizer →
// uiStateController), `checkHidden()`, and the 4-state `applyAuthState` visual
// treatment — yet it had no dedicated coverage. These pin the combination
// order and the per-state rendering.

/// Minimal concrete widget mixing in [TomWidgetMixin].
class _MixinWidget extends StatelessWidget with TomWidgetMixin {
  _MixinWidget({
    this.tomId,
    this.authorizer,
    this.uiStateController,
    this.tomGroup,
    required this.child,
  });

  @override
  final String? tomId;
  @override
  final TomAuthorizer? authorizer;
  @override
  final TomUIStateController? uiStateController;
  @override
  final TomAuthorizationGroup? tomGroup;

  final Widget child;

  @override
  Widget build(BuildContext context) => applyAuthState(context, child);
}

class _MapAuthAdapter implements TomAuthorizationAdapter {
  _MapAuthAdapter(this.rules);
  final Map<String, TomAuthState> rules;
  @override
  TomAuthState resolveAuth(String path) => rules[path] ?? TomAuthState.full;
}

Widget _host(Widget child) =>
    Directionality(textDirection: TextDirection.ltr, child: child);

void main() {
  tearDown(TomAuthorization.reset);

  group('TomWidgetMixin.getAuth combination order (§24)', () {
    test('defaults to full with no tomId and no adapter', () {
      expect(_MixinWidget(child: const Text('x')).getAuth(), TomAuthState.full);
    });

    test('resolves resource auth at basePath', () {
      TomAuthorization.adapter = _MapAuthAdapter({'w': TomAuthState.read});
      expect(_MixinWidget(tomId: 'w', child: const Text('x')).getAuth(),
          TomAuthState.read);
    });

    test('authorizer narrows resource auth', () {
      TomAuthorization.adapter = _MapAuthAdapter({'w': TomAuthState.full});
      final widget = _MixinWidget(
        tomId: 'w',
        authorizer: TomAuthorizer.fixed(TomAuthState.disabled),
        child: const Text('x'),
      );
      // narrowsOnly default: full narrowed by disabled → disabled.
      expect(widget.getAuth(), TomAuthState.disabled);
    });

    test('uiStateController narrows resource auth', () {
      TomAuthorization.adapter = _MapAuthAdapter({'w': TomAuthState.full});
      final widget = _MixinWidget(
        tomId: 'w',
        uiStateController:
            TomUIStateController(resolve: (_, _) => TomAuthState.read),
        child: const Text('x'),
      );
      expect(widget.getAuth(), TomAuthState.read);
    });

    test('group applyMode (controlsAll) replaces the state', () {
      TomAuthorization.adapter = _MapAuthAdapter({
        'w': TomAuthState.full,
        'grp': TomAuthState.read,
      });
      final widget = _MixinWidget(
        tomId: 'w',
        tomGroup: TomAuthorizationGroup('grp', mode: AuthGroupMode.controlsAll),
        child: const Text('x'),
      );
      expect(widget.getAuth(), TomAuthState.read);
    });
  });

  group('TomWidgetMixin.checkHidden (§24)', () {
    test('returns SizedBox.shrink when none, null otherwise', () {
      TomAuthorization.adapter = _MapAuthAdapter({'w': TomAuthState.none});
      expect(_MixinWidget(tomId: 'w', child: const Text('x')).checkHidden(),
          isA<SizedBox>());
      TomAuthorization.adapter = _MapAuthAdapter({'w': TomAuthState.full});
      expect(_MixinWidget(tomId: 'w', child: const Text('x')).checkHidden(),
          isNull);
    });
  });

  group('TomWidgetMixin.applyAuthState visual treatment (§24)', () {
    testWidgets('full → bare child', (tester) async {
      await tester.pumpWidget(_host(_MixinWidget(child: const Text('x'))));
      expect(find.text('x'), findsOneWidget);
      expect(find.byType(AbsorbPointer), findsNothing);
      expect(find.byType(Opacity), findsNothing);
    });

    testWidgets('none → SizedBox.shrink, child removed', (tester) async {
      TomAuthorization.adapter = _MapAuthAdapter({'w': TomAuthState.none});
      await tester.pumpWidget(
          _host(_MixinWidget(tomId: 'w', child: const Text('x'))));
      expect(find.text('x'), findsNothing);
    });

    testWidgets('disabled → AbsorbPointer + 0.38 opacity', (tester) async {
      TomAuthorization.adapter = _MapAuthAdapter({'w': TomAuthState.disabled});
      await tester.pumpWidget(
          _host(_MixinWidget(tomId: 'w', child: const Text('x'))));
      expect(find.byType(AbsorbPointer), findsOneWidget);
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity,
          closeTo(0.38, 0.001));
    });

    testWidgets('read → default readonly AbsorbPointer + 0.6 opacity',
        (tester) async {
      TomAuthorization.adapter = _MapAuthAdapter({'w': TomAuthState.read});
      await tester.pumpWidget(
          _host(_MixinWidget(tomId: 'w', child: const Text('x'))));
      expect(find.byType(AbsorbPointer), findsOneWidget);
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity,
          closeTo(0.6, 0.001));
    });
  });
}
