/// Layout gate: no demo may overflow the viewport it is designed for.
///
/// An overflow is not cosmetic. Flutter's own words for it are "this is
/// considered an error condition because it indicates that there is content
/// that cannot be seen" — the striped banner is covering a control the demo
/// exists to show. Because these demos are the worked examples for the
/// `tom_flutter_ui` widgets and the ACL layout engine, an overflow here is also
/// a *documentation* fault: it teaches the reader a layout that does not fit.
///
/// **This gate measures Ahem, not Roboto**, and that is the deliberate choice.
/// `flutter test` installs the Ahem placeholder font, whose every glyph is a
/// full em square — essentially all text is wider than the same string in
/// Roboto, and text long enough to wrap gains lines and so also grows taller.
/// Two reasons to keep it:
///
/// - **It is reproducible.** Ahem ships inside `flutter_test`. The real fonts
///   come from `$FLUTTER_ROOT/bin/cache/artifacts/material_fonts`, which is
///   absent on any machine that has not downloaded the artifact — a real-font
///   gate would have to skip there, i.e. stop gating exactly where nobody
///   notices.
/// - **It leaves slack.** A layout that fits only because Roboto's glyphs are
///   narrow is one localisation or one text-scale setting away from breaking.
///   Passing under Ahem means the row had room to spare.
///
/// The consequence to keep in mind when reading a failure: the pixel counts
/// reported here are Ahem's and are larger than what the running app shows. The
/// fault is real, the number is an upper bound.
///
/// Why this is a separate file from `screenshots.dart`: that harness asserts
/// nothing — it writes a picture for a human, under the real fonts, so the
/// labels are readable — and so is deliberately kept out of the auto-discovered
/// suite. The finding it produced was therefore visible only to whoever
/// happened to run it and read the log, which is how four demos stayed broken
/// across releases. This file mounts the demos exactly the same way (both use
/// `demo_harness.dart`) and turns that finding into a failure.
///
/// Run with: `flutter test test/demo_overflow_test.dart`
@Timeout(Duration(minutes: 5))
library;

import 'package:flutter_test/flutter_test.dart';

import 'demo_harness.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => installDemoEnvironment(binding));
  tearDownAll(() => restoreDemoEnvironment(binding));

  group('demos fit the viewport', () {
    for (final (slug, _) in demos) {
      testWidgets(slug, (tester) async {
        final mount = await pumpDemo(tester, slug);

        expect(
          mount.overflows,
          isEmpty,
          reason:
              'Demo "$slug" does not fit ${viewport.width.toInt()}x'
              '${viewport.height.toInt()}. Run '
              '`flutter test test/screenshots.dart` and look at '
              'test/screenshots/$slug.png — the striped banner marks the edge '
              'that overflowed. Note the PNG uses the real fonts, so the demo '
              'may fit there while failing here; the gate measures the wider '
              'Ahem placeholder on purpose.',
        );
      });
    }
  });
}
