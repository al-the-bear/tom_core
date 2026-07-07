/// A small labelled, coloured box used as the generic "component" inside the
/// ACL layouts on display.
///
/// The ACL engine arranges *any* widget; using a plain box keeps every cell's
/// focus on the layout being demonstrated rather than on the contents of the
/// cells. Mirrors the `DemoBox` used by `tom_flutter_ui_test/lib/acl_demos/`.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Builds a labelled box tinted with [color]. Const-friendly so cells can keep
/// their snippets and their live children byte-for-byte aligned.
Widget demoBox(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: TomText(text: label),
    );
