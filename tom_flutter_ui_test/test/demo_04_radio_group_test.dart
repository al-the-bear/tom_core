/// Demo 4's radio sections, which carry their selection on a `RadioGroup`
/// ancestor rather than on each radio.
///
/// Flutter stopped modelling a radio as a widget holding `groupValue` and
/// `onChanged` of its own; `tom_flutter_ui` followed, and [TomRadio],
/// [TomRadioListTile] and [TomCupertinoRadio] now forward only their `value`.
/// A radio with no `RadioGroup<T>` of the same type argument above it still
/// *compiles* — it simply renders unselected and inert. That is the failure
/// mode this file exists for: the demo would look plausible in a screenshot
/// and be dead to the touch, and the overflow gate, which asks only whether
/// the layout fits, would pass it.
///
/// So the assertions come in pairs: the group holds the expected selection
/// (the radios are wired to *something*), and tapping a radio moves it (the
/// group's `onChanged` reaches the demo's state). Demo 4 has five independent
/// groups and each is wired separately, so each is checked separately.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'demo_harness.dart';

/// The `RadioGroup<String>` currently holding [value], or a failure if no
/// group does.
///
/// Demo 4 mounts five groups of the same type argument, so a group has to be
/// identified by what it holds rather than by its type.
Finder _groupHolding(String? value) => find.byWidgetPredicate(
      (w) => w is RadioGroup<String> && w.groupValue == value,
      description: 'RadioGroup<String>(groupValue: $value)',
    );

/// The radio offering [value], in any of the three flavours demo 4 shows.
Finder _radioFor(String value) => find.byWidgetPredicate(
      (w) =>
          (w is Radio<String> && w.value == value) ||
          (w is RadioListTile<String> && w.value == value) ||
          (w is CupertinoRadio<String> && w.value == value),
      description: 'a radio offering "$value"',
    );

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => installDemoEnvironment(binding));
  tearDownAll(() => restoreDemoEnvironment(binding));

  group('demo 4 radios are wired to a RadioGroup ancestor', () {
    testWidgets('every group starts on the value the demo seeds it with',
        (tester) async {
      await pumpDemo(tester, 'widget_04_toggles');

      // The five seeds, from the state fields at the top of the demo.
      for (final seed in ['credit', 'medium', 'standard', 'a', 'option1']) {
        expect(_groupHolding(seed), findsOneWidget,
            reason: 'no RadioGroup holds "$seed", so the radios offering it '
                'have no ancestor to read their selection from');
      }
    });

    testWidgets('picking a payment option moves that group and no other',
        (tester) async {
      await pumpDemo(tester, 'widget_04_toggles');

      final paypal = _radioFor('paypal');
      await tester.ensureVisible(paypal.first);
      await tester.pumpAndSettle();
      await tester.tap(paypal.first);
      await tester.pumpAndSettle();

      expect(_groupHolding('paypal'), findsOneWidget,
          reason: "the group's onChanged must reach the demo's setState");
      expect(_groupHolding('credit'), findsNothing);
      // The other four groups are independent and must not have moved.
      for (final untouched in ['medium', 'standard', 'a', 'option1']) {
        expect(_groupHolding(untouched), findsOneWidget,
            reason: 'group holding "$untouched" must be independent of the '
                'payment group');
      }
    });

    testWidgets('picking a shipping tile moves the RadioListTile group',
        (tester) async {
      await pumpDemo(tester, 'widget_04_toggles');

      final express = _radioFor('express');
      await tester.ensureVisible(express.first);
      await tester.pumpAndSettle();
      await tester.tap(express.first);
      await tester.pumpAndSettle();

      expect(_groupHolding('express'), findsOneWidget);
      expect(_groupHolding('standard'), findsNothing);
    });
  });
}
