/// `custom/` is a leaf, and stays one.
///
/// The kit was built as a set of composites for downstream applications, and
/// nothing in the package consumes it — the module is exported and reachable,
/// and `forms/` builds on none of it. That was once described the other way
/// round: `tom_empty_state.dart` named `TomListForm` as its consumer for the
/// empty-list case, which was never true and could not have been —
/// `TomListForm` is a Flutter-free model with no `build` method at all. The
/// wording is paraphrased rather than quoted on purpose: `check_consumer_claims
/// .py` reads the original phrasing as a live claim wherever it appears, and
/// it is right to, since a checker that could tell a quotation from an
/// assertion could be defeated by quoting.
///
/// The question that outlived the false claim is whether the integration
/// *should* exist, and the answer recorded in `doc/custom.md` is no. The
/// argument for wiring was that it would delete a duplicate: it would not.
/// `TomInlineListForm` and its siblings resolve an empty list through
/// `emptyBuilder`, then `emptyText` as a bare `Text`, then `null` — nothing
/// there reproduces `TomEmptyState`'s icon, headline, body and action. So what
/// wiring would buy is a *default*, and defaulting is the one thing an empty
/// slot should not do unasked: drawing nothing is a legitimate choice for a
/// short list inside a card, and an icon-and-headline block is not. Opting in
/// costs one line.
///
/// This file is that decision made checkable. Both directions are asserted,
/// because a leaf is only a leaf while both hold: nothing depends on it, and
/// it depends on as little as it can.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _module = 'lib/src/custom';

/// Every `.dart` file under [dir], generated output aside.
List<File> _sources(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .where((f) => !f.path.endsWith('.reflection.dart'))
    .toList();

/// The `import`/`export` targets of [file], as written.
Iterable<String> _directives(File file) => RegExp(
  r"^(?:import|export)\s+'([^']+)'",
  multiLine: true,
).allMatches(file.readAsStringSync()).map((m) => m.group(1)!);

void main() {
  test('the scan reads both sides', () {
    // Guards the two cases below: an empty walk satisfies "nothing imports
    // custom" and "custom imports little" without reading anything.
    expect(_sources(_module), hasLength(greaterThanOrEqualTo(8)));
    expect(_sources('lib'), hasLength(greaterThan(100)));
  });

  test('nothing in the package depends on custom/', () {
    // The package barrel exports it, which is how a consumer reaches it and
    // is not a dependency: an export creates no compile-time edge into the
    // module and no behaviour that the module could break.
    const barrel = 'lib/tom_flutter_ui.dart';
    final offenders = <String>[];

    for (final file in _sources('lib')) {
      if (file.path.startsWith(_module)) continue;
      if (file.path == barrel) continue;
      for (final target in _directives(file)) {
        if (target.contains('custom/')) {
          offenders.add('${file.path} → $target');
        }
      }
    }

    expect(
      offenders..sort(),
      isEmpty,
      reason:
          'the kit is deliberately downstream-only — see doc/custom.md. '
          'Wiring one of these in is a decision, not a convenience: it gives '
          'a slot a default the caller did not ask for, and couples forms to '
          'custom in a direction that is far harder to undo than to add: '
          '$offenders',
    );
  });

  test('custom/ reaches only for what it cannot do without', () {
    // The other direction. `tom_loading_overlay.dart` says in its own dartdoc
    // that it backticks `SlowValidator` rather than linking it, because
    // `custom/` does not import `forms/validation` "and must not import for
    // the sake of a doc reference". This is that sentence, checked.
    const allowed = {'widget_base/', 'custom/'};
    final offenders = <String>[];

    for (final file in _sources(_module)) {
      for (final target in _directives(file)) {
        if (target.startsWith('package:flutter') ||
            target.startsWith('package:tom_core_kernel') ||
            target.startsWith('dart:')) {
          continue;
        }
        // A relative target inside the module, or one reaching a sibling
        // module through `../`.
        final reaches = target.startsWith('../')
            ? target.substring(3)
            : 'custom/$target';
        if (!allowed.any(reaches.startsWith)) {
          offenders.add('${file.path} → $target');
        }
      }
    }

    expect(
      offenders..sort(),
      isEmpty,
      reason:
          'custom/ may use widget_base (the scope-path rule and the '
          'construction helpers, which every module shares) and itself. '
          'Anything else makes it a participant in another module rather '
          'than a kit that sits on top: $offenders',
    );
  });
}
