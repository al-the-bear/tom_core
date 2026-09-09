/// Executable example for the `widget_base/` module of `tom_flutter_ui`.
///
/// Demonstrates the two resource-resolution entry points the rest of the
/// library is built on: `TomCtr` (text/colour/numeric/style lookups against the
/// kernel resource provider) and `TomStyleResolvers` (parsing complex Material
/// objects from JSON resource maps). Because it imports `flutter/material`
/// (which pulls in `dart:ui`), bare `dart run` cannot execute it. Run
/// `flutter test test/widget_base/widget_base_resolvers_test.dart`, which
/// calls this example and reports its result in the exit code.
library;

// Demonstration example: console output is intentional.
// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

void run() {
  // TomUIColors needs an adapter to turn names/hex strings into Colors.
  TomUIColors.adapter = AllColorsAdapter();

  // Install a resource tree. The provider walks nested maps by dotted path, so
  // TomCtr.text('login', 'title') resolves login → title, and
  // TomCtr.textStyle('login', 'heading') walks login → heading → fontSize.
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from({
      'login': {
        'title': 'Sign in',
        'accent': '#2196F3',
        'gap': 12,
        'heading': {'fontSize': 20, 'fontWeight': 'w600', 'color': '#1565C0'},
      },
    }),
  );

  // Example 1: plain text resolution.
  final title = TomCtr.text('login', 'title');
  print('title -> $title');

  // Example 2: colour resolution from a hex string.
  final accent = TomCtr.color('login', 'accent');
  print('accent -> $accent');

  // Example 3: a numeric resource.
  final gap = TomCtr.doubleVal('login', 'gap');
  print('gap -> $gap');

  // Example 4: a composite TextStyle assembled from a sub-tree.
  final heading = TomCtr.textStyle('login', 'heading');
  print('heading -> size=${heading?.fontSize} weight=${heading?.fontWeight}');

  // Example 5: TomStyleResolvers parses Material objects directly from a map —
  // no resource provider needed, which makes these the easiest to unit-test.
  final buttonStyle = TomStyleResolvers.parseButtonStyle({
    'backgroundColor': '#FF5722',
    'elevation': 4,
  });
  final bgColor = buttonStyle?.backgroundColor?.resolve(<WidgetState>{});
  print('button bg -> $bgColor');

  final border = TomStyleResolvers.parseShapeBorder({
    'type': 'rounded',
    'borderRadius': 8,
  });
  print('shape -> ${border.runtimeType}');

  // Example 6: a missing key resolves to null (or, for text, the key itself as
  // a development indicator).
  final missingColor = TomCtr.color('login', 'nope');
  final missingText = TomCtr.text('login', 'nope');
  print('missing colour -> $missingColor; missing text -> $missingText');

  // Assertions
  assert(title == 'Sign in');
  assert(accent == const Color(0xFF2196F3));
  assert(gap == 12.0);
  assert(heading != null);
  assert(heading!.fontSize == 20);
  assert(heading!.fontWeight == FontWeight.w600);
  assert(heading!.color == const Color(0xFF1565C0));
  assert(bgColor == const Color(0xFFFF5722));
  assert(border is RoundedRectangleBorder);
  assert(missingColor == null);
  assert(missingText == 'login.nope');

  // Restore an empty provider so the example leaves no global state behind.
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(<String, dynamic>{}),
  );
}

void main() => run();
