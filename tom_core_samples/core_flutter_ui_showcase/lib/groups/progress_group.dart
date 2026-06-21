/// Progress group — circular and linear progress indicators.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';

/// The Progress component group.
final ShowcaseGroup progressGroup = ShowcaseGroup(
  id: 'progress',
  title: 'Progress',
  summary: 'Circular and linear progress indicators, both determinate and '
      'indeterminate.',
  icon: Icons.donut_large,
  cells: (context) => [
    ShowcaseCell(
      title: 'TomCircularProgressIndicator (indeterminate)',
      code: "TomCircularProgressIndicator()",
      child: TomCircularProgressIndicator(),
    ),
    ShowcaseCell(
      title: 'TomCircularProgressIndicator (determinate)',
      code: "TomCircularProgressIndicator(\n"
          "  value: 0.65,\n"
          ")",
      child: TomCircularProgressIndicator(value: 0.65),
    ),
    ShowcaseCell(
      title: 'TomLinearProgressIndicator (determinate)',
      code: "TomLinearProgressIndicator(\n"
          "  value: 0.4,\n"
          ")",
      child: SizedBox(
        width: 240,
        child: TomLinearProgressIndicator(value: 0.4),
      ),
    ),
  ],
);
