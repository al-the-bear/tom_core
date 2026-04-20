/// Regression tests for [AclBuilder.setAclDefaultHideUnauthorized] and
/// [AclBuilder.setHideUnauthorized]. Verifies:
///
///   * A hidden component is dropped from the row; the **following**
///     component's `gapBefore` is dropped with it, so the next visible
///     component slides into the hidden component's slot.
///   * A row in which every component is hidden is dropped entirely; the
///     following content row's `gapBefore` is dropped with it.
///   * Components without a [TomAuthorizable] child are never touched.
///   * Per-component `setHideUnauthorized(false)` overrides the container
///     default.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/src/advanced_container_layout/acl_builder.dart';

/// A trivial [TomAuthorizable] widget whose auth state is fed by the
/// tests — avoids pulling in the global `TomAuthorization` adapter.
class _AuthBox extends StatelessWidget implements TomAuthorizable {
  @override
  final String? tomId;
  @override
  final TomAuthState effectiveAuthState;
  final Color color;

  const _AuthBox({
    required this.tomId,
    required this.effectiveAuthState,
    this.color = const Color(0xFF000000),
  });

  @override
  TomAuthorizationGroup? get tomGroup => null;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: ValueKey(tomId),
      width: 40,
      height: 40,
      child: ColoredBox(color: color),
    );
  }
}

/// Returns the top-left origin of the `_AuthBox` whose `tomId == id`.
Offset _topLeftOf(WidgetTester tester, String id) {
  final element = tester
      .elementList(find.byWidgetPredicate(
        (w) => w is _AuthBox && w.tomId == id,
      ))
      .single;
  final box = element.renderObject as RenderBox;
  return box.localToGlobal(Offset.zero);
}

bool _hasBox(WidgetTester tester, String id) {
  return tester
      .widgetList<_AuthBox>(find.byType(_AuthBox))
      .any((w) => w.tomId == id);
}

void main() {
  Future<void> pumpAcl(WidgetTester tester, Widget aclWidget) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: aclWidget)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
      'container default: hidden component vanishes, following gap dropped, '
      'next component takes its slot', (tester) async {
    final acl = AclBuilder()
        .setAclDefaultHideUnauthorized(true)
        .append(const _AuthBox(
          tomId: 'a',
          effectiveAuthState: TomAuthState.full,
        ))
        .setPSize(40, 40)
        .append(
          const _AuthBox(
            tomId: 'b',
            effectiveAuthState: TomAuthState.none,
          ),
          dist: 20,
        )
        .setPSize(40, 40)
        .append(
          const _AuthBox(
            tomId: 'c',
            effectiveAuthState: TomAuthState.full,
            color: Color(0xFFFF0000),
          ),
          dist: 20,
        )
        .setPSize(40, 40)
        .build();

    await pumpAcl(tester, acl);

    // b is gone; c should start where b used to start.
    expect(_hasBox(tester, 'b'), isFalse);
    final aLeft = _topLeftOf(tester, 'a');
    final cLeft = _topLeftOf(tester, 'c');
    // b would have sat at aLeft.dx + 40 (a width) + 20 (dist on b).
    // With b + its *following* gap (c's dist=20) dropped, c takes that slot:
    //   cLeft.dx == aLeft.dx + 40 (a width) + 20 (b's dist, preserved)
    expect(cLeft.dx, closeTo(aLeft.dx + 40 + 20, 0.5),
        reason: 'c must occupy the slot b used to hold.');
  });

  testWidgets(
      'per-component setHideUnauthorized(false) opts out of container default',
      (tester) async {
    final acl = AclBuilder()
        .setAclDefaultHideUnauthorized(true)
        .append(const _AuthBox(
          tomId: 'a',
          effectiveAuthState: TomAuthState.full,
        ))
        .append(
          const _AuthBox(
            tomId: 'b',
            effectiveAuthState: TomAuthState.none,
          ),
          dist: 20,
        )
        .setHideUnauthorized(false)
        .append(
          const _AuthBox(
            tomId: 'c',
            effectiveAuthState: TomAuthState.full,
          ),
          dist: 20,
        )
        .build();

    await pumpAcl(tester, acl);
    // b opted out → still in the tree (even though it self-shrinks is irrelevant
    // here; the Widget still exists as the row's child).
    expect(_hasBox(tester, 'b'), isTrue);
  });

  testWidgets('plain (non-TomAuthorizable) children are never touched',
      (tester) async {
    const plainKey = ValueKey('plain');
    final acl = AclBuilder()
        .setAclDefaultHideUnauthorized(true)
        .append(const SizedBox(key: plainKey, width: 40, height: 40))
        .build();
    await pumpAcl(tester, acl);
    expect(find.byKey(plainKey), findsOneWidget);
  });

  testWidgets(
      'whole row elided when every component is hidden; next row gap drops',
      (tester) async {
    final acl = AclBuilder()
        .setAclDefaultHideUnauthorized(true)
        .append(const _AuthBox(
          tomId: 'r0',
          effectiveAuthState: TomAuthState.full,
        ))
        .setPSize(40, 40)
        .newRow(dist: 100)
        .append(const _AuthBox(
          tomId: 'r1-a',
          effectiveAuthState: TomAuthState.none,
        ))
        .setPSize(40, 40)
        .append(
          const _AuthBox(
            tomId: 'r1-b',
            effectiveAuthState: TomAuthState.none,
          ),
          dist: 16,
        )
        .setPSize(40, 40)
        .newRow(dist: 30)
        .append(const _AuthBox(
          tomId: 'r2',
          effectiveAuthState: TomAuthState.full,
        ))
        .setPSize(40, 40)
        .build();

    await pumpAcl(tester, acl);

    expect(_hasBox(tester, 'r1-a'), isFalse);
    expect(_hasBox(tester, 'r1-b'), isFalse);

    // r1 is elided. Its own gapBefore (100) is carried forward onto r2;
    // r2's own gapBefore (30) is the "gap after" the elided row and gets
    // dropped. Net: r2 sits at r0.bottom + 100.
    final r0 = _topLeftOf(tester, 'r0');
    final r2 = _topLeftOf(tester, 'r2');
    expect(r2.dy, closeTo(r0.dy + 40 + 100, 0.5),
        reason:
            'r2 inherits r1\'s gapBefore; r2\'s own gapBefore is dropped.');
  });

  testWidgets(
      'hidden component using default append gap carries the default forward',
      (tester) async {
    // Default append gap = 8 (ACL's built-in default). `a` and `b` both
    // use the default. Hiding `b` must NOT collapse the gap between `a`
    // and the next visible component (`c`) — the default gap travels.
    final acl = AclBuilder()
        .setAclDefaultHideUnauthorized(true)
        .append(const _AuthBox(
          tomId: 'a',
          effectiveAuthState: TomAuthState.full,
        ))
        .setPSize(40, 40)
        .append(const _AuthBox(
          tomId: 'b',
          effectiveAuthState: TomAuthState.none,
        ))
        .setPSize(40, 40)
        .append(const _AuthBox(
          tomId: 'c',
          effectiveAuthState: TomAuthState.full,
        ))
        .setPSize(40, 40)
        .build();

    await pumpAcl(tester, acl);

    expect(_hasBox(tester, 'b'), isFalse);
    final aLeft = _topLeftOf(tester, 'a');
    final cLeft = _topLeftOf(tester, 'c');
    // a ends at aLeft.dx + 40. b's (default=8) gapBefore is carried to c;
    // c's own default gap is dropped. c sits at a.right + 8.
    expect(cLeft.dx, closeTo(aLeft.dx + 40 + 8, 0.5),
        reason:
            'Default-gap carry must preserve the row\'s default append gap.');
  });

  testWidgets('flag off (default): component still renders in place',
      (tester) async {
    final acl = AclBuilder()
        .append(const _AuthBox(
          tomId: 'a',
          effectiveAuthState: TomAuthState.full,
        ))
        .append(
          const _AuthBox(
            tomId: 'b',
            effectiveAuthState: TomAuthState.none,
          ),
          dist: 20,
        )
        .build();
    await pumpAcl(tester, acl);
    // b has auth `none` but flag is off → the widget is kept; the widget
    // itself is responsible for its self-shrink (not under test here).
    expect(
      tester.widgetList<_AuthBox>(find.byType(_AuthBox))
          .any((w) => w.tomId == 'b'),
      isTrue,
    );
  });
}
