/// The defining piece of this sample: a cell that shows a responsive layout's
/// instantiation source *beside* the live, rendered layout.
///
/// The teaching value is the `code | rendered` pairing — the verbatim builder
/// chain next to the layout it produces. Fittingly for a sample *about* the
/// responsive engine, the cell **dogfoods** that engine to lay itself out:
/// [AclDeviceContext.resolveFormFactor] decides side-by-side on tablet/desktop
/// widths vs. stacked on phone widths, rather than a bare numeric `MediaQuery`
/// compare. Shared in shape with `core_flutter_form_showcase` /
/// `core_flutter_acl_sample`.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'code_block.dart';

/// A single showcase entry: a [title], the verbatim [code] snippet, and the
/// live [child] layout the snippet produces. An optional [note] surfaces a
/// caveat (e.g. the width threshold a mechanism reacts at).
class ShowcaseCell extends StatelessWidget {
  const ShowcaseCell({
    super.key,
    required this.title,
    required this.code,
    required this.child,
    this.note,
  });

  /// Human-readable label for the mechanism being shown.
  final String title;

  /// The verbatim Dart that produced [child]. Kept in lock-step with [child]
  /// by hand (the article wants curated snippets); `showcase_cell_test.dart`
  /// asserts both halves are present so an empty snippet can't slip through.
  final String code;

  /// The live layout rendered from [code].
  final Widget child;

  /// Optional caveat shown under the title.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Dogfood the engine: a sample about responsiveness lays its own cells out
    // with the same form-factor tiers it teaches. phone → stacked; tablet /
    // desktop → side by side.
    final width = MediaQuery.sizeOf(context).width;
    final wide =
        AclDeviceContext.resolveFormFactor(width) != AclFormFactor.phone;

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
              // Top-aligned rather than stretched: several previews build a
              // LayoutBuilder internally (the ACL engine), which cannot be
              // measured by IntrinsicHeight. Letting each column size itself
              // keeps the cell robust for every layout.
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

/// A bordered surface that frames the live layout so it reads as a preview
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
