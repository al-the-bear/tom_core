/// What [AclScope] actually publishes to the widgets inside a container.
///
/// The container wraps every component in an `AclScope` carrying five values —
/// the container id, the component id, the row id, the group, and the composed
/// `fullIdPath`. Reading one's own composed id is what an authorization-aware
/// component needs in order to ask about itself, and it is the only mechanism
/// the unit offers for it.
///
/// Every value is asserted from inside the tree, by a leaf that calls
/// `AclScope.of(context)` — the way a real consumer reaches it — rather than by
/// finding the widget and inspecting its fields. A finder would pass for a
/// scope published *above* the component it is supposed to describe, which is
/// the one arrangement that would make the whole mechanism useless.
///
/// `fullIdPath` is checked against the path the container itself resolves
/// authorization on, captured from the adapter in the same pump. Comparing the
/// two rather than asserting a literal is what makes this a statement about
/// agreement: a component that reads its own id and then asks the policy about
/// it must be asking about itself.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Grants everything and records every path the container asks about.
class _RecordingAdapter implements TomAuthorizationAdapter {
  final Set<String> paths = <String>{};

  @override
  TomAuthState resolveAuth(String path) {
    paths.add(path);
    return TomAuthState.full;
  }
}

/// A leaf that captures the scope its own `BuildContext` sees.
class _ScopeProbe extends StatelessWidget {
  const _ScopeProbe(this.seen);

  /// Written on build. A field rather than a return value because the point is
  /// what a widget *inside* the container observes.
  final List<AclScope?> seen;

  @override
  Widget build(BuildContext context) {
    seen.add(AclScope.of(context));
    return const SizedBox(width: 40, height: 20);
  }
}

void main() {
  late _RecordingAdapter adapter;
  late List<AclScope?> seen;

  setUp(() {
    adapter = _RecordingAdapter();
    seen = <AclScope?>[];
    TomAuthorization.reset();
    TomAuthorization.adapter = adapter;
  });

  tearDown(TomAuthorization.reset);

  Future<void> pump(WidgetTester tester, Widget layout) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SizedBox(width: 1000, child: layout)),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('a component reads the scope describing itself', () {
    testWidgets('every published value names this component, not its row', (
      tester,
    ) async {
      await pump(
        tester,
        AclBuilder()
            .setAclId('order')
            .setAclIdScope(true)
            .setRowId('actions')
            .setRowIdScope(true)
            .append(_ScopeProbe(seen))
            .setRowGroup('admin')
            .setId('save')
            .build(),
      );

      expect(seen, hasLength(greaterThanOrEqualTo(1)));
      final scope = seen.last;
      expect(
        scope,
        isNotNull,
        reason: 'a component inside a container must find an AclScope',
      );
      expect(scope!.containerId, 'order');
      expect(scope.componentId, 'save');
      expect(scope.rowId, 'actions');
      expect(
        scope.groupName,
        'admin',
        reason:
            'the builder sets a group on the row; a component without one of '
            'its own inherits it — `comp.group ?? row.group`',
      );
    });

    testWidgets('fullIdPath is the path the container asks the policy about', (
      tester,
    ) async {
      // The claim worth making: a component that reads its own id and asks the
      // policy about it is asking about *itself*. Asserting a literal would
      // pin today's composition rule twice — once here and once in the
      // id-scope tests — and would still pass if the two drifted apart.
      await pump(
        tester,
        AclBuilder()
            .setAclId('order')
            .setAclIdScope(true)
            .setRowId('actions')
            .setRowIdScope(true)
            .append(_ScopeProbe(seen))
            .setRowGroup('admin')
            .setId('save')
            .build(),
      );

      final path = seen.last!.fullIdPath;
      expect(path, isNotNull);
      expect(
        adapter.paths,
        contains(path),
        reason:
            'the container resolved authorization on these paths '
            '${adapter.paths.toList()..sort()}; the id it published to the '
            'component is not among them, so a component asking about its own '
            'id would be asking about something else',
      );
      // Named once, so a reader can see what the agreement is *about*.
      expect(path, 'order.admin.actions.save');
    });

    testWidgets(
      'the path the documented example promises is the one composed',
      (tester) async {
        // `doc/advanced_container_layout.md` and the completion document both
        // teach `AclScope.of(context)?.fullIdPath` on exactly this layout and
        // promise `order.actions.delete`. Until something ran it, that was a
        // claim about a value no code had ever read.
        await pump(
          tester,
          AclBuilder()
              .setAclId('order')
              .setAclIdScope(true)
              .setRowId('actions')
              .setRowIdScope(true)
              .append(const SizedBox(width: 40, height: 20))
              .setId('save')
              .append(_ScopeProbe(seen), dist: 8)
              .setId('delete')
              .build(),
        );

        expect(seen.last!.fullIdPath, 'order.actions.delete');
        expect(adapter.paths, contains('order.actions.delete'));
      },
    );

    testWidgets('a nested container publishes its own id, not the outer one', (
      tester,
    ) async {
      // Nesting is where an inherited widget earns its keep: the inner scope
      // must shadow the outer, or every component in the tree would read the
      // outermost container's identity.
      await pump(
        tester,
        AclBuilder()
            .setAclId('outer')
            .setAclIdScope(true)
            .setRowId('outerRow')
            .append(
              AclBuilder()
                  .setAclId('inner')
                  .setAclIdScope(true)
                  .setRowId('innerRow')
                  .append(_ScopeProbe(seen))
                  .setId('leaf')
                  .build(),
            )
            .setId('nested')
            .build(),
      );

      final scope = seen.last!;
      expect(scope.containerId, 'inner', reason: 'the nearer scope wins');
      expect(scope.componentId, 'leaf');
      expect(scope.rowId, 'innerRow');
      expect(scope.groupName, isNull);
    });

    testWidgets('an ungrouped component in an unscoped container', (
      tester,
    ) async {
      // The defaults, so the assertions above are known to be reading values
      // that vary rather than constants the container always publishes.
      await pump(
        tester,
        AclBuilder()
            .setAclId('order')
            .setRowId('actions')
            .append(_ScopeProbe(seen))
            .setId('save')
            .build(),
      );

      final scope = seen.last!;
      expect(scope.containerId, 'order', reason: 'containerId is the raw id');
      expect(scope.groupName, isNull);
      expect(
        scope.fullIdPath,
        'save',
        reason:
            'idScope is false on both, so neither id is a descendant segment',
      );
      expect(adapter.paths, contains(scope.fullIdPath));
    });

    testWidgets('a component with no id publishes a null path', (tester) async {
      // `fullIdPath` is composed from the component id, so a component without
      // one has no path — and the container asks the policy nothing about it.
      await pump(
        tester,
        AclBuilder()
            .setAclId('order')
            .setRowId('actions')
            .append(_ScopeProbe(seen))
            .build(),
      );

      final scope = seen.last!;
      expect(scope.componentId, isNull);
      expect(scope.fullIdPath, isNull);
      expect(scope.containerId, 'order');
    });
  });
}
