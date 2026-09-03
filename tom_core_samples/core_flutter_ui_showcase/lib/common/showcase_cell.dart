/// The defining piece of this sample: a cell that shows a widget's
/// instantiation source *beside* the live, rendered widget.
///
/// `tom_flutter_ui_test` renders every widget but never displays the source
/// that produced it; the showcase's teaching value is precisely that
/// `code | rendered` pairing. The cell is responsive — side-by-side on wide
/// viewports, stacked on narrow ones — so it reads well both in the running
/// app and in the screenshots a published article is built from. Fittingly for
/// a `tom_flutter_ui` sample, the reflow is driven by an [AclBuilder] row
/// breakpoint (G-UI-4), not a hand-rolled `MediaQuery` width compare.
///
/// Shared in shape with `core_flutter_acl_sample` /
/// `core_flutter_acl_responsive` / `core_flutter_form_showcase`.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'code_block.dart';

/// A single showcase entry: a [title], a curated [code] snippet, and the live
/// [child] widget that snippet illustrates. An optional [note] surfaces a
/// caveat (e.g. a state that depends on a specific feature).
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

  /// Human-readable label for the component being shown.
  final String title;

  /// A curated Dart snippet of the API [child] demonstrates, kept in step with
  /// [child] by hand.
  ///
  /// It is deliberately **not** a transcript of the live source. The child is
  /// wrapped in gallery harness — width pins, stateful demo wrappers, badge
  /// rows that make the behaviour observable and testable — which would bury
  /// the one widget the cell is about. So a snippet may drop scaffolding, elide
  /// repetition behind a `…` comment, and stand in for a whole StatefulWidget
  /// with a bare `_value` and `setState`.
  ///
  /// What it may not do is **name something that does not exist**. That is the
  /// line between an abridgement and a lie, and it is the half a reader relies
  /// on when they lift a line into their own project.
  /// `showcase_cell_test.dart` holds that half: every identifier a snippet uses
  /// must also appear in the live, non-snippet source of the group file that
  /// renders it — which is why [demoBox] is public and named rather than a
  /// private `_box`.
  final String code;

  /// The live widget rendered from [code].
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
            // G-UI-4: the `code | preview` split reflows through an AclBuilder
            // row breakpoint rather than a hand-rolled MediaQuery compare — the
            // two columns share one row while the cell is at least 720px wide
            // and stack below it. The ACL default top cross-alignment (and its
            // intrinsic-free measurement) keeps previews that build an internal
            // LayoutBuilder — e.g. the ACL engine itself — robust.
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

/// A bordered surface that frames the live widget so it reads as a preview
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
