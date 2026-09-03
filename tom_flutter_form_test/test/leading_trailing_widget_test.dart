/// T13 — style.leadingWidget / style.trailingWidget reach the rendered field.
///
/// Phase 2 of the leading-widget story (the symmetric trailing extension)
/// added four new fields to `TomFieldStyle` + `TomFieldPartialStyle`:
///   * `leadingWidget`  + `leadingGap`  (default 4.0)
///   * `trailingWidget` + `trailingGap` (default 4.0)
///
/// These should land in:
///   * Material:  InputDecoration.prefixIcon / suffixIcon (composed via
///     `applyErrorVisuals` so error icons stay rightmost)
///   * Cupertino: CupertinoTextField.prefix / suffix (composed via
///     `composeCupertinoLeading` / `composeCupertinoTrailing`)
///
/// We pump a single field inside a TomFormStyleScope that injects the
/// new widgets and assert the underlying Flutter widget exposes them in
/// the right slot. Probing the decoration / Cupertino prefix slot via
/// `tester.widget<…>(…)` is enough — we don't need a screenshot, we
/// just need to prove the wiring.
library;

import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'package:tom_flutter_form_test/main.reflection.dart';
import 'package:tom_flutter_form_test/forms/company_forms.dart';

// ---------------------------------------------------------------------------
// Probes — recursively walk a widget subtree to find a Text descendant by
// data, regardless of how many Padding / SizedBox / Row wrappers our
// composition inserted.
// ---------------------------------------------------------------------------

bool _subtreeContainsText(Widget? root, String data) {
  if (root == null) return false;
  final found = <bool>[false];
  void visit(Widget w) {
    if (found[0]) return;
    if (w is Text && w.data == data) {
      found[0] = true;
      return;
    }
    // Walk children for the wrappers we know we use.
    if (w is Padding && w.child != null) visit(w.child!);
    if (w is Row) {
      for (final c in w.children) {
        visit(c);
      }
    }
    if (w is SizedBox && w.child != null) visit(w.child!);
    if (w is Container && w.child != null) visit(w.child!);
  }

  visit(root);
  return found[0];
}

// ---------------------------------------------------------------------------
// Material harness — pumps `CompanyBasicInfoForm.name` (a string input,
// the simplest concrete) inside a TomFormStyleScope that injects a
// star Text as the leading widget.
// ---------------------------------------------------------------------------

Widget _materialHarness({required Widget child, required TomFormStyle style}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: TomFormStyleScope(
            tomId: 't13MaterialScope',
            style: style,
            child: Builder(builder: (_) => child),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    initializeReflection();
    final jsonStr = await rootBundle.loadString('assets/demo_resources.json');
    final resources = json.decode(jsonStr) as Map<String, dynamic>;
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(resources),
    );
  });

  group('T13 — Material InputDecoration carries leading/trailing widgets', () {
    late CompanyBasicInfoForm form;

    setUp(() {
      form = TomScope.withScope(
        'companyBasicInfo',
        () => CompanyBasicInfoForm(),
      );
    });
    tearDown(() => form.dispose());

    testWidgets('leadingWidget lands in InputDecoration.prefixIcon', (
      tester,
    ) async {
      final style = TomFormStyle.material3.copyWith(
        defaults: TomFormStyle.material3.defaults.copyWith(
          leadingWidget: const Text('★'),
          leadingGap: 8.0,
          leadingWidgetSet: true,
        ),
      );
      await tester.pumpWidget(
        _materialHarness(style: style, child: form.name.widget),
      );
      await tester.pumpAndSettle();

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(
        tf.decoration?.prefixIcon,
        isNotNull,
        reason: 'leadingWidget must land in prefixIcon',
      );
      expect(
        _subtreeContainsText(tf.decoration!.prefixIcon, '★'),
        isTrue,
        reason: 'leadingWidget Text must survive the Padding wrapper',
      );
    });

    testWidgets('trailingWidget lands in InputDecoration.suffixIcon', (
      tester,
    ) async {
      final style = TomFormStyle.material3.copyWith(
        defaults: TomFormStyle.material3.defaults.copyWith(
          trailingWidget: const Text('☆'),
          trailingGap: 12.0,
          trailingWidgetSet: true,
        ),
      );
      await tester.pumpWidget(
        _materialHarness(style: style, child: form.name.widget),
      );
      await tester.pumpAndSettle();

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(
        tf.decoration?.suffixIcon,
        isNotNull,
        reason: 'trailingWidget must land in suffixIcon',
      );
      expect(
        _subtreeContainsText(tf.decoration!.suffixIcon, '☆'),
        isTrue,
        reason: 'trailingWidget Text must survive the Padding wrapper',
      );
    });

    testWidgets('both leading + trailing land in their respective slots', (
      tester,
    ) async {
      final style = TomFormStyle.material3.copyWith(
        defaults: TomFormStyle.material3.defaults.copyWith(
          leadingWidget: const Text('L'),
          leadingWidgetSet: true,
          trailingWidget: const Text('T'),
          trailingWidgetSet: true,
        ),
      );
      await tester.pumpWidget(
        _materialHarness(style: style, child: form.name.widget),
      );
      await tester.pumpAndSettle();

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(_subtreeContainsText(tf.decoration?.prefixIcon, 'L'), isTrue);
      expect(_subtreeContainsText(tf.decoration?.suffixIcon, 'T'), isTrue);
    });

    testWidgets('absence — no leading/trailing widget = both slots null', (
      tester,
    ) async {
      // Sanity baseline: with the stock material3 style, a plain string
      // input has no prefixIcon/suffixIcon. This guards against accidental
      // injection from the new code path.
      await tester.pumpWidget(
        _materialHarness(
          style: TomFormStyle.material3,
          child: form.name.widget,
        ),
      );
      await tester.pumpAndSettle();

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(
        tf.decoration?.prefixIcon,
        isNull,
        reason: 'no leadingWidget = no prefixIcon',
      );
      expect(
        tf.decoration?.suffixIcon,
        isNull,
        reason: 'no trailingWidget = no suffixIcon',
      );
    });
  });

  // -------------------------------------------------------------------------
  // Cupertino side — pumps a TomCupertinoFormStringInput field. We have to
  // construct it on the fly because the existing demo forms in the test
  // app don't expose a "lone" Cupertino string field outside a TomList /
  // demo wrapper.
  // -------------------------------------------------------------------------

  group(
    'T13 — Cupertino prefix/suffix slots carry leading/trailing widgets',
    () {
      Widget cupertinoHarness({
        required TomFormStyle style,
        required Widget Function() build,
      }) {
        return CupertinoApp(
          home: CupertinoPageScaffold(
            child: SafeArea(
              child: SingleChildScrollView(
                child: SizedBox(
                  width: 400,
                  child: TomFormStyleScope(
                    tomId: 't13CupertinoScope',
                    style: style,
                    child: Builder(builder: (_) => build()),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      testWidgets(
        'Cupertino string input — leadingWidget reaches prefix slot',
        (tester) async {
          late TomCupertinoFormStringInput field;
          TomScope.withScope('t13Cupertino', () {
            field = TomCupertinoFormStringInput('t13s', '');
          });
          addTearDown(field.dispose);

          final style = TomFormStyle.material3.copyWith(
            defaults: TomFormStyle.material3.defaults.copyWith(
              leadingWidget: const Text('★'),
              leadingWidgetSet: true,
            ),
          );

          await tester.pumpWidget(
            cupertinoHarness(style: style, build: () => field.widget),
          );
          await tester.pumpAndSettle();

          final ctf = tester.widget<CupertinoTextField>(
            find.byType(CupertinoTextField),
          );
          expect(
            ctf.prefix,
            isNotNull,
            reason: 'leadingWidget must reach CupertinoTextField.prefix',
          );
          expect(_subtreeContainsText(ctf.prefix, '★'), isTrue);
        },
      );

      testWidgets(
        'Cupertino string input — trailingWidget reaches suffix slot',
        (tester) async {
          late TomCupertinoFormStringInput field;
          TomScope.withScope('t13Cupertino', () {
            field = TomCupertinoFormStringInput('t13s2', '');
          });
          addTearDown(field.dispose);

          final style = TomFormStyle.material3.copyWith(
            defaults: TomFormStyle.material3.defaults.copyWith(
              trailingWidget: const Text('☆'),
              trailingWidgetSet: true,
            ),
          );

          await tester.pumpWidget(
            cupertinoHarness(style: style, build: () => field.widget),
          );
          await tester.pumpAndSettle();

          final ctf = tester.widget<CupertinoTextField>(
            find.byType(CupertinoTextField),
          );
          expect(
            ctf.suffix,
            isNotNull,
            reason: 'trailingWidget must reach CupertinoTextField.suffix',
          );
          expect(_subtreeContainsText(ctf.suffix, '☆'), isTrue);
        },
      );
    },
  );
}
