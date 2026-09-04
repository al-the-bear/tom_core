import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// Scope propagation is what makes implicit TomScope addressing (G-RES-2/3)
// work: a widget constructed inside a `TomScope.withScope` zone resolves its
// resources under that scope's path without naming it. The failure mode is
// silent — a widget that loses its scope still builds and still renders, it
// just reads the wrong resource bundle. These tests pin the two mechanisms
// that carry the scope across the places Flutter drops it.

/// A minimal [TomNodeBase] that renders its own resolved resource text.
///
/// [basePath] is computed in the [TomNodeBase] constructor from the ambient
/// scope, so what this widget paints is exactly what the scope resolution
/// produced — which is what makes it usable as a probe.
class _ProbeNode extends TomNodeBase {
  _ProbeNode({required String super.tomId, super.scope});

  // Authorization is orthogonal to scope resolution; the probe always has full
  // access so nothing hides the text these tests read.
  @override
  TomAuthState get effectiveAuthState => TomAuthState.full;

  @override
  Widget build(BuildContext context) => Text(TomCtr.text(basePath, 'label'));
}

/// A [TomStatelessWidget] that constructs its child inside [build].
///
/// This is the shape that breaks without scope capture: Flutter calls [build]
/// from its own zone, long after the constructing zone has been left, so the
/// child's `TomScope.current` would be [TomScope.defaultScope] unless the
/// parent re-enters the scope it captured at construction.
class _ScopedHost extends TomStatelessWidget {
  _ScopedHost({super.key, required this.childId});

  final String childId;

  @override
  Widget buildContent(BuildContext context) => _ProbeNode(tomId: childId);
}

/// The same shape built from a plain [StatelessWidget], used as the control:
/// without the scope capture the child must fall back to the default scope.
class _UnscopedHost extends StatelessWidget {
  const _UnscopedHost({required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context) => _ProbeNode(tomId: childId);
}

class _OrderProvider extends TomScreenElementsProviderBase {
  _OrderProvider([TomScreenElementsProvider? parent]) : super('order', parent);

  late final submit = _ProbeNode(tomId: 'submit', scope: this);
  late final details = _OrderDetailsProvider(this);
}

class _OrderDetailsProvider extends TomScreenElementsProviderBase {
  _OrderDetailsProvider(TomScreenElementsProvider parent)
    : super('details', parent);

  late final name = _ProbeNode(tomId: 'name', scope: this);
}

/// A provider that adopts whatever scope surrounds it instead of adding a
/// segment — the shape a root screen provider takes when it expects to be
/// constructed inside a [TomScope.withScope] zone.
///
/// Used here for the case the zone is *absent*, which is the default for a
/// provider and the one the adoption branch got wrong.
class _AdoptingProvider extends TomScreenElementsProviderBase {
  _AdoptingProvider([TomScreenElementsProvider? parent]) : super(null, parent);

  late final field = _ProbeNode(tomId: 'field', scope: this);
  late final order = _OrderProvider(this);
}

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUp(() {
    // Resource values keyed by the *fully scoped* path. A widget that resolves
    // against the wrong scope misses every one of these and TomCtr.text falls
    // back to echoing the key, which is what the assertions distinguish.
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(<String, dynamic>{
        'checkout': {
          'field': {'label': 'scoped value'},
          'order': {
            'submit': {'label': 'Submit order'},
            'details': {
              'name': {'label': 'Customer name'},
            },
          },
        },
        'field': {'label': 'unscoped value'},
      }),
    );
  });

  tearDown(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(<String, dynamic>{}),
    );
  });

  group('TomNodeBase base path resolution', () {
    test('an ambient scope prefixes the node id', () {
      TomScope.withScope('checkout', () {
        expect(_ProbeNode(tomId: 'field').basePath, 'checkout.field');
      });
    });

    test('nested ambient scopes build a dotted path', () {
      TomScope.withScope('checkout', () {
        TomScope.withScope('payment', () {
          expect(_ProbeNode(tomId: 'field').basePath, 'checkout.payment.field');
        });
      });
    });

    test('no ambient scope leaves the id unprefixed', () {
      // The root sentinel contributes no segment, so the path is the bare id.
      expect(_ProbeNode(tomId: 'field').basePath, 'field');
    });

    test('an explicit scope overrides the ambient one', () {
      final explicit = TomScopeBase(scopeId: 'admin');
      TomScope.withScope('checkout', () {
        expect(
          _ProbeNode(tomId: 'field', scope: explicit).basePath,
          'admin.field',
        );
      });
    });
  });

  group('TomStatelessWidget scope capture', () {
    testWidgets(
      'a child constructed in build inherits the construction scope',
      (tester) async {
        // The host is constructed inside the zone; the child is constructed by
        // Flutter later, outside it. Only the captured scope can bridge that.
        final hosted = TomScope.withScope(
          'checkout',
          () => _ScopedHost(childId: 'field'),
        );

        await tester.pumpWidget(_host(hosted));
        await tester.pumpAndSettle();

        expect(find.text('scoped value'), findsOneWidget);
        expect(find.text('unscoped value'), findsNothing);
      },
    );

    testWidgets(
      'without the capture the child falls back to the default scope',
      (tester) async {
        // The control: same construction site, same zone, no TomStatelessWidget.
        // It resolves the unscoped key — which is precisely the silent wrong-
        // bundle failure the capture exists to prevent.
        final hosted = TomScope.withScope(
          'checkout',
          () => const _UnscopedHost(childId: 'field'),
        );

        await tester.pumpWidget(_host(hosted));
        await tester.pumpAndSettle();

        expect(find.text('unscoped value'), findsOneWidget);
        expect(find.text('scoped value'), findsNothing);
      },
    );

    testWidgets('the captured scope survives a rebuild', (tester) async {
      final hosted = TomScope.withScope(
        'checkout',
        () => _ScopedHost(key: const Key('host'), childId: 'field'),
      );

      await tester.pumpWidget(_host(hosted));
      await tester.pumpAndSettle();
      // Force a second build from Flutter's zone.
      tester.element(find.byKey(const Key('host'))).markNeedsBuild();
      await tester.pumpAndSettle();

      expect(find.text('scoped value'), findsOneWidget);
    });
  });

  group('TomScreenElementsProviderBase scope nesting', () {
    test('a provider nests under the ambient scope', () {
      TomScope.withScope('checkout', () {
        expect(_OrderProvider().scope.getScopePath(), 'checkout.order');
      });
    });

    test('a provider supplies the base path for the widgets it declares', () {
      TomScope.withScope('checkout', () {
        expect(_OrderProvider().submit.basePath, 'checkout.order.submit');
      });
    });

    test('nesting providers chains their scope segments', () {
      TomScope.withScope('checkout', () {
        expect(
          _OrderProvider().details.name.basePath,
          'checkout.order.details.name',
        );
      });
    });

    test('a null scopeId adopts the ambient scope without nesting', () {
      TomScope.withScope('checkout', () {
        expect(
          TomScreenElementsProviderBase().scope.getScopePath(),
          'checkout',
        );
      });
    });
  });

  group('TomScreenElementsProviderBase adopting the root scope', () {
    // Adoption with no surrounding zone is the *default* shape for a provider,
    // and the one the group above does not reach: with an ambient 'checkout'
    // an adopted copy of the parent renders the same path, so the copy passes
    // for the original. The root sentinel is the case where it cannot, because
    // TomScope.buildScopePath elides the root by identity and never by name —
    // deliberately, so a domain scope legitimately named 'default' keeps its
    // segment. A copy reproduces the id and the parent faithfully; it cannot
    // reproduce identity, so it stops being elided and contributes a segment.

    test('adopting the root scope yields the empty path', () {
      expect(_AdoptingProvider().scope.getScopePath(), '');
    });

    test('a widget it declares resolves unprefixed', () {
      // The consequence a reader notices: every resource and authorization
      // lookup below a root provider would be prefixed with 'default.'.
      expect(_AdoptingProvider().field.basePath, 'field');
    });

    test('a nested provider does not inherit a root segment', () {
      expect(_AdoptingProvider().order.scope.getScopePath(), 'order');
    });

    test('widgets under a nested provider resolve without a root segment', () {
      expect(_AdoptingProvider().order.submit.basePath, 'order.submit');
    });

    test('running in the adopted scope adds no segment', () {
      final path = _AdoptingProvider().scope.runInScope(
        () => TomScope.withScope(
          'checkout',
          () => TomScope.current,
        ).getScopePath(),
      );
      expect(path, 'checkout');
    });

    test('adopting a non-root scope still yields that scope path', () {
      // The case that already worked, kept as the other half of the pair so a
      // fix for the root case cannot silently break the ordinary one.
      TomScope.withScope('checkout', () {
        expect(_AdoptingProvider().scope.getScopePath(), 'checkout');
      });
    });

    test('a provider named default keeps its segment', () {
      // The behaviour the identity check exists to protect: eliding by name
      // would make this path empty. It has to stay 'default'.
      expect(
        TomScreenElementsProviderBase('default').scope.getScopePath(),
        'default',
      );
    });
  });

  group('root-adopted resource resolution', () {
    testWidgets('a root-adopted widget reads the unscoped resource', (
      tester,
    ) async {
      // End-to-end: the bundle holds 'field.label' at its root and
      // 'checkout.field.label' below. A provider that adopted a *copy* of the
      // root resolves 'default.field.label' and finds neither, so the key
      // echoes back — which is the silent failure, since nothing throws.
      final provider = _AdoptingProvider();

      await tester.pumpWidget(_host(provider.field));
      await tester.pumpAndSettle();

      expect(find.text('unscoped value'), findsOneWidget);
      expect(find.text('default.field.label'), findsNothing);
    });
  });

  group('resource resolution against the inherited scope (G-RES-2/3)', () {
    testWidgets('a provider-scoped widget reads the provider-scoped resource', (
      tester,
    ) async {
      // The end-to-end assertion: zone scope → provider scope → base path →
      // resource key. Every link has to hold for this text to appear.
      final provider = TomScope.withScope('checkout', () => _OrderProvider());

      await tester.pumpWidget(
        _host(Column(children: [provider.submit, provider.details.name])),
      );
      await tester.pumpAndSettle();

      expect(find.text('Submit order'), findsOneWidget);
      expect(find.text('Customer name'), findsOneWidget);
    });

    testWidgets('a key missing under the inherited scope is not silently '
        'resolved from the root', (tester) async {
      // 'field.label' exists at the root of the bundle. A widget scoped to
      // 'checkout.order' must NOT find it — scope resolution is a prefix, not
      // a search path. Without this, a mis-scoped widget would keep working
      // by accident and the scope would stop being load-bearing.
      final provider = TomScope.withScope('checkout', () => _OrderProvider());
      final stray = TomScope.withScope(
        'checkout',
        () => _ProbeNode(tomId: 'field', scope: provider),
      );

      await tester.pumpWidget(_host(stray));
      await tester.pumpAndSettle();

      expect(stray.basePath, 'checkout.order.field');
      expect(find.text('unscoped value'), findsNothing);
      expect(find.text('scoped value'), findsNothing);
      // getText echoes the key when nothing resolves.
      expect(find.text('checkout.order.field.label'), findsOneWidget);
    });
  });
}
