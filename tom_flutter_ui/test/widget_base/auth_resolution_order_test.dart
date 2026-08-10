import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// tests §78: the four authorization layers have to compose in the order
// resource → group → authorizer → uiStateController.
//
// `uiStateController` is documented as being able to *only narrow, never
// widen* the effective state. That promise only holds if the controller runs
// last. `TomAuthorizationGroup.applyMode` widens under `controlsNarrowest` and
// replaces outright under `controlsAll`, so a group applied after the
// controller silently undoes the narrowing the controller just performed.
//
// `TomField.resolveEffectiveAuth` (forms, §19) already resolves group at
// position 2. These pin the same order for the two widget-side resolvers,
// `TomPolicyNodeBase.resolveEffectiveAuth` and `TomWidgetMixin.getAuth`.

class _MapAuthAdapter implements TomAuthorizationAdapter {
  _MapAuthAdapter(this.rules);
  final Map<String, TomAuthState> rules;
  @override
  TomAuthState resolveAuth(String path) => rules[path] ?? TomAuthState.full;
}

/// Minimal [TomPolicyNodeBase] whose content is a findable marker.
class _GatedNode extends TomPolicyNodeBase {
  _GatedNode({super.tomId, super.tomGroup, super.uiStateController});

  @override
  Widget buildContent(BuildContext context) => const Text('content');
}

/// Minimal [TomWidgetMixin] implementor.
class _MixinWidget extends StatelessWidget with TomWidgetMixin {
  _MixinWidget({this.tomId, this.tomGroup, this.uiStateController});

  @override
  final String? tomId;
  @override
  final TomAuthorizationGroup? tomGroup;
  @override
  final TomUIStateController? uiStateController;

  @override
  Widget build(BuildContext context) =>
      applyAuthState(context, const Text('content'));
}

TomUIStateController _narrowTo(TomAuthState state) =>
    TomUIStateController(resolve: (_, _) => state);

void main() {
  tearDown(TomAuthorization.reset);

  group('auth resolution order: group precedes the controller (§78)', () {
    test('controlsAll group does not undo the controller (policy node)', () {
      TomAuthorization.adapter = _MapAuthAdapter({
        'w': TomAuthState.full,
        'grp': TomAuthState.full,
      });
      final node = _GatedNode(
        tomId: 'w',
        tomGroup: TomAuthorizationGroup('grp', mode: AuthGroupMode.controlsAll),
        uiStateController: _narrowTo(TomAuthState.read),
      );
      // Group replaces full with full, then the controller narrows to read.
      expect(node.resolveEffectiveAuth(), TomAuthState.read);
    });

    test('controlsAll group does not undo the controller (widget mixin)', () {
      TomAuthorization.adapter = _MapAuthAdapter({
        'w': TomAuthState.full,
        'grp': TomAuthState.full,
      });
      final widget = _MixinWidget(
        tomId: 'w',
        tomGroup: TomAuthorizationGroup('grp', mode: AuthGroupMode.controlsAll),
        uiStateController: _narrowTo(TomAuthState.read),
      );
      expect(widget.getAuth(), TomAuthState.read);
    });

    test('controlsNarrowest group widens before the controller narrows', () {
      TomAuthorization.adapter = _MapAuthAdapter({
        'w': TomAuthState.read,
        'grp': TomAuthState.full,
      });
      final node = _GatedNode(
        tomId: 'w',
        tomGroup:
            TomAuthorizationGroup('grp', mode: AuthGroupMode.controlsNarrowest),
        uiStateController: _narrowTo(TomAuthState.disabled),
      );
      // read widened to full by the group, then narrowed to disabled.
      expect(node.resolveEffectiveAuth(), TomAuthState.disabled);
    });

    test('group still applies when no controller is present', () {
      TomAuthorization.adapter = _MapAuthAdapter({
        'w': TomAuthState.full,
        'grp': TomAuthState.read,
      });
      final node = _GatedNode(
        tomId: 'w',
        tomGroup: TomAuthorizationGroup('grp', mode: AuthGroupMode.controlsAll),
      );
      expect(node.resolveEffectiveAuth(), TomAuthState.read);
    });

    testWidgets('the narrowed state reaches the render path', (tester) async {
      TomAuthorization.adapter = _MapAuthAdapter({
        'w': TomAuthState.full,
        'grp': TomAuthState.full,
      });
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: _GatedNode(
            tomId: 'w',
            tomGroup:
                TomAuthorizationGroup('grp', mode: AuthGroupMode.controlsAll),
            uiStateController: _narrowTo(TomAuthState.none),
          ),
        ),
      );

      // none → hidden; had the group run last, content would still render.
      expect(find.text('content'), findsNothing);
    });
  });
}
