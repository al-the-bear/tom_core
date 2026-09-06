/// Guards every `*.icon` resource name in `lib/demo_resources.dart` against
/// naming an icon the generated table does not hold.
///
/// `TomUIIcons.resolveIcon` returns `null` for an unknown name, and every
/// widget that consumes one treats `null` as "no icon" — so a misspelt or
/// stale name renders a blank space and nothing anywhere reports it. That is
/// not hypothetical: 55 of the app's 362 icon names were dangling — 48 written
/// in the SDK's own snake_case (`aspect_ratio`) rather than the table's key
/// form (`mAspectRatio`), and 7 invented outright (`mDialog`, `mTooltip`,
/// `cTabBarItem` — no such SDK icon under any spelling). They had been wrong
/// since they were written, and the only symptom was an icon that never
/// appeared.
///
/// The assertion runs through the same seam the widgets do —
/// `initializeDemoResources()` installs the provider and the adapter, and the
/// test resolves through `TomUIIcons` — so it fails for exactly the reason a
/// screen would render blank, not for a lookalike reason of its own.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';
import 'package:tom_flutter_ui_test/demo_resources.dart';

/// Every `<path>.icon` leaf in [resources], as full dotted key to value.
///
/// The demo maps are authored flat, but `TomTextResourceProvider` resolves a
/// path through nested maps just as happily, so the walk descends rather than
/// assuming the flat shape the maps happen to use today.
Map<String, String> _iconNames(
  Map<String, dynamic> resources, [
  String at = '',
]) {
  final found = <String, String>{};
  resources.forEach((key, value) {
    final path = at.isEmpty ? key : '$at.$key';
    if (value is Map<String, dynamic>) {
      found.addAll(_iconNames(value, path));
    } else if (value is String && path.endsWith('.icon')) {
      found[path] = value;
    }
  });
  return found;
}

void main() {
  setUpAll(initializeDemoResources);

  test('every icon resource names an icon the generated table holds', () {
    final names = _iconNames(
      TomTextResourceProvider.getAppResources().resources,
    );

    // A guard that found nothing would pass forever; the app has hundreds.
    expect(names, hasLength(greaterThan(300)));

    final unresolved = {
      for (final entry in names.entries)
        if (TomUIIcons.resolveIcon(entry.value) == null) entry.key: entry.value,
    };
    expect(
      unresolved,
      isEmpty,
      reason:
          'These resource keys name icons GeneratedIcons does not contain, so '
          'the widgets reading them render no icon at all. Icon keys are '
          '`m<PascalCase>` for Material and `c<PascalCase>` for Cupertino — '
          'the SDK\'s snake_case name is not a key.',
    );
  });
}
