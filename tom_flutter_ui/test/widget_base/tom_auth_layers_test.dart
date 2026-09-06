/// Pins the composition itself, at the one place it now lives.
///
/// `auth_resolution_order_test.dart` asserts the order through the two
/// widget-side resolvers and `tom_field_test.dart` through the form layer.
/// Those remain the proof that each caller *reaches* the composition. This
/// file exercises [TomAuthLayers.resolve] directly, because centralising it
/// made it the single point where a permutation breaks all three at once —
/// and because `narrowBy`, the layer only `forms/` supplies, has a position
/// that no widget test can reach.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

class _MapAuthAdapter implements TomAuthorizationAdapter {
  _MapAuthAdapter(this.rules);
  final Map<String, TomAuthState> rules;
  @override
  TomAuthState resolveAuth(String path) => rules[path] ?? TomAuthState.full;
}

TomUIStateController _narrowTo(TomAuthState state) =>
    TomUIStateController(resolve: (_, _) => state);

/// The composition with every optional layer absent, so each test names only
/// the layers it is about.
TomAuthState _resolve({
  String? basePath,
  TomAuthorizationGroup? group,
  TomAuthorizer? authorizer,
  TomUIStateController? uiStateController,
  TomAuthState? narrowBy,
}) => TomAuthLayers.resolve(
  basePath: basePath,
  group: group,
  groupScope: TomScope.current,
  authorizer: authorizer,
  uiStateController: uiStateController,
  narrowBy: narrowBy,
);

void main() {
  tearDown(TomAuthorization.reset);

  group('TomAuthLayers.resolve seeds from the resource layer', () {
    test(
      'a null basePath seeds full rather than looking up the empty path',
      () {
        // An element that addresses no resource is not an element addressing
        // `''` — the adapter must not be consulted at all.
        TomAuthorization.adapter = _MapAuthAdapter({'': TomAuthState.none});
        expect(_resolve(basePath: null), TomAuthState.full);
      },
    );

    test('a basePath resolves through the adapter', () {
      TomAuthorization.adapter = _MapAuthAdapter({'w': TomAuthState.read});
      expect(_resolve(basePath: 'w'), TomAuthState.read);
    });
  });

  group('TomAuthLayers.resolve applies narrowBy after the group', () {
    test('a controlsAll group cannot widen past narrowBy', () {
      // The form's ceiling is the reason `narrowBy` sits where it does: run it
      // before the group and a `controlsAll` group would replace it outright.
      TomAuthorization.adapter = _MapAuthAdapter({
        'f': TomAuthState.read,
        'grp': TomAuthState.full,
      });
      expect(
        _resolve(
          basePath: 'f',
          group: TomAuthorizationGroup('grp', mode: AuthGroupMode.controlsAll),
          narrowBy: TomAuthState.read,
        ),
        TomAuthState.read,
      );
    });

    test('a controlsNarrowest group cannot widen past narrowBy either', () {
      TomAuthorization.adapter = _MapAuthAdapter({
        'f': TomAuthState.read,
        'grp': TomAuthState.full,
      });
      expect(
        _resolve(
          basePath: 'f',
          group: TomAuthorizationGroup(
            'grp',
            mode: AuthGroupMode.controlsNarrowest,
          ),
          narrowBy: TomAuthState.disabled,
        ),
        TomAuthState.disabled,
      );
    });

    test('an absent narrowBy leaves the group result standing', () {
      TomAuthorization.adapter = _MapAuthAdapter({
        'f': TomAuthState.read,
        'grp': TomAuthState.full,
      });
      expect(
        _resolve(
          basePath: 'f',
          group: TomAuthorizationGroup(
            'grp',
            mode: AuthGroupMode.controlsNarrowest,
          ),
        ),
        TomAuthState.full,
      );
    });
  });

  group('TomAuthLayers.resolve applies narrowBy before the authorizer', () {
    test('a deciding authorizer answers over narrowBy', () {
      // `authorizerDecides` is documented as deciding outright. Were narrowBy
      // to run after it, the authorizer could no longer widen and the two
      // strategies would collapse into one.
      TomAuthorization.adapter = _MapAuthAdapter({'f': TomAuthState.full});
      expect(
        _resolve(
          basePath: 'f',
          narrowBy: TomAuthState.read,
          authorizer: TomAuthorizer.fixed(TomAuthState.full),
        ),
        TomAuthState.full,
      );
    });

    test('a narrowing authorizer sees the already-narrowed state', () {
      TomAuthorization.adapter = _MapAuthAdapter({'f': TomAuthState.full});
      expect(
        _resolve(
          basePath: 'f',
          narrowBy: TomAuthState.read,
          authorizer: TomAuthorizer(resolve: (state) => state),
        ),
        TomAuthState.read,
      );
    });
  });

  group('TomAuthLayers.resolve runs the controller last', () {
    test('the controller narrows what the group widened', () {
      TomAuthorization.adapter = _MapAuthAdapter({
        'w': TomAuthState.read,
        'grp': TomAuthState.full,
      });
      expect(
        _resolve(
          basePath: 'w',
          group: TomAuthorizationGroup(
            'grp',
            mode: AuthGroupMode.controlsNarrowest,
          ),
          uiStateController: _narrowTo(TomAuthState.disabled),
        ),
        TomAuthState.disabled,
      );
    });

    test('the controller narrows what a deciding authorizer widened', () {
      TomAuthorization.adapter = _MapAuthAdapter({'w': TomAuthState.none});
      expect(
        _resolve(
          basePath: 'w',
          authorizer: TomAuthorizer.fixed(TomAuthState.full),
          uiStateController: _narrowTo(TomAuthState.read),
        ),
        TomAuthState.read,
      );
    });
  });

  test('every layer is optional', () {
    TomAuthorization.adapter = _MapAuthAdapter({});
    expect(_resolve(), TomAuthState.full);
  });
}
