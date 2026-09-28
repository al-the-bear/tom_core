/// `TomLoadingOverlay` — the widget in `custom/` that had no test file of its
/// own, and whose two interesting parameters were both unasserted.
///
/// `blocksPointerEvents` is the one that matters: the scrim *looks* like a
/// barrier whether or not it is one, so a caller who sets it to false and a
/// caller who leaves it true see identical pixels and opposite behaviour. The
/// cases below tap through.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Content with something to press, so "covered" can be told from "blocked".
Widget _content(VoidCallback onPressed) => Center(
  child: ElevatedButton(onPressed: onPressed, child: const Text('act')),
);

void main() {
  group('isLoading', () {
    testWidgets('false renders the child and nothing else', (tester) async {
      // Documented as "only [child] is rendered (no extra widgets)", which is
      // stronger than "the spinner is hidden" and is the half worth pinning:
      // a scrim left in the tree at zero opacity would still eat taps.
      var taps = 0;
      await tester.pumpWidget(
        _host(
          TomLoadingOverlay(isLoading: false, child: _content(() => taps++)),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
      // Not a finder for the barrier type: the ambient `MaterialApp` puts one
      // of those above everything, so it is present either way. The tap is
      // the assertion.
      await tester.tap(find.text('act'));
      await tester.pump();
      expect(taps, 1, reason: 'nothing is in the way');
    });

    testWidgets('true veils the child rather than replacing it', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(TomLoadingOverlay(isLoading: true, child: _content(() {}))),
      );

      expect(
        find.text('act'),
        findsOneWidget,
        reason: 'the content stays painted under the scrim',
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('blocksPointerEvents', () {
    testWidgets('true stops a tap reaching the covered content', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          TomLoadingOverlay(isLoading: true, child: _content(() => taps++)),
        ),
      );

      await tester.tap(find.text('act'), warnIfMissed: false);
      await tester.pump();
      expect(taps, 0, reason: 'the default is a barrier, not a tint');
    });

    testWidgets('false lets it through', (tester) async {
      // The control, and the parameter's whole purpose: a caller who wants a
      // progress hint over content that stays usable.
      var taps = 0;
      await tester.pumpWidget(
        _host(
          TomLoadingOverlay(
            isLoading: true,
            blocksPointerEvents: false,
            child: _content(() => taps++),
          ),
        ),
      );

      await tester.tap(find.text('act'), warnIfMissed: false);
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('presentation', () {
    testWidgets('a message is rendered beneath the spinner', (tester) async {
      await tester.pumpWidget(
        _host(
          const TomLoadingOverlay(
            isLoading: true,
            message: 'Saving…',
            child: SizedBox.expand(),
          ),
        ),
      );

      expect(
        tester.getTopLeft(find.text('Saving…')).dy,
        greaterThan(
          tester.getTopLeft(find.byType(CircularProgressIndicator)).dy,
        ),
      );
    });

    testWidgets('no message renders no text at all', (tester) async {
      // The control for the case above: an empty `Text` would look the same
      // on screen and is what a careless `??  ''` produces.
      await tester.pumpWidget(
        _host(
          const TomLoadingOverlay(isLoading: true, child: SizedBox.expand()),
        ),
      );

      expect(find.byType(Text), findsNothing);
    });

    testWidgets('scrimColor is the colour actually laid over the child', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const TomLoadingOverlay(
            isLoading: true,
            scrimColor: Color(0xFF00FF00),
            child: SizedBox.expand(),
          ),
        ),
      );

      final scrim = tester.widgetList<ColoredBox>(find.byType(ColoredBox));
      expect(
        scrim.map((b) => b.color),
        contains(const Color(0xFF00FF00)),
        reason: 'the parameter reaches the box that paints the veil',
      );
    });

    testWidgets('progress makes the indicator determinate', (tester) async {
      // `null` and a value render the same *type*, so the assertion is on the
      // value the indicator was given — which is the only thing that differs.
      await tester.pumpWidget(
        _host(
          const TomLoadingOverlay(
            isLoading: true,
            progress: 0.42,
            child: SizedBox.expand(),
          ),
        ),
      );

      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .value,
        0.42,
      );
    });

    testWidgets('no progress leaves it indeterminate', (tester) async {
      await tester.pumpWidget(
        _host(
          const TomLoadingOverlay(isLoading: true, child: SizedBox.expand()),
        ),
      );

      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .value,
        isNull,
      );
    });
  });
}
