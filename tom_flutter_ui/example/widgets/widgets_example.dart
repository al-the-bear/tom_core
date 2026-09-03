/// Executable example for the `widgets/` module of `tom_flutter_ui`.
///
/// `widgets/` is the **general widget kit** — 290 thin Tom wrappers over the
/// Flutter/Cupertino widget set, grouped into 20 families (buttons, labels,
/// inputs, toggles, containers, dialogs, navigation, progress, …). 273 of them
/// extend a family base class (`TomButtonBase`, `TomLabelBase`, …) from
/// `widget_base/` and so share the whole Tom contract:
///
/// - it reports its [TomWidgetFamily] via `family` / `families` / `isFamily`,
/// - it carries a `tomId` and a scope-resolved `basePath`,
/// - it resolves an `effectiveAuthState` from resource auth + authorizer +
///   UI-state controller + group, with no `BuildContext`,
/// - it resolves its display values from Tom resources at construction time.
///
/// The other 17 extend a Flutter widget directly (their parent type-checks for
/// it) and mix in `TomWidgetMixin`: everything above holds for them except the
/// family tag, which only `TomFamilyBase` supplies. Section 5 uses one of them.
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
/// barrel, run it under the Flutter toolchain, e.g.
/// `flutter test example/widgets/widgets_example.dart`, not bare `dart run`.
/// The same scenarios are covered by `test/widgets/widgets_example_test.dart`.
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
/// family it reports and ordered the way `widget_base/` declares the bases.
///
/// Each is given its family's name as its `tomId`, so the resource path a
/// widget resolves is legible in the output below: the button addresses
/// `button`, and inside a `settings` scope it addresses `settings.button`.
///
/// These are representatives, not recommendations — `TomCard` is one of 75
/// container-family wrappers and nothing distinguishes it here beyond being
/// short to construct. The point of the map is coverage of the *families*,
/// which is what the kit is organised by.
Map<TomWidgetFamily, TomFamilyBase> oneWidgetPerFamily() => {
  TomWidgetFamily.button: TomElevatedButton(tomId: 'button'),
  TomWidgetFamily.input: TomTextField(tomId: 'input'),
  TomWidgetFamily.select: TomDropdownButton<int>(tomId: 'select'),
  TomWidgetFamily.toggle: TomCheckbox(tomId: 'toggle', value: false),
  TomWidgetFamily.slider: TomSlider(tomId: 'slider', value: 0),
  TomWidgetFamily.container: TomCard(tomId: 'container'),
  TomWidgetFamily.dialog: TomAlertDialog(tomId: 'dialog'),
  TomWidgetFamily.table: TomTable(tomId: 'table'),
  TomWidgetFamily.label: TomText(tomId: 'label', text: 'Hello'),
  TomWidgetFamily.image: TomIcon(tomId: 'image'),
  TomWidgetFamily.navigation: TomDrawer(tomId: 'navigation'),
  TomWidgetFamily.progress: TomCircularProgressIndicator(tomId: 'progress'),
  TomWidgetFamily.chip: TomActionChip(tomId: 'chip'),
  TomWidgetFamily.list: TomListView(tomId: 'list'),
  TomWidgetFamily.tree: TomTreeView(tomId: 'tree', nodes: const []),
  TomWidgetFamily.sliver: TomSliverPadding(
    tomId: 'sliver',
    sliver: const SizedBox(),
  ),
  TomWidgetFamily.animated: TomAnimatedContainer(tomId: 'animated'),
  TomWidgetFamily.effect: TomSelectionArea(
    tomId: 'effect',
    child: const SizedBox(),
  ),
  TomWidgetFamily.interaction: TomInkWell(tomId: 'interaction'),
  TomWidgetFamily.builder: TomLayoutBuilder(
    tomId: 'builder',
    builder: (_, _) => const SizedBox(),
  ),
};

void run() {
  // Construction resolves display values from Tom resources, so install an
  // (empty) provider and a colours adapter — exactly as the widget tests do.
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(const {}),
  );
  TomUIColors.adapter = AllColorsAdapter();
  TomAuthorization.reset();

  // ---------------------------------------------------------------------------
  // 1. Every family reports its own tag — the Tom-specific part of a wrapper.
  //
  //    `family` is fixed by the base class at compile time, so this is a
  //    property of the type rather than of the instance: no configuration
  //    below can make a TomCard report anything but `container`.
  // ---------------------------------------------------------------------------
  final kit = oneWidgetPerFamily();

  for (final MapEntry(key: family, value: widget) in kit.entries) {
    print('${family.name.padRight(12)} ${widget.runtimeType}');
    assert(widget.family == family);
    assert(widget.isFamily(family));
    assert(widget.families.contains(family));
  }

  // `families` is a set because the base leaves room for a widget that belongs
  // to more than one; every wrapper in the kit today reports exactly its own.
  final button = kit[TomWidgetFamily.button]!;
  print('button.families:        ${button.families}');
  print('button.isFamily(label): ${button.isFamily(TomWidgetFamily.label)}');
  assert(!button.isFamily(TomWidgetFamily.label));

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
    'label.tomId / basePath: ${kit[TomWidgetFamily.label]!.tomId} / '
    '${kit[TomWidgetFamily.label]!.basePath}',
  );

  // Inside a scope, the same construction addresses a different resource.
  TomScope.withScope('settings', () {
    final scoped = oneWidgetPerFamily();
    for (final MapEntry(key: family, value: widget) in scoped.entries) {
      assert(widget.basePath == 'settings.${family.name}');
    }
    print(
      'scoped label basePath:  '
      '${scoped[TomWidgetFamily.label]!.basePath}',
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
      TomWidgetFamily.button => TomAuthState.read,
      TomWidgetFamily.dialog => TomAuthState.none,
      TomWidgetFamily.input => TomAuthState.disabled,
      _ => TomAuthState.full, // no rule for this path
    };
    assert(widget.effectiveAuthState == expected);
  }
  print(
    'button auth (rule: read):     '
    '${oneWidgetPerFamily()[TomWidgetFamily.button]!.effectiveAuthState}',
  );
  print(
    'label auth (no rule → full):  '
    '${oneWidgetPerFamily()[TomWidgetFamily.label]!.effectiveAuthState}',
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
  //    authorization work identically — only `family` is missing, because
  //    `family` lives on `TomFamilyBase`.
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
