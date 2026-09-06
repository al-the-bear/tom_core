/// Guards Demo G's "Flags & tags" row against reverting to hand-rolled
/// Material widgets.
///
/// The row used to render bare `Switch`es and `InputChip`s over the state's
/// observables, captioned "Phase 2 stand-ins", on the claim that the
/// `TomField` implementations did not exist yet. They did. Nothing about a
/// screenshot distinguishes a real `TomFormBoolSwitch` from a bare `Switch`,
/// so the assertion that they are real fields — bound, carrying the brief's
/// values — has to be made here rather than left to the goldens.
library;

import 'dart:convert';

// `services.dart` re-exports `dart:ui`, so it carries both `rootBundle` and
// the `Size` used to widen the test viewport.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'package:tom_flutter_form_test/main.dart';
import 'package:tom_flutter_form_test/main.reflection.dart';
import 'package:tom_flutter_form_test/state/project_brief_state.dart';

/// Every field Demo G renders, by runtime type — read back off the
/// [TomFieldWidgetAdapter] each field wraps its widget in.
Map<Type, List<TomField>> _renderedFields(WidgetTester tester) {
  final byType = <Type, List<TomField>>{};
  for (final adapter in tester.widgetList<TomFieldWidgetAdapter>(
    find.byType(TomFieldWidgetAdapter),
  )) {
    byType.putIfAbsent(adapter.field.runtimeType, () => []).add(adapter.field);
  }
  return byType;
}

Future<void> _openDemoG(WidgetTester tester) async {
  tester.view.physicalSize = const Size(2400, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(const FormDemoApp());
  await tester.tap(find.text('Demo G: Complex Breakpoint Scenarios'));
  await tester.pumpAndSettle();
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

  testWidgets('Demo G renders real bool fields carrying the brief values', (
    tester,
  ) async {
    await _openDemoG(tester);
    final fields = _renderedFields(tester);

    // One of each shipped rendering, so the style swap is proven against
    // all three boolean anatomies rather than three copies of one.
    expect(fields[TomFormBoolSwitch], hasLength(1));
    expect(fields[TomFormBoolCheckbox], hasLength(1));
    expect(fields[TomFormBoolToggle], hasLength(1));

    final bools = {
      for (final field in [
        ...fields[TomFormBoolSwitch]!,
        ...fields[TomFormBoolCheckbox]!,
        ...fields[TomFormBoolToggle]!,
      ])
        field.tomId: field as TomField<bool>,
    };
    expect(bools.keys, {'isPublic', 'needsReview', 'notifySubscribers'});

    // Bound, not merely constructed: these are the seeded brief's values,
    // and `needsReview` / `notifySubscribers` differ from the fields'
    // `false` initial value, so only binding can have produced them.
    expect(bools['isPublic']!.get(), phase2ProjectBriefState.isPublic.get());
    expect(
      bools['needsReview']!.get(),
      phase2ProjectBriefState.needsReview.get(),
    );
    expect(
      bools['notifySubscribers']!.get(),
      phase2ProjectBriefState.notifySubscribers.get(),
    );
    expect(bools['needsReview']!.get(), isTrue);
  });

  testWidgets('Demo G renders a real tag multi-select seeded from the brief', (
    tester,
  ) async {
    await _openDemoG(tester);
    final chips = _renderedFields(tester)[TomFormStringFilterChips];

    expect(chips, hasLength(1));
    final tags = chips!.single as TomFormStringFilterChips;
    expect(tags.tomId, 'tags');
    expect(tags.get(), [
      for (final tag in phase2ProjectBriefState.tags) tag.get(),
    ]);
    expect(tags.get(), isNotEmpty, reason: 'The brief seeds three tags.');
  });

  testWidgets('Editing the tag field writes back onto the brief', (
    tester,
  ) async {
    await _openDemoG(tester);
    final tags =
        _renderedFields(tester)[TomFormStringFilterChips]!.single
            as TomFormStringFilterChips;

    // The field is not a form member — `TomList<TomString>` cannot bind to a
    // `TomField<List<String>>` — so the demo mirrors edits back by hand. That
    // hand-written path is what this asserts.
    addTearDown(() => tags.toggleItem('incident', false));
    tags.toggleItem('incident', true);
    await tester.pumpAndSettle();

    expect(
      [for (final tag in phase2ProjectBriefState.tags) tag.get()],
      contains('incident'),
    );
  });
}
