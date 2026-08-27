import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The modules whose readme claims to be a *complete* inventory of what the
/// module exports.
///
/// Not every module can make that claim, and this list is the honest half of
/// saying so. `widgets/` exports 301 mostly-mechanical Flutter wrappers and
/// `widget_base/` 31 `…Base` families; enumerating either would produce a worse
/// document than the summary that is there, so neither is checked. The four
/// below are small enough that "the table lists everything" is both true and
/// useful — and that is exactly the claim that rots, because adding a type to a
/// module is a one-line edit away from leaving the table behind.
///
/// A module joins this list by having a readme that already lists everything.
/// Never add one and then loosen the assertions to accommodate it.
const _inventoryModules = ['actions', 'groups', 'resource_auth', 'theme'];

/// A public top-level declaration. The leading alternation is the modifier
/// soup Dart allows (`abstract base class`, `mixin class`, `sealed class`);
/// the captured group is the name.
final _declaration = RegExp(
  r'^(?:abstract\s+|base\s+|final\s+|sealed\s+|interface\s+|mixin\s+)*'
  r'(?:class|mixin|enum|extension|typedef)\s+(\w+)',
  multiLine: true,
);

/// A `static` member, including `static get` / `static set` and
/// `static const` fields. Matching the declaration rather than a call site is
/// what keeps this derived from the source instead of from a hand-kept list —
/// a hand-kept list is the same artifact as the table it is guarding, and would
/// go stale with it.
final _staticMember = RegExp(
  r'^\s*static\s+(?:[\w<>,\s?]+\s+)?(?:get\s+|set\s+)?(\w+)\s*[({=;]',
  multiLine: true,
);

final _export = RegExp(r"^export\s+'([^']+)'", multiLine: true);

/// The source of every file the module's barrel re-exports.
///
/// Going through the barrel rather than globbing the directory is deliberate:
/// a file that exists but is not exported is not part of the public surface,
/// and demanding the readme document it would be wrong.
List<String> _exportedSources(String module) {
  final dir = 'lib/src/$module';
  final barrel = File('$dir/$module.dart').readAsStringSync();
  return _export
      .allMatches(barrel)
      .map((m) => File('$dir/${m.group(1)}'))
      .where((f) => f.existsSync())
      .map((f) => f.readAsStringSync())
      .toList();
}

Set<String> _publicNames(List<String> sources, RegExp pattern) => sources
    .expand(pattern.allMatches)
    .map((m) => m.group(1)!)
    .where((n) => !n.startsWith('_'))
    .toSet();

void main() {
  group('module readmes list the surface their module exports', () {
    for (final module in _inventoryModules) {
      final sources = _exportedSources(module);
      final readme = File('lib/src/$module/readme.md').readAsStringSync();

      test('$module/readme.md names every public type', () {
        final types = _publicNames(sources, _declaration);
        expect(types, isNotEmpty,
            reason: 'found no public types in $module — the barrel parse or '
                'the declaration pattern is broken, not the readme');

        final missing = types.where((t) => !readme.contains(t)).toList()..sort();
        expect(missing, isEmpty,
            reason: 'lib/src/$module/$module.dart exports these public types '
                'and lib/src/$module/readme.md never names them: $missing');
      });

      test('$module/readme.md names every public static entry point', () {
        // Types alone are not the surface. The omission that prompted this
        // check was the teardown half of resource_auth's lifecycle —
        // `reset` and the `clearCustom…` pair — none of which a table of
        // types has a row for, and all of which are what authors get wrong.
        final statics = _publicNames(sources, _staticMember);
        final missing =
            statics.where((s) => !readme.contains(s)).toList()..sort();
        expect(missing, isEmpty,
            reason: 'lib/src/$module declares these public statics and '
                'lib/src/$module/readme.md never names them: $missing');
      });
    }
  });
}
