import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// TomMessenger is the Tom-side entry point for transient messages. showSnackBar
// mirrors ScaffoldMessenger.of (asserting when no messenger is in scope),
// showSnackBarIfPresent mirrors maybeOf (returning null instead), and
// showMessage is the one-line convenience that builds the TomSnackBar/TomText
// pair so callers do not hand-assemble it. These pin all three, including the
// maybeOf/of split — the whole point of having two entry points.

void main() {
  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(const {}),
    );
    TomUIColors.adapter = AllColorsAdapter();
    TomAuthorization.reset();
  });

  testWidgets('showMessage renders the text in a snack bar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => TomMessenger.showMessage(context, 'saved'),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('saved'), findsNothing);
    await tester.tap(find.text('go'));
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('saved'), findsOneWidget);
  });

  testWidgets('showSnackBar returns a controller for the shown bar', (
    tester,
  ) async {
    ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? controller;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => controller = TomMessenger.showSnackBar(
                context,
                TomSnackBar(content: TomText(text: 'hello')),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pump();

    expect(controller, isNotNull);
    expect(find.text('hello'), findsOneWidget);

    // The controller drives the bar it returned.
    controller!.close();
    await tester.pumpAndSettle();
    expect(find.text('hello'), findsNothing);
  });

  testWidgets('showSnackBarIfPresent returns null with no messenger in scope', (
    tester,
  ) async {
    Object? result = 'unset';

    // A bare WidgetsApp — no Scaffold, so no ScaffoldMessenger ancestor.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) {
            result = TomMessenger.showSnackBarIfPresent(
              context,
              TomSnackBar(content: TomText(text: 'ignored')),
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(result, isNull);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('showSnackBarIfPresent shows when a messenger IS in scope', (
    tester,
  ) async {
    ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? controller;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => controller = TomMessenger.showSnackBarIfPresent(
                context,
                TomSnackBar(content: TomText(text: 'present')),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pump();

    expect(controller, isNotNull);
    expect(find.text('present'), findsOneWidget);
  });
}
