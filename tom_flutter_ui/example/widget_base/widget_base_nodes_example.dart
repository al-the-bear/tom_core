/// Executable example for the node half of the `widget_base/` module of
/// `tom_flutter_ui`.
///
/// `widget_base_example.dart` covers resource binding — `TomCtr` and
/// `TomStyleResolvers`. This one covers the other two things every Tom node
/// does before it renders anything:
///
/// 1. **Identity & scope** — a node composes a canonical `basePath` from the
///    scope it was constructed in and its own `tomId`.
/// 2. **Authorization** — it passes through a four-layer gate that resolves a
///    `TomAuthState`, and that state decides which build hook runs.
///
/// plus the classification the rest of the framework dispatches on:
///
/// 3. **Family** — a widget belongs to the family whose branch base it
///    extends, and a caller asks with an `is` test.
///
/// None of the three needs a widget tree. `basePath` is computed in the
/// `TomNodeBase` constructor, `resolveEffectiveAuth()` is public and takes no
/// `BuildContext`, and the family is the widget's type — so all three are readable
/// on a constructed node, and this example asserts them directly rather than
/// pumping. Because it imports `flutter/material` (which pulls in `dart:ui`),
/// bare `dart run` cannot execute it. Run `flutter test
/// test/widget_base/widget_base_nodes_example_test.dart`, which calls this
/// example and reports its result in the exit code.
library;

// Demonstration example: console output is intentional.
// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// A resource-driven authorization adapter: grants keyed by resource path.
///
/// This is the shape an application installs at startup. Anything the map does
/// not mention resolves to [TomAuthState.full], which is also what
/// `TomAuthorization` answers when no adapter is installed at all.
class _GrantsAdapter implements TomAuthorizationAdapter {
  _GrantsAdapter(this.grants);

  final Map<String, TomAuthState> grants;

  @override
  TomAuthState resolveAuth(String resourceKeyPath) =>
      grants[resourceKeyPath] ?? TomAuthState.full;
}

/// A leaf node in the `label` family.
///
/// Concrete Tom widgets extend a branch base and implement [buildContent] —
/// never `build`, which `TomPolicyNodeBase` owns so the gate cannot be
/// bypassed.
class _Caption extends TomLabelBase {
  _Caption({super.tomId, super.scope, super.uiStateController});

  @override
  Widget buildContent(BuildContext context) => Text(TomCtr.text(basePath));
}

/// A leaf node in the `button` family. Same base class chain, different branch.
class _ActionButton extends TomButtonBase {
  _ActionButton({super.tomId, super.tomGroup, super.scope, super.authorizer});

  @override
  Widget buildContent(BuildContext context) => Text(TomCtr.text(basePath));
}

/// A screen-element provider: it declares its widgets as fields and *is* the
/// scope they resolve against, so children pass `scope: this`.
class _OrderElements extends TomScreenElementsProviderBase {
  _OrderElements([TomScreenElementsProvider? parent]) : super('order', parent);

  late final total = _Caption(tomId: 'total', scope: this);
  late final save = _ActionButton(
    tomId: 'save',
    scope: this,
    tomGroup: editing,
  );
  late final details = _OrderDetails(this);

  /// The group the editable elements of this screen share.
  final editing = TomAuthorizationGroup('editing');
}

/// A nested provider — its scope chains under its parent's.
class _OrderDetails extends TomScreenElementsProviderBase {
  _OrderDetails(TomScreenElementsProvider parent) : super('details', parent);

  late final note = _Caption(tomId: 'note', scope: this);
}

void run() {
  // Resource text, keyed by the *fully scoped* path. A node that resolved
  // against the wrong scope would miss every one of these.
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(<String, dynamic>{
      'checkout': {
        'order': {
          'total': 'Order total',
          'save': 'Save order',
          'details': {'note': 'Delivery note'},
        },
      },
    }),
  );

  // The grants an application's authorization adapter would answer with. Note
  // `checkout.order.editing` — a group resolves its own path the same way a
  // node does, as `<scope path>.<groupId>`.
  TomAuthorization.adapter = _GrantsAdapter(<String, TomAuthState>{
    'checkout.order.total': TomAuthState.read,
    'checkout.order.save': TomAuthState.full,
    'checkout.order.editing': TomAuthState.read,
    'checkout.order.details.note': TomAuthState.none,
  });

  // ───────────────────────────────────────────────────────────────────────
  // Pillar 1 — identity & scope
  // ───────────────────────────────────────────────────────────────────────

  // The provider is constructed inside the ambient scope; its own segment
  // nests under it, and its children nest under the provider.
  final order = TomScope.withScope('checkout', () => _OrderElements());

  print('provider scope     -> ${order.scope.getScopePath()}');
  print('total.basePath     -> ${order.total.basePath}');
  print('save.basePath      -> ${order.save.basePath}');
  print('note.basePath      -> ${order.details.note.basePath}');
  print('save.debugLabel    -> ${order.save.debugLabel}');

  assert(order.scope.getScopePath() == 'checkout.order');
  assert(order.total.basePath == 'checkout.order.total');
  assert(order.save.basePath == 'checkout.order.save');
  assert(order.details.note.basePath == 'checkout.order.details.note');

  // The base path is what the node reads its resources with — identity and
  // resource binding are the same address, not two parallel ones.
  assert(TomCtr.text(order.total.basePath) == 'Order total');
  assert(TomCtr.text(order.details.note.basePath) == 'Delivery note');

  // An explicit scope replaces the ambient one outright rather than nesting
  // under it — useful for a widget that must address a different bundle.
  final adminScope = TomScopeBase(scopeId: 'admin');
  final impersonated = TomScope.withScope(
    'checkout',
    () => _Caption(tomId: 'total', scope: adminScope),
  );
  print('explicit scope     -> ${impersonated.basePath}');
  assert(impersonated.basePath == 'admin.total');

  // ───────────────────────────────────────────────────────────────────────
  // Pillar 2 — the four-layer authorization gate
  // ───────────────────────────────────────────────────────────────────────

  // Layer 1, resource auth alone: the grant for `checkout.order.total` is
  // `read`, and nothing else touches this node.
  print('total  auth        -> ${order.total.resolveEffectiveAuth()}');
  assert(order.total.resolveEffectiveAuth() == TomAuthState.read);

  // Layer 2, the group ceiling: the node's own grant is `full`, but it is a
  // member of `editing`, whose grant is `read`. The default mode
  // (`controlsWidest`) makes the group a ceiling, so the member narrows to it.
  print('save   auth        -> ${order.save.resolveEffectiveAuth()}');
  assert(
    TomAuthorization.resolveAuth(order.save.basePath!) == TomAuthState.full,
  );
  assert(order.save.resolveEffectiveAuth() == TomAuthState.read);

  // Layer 3, the per-widget authorizer. `TomAuthorizer.fixed` uses the
  // `authorizerDecides` strategy, so it overrides the resource grant in either
  // direction; the default `authorizerNarrowsOnly` strategy could only narrow.
  final export = TomScope.withScope(
    'checkout',
    () => _ActionButton(
      tomId: 'export',
      authorizer: TomAuthorizer.fixed(TomAuthState.disabled),
    ),
  );
  print('export auth        -> ${export.resolveEffectiveAuth()}');
  assert(TomAuthorization.resolveAuth(export.basePath!) == TomAuthState.full);
  assert(export.resolveEffectiveAuth() == TomAuthState.disabled);

  // Layer 4, the build-time controller. It runs last and can only *narrow*:
  // asking for `full` on a `read` resource changes nothing, asking for `none`
  // takes effect.
  final tryToWiden = _Caption(
    tomId: 'total',
    scope: order,
    uiStateController: TomUIStateController(
      resolve: (_, _) => TomAuthState.full,
    ),
  );
  final narrowed = _Caption(
    tomId: 'total',
    scope: order,
    uiStateController: TomUIStateController(
      resolve: (_, _) => TomAuthState.none,
    ),
  );
  print('widen attempt      -> ${tryToWiden.resolveEffectiveAuth()}');
  print('narrow attempt     -> ${narrowed.resolveEffectiveAuth()}');
  assert(tryToWiden.resolveEffectiveAuth() == TomAuthState.read);
  assert(narrowed.resolveEffectiveAuth() == TomAuthState.none);

  // What the resolved state means for rendering. `build` dispatches on exactly
  // these predicates: `none` renders `SizedBox.shrink()`, `disabled` and `read`
  // render `buildDisabled` / `buildReadonly`, `full` renders `buildContent`.
  final noteAuth = order.details.note.resolveEffectiveAuth();
  print('note   auth        -> $noteAuth (visible: ${noteAuth.isVisible})');
  assert(noteAuth == TomAuthState.none);
  assert(!noteAuth.isVisible);
  assert(!TomAuthState.disabled.showsContent);
  assert(TomAuthState.read.showsContent);
  assert(!TomAuthState.read.isInteractive);
  assert(TomAuthState.full.isInteractive);

  // ───────────────────────────────────────────────────────────────────────
  // Pillar 3 — the family taxonomy
  // ───────────────────────────────────────────────────────────────────────

  // A widget's family is the branch base it extends, so asking is an `is`
  // test — here on the common supertype, the way a tool holding "some Tom
  // widget" would ask. It is fixed by the type: no configuration makes the
  // total a button.
  final TomFamilyBase total = order.total;
  final TomFamilyBase save = order.save;
  print('total  is TomLabelBase  -> ${total is TomLabelBase}');
  print('save   is TomButtonBase -> ${save is TomButtonBase}');
  assert(total is TomLabelBase && total is! TomButtonBase);
  assert(save is TomButtonBase && save is! TomLabelBase);

  // Leave no global state behind: both the resource provider and the
  // authorization adapter are process-wide singletons.
  TomAuthorization.reset();
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(<String, dynamic>{}),
  );
}

void main() => run();
