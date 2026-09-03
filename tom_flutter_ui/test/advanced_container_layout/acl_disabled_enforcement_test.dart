/// What the ACL does to a component, a row and a whole container that
/// authorization resolves to [TomAuthState.disabled] — and to a component whose
/// *group* is switched to [AclGroupVisibilityMode.disabled].
///
/// The two are different axes and stay different: one is a grant, the other is
/// a runtime toggle the application drives. What they are not is two different
/// *looks*. A user cannot tell — and must not be able to tell — from the pixels
/// whether a control is inert because a policy withheld it or because its group
/// was collapsed; "visible but not usable" is one appearance, and this file
/// requires all four sites to render it identically, by resolving it from the
/// ambient [TomTheme] rather than by spelling it out.
///
/// Enforcement is asserted by dispatching a real tap and requiring it not to
/// arrive — not by finding an [AbsorbPointer] above the component, because the
/// ambient `MaterialApp` already puts one there and such a finder passes
/// whether or not the container added its own. Dimming is asserted as "some
/// opacity below 1" rather than against a literal, because the number belongs
/// to the theme and an app is expected to change it. The one place a literal
/// *is* asserted is the custom-theme group, which is how "resolved from the
/// theme" is told apart from "hard-coded to the value the theme happens to
/// hold".
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

const _size = 40.0;

/// Records taps that reach it. The component under test is tappable because
/// "not usable" is a claim about what a tap does, and a structural check for
/// an [AbsorbPointer] cannot make it: the ambient `MaterialApp` already puts
/// one above everything, so a finder for the type passes whether or not the
/// container added its own.
class _Taps {
  int count = 0;

  Widget get target => GestureDetector(
    onTap: () => count++,
    behavior: HitTestBehavior.opaque,
    child: const SizedBox(width: _size, height: _size, child: Text('body')),
  );
}

/// Grants everything except the paths it is told to withhold.
class _Adapter implements TomAuthorizationAdapter {
  final Map<String, TomAuthState> denials = <String, TomAuthState>{};

  @override
  TomAuthState resolveAuth(String path) => denials[path] ?? TomAuthState.full;
}

/// The minimum a [TomAclBuilder] needs: a scope, and widgets to select from.
class _Elements extends TomScreenElementsProviderBase {
  _Elements(this.taps) : super('screen');

  final _Taps taps;

  Widget get box => taps.target;
}

/// A theme whose two withheld states are visibly distinct from each other and
/// from every framework default, so a site that ignores the theme fails rather
/// than passing on a coincidence.
const _distinctTheme = TomTheme(
  readonlyStyle: TomStateStyle(opacity: 0.71),
  disabledStyle: TomStateStyle(opacity: 0.23),
);

void main() {
  late _Adapter adapter;
  late _Taps taps;

  setUp(() {
    adapter = _Adapter();
    taps = _Taps();
    TomAuthorization.reset();
    TomAuthorization.adapter = adapter;
  });

  tearDown(TomAuthorization.reset);

  Future<void> pump(
    WidgetTester tester,
    Widget layout, {
    TomTheme? theme,
  }) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final body = SizedBox(width: 1000, child: layout);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: theme == null ? body : TomThemeScope(theme: theme, child: body),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The opacities applied above [content], nearest ancestor first.
  List<double> dimmingOf(WidgetTester tester, Finder content) => tester
      .widgetList<Opacity>(
        find.ancestor(of: content, matching: find.byType(Opacity)),
      )
      .map((o) => o.opacity)
      .where((o) => o < 1.0)
      .toList();

  /// Fails unless the component is rendered, dimmed, and does not respond to
  /// a tap — the three halves of "visible but not usable".
  Future<void> expectWithheld(WidgetTester tester, {String? reason}) async {
    expect(find.text('body'), findsOneWidget);
    expect(
      dimmingOf(tester, find.text('body')),
      isNotEmpty,
      reason: reason ?? 'withheld content must be dimmed',
    );
    await tester.tap(find.text('body'), warnIfMissed: false);
    await tester.pump();
    expect(
      taps.count,
      0,
      reason: reason ?? 'withheld content must not receive pointer events',
    );
  }

  /// One identified component in one identified row.
  Widget layout() => AclBuilder()
      .setRowId('r0')
      .append(taps.target)
      .setId('c0')
      .setPSize(_size, _size)
      .build();

  /// The same component, in a named group whose mode [controller] drives.
  Widget groupedLayout(AclGroupVisibilityController controller) => AclBuilder()
      .setGroupVisibilityController('g', controller)
      .append(taps.target)
      .group('g')
      .setPSize(_size, _size)
      .build();

  group('a disabled grant is enforced by the container', () {
    testWidgets('on a component', (tester) async {
      // `disabled.isVisible` is true, so a gate written as "hide if invisible,
      // else dim if read, else pass through" renders a withheld component
      // fully interactive. That is not a milder enforcement of the grant; it
      // is no enforcement of it.
      adapter.denials['c0'] = TomAuthState.disabled;
      await pump(tester, layout());

      await expectWithheld(
        tester,
        reason:
            'a component the policy resolved to disabled must be '
            'rendered inert, not merely rendered',
      );
    });

    testWidgets('but a full component stays live', (tester) async {
      // The other direction, without which every assertion above passes for a
      // container that simply dims and deadens everything.
      await pump(tester, layout());

      expect(dimmingOf(tester, find.text('body')), isEmpty);
      await tester.tap(find.text('body'));
      await tester.pump();
      expect(taps.count, 1);
    });

    testWidgets('on a row, reaching every component in it', (tester) async {
      // A row grant is the component grant's superior: the row is where a
      // policy says "this whole line is withheld", and a component inside it
      // that resolves `full` on its own must not escape.
      adapter.denials['r0'] = TomAuthState.disabled;
      await pump(tester, layout());

      await expectWithheld(tester);
    });

    testWidgets('by the more restrictive of the row and the component', (
      tester,
    ) async {
      // Both levels resolve, and neither may widen the other. `read` on the
      // row with `disabled` on the component must render as `disabled` — the
      // narrower of the two — and the theme's two states are far enough apart
      // here to tell which one was applied.
      adapter.denials['r0'] = TomAuthState.read;
      adapter.denials['c0'] = TomAuthState.disabled;
      await pump(tester, layout(), theme: _distinctTheme);

      expect(
        dimmingOf(tester, find.text('body')),
        [0.23],
        reason:
            'the narrower grant wins, and it is applied once — a row '
            'and a component that both withhold must not stack their '
            'treatments into a doubly-dimmed component',
      );
    });

    testWidgets('leaving the geometry exactly where full leaves it', (
      tester,
    ) async {
      // The treatment is a paint-time wrapper. If enforcing it moved anything,
      // a grant change would reflow the screen — which is the failure mode
      // `read` was already careful to avoid.
      await pump(tester, layout());
      final full = tester
          .renderObject<RenderBox>(find.text('body'))
          .localToGlobal(Offset.zero);

      adapter.denials['c0'] = TomAuthState.disabled;
      await pump(tester, layout());
      final withheld = tester
          .renderObject<RenderBox>(find.text('body'))
          .localToGlobal(Offset.zero);

      expect(withheld, full);
    });
  });

  group('a disabled grant is enforced by TomAclBuilder', () {
    // The Tom wrapper resolves the container's *own* path and so decides for
    // the container as a whole. It handled `none` and `read` and let
    // `disabled` through untouched, which is the same defect one level up.
    Widget tomContainer() => Builder(
      builder: (context) => TomAclBuilder(
        id: 'panel',
        elementProvider: _Elements(taps),
      ).append((p) => p.box).build(context),
    );

    testWidgets('a disabled container is dimmed and untouchable', (
      tester,
    ) async {
      adapter.denials['panel'] = TomAuthState.disabled;
      await pump(tester, tomContainer());

      await expectWithheld(tester);
    });

    testWidgets('a disabled container takes its dimming from the theme', (
      tester,
    ) async {
      adapter.denials['panel'] = TomAuthState.disabled;
      await pump(tester, tomContainer(), theme: _distinctTheme);

      expect(dimmingOf(tester, find.text('body')), [0.23]);
    });

    testWidgets('a full container gets no treatment at all', (tester) async {
      // The guard for the other direction: a wrapper that dimmed everything
      // would pass the test above for the wrong reason.
      await pump(tester, tomContainer());

      expect(dimmingOf(tester, find.text('body')), isEmpty);
    });

    testWidgets('a none container renders nothing', (tester) async {
      adapter.denials['panel'] = TomAuthState.none;
      await pump(tester, tomContainer());

      expect(find.text('body'), findsNothing);
    });
  });

  group('the group-visibility axis renders the same appearance', () {
    // A different axis — the application toggles it, no policy is consulted —
    // but the same appearance. It used to have a look of its own: opacity 0.4
    // where the grant used 0.38, and `IgnorePointer`, which lets the pointer
    // fall through to whatever is behind rather than swallowing it. Neither
    // difference was a decision anyone could defend, and the first of them was
    // visible on screen whenever both appeared in one container.
    testWidgets('a disabled group is dimmed and untouchable', (tester) async {
      await pump(
        tester,
        groupedLayout(
          AclBinaryVisibilityController(
            initialMode: AclGroupVisibilityMode.disabled,
          ),
        ),
      );

      await expectWithheld(tester);
    });

    testWidgets('a disabled group absorbs pointers rather than ignoring them', (
      tester,
    ) async {
      // `IgnorePointer` makes the component transparent to hit tests, so the
      // tap lands on whatever is underneath. In a Stack that is a live sibling;
      // "not usable" has to mean the event stops here.
      await pump(
        tester,
        groupedLayout(
          AclBinaryVisibilityController(
            initialMode: AclGroupVisibilityMode.disabled,
          ),
        ),
      );

      expect(
        find.byWidgetPredicate((w) => w is IgnorePointer && w.ignoring),
        findsNothing,
      );
    });

    testWidgets('a disabled group takes its dimming from the theme', (
      tester,
    ) async {
      // The point of routing it through the theme: an app that restyles the
      // withheld state restyles both axes at once, and cannot end up with two
      // shades of "off" in the same container.
      await pump(
        tester,
        groupedLayout(
          AclBinaryVisibilityController(
            initialMode: AclGroupVisibilityMode.disabled,
          ),
        ),
        theme: _distinctTheme,
      );

      expect(dimmingOf(tester, find.text('body')), [0.23]);
    });

    testWidgets('a visible group gets no treatment at all', (tester) async {
      await pump(
        tester,
        groupedLayout(
          AclBinaryVisibilityController(
            initialMode: AclGroupVisibilityMode.visible,
          ),
        ),
      );

      expect(dimmingOf(tester, find.text('body')), isEmpty);
    });
  });

  group('the withheld states are resolved, not hard-coded', () {
    testWidgets('a component grant uses the theme disabledStyle', (
      tester,
    ) async {
      adapter.denials['c0'] = TomAuthState.disabled;
      await pump(tester, layout(), theme: _distinctTheme);

      expect(dimmingOf(tester, find.text('body')), [0.23]);
    });

    testWidgets('a component grant uses the theme readonlyStyle for read', (
      tester,
    ) async {
      // The state that already worked, re-measured against the same theme —
      // so "disabled now resolves from the theme" is a statement about which
      // field, not merely about the fact that some field was consulted.
      adapter.denials['c0'] = TomAuthState.read;
      await pump(tester, layout(), theme: _distinctTheme);

      expect(dimmingOf(tester, find.text('body')), [0.71]);
    });

    testWidgets('a theme with dimming switched off still blocks pointers', (
      tester,
    ) async {
      // `opacity: 1.0` is the documented way to turn dimming off. Enforcement
      // is not a styling choice, so it must survive that.
      adapter.denials['c0'] = TomAuthState.disabled;
      await pump(
        tester,
        layout(),
        theme: const TomTheme(disabledStyle: TomStateStyle(opacity: 1.0)),
      );

      expect(dimmingOf(tester, find.text('body')), isEmpty);
      await tester.tap(find.text('body'), warnIfMissed: false);
      await tester.pump();
      expect(
        taps.count,
        0,
        reason:
            'a theme may drop the dimming; it may not drop the '
            'enforcement the dimming advertises',
      );
    });
  });
}
