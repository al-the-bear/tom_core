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
// Why: extends [TomStatelessWidget] (not raw StatelessWidget) so the chrome
// itself conforms to G-UI-1/G-UI-2 — the sample's own UI is built from Tom*
// bases too. [TomStatelessWidget] is the framework's sanctioned base for a
// non-Tom layout wrapper (no tomId/resources of its own) that still enters the
// [TomScope]; a family base (e.g. TomContainerBase) would attach a spurious
// authorization/family identity this teaching cell must not carry. Its
// construction runs [TomScope.current], so the constructor cannot be const.
class ShowcaseCell extends TomStatelessWidget {
  ShowcaseCell({
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
  Widget buildContent(BuildContext context) {
    final theme = Theme.of(context);

    final codeView = CodeBlock(code);
    final preview = _PreviewSurface(child: child);

    return TomCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomText(text: title, style: theme.textTheme.titleMedium),
            if (note != null) ...[
              TomSizedBox(height: 4),
              TomText(
                text: note!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.secondary),
              ),
            ],
            TomSizedBox(height: 12),
            // Dogfood the engine (G-UI-4): a sample *about* responsiveness lays
            // its own cells out with an AclBuilder row breakpoint instead of a
            // hand-rolled MediaQuery compare — code | preview share one row
            // while the cell is at least 720px wide and reflow to a stack below
            // it. The ACL default top cross-alignment and its intrinsic-free
            // measurement keep previews that build an internal LayoutBuilder —
            // the ACL engine itself — robust.
            AclBuilder()
                .setAclExpandXDefault(true)
                .append(codeView)
                .addRowBreakpoint(atWidth: 720, splitRowDist: 12)
                .append(preview, dist: 16)
                .build(),
          ],
        ),
      ),
    );
  }
}

/// A bordered surface that frames the live layout so it reads as a preview
/// rather than part of the page chrome.
// Why: same rationale as [ShowcaseCell] — a scope-participating layout wrapper,
// so it derives from [TomStatelessWidget] and frames its content with
// [TomContainer]/[TomAlign] rather than raw Container/Align. Non-const for the
// same reason (construction enters [TomScope.current]).
class _PreviewSurface extends TomStatelessWidget {
  _PreviewSurface({required this.child});

  final Widget child;

  @override
  Widget buildContent(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TomContainer(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: TomAlign(
        alignment: Alignment.centerLeft,
        child: child,
      ),
    );
  }
}
