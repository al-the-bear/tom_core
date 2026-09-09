/// Executable example for the `theme/` module of `tom_flutter_ui`.
///
/// Demonstrates the two things Tom layers on top of Flutter's theming: the
/// visual treatment of its two withheld authorization states — `read` and
/// `disabled`, both described by `TomStateStyle` — and the semantic button
/// variants (`TomButtonVariants`), plus the immutable `TomTheme` value class.
/// Because it imports `flutter/material` (which pulls in `dart:ui`), bare
/// `dart run` cannot execute it. Run
/// `flutter test test/theme/theme_test.dart`, which calls this example and
/// reports its result in the exit code.
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
    readonlyStyle: const TomStateStyle(opacity: 0.5),
  );
  print(
    'base="${base.name}" dimmed="${dimmed.name}" '
    'opacity=${dimmed.readonlyStyle.opacity}',
  );

  // Example 2: the default readonly treatment wraps content in an
  // AbsorbPointer (over an Opacity). apply() needs no BuildContext.
  final wrapped = TomStateStyle.readonly.apply(const Text('field'));
  print('default readonly -> ${wrapped.runtimeType}');

  // Example 3: `disabled` is the other withheld state, and it is themed
  // exactly like `read` — same class, same composition, its own instance on
  // the theme. Only the opacity differs, and that is what tells a user *why*
  // the widget is inert. Both are settings, not constants: an app that wants
  // to distinguish "you may not" from "not right now" changes them here.
  final strictDisabled = base.copyWith(
    disabledStyle: const TomStateStyle(opacity: 0.2),
  );
  print(
    'disabled default=${base.disabledStyle.opacity} '
    'restyled=${strictDisabled.disabledStyle.opacity} '
    '(readonly untouched: ${strictDisabled.readonlyStyle.opacity})',
  );

  // Example 4: applyAuthState is the single mapping from authorization state
  // to appearance. Both enforcement points — TomPolicyNodeBase's default
  // hooks and TomWidgetMixin.applyAuthState — resolve through it, so the two
  // cannot drift apart. Note that `content` is a callback: `none` must not
  // build what it is about to discard.
  var builds = 0;
  Widget field() {
    builds++;
    return const Text('field');
  }

  final hidden = strictDisabled.applyAuthState(TomAuthState.none, field);
  final inert = strictDisabled.applyAuthState(TomAuthState.disabled, field);
  final editable = strictDisabled.applyAuthState(TomAuthState.full, field);
  print(
    'none -> ${hidden.runtimeType} (content built $builds times), '
    'disabled -> ${inert.runtimeType}, full -> ${editable.runtimeType}',
  );

  // Example 5: a fully permissive style returns the content untouched.
  const passthrough = TomStateStyle(opacity: 1.0, absorbPointers: false);
  const content = Text('editable');
  final unwrapped = passthrough.apply(content);
  print('passthrough identical -> ${identical(unwrapped, content)}');

  // Example 6: a custom builder replaces the default treatment entirely.
  final custom = TomStateStyle(
    builder: (child) => Banner(
      message: 'read-only',
      location: BannerLocation.topEnd,
      child: child,
    ),
  ).apply(const Text('field'));
  print('custom readonly -> ${custom.runtimeType}');

  // Example 7: semantic button variants derived from a ColorScheme.
  const scheme = ColorScheme.light();
  final variants = TomButtonVariants.fromColorScheme(scheme);
  final primaryBg = variants.primary.backgroundColor?.resolve(<WidgetState>{});
  final destructiveBg = variants.destructive.backgroundColor?.resolve(
    <WidgetState>{},
  );
  print('primary bg=$primaryBg destructive bg=$destructiveBg');

  // Example 8: themes and styles are values, which is what lets a
  // TomThemeScope built inside `build` avoid rebuilding its dependents on
  // every ancestor rebuild. copyWith always allocates, so without value
  // equality every rebuild would look like a theme change.
  final rebuiltDimmed = base.copyWith(
    name: 'dimmed',
    readonlyStyle: const TomStateStyle(opacity: 0.5),
  );
  print('separately built themes equal -> ${rebuiltDimmed == dimmed}');

  // The exception: `builder` holds a function, and functions compare by
  // reference. A hoisted (named) builder is the same object every time; an
  // inline closure is a new one on each build.
  final hoistedA = TomStateStyle(builder: readOnlyBanner);
  final hoistedB = TomStateStyle(builder: readOnlyBanner);
  final inlineA = TomStateStyle(builder: (child) => child);
  final inlineB = TomStateStyle(builder: (child) => child);
  print(
    'hoisted builders equal -> ${hoistedA == hoistedB}   '
    'inline builders equal -> ${inlineA == inlineB}',
  );

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

  // The disabled default is Material's disabled opacity, borrowed so a
  // Tom-disabled widget sits beside a Material-disabled one without looking
  // wrong — but it is a default, not a rule.
  assert(base.disabledStyle.opacity == 0.38);
  assert(strictDisabled.disabledStyle.opacity == 0.2);
  // Restyling one state leaves the other alone: they are two settings.
  assert(strictDisabled.readonlyStyle == base.readonlyStyle);

  // The four states map to: nothing, the disabled style, the readonly style,
  // the content itself.
  assert(hidden is SizedBox);
  assert(inert is AbsorbPointer);
  assert(((inert as AbsorbPointer).child as Opacity).opacity == 0.2);
  assert(editable is Text);
  // `full` and `disabled` each built the content once; `none` built nothing.
  assert(builds == 2);

  assert(primaryBg == scheme.primary);
  assert(destructiveBg == scheme.error);

  // Value equality: separate instances with the same fields are the same
  // theme, and a no-op copyWith changes nothing.
  assert(rebuiltDimmed == dimmed);
  assert(rebuiltDimmed.hashCode == dimmed.hashCode);
  assert(base.copyWith() == base);
  assert(dimmed != base);
  // Both nested styles count too.
  assert(
    base.copyWith(readonlyStyle: const TomStateStyle(opacity: 0.5)) != base,
  );
  assert(strictDisabled != base);

  // Hoisted builders compare equal; inline ones never do — which is why a
  // custom builder belongs in a named function.
  assert(hoistedA == hoistedB);
  assert(inlineA != inlineB);
}

/// A hoisted read-only builder: naming the function is what lets two
/// [TomStateStyle]s that use it compare equal across rebuilds.
Widget readOnlyBanner(Widget child) =>
    Banner(message: 'read-only', location: BannerLocation.topEnd, child: child);

void main() => run();
