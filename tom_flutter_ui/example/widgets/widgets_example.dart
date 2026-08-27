/// Executable example for the `widgets/` module of `tom_flutter_ui`.
///
/// `widgets/` is the **general widget kit** — ~200 thin Tom wrappers over the
/// Flutter/Cupertino widget set, grouped into 21 families (buttons, labels,
/// inputs, toggles, containers, dialogs, navigation, progress, …). Each wrapper
/// extends a family base class (`TomButtonBase`, `TomLabelBase`, …) from
/// `widget_base/`, so every widget inherits the same Tom contract:
///
/// - it reports its [TomWidgetFamily] via `family` / `families` / `isFamily`,
/// - it carries a `tomId` and a scope-resolved `basePath`,
/// - it resolves an `effectiveAuthState` from resource auth + authorizer +
///   UI-state controller + group, with no `BuildContext`,
/// - it resolves its display values from Tom resources at construction time.
///
/// This example demonstrates those **context-free** surfaces across a handful
/// of widgets from different families. Rendering (the `build` half) needs a
/// widget tree and is out of scope here — see `gallery_demo.dart` and the
/// per-widget `testWidgets` suites for that.
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

void run() {
  // Construction resolves display values from Tom resources, so install an
  // (empty) provider and a colours adapter — exactly as the widget tests do.
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(const {}),
  );
  TomUIColors.adapter = AllColorsAdapter();
  TomAuthorization.reset();

  // ---------------------------------------------------------------------------
  // 1. Every widget reports its family — the Tom-specific tag on each wrapper.
  // ---------------------------------------------------------------------------
  final button = TomElevatedButton(
    tomId: 'save',
    onPressed: () {},
    child: TomText(text: 'Save'),
  );
  final label = TomText(tomId: 'greeting', text: 'Hello');
  final checkbox = TomCheckbox(tomId: 'agree', value: true, onChanged: (_) {});
  final container = TomContainer(tomId: 'panel', child: const SizedBox());
  final progress =
      TomCircularProgressIndicator(tomId: 'busy', semanticsLabel: 'Loading');

  print('button.family    = ${button.family}');
  print('label.family     = ${label.family}');
  print('checkbox.family  = ${checkbox.family}');
  print('container.family = ${container.family}');
  print('progress.family  = ${progress.family}');
  print('button.isFamily(button): ${button.isFamily(TomWidgetFamily.button)}');
  print('label.families:   ${label.families}');

  // ---------------------------------------------------------------------------
  // 2. tomId / basePath flow through the same node base for every family.
  // ---------------------------------------------------------------------------
  print('button.basePath  = ${button.basePath}');
  print('label.basePath   = ${label.basePath}');

  // ---------------------------------------------------------------------------
  // 3. effectiveAuthState resolves from resource auth (+ authorizer + group),
  //    with no BuildContext.  'save' is read-only; 'greeting' has no rule → full.
  // ---------------------------------------------------------------------------
  TomAuthorization.adapter = _PathAuthAdapter({
    'save': TomAuthState.read,
    'tools': TomAuthState.read, // group ceiling for controlsWidest
  });
  final saveBtn = TomElevatedButton(
    tomId: 'save',
    onPressed: () {},
    child: TomText(text: 'Save'),
  );
  final freeLabel = TomText(tomId: 'greeting', text: 'Hello');
  print('saveBtn auth (resource read):   ${saveBtn.effectiveAuthState}');
  print('freeLabel auth (no rule → full): ${freeLabel.effectiveAuthState}');

  // A widget in a group is narrowed to the group ceiling: full ⊓ read = read.
  final tools = TomAuthorizationGroup('tools'); // default mode: controlsWidest
  final grouped =
      TomContainer(tomId: 'panel', tomGroup: tools, child: const SizedBox());
  print('grouped auth (full ⊓ read ceiling): ${grouped.effectiveAuthState}');

  // ---------------------------------------------------------------------------
  // 4. basePath is scope-prefixed when constructed inside a TomScope.
  // ---------------------------------------------------------------------------
  TomScope.withScope('settings', () {
    final scoped = TomText(tomId: 'greeting', text: 'Hi');
    print('scoped basePath: ${scoped.basePath}');
  });

  // ---------------------------------------------------------------------------
  // Assertions
  // ---------------------------------------------------------------------------
  assert(button.family == TomWidgetFamily.button);
  assert(label.family == TomWidgetFamily.label);
  assert(checkbox.family == TomWidgetFamily.toggle);
  assert(container.family == TomWidgetFamily.container);
  assert(progress.family == TomWidgetFamily.progress);

  assert(button.isFamily(TomWidgetFamily.button));
  assert(!button.isFamily(TomWidgetFamily.label));
  assert(label.families.contains(TomWidgetFamily.label));

  assert(button.basePath == 'save');
  assert(label.basePath == 'greeting');

  assert(saveBtn.effectiveAuthState == TomAuthState.read);
  assert(freeLabel.effectiveAuthState == TomAuthState.full);
  assert(grouped.effectiveAuthState == TomAuthState.read);

  TomScope.withScope('settings', () {
    final scoped = TomText(tomId: 'greeting', text: 'Hi');
    assert(scoped.basePath == 'settings.greeting');
  });

  TomAuthorization.reset();
}

void main() => run();
