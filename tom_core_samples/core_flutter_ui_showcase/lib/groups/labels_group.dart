/// Labels & images group — text, icons, chips and badges.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';

/// The Labels & images component group.
final ShowcaseGroup labelsGroup = ShowcaseGroup(
  id: 'labels',
  title: 'Labels & images',
  summary: 'Text, selectable text, icons, chips and badges — the read-only '
      'display widgets.',
  icon: Icons.label_outline,
  cells: (context) => [
    ShowcaseCell(
      title: 'TomText',
      code: "TomText(\n"
          "  text: 'Headline text',\n"
          "  style: Theme.of(context).textTheme.headlineSmall,\n"
          ")",
      child: TomText(
        text: 'Headline text',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    ),
    ShowcaseCell(
      title: 'TomSelectableText',
      code: "TomSelectableText(\n"
          "  text: 'Select and copy me',\n"
          ")",
      child: TomSelectableText(text: 'Select and copy me'),
    ),
    ShowcaseCell(
      title: 'TomIcon',
      code: "TomIcon(\n"
          "  icon: Icons.star,\n"
          "  size: 32,\n"
          "  color: Colors.amber,\n"
          ")",
      child: TomIcon(icon: Icons.star, size: 32, color: Colors.amber),
    ),
    ShowcaseCell(
      title: 'TomChip',
      code: "TomChip(\n"
          "  labelText: 'Flutter',\n"
          ")",
      child: TomChip(labelText: 'Flutter'),
    ),
    ShowcaseCell(
      title: 'TomBadge',
      code: "TomBadge(\n"
          "  labelText: '5',\n"
          "  child: TomIcon(icon: Icons.notifications_outlined),\n"
          ")",
      child: TomBadge(
        labelText: '5',
        child: TomIcon(icon: Icons.notifications_outlined),
      ),
    ),
  ],
);
