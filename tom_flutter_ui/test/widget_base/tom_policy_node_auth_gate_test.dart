import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/src/widget_base/tom_policy_node_base.dart';

// tests §61(a): TomPolicyNodeBase is the authorization-enforcement layer every
// Tom widget passes through, yet the four-state `_buildWithAuth` switch had zero
// testWidgets coverage. These pin the dispatch:
//   none     → SizedBox.shrink  (hidden from layout)
//   disabled → buildDisabled    (AbsorbPointer + Opacity 0.38)
//   read     → buildReadonly    (default TomReadonlyStyle: AbsorbPointer + 0.6)
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
  });
}
