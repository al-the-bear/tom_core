/// A small labelled, coloured box used as the generic "component" inside the
/// raw-widget ACL layouts on display (row breakpoints, form-factor variants,
/// adaptive sizing).
///
/// The ACL engine arranges *any* widget; using a plain box keeps each cell's
/// focus on the responsive behaviour being demonstrated rather than on the
/// contents of the cells. Shared in shape with `core_flutter_acl_sample`.
library;

import 'package:flutter/material.dart';

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
      child: Text(label),
    );
