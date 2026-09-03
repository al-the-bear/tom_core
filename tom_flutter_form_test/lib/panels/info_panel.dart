import 'package:flutter/material.dart';

/// Generic right-side info/control panel used by Demos A, B, C.
///
/// Provides a titled, scrollable container so pages can drop in a list of
/// widgets (field-state table, event log, theming controls, …) without each
/// demo having to repeat the same framing.
class InfoPanel extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final EdgeInsets padding;

  const InfoPanel({
    super.key,
    required this.title,
    required this.children,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// A subtle subheading for grouping rows inside an [InfoPanel].
class InfoPanelHeading extends StatelessWidget {
  final String label;
  const InfoPanelHeading(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
