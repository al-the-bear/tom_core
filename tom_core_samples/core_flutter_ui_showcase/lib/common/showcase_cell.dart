/// The defining piece of this sample: a cell that shows a widget's
/// instantiation source *beside* the live, rendered widget.
///
/// `tom_flutter_ui_test` renders every widget but never displays the source
/// that produced it; the showcase's teaching value is precisely that
/// `code | rendered` pairing. The cell is responsive — side-by-side on wide
/// viewports, stacked on narrow ones — so it reads well both in the running
/// app and in the screenshots a published article is built from.
library;

import 'package:flutter/material.dart';

import 'code_block.dart';

/// A single showcase entry: a [title], the verbatim [code] snippet, and the
/// live [child] widget the snippet produces. An optional [note] surfaces a
/// caveat (e.g. a state that depends on a specific feature).
class ShowcaseCell extends StatelessWidget {
  const ShowcaseCell({
    super.key,
    required this.title,
    required this.code,
    required this.child,
    this.note,
  });

  /// Human-readable label for the component being shown.
  final String title;

  /// The verbatim Dart that produced [child]. Kept in lock-step with [child]
  /// by hand (the article wants curated snippets); `showcase_cell_test.dart`
  /// asserts both halves are present so an empty snippet can't slip through.
  final String code;

  /// The live widget rendered from [code].
  final Widget child;

  /// Optional caveat shown under the title.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 720;

    final codeView = CodeBlock(code);
    final preview = _PreviewSurface(child: child);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            if (note != null) ...[
              const SizedBox(height: 4),
              Text(
                note!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.secondary),
              ),
            ],
            const SizedBox(height: 12),
            if (wide)
              // Top-aligned rather than stretched: some previews (e.g. the ACL
              // engine) build a LayoutBuilder internally, which cannot be
              // measured by IntrinsicHeight. Letting each column size itself
              // keeps the cell robust for every widget family.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: codeView),
                  const SizedBox(width: 16),
                  Expanded(child: preview),
                ],
              )
            else ...[
              codeView,
              const SizedBox(height: 12),
              preview,
            ],
          ],
        ),
      ),
    );
  }
}

/// A bordered surface that frames the live widget so it reads as a preview
/// rather than part of the page chrome.
class _PreviewSurface extends StatelessWidget {
  const _PreviewSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: child,
      ),
    );
  }
}
