/// Shared golden-test font loader.
///
/// Golden screenshots must render identical real text on every fleet host.
/// The fonts are therefore **committed** under `test/fonts/` and loaded from
/// those version-controlled bytes via a package-root-relative path (the CWD of
/// `flutter test`), exactly like `d4rt_flutter_sample`.
///
/// Why not the Flutter SDK's own font files: they live at a host-specific
/// absolute path (`.../bin/cache/dart-sdk/.../devtools/assets/fonts/Roboto`,
/// `.../artifacts/material_fonts/...`) and system paths (`/usr/share/fonts/...`)
/// that differ per machine and are simply absent on other hosts. The old
/// per-file loaders guarded each read with `existsSync()`, so on any host where
/// the path did not resolve they silently loaded *nothing* — text fell back to
/// the flutter_test Ahem font, producing up to ~47% cross-host pixel drift
/// (measured bomber→bigbeast, RCL14). Reading committed bytes makes rendering
/// deterministic; a missing file now throws instead of silently degrading.
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads every font family the golden suites render, from the committed
/// `test/fonts/` directory. Call once (e.g. in `setUpAll`) before pumping any
/// widget whose golden is compared.
Future<void> loadTestFonts() async {
  await _loadFamily('Roboto', const [
    'test/fonts/Roboto-Thin.ttf',
    'test/fonts/Roboto-Light.ttf',
    'test/fonts/Roboto-Regular.ttf',
    'test/fonts/Roboto-Medium.ttf',
    'test/fonts/Roboto-Bold.ttf',
    'test/fonts/Roboto-Black.ttf',
  ]);
  await _loadFamily('serif', const [
    'test/fonts/DejaVuSerif.ttf',
    'test/fonts/DejaVuSerif-Bold.ttf',
  ]);
  await _loadFamily('MaterialIcons', const [
    'test/fonts/MaterialIcons-Regular.otf',
  ]);
}

/// Registers all [paths] under font [family]. Throws if any file is missing so
/// a broken/relocated checkout fails loudly instead of rendering fallback glyphs.
Future<void> _loadFamily(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    final file = File(path);
    if (!file.existsSync()) {
      throw StateError(
        'Golden test font not found: "$path" '
        '(cwd=${Directory.current.path}). Fonts must be committed under '
        'test/fonts/ so golden rendering is host-independent.',
      );
    }
    loader.addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer)));
  }
  await loader.load();
}
