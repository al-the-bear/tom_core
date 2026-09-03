/// Layout group — the Tom flex and spacing primitives.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_box.dart';
import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';

/// The Layout component group.
final ShowcaseGroup layoutGroup = ShowcaseGroup(
  id: 'layout',
  title: 'Layout',
  summary:
      'Rows, columns, wraps and the Expanded flex child — the Tom '
      'mirrors of Flutter\'s layout primitives.',
  icon: Icons.view_quilt_outlined,
  cells: (context) => [
    ShowcaseCell(
      title: 'TomRow',
      code:
          "TomRow(\n"
          "  mainAxisSize: MainAxisSize.min,\n"
          "  children: [\n"
          "    demoBox('A', Colors.red),\n"
          "    TomSizedBox(width: 8),\n"
          "    demoBox('B', Colors.green),\n"
          "    TomSizedBox(width: 8),\n"
          "    demoBox('C', Colors.blue),\n"
          "  ],\n"
          ")",
      child: TomRow(
        mainAxisSize: MainAxisSize.min,
        children: [
          demoBox('A', Colors.red),
          TomSizedBox(width: 8),
          demoBox('B', Colors.green),
          TomSizedBox(width: 8),
          demoBox('C', Colors.blue),
        ],
      ),
    ),
    ShowcaseCell(
      title: 'TomColumn',
      code:
          "TomColumn(\n"
          "  mainAxisSize: MainAxisSize.min,\n"
          "  crossAxisAlignment: CrossAxisAlignment.start,\n"
          "  children: [\n"
          "    demoBox('First', Colors.orange),\n"
          "    TomSizedBox(height: 8),\n"
          "    demoBox('Second', Colors.purple),\n"
          "  ],\n"
          ")",
      child: TomColumn(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          demoBox('First', Colors.orange),
          TomSizedBox(height: 8),
          demoBox('Second', Colors.purple),
        ],
      ),
    ),
    ShowcaseCell(
      title: 'TomRow + TomExpanded',
      code:
          "TomRow(\n"
          "  children: [\n"
          "    TomExpanded(flex: 2, child: demoBox('flex 2', Colors.teal)),\n"
          "    TomExpanded(flex: 1, child: demoBox('flex 1', Colors.amber)),\n"
          "  ],\n"
          ")",
      child: TomRow(
        children: [
          TomExpanded(flex: 2, child: demoBox('flex 2', Colors.teal)),
          TomExpanded(flex: 1, child: demoBox('flex 1', Colors.amber)),
        ],
      ),
    ),
    ShowcaseCell(
      title: 'TomWrap',
      code:
          "TomWrap(\n"
          "  spacing: 8,\n"
          "  runSpacing: 8,\n"
          "  children: [\n"
          "    demoBox('one', Colors.red),\n"
          "    demoBox('two', Colors.green),\n"
          "    demoBox('three', Colors.blue),\n"
          "    demoBox('four', Colors.orange),\n"
          "  ],\n"
          ")",
      child: TomWrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          demoBox('one', Colors.red),
          demoBox('two', Colors.green),
          demoBox('three', Colors.blue),
          demoBox('four', Colors.orange),
        ],
      ),
    ),
  ],
);
