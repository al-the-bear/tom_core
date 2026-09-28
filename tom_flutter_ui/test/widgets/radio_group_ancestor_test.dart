import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// Flutter modelled a radio with `groupValue` and `onChanged` on the widget
// itself before v3.32, and stopped modelling one that way after. Selection
// comes from a `RadioGroup<T>` ancestor, so the three radio wrappers forward
// only their `value`.
//
// That move takes away the lever Tom's authorization used to reach for. A
// withheld `TomAuthState` never touched `onChanged` — `TomPolicyNodeBase`
// wraps the readonly and disabled builds in a `TomStateStyle`, whose default
// is an `AbsorbPointer` — but the pointer was the only way in, so blocking it
// was enough. `RadioGroup` adds arrow-key navigation, and `AbsorbPointer` does
// not stop a keyboard. `Radio.enabled` is the remaining lever, so
// `_radioEnabled` pulls it for every state but `full`; the four `enabled`
// tests below are what keep that from being re-broken by someone who reads
// the wrapper and sees no auth code in it.
//
// The tests assert `enabled` on the *Flutter* widget rather than tapping,
// because `enabled: false` and "blocked by the AbsorbPointer above it" are
// indistinguishable from a tap's point of view, and only one of them survives
// a keyboard.

class _PathAuthAdapter extends TomAuthorizationAdapter {
  _PathAuthAdapter(this.rules);
  final Map<String, TomAuthState> rules;

  @override
  TomAuthState resolveAuth(String path) => rules[path] ?? TomAuthState.full;
}

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Pumps [child] under a `RadioGroup<int>` reporting through [onChanged].
Widget _grouped(Widget child, {int? selected, ValueChanged<int?>? onChanged}) =>
    _host(
      RadioGroup<int>(
        groupValue: selected,
        onChanged: onChanged ?? (_) {},
        child: child,
      ),
    );

Radio<int> _radioOf(WidgetTester tester) =>
    tester.widget<Radio<int>>(find.byType(Radio<int>));

void main() {
  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(const {}),
    );
    TomUIColors.adapter = AllColorsAdapter();
    TomAuthorization.reset();
  });
  tearDown(TomAuthorization.reset);

  group('tcinc806: selection comes from the ancestor', () {
    testWidgets('tcinc806-01: a matching ancestor value selects the radio', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_grouped(TomRadio<int>(value: 1), selected: 1));

      final node = tester.getSemantics(find.byType(Radio<int>));
      expect(node, isSemantics(isChecked: true));
      handle.dispose();
    });

    testWidgets(
      'tcinc806-02: a different ancestor value leaves it unselected',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_grouped(TomRadio<int>(value: 1), selected: 2));

        final node = tester.getSemantics(find.byType(Radio<int>));
        expect(node, isSemantics(isChecked: false));
        handle.dispose();
      },
    );

    testWidgets('tcinc806-03: tapping reports this radio value to the group', (
      tester,
    ) async {
      int? picked;
      await tester.pumpWidget(
        _grouped(
          TomRadio<int>(value: 7),
          selected: 1,
          onChanged: (v) => picked = v,
        ),
      );

      await tester.tap(find.byType(Radio<int>));
      await tester.pump();
      expect(picked, 7);
    });

    testWidgets(
      'tcinc806-04: without an ancestor it renders inert, not broken',
      (tester) async {
        // A radio with no group is not an error — `Radio` itself renders one
        // unselected and disabled. The wrapper must not turn that into a throw,
        // because a caller who has not wired the group yet still has to be able
        // to lay the screen out.
        await tester.pumpWidget(_host(TomRadio<int>(value: 1)));

        expect(find.byType(Radio<int>), findsOneWidget);
        expect(_radioOf(tester).enabled, isNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('tcinc806-05: TomRadioListTile reads the same ancestor', (
      tester,
    ) async {
      int? picked;
      await tester.pumpWidget(
        _grouped(
          TomRadioListTile<int>(value: 3, title: const Text('Gamma')),
          selected: 1,
          onChanged: (v) => picked = v,
        ),
      );

      await tester.tap(find.text('Gamma'));
      await tester.pump();
      expect(picked, 3);
    });

    testWidgets('tcinc806-06: TomCupertinoRadio reads the same ancestor', (
      tester,
    ) async {
      int? picked;
      await tester.pumpWidget(
        _grouped(
          TomCupertinoRadio<int>(value: 5),
          selected: 1,
          onChanged: (v) => picked = v,
        ),
      );

      await tester.tap(find.byType(CupertinoRadio<int>));
      await tester.pump();
      expect(picked, 5);
    });
  });

  group('tcinc806: a withheld auth state pulls `enabled`', () {
    testWidgets('tcinc806-07: full leaves the decision to the ancestor', (
      tester,
    ) async {
      await tester.pumpWidget(
        _grouped(TomRadio<int>(tomId: 'grade', value: 1), selected: 1),
      );
      expect(_radioOf(tester).enabled, isNull);
    });

    testWidgets('tcinc806-08: read disables the radio under a live group', (
      tester,
    ) async {
      TomAuthorization.adapter = _PathAuthAdapter({'grade': TomAuthState.read});
      await tester.pumpWidget(
        _grouped(TomRadio<int>(tomId: 'grade', value: 1), selected: 1),
      );
      expect(_radioOf(tester).enabled, isFalse);
    });

    testWidgets('tcinc806-09: disabled does the same', (tester) async {
      TomAuthorization.adapter = _PathAuthAdapter({
        'grade': TomAuthState.disabled,
      });
      await tester.pumpWidget(
        _grouped(TomRadio<int>(tomId: 'grade', value: 1), selected: 1),
      );
      expect(_radioOf(tester).enabled, isFalse);
    });

    testWidgets('tcinc806-10: an explicit enabled overrides the auth default', (
      tester,
    ) async {
      // `enabled` is the caller's own answer, so it wins over the state
      // `_radioEnabled` would otherwise pick — including in the other
      // direction, where a caller disables a radio the grant permits.
      await tester.pumpWidget(
        _grouped(
          TomRadio<int>(tomId: 'grade', value: 1, enabled: false),
          selected: 1,
        ),
      );
      expect(_radioOf(tester).enabled, isFalse);
    });

    testWidgets('tcinc806-11: the list tile pulls enabled the same way', (
      tester,
    ) async {
      TomAuthorization.adapter = _PathAuthAdapter({'grade': TomAuthState.read});
      await tester.pumpWidget(
        _grouped(
          TomRadioListTile<int>(
            tomId: 'grade',
            value: 1,
            title: const Text('G'),
          ),
          selected: 1,
        ),
      );
      expect(
        tester
            .widget<RadioListTile<int>>(find.byType(RadioListTile<int>))
            .enabled,
        isFalse,
      );
    });

    testWidgets('tcinc806-12: the Cupertino radio pulls enabled the same way', (
      tester,
    ) async {
      TomAuthorization.adapter = _PathAuthAdapter({'grade': TomAuthState.read});
      await tester.pumpWidget(
        _grouped(TomCupertinoRadio<int>(tomId: 'grade', value: 1), selected: 1),
      );
      expect(
        tester
            .widget<CupertinoRadio<int>>(find.byType(CupertinoRadio<int>))
            .enabled,
        isFalse,
      );
    });
  });

  group('tcinc806: TomChoiceGroup supplies the ancestor', () {
    const items = <TomChoiceGroupItem<String>>[
      TomChoiceGroupItem(value: 'a', label: 'Alpha'),
      TomChoiceGroupItem(value: 'b', label: 'Beta'),
    ];

    testWidgets('tcinc806-13: the group carries the selected value', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const TomChoiceGroup<String>(items: items, selected: 'b')),
      );
      expect(
        tester
            .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
            .groupValue,
        'b',
      );
    });

    testWidgets('tcinc806-14: picking a row reports through onChanged', (
      tester,
    ) async {
      String? picked;
      await tester.pumpWidget(
        _host(
          TomChoiceGroup<String>(
            items: items,
            selected: 'a',
            onChanged: (v) => picked = v,
          ),
        ),
      );

      await tester.tap(find.byType(Radio<String>).last);
      await tester.pump();
      expect(picked, 'b');
    });

    testWidgets(
      'tcinc806-15: read disables every radio, not just the pointer',
      (tester) async {
        // The `IgnorePointer` the group already applied is not enough once a
        // `RadioGroup` is overhead: arrow keys reach the radios around it.
        TomAuthorization.adapter = _PathAuthAdapter({
          'choice': TomAuthState.read,
        });
        await tester.pumpWidget(
          _host(
            const TomChoiceGroup<String>(
              tomId: 'choice',
              items: items,
              selected: 'a',
            ),
          ),
        );

        final radios = tester.widgetList<Radio<String>>(
          find.byType(Radio<String>),
        );
        expect(radios, hasLength(2));
        expect(radios.map((r) => r.enabled), everyElement(isFalse));
      },
    );

    testWidgets('tcinc806-16: full leaves every radio enabled', (tester) async {
      await tester.pumpWidget(
        _host(const TomChoiceGroup<String>(items: items, selected: 'a')),
      );

      final radios = tester.widgetList<Radio<String>>(
        find.byType(Radio<String>),
      );
      expect(radios.map((r) => r.enabled), everyElement(isTrue));
    });
  });
}
