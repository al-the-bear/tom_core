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
///
/// All of that is the `_applyAuthHiding` pass, which keys on the *child
/// widget's* own auth state. It is not the only way an unauthorized element
/// is removed: id'd rows and components are gated again at render time on
/// their resolved policy path, ignoring `hideUnauthorized` entirely and
/// reclaiming different space. `acl_auth_visibility_test.dart` measures the
/// two against a shared fixture.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// A trivial [TomAuthorizable] widget that resolves its own auth state, the
/// way an application's widgets do.
///
/// Feeding the state in through the constructor would be simpler and would
/// exercise a path nothing ships: a real [TomAuthorizable] answers from
/// [TomAuthorization], and the id it answers *about* is the thing an
/// application gets wrong. `TomAuthorization.reset()` makes installing an
/// adapter safe to undo per test, so there is nothing to avoid.
class _AuthBox extends StatelessWidget implements TomAuthorizable {
  @override
  final String? tomId;
  final Color color;

  const _AuthBox({required this.tomId, this.color = const Color(0xFF000000)});

  @override
  TomAuthState get effectiveAuthState => TomAuthorization.resolveAuth(tomId!);

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

/// Grants every path except the ids a test withholds.
///
/// The ids here are the component ids themselves rather than composed policy
/// paths: `_applyAuthHiding` asks the *child widget* what its state is, and
/// takes no part in path composition. `acl_auth_visibility_test.dart` covers
/// the render-time gate, which does compose a path and is the other half of
/// the story.
class _Policy implements TomAuthorizationAdapter {
  final Set<String> _withheld = <String>{};

  void withhold(List<String> ids) => _withheld.addAll(ids);

  @override
  TomAuthState resolveAuth(String path) =>
      _withheld.contains(path) ? TomAuthState.none : TomAuthState.full;
}

/// The adapter in force for the current test, replaced by `setUp`.
// ignore: library_private_types_in_public_api
late _Policy policy;

/// Returns the top-left origin of the `_AuthBox` whose `tomId == id`.
Offset _topLeftOf(WidgetTester tester, String id) {
  final element = tester
      .elementList(
        find.byWidgetPredicate((w) => w is _AuthBox && w.tomId == id),
      )
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
  setUp(() {
    TomAuthorization.reset();
    policy = _Policy();
    TomAuthorization.adapter = policy;
  });

  // The adapter is process-wide, so it is put back whether the test passed or
  // not — a leaked policy would answer for whatever suite ran next.
  tearDown(TomAuthorization.reset);

  test('the adapter is installed, and answers about the ids under test', () {
    // The control. Every case below reads "this component vanished" as
    // evidence about `_applyAuthHiding`, and all of them would read the same
    // way if the adapter were never consulted and every component were simply
    // absent — or if `withhold` did nothing and none ever vanished. This says
    // which of the two the suite is in.
    policy.withhold(const ['b']);
    expect(TomAuthorization.resolveAuth('b'), TomAuthState.none);
    expect(TomAuthorization.resolveAuth('a'), TomAuthState.full);
  });

  Future<void> pumpAcl(WidgetTester tester, Widget aclWidget) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: aclWidget)));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'container default: hidden component vanishes, following gap dropped, '
    'next component takes its slot',
    (tester) async {
      policy.withhold(const ['b']);
      final acl = AclBuilder()
          .setAclDefaultHideUnauthorized(true)
          .append(const _AuthBox(tomId: 'a'))
          .setPSize(40, 40)
          .append(const _AuthBox(tomId: 'b'), dist: 20)
          .setPSize(40, 40)
          .append(
            const _AuthBox(tomId: 'c', color: Color(0xFFFF0000)),
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
      expect(
        cLeft.dx,
        closeTo(aLeft.dx + 40 + 20, 0.5),
        reason: 'c must occupy the slot b used to hold.',
      );
    },
  );

  testWidgets(
    'per-component setHideUnauthorized(false) opts out of container default',
    (tester) async {
      policy.withhold(const ['b']);
      final acl = AclBuilder()
          .setAclDefaultHideUnauthorized(true)
          .append(const _AuthBox(tomId: 'a'))
          .append(const _AuthBox(tomId: 'b'), dist: 20)
          .setHideUnauthorized(false)
          .append(const _AuthBox(tomId: 'c'), dist: 20)
          .build();

      await pumpAcl(tester, acl);
      // b opted out → still in the tree (even though it self-shrinks is irrelevant
      // here; the Widget still exists as the row's child).
      expect(_hasBox(tester, 'b'), isTrue);
    },
  );

  testWidgets('plain (non-TomAuthorizable) children are never touched', (
    tester,
  ) async {
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
      policy.withhold(const ['r1-a', 'r1-b']);
      final acl = AclBuilder()
          .setAclDefaultHideUnauthorized(true)
          .append(const _AuthBox(tomId: 'r0'))
          .setPSize(40, 40)
          .newRow(dist: 100)
          .append(const _AuthBox(tomId: 'r1-a'))
          .setPSize(40, 40)
          .append(const _AuthBox(tomId: 'r1-b'), dist: 16)
          .setPSize(40, 40)
          .newRow(dist: 30)
          .append(const _AuthBox(tomId: 'r2'))
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
      expect(
        r2.dy,
        closeTo(r0.dy + 40 + 100, 0.5),
        reason: 'r2 inherits r1\'s gapBefore; r2\'s own gapBefore is dropped.',
      );
    },
  );

  testWidgets(
    'hidden component using default append gap carries the default forward',
    (tester) async {
      policy.withhold(const ['b']);
      // Default append gap = 8 (ACL's built-in default). `a` and `b` both
      // use the default. Hiding `b` must NOT collapse the gap between `a`
      // and the next visible component (`c`) — the default gap travels.
      final acl = AclBuilder()
          .setAclDefaultHideUnauthorized(true)
          .append(const _AuthBox(tomId: 'a'))
          .setPSize(40, 40)
          .append(const _AuthBox(tomId: 'b'))
          .setPSize(40, 40)
          .append(const _AuthBox(tomId: 'c'))
          .setPSize(40, 40)
          .build();

      await pumpAcl(tester, acl);

      expect(_hasBox(tester, 'b'), isFalse);
      final aLeft = _topLeftOf(tester, 'a');
      final cLeft = _topLeftOf(tester, 'c');
      // a ends at aLeft.dx + 40. b's (default=8) gapBefore is carried to c;
      // c's own default gap is dropped. c sits at a.right + 8.
      expect(
        cLeft.dx,
        closeTo(aLeft.dx + 40 + 8, 0.5),
        reason:
            'Default-gap carry must preserve the row\'s default append gap.',
      );
    },
  );

  testWidgets(
    'non-default component gaps: hidden comp preserves its own explicit '
    'gap, next comp\'s explicit gap is dropped',
    (tester) async {
      policy.withhold(const ['b']);
      // [a, b(hidden), c] with explicit non-default dists of 24 and 12.
      // Rule: b's own dist (24) is the "gap between a and b" — preserved.
      // c's own dist (12) is the "gap between b and c" (= gap after b) —
      // dropped. Net: c sits at a.right + 24.
      final acl = AclBuilder()
          .setAclDefaultHideUnauthorized(true)
          .append(const _AuthBox(tomId: 'a'))
          .setPSize(40, 40)
          .append(const _AuthBox(tomId: 'b'), dist: 24)
          .setPSize(40, 40)
          .append(const _AuthBox(tomId: 'c'), dist: 12)
          .setPSize(40, 40)
          .build();

      await pumpAcl(tester, acl);

      expect(_hasBox(tester, 'b'), isFalse);
      final aLeft = _topLeftOf(tester, 'a');
      final cLeft = _topLeftOf(tester, 'c');
      expect(
        cLeft.dx,
        closeTo(aLeft.dx + 40 + 24, 0.5),
        reason:
            'Non-default explicit gap on the hidden comp must carry '
            'forward verbatim; the next comp\'s explicit gap is dropped.',
      );
    },
  );

  testWidgets(
    'chain of hidden comps: only the first hidden comp\'s gap carries',
    (tester) async {
      policy.withhold(const ['h1', 'h2']);
      // [a, h1(hidden, dist 30), h2(hidden, dist 50), c(dist 10)]
      // Expected: c at a.right + 30. h1's gap is "gap between a and h1" — kept.
      // h2's own gap (50) is "gap after h1" — dropped. c's own gap (10) is
      // "gap after h2" — dropped.
      final acl = AclBuilder()
          .setAclDefaultHideUnauthorized(true)
          .append(const _AuthBox(tomId: 'a'))
          .setPSize(40, 40)
          .append(const _AuthBox(tomId: 'h1'), dist: 30)
          .setPSize(40, 40)
          .append(const _AuthBox(tomId: 'h2'), dist: 50)
          .setPSize(40, 40)
          .append(const _AuthBox(tomId: 'c'), dist: 10)
          .setPSize(40, 40)
          .build();

      await pumpAcl(tester, acl);

      final aLeft = _topLeftOf(tester, 'a');
      final cLeft = _topLeftOf(tester, 'c');
      expect(
        cLeft.dx,
        closeTo(aLeft.dx + 40 + 30, 0.5),
        reason:
            'Only the first hidden component\'s gapBefore should carry; '
            'intermediates and the trailing visible comp\'s gap are gaps '
            '"after a hidden comp" and drop.',
      );
    },
  );

  testWidgets('non-default row gaps: hidden row carries its own dist onto the '
      'next row; next row\'s dist drops', (tester) async {
    policy.withhold(const ['r1-only']);
    // r0 (no dist), r1 (dist 55, all hidden), r2 (dist 17, visible).
    // Rule: r1's own dist (55) is the "gap between r0 and r1" — preserved
    // as r2's row gap. r2's own dist (17) is "gap after r1" — dropped.
    // Net: r2.dy == r0.bottom + 55.
    final acl = AclBuilder()
        .setAclDefaultHideUnauthorized(true)
        .append(const _AuthBox(tomId: 'r0'))
        .setPSize(40, 40)
        .newRow(dist: 55)
        .append(const _AuthBox(tomId: 'r1-only'))
        .setPSize(40, 40)
        .newRow(dist: 17)
        .append(const _AuthBox(tomId: 'r2'))
        .setPSize(40, 40)
        .build();

    await pumpAcl(tester, acl);

    expect(_hasBox(tester, 'r1-only'), isFalse);
    final r0 = _topLeftOf(tester, 'r0');
    final r2 = _topLeftOf(tester, 'r2');
    expect(
      r2.dy,
      closeTo(r0.dy + 40 + 55, 0.5),
      reason:
          'Elided row\'s own gap must carry onto the next row; next '
          'row\'s own gap drops.',
    );
  });

  testWidgets('chain of elided rows: only the first elided row\'s gap carries', (
    tester,
  ) async {
    policy.withhold(const ['r1-only', 'r2-only']);
    // r0 (40), r1 elided (dist 30), r2 elided (dist 80), r3 visible (dist 12).
    // Expected: r3 at r0.bottom + 30 — r1's own dist kept; r2's and r3's
    // are gaps "after an elided row" and drop.
    final acl = AclBuilder()
        .setAclDefaultHideUnauthorized(true)
        .append(const _AuthBox(tomId: 'r0'))
        .setPSize(40, 40)
        .newRow(dist: 30)
        .append(const _AuthBox(tomId: 'r1-only'))
        .setPSize(40, 40)
        .newRow(dist: 80)
        .append(const _AuthBox(tomId: 'r2-only'))
        .setPSize(40, 40)
        .newRow(dist: 12)
        .append(const _AuthBox(tomId: 'r3'))
        .setPSize(40, 40)
        .build();

    await pumpAcl(tester, acl);

    final r0 = _topLeftOf(tester, 'r0');
    final r3 = _topLeftOf(tester, 'r3');
    expect(
      r3.dy,
      closeTo(r0.dy + 40 + 30, 0.5),
      reason:
          'Only the first elided row\'s dist carries; subsequent '
          'elided-row / next-row dists are all dropped.',
    );
  });

  testWidgets('mixed: non-default row gap + non-default component gap both '
      'behave correctly through one hide per side', (tester) async {
    policy.withhold(const ['y0']);
    // Row 0: [x0, y0(hidden, dist 22), z0(dist 14)]  → horizontal hide
    // Row 1: [w1]                                    — kept
    // r1 gapBefore = 40 (explicit)
    //
    // Expected:
    //   z0.dx = x0.dx + 40 + 22   (y0's gap carried; z0's dropped)
    //   w1.dy = x0.dy + 40 + 40    (row 1 kept; its own explicit gap 40)
    final acl = AclBuilder()
        .setAclDefaultHideUnauthorized(true)
        .append(const _AuthBox(tomId: 'x0'))
        .setPSize(40, 40)
        .append(const _AuthBox(tomId: 'y0'), dist: 22)
        .setPSize(40, 40)
        .append(const _AuthBox(tomId: 'z0'), dist: 14)
        .setPSize(40, 40)
        .newRow(dist: 40)
        .append(const _AuthBox(tomId: 'w1'))
        .setPSize(40, 40)
        .build();

    await pumpAcl(tester, acl);

    final x0 = _topLeftOf(tester, 'x0');
    final z0 = _topLeftOf(tester, 'z0');
    final w1 = _topLeftOf(tester, 'w1');
    expect(
      z0.dx,
      closeTo(x0.dx + 40 + 22, 0.5),
      reason: 'y0\'s explicit gap must carry onto z0.',
    );
    expect(
      w1.dy,
      closeTo(x0.dy + 40 + 40, 0.5),
      reason: 'Row 1 kept → its own explicit dist (40) applies verbatim.',
    );
  });

  testWidgets('flag off (default): component still renders in place', (
    tester,
  ) async {
    policy.withhold(const ['b']);
    final acl = AclBuilder()
        .append(const _AuthBox(tomId: 'a'))
        .append(const _AuthBox(tomId: 'b'), dist: 20)
        .build();
    await pumpAcl(tester, acl);
    // b has auth `none` but flag is off → the widget is kept; the widget
    // itself is responsible for its self-shrink (not under test here).
    expect(
      tester
          .widgetList<_AuthBox>(find.byType(_AuthBox))
          .any((w) => w.tomId == 'b'),
      isTrue,
    );
  });
}
