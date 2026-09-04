/// A small labelled, coloured box used as the generic "component" inside the
/// raw-widget ACL layouts on display (row breakpoints, form-factor variants,
/// adaptive sizing).
///
/// The ACL engine arranges *any* widget; using a plain box keeps each cell's
/// focus on the responsive behaviour being demonstrated rather than on the
/// contents of the cells. Shared in shape with `core_flutter_ui_showcase` /
/// `core_flutter_acl_sample`.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Builds a labelled box tinted with [color]. The box itself is a
/// [TomContainer] (G-UI-1/G-UI-2): even the generic filler that the ACL engine
/// arranges is a Tom widget, not a raw `Container`.
Widget demoBox(String label, Color color) => TomContainer(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  alignment: Alignment.center,
  decoration: BoxDecoration(
    color: color.withValues(alpha: 0.18),
    border: Border.all(color: color),
    borderRadius: BorderRadius.circular(4),
  ),
  child: TomText(text: label),
);
