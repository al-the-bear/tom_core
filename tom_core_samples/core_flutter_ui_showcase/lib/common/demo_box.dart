/// A small labelled, coloured box used as the generic "component" inside the
/// layout and ACL cells.
///
/// Layout engines arrange *any* widget; using a plain box keeps those cells'
/// focus on the arrangement being demonstrated rather than on the contents of
/// the boxes. It is public, and named, precisely so the snippets can call it:
/// a `ShowcaseCell.code` must name only things the reader can look up, so a
/// private `_box` — or a bare `boxA` that exists nowhere — would break the
/// verbatim contract the cell's own dartdoc states.
///
/// Shared in shape with `core_flutter_acl_sample` / `core_flutter_acl_responsive`.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Builds a labelled box tinted with [color]. The box itself is a
/// [TomContainer] (G-UI-1/G-UI-2): even the generic filler that a layout
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
