/// Tests for `idScope` — the flag that decides whether a container's or a
/// row's id becomes a segment of its **descendants'** policy paths.
///
/// The flag was settable and documented long before anything read it, so
/// these tests pin the composed path with the flag set each way. Without
/// them the two path builders can silently drift back to appending
/// unconditionally, which is exactly the state they were found in.
///
/// The contract, per [AclContainer.idScope] / [AclRow.idScope]:
///
///   * `true` — identity container/row: the id appears in descendant paths.
///   * `false` — layout container/row (the default): the id is used for the
///     container's or row's *own* resources only.
///
/// A row's own policy path always ends in the row id — that *is* the row's
/// own resource — but the container id above it is a descendant segment and
/// so honours the container's flag.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Records every path the container asks about and grants everything, so the
/// layout renders in full and each path is observed exactly as composed.
class _RecordingAdapter implements TomAuthorizationAdapter {
  final Set<String> paths = <String>{};

  @override
  TomAuthState resolveAuth(String path) {
    paths.add(path);
    return TomAuthState.full;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _RecordingAdapter adapter;

  setUp(() {
    adapter = _RecordingAdapter();
    TomAuthorization.reset();
    TomAuthorization.adapter = adapter;
  });

  tearDown(TomAuthorization.reset);

  Future<Set<String>> pathsOf(
    WidgetTester tester,
    Widget layout, {
    double width = 1000,
  }) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    adapter.paths.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: width, child: layout),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return adapter.paths;
  }

  Widget buildOrder({required bool aclIdScope, required bool rowIdScope}) {
    return AclBuilder()
        .setAclId('order')
        .setAclIdScope(aclIdScope)
        .setRowId('actions')
        .setRowIdScope(rowIdScope)
        .append(const Text('save'))
        .setId('save')
        .build();
  }

  group('container idScope', () {
    testWidgets(
      'false (default) keeps the container id out of descendant paths',
      (tester) async {
        final paths = await pathsOf(
          tester,
          buildOrder(aclIdScope: false, rowIdScope: false),
        );
        expect(paths, contains('save'));
        expect(paths, isNot(contains('order.save')));
      },
    );

    testWidgets('true puts the container id into descendant paths', (
      tester,
    ) async {
      final paths = await pathsOf(
        tester,
        buildOrder(aclIdScope: true, rowIdScope: false),
      );
      expect(paths, contains('order.save'));
      expect(paths, isNot(contains('save')));
    });

    testWidgets('the flag also gates the container id on a row path', (
      tester,
    ) async {
      final off = await pathsOf(
        tester,
        buildOrder(aclIdScope: false, rowIdScope: false),
      );
      expect(off, contains('actions'));

      final on = await pathsOf(
        tester,
        buildOrder(aclIdScope: true, rowIdScope: false),
      );
      expect(on, contains('order.actions'));
    });
  });

  group('row idScope', () {
    testWidgets('false (default) keeps the row id out of component paths', (
      tester,
    ) async {
      final paths = await pathsOf(
        tester,
        buildOrder(aclIdScope: true, rowIdScope: false),
      );
      expect(paths, contains('order.save'));
      expect(paths, isNot(contains('order.actions.save')));
    });

    testWidgets('true puts the row id into component paths', (tester) async {
      final paths = await pathsOf(
        tester,
        buildOrder(aclIdScope: true, rowIdScope: true),
      );
      expect(paths, contains('order.actions.save'));
      expect(paths, isNot(contains('order.save')));
    });

    testWidgets(
      "a layout row is still addressable by its own id — that is what "
      "'own resources only' means",
      (tester) async {
        final paths = await pathsOf(
          tester,
          buildOrder(aclIdScope: true, rowIdScope: false),
        );
        expect(paths, contains('order.actions'));
      },
    );
  });

  group('both flags together', () {
    testWidgets('compose the full documented path', (tester) async {
      final paths = await pathsOf(
        tester,
        buildOrder(aclIdScope: true, rowIdScope: true),
      );
      expect(
        paths,
        containsAll(<String>['order.actions', 'order.actions.save']),
      );
    });

    testWidgets('each flag is independently load-bearing', (tester) async {
      expect(
        await pathsOf(tester, buildOrder(aclIdScope: true, rowIdScope: true)),
        contains('order.actions.save'),
      );
      expect(
        await pathsOf(tester, buildOrder(aclIdScope: false, rowIdScope: true)),
        contains('actions.save'),
      );
      expect(
        await pathsOf(tester, buildOrder(aclIdScope: true, rowIdScope: false)),
        contains('order.save'),
      );
      expect(
        await pathsOf(tester, buildOrder(aclIdScope: false, rowIdScope: false)),
        contains('save'),
      );
    });
  });

  group('responsive rebuilds preserve the path', () {
    // A row breakpoint splits one logical row into several visual rows. The
    // rebuild used to name fields explicitly and omit `idScope`, and to drop
    // the row id on every fragment after the first — both of which would move
    // a component's policy path as the window narrows. An authorization path
    // that depends on the viewport is not an authorization path.
    Widget buildSplittableOrder() {
      return AclBuilder()
          .setAclId('order')
          .setAclIdScope(true)
          .setRowId('actions')
          .setRowIdScope(true)
          .append(const Text('save'))
          .setId('save')
          .setPSize(300)
          .addRowBreakpoint(atWidth: 600)
          .append(const Text('cancel'))
          .setId('cancel')
          .setPSize(300)
          .build();
    }

    testWidgets('a breakpoint split does not move component paths', (
      tester,
    ) async {
      final wide = await pathsOf(tester, buildSplittableOrder(), width: 1000);
      final narrow = await pathsOf(tester, buildSplittableOrder(), width: 400);

      const expected = <String>{'order.actions.save', 'order.actions.cancel'};
      expect(wide, containsAll(expected));
      expect(
        narrow,
        containsAll(expected),
        reason: 'the split fragment must keep the row id and its idScope',
      );
    });

    testWidgets('a breakpoint split does not move the row path', (
      tester,
    ) async {
      expect(
        await pathsOf(tester, buildSplittableOrder(), width: 1000),
        contains('order.actions'),
      );
      expect(
        await pathsOf(tester, buildSplittableOrder(), width: 400),
        contains('order.actions'),
      );
    });
  });

  group('generated flow rows', () {
    testWidgets('a generated row is addressable as <aclId>.r<n> and does not '
        'double the container id', (tester) async {
      final paths = await pathsOf(
        tester,
        const AclFlowContainer(
          kind: AclFlowKind.wrap,
          aclId: 'tags',
          idScope: true,
          components: [
            AclComponent(child: Text('a'), id: 'one'),
            AclComponent(child: Text('b'), id: 'two'),
          ],
        ),
      );
      // The generated row id already reads `tags.r0`; the container must
      // not prepend `tags` a second time.
      expect(paths, contains('tags.r0'));
      expect(paths, isNot(contains('tags.tags.r0')));
    });

    testWidgets(
      'generated rows are layout rows, so they add no segment to their '
      'components',
      (tester) async {
        final paths = await pathsOf(
          tester,
          const AclFlowContainer(
            kind: AclFlowKind.wrap,
            aclId: 'tags',
            idScope: true,
            components: [AclComponent(child: Text('a'), id: 'one')],
          ),
        );
        expect(paths, contains('tags.one'));
        expect(paths, isNot(contains('tags.tags.r0.one')));
      },
    );
  });
}
