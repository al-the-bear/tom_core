/// `TomFieldWidgetAdapter` sits between a field's model state and the widget
/// the user sees, and every field in the module routes its `widget` getter
/// through it. It does two unrelated jobs, and both fail silently.
///
///   * **It makes the rendered widget answerable to authorization.** A
///     `TomField` implements `TomAuthorizable`, but the `TextField` /
///     `ValueListenableBuilder` it renders does not — and the ACL's
///     hide-unauthorized pass interrogates the *child widget*, never the
///     field. Without the adapter a denied field renders normally, which is
///     the worst possible failure for an authorization mechanism: it looks
///     like it worked.
///
///   * **It ties `State` to the field instance rather than to the slot.**
///     Flutter reconciles by position, so swapping the field at a fixed tree
///     position — a master/detail row change — hands the old `State` to the
///     new field. The `KeyedSubtree` keyed on the field prevents that. The
///     converse matters just as much: a re-layout that keeps the *same* field
///     must keep its `State`, or focus, selection and in-flight text are
///     thrown away on every breakpoint crossing.
///
/// So the assertions below pin the adaptation contract — state in, widget out
/// — rather than any one field's rendering. Only the last group uses a real
/// field, and only to close the loop the first group opens: the ACL suite in
/// `test/advanced_container_layout/acl_auth_visibility_test.dart` proves the
/// hiding pass works against a hand-rolled `TomAuthorizable` child, which
/// says nothing about whether a form field ever presents as one.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

/// Grants everything except the paths it is told to deny, so a test only has
/// to name the one field it cares about.
class _Adapter implements TomAuthorizationAdapter {
  final Map<String, TomAuthState> denials = <String, TomAuthState>{};

  @override
  TomAuthState resolveAuth(String path) => denials[path] ?? TomAuthState.full;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A child that records the lifecycle of its own `State`, which is how the
/// keying group tells "reused" from "rebuilt".
class _Probe extends StatefulWidget {
  const _Probe(this.label, this.log);

  final String label;
  final List<String> log;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.log.add('init ${widget.label}');
  }

  @override
  void didUpdateWidget(_Probe oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.log.add('update ${widget.label}');
  }

  @override
  void dispose() {
    widget.log.add('dispose ${widget.label}');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(widget.label);
}

Widget _host(Widget child) =>
    Directionality(textDirection: TextDirection.ltr, child: child);

void main() {
  late _Adapter authorization;

  setUp(() {
    authorization = _Adapter();
    TomAuthorization.reset();
    TomAuthorization.adapter = authorization;
  });

  tearDown(TomAuthorization.reset);

  TomFormStringInput field(String tomId) {
    final created = TomFormStringInput(tomId, 'Bolt');
    addTearDown(created.dispose);
    return created;
  }

  // -------------------------------------------------------------------------
  // Delegation
  // -------------------------------------------------------------------------

  group('as a TomAuthorizable, the adapter answers for its field', () {
    test('reports the field\'s tomId', () {
      final wrapped = field('quantity');

      final adapter =
          TomFieldWidgetAdapter(field: wrapped, child: const SizedBox());

      expect(adapter.tomId, 'quantity');
    });

    test('reports the field\'s group', () {
      final group = TomAuthorizationGroup('tools');
      final wrapped = TomFormStringInput('quantity', 'Bolt', tomGroup: group);
      addTearDown(wrapped.dispose);

      final adapter =
          TomFieldWidgetAdapter(field: wrapped, child: const SizedBox());

      expect(adapter.tomGroup, same(group));
      expect(
        TomFieldWidgetAdapter(field: field('other'), child: const SizedBox())
            .tomGroup,
        isNull,
      );
    });

    test('reports the field\'s auth state, not an optimistic default', () {
      authorization.denials['secret'] = TomAuthState.none;
      final wrapped = field('secret');

      final adapter =
          TomFieldWidgetAdapter(field: wrapped, child: const SizedBox());

      expect(adapter.effectiveAuthState, TomAuthState.none);
    });

    test('distinguishes the states, rather than collapsing them to one', () {
      // A delegation that returned a constant would pass the test above for
      // whichever constant it chose, so two states are asked for.
      authorization.denials['readonly'] = TomAuthState.read;
      final readonly = field('readonly');
      final open = field('open');

      expect(
        TomFieldWidgetAdapter(field: readonly, child: const SizedBox())
            .effectiveAuthState,
        TomAuthState.read,
      );
      expect(
        TomFieldWidgetAdapter(field: open, child: const SizedBox())
            .effectiveAuthState,
        TomAuthState.full,
      );
    });

    test('asks the field again each time, so a later policy change is seen',
        () {
      // The adapter is `const`-constructible and long-lived; if it snapshotted
      // the state at construction, a policy that changed after login — or
      // after a group's mode was flipped — would never reach the UI.
      final wrapped = field('secret');
      final adapter =
          TomFieldWidgetAdapter(field: wrapped, child: const SizedBox());
      expect(adapter.effectiveAuthState, TomAuthState.full);

      authorization.denials['secret'] = TomAuthState.none;

      expect(adapter.effectiveAuthState, TomAuthState.none);
    });
  });

  // -------------------------------------------------------------------------
  // Pass-through
  // -------------------------------------------------------------------------

  group('the widget it was given', () {
    testWidgets('is what gets rendered — the adapter adds no chrome',
        (tester) async {
      final wrapped = field('quantity');

      await tester.pumpWidget(
        _host(TomFieldWidgetAdapter(
          field: wrapped,
          child: const Text('payload'),
        )),
      );

      expect(find.text('payload'), findsOneWidget);
    });

    test('is how every field reaches the tree', () {
      // The adapter is not an opt-in wrapper a caller may forget: the field's
      // own `widget` getter installs it, which is why all 26 of the module's
      // field files go through this class.
      final wrapped = field('quantity');

      final rendered = wrapped.widget;

      expect(rendered, isA<TomFieldWidgetAdapter>());
      expect((rendered as TomFieldWidgetAdapter).field, same(wrapped));
    });
  });

  // -------------------------------------------------------------------------
  // Identity keying
  // -------------------------------------------------------------------------

  group('State follows the field, not the slot', () {
    testWidgets('a different field in the same slot gets a fresh State',
        (tester) async {
      // The master/detail row swap. A reused State keeps observing the
      // previous field: its controller never updates, the displayed value
      // goes stale, and edits land on the wrong record.
      final log = <String>[];
      final first = field('first');
      final second = field('second');

      await tester.pumpWidget(
        _host(TomFieldWidgetAdapter(field: first, child: _Probe('a', log))),
      );
      await tester.pumpWidget(
        _host(TomFieldWidgetAdapter(field: second, child: _Probe('b', log))),
      );
      await tester.pump();

      expect(log.where((entry) => entry.startsWith('update')), isEmpty,
          reason: 'no State may be carried over to the new field');
      expect(log, contains('init b'));
      expect(log, contains('dispose a'));
    });

    testWidgets('the same field re-rendered keeps its State', (tester) async {
      // A breakpoint-driven re-layout rebuilds with the same field. Losing
      // State here would flash focus, selection and controller text on every
      // width change — the reason the key is the field and not a UniqueKey.
      final log = <String>[];
      final only = field('only');

      await tester.pumpWidget(
        _host(TomFieldWidgetAdapter(field: only, child: _Probe('a', log))),
      );
      await tester.pumpWidget(
        _host(TomFieldWidgetAdapter(field: only, child: _Probe('a', log))),
      );

      expect(log, ['init a', 'update a']);
    });

    testWidgets('keys on the field instance, not on the field\'s id',
        (tester) async {
      // Two fields can legitimately share a tomId — the same form rendered
      // for two rows of a list — so identity, not name, has to decide.
      final log = <String>[];

      await tester.pumpWidget(
        _host(TomFieldWidgetAdapter(field: field('row'), child: _Probe('a', log))),
      );
      await tester.pumpWidget(
        _host(TomFieldWidgetAdapter(field: field('row'), child: _Probe('b', log))),
      );
      await tester.pump();

      expect(log.where((entry) => entry.startsWith('update')), isEmpty);
      expect(log, contains('dispose a'));
    });
  });

  // -------------------------------------------------------------------------
  // What the delegation is for
  // -------------------------------------------------------------------------

  group('inside an ACL hide-unauthorized pass', () {
    Widget layout(TomFormStringInput wrapped) => AclBuilder()
        .setAclDefaultHideUnauthorized(true)
        .append(wrapped.widget)
        .setPSize(300, 220)
        .build();

    Future<void> pump(WidgetTester tester, Widget content) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SizedBox(width: 1000, child: content)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a denied field is elided', (tester) async {
      authorization.denials['secret'] = TomAuthState.none;

      await pump(tester, layout(field('secret')));

      expect(find.byType(TextField), findsNothing,
          reason: 'the pass reads the child widget, so the field only '
              'disappears if the adapter presents its auth state');
    });

    testWidgets('a permitted field is left alone', (tester) async {
      await pump(tester, layout(field('open')));

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('only `none` hides — a read-only field still renders',
        (tester) async {
      // The pass tests for `none` exactly. A delegation that widened or
      // narrowed on the way through would show up here as a read-only field
      // vanishing.
      authorization.denials['readonly'] = TomAuthState.read;

      await pump(tester, layout(field('readonly')));

      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
