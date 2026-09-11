/// Holds `tom_flutter_ui` and `tom_core_kernel` to being importable *together*.
///
/// This file's job is done at compile time. It imports both public barrels
/// unprefixed, with no `hide` and no `as`, and then names types from each — so
/// if the two packages ever declare a public top-level name in common again,
/// this library stops compiling and the suite fails to load. The runtime
/// assertions below exist so the file is a test rather than a comment; they
/// are not what is being guarded.
///
/// The hazard is real and cheap to reintroduce. The kernel barrel re-exports
/// `tom_basics` in full, which declares a `TomEnvironment` class and a
/// `TomPlatform` class, so any name this package adds to that pair becomes an
/// `ambiguous_import` for every library importing both — and the consumer it
/// strands is the one following `doc/kernel_types.md`'s advice to import the
/// kernel directly for anything off the bridge list. That is why this
/// package's config enums carry the qualified names `TomConfigEnvironment` and
/// `TomConfigPlatform`: `tom_basics` is published and its pair describe the
/// runtime the process executes in, so the narrower concept — configuration a
/// widget resolves against — is the one that qualifies.
///
/// Neither package's own suite imports the other's barrel, so nothing else
/// here can notice a collision; without this file it takes a hand-written
/// probe to find one.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// A public top-level declaration. The leading alternation is the modifier
/// soup Dart allows; the captured group is the name.
final _declaration = RegExp(
  r'^(?:abstract\s+|base\s+|final\s+|sealed\s+|interface\s+|mixin\s+)*'
  // `extension type Name` declares `Name`: the keyword pair is matched as one
  // alternative, ahead of plain `extension`, or `type` is taken for the name.
  r'(?:class|mixin|enum|extension\s+type|extension|typedef)\s+(\w+)',
  multiLine: true,
);

/// The `lib/` root of [package], read from the package config so the check
/// works under any checkout layout.
Directory _packageLib(String package) {
  final config =
      jsonDecode(File('.dart_tool/package_config.json').readAsStringSync())
          as Map<String, dynamic>;
  final entry = (config['packages'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((p) => p['name'] == package);
  var root = entry['rootUri'] as String;
  if (!root.endsWith('/')) root = '$root/';
  final base = Directory('.dart_tool').absolute.uri;
  return Directory.fromUri(
    base.resolve(root).resolve(entry['packageUri'] as String),
  );
}

/// Every public top-level type declared under [root].
Set<String> _publicTypesIn(Directory root) => {
  for (final file
      in root
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.endsWith('.reflection.dart')))
    for (final match in _declaration.allMatches(file.readAsStringSync()))
      if (!match.group(1)!.startsWith('_')) match.group(1)!,
};

void main() {
  test('both barrels import into one library without an ambiguous name', () {
    // The kernel's pair, reached through `tom_core_kernel` -> `tom_basics`.
    const runtimeEnvironment = TomEnvironment('test', isTest: true);
    const runtimePlatform = TomPlatform('probe');

    // This package's pair, qualified so the two can coexist.
    const configEnvironment = TomConfigEnvironment.staging;
    const configPlatform = TomConfigPlatform.desktop;

    // Naming all four above is the assertion. These keep the analyzer from
    // reporting them unused, and pin that the two pairs are genuinely
    // different kinds of thing rather than duplicates of one concept.
    expect(runtimeEnvironment.env, 'test');
    expect(runtimePlatform.name, 'probe');
    expect(configEnvironment, isA<TomConfigEnvironment>());
    expect(configPlatform, isA<TomConfigPlatform>());
  });

  test('no name is declared on both sides of the barrel', () {
    // The compile-time guard above is the strong one, but it is only strong
    // about names it happens to mention. Dart reports an ambiguous import at
    // the *use* site, not at the import, so a future collision on some other
    // name would leave this file compiling and silently strand whichever
    // consumer named that type instead.
    //
    // So the set is compared rather than sampled. `tom_basics` and
    // `tom_crypto` are in it because the kernel barrel re-exports both in
    // full: a name they declare reaches a consumer exactly as the kernel's own
    // do, which is how `TomEnvironment` and `TomPlatform` collided in the
    // first place.
    final ui = _publicTypesIn(Directory('lib/src'));
    final reachable = _publicTypesIn(_packageLib('tom_core_kernel'))
        .union(_publicTypesIn(_packageLib('tom_basics')))
        .union(_publicTypesIn(_packageLib('tom_crypto')));

    // Non-vacuity: an empty side would satisfy the check below while
    // comparing nothing.
    expect(
      ui.length,
      greaterThan(500),
      reason: 'found ${ui.length} types under lib/src — the scan is broken',
    );
    expect(
      reachable.length,
      greaterThan(200),
      reason:
          'found ${reachable.length} reachable types — package-config '
          'resolution is broken, not the packages',
    );

    expect(
      ui.intersection(reachable).toList()..sort(),
      isEmpty,
      reason:
          'these names are declared both in tom_flutter_ui and in a package '
          'the kernel barrel re-exports, so every use of one in a library '
          'importing both barrels is an ambiguous_import. Qualify the name on '
          'this side, as TomConfigEnvironment / TomConfigPlatform are',
    );
  });

  test('a config provider builds from the renamed enums', () {
    // The call `doc/kernel_types.md` used to single out as un-compilable in a
    // library that also imports the kernel. It compiles here, in such a
    // library, which is the whole point.
    final config = TomConfigProvider.create(
      environment: TomConfigEnvironment.production,
      platform: TomConfigPlatform.web,
      flags: const {'beta': true},
    );

    expect(config.environment, TomConfigEnvironment.production);
    expect(config.platform, TomConfigPlatform.web);
    expect(config.isEnabled('beta'), isTrue);
  });
}
