import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// Resource resolution for a TomWidgetMixin widget: its `getText`, and the
// TomCtr statics every widget calls with its `basePath`, each resolving
// `<basePath>.<suffix>`.
//
// What makes this worth pinning is that the family has three different answers
// for the *same* situation — the resource is not there:
//
//   getText              → the key itself, as a development indicator
//   TomCtr typed lookups → null
//   TomCtr.doubleOrFail  → throws StateError
//
// Only the second and third are announced by the method name. `getText` looks
// like the safest of the three and is the one that silently puts a resource
// path on screen, and `doubleOrFail` is the only lookup that can bring a
// widget build down. Both need to be visible in the contract, so both are
// asserted here rather than left to the naming convention.

/// Minimal Tom widget: its `basePath` needs only `tomId`/`scope`.
class _ResourceWidget extends StatelessWidget with TomWidgetMixin {
  const _ResourceWidget({this.tomId, this.scope});

  @override
  final String? tomId;
  @override
  final TomScope? scope;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void _installResources(Map<String, dynamic> tree) {
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(tree),
  );
}

void main() {
  setUpAll(() => TomUIColors.adapter = TomAllColorsAdapter());
  tearDown(() => _installResources({}));

  group('TomWidgetMixin typed resources: values that are present', () {
    test('every lookup resolves its own type from the widget path', () {
      _installResources({
        'w': {
          'label': 'Street',
          'tint': '#FF5733',
          'size': 14.5,
          'count': 7,
          'dense': true,
          'pad': 8,
        },
      });
      const widget = _ResourceWidget(tomId: 'w');

      expect(widget.getText('label'), 'Street');
      expect(TomCtr.color(widget.basePath, 'tint'), const Color(0xFFFF5733));
      expect(TomCtr.doubleVal(widget.basePath, 'size'), 14.5);
      expect(TomCtr.doubleOrFail(widget.basePath, 'size'), 14.5);
      expect(TomCtr.intVal(widget.basePath, 'count'), 7);
      expect(TomCtr.boolVal(widget.basePath, 'dense'), isTrue);
      expect(
        TomCtr.edgeInsets(widget.basePath, 'pad'),
        const EdgeInsets.all(8),
      );
    });

    test('resolution is scope-aware, like basePath', () {
      _installResources({
        'checkout': {
          'w': {'size': 20.0},
        },
        'w': {'size': 4.0},
      });
      final scoped = _ResourceWidget(
        tomId: 'w',
        scope: TomScopeBase(scopeId: 'checkout'),
      );

      expect(scoped.basePath, 'checkout.w');
      expect(TomCtr.doubleVal(scoped.basePath, 'size'), 20.0);
      expect(TomCtr.doubleOrFail(scoped.basePath, 'size'), 20.0);
      // The unscoped widget reads the other value entirely.
      expect(
        TomCtr.doubleVal(const _ResourceWidget(tomId: 'w').basePath, 'size'),
        4.0,
      );
    });
  });

  group('TomWidgetMixin typed resources: the three answers to a miss', () {
    test('getText echoes the key back as a development indicator', () {
      _installResources({});
      // Not null, not an empty string, and not a throw: the resolved path
      // itself, so an unresourced label is visible on screen rather than
      // silently blank.
      expect(const _ResourceWidget(tomId: 'w').getText('label'), 'w.label');
    });

    test('getText yields the empty string when there is no tomId', () {
      // basePath is null, so there is no key to echo.
      expect(const _ResourceWidget().getText('label'), '');
    });

    test('every nullable lookup returns null for an absent resource', () {
      _installResources({});
      const widget = _ResourceWidget(tomId: 'w');

      expect(TomCtr.color(widget.basePath, 'tint'), isNull);
      expect(TomCtr.doubleVal(widget.basePath, 'size'), isNull);
      expect(TomCtr.intVal(widget.basePath, 'count'), isNull);
      expect(TomCtr.boolVal(widget.basePath, 'dense'), isNull);
      expect(TomCtr.edgeInsets(widget.basePath, 'pad'), isNull);
    });

    test('every nullable lookup returns null for an unparseable value', () {
      _installResources({
        'w': {
          'tint': 'not-a-colour',
          'size': 'not-a-number',
          'count': 'not-a-number',
          'dense': 'not-a-bool',
          'pad': 'not-an-inset',
        },
      });
      const widget = _ResourceWidget(tomId: 'w');

      expect(TomCtr.color(widget.basePath, 'tint'), isNull);
      expect(TomCtr.doubleVal(widget.basePath, 'size'), isNull);
      expect(TomCtr.intVal(widget.basePath, 'count'), isNull);
      expect(TomCtr.boolVal(widget.basePath, 'dense'), isNull);
      expect(TomCtr.edgeInsets(widget.basePath, 'pad'), isNull);
    });

    test('every nullable lookup returns null when there is no tomId', () {
      const widget = _ResourceWidget();

      expect(TomCtr.color(widget.basePath, 'tint'), isNull);
      expect(TomCtr.doubleVal(widget.basePath, 'size'), isNull);
      expect(TomCtr.intVal(widget.basePath, 'count'), isNull);
      expect(TomCtr.boolVal(widget.basePath, 'dense'), isNull);
      expect(TomCtr.edgeInsets(widget.basePath, 'pad'), isNull);
    });

    test('doubleOrFail throws, naming the key it wanted', () {
      _installResources({});
      expect(
        () => TomCtr.doubleOrFail(
          const _ResourceWidget(tomId: 'w').basePath,
          'size',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('numeric resource value at w.size'),
          ),
        ),
      );
    });

    test('doubleOrFail throws on a present but non-numeric value', () {
      // The resource exists, so this is a distinct failure from absence: the
      // nullable doubleVal answers null here, and doubleOrFail still refuses.
      _installResources({
        'w': {'size': 'not-a-number'},
      });
      expect(
        TomCtr.doubleVal(const _ResourceWidget(tomId: 'w').basePath, 'size'),
        isNull,
      );
      expect(
        () => TomCtr.doubleOrFail(
          const _ResourceWidget(tomId: 'w').basePath,
          'size',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('must be numeric'),
          ),
        ),
      );
    });

    test('doubleOrFail throws when there is no tomId', () {
      // No basePath means no key to look up at all, so the message asks for a
      // tomId rather than for a value.
      expect(
        () => TomCtr.doubleOrFail(const _ResourceWidget().basePath, 'size'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('an explicit size or a tomId'),
          ),
        ),
      );
    });
  });
}
