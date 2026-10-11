/// Executable example for the `widgets/` module of `tom_flutter_ui`.
///
/// `widgets/` is the **general widget kit** — 290 thin Tom wrappers over the
/// Flutter/Cupertino widget set, grouped into 20 families (buttons, labels,
/// inputs, toggles, containers, dialogs, navigation, progress, …). 273 of them
/// extend a family base class (`TomButtonBase`, `TomLabelBase`, …) from
/// `widget_base/` and so share the whole Tom contract:
///
/// - its family is the base it extends — `widget is TomButtonBase` — so it
///   is fixed by the type and needs no tag to read,
/// - it carries a `tomId` and a scope-resolved `basePath`,
/// - it resolves an `effectiveAuthState` from resource auth + authorizer +
///   UI-state controller + group, with no `BuildContext`,
/// - it resolves its display values from Tom resources at construction time.
///
/// The other 17 extend a Flutter widget directly (their parent type-checks for
/// it) and mix in `TomWidgetMixin`: everything above holds for them except the
/// family, which only a `TomFamilyBase` branch has. Section 5 uses one of them.
///
/// ## The shape of this example
///
/// One widget from **every** family, and each part of the contract shown once
/// over all twenty at once.
///
/// That combination is deliberate. A reader arriving from the family catalogue
/// in [`doc/widgets.md`](../../doc/widgets.md) is looking for *their* family,
/// so no family is left out — [oneWidgetPerFamily] names all twenty, and a
/// twenty-first family added to `widget_base/` fails
/// `test/widgets/widgets_example_test.dart` until it appears here too. But the
/// proposition this example exists to demonstrate is that the Tom contract
/// **does not vary** between them, and twenty copied blocks would quietly
/// claim the opposite: that a select is worth reading about separately from a
/// slider. It is not. Whatever your family is, sections 1–4 are its manual.
///
/// This example demonstrates those **context-free** surfaces. Rendering (the
/// `build` half) needs a widget tree and is out of scope here — see
/// `gallery_demo.dart` and the per-widget `testWidgets` suites for that.
///
/// Because it imports `flutter/material` (→ `dart:ui`) through the package
/// barrel, bare `dart run` cannot execute it. Run
/// `flutter test test/widgets/widgets_example_test.dart`, which calls this
/// example and reports its result in the exit code.
library;

// Demonstration example: console output is intentional.
// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Resolves auth state by exact resource path; unknown paths default to full.
class _PathAuthAdapter extends TomAuthorizationAdapter {
  final Map<String, TomAuthState> rules;
  _PathAuthAdapter(this.rules);

  @override
  TomAuthState resolveAuth(String path) => rules[path] ?? TomAuthState.full;
}

/// One representative widget from each of the kit's 20 families, keyed by the
/// family's name and ordered the way `widget_base/` declares the bases.
///
/// Each is given its family's name as its `tomId`, so the resource path a
/// widget resolves is legible in the output below: the button addresses
/// `button`, and inside a `settings` scope it addresses `settings.button`.
///
/// These are representatives, not recommendations — `TomCard` is one of 75
/// container-family wrappers and nothing distinguishes it here beyond being
/// short to construct. The point of the map is coverage of the *families*,
/// which is what the kit is organised by.
Map<String, TomFamilyBase> oneWidgetPerFamily() => {
  'button': TomElevatedButton(tomId: 'button'),
  'input': TomTextField(tomId: 'input'),
  'select': TomDropdownButton<int>(tomId: 'select'),
  'toggle': TomCheckbox(tomId: 'toggle', value: false),
  'slider': TomSlider(tomId: 'slider', value: 0),
  'container': TomCard(tomId: 'container'),
  'dialog': TomAlertDialog(tomId: 'dialog'),
  'table': TomTable(tomId: 'table'),
  'label': TomText(tomId: 'label', text: 'Hello'),
  'image': TomIcon(tomId: 'image'),
  'navigation': TomDrawer(tomId: 'navigation'),
  'progress': TomCircularProgressIndicator(tomId: 'progress'),
  'chip': TomActionChip(tomId: 'chip'),
  'list': TomListView(tomId: 'list'),
  'tree': TomTreeView(tomId: 'tree', nodes: const []),
  'sliver': TomSliverPadding(tomId: 'sliver', sliver: const SizedBox()),
  'animated': TomAnimatedContainer(tomId: 'animated'),
  'effect': TomSelectionArea(tomId: 'effect', child: const SizedBox()),
  'interaction': TomInkWell(tomId: 'interaction'),
  'builder': TomLayoutBuilder(
    tomId: 'builder',
    builder: (_, _) => const SizedBox(),
  ),
};

/// How to ask whether a widget belongs to a family: an `is` test against the
/// family's branch base. The family is the type; there is no tag to compare.
final Map<String, bool Function(TomFamilyBase)> familyTest = {
  'button': (w) => w is TomButtonBase,
  'input': (w) => w is TomInputBase,
  'select': (w) => w is TomSelectBase,
  'toggle': (w) => w is TomToggleBase,
  'slider': (w) => w is TomSliderBase,
  'container': (w) => w is TomContainerBase,
  'dialog': (w) => w is TomDialogBase,
  'table': (w) => w is TomTableBase,
  'label': (w) => w is TomLabelBase,
  'image': (w) => w is TomImageBase,
  'navigation': (w) => w is TomNavigationBase,
  'progress': (w) => w is TomProgressBase,
  'chip': (w) => w is TomChipBase,
  'list': (w) => w is TomListBase,
  'tree': (w) => w is TomTreeBase,
  'sliver': (w) => w is TomSliverBase,
  'animated': (w) => w is TomAnimatedBase,
  'effect': (w) => w is TomEffectBase,
  'interaction': (w) => w is TomInteractionBase,
  'builder': (w) => w is TomBuilderBase,
};

void run() {
  // Construction resolves display values from Tom resources, so install an
  // (empty) provider and a colours adapter — exactly as the widget tests do.
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(const {}),
  );
  TomUIColors.adapter = TomAllColorsAdapter();
  TomAuthorization.reset();

  // ---------------------------------------------------------------------------
  // 1. A widget's family is the branch base it extends.
  //
  //    It is a property of the type rather than of the instance: no
  //    configuration below can make a TomCard anything but a container. And
  //    each widget belongs to exactly one family, because no branch base
  //    extends another.
  // ---------------------------------------------------------------------------
  final kit = oneWidgetPerFamily();

  for (final MapEntry(key: family, value: widget) in kit.entries) {
    print('${family.padRight(12)} ${widget.runtimeType}');
    final belongsTo = [
      for (final test in familyTest.entries)
        if (test.value(widget)) test.key,
    ];
    assert(belongsTo.length == 1 && belongsTo.single == family);
  }

  final button = kit['button']!;
  print('button is TomButtonBase: ${button is TomButtonBase}');
  print('button is TomLabelBase:  ${button is TomLabelBase}');
  assert(button is! TomLabelBase);

  // ---------------------------------------------------------------------------
  // 2. The same identity and path machinery, for all twenty.
  //
  //    `basePath` is computed in the constructor, so it is readable on a widget
  //    that has never been built — no BuildContext, no pump.
  // ---------------------------------------------------------------------------
  for (final widget in kit.values) {
    assert(widget.basePath == widget.tomId);
  }
  print(
    'label.tomId / basePath: ${kit['label']!.tomId} / '
    '${kit['label']!.basePath}',
  );

  // Inside a scope, the same construction addresses a different resource.
  TomScope.withScope('settings', () {
    final scoped = oneWidgetPerFamily();
    for (final MapEntry(key: family, value: widget) in scoped.entries) {
      assert(widget.basePath == 'settings.$family');
    }
    print(
      'scoped label basePath:  '
      '${scoped['label']!.basePath}',
    );
  });

  // ---------------------------------------------------------------------------
  // 3. Authorization resolves from the path, for all twenty, without a
  //    BuildContext. Each widget consults *its own* basePath, so a rule aimed
  //    at one family does not reach another.
  // ---------------------------------------------------------------------------
  TomAuthorization.adapter = _PathAuthAdapter({
    'button': TomAuthState.read,
    'dialog': TomAuthState.none,
    'input': TomAuthState.disabled,
    'tools': TomAuthState.read, // group ceiling, used in section 4
  });

  for (final MapEntry(key: family, value: widget)
      in oneWidgetPerFamily().entries) {
    final expected = switch (family) {
      'button' => TomAuthState.read,
      'dialog' => TomAuthState.none,
      'input' => TomAuthState.disabled,
      _ => TomAuthState.full, // no rule for this path
    };
    assert(widget.effectiveAuthState == expected);
  }
  print(
    'button auth (rule: read):     '
    '${oneWidgetPerFamily()['button']!.effectiveAuthState}',
  );
  print(
    'label auth (no rule → full):  '
    '${oneWidgetPerFamily()['label']!.effectiveAuthState}',
  );

  // ---------------------------------------------------------------------------
  // 4. A group narrows its members to the group's ceiling: full ⊓ read = read.
  // ---------------------------------------------------------------------------
  final tools = TomAuthorizationGroup('tools'); // default mode: controlsWidest
  final grouped = TomCard(tomId: 'panel', tomGroup: tools);
  print('grouped auth (full ⊓ read):   ${grouped.effectiveAuthState}');
  assert(grouped.effectiveAuthState == TomAuthState.read);

  // ---------------------------------------------------------------------------
  // 5. The 17 wrappers without a family base carry everything else.
  //
  //    A `TomExpanded` has to *be* an `Expanded` for `Flex` to accept it, so it
  //    cannot also extend `TomNodeBase`; it mixes in `TomWidgetMixin` instead.
  //    Both routes implement `TomWidgetSurface`, so identity, path and
  //    authorization work identically — only the family is missing, because a
  //    family is a `TomFamilyBase` branch and an `Expanded` cannot be one.
  // ---------------------------------------------------------------------------
  final expanded = TomExpanded(tomId: 'button');
  print(
    'TomExpanded basePath / auth:  '
    '${expanded.basePath} / ${expanded.effectiveAuthState}',
  );
  assert(expanded is! TomFamilyBase);
  assert(expanded.basePath == 'button');
  assert(expanded.effectiveAuthState == TomAuthState.read);

  TomAuthorization.reset();
}

void main() => run();
