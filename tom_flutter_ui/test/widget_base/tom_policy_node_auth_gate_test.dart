import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// tests §61(a): TomPolicyNodeBase is the authorization-enforcement layer every
// Tom widget passes through, yet the four-state `_buildWithAuth` switch had zero
// testWidgets coverage. These pin the dispatch:
//   none     → SizedBox.shrink  (hidden from layout)
//   disabled → buildDisabled    (theme's disabledStyle; default 0.38)
//   read     → buildReadonly    (theme's readonlyStyle; default 0.6)
//   full     → buildContent     (bare, interactive)
// State is driven through the build-time uiStateController, which can only
// narrow the construction-time `full` default.

/// Minimal concrete node whose content is a findable marker.
class _GatedNode extends TomPolicyNodeBase {
  _GatedNode({super.uiStateController});

  @override
  Widget buildContent(BuildContext context) => const Text('content');
}

TomUIStateController _forceState(TomAuthState state) =>
    TomUIStateController(resolve: (_, _) => state);

Widget _host(Widget child) =>
    Directionality(textDirection: TextDirection.ltr, child: child);

void main() {
  group('TomPolicyNodeBase 4-state auth gate (§61a)', () {
    testWidgets('full → renders bare content, no auth wrapper', (tester) async {
      await tester.pumpWidget(_host(_GatedNode()));

      expect(find.text('content'), findsOneWidget);
      expect(find.byType(AbsorbPointer), findsNothing);
      expect(find.byType(Opacity), findsNothing);
    });

    testWidgets('none → SizedBox.shrink, content removed from layout',
        (tester) async {
      await tester.pumpWidget(
        _host(_GatedNode(uiStateController: _forceState(TomAuthState.none))),
      );

      expect(find.text('content'), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
      final box = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(box.width, 0);
      expect(box.height, 0);
    });

    testWidgets('disabled → AbsorbPointer + 0.38 opacity over content',
        (tester) async {
      await tester.pumpWidget(
        _host(
            _GatedNode(uiStateController: _forceState(TomAuthState.disabled))),
      );

      expect(find.text('content'), findsOneWidget);
      expect(find.byType(AbsorbPointer), findsOneWidget);
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity,
          closeTo(0.38, 0.001));
    });

    testWidgets('read → AbsorbPointer + default 0.6 readonly opacity',
        (tester) async {
      await tester.pumpWidget(
        _host(_GatedNode(uiStateController: _forceState(TomAuthState.read))),
      );

      expect(find.text('content'), findsOneWidget);
      expect(find.byType(AbsorbPointer), findsOneWidget);
      // Distinguishes read (0.6) from disabled (0.38).
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity,
          closeTo(0.6, 0.001));
    });

    // The two treatments above are theme *defaults*, not fixed values. The
    // disabled one used to be a literal in this file's production counterpart
    // (and a second literal in TomWidgetMixin), so an app could restyle `read`
    // and find `disabled` unchanged. Both states resolve from the scope now,
    // and `tom_widget_mixin_test.dart` asserts the same 0.2 through the other
    // enforcement point — the same number in both places is what pins that the
    // two agree.
    testWidgets('both treatments follow the scoped theme, not a literal',
        (tester) async {
      Widget scoped(TomAuthState state) => _host(
            TomThemeScope(
              theme: const TomTheme(
                readonlyStyle: TomStateStyle(opacity: 0.7),
                disabledStyle: TomStateStyle(opacity: 0.2),
              ),
              child: _GatedNode(uiStateController: _forceState(state)),
            ),
          );

      await tester.pumpWidget(scoped(TomAuthState.disabled));
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity,
          closeTo(0.2, 0.001));

      await tester.pumpWidget(scoped(TomAuthState.read));
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity,
          closeTo(0.7, 0.001));
    });
  });
}
