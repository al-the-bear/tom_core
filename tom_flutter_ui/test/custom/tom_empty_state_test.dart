/// Behavioural coverage for `TomEmptyState`'s headline contract.
///
/// The dartdoc called the headline "Required when no `tomId` resolves a
/// `title` resource" beside an ordinary optional parameter with no assertion,
/// no default and no check. Supplying neither source rendered a lone grey
/// icon — the widget's whole purpose is to make "no rows" read as a designed
/// surface rather than blank space, and a wordless glyph is blank space with
/// extra steps.
///
/// It is enforced now, through the same `TomCtr.textOrFail` that twenty-odd
/// sibling widgets use for a text they genuinely need. That brings two
/// properties worth pinning separately, because only the first is obvious:
///
/// 1. **No source at all throws.** The documented requirement is now true.
/// 2. **A `tomId` whose resource is missing renders the key**, rather than
///    resolving to `null` and vanishing. Every other Tom widget surfaces an
///    absent resource this way; this one used to swallow it, so a typo in a
///    `tomId` produced silence and nobody found out.
///
/// The throw happens **at construction, not during build**, which the last
/// group exists to pin. It is not a stylistic preference: this package ships
/// `TomErrorBoundary`, whose entire job is to catch build errors in its
/// subtree and render a fallback instead — and `example/gallery_demo.dart`
/// wraps a `TomEmptyState` in exactly one. A misconfiguration raised from
/// `build()` would be caught by that boundary and shown as a tidy error card,
/// converting "you forgot the headline" into a runtime condition the caller
/// never sees. Raised from the constructor it lands on the caller's own line.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void _resources(Map<String, String> entries) {
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(entries),
  );
}

/// Throws while building — the control case for the boundary group below.
class _ThrowsInBuild extends StatelessWidget {
  const _ThrowsInBuild();

  @override
  Widget build(BuildContext context) => throw StateError('build-time failure');
}

void main() {
  setUp(() => _resources({}));
  tearDown(() => _resources({}));

  group('TomEmptyState headline contract', () {
    test('neither a title nor a tomId throws', () {
      expect(TomEmptyState.new, throwsStateError,
          reason: 'the dartdoc calls the headline required, so it is');
    });

    test('an explicit title suffices', () {
      expect(() => TomEmptyState(title: 'Nothing here'), returnsNormally);
    });

    test('a tomId suffices even before any resource is registered', () {
      // `textOrFail` demands a resolvable *path*, not a populated resource:
      // with a tomId the caller has said where the string lives, and a bundle
      // that has not been loaded yet is a deployment problem, not a call-site
      // one. The missing entry surfaces as the key — see below.
      expect(() => TomEmptyState(tomId: 'reports.empty'), returnsNormally);
    });

    test('the other two strings stay optional', () {
      // Only the headline was ever documented as required. Guarding this
      // keeps a future tightening from quietly spreading to the copy and the
      // action, which have no such claim.
      expect(() => TomEmptyState(title: 'Empty'), returnsNormally);
    });
  });

  group('TomEmptyState headline resolution', () {
    testWidgets('renders the explicit title', (tester) async {
      await tester.pumpWidget(_host(TomEmptyState(title: 'Nothing here')));
      expect(find.text('Nothing here'), findsOneWidget);
    });

    testWidgets('a resource beats the explicit title', (tester) async {
      // The precedence this widget documents at the `tomId` field — resources
      // first, explicit parameters as the fallback — and the opposite of the
      // `label ?? textOrFail(...)` order the button family uses. Pinned here
      // because enforcing the requirement meant touching this exact chain,
      // and flipping it while doing so would have been invisible.
      _resources({'reports.empty.title': 'From resources'});
      await tester.pumpWidget(_host(
        TomEmptyState(tomId: 'reports.empty', title: 'From the call site'),
      ));
      expect(find.text('From resources'), findsOneWidget);
      expect(find.text('From the call site'), findsNothing);
    });

    testWidgets('an explicit title covers a missing resource', (tester) async {
      await tester.pumpWidget(_host(
        TomEmptyState(tomId: 'reports.empty', title: 'From the call site'),
      ));
      expect(find.text('From the call site'), findsOneWidget);
    });

    testWidgets('a tomId with no resource shows the key, not silence',
        (tester) async {
      // The half of this that is not about the "Required" claim at all. The
      // old resolver returned `null` here and the headline simply vanished,
      // so a mistyped `tomId` was indistinguishable from a correct one on a
      // screen nobody had translated yet.
      await tester.pumpWidget(_host(TomEmptyState(tomId: 'typo.path')));
      expect(find.text('typo.path.title'), findsOneWidget,
          reason: 'an unresolved resource is a development signal, and every '
              'other Tom widget renders its key');
    });
  });

  group('TomEmptyState failure reaches the caller', () {
    testWidgets('a build-time throw is turned into a card by TomErrorBoundary',
        (tester) async {
      // The control. Without it the next test proves nothing: "constructing
      // throws" is unremarkable unless the alternative is shown to be worse.
      await tester.pumpWidget(_host(
        const TomErrorBoundary(child: _ThrowsInBuild()),
      ));
      // Two deferred frames — see `tom_error_boundary_test.dart`'s
      // `_settleError` for why a fixed pump count is brittle here.
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsOneWidget,
          reason: 'the boundary converted the failure into UI — working as '
              'designed, and precisely why a misconfiguration must not '
              'travel this route');
      // The framework still records the original throw; draining it is the
      // package idiom, not a way of hiding anything.
      tester.takeException();
    });

    testWidgets('a misconfigured empty state throws before any boundary sees it',
        (tester) async {
      // Constructing the child happens in the caller's own expression, so the
      // boundary is never reached — it cannot guard against a widget that
      // could not be built in the first place.
      expect(
        () => TomErrorBoundary(child: TomEmptyState()),
        throwsStateError,
      );
    });
  });
}
