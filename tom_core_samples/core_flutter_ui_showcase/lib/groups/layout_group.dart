/// Layout group — the Tom flex and spacing primitives.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';

Widget _box(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: color,
      child: Text(label),
    );

/// The Layout component group.
final ShowcaseGroup layoutGroup = ShowcaseGroup(
  id: 'layout',
  title: 'Layout',
  summary: 'Rows, columns, wraps and the Expanded flex child — the Tom '
      'mirrors of Flutter\'s layout primitives.',
  icon: Icons.view_quilt_outlined,
  cells: (context) => [
    ShowcaseCell(
      title: 'TomRow',
      code: "TomRow(\n"
          "  children: [boxA, boxB, boxC],\n"
          ")",
      child: TomRow(
        mainAxisSize: MainAxisSize.min,
        children: [
          _box('A', Colors.red.shade100),
          const SizedBox(width: 8),
          _box('B', Colors.green.shade100),
          const SizedBox(width: 8),
          _box('C', Colors.blue.shade100),
        ],
      ),
    ),
    ShowcaseCell(
      title: 'TomColumn',
      code: "TomColumn(\n"
          "  crossAxisAlignment: CrossAxisAlignment.start,\n"
          "  children: [boxA, boxB],\n"
          ")",
      child: TomColumn(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _box('First', Colors.orange.shade100),
          const SizedBox(height: 8),
          _box('Second', Colors.purple.shade100),
        ],
      ),
    ),
    ShowcaseCell(
      title: 'TomRow + TomExpanded',
      code: "TomRow(\n"
          "  children: [\n"
          "    TomExpanded(flex: 2, child: boxA),\n"
          "    TomExpanded(flex: 1, child: boxB),\n"
          "  ],\n"
          ")",
      child: TomRow(
        children: [
          TomExpanded(flex: 2, child: _box('flex 2', Colors.teal.shade100)),
          TomExpanded(flex: 1, child: _box('flex 1', Colors.amber.shade100)),
        ],
      ),
    ),
    ShowcaseCell(
      title: 'TomWrap',
      code: "TomWrap(\n"
          "  spacing: 8,\n"
          "  runSpacing: 8,\n"
          "  children: [chipA, chipB, chipC, chipD],\n"
          ")",
      child: TomWrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _box('one', Colors.red.shade100),
          _box('two', Colors.green.shade100),
          _box('three', Colors.blue.shade100),
          _box('four', Colors.orange.shade100),
        ],
      ),
    ),
  ],
);
