/// Measures what the ACL actually does to an element the authorization
/// policy denies — separately for a component and for a row, and separately
/// for each of the two mechanisms that can remove one.
///
/// The container has **two** of them, and they are easy to conflate because
/// both end with something disappearing:
///
///   * `_applyAuthHiding` runs **before layout**, is gated on
///     `hideUnauthorized`, and keys on the *child widget's*
///     [TomAuthorizable.effectiveAuthState]. It rebuilds the row list, so it
///     can move gaps around: the hidden element's own `gapBefore` is carried
///     onto the next survivor and the survivor's own `gapBefore` is dropped.
///     Covered by `acl_hide_unauthorized_test.dart`; reproduced here only as
///     the contrast that makes the other mechanism legible.
///   * The **render-time policy gates** run during `build`, are **not** gated
///     on `hideUnauthorized`, and key on
///     `TomAuthorization.resolveAuth(<policy path>)` — so they need an id, and
///     they fire for any child, [TomAuthorizable] or not. They cannot move a
///     gap, only skip a widget, so the arithmetic comes out the other way
///     round.
///
/// The documentation described one behaviour where there are two, and
/// described it as "an empty box is left in place". No box is left: a denied
/// component is replaced by a zero-size widget whose *width* is reclaimed
/// while **both** surrounding gaps survive, and a denied row loses its own
/// `gapBefore` along with the row. Every number below was read off a rendered
/// frame, and the two mechanisms are asserted against the same fixture so the
/// divergence is a subtraction rather than a claim.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// This file, for the enum-coverage guard at the bottom. Package-relative;
/// `flutter test` runs with the package root as its working directory.
const _thisTest =
    'test/advanced_container_layout/acl_auth_visibility_test.dart';

/// Fixture geometry. Every component is 40 × 40; `a` takes the row's default
/// append gap of 8 and the other two take an explicit 20.
const _size = 40.0;
const _defaultGap = 8.0;
const _compGap = 20.0;

/// Row 1 sits 50 below row 0, row 2 sits 30 below row 1.
const _row1Gap = 50.0;
const _row2Gap = 30.0;

/// A child that carries its own auth state, which is what `_applyAuthHiding`
/// reads. Plain widgets — like the [Text]s used for the policy-gate fixture —
/// are invisible to that mechanism.
class _AuthBox extends StatelessWidget implements TomAuthorizable {
  const _AuthBox({required this.tomId, required this.effectiveAuthState});

  @override
  final String? tomId;
  @override
  final TomAuthState effectiveAuthState;

  @override
  TomAuthorizationGroup? get tomGroup => null;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: _size, height: _size, child: Text(tomId!));
}

/// Grants everything except the paths it is told to deny.
class _Adapter implements TomAuthorizationAdapter {
  final Map<String, TomAuthState> denials = <String, TomAuthState>{};

  @override
  TomAuthState resolveAuth(String path) =>
      denials[path] ?? TomAuthState.full;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Adapter adapter;

  setUp(() {
    adapter = _Adapter();
    TomAuthorization.reset();
    TomAuthorization.adapter = adapter;
  });

  tearDown(TomAuthorization.reset);

  Future<void> pump(WidgetTester tester, Widget layout) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SizedBox(width: 1000, child: layout))),
    );
    await tester.pumpAndSettle();
  }

  Offset originOf(WidgetTester tester, String label) =>
      tester.renderObject<RenderBox>(find.text(label)).localToGlobal(
            Offset.zero,
          );

  /// Three components in row 0 and one each in rows 1 and 2, every one of them
  /// carrying an id — so the render-time policy gates apply and the adapter
  /// decides what survives. The children are plain [Text]s, which
  /// `_applyAuthHiding` cannot see, so `hideUnauthorized` is inert here
  /// whatever it is set to.
  Widget policyLayout({bool hideUnauthorized = false}) => AclBuilder()
      .setAclDefaultHideUnauthorized(hideUnauthorized)
      .setRowId('r0')
      .append(const Text('a'))
      .setId('a')
      .setPSize(_size, _size)
      .append(const Text('b'), dist: _compGap)
      .setId('b')
      .setPSize(_size, _size)
      .append(const Text('c'), dist: _compGap)
      .setId('c')
      .setPSize(_size, _size)
      .newRow(dist: _row1Gap)
      .setRowId('r1')
      .append(const Text('d'))
      .setId('d')
      .setPSize(_size, _size)
      .newRow(dist: _row2Gap)
      .setRowId('r2')
      .append(const Text('e'))
      .setId('e')
      .setPSize(_size, _size)
      .build();

  /// The same geometry built from [TomAuthorizable] children and no ids, so
  /// the *only* mechanism in play is `_applyAuthHiding`. `denied` names the
  /// components whose own auth state is [TomAuthState.none].
  Widget hidingLayout(Set<String> denied) {
    TomAuthState state(String id) =>
        denied.contains(id) ? TomAuthState.none : TomAuthState.full;
    return AclBuilder()
        .setAclDefaultHideUnauthorized(true)
        .append(_AuthBox(tomId: 'a', effectiveAuthState: state('a')))
        .setPSize(_size, _size)
        .append(
          _AuthBox(tomId: 'b', effectiveAuthState: state('b')),
          dist: _compGap,
        )
        .setPSize(_size, _size)
        .append(
          _AuthBox(tomId: 'c', effectiveAuthState: state('c')),
          dist: _compGap,
        )
        .setPSize(_size, _size)
        .newRow(dist: _row1Gap)
        .append(_AuthBox(tomId: 'd', effectiveAuthState: state('d')))
        .setPSize(_size, _size)
        .newRow(dist: _row2Gap)
        .append(_AuthBox(tomId: 'e', effectiveAuthState: state('e')))
        .setPSize(_size, _size)
        .build();
  }

  group('the undenied baseline', () {
    // Every later assertion is a displacement from these, so they are pinned
    // rather than assumed.
    testWidgets('places the fixture where the gaps say it should',
        (tester) async {
      await pump(tester, policyLayout());

      expect(originOf(tester, 'a').dx, closeTo(_defaultGap, 0.5));
      expect(originOf(tester, 'b').dx,
          closeTo(_defaultGap + _size + _compGap, 0.5));
      expect(originOf(tester, 'c').dx,
          closeTo(_defaultGap + 2 * (_size + _compGap), 0.5));

      expect(originOf(tester, 'a').dy, closeTo(0, 0.5));
      expect(originOf(tester, 'd').dy, closeTo(_size + _row1Gap, 0.5));
      expect(originOf(tester, 'e').dy,
          closeTo(2 * _size + _row1Gap + _row2Gap, 0.5));
    });
  });

  group('a denied component: width reclaimed, both gaps kept', () {
    testWidgets('the widget is gone from the tree', (tester) async {
      adapter.denials['b'] = TomAuthState.none;
      await pump(tester, policyLayout());
      expect(find.text('b'), findsNothing);
    });

    testWidgets('the following component moves left by exactly the width',
        (tester) async {
      // The gate replaces the child with a zero-size widget *after* the gap
      // has already been emitted, and the next component emits its own gap as
      // usual. So the two gaps end up adjacent and only the 40 of `b` is
      // reclaimed — not the 60 someone reading "an empty box is left in
      // place" would predict, and not the 60 `_applyAuthHiding` would give.
      await pump(tester, policyLayout());
      final before = originOf(tester, 'c').dx;

      adapter.denials['b'] = TomAuthState.none;
      await pump(tester, policyLayout());
      final after = originOf(tester, 'c').dx;

      expect(before - after, closeTo(_size, 0.5),
          reason: 'only the component\'s own width is reclaimed; its '
              'gapBefore and the next component\'s gapBefore both survive');
    });

    testWidgets('no space is reserved for the denied component',
        (tester) async {
      // The other half of the same measurement: the geometry is *not* stable
      // across a grant change. A layout that must not reflow cannot rely on
      // this gate leaving a placeholder, because it leaves none.
      adapter.denials['b'] = TomAuthState.none;
      await pump(tester, policyLayout());

      expect(originOf(tester, 'c').dx,
          closeTo(_defaultGap + _size + 2 * _compGap, 0.5),
          reason: 'c sits directly after the two collapsed gaps');
    });
  });

  group('a denied row: the row and its own gapBefore both go', () {
    testWidgets('the widget is gone from the tree', (tester) async {
      adapter.denials['r1'] = TomAuthState.none;
      await pump(tester, policyLayout());
      expect(find.text('d'), findsNothing);
    });

    testWidgets('the following row moves up by the row height plus its gap',
        (tester) async {
      // The row gate `continue`s *before* `gapBefore` is emitted, so unlike
      // the component case the gap dies with the element. The next row keeps
      // its own gap — which is again the opposite of `_applyAuthHiding`,
      // where the elided row's gap is the one that survives.
      await pump(tester, policyLayout());
      final before = originOf(tester, 'e').dy;

      adapter.denials['r1'] = TomAuthState.none;
      await pump(tester, policyLayout());
      final after = originOf(tester, 'e').dy;

      expect(before - after, closeTo(_size + _row1Gap, 0.5),
          reason: 'the row\'s height and its own gapBefore are both '
              'reclaimed; the next row keeps its own gapBefore');
    });

    testWidgets('the surviving row keeps its own gapBefore', (tester) async {
      adapter.denials['r1'] = TomAuthState.none;
      await pump(tester, policyLayout());

      expect(originOf(tester, 'e').dy, closeTo(_size + _row2Gap, 0.5));
    });
  });

  group('the policy gates ignore hideUnauthorized', () {
    // The flag names the *other* mechanism. Reading the two as one control is
    // what made "with it / without it" look like the axis that decides
    // whether space is reserved; it decides nothing here.
    for (final flag in [false, true]) {
      testWidgets('a denied component is skipped with the flag $flag',
          (tester) async {
        adapter.denials['b'] = TomAuthState.none;
        await pump(tester, policyLayout(hideUnauthorized: flag));

        expect(find.text('b'), findsNothing);
        expect(originOf(tester, 'c').dx,
            closeTo(_defaultGap + _size + 2 * _compGap, 0.5));
      });

      testWidgets('a denied row is skipped with the flag $flag',
          (tester) async {
        adapter.denials['r1'] = TomAuthState.none;
        await pump(tester, policyLayout(hideUnauthorized: flag));

        expect(find.text('d'), findsNothing);
        expect(originOf(tester, 'e').dy, closeTo(_size + _row2Gap, 0.5));
      });
    }
  });

  group('the same fixture under _applyAuthHiding, for contrast', () {
    // Same geometry, same element removed, different arithmetic — because
    // this mechanism runs before layout and so can hand a gap to the next
    // survivor, which the render-time gate cannot.
    testWidgets('a hidden component also takes the next component\'s gap',
        (tester) async {
      await pump(tester, hidingLayout(const {}));
      final before = originOf(tester, 'c').dx;

      await pump(tester, hidingLayout(const {'b'}));
      final after = originOf(tester, 'c').dx;

      expect(before - after, closeTo(_size + _compGap, 0.5),
          reason: 'b\'s own gap carries onto c and c\'s own gap is dropped, '
              'so 60 is reclaimed where the policy gate reclaims 40');
    });

    testWidgets('an elided row keeps its own gap and drops the next row\'s',
        (tester) async {
      await pump(tester, hidingLayout(const {}));
      final before = originOf(tester, 'e').dy;

      await pump(tester, hidingLayout(const {'d'}));
      final after = originOf(tester, 'e').dy;

      expect(before - after, closeTo(_size + _row2Gap, 0.5),
          reason: 'row 1\'s gap of 50 survives onto e and e\'s own 30 is '
              'dropped, so 70 is reclaimed where the policy gate reclaims 90');
    });
  });

  group('states that are visible leave the geometry untouched', () {
    testWidgets('read renders the component in place', (tester) async {
      // `read` only reaches the readonly style wrapper, which does not
      // participate in sizing.
      adapter.denials['b'] = TomAuthState.read;
      await pump(tester, policyLayout());

      expect(find.text('b'), findsOneWidget);
      expect(originOf(tester, 'c').dx,
          closeTo(_defaultGap + 2 * (_size + _compGap), 0.5));
    });

    testWidgets('disabled renders the component in place too', (tester) async {
      // `disabled` is enforced — dimmed and pointer-blocked, which
      // acl_disabled_enforcement_test.dart measures — but enforcement is a
      // paint-time wrapper, so it must cost the layout nothing. If it did,
      // a grant change would reflow the screen, which is the whole reason
      // this file measures the visible states separately from the hidden
      // ones.
      adapter.denials['b'] = TomAuthState.disabled;
      await pump(tester, policyLayout());

      expect(find.text('b'), findsOneWidget);
      expect(originOf(tester, 'c').dx,
          closeTo(_defaultGap + 2 * (_size + _compGap), 0.5));
    });
  });

  group('every authorization state is accounted for here', () {
    test('each TomAuthState value is exercised by this file', () {
      // A state added to the kernel enum and never measured is a state whose
      // effect on the layout the documentation would be guessing at — which
      // is the condition that produced the "empty box" claim in the first
      // place. Comments are stripped so naming a state in prose does not
      // count as measuring it.
      final source =
          _withoutComments(File(_thisTest).readAsStringSync());
      final unexercised = TomAuthState.values
          .map((s) => s.name)
          .where((name) => !source.contains('TomAuthState.$name'))
          .toList()
        ..sort();

      expect(unexercised, isEmpty,
          reason: 'these TomAuthState values are never used in $_thisTest, so '
              'what the ACL does with them is unmeasured:\n'
              '${unexercised.map((s) => '  $s').join('\n')}');
    });
  });
}

/// Source with comments removed, so a state named in prose does not count as
/// a state this file exercises.
String _withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .split('\n')
    .map((line) {
      final start = line.indexOf('//');
      return start < 0 ? line : line.substring(0, start);
    })
    .join('\n');
