/// Regression test for feedback round 4 (r/s).
///
/// Symptom: every Cupertino icon in Demo M / Demo N rendered as a
/// small placeholder rectangle, and the eventTime row rendered as
/// what looked like an open lock — classic signature of the
/// `CupertinoIcons.ttf` font not being bundled (so the renderer
/// falls back to the next loaded font, which happens to ship a
/// glyph at the colliding codepoint).
///
/// Root cause was that `tom_flutter_form_test/pubspec.yaml` declared
/// neither a direct dependency on `cupertino_icons` nor a transitive
/// pull-through. Flutter's asset bundler only bundles a font when
/// the owning package appears in the resolved dependency graph;
/// without that, the IconData's `fontFamily: 'CupertinoIcons'` falls
/// back to the system font.
///
/// This test asserts the regression doesn't recur by reading the
/// FontManifest.json that Flutter generates at build time and
/// verifying the CupertinoIcons family is present.
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('(r/s) FontManifest bundles the CupertinoIcons font', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final manifestStr = await rootBundle.loadString('FontManifest.json');
    final manifest = json.decode(manifestStr) as List<dynamic>;
    // Each entry: { "family": "<name>", "fonts": [ { "asset": ... } ] }.
    final families = manifest
        .map((e) => (e as Map<String, dynamic>)['family'] as String)
        .toList();
    // Fonts shipped through a package are registered under the
    // synthetic family `packages/<pkg>/<family>` — that's what
    // Flutter resolves when an `IconData` carries both `fontFamily`
    // and `fontPackage`. So the assertion looks for either form.
    const cupertinoFamily = 'CupertinoIcons';
    const cupertinoPackagedFamily =
        'packages/cupertino_icons/CupertinoIcons';
    expect(
      families.any((f) =>
          f == cupertinoFamily || f == cupertinoPackagedFamily),
      isTrue,
      reason: 'CupertinoIcons font missing from FontManifest — '
          'Cupertino widget icons will render as placeholder '
          'rectangles. Make sure `cupertino_icons` is in '
          'pubspec.yaml dependencies. Got families: $families',
    );

    // Drill in once: the family declaration should reference the
    // .ttf asset shipped by the cupertino_icons package, not a stub.
    final cupertino = manifest.cast<Map<String, dynamic>>().firstWhere(
        (e) =>
            e['family'] == cupertinoFamily ||
            e['family'] == cupertinoPackagedFamily);
    final fonts = (cupertino['fonts'] as List).cast<Map<String, dynamic>>();
    final assets =
        fonts.map((f) => f['asset'] as String).toList(growable: false);
    expect(assets, isNotEmpty);
    expect(
      assets.any((a) => a.endsWith('CupertinoIcons.ttf')),
      isTrue,
      reason: 'Expected at least one font asset to be CupertinoIcons.ttf, '
          'got: $assets',
    );
  });
}
