/// Executable example for the `theme/` module of `tom_flutter_ui`.
///
/// Demonstrates the two things Tom layers on top of Flutter's theming: the
/// readonly visual treatment (`TomReadonlyStyle`) and the semantic button
/// variants (`TomButtonVariants`), plus the immutable `TomTheme` value class.
/// Because it imports `flutter/material` (which pulls in `dart:ui`), run it
/// under the Flutter toolchain, e.g. `flutter test example/theme/theme_example.dart`,
/// not bare `dart run`. The same scenarios are covered by
/// `test/theme/theme_test.dart`.
library;

// Demonstration example: console output is intentional.
// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

void run() {
  // Example 1: the immutable TomTheme and copyWith.
  const base = TomTheme.defaultTheme;
  final dimmed = base.copyWith(
    name: 'dimmed',
    readonlyStyle: const TomReadonlyStyle(opacity: 0.5),
  );
  print('base="${base.name}" dimmed="${dimmed.name}" '
      'opacity=${dimmed.readonlyStyle.opacity}');

  // Example 2: the default readonly treatment wraps content in an
  // AbsorbPointer (over an Opacity). apply() needs no BuildContext.
  final wrapped = TomReadonlyStyle.defaultStyle.apply(const Text('field'));
  print('default readonly -> ${wrapped.runtimeType}');

  // Example 3: a fully permissive style returns the content untouched.
  const passthrough = TomReadonlyStyle(opacity: 1.0, absorbPointers: false);
  const content = Text('editable');
  final unwrapped = passthrough.apply(content);
  print('passthrough identical -> ${identical(unwrapped, content)}');

  // Example 4: a custom builder replaces the default treatment entirely.
  final custom = TomReadonlyStyle(
    builder: (child) => Banner(
      message: 'read-only',
      location: BannerLocation.topEnd,
      child: child,
    ),
  ).apply(const Text('field'));
  print('custom readonly -> ${custom.runtimeType}');

  // Example 5: semantic button variants derived from a ColorScheme.
  const scheme = ColorScheme.light();
  final variants = TomButtonVariants.fromColorScheme(scheme);
  final primaryBg =
      variants.primary.backgroundColor?.resolve(<WidgetState>{});
  final destructiveBg =
      variants.destructive.backgroundColor?.resolve(<WidgetState>{});
  print('primary bg=$primaryBg destructive bg=$destructiveBg');

  // Example 6: themes and styles are values, which is what lets a
  // TomThemeScope built inside `build` avoid rebuilding its dependents on
  // every ancestor rebuild. copyWith always allocates, so without value
  // equality every rebuild would look like a theme change.
  final rebuiltDimmed = base.copyWith(
    name: 'dimmed',
    readonlyStyle: const TomReadonlyStyle(opacity: 0.5),
  );
  print('separately built themes equal -> ${rebuiltDimmed == dimmed}');

  // The exception: `builder` holds a function, and functions compare by
  // reference. A hoisted (named) builder is the same object every time; an
  // inline closure is a new one on each build.
  final hoistedA = TomReadonlyStyle(builder: readOnlyBanner);
  final hoistedB = TomReadonlyStyle(builder: readOnlyBanner);
  final inlineA = TomReadonlyStyle(builder: (child) => child);
  final inlineB = TomReadonlyStyle(builder: (child) => child);
  print('hoisted builders equal -> ${hoistedA == hoistedB}   '
      'inline builders equal -> ${inlineA == inlineB}');

  // Assertions
  assert(base.name == 'default');
  assert(base.readonlyStyle.opacity == 0.6);
  assert(dimmed.name == 'dimmed');
  assert(dimmed.readonlyStyle.opacity == 0.5);
  // copyWith leaves untouched fields intact.
  assert(base.copyWith().name == 'default');

  assert(wrapped is AbsorbPointer);
  assert(identical(unwrapped, content));
  assert(custom is Banner);

  assert(primaryBg == scheme.primary);
  assert(destructiveBg == scheme.error);

  // Value equality: separate instances with the same fields are the same
  // theme, and a no-op copyWith changes nothing.
  assert(rebuiltDimmed == dimmed);
  assert(rebuiltDimmed.hashCode == dimmed.hashCode);
  assert(base.copyWith() == base);
  assert(dimmed != base);
  // The nested style counts too.
  assert(base.copyWith(readonlyStyle: const TomReadonlyStyle(opacity: 0.5)) !=
      base);

  // Hoisted builders compare equal; inline ones never do — which is why a
  // custom builder belongs in a named function.
  assert(hoistedA == hoistedB);
  assert(inlineA != inlineB);
}

/// A hoisted read-only builder: naming the function is what lets two
/// [TomReadonlyStyle]s that use it compare equal across rebuilds.
Widget readOnlyBanner(Widget child) => Banner(
      message: 'read-only',
      location: BannerLocation.topEnd,
      child: child,
    );

void main() => run();
