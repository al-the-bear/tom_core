/// Cards & surfaces group — cards, containers and dividers.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';

/// The Cards & surfaces component group.
final ShowcaseGroup cardsGroup = ShowcaseGroup(
  id: 'cards',
  title: 'Cards & surfaces',
  summary:
      'Cards, decorated containers and dividers — the surfaces that '
      'group and separate content.',
  icon: Icons.dashboard_outlined,
  cells: (context) => [
    ShowcaseCell(
      title: 'TomCard',
      code:
          "TomCard(\n"
          "  elevation: 2,\n"
          "  child: TomPadding(\n"
          "    padding: const EdgeInsets.all(16),\n"
          "    child: TomText(text: 'Card content'),\n"
          "  ),\n"
          ")",
      child: TomCard(
        elevation: 2,
        child: TomPadding(
          padding: const EdgeInsets.all(16),
          child: TomText(text: 'Card content'),
        ),
      ),
    ),
    ShowcaseCell(
      title: 'TomContainer',
      code:
          "TomContainer(\n"
          "  height: 80,\n"
          "  decoration: BoxDecoration(\n"
          "    border: Border.all(\n"
          "      color: Theme.of(context).colorScheme.outline,\n"
          "    ),\n"
          "    borderRadius: BorderRadius.circular(8),\n"
          "  ),\n"
          "  child: TomCenter(child: TomText(text: 'Boxed')),\n"
          ")",
      child: TomContainer(
        height: 80,
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: TomCenter(child: TomText(text: 'Boxed')),
      ),
    ),
    ShowcaseCell(
      title: 'TomDivider',
      code:
          "TomColumn(\n"
          "  mainAxisSize: MainAxisSize.min,\n"
          "  children: [\n"
          "    TomText(text: 'Above'),\n"
          "    TomDivider(thickness: 2),\n"
          "    TomText(text: 'Below'),\n"
          "  ],\n"
          ")",
      child: TomColumn(
        mainAxisSize: MainAxisSize.min,
        children: [
          TomText(text: 'Above'),
          TomDivider(thickness: 2),
          TomText(text: 'Below'),
        ],
      ),
    ),
  ],
);
