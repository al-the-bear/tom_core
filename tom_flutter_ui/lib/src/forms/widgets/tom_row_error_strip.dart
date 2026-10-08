import 'package:flutter/material.dart';

import '../tom_form.dart';
import '../tom_form_labels.dart';

// ---------------------------------------------------------------------------
// TomRowErrorStrip — Inline row-level validation error display
// ---------------------------------------------------------------------------
//
// Renders a coloured strip that lists every field in [form] that currently
// has a [TomValidationError], using each field's [TomField.resolvedLabel] and
// [TomField.resolvedErrorMessage] so no string-resolution boilerplate is
// needed at the call site.
//
// Typical placement: as the last child inside an [ExpansionTile.children]
// list, flush with the tile's edges (set `childrenPadding: EdgeInsets.zero`
// on the tile and apply horizontal padding inside the strip itself). The
// strip shrinks to nothing when the row has no errors, so it is always safe
// to include unconditionally.
//
// Alignment:
//   The [crossAxisAlignment] parameter controls both the [Column] alignment
//   and the [TextAlign] of each line.  This is a constructor parameter so
//   it can be changed by the parent calling `setState` — the StatefulWidget
//   re-renders on `didUpdateWidget` without needing an extra listenable.

class TomRowErrorStrip extends StatefulWidget {
  const TomRowErrorStrip({
    super.key,
    required this.form,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  /// The form whose field errors are displayed.
  final TomForm form;

  /// Horizontal alignment for both the column children and text.
  /// Defaults to [CrossAxisAlignment.start] (left-aligned). Pass
  /// [CrossAxisAlignment.center] for centred layout.
  final CrossAxisAlignment crossAxisAlignment;

  @override
  State<TomRowErrorStrip> createState() => _TomRowErrorStripState();
}

class _TomRowErrorStripState extends State<TomRowErrorStrip> {
  @override
  void initState() {
    super.initState();
    widget.form.changes.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(TomRowErrorStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.form != widget.form) {
      oldWidget.form.changes.removeListener(_rebuild);
      widget.form.changes.addListener(_rebuild);
    }
    // crossAxisAlignment changes arrive via the updated widget prop;
    // didUpdateWidget is followed by an automatic build() call so no
    // explicit setState is needed for alignment updates.
  }

  @override
  void dispose() {
    widget.form.changes.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final errors = widget.form.fieldsWithErrors;
    if (errors.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isCenter = widget.crossAxisAlignment == CrossAxisAlignment.center;
    final count = errors.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.6),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.error.withValues(alpha: 0.4),
          ),
          bottom: BorderSide(
            color: theme.colorScheme.error.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: widget.crossAxisAlignment,
        children: [
          Text(
            // Resolved globally: the strip reports a whole row, and the
            // one/many split is a key per plural form rather than a count
            // interpolated into a single English template.
            TomFormLabels.rowErrors(null, count),
            textAlign: isCenter ? TextAlign.center : TextAlign.start,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          for (final f in errors)
            Text(
              '• ${f.resolvedLabel}: ${f.resolvedErrorMessage}',
              textAlign: isCenter ? TextAlign.center : TextAlign.start,
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}
