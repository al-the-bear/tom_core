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

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

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
