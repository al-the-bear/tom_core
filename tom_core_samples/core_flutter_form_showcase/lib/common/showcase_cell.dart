/// The defining piece of this sample: a cell that shows a form field's
/// declaration source *beside* the live, bound field it produces.
///
/// The teaching value is precisely that `code | rendered` pairing, and here the
/// rendered half is not a static widget: it is a field really bound to a
/// reflected entity, so the validation, formatting and authorization the reader
/// exercises are the ones the snippet declared. The cell is responsive —
/// side-by-side on wide viewports, stacked on narrow ones — so it reads well
/// both in the running app and in the screenshots a published article is built
/// from. Fittingly for a `tom_flutter_ui` sample, the reflow is driven by an
/// [AclBuilder] row breakpoint (G-UI-4), not a hand-rolled `MediaQuery` width
/// compare. Shared in shape with `core_flutter_ui_showcase` /
/// `core_flutter_acl_sample` / `core_flutter_acl_responsive`.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'code_block.dart';

/// A single showcase entry: a [title], the verbatim [code] snippet, and the
/// live [child] widget the snippet produces. An optional [note] surfaces a
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
    this.previewMinWidth,
  });

  /// Human-readable label for the forms capability being shown.
  final String title;

  /// The verbatim Dart that produced [child]. Kept in lock-step with [child]
  /// by hand (the article wants curated snippets); `showcase_cell_test.dart`
  /// asserts both halves are present so an empty snippet can't slip through.
  final String code;

  /// The live widget rendered from [code].
  final Widget child;

  /// Optional caveat shown under the title.
  final String? note;

  /// The narrowest surface [child] renders correctly on, when it has one.
  ///
  /// Most previews are elastic and leave this null. Only the master-detail
  /// cell declares one: its fixed-width master pane leaves the detail pane no
  /// room for its field column below that point. Side-by-side is what takes a
  /// preview there — the split halves the cell — so declaring the width lets
  /// the cell stack instead of shrinking the preview past what it can render.
  final double? previewMinWidth;

  /// The narrowest code column worth splitting for. Below it the snippet wraps
  /// so hard that the side-by-side reading the cell exists for is lost.
  static const double _minCodeWidth = 280;

  /// The gutter between the two columns.
  static const double _gutter = 16;

  /// The cell width below which the `code | preview` pair stacks.
  ///
  /// Splitting is only worth it when both halves fit: the preview's declared
  /// minimum, a readable code column, and the gutter between them. 720 is the
  /// floor for a preview that declares nothing.
  double get _splitBelow => previewMinWidth == null
      ? 720
      : math.max(720, previewMinWidth! + _minCodeWidth + _gutter);

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
            // two columns share one row while the cell is wide enough for both
            // and stack below that. The ACL default top cross-alignment (and
            // its intrinsic-free measurement) keeps previews that build an
            // internal LayoutBuilder — e.g. the ACL engine itself — robust.
            _split(codeView, preview),
          ],
        ),
      ),
    );
  }

  /// Lays the two halves out as one ACL row that breaks below [_splitBelow].
  Widget _split(Widget codeView, Widget preview) {
    final builder = AclBuilder()
        .setAclExpandXDefault(true)
        .append(codeView)
        .addRowBreakpoint(atWidth: _splitBelow, splitRowDist: 12)
        .append(preview, dist: _gutter);
    // Both columns expand, so the slack is shared from their preferred widths
    // — a preview left at the default preferred width ends up much narrower
    // than the code column, whose long snippet lines prefer a wide box. A
    // declared minimum is what makes the split honour the width the preview
    // actually needs; the breakpoint above guarantees the row is wide enough
    // to grant it.
    if (previewMinWidth != null) builder.setPSize(previewMinWidth!);
    return builder.build();
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
